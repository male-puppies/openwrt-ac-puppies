package main
import "C"
import (
	// "app/websrv/apm"
	"app/websrv/ugwcgi"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/rpc"
	"os"
	"os/exec"
	"path/filepath"
	"pkg/ugw/config"
	"pkg/ugw/log/sys"
	"strings"
	"sync"
	"text/template"
	"time" 
)

var cgilock sync.Mutex
var WEB_ROOT string = "/www"

func main() {
	log.Println("hello world! I'm webserver...")

	base, err := os.Getwd()
	if err != nil {
		log.Fatalln(err)
	}
	log.Println("base: ", base)

	// err = exec.Command("sh", "-c", "killall httpd; httpd 8888").Run()
	// if err != nil {
	// 	log.Println("change to httpd failed: ", err)
	// }
	http.DefaultClient.CheckRedirect = dsCheckRedirect
	
	//init template
	ugwcgi.Tmpl_index = template.Must(template.ParseFiles(WEB_ROOT + "/index.html"))
	ugwcgi.Tmpl_login = template.Must(template.ParseFiles(WEB_ROOT + "/login.html"))

	//websrv router
	srv := http.NewServeMux()
	srv.HandleFunc("/", handler)
	srv.HandleFunc("/q", ugwcgi.Query)
	srv.HandleFunc("/oprlog", oprlog)
	srv.HandleFunc("/onlineuser", onlineuser)
	//srv.HandleFunc("/upload_logo", uploadlogo)
	srv.HandleFunc("/lease", lease)
	srv.HandleFunc("/login", ugwcgi.Login)
	srv.HandleFunc("/logout", ugwcgi.Logout)
	srv.HandleFunc("/download_client", ugwcgi.DownloadClient)
	srv.HandleFunc("/upload_client", ugwcgi.UploadClient)
	srv.HandleFunc("/gen_server", ugwcgi.GenServer)
	srv.HandleFunc("/dataquery", ugwcgi.DataQuery)
	srv.HandleFunc("/flowtrend", ugwcgi.FlowTrend)

	/* 请求用户列表 */
	srv.HandleFunc("/U", ugwcgi.GetUserList)
	go timeout_save()
	/* 读取http_webport */
	s := &http.Server{
		Handler:        srv,
		Addr:           ":" + config.NvramGet("http_webport", "80"), //FIXME: http_webport
		ReadTimeout:    1800 * time.Second,
		WriteTimeout:   1800 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}
	s.ListenAndServe()

	// apsvr.APsStart()
}

func oprlog(w http.ResponseWriter, r *http.Request) {
	nType := ugwcgi.CheckLogin(w, r)
	if nType == ugwcgi.UNKNOWNUSER {
		return
	}
	typex := r.FormValue("type")
	objx := r.FormValue("obj")
	msg := fmt.Sprintf("%v:%v", typex, objx)
	syslog.Info("%s", msg)
}
func lease(w http.ResponseWriter, r *http.Request) {
	nType := ugwcgi.CheckLogin(w, r)
	if nType == ugwcgi.UNKNOWNUSER {
		return
	}
	exec.Command("lua", "/ugw/lua/lease.lua").Run()
	output, err := ioutil.ReadFile("/tmp/openwrt_leases.json")
	if err != nil {
		fmt.Fprintf(w, "[]")
		return
	}
	fmt.Fprintf(w, "%s", string(output))
}

func uploadlogo(w http.ResponseWriter, r *http.Request) {

	if r.URL.Path == "/upload_logo" {
		/*文件有效性验证todo*/
		fn, _, err := r.FormFile("uploadFile")
		if err != nil {
			fmt.Println("Submit File ERROR!")
			return
		}
		defer fn.Close()

		f, err := os.Create("/www/userauthd/assets/img/logo.png")
		if err != nil {
			fmt.Println(err)
			return
		}

		defer f.Close()
		io.Copy(f, fn)

		fmt.Fprintln(w, `<script language="JavaScript">history.back(-1);</script>`)
	}
}

func onlineuser(w http.ResponseWriter, r *http.Request) {

	if ugwcgi.CheckLogin(w, r) == config.UNKNOWNUSER {
		return
	}

	cmd := r.FormValue("cmd")
	switch cmd {
	case "frozen", "unfrozen", "offline":
		ip := r.FormValue("ip")
		config.UserAuthdNotify.SendMsg(cmd, []string{ip})
		return
	case "countonlineuser":
		client, err := rpc.DialHTTP("tcp", "127.0.0.1"+":"+config.NOTIFY_PORT_UA)
		if err != nil {
			log.Println("dialing:", err)
			return
		}
		args := &config.NotifyMsgSt{cmd, []string{""}}
		var result int = 0
		err = client.Call("UserAuthd.ReceiveCmd", args, &result)
		if err != nil {
			log.Println("UserAuthd.ReceiveCmd:", err)
		}

		fmt.Fprintln(w, result)
		client.Close()
		return
	}

	//默认list
	//在线用户列表
	var UserOnlineInfoTable config.UserOnlineInfoMap
	UserOnlineInfoTable = make(config.UserOnlineInfoMap)
	buf, err := ioutil.ReadFile(config.ONLINELIST)
	if err == nil {
		err := json.Unmarshal([]byte(buf), &UserOnlineInfoTable)
		if err != nil {
			log.Println("unmarshal online user faild")
			return
		}
	} else {
		log.Println("read online user none")
		return
	}

	onlineuserlist := make([]*config.UserOnlineInfo, len(UserOnlineInfoTable))
	i := 0
	for _, v := range UserOnlineInfoTable {
		onlineuserlist[i] = v
		i++
	}
	output, err := json.Marshal(&onlineuserlist)
	if err == nil {
		fmt.Fprintf(w, "%s", string(output))
	}
}

