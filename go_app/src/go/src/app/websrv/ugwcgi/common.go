package ugwcgi

import (
	"io"
	"os" 
	// _ "app/websrv/apm"
	"app/websrv/session"
	_ "app/websrv/session/providers/memory"

	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os/exec"
	"pkg/ugw/config"
	"pkg/ugw/log/sys"
	"strings"
	"sync"
	"text/template"
	"time"
)

type userErrorCount struct {
	errcount int
	locktime int
}

var usererr map[string]*userErrorCount //ip -> errCount 统计结果
var usererrlock sync.Mutex

var Tmpl_login *template.Template
var Tmpl_index *template.Template

const (
	UNKNOWNUSER = 0
	SUPERUSER   = 1
)

const (
	APM_LOG_DIR = "/tmp/ugw/AP"
	APM_LOG_ZIP = "/tmp/APs.tar.gz"
)

var globalSessions *session.Manager

func init() {
	globalSessions, _ = session.NewManager("memory", "ugwsessionid", 86400)
	go globalSessions.GC()

	usererr = make(map[string]*userErrorCount)
	go func() {
		for {
			usererrlock.Lock()
			for k, v := range usererr {
				if v.errcount < 3 {
					continue
				}
				v.locktime--
				if v.locktime <= 0 {
					delete(usererr, k)
				}
			}
			usererrlock.Unlock()
			time.Sleep(1 * time.Second)
		}
	}()
}

func LoginErr(w http.ResponseWriter, r *http.Request) {
	usererrlock.Lock()
	defer usererrlock.Unlock()

	sip, _, _ := net.SplitHostPort(r.RemoteAddr)
	if v, ok := usererr[sip]; ok {
		if v.errcount >= 3 && v.locktime > 0 {
			err := fmt.Sprintf("You had entered wrong username/password for 3 times, please retry after %d seconds!", v.locktime)
			fmt.Fprintf(w, err)
			return
		} else if v.errcount > 0 {
			err := fmt.Sprintf("Wrong username or password! You still have %d chances.", 3-v.errcount)
			fmt.Fprintf(w, err)
			return
		}
	}
	fmt.Fprintf(w, "")
}

/*检查ip是否在ip范围之内*/
func checkip(sip string, iplist []config.IpRange) bool {

	ip, _ := config.GetHlIP(sip)

	bFound := true

	for i := 0; i < len(iplist); i++ {
		if iplist[i].Start == "" || iplist[i].End == "" {
			continue
		}
		start, _ := config.GetHlIP(iplist[i].Start)
		end, _ := config.GetHlIP(iplist[i].End)
		log.Println("check ip range", sip, ip, iplist[i].Start, start, iplist[i].End, end)
		if start <= ip && ip <= end {
			bFound = true
			break
		} else {
			bFound = false
		}
	}

	return bFound
}

/*登录时调用的函数, 登录成功后跳转到首页*/
func Login(w http.ResponseWriter, r *http.Request) {

	if r.Method == "GET" {
		Tmpl_login.Execute(w, "")
		return
	}

	usererrlock.Lock()
	defer usererrlock.Unlock()

	username := r.FormValue("username")
	password := r.FormValue("password")
	sip, _, _ := net.SplitHostPort(r.RemoteAddr)
	var ue *userErrorCount
	if v, ok := usererr[sip]; ok {
		ue = v
	} else {
		usererr[sip] = &userErrorCount{
			errcount: 0,
			locktime: 0,
		}
		ue = usererr[sip]
	}
	//登录失败次数超限, 请您在1分钟后再重新尝试登录!
	if ue.errcount >= 3 && ue.locktime > 0 {
		err := fmt.Sprintf("You had entered wrong username/password for 3 times, please retry after %d seconds!", ue.locktime)
		Tmpl_login.Execute(w, err)
		return
	}

	/*验证用户名密码*/
	if username != config.NvramGet("http_username", "admin") ||
		password != config.NvramGet("http_password", "admin") {
		ue.errcount++
		if ue.errcount >= 3 {
			ue.locktime = 60
		}
		err := fmt.Sprintf("Wrong username or password! You still have %d chances.", 3-ue.errcount)
		if 3-ue.errcount <= 0 {
			err = fmt.Sprintf("You had entered wrong username/password for 3 times, please retry after %d seconds!", 59)
		}
		Tmpl_login.Execute(w, err)
		return
	}

	delete(usererr, sip)

	sess := globalSessions.SessionStart(w, r)
	sess.Set("accountname", username)
	sess.Set("accounttype", SUPERUSER)
	http.Redirect(w, r, "/", http.StatusFound)
	//登录成功，写网关操作日志
}

func SetLogin(w http.ResponseWriter, r *http.Request) {
	sess := globalSessions.SessionStart(w, r)
	sess.Set("accountname", "xxx")
	sess.Set("accounttype", SUPERUSER)
}

