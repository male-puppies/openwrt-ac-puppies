package config

import (
	_ "encoding/json"
	"fmt"
	"log"
	"net"
	"net/rpc"
	"os/exec"
	"strings"
	"time"
)

func RequestAC(args []string) (reply string, err error) {
	cli, err := rpc.Dial("tcp4", "127.0.0.1:6667")
	if err == nil {
		defer cli.Close()
		err = cli.Call("APSrvNotify.Exec", args, &reply)
	} else {
		log.Println(args)
	}
	return
}

func (apm *APConfig) SSIDReferenced(ssid string, cb func(apNode *APNodeSt) bool) bool {
	//check ref
	for _, apNode := range apm.APs {
		if apNode == nil {
			continue
		}
		for _, ref := range apNode.SSIDs {
			if ref == ssid { //ref
				apNode.NeedCommit = true
				if cb != nil {
					if !cb(apNode) {
						return false
					}
				}
				return true
			}
		}
	}

	return false
}

func (apm *APConfig) OnSSIDsDelete(m map[string]*SSIDNodeSt, k string, v *SSIDNodeSt) bool {
	log.Printf("delete ssid [%s]\n", k)

	if apm.SSIDReferenced(k, nil) {
		return false
	}

	return true
}

func (apm *APConfig) OnSSIDsInsert(m map[string]*SSIDNodeSt, k string, v *SSIDNodeSt) bool {
	log.Printf("insert ssid [%s]\n", k)

	if k == "" {
		return false
	}

	return true
}

func (apm *APConfig) OnSSIDsUpdate(m map[string]*SSIDNodeSt, k string, v *SSIDNodeSt) bool {
	log.Printf("update ssid[%s]\n", k)

	var cbCommit = func(ap *APNodeSt) bool {
		//不能在这里更新配置, 因为Update钩子函数调用在更新APM结构之前...
		//ap.ConfCommit(apm)
		//ap.ExecCommands("rc restart")
		return true
	}

	//rebuid ref aps
	if apm.SSIDReferenced(k, cbCommit) {
		return true
	}

	return true
}

func (apm *APConfig) OnConfAcAddrSet(v string) bool {
	log.Printf("set ConfAcAddr: %s->%s\n", apm.ConfAcAddr, v)

	var defer_quit = func() {
		exec.Command("killall", "apmgr").Run()
	}

	if apm.ConfAcAddr != v {
		go defer_quit()
		return true
	}
	return false
}

func ParseScanResults(sRes string, cache []*APScanSt) []*APScanSt {
	//parase
	var curObject *APScanSt
	if len(sRes) > 30 {
		lines := strings.Split(sRes, "\n")
		for _, line := range lines {
			if !strings.Contains(line, "=") { //too short
				continue
			}
			val := strings.Split(line, "=")
			if len(val) < 2 {
				continue
			}
			if val[0] == "BSSID" {
				//create a new object
				var oSingal APScanSt
				oSingal.ScanVals = make(map[string]string, 0)
				curObject = &oSingal
			}
			//log.Printf("scan[%s=%s]\n", val[0], val[1])
			curObject.ScanVals[val[0]] = val[1]
			if val[0] == "timestamp" {
				//finished && save on object
				cache = append(cache, curObject)
			}
		}
	}
	return cache
}