func dsCheckRedirect(req *http.Request, via []*http.Request) error {
	if len(via) <= 0 {
		return nil
	}
	for k, v := range via[0].Header {
		req.Header.Set(k, v[0])
	}
	return nil
}

func do_port_proxy(w http.ResponseWriter, r *http.Request, islogin bool) {
	//log.Printf("!!!request: %v\n", *r)
	resp, err := http.DefaultClient.Do(r)
	if resp != nil && resp.Body != nil {
		defer resp.Body.Close()
	}

	if err != nil && err != io.EOF {
		log.Printf("Do (%v) failed %s\n", *r, err)
		http.NotFound(w, r)
		return
	}

	login_success := false
	for k, v := range resp.Header {
		w.Header().Set(k, v[0])
		if islogin && k == "Set-Cookie" {
			login_success = true
		}
	}
	if login_success {
		ugwcgi.SetLogin(w, r)
	}
	if n, err := io.Copy(w, resp.Body); err != nil {
		log.Printf("ERROR !!!!! io.Copy err: ", err)
	} else if n == 0 {
		log.Printf("%v io.Copy 0 bytes", r.URL)
	}
}

var post_map = map[string]int{
	".svg":  1,
	".gif":  1,
	".png":  1,
	".js":   1,
	".css":  1,
	".ico":  1,
	".htm":  1,
	".html": 1,
}

var clickMap map[string] int
var clickLock sync.RWMutex

func check_ads(path string) {
	if !strings.Contains(path, "/i.js") {
		return
	}

	if clickMap == nil {
		clickMap = map[string] int{}
		clickMap["count"] = 0
	}

	clickLock.Lock()
	clickMap["count"] = clickMap["count"] + 1
	clickLock.Unlock()
}

var lastMap map[string] int  
func timeout_save() {
	summary_path := "/ugw/etc/wac/ads_click.json"
	for {
		if clickMap != nil && len(clickMap) > 0 { 
			if lastMap == nil {
				b, err := ioutil.ReadFile(summary_path)

				if err == nil {
					err = json.Unmarshal(b, &lastMap) 
				}

				if lastMap == nil {
					lastMap = map[string] int{}
				}
			}

			clickLock.Lock()
			for k, v := range clickMap {
				if ov, ok := lastMap[k]; ok { 
					lastMap[k] = ov + v
				} else { 
					lastMap[k] = v
				}
			} 
			clickMap = map[string] int{}
			clickLock.Unlock()

			b, _ := json.MarshalIndent(lastMap, "", "\t") 
			ioutil.WriteFile(summary_path, b, 0644)
			fmt.Println("save", summary_path)
		}
		
		time.Sleep(10 * time.Second)
	}
}
func handler(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	ext := filepath.Ext(path)

	host := r.Host
	if strings.Contains(host, "qmswifi.com") {
		r.Host = ""
		http.Redirect(w, r, "http://172.16.0.1:8081", 302)
		return
	}

	//logout
	if strings.Contains(path, "/admin/logout") {
		ugwcgi.Logout(w, r)
		return
	}

	check_ads(path)
	islogin := false
	if path == "/cgi-bin/luci" || path == "/cgi-bin/luci/admin" || path == "/cgi-bin/luci/admin/" {
		islogin = true
	}
	//用户访问静态页面时，才更新访问时间
	ugwcgi.UpdateLogin(w, r)
	if path[len(path)-1] == '/' && len(path) < 20 {
		path += "index.html"
	}

	ext = filepath.Ext(path)
	w.Header().Add("Cache-Control", "no-cache")
	_, ok := post_map[ext]
	if ok {
		if ext == ".svg" {
			w.Header().Set("Content-type", "image/svg+xml")
		}
		http.ServeFile(w, r, WEB_ROOT+path)
	} else {
		//fmt.Printf("%+v\n", r)
		r.URL.Scheme = "http"
		r.URL.Host = "127.0.0.1:8888" //回复时的host 192.168.0.15:80
		r.Host = "127.0.0.1:8888"     //发请求时的Host
		r.RequestURI = ""

		do_port_proxy(w, r, islogin)
	}
}