/*注销时调用的函数
注销后跳转到登录页面*/
func Logout(w http.ResponseWriter, r *http.Request) {
	//注销成功，写网关操作日志, todo 有bug待查
	//sip, _, _ := net.SplitHostPort(r.RemoteAddr)
	sess := globalSessions.SessionStart(w, r)
	accountobj := sess.Get("accountname")
	if accountobj == nil {
		http.Redirect(w, r, "/cgi-bin/luci", http.StatusFound)
		return
	}
	//accountname := accountobj.(string)
	globalSessions.SessionDestroy(w, r)
	http.Redirect(w, r, "/cgi-bin/luci", http.StatusFound)
}

func UpdateLogin(w http.ResponseWriter, r *http.Request) {
	sess := globalSessions.SessionStart(w, r)
	sess.Update()
}

/*检查发起连接的用户是否已登录，并返回用户类型
 */
func CheckLogin(w http.ResponseWriter, r *http.Request) int {
	sip, _, _ := net.SplitHostPort(r.RemoteAddr)
	if sip == "127.0.0.1" {
		return SUPERUSER
	}

	if len(r.URL.Path) > 4 && r.URL.Path[len(r.URL.Path)-4:] == `.trx` {
		return SUPERUSER
	}

	nType := UNKNOWNUSER
	sess := globalSessions.SessionStart(w, r)
	if sess.Get("accountname") == nil {
		//http.Redirect(w, r, "/login", http.StatusFound)
		fmt.Fprintln(w, `<script language="JavaScript">parent.location.href="/cgi-bin/luci";</script>`)
	} else {
		//log.Println(sess.Get("username"), "vist page")
		nType = int(sess.Get("accounttype").(int))
	}

	return nType
}

/*管理账号配置接口*/
func Account(w http.ResponseWriter, r *http.Request) {
	if CheckLogin(w, r) == UNKNOWNUSER {
		return
	}

	cmd := r.FormValue("cmd")
	switch cmd {
	case "delete": //删除某个账户的session
		accountname := r.FormValue("name")
		log.Println("delete account: ", accountname)
		if accountname != "" {
			globalSessions.AccountDestroy(accountname)
		}
	case "get": //取得当前登录帐号的账号信息, 前端可以用来做权限控制
		sess := globalSessions.SessionStart(w, r)
		accountname := sess.Get("accountname")
		accounttype := sess.Get("accounttype")
		var output string
		if accountname != nil && accounttype != nil {
			output = fmt.Sprintf(`{"Account": "%s", "Type": %v}`, accountname, accounttype)
		} else {
			output = `{"Account": "", "Type": 0}`
		}
		fmt.Fprintln(w, output)
	}
}

func Query(w http.ResponseWriter, r *http.Request) {

	if CheckLogin(w, r) == UNKNOWNUSER {
		return
	}

	/*if r.Method == "GET" {
		fmt.Fprintln(w, "not suport GET")
		return
	}*/

	cmd := r.FormValue("cmd")

	if strings.HasPrefix(cmd, "AP.ConfBrdAddrs.set") {
		/* 重启AP管理器 */
		log.Println("AP broad addr changed. restart....")
		//go apsvr.APsStop()
	}

	log.Println("cmd: ", cmd)


	if strings.HasPrefix(cmd, "TC.Rules.deleteE") {
		if strings.Contains(cmd, "\"Free\"") || strings.Contains(cmd, "\"VIP\"") {
			fmt.Fprintln(w, `[]`)
			return
		}
	}

	var res interface{}
	err := config.Eval(cmd, &res)
	if strings.HasPrefix(cmd, "AP.ConfAcAddr.set") {
		syslog.Debug("restart apmgr")
		go func() {
			errmsg := exec.Command("appctl", "restart", "apmgr").Run()
			if errmsg != nil {
				syslog.Debug("restart apmgr fail", errmsg)
			}
		}()
	}
	if err != nil {
		log.Println(err)
		fmt.Println("ERROR", cmd, err, res)
		fmt.Fprintln(w, `[]`)
		return
	}

	if strings.HasPrefix(cmd, "RDS.") {
		s, ok := res.(string)
		if ok {
			fmt.Fprintf(w, "%s", s) 
			return 
		}
	}

	output, err := json.MarshalIndent(res, "", "   ")
	if err != nil || `null` == string(output) {
		log.Println(err)
		fmt.Println("ERROR2", cmd, err)
		fmt.Fprintln(w, `[]`)
		return
	}
	// fmt.Printf("%s %+v", string(output), res)
	fmt.Fprintf(w, "%s", string(output))
}

