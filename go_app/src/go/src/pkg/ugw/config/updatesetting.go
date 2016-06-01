package config

import (
	"crypto/tls"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"time"
)

const (
	UPDATEINFO = "UpdateSetting.UpdateInfo"
	UPDATESERV = "UpdateSetting.UpdateServ"
)

type UpdateSettingConfig struct {
	UpdateInfo []*UpdateInfo //升级信息
	UpdateServ []*UpdateServ //升级服务器地址列表
}

type UpdateServ struct {
	ServName string //名称
	Host     string //地址
	Selected uint8  //是否选中
}

type UpdateInfo struct {
	SNKey       string //减少序列号的key
	ModuleName  string //库名称
	CurVersion  string //当前版本
	LastVersion string //最新版本
	AutoUpdate  uint8  //是否自动升级
}

/*启用/禁用 配置改变时通知操作*/
func (conf *UpdateInfo) OnAutoUpdateSet(key uint8) bool {
	//合法性检测
	log.Println("OnACPolicyUpdate was called!")
	Notify_upgrade("updatepolicy")
	return true
}

/*事件通知接口*/
func Notify_upgrade(cmd string) {
	go UPgradeNotify.SendMsg(cmd, []string{""})
}

//update.ip-com.com.cn:6666/upgrade/ugw50/dpi/version.txt
const testfile = "/upgrade/ugw50/dpi/version.txt"

func (conf *UpdateSettingConfig) TestServ() string { //测试服务器

	result := "BAD"
	for i := 0; i < len(conf.UpdateServ); i++ {
		serv := conf.UpdateServ[i]

		if serv.Selected == 1 {

			redirectPolicy := func(req *http.Request, via []*http.Request) error {
				if len(via) >= 1 {
					return errors.New("stopped after 3 redirects")
				}
				return nil
			}

			transport := &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
				Dial: func(proto, addr string) (net.Conn, error) {
					conn, err := net.DialTimeout(proto, addr, 3*time.Second)
					if err != nil {
						return nil, err
					}
					deadline := time.Now().Add(3 * time.Second)
					conn.SetDeadline(deadline)
					return conn, nil
				},
				DisableKeepAlives:   true,
				MaxIdleConnsPerHost: 1,
			}

			httpclient := &http.Client{Transport: transport, CheckRedirect: redirectPolicy}

			url := "http://" + serv.Host + testfile
			fmt.Println("testfile is", url)
			resp, err := httpclient.Get(url)
			if err == nil {
				defer resp.Body.Close()
			}

			//resp, err := http.Get(url)
			if err != nil || resp.StatusCode/100 != 2 {
				fmt.Println("http get err:", err)
				result = "BAD"
			} else {
				fmt.Println("http get code:", resp.StatusCode)
				result = "GOOD"
				return result
			}
		}
	}

	return result
}

func (u *UpdateSettingConfig) GetFirewareVersion() string {
	f, err := os.Open("/ugw/build.info")
	if err != nil {
		return "Tue May 7 19:58:51 CST 2013"
	}
	defer f.Close()
	var buf [1024]byte
	n, err := f.Read(buf[:])
	if err != nil || n == 0 {
		return "Tue May 7 20:58:51 CST 2013"
	}
	//去掉后面的换行符
	return string(buf[:n-1])
}

func (u *UpdateSettingConfig) ShowVersionDetail() string {
	f, err := os.Open("/ugw/upgrade.info")
	if err != nil {
		return "Tue May 7 19:58:51 CST 2013"
	}
	defer f.Close()
	var buf [1024]byte
	n, err := f.Read(buf[:])
	if err != nil || n == 0 {
		return "Tue May 7 20:58:51 CST 2013"
	}
	//去掉后面的换行符
	return string(buf[:n-1])
}