func (apNode *APNodeSt) ScanWl(ifname string) []*APScanSt {
	apNode.ScanCache = make([]*APScanSt, 0)

	var brcm_scan = func() {
		cmd := fmt.Sprintf("wl -i %s scan", ifname)
		_, err := RequestAC([]string{"request", apNode.AddrMac, "set", "exec_cmds", cmd})
		if err != nil {
			log.Println(err)
		}
		time.Sleep(time.Second * 2)
		cmd = fmt.Sprintf("wl -i %s dumpscan", ifname)
		_, err = RequestAC([]string{"request", apNode.AddrMac, "set", "exec_cmds", cmd})
		if err != nil {
			log.Println(err)
		}
	}

	var mr_scan = func() {
		cmd := fmt.Sprintf("wlconf ra0 ugw scan > /tmp/wl_scan.log")
		_, err := RequestAC([]string{"request", apNode.AddrMac, "set", "exec_cmds", cmd})
		if err != nil {
			log.Println("mr_scan", err)
		}
	}

	if apNode.HW == "MR" {
		mr_scan()
	} else {
		brcm_scan()
	}
	res, err := apNode.FetchFile("/tmp/wl_scan.log", "")
	if err != nil {
		log.Println("fetch result:", err)
		return apNode.ScanCache
	}
	apNode.ScanCache = ParseScanResults(res, apNode.ScanCache)

	return apNode.ScanCache
}

func (apNode *APNodeSt) Scan() []*APScanSt {
	apNode.ScanCache = make([]*APScanSt, 0) //cleanup

	var start_scan = func(ifname string) {
		cmd := fmt.Sprintf("acs_cli -i %s csscan && acs_cli -i %s dump scanres &", ifname, ifname)
		_, err := RequestAC([]string{"request", apNode.AddrMac, "set", "exec_cmds", cmd})
		if err != nil {
			log.Println(err)
		}
	}

	go start_scan("eth1")
	time.Sleep(time.Second * 5) //wait sacn finished.
	res, err := apNode.FetchFile("/tmp/wlscan.log", "rm /tmp/wlscan.log")
	if err != nil {
		log.Println(err)
		return apNode.ScanCache
	}
	apNode.ScanCache = ParseScanResults(res, apNode.ScanCache)

	if apNode.IsDBand {
		go start_scan("eth2")
		time.Sleep(time.Second * 5) //wait sacn finished.
		res, err = apNode.FetchFile("/tmp/wlscan.log", "")
		if err != nil {
			log.Println(err)
		}
		apNode.ScanCache = ParseScanResults(res, apNode.ScanCache)
	}

	return apNode.ScanCache
}

func (apNode *APNodeSt) ResetChannel() {

	var exec = func() {
		cmd := []string{"request", apNode.AddrMac, "set", "exec_cmds", "acs_cli autochannel &"}
		if apNode.HW == "MR" {
			cmd = []string{"request", apNode.AddrMac, "set", "exec_cmds", "iwpriv ra0 set AutoChannelSel=2"}
		}
		_, err := RequestAC(cmd)
		if err != nil {
			log.Println(err)
		}
	}
	go exec()

	time.Sleep(time.Second * 5)
}

func (apNode *APNodeSt) RecalcTxPwr() {
	time.Sleep(time.Second)
}

func (apm *APConfig) Scan(aps []string) {

	for _, apId := range aps {
		apNode, ok := apm.APs[apId]
		if !ok || apNode == nil {
			continue
		}
		apNode.Scan()
	}

}

//acs_cli autochannel
func (apm *APConfig) ResetChannel(aps []string) []string {
	res := make([]string, 0)
	for _, apId := range aps {
		apNode, ok := apm.APs[apId]
		if !ok || apNode == nil {
			continue
		}
		apNode.ResetChannel()
		apm.ApmUpdateBasicAP(apNode.AddrMac, 0, true)
		res = append(res, apNode.ChannelId)
	}

	return res
}

func (apm *APConfig) RecalcTxPwr(aps []string) []string {
	res := make([]string, 0)
	for _, apId := range aps {
		apNode, ok := apm.APs[apId]
		if !ok || apNode == nil {
			continue
		}
		apNode.RecalcTxPwr()
		apm.ApmUpdateBasicAP(apNode.AddrMac, 0, true)
		res = append(res, apNode.TxPwrInfo)
	}

	return res
}

func (apm *APConfig) ApmListAddrs() (brds []string) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return
	}
	for _, addr := range addrs {
		if addr.String() == "0.0.0.0" || addr.String() == "255.255.255.255" {
			continue
		}
		brds = append(brds, addr.String())
	}

	return
}