/*数据中心查询处理*/
func DataQuery(w http.ResponseWriter, r *http.Request) {
	/*todo 数据合法性验证*/
	/*提交数据给相应的后台处理*/
	sql := r.FormValue("data") 
	cmd := exec.Command("/ugw/bin/logquery", "-c", sql)
	cmd.Dir = config.UgwLogPath 
	Result, err := cmd.Output()

	if err != nil {
		fmt.Println("Exec command logquery Failure!", err)
		return
	}
	w.Write(Result)
}

/*数据中心查询处理，流量趋势*/
func FlowTrend(w http.ResponseWriter, r *http.Request) {
	/*todo 数据合法性验证*/
	/*提交数据给相应的后台处理*/
	cmd := exec.Command("/ugw/bin/flowtrend", r.FormValue("data"))
	cmd.Dir = config.UgwLogPath

	Result, err := cmd.Output()

	if err != nil {
		fmt.Println("Exec command flowtrend Failure!")
		return
	}
	w.Write(Result)
}

func GetUserList(w http.ResponseWriter, r *http.Request) {

	err := exec.Command("/ugw/bin/nosq").Run()
	if err != nil {
		log.Println(err)
	}

	fctx, err := ioutil.ReadFile("/tmp/ugw/stat_u")
	if err != nil {
		log.Println(err)
		goto fail
	}

	w.Header().Set("Content-Type", "application/html")
	w.Write(fctx)
	return

fail:
	fmt.Fprintln(w, `<script language="JavaScript">alert("Request failed, please retry later!")</script>`)
	return
}

func GetApmLogs(w http.ResponseWriter, r *http.Request) {
	var flogs []byte

	err := exec.Command("tar", "czf", APM_LOG_ZIP, APM_LOG_DIR).Run()
	if err != nil {
		log.Println(err)
		goto fail
	}

	flogs, err = ioutil.ReadFile(APM_LOG_ZIP)
	if err != nil {
		log.Println(err)
		goto fail
	}

	w.Header().Set("Content-Type", "application/x-msdownload")
	w.Header().Set("Content-Disposition", "attachment;filename=APs.tar.gz")
	w.Write(flogs)
	return

fail:
	fmt.Fprintln(w, `<script language="JavaScript">alert("Request failed, please retry later!")</script>`, err)
	return
}

func DownloadClient(w http.ResponseWriter, r *http.Request) {
	var ipsec config.IpsecConfig
	output, err := ipsec.DownloadClient()
	if err != nil {
		fmt.Println("Download client CA fail")
		goto fail
	}
	w.Header().Set("Content-Type", "application/x-msdownload")
	w.Header().Set("Content-Disposition", "attachment;filename=client.tar")
	w.Write(output)
	return
fail:
	fmt.Fprintln(w, `<script language="JavaScript">history.back(-1); alert("Download failed, please retry later!")</script>`, err)
}

func DownloadApLog(w http.ResponseWriter, r *http.Request) {
	apid := r.FormValue("apid") 
	if apid == "" {
		s := "no apid"
		w.Write([]byte(s))
		return
	}
	
	w.Header().Set("Content-Type", "application/x-msdownload")
	w.Header().Set("Content-Disposition", "attachment;filename=APs.tar.gz")
	xxx, _ := ioutil.ReadFile("/tmp/debug.txt")
	w.Write(xxx)
}

func GenServer(w http.ResponseWriter, r *http.Request) {
	var ipsec config.IpsecConfig
	ret := ipsec.GenServer()
	if ret == false {
		fmt.Println("Download client CA fail")
		goto fail
	}
	fmt.Fprintln(w, `<script language="JavaScript">history.back(-1); alert("服务器证书生成成功!")</script>`)
	return
fail:
	fmt.Fprintln(w, `<script language="JavaScript">history.back(-1); alert("服务器证书生成失败!")</script>`)
}

func tmpname() string {
	now := time.Now()
	return fmt.Sprintf("/tmp/json_%d.json", now.UnixNano())
}

func UploadClient(w http.ResponseWriter, r *http.Request) {
	fn, _, err := r.FormFile("uploadFile")
	if err != nil {
		fmt.Println("Submit File ERROR!", err)
		fmt.Fprintln(w, "Read from form fail", err)
		return
	}
	defer fn.Close()

	path := tmpname()
	f, err := os.Create(path)
	if err != nil {
		fmt.Println("Create File fail!", path, err)
		fmt.Fprintln(w, "Create File fail!", path, err)
		return
	}
	//defer os.Remove(path)
	io.Copy(f, fn)
	f.Close()
	var ipsec config.IpsecConfig
	ret := ipsec.UploadClient(path)
	if ret != true {
		fmt.Println("UploadClient fail!", path)
		fmt.Fprintln(w, `<script language="JavaScript">history.back(-1);alert("upload client failed!");</script>`)
		return
	}
	fmt.Println("UploadClient successfully!")
	fmt.Fprintln(w, `<script language="JavaScript">history.back(-1);alert("upload client successfully!");</script>`)
}
