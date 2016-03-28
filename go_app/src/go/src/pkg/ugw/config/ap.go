package config

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"
	"unicode/utf8"
)

type APScanSt struct {
	ScanVals map[string]string
}

type APNodeSt struct {
	Enable     bool
	NeedCommit bool

	VerConf string
	VerFirw string

	AddrMac  string
	HW       string //硬件类型
	HwEnable bool   //支持该硬件类型?

	//basic
	NameDisplay string //显示名
	AddrIp      string
	ChannelId   string //当前信道ID
	TxPwrInfo   string //当前功率信息
	StaNum      string //记录终端数
	AssocNum    string //关联终端数
	Status      string //0:离线, 1:在线, 2:升级中(可能不在线)

	//关闭射频 频段
	IsDBand        bool
	DisableRadio2G bool //wl0, wl1 (5G,2.4G)
	DisableRadio5G bool

	Channel2G string
	Channel5G string

	TxPwr2G string
	TxPwr5G string

	VlanIndex int8 //0-15

	//console vals
	NVRamValsAP map[string]string

	SSIDs [4]string //被配置的SSID, 最多支持4个

	ScanCache []*APScanSt //信道扫描结果缓存.

	LogRuntime string
}

type APUserSt struct {
	AddrMac string
	AddrIp  string
	SSID    string //接入点的SSID
	APMac   string
	Status  string

	StaVals map[string]string //AP返回的查询参数表
}

type SSIDNodeSt struct {
	Enable bool

	SSID     string
	Encrypt  string //none, wpa2-psk, wpa-psk, wpa2-mix
	Password string
	Hide     bool

	VlanEnable bool
	VlanID     string
}

type Mac2IpSt struct {
	Timestamp int64
	IPAddr    string
}

type APConfig struct {
	VerAcConf      string
	VerAcFirw      string
	ConfAcAddr     string //强制广播的AC地址.
	ConfBrdAddrs   []string
	Messages       string
	EnableFireware string //初始0, 禁止1, 允许2, 检测版本更新3.
	EnableAPs      map[string]string

	Users map[string]*APUserSt
	APs   map[string]*APNodeSt
	SSIDs map[string]*SSIDNodeSt

	Mac2IPs map[string]*Mac2IpSt

	NumAPsLimits int //可管理的AP数限制
	NumAPsOnline int //当前在线数

	NumUsrsLimits int //最多缓存用户数
}

//AP上线, 回写配置时不要覆盖/删除的字段
var G_nv_reseved map[string]string = map[string]string{
	"HW":         "",
	"ac_ipaddr":  "",
	"ac_current": "",
	"sta_limits": "",
}

//AP多选编辑的公共字段
var G_nv_comm map[string]string = map[string]string{
	"lan_dhcp":        "",
	"lan_gateway":     "",
	"ac_ipaddr":       "",
	"sta_limits":      "",
	"telnet_enable":   "",
	"sys_led_enable":  "",
	"rssi_disabled":   "",
	"rssi_threshold":  "",
	"rssi_check_intv": "",
	"wl_nbw_cap":      "",
	"wl_obss_coex":    "",
	"wl0_txpwr":       "",
	"wl1_txpwr":       "",
	"ap_standalone":   "",
}

/* 回显时,取回的配置列表 */
var g_nv_comm_writeback []string = []string{
	"nick_name",
	"lan_dhcp",
	"lan_ipaddr",
	"lan_netmask",
	"lan_gateway",
	"ac_ipaddr",
	"ac_current",
	"sta_limits",
	"telnet_enable",
	"sys_led_enable",
	"ap_standalone",
	"rssi_disabled",
	"rssi_threshold",
	"rssi_check_intv",
	"wl_channel",
	"wl_nbw_cap",
	"wl_obss_coex",
	"wl0_txpwr",
	"wl1_txpwr",
	"ap_alert",
}
var g_nv_wr_writeback []string = []string{
	"wl0_channel",
	"wl1_channel",
	"wl0_hwaddr",
	"wl0.1_hwaddr",
	"wl0.2_hwaddr",
	"wl0.3_hwaddr",
	"wl1_hwaddr",
	"wl1.1_hwaddr",
	"wl1.2_hwaddr",
	"wl1.3_hwaddr",
	"wl0_ssid",
	"wl0.1_ssid",
	"wl0.2_ssid",
	"wl0.3_ssid",
	"http_encrypted",
}
var g_nv_mr_writeback []string = []string{
	"BssidNum",
	"SSID1",
	"SSID2",
	"SSID3",
	"SSID4",
}

func (apm *APConfig) ApmInitStruct() {
	if apm.APs == nil {
		apm.APs = make(map[string]*APNodeSt, 0)
	}

	if apm.Users == nil {
		apm.Users = make(map[string]*APUserSt, 0)
	}

	if apm.SSIDs == nil {
		apm.SSIDs = make(map[string]*SSIDNodeSt, 0)
	}

	if apm.Mac2IPs == nil {
		apm.Mac2IPs = make(map[string]*Mac2IpSt, 0)
	}

	if apm.EnableFireware == "" {
		apm.EnableFireware = "3"
	}

	if apm.NumUsrsLimits == 0 {
		apm.NumUsrsLimits = 100
	}

	if apm.EnableAPs == nil || len(apm.EnableAPs) == 0 {
		ens := make(map[string]string, 0)
		ens["WR10."] = "1"
		ens["WR15."] = "1"
		ens["WR30."] = "1"
		ens["WR40."] = "1"
		ens["WR45."] = "1"
		ens["WR65."] = "1"
		ens["WR75."] = "1"
		ens["WR131"] = "1"

		ens["CA115"] = "1" //15
		ens["CA155"] = "1" //85
		ens["CA130"] = "1" //40
		ens["CA131"] = "1" //45
		ens["CA135"] = "1" //131
		//ens["LG-A2"] = "1"
		apm.EnableAPs = ens
	}
}

func (apm *APConfig) ApmListAPs() *APConfig {
	apm.ApmInitStruct()
	apm.NumAPsOnline = 0

	sIDs, err := RequestAC([]string{"list"})
	if err != nil {
		log.Println("ApmListAPs list failed,", err)
		return nil
	}

	for mac, node := range apm.APs {
		if node == nil {
			//cleanup current apm
			delete(apm.APs, mac)
		} else if node.Status == "" || node.Status == "1" {
			node.Status = "0" //default offline. 升级中不处理
		}
	}

	if sIDs != "" {
		aIDs := strings.Split(sIDs, " ")
		log.Printf("Resov [%d] apm from list command\n", len(aIDs))
		for i := 0; i < len(aIDs); i++ {
			apMac := aIDs[i]
			if len(apMac) < 11 {
				continue
			}
			//add counter.
			apm.NumAPsOnline++
			if apm.NumAPsOnline <= apm.NumAPsLimits {
				err = apm.ApmUpdateBasicAP(apMac, 0, true)
				if err != nil {
					log.Printf("Build Basic AP[%s] info failed.\n", apMac)
				} else {
					//log.Printf("build basic apm[%s] writeback.\n", apMac)
				}
			} else {
				//超出部分怎么处理?
				log.Printf("AP[%s] can't updated over limited.\n", apMac)
			}
		}
	}

	var res bool
	go Eval(fmt.Sprintf("AP.NumAPsOnline.set(%d)", apm.NumAPsOnline), &res)
	return apm
}

func (apNode *APNodeSt) updateMapVals(sVals string, delEmpty bool, learn_rev bool) (updated bool) {
	updated = false
	newVals := make(map[string]string, 0)

	//拷贝全部 字段
	aVals := strings.Split(sVals, "\n")
	for i := 0; i < len(aVals); i++ {
		field := strings.Split(aVals[i], "=")
		if len(field) > 0 && len(field[0]) > 0 {
			key := field[0]
			if learn_rev {
				G_nv_reseved[key] = ""
			}
			prev, ok := apNode.NVRamValsAP[key]
			if ok && len(field) > 1 {
				//之前有这个字段,值不一样了.
				if prev != field[1] {
					updated = true
					log.Printf("\tupdate Nvram[%s][(%s) -> (%s)]\n", key, prev, field[1])
				}
			} else {
				//新插入字段
				updated = true
				if len(field) > 1 {
					log.Printf("\tnew nvram[%s][%s]\n", key, field[1])
				} else {
					log.Printf("\tnew nvram[%s][%s]\n", key, "null")
				}
			}
			//debug
			if !utf8.ValidString(field[1]) {
				fmt.Printf("Valid Utf8 string[%s]\n", field[1])
				continue
			}

			if len(field) > 1 {
				apNode.NVRamValsAP[key] = field[1]
				newVals[key] = field[1]
			} else if key != "" {
				apNode.NVRamValsAP[key] = ""
				newVals[key] = ""
			}
		}
	}
	//去掉不存在的字段
	for key, _ := range apNode.NVRamValsAP {
		_, ok := newVals[key]
		if !ok {
			//remove
			if delEmpty {
				_, ok := G_nv_reseved[key]
				if ok {
					continue
				}
				//删除不存在的字段
				log.Printf("\tremove key[%s][%s]\n", key, apNode.NVRamValsAP[key])
				updated = true
				delete(apNode.NVRamValsAP, key)
			}
		}
	}
	return updated
}

func (apNode *APNodeSt) BasicToHw() {
	ver := apNode.NVRamValsAP["ugw_version"]
	if strings.Contains(ver, "MR") {
		apNode.HW = "MR"
	} else {
		apNode.HW = "WR"
	}
}

func VerToHw(ver uint16) (hw string) {
	hw = "WR"
	switch ver {
	case 0, 1:
	case 2:
		hw = "MR"
	default:
		log.Printf("VerToHw error, unknown ver info: %d\n", ver)
	}
	return hw
}

func IdToHw(id string) (hw string) {
	hw = ""
	if strings.Contains(id, "76:20") {
		hw = "MR"
	}
	return
}

func (apm *APConfig) ApmUpdateBasicAP(id string, ver uint16, force bool) error {

	changed := false
	node := apm.APs[id]
	if node == nil {
		force = false //新节点,强制取回其它信息
		node = &APNodeSt{}
		//init vals
		node.AddrMac = id
		if ver != 0 {
			node.HW = VerToHw(ver)
		} else {
			node.HW = IdToHw(id)
		}
		node.NeedCommit = false
		node.Channel2G = "0"
		node.Channel5G = "0"
		node.TxPwr2G = "-1"
		node.TxPwr5G = "-1"
		node.NVRamValsAP = make(map[string]string, 0)
		node.NVRamValsAP["ac_ipaddr"] = ""
		node.NVRamValsAP["sta_limits"] = "0"
		apm.APs[id] = node //writeback
		log.Printf("[%s][%s] created.\n", id, node.HW)
	}
	//后续上线事件, 强制改回HW类型.
	if ver != 0 {
		node.HW = VerToHw(ver)
	}

	//更新配置和信息字段.
	if !force {
		//aleady inserted
		prev_len := len(node.NVRamValsAP)
		changed = node.UpdateFullNvram()
		//if changed {}
		log.Printf("fullnv node[%s] nv_len[%d:%d] updated[%v].\n",
			node.AddrMac, prev_len, len(node.NVRamValsAP), changed)
	} else {
		//force basic
		sBasic, err := RequestAC([]string{"request", id, "get", "basic"})
		if err != nil {
			return fmt.Errorf("req basic apm failed", err)
		}
		//resolve vals, upate basic, 不移除AP端已删除的字段
		changed = node.updateMapVals(sBasic, false, true)
		//if changed {}
		log.Printf("basic node[%s] updated[%v]\n", id, changed)
	}

	//更新页面显示
	node.AddrIp = node.NVRamValsAP["ipaddr"]
	node.NameDisplay = node.NVRamValsAP["nick_name"]
	node.VerFirw = node.NVRamValsAP["os_version"]

	ugw_version := node.NVRamValsAP["ugw_version"]
	if ugw_version != "" {
		idx := strings.LastIndex(node.VerFirw, ".")
		idx2 := strings.LastIndex(ugw_version, "-")
		if idx > 0 && idx2 > 0 {
			node.VerFirw = node.VerFirw[0:idx+1] + ugw_version[idx2+1:]
		}
	}

	//再次尝试获取HW类型
	if node.HW == "" {
		node.BasicToHw()
	}

	//是否允许接入
	hw := node.GetHwType(5)
	if hw != "" {
		_, ok := apm.EnableAPs[hw]
		if ok {
			node.HwEnable = true
		} else {
			log.Printf("AP[%s][%s] hw not be allowed.\n", id, node.VerFirw)
			// node.HwEnable = false
			// node.Status = "9"
			// return nil
			node.HwEnable = true
		}
	}

	if node.IsDBand {
		node.ChannelId = node.NVRamValsAP["wl1_channel"] + " " + node.NVRamValsAP["wl0_channel"]
		node.TxPwrInfo = node.NVRamValsAP["wl1_txpwr_cur"] + " " + node.NVRamValsAP["wl0_txpwr_cur"]
	} else {
		node.ChannelId = node.NVRamValsAP["wl0_channel"]
		node.TxPwrInfo = node.NVRamValsAP["wl0_txpwr_cur"]
	}
	node.StaNum = node.NVRamValsAP["auth_count"]
	node.AssocNum = node.NVRamValsAP["assoc_num"]
	if node.IsDBand {
		node.StaNum = node.NVRamValsAP["auth_count1"] + " " + node.StaNum
		node.AssocNum = node.NVRamValsAP["assoc_num1"] + " " + node.AssocNum
	}

	if node.Status == "0" || node.Status == "" || node.VerFirw == apm.VerAcFirw {
		//升级完成
		node.Status = "1" //上线
	}

	if node.NVRamValsAP["ac_ipaddr"] == "" {
		node.NVRamValsAP["ac_ipaddr"] = node.NVRamValsAP["ac_current"]
	}

	return nil
}

func (apNode *APNodeSt) ConfSync() {
	if apNode.HW == "MR" {
		//MTK ssid restore
		var BssidNum int
		fmt.Sscanf(apNode.NVRamValsAP["BssidNum"], "%d", &BssidNum)
		if BssidNum > 0 {
			for i := 1; i <= BssidNum && i <= 4; i++ {
				ssid := apNode.NVRamValsAP[fmt.Sprintf("SSID%d", i)]
				if ssid != apNode.SSIDs[i-1] {
					log.Printf("ConfSync update ssid: [%s]->[%s]\n", apNode.SSIDs[i-1], ssid)
				}
				apNode.SSIDs[i-1] = ssid
			}
		}
	} else {
		ssid := apNode.NVRamValsAP["wl0_ssid"]
		if ssid != "" {
			apNode.SSIDs[0] = ssid
		}
		for i := 1; i <= 3; i++ {
			ssid := apNode.NVRamValsAP[fmt.Sprintf("wl0.%d_ssid", i)]
			if ssid != apNode.SSIDs[i] {
				log.Printf("ConfSync update ssid: [%s]-->[%s]\n", apNode.SSIDs[i], ssid)
			}
			apNode.SSIDs[i] = ssid
		}
	}
}

func (apNode *APNodeSt) UpdateFullNvram() (changed bool) {
	sNvWb := "lst=\n"
	for _, key := range g_nv_comm_writeback {
		sNvWb += key + "\n"
	}
	if apNode.HW == "MR" {
		for _, key := range g_nv_mr_writeback {
			sNvWb += key + "\n"
		}
	} else {
		for _, key := range g_nv_wr_writeback {
			sNvWb += key + "\n"
		}
	}

	sVals, err := RequestAC([]string{"request", apNode.AddrMac, "set", "nvram", sNvWb})
	if err != nil {
		msg := fmt.Sprintf("UpdateFullNvram: %v", err)
		log.Println(msg)
		return false
	}

	//log.Printf("[%s]\n\n", sVals)

	//去掉AP端不存在的字段? 调试模式先保留
	changed = apNode.updateMapVals(sVals, true, false)

	//同步AP上的配置和AC上的配置
	apNode.ConfSync()

	return changed
}

func (apNode *APNodeSt) UnsetNvram(keys []string) bool {
	sUnset := ""
	//unset del keys
	for _, key := range keys {
		sUnset += key + "=\n"
	}

	//unset
	if sUnset != "" {
		_, err := RequestAC([]string{"request", apNode.AddrMac, "set", "unset", sUnset})
		if err != nil {
			log.Printf("UnsetNvram failed[%s]\n", sUnset)
			return false
		}
	}

	return true
}

func (apNode *APNodeSt) WriteNvramBack2Ap(newAP *APNodeSt, force bool, mult bool) (changed bool) {
	sReq := ""
	changed = false

	//遍历新的AP配置项
	for key, val := range newAP.NVRamValsAP {
		_, ok := G_nv_comm[key]
		if mult && !ok {
			//多项编辑,且非公共项
			continue
		}
		//单独编辑, force:表示新建字段强制写入
		oVal, ok := apNode.NVRamValsAP[key]
		if !ok || val != oVal || force {
			sReq += key + "=" + val + "\n"
			//debug
			if val != oVal {
				log.Printf("OnAPs[%s] update[%s:(%s)->(%s)]\n", apNode.AddrMac, key, oVal, val)
			}
		}
	}

	//exec update
	if sReq != "" {
		//need update
		sRep, err := RequestAC([]string{"request", apNode.AddrMac, "set", "nvram", "set=\n" + sReq})
		if err != nil {
			log.Printf("NvWrBack2Ap set failed[%v]\n", err)
			return
		}

		//回显AP上的配置项
		changed = apNode.updateMapVals(sRep, false, false)
		if changed {
			log.Printf("NvWrBack2Ap set update map[%d], changed[%v]\n", len(apNode.NVRamValsAP), changed)
		}

		//log.Printf("NvWrBack2Ap set rep[%s]\n", sRep)
	}
	return
}

func (apNode *APNodeSt) UpdateWlConfig(unit int, index int, ssid *SSIDNodeSt) {

	sUnit := ""
	prefix := "wl"
	if index == 0 {
		//eth1,eth2
		sUnit = fmt.Sprintf("%d", unit)
	} else {
		//wl0.1, wl1.1
		sUnit = fmt.Sprintf("%d.%d", unit, index)
	}
	prefix += sUnit

	if index == 0 {
		//wl0/1_ 主接口配置(射频方面的配置)
		if apNode.IsDBand {
			//双频
			if unit == 0 {
				//5G
				apNode.NVRamValsAP[prefix+"_ifname"] = "eth1"
				apNode.NVRamValsAP[prefix+"_channel"] = apNode.Channel5G
				apNode.NVRamValsAP[prefix+"_chanspec"] = apNode.Channel5G //新版SDK, 这个字段变了
				apNode.NVRamValsAP[prefix+"_txpwr"] = apNode.TxPwr5G
			} else {
				//2.4G
				apNode.NVRamValsAP[prefix+"_ifname"] = "eth2"
				apNode.NVRamValsAP[prefix+"_channel"] = apNode.Channel2G
				apNode.NVRamValsAP[prefix+"_chanspec"] = apNode.Channel2G
				apNode.NVRamValsAP[prefix+"_txpwr"] = apNode.TxPwr2G
			}
			//射频开关
			if (unit == 0 && apNode.DisableRadio5G) || (unit == 1 && apNode.DisableRadio2G) {
				//eth1/2, 双频, 5G关闭/2.4G关闭
				apNode.NVRamValsAP[prefix+"_radio"] = "0"
			} else {
				apNode.NVRamValsAP[prefix+"_radio"] = "1"
			}
		} else {
			//单频2.4G
			apNode.NVRamValsAP[prefix+"_ifname"] = "eth1"
			apNode.NVRamValsAP[prefix+"_channel"] = apNode.Channel2G
			apNode.NVRamValsAP[prefix+"_chanspec"] = apNode.Channel2G
			apNode.NVRamValsAP[prefix+"_txpwr"] = apNode.TxPwr2G
			//射频开关
			if apNode.DisableRadio2G {
				apNode.NVRamValsAP[prefix+"_radio"] = "0"
			} else {
				apNode.NVRamValsAP[prefix+"_radio"] = "1"
			}
		}

		//20M/40M, 全局开关
		apNode.NVRamValsAP[prefix+"_nbw_cap"] = apNode.NVRamValsAP["wl_nbw_cap"]
		//6.0SDK,这个字段改成了 bw_cap
		apNode.NVRamValsAP[prefix+"_bw_cap"] = apNode.NVRamValsAP["wl_nbw_cap"]
		//混合模式,
		apNode.NVRamValsAP[prefix+"_obss_coex"] = apNode.NVRamValsAP["wl_obss_coex"]
		//后续增加海外版本
		apNode.NVRamValsAP[prefix+"_country_code"] = "CN"
		//省电模式
		apNode.NVRamValsAP[prefix+"_wme_apsd"] = "off"
	} else {
		//虚拟BSS接口
		apNode.NVRamValsAP[prefix+"_ifname"] = prefix
		//兼容之前的版本,防止eap认证判断BUG, 这里虚拟接口radio强制开启(实际上依赖wl主接口的开启/关闭)
		apNode.NVRamValsAP[prefix+"_radio"] = "1"
	}

	//虚拟接口和主接口共享配置(SSID和认证)
	if ssid != nil {
		apNode.NVRamValsAP[prefix+"_ssid"] = ssid.SSID
		apNode.NVRamValsAP[prefix+"_akm"] = ssid.Encrypt
		apNode.NVRamValsAP[prefix+"_wpa_psk"] = ssid.Password
		apNode.NVRamValsAP[prefix+"_bss_enabled"] = "1"
		if ssid.Hide {
			apNode.NVRamValsAP[prefix+"_closed"] = "1"
		} else {
			apNode.NVRamValsAP[prefix+"_closed"] = "0"
		}
		apNode.NVRamValsAP[prefix+"_wme"] = "on"
		//VLAN eth ifname
		if ssid.VlanEnable {
			apNode.NVRamValsAP[fmt.Sprintf("%shwname", fmt.Sprintf("vlan%d", apNode.VlanIndex))] = "br0"
			apNode.NVRamValsAP["eth0macaddr"] = apNode.NVRamValsAP["et0macaddr"]
		}
	} else {
		//cleanup
		apNode.NVRamValsAP[prefix+"_ssid"] = ""
		apNode.NVRamValsAP[prefix+"_akm"] = ""
		apNode.NVRamValsAP[prefix+"_wpa_psk"] = ""
		apNode.NVRamValsAP[prefix+"_bss_enabled"] = "0"
		apNode.NVRamValsAP[prefix+"_closed"] = "0"
		apNode.NVRamValsAP[prefix+"_wme"] = ""
		apNode.NVRamValsAP[prefix+"_vlan"] = ""
	}
	//工作模式
	apNode.NVRamValsAP[prefix+"_mode"] = "ap"

	//SEC
	apNode.NVRamValsAP[prefix+"_auth"] = "0"
	apNode.NVRamValsAP[prefix+"_auth_mode"] = "none"
	apNode.NVRamValsAP[prefix+"_ap_isolate"] = "0" //默认不开隔离
	apNode.NVRamValsAP[prefix+"_key"] = "2"
	apNode.NVRamValsAP[prefix+"_key1"] = ""
	apNode.NVRamValsAP[prefix+"_key2"] = ""
	apNode.NVRamValsAP[prefix+"_key3"] = ""
	apNode.NVRamValsAP[prefix+"_key4"] = ""
	apNode.NVRamValsAP[prefix+"_maclist"] = ""
	apNode.NVRamValsAP[prefix+"_macmode"] = "disabled"
	apNode.NVRamValsAP[prefix+"_radius_ipaddr"] = ""
	apNode.NVRamValsAP[prefix+"_radius_key"] = ""
	apNode.NVRamValsAP[prefix+"_radius_port"] = "1812"
	apNode.NVRamValsAP[prefix+"_unit"] = sUnit
	apNode.NVRamValsAP[prefix+"_wep"] = "disabled"
	apNode.NVRamValsAP[prefix+"_wme_bss_disable"] = "0"
	apNode.NVRamValsAP[prefix+"_wpa_gtk_rekey"] = "0"
	apNode.NVRamValsAP[prefix+"_crypto"] = "tkip+aes"
	apNode.NVRamValsAP[prefix+"_sta_retry_time"] = "5"
	if apNode.NVRamValsAP["sta_limits"] != "" {
		apNode.NVRamValsAP[prefix+"_maxassoc"] = apNode.NVRamValsAP["sta_limits"]
	} else {
		apNode.NVRamValsAP[prefix+"_maxassoc"] = "80"
	}
}

func (apNode *APNodeSt) TranslateWlSSID(index int, oSSID *SSIDNodeSt) bool {

	if oSSID != nil {
		log.Printf("\tSSID[%v] Translate[index:%d, ssid:%s, encryt:%s, pwd:%s]\n",
			apNode.IsDBand, index, oSSID.SSID, oSSID.Encrypt, oSSID.Password)
	} else {
		log.Printf("\tSSID cleanup[index:%d]\n", index)
	}

	//wl default ssid
	//if index == 0 {
	//	UpdateWlConfig("wl", index, nvram, oSSID)
	//}

	//wl0 & wl0.x
	apNode.UpdateWlConfig(0, index, oSSID)
	//wl1 & wl1.x
	if apNode.IsDBand {
		apNode.UpdateWlConfig(1, index, oSSID)
	}
	return true
}

func (apNode *APNodeSt) GetHwType(n int) (hw_ver string) {
	if len(apNode.VerFirw) > n {
		hw_ver = string(apNode.VerFirw[0:n])
		if hw_ver == "WR48." {
			hw_ver = "WR45." //鑫嘉定制版本48其实是45
		}
	}
	return
}

func (apNode *APNodeSt) BuildSSIDRefWR(SsidContainer map[string]*SSIDNodeSt) bool {
	//1.读取AP的SSID引用, 并跟新配置文件
	sMac := apNode.AddrMac
	log.Printf("Reserve ap[%s][%s] status:%s, ssids[%v]\n", apNode.NameDisplay, sMac, apNode.Status, apNode.SSIDs)

	//Build SSID & lan/wan/bridge interface
	//check VER string
	HwType := apNode.GetHwType(5)
	if HwType == "" {
		log.Printf("Build SSID for[%s] ver unknown.\n", apNode.NameDisplay)
		return false
	}

	//目前只有75AP是双频的.
	apNode.IsDBand = false

	if HwType == "WR75." || HwType == "WR85." || HwType == "CA155" {

		apNode.IsDBand = true
	}
	//cleanup: FIXME: unset all vlan%dhwname, for no vlan config
	for i := 1; i < 5; i++ {
		apNode.NVRamValsAP[fmt.Sprintf("lan%d_ifname", i)] = ""
		apNode.NVRamValsAP[fmt.Sprintf("lan%d_ifnames", i)] = ""
	}

	//wl vitual interface list.
	wl0_vifs := ""
	wl1_vifs := ""

	//bridge ifnames
	ifindex := 0
	brIndex := 1
	brNoVlan := "vlan1"
	if HwType == "WR45." {
		brNoVlan = "eth0"
		apNode.VlanIndex = 1 //每一个vlan, index++
	}
	//build ssid nvram
	for index, sSSID := range apNode.SSIDs {
		if sSSID != "" {
			log.Printf("\tReserve ssid[%s]\n", sSSID)
			oSSID, ok := SsidContainer[sSSID]
			if !ok || oSSID == nil {
				continue
			}
			//未启用
			if !oSSID.Enable {
				//停用该SSID
				apNode.TranslateWlSSID(index, nil)
				continue
			}
			var compSSID = *oSSID
			//转换成30AP,45AP,131AP兼容的配置.
			if compSSID.VlanEnable && (HwType != "WR45.") {
				//只有45AP才支持VLAN.
				compSSID.VlanEnable = false
				log.Printf("This AP[%s:%s] can't use vlan.\n", apNode.AddrMac, apNode.VerFirw)
			}

			//转换配置文件内容
			apNode.TranslateWlSSID(ifindex, &compSSID)
			if ifindex != 0 {
				wl0_vifs += fmt.Sprintf("wl0.%d ", ifindex) //5G
				if apNode.IsDBand {
					wl1_vifs += fmt.Sprintf("wl1.%d ", ifindex) //2.4G
				}
			}
			//VLAN
			if compSSID.VlanEnable {
				//only 45AP go here...
				apNode.NVRamValsAP[fmt.Sprintf("lan%d_ifname", brIndex)] = fmt.Sprintf("br%d", brIndex)
				if ifindex != 0 {
					apNode.NVRamValsAP[fmt.Sprintf("lan%d_ifnames", brIndex)] =
						fmt.Sprintf("wl0.%d", ifindex) + fmt.Sprintf(" vlan%s", compSSID.VlanID)
				} else {
					apNode.NVRamValsAP[fmt.Sprintf("lan%d_ifnames", brIndex)] =
						"eth1" + fmt.Sprintf(" vlan%s", compSSID.VlanID)
				}
				apNode.NVRamValsAP[fmt.Sprintf("vlan%d_tag", apNode.VlanIndex)] = compSSID.VlanID
				apNode.NVRamValsAP[fmt.Sprintf("lan%d_dhcp", brIndex)] = "1" //自动获取IP地址
				apNode.NVRamValsAP[fmt.Sprintf("lan%d_stp", brIndex)] = "0"  //默认关闭STP
				//VLAN从br1开始
				brIndex++
				apNode.VlanIndex++
			} else {
				//add to br0
				if ifindex != 0 {
					brNoVlan += fmt.Sprintf(" wl0.%d", ifindex) //5G
					if apNode.IsDBand {
						brNoVlan += fmt.Sprintf(" wl1.%d", ifindex) //2.4G
					}
				} else {
					brNoVlan += " eth1" //5G
					if apNode.IsDBand {
						brNoVlan += " eth2" //2.4G
					}
				}
			}
			//next
			ifindex++
		} else {
			//删除该SSID配置参数
			apNode.TranslateWlSSID(index, nil)
		}
	}

	acs_ifnames := ""
	if apNode.IsDBand {
		if apNode.Channel5G == "0" {
			acs_ifnames += "eth1"
		}
		if apNode.Channel2G == "0" {
			acs_ifnames += "eth2"
		}

	} else {
		if apNode.Channel2G == "0" {
			acs_ifnames += "eth1"
		}
	}
	//br0 NO vlan interface use only
	apNode.NVRamValsAP["lan_ifname"] = "br0"
	apNode.NVRamValsAP["lan_ifnames"] = brNoVlan
	apNode.NVRamValsAP["acs_ifnames"] = acs_ifnames

	//bssid 虚拟接口
	apNode.NVRamValsAP["wl0_vifs"] = wl0_vifs
	apNode.NVRamValsAP["wl1_vifs"] = wl1_vifs

	log.Printf("Finished ssid ref[%s-%s]\n", apNode.NameDisplay, apNode.AddrMac)
	return true
}

func (apNode *APNodeSt) TranslateMrSSID(index int, oSSID *SSIDNodeSt) bool {
	if oSSID != nil {
		apNode.NVRamValsAP[fmt.Sprintf("SSID%d", index+1)] = oSSID.SSID
		apNode.NVRamValsAP[fmt.Sprintf("WPAPSK%d", index+1)] = oSSID.Password

		keyid := "1"
		enpt := "NONE"
		auth := "OPEN"
		rekey := "DISABLE"
		if oSSID.Encrypt == "psk" {
			keyid = "2"
			enpt = "TKIPAES"
			auth = "WPAPSKWPA2PSK"
			rekey = "TIME"
		} else if oSSID.Encrypt == "psk2" {
			keyid = "2"
			enpt = "TKIPAES"
			auth = "WPA2PSK"
			rekey = "TIME"
		} else {
			//default open,none,1
		}
		//hide
		hide := "0"
		if oSSID.Hide {
			hide = "1"
		}

		apNode.NVRamValsAP["AuthMode"] += auth + ";"
		apNode.NVRamValsAP["EncrypType"] += enpt + ";"
		apNode.NVRamValsAP["DefaultKeyID"] += keyid + ";"
		apNode.NVRamValsAP["RekeyMethod"] += rekey + ";"
		apNode.NVRamValsAP["HideSSID"] += hide + ";"

		apNode.NVRamValsAP["TxRate"] += "1;"
		apNode.NVRamValsAP["WmmCapable"] += "1;"
	} else {
		apNode.NVRamValsAP[fmt.Sprintf("SSID%d", index+1)] = ""
	}

	return true
}

func (apNode *APNodeSt) BuildSSIDRefMR(SsidContainer map[string]*SSIDNodeSt) bool {
	//初始化
	apNode.NVRamValsAP["SSID"] = ""
	apNode.NVRamValsAP["TxRate"] = ""
	apNode.NVRamValsAP["WmmCapable"] = ""
	apNode.NVRamValsAP["AuthMode"] = ""
	apNode.NVRamValsAP["EncrypType"] = ""
	apNode.NVRamValsAP["DefaultKeyID"] = ""
	apNode.NVRamValsAP["RekeyMethod"] = ""
	//empty
	apNode.NVRamValsAP["WPAPSK"] = ""
	apNode.NVRamValsAP["Key1Str"] = ""
	apNode.NVRamValsAP["Key2Str"] = ""
	apNode.NVRamValsAP["Key3Str"] = ""
	apNode.NVRamValsAP["Key4Str"] = ""

	//遍历AP的SSID列表
	ifindex := 0
	for index, sSSID := range apNode.SSIDs {
		if sSSID == "" {
			//清空配置
			apNode.TranslateMrSSID(index, nil)
			continue
		}
		oSSID, ok := SsidContainer[sSSID]
		if !ok {
			//已经删除, 或未启用.
			log.Printf("error SSID[%s] not found.\n", sSSID)
			oSSID = &SSIDNodeSt{}
			oSSID.Hide = false
			oSSID.SSID = sSSID
			oSSID.Enable = true
			oSSID.VlanEnable = false
			oSSID.Encrypt = "none"
		}
		if !oSSID.Enable {
			log.Printf("SSID[%s] not enabled.\n", sSSID)
			apNode.TranslateMrSSID(index, nil)
			continue
		}
		//生成无线配置
		apNode.TranslateMrSSID(ifindex, oSSID)

		//无线网口下标.
		ifindex++
	}
	apNode.NVRamValsAP["AuthMode"] += "OPEN"
	apNode.NVRamValsAP["EncrypType"] += "NONE"

	//配置属性
	//radio
	if apNode.DisableRadio2G {
		apNode.NVRamValsAP["RadioOn"] = "0"
	} else {
		apNode.NVRamValsAP["RadioOn"] = "1"
	}

	//power
	if apNode.TxPwr2G != "-1" && apNode.TxPwr2G != "0" {
		apNode.NVRamValsAP["TxPower"] = apNode.TxPwr2G // xx%
	} else {
		apNode.NVRamValsAP["TxPower"] = "100"
	}

	if apNode.Channel2G != "0" {
		apNode.NVRamValsAP["AutoChannelSelect"] = "0"    //auto channel, 0,1,2 (Random, APCount, ACC)
		apNode.NVRamValsAP["Channel"] = apNode.Channel2G //"0"
	} else {
		apNode.NVRamValsAP["AutoChannelSelect"] = "2" //auto channel, 0,1,2 (Random, APCount, ACC)
		apNode.NVRamValsAP["Channel"] = "0"
	}

	MaxStaNum := apNode.NVRamValsAP["sta_limits"]
	if MaxStaNum != "" {
		apNode.NVRamValsAP["MaxStaNum"] = MaxStaNum
	} else {
		apNode.NVRamValsAP["MaxStaNum"] = "20"
	}

	apNode.NVRamValsAP["BssidNum"] = fmt.Sprintf("%d", ifindex)
	// apNode.NVRamValsAP["CountryCode"] = "HK" //TW,HK,US,JP
	apNode.NVRamValsAP["CountryRegion"] = "1"
	apNode.NVRamValsAP["CountryRegionABand"] = "5"

	//全局属性
	{
		// apNode.NVRamValsAP["WirelessMode"] = "9" //n, abgn, ac
		// apNode.NVRamValsAP["FixedTxMode"] = "HT" //FIXED_TXMODE_HT,CCK,OFDM:0-2
		// apNode.NVRamValsAP["BasicRate"] = "15"
		// apNode.NVRamValsAP["BeaconPeriod"] = "100"
		// apNode.NVRamValsAP["DtimPeriod"] = "1"
		// apNode.NVRamValsAP["HideSSID"] = "0;0;0" //hide
		// apNode.NVRamValsAP["NoForwarding"] = "0;0;0" //isolate
		// apNode.NVRamValsAP["NoForwardingBTNBSSID"] = "0"
		// apNode.NVRamValsAP["IEEE8021X"] = "0;0;0"

		// apNode.NVRamValsAP["DisableOLBC"] = "0"
		// apNode.NVRamValsAP["BGProtection"] = "0"
		// apNode.NVRamValsAP["TxAntenna"] = ""
		// apNode.NVRamValsAP["RxAntenna"] = ""
		// apNode.NVRamValsAP["TxPreamble"] = "0"
		// apNode.NVRamValsAP["RTSThreshold"] = "2347"
		// apNode.NVRamValsAP["FragThreshold"] = "2346"
		// apNode.NVRamValsAP["TxBurst"] = "0"
		// apNode.NVRamValsAP["PktAggregate"] = "1"
		// apNode.NVRamValsAP["AutoProvisionEn"] = "0"
		// apNode.NVRamValsAP["VideoTurbine"] = "0"
		// apNode.NVRamValsAP["FreqDelta"] = "0"
		// apNode.NVRamValsAP["TurboRate"] = "0"
		// apNode.NVRamValsAP["APAifsn"] = "3;7;1;1"
		// apNode.NVRamValsAP["APCwmin"] = "4;4;3;2"
		// apNode.NVRamValsAP["APCwmax"] = "6;10;4;3"
		// apNode.NVRamValsAP["APTxop"] = "0;0;94;47"
		// apNode.NVRamValsAP["APACM"] = "0;0;0;0"
		// apNode.NVRamValsAP["BSSAifsn"] = "3;7;2;2"
		// apNode.NVRamValsAP["BSSCwmin"] = "4;4;3;2"
		// apNode.NVRamValsAP["BSSCwmax"] = "10;10;4;3"
		// apNode.NVRamValsAP["BSSTxop"] = "0;0;94;47"
		// apNode.NVRamValsAP["BSSACM"] = "0;0;0;0"
		// apNode.NVRamValsAP["AckPolicy"] = "0;0;0;0"
		// apNode.NVRamValsAP["APSDCapable"] = "0"
		// apNode.NVRamValsAP["DLSCapable"] = "0"
		// apNode.NVRamValsAP["ShortSlot"] = "1"
		// apNode.NVRamValsAP["IEEE80211H"] = "0"
		// apNode.NVRamValsAP["CarrierDetect"] = "0"
		// apNode.NVRamValsAP["ITxBfEn"] = "0"
		// apNode.NVRamValsAP["PreAntSwitch"] = ""
		// apNode.NVRamValsAP["PhyRateLimit"] = "0"
		// apNode.NVRamValsAP["DebugFlags"] = "0"
		// apNode.NVRamValsAP["ETxBfEnCond"] = "0"
		// apNode.NVRamValsAP["ITxBfTimeout"] = "0"
		// apNode.NVRamValsAP["ETxBfTimeout"] = "0"
		// apNode.NVRamValsAP["ETxBfNoncompress"] = "0"
		// apNode.NVRamValsAP["ETxBfIncapable"] = "0"
		// apNode.NVRamValsAP["FineAGC"] = "0"
		// apNode.NVRamValsAP["StreamMode"] = "0"
		// apNode.NVRamValsAP["StreamModeMac0"] = ""
		// apNode.NVRamValsAP["StreamModeMac1"] = ""
		// apNode.NVRamValsAP["StreamModeMac2"] = ""
		// apNode.NVRamValsAP["StreamModeMac3"] = ""
		// apNode.NVRamValsAP["CSPeriod"] = "10"
		// apNode.NVRamValsAP["RDRegion"] = ""
		// apNode.NVRamValsAP["StationKeepAlive"] = "1"
		// apNode.NVRamValsAP["DfsLowerLimit"] = "0"
		// apNode.NVRamValsAP["DfsUpperLimit"] = "0"
		// apNode.NVRamValsAP["DfsOutdoor"] = "0"
		// apNode.NVRamValsAP["SymRoundFromCfg"] = "0"
		// apNode.NVRamValsAP["BusyIdleFromCfg"] = "0"
		// apNode.NVRamValsAP["DfsRssiHighFromCfg"] = "0"
		// apNode.NVRamValsAP["DfsRssiLowFromCfg"] = "0"
		// apNode.NVRamValsAP["DFSParamFromConfig"] = "0"
		// apNode.NVRamValsAP["FCCParamCh0"] = ""
		// apNode.NVRamValsAP["FCCParamCh1"] = ""
		// apNode.NVRamValsAP["FCCParamCh2"] = ""
		// apNode.NVRamValsAP["FCCParamCh3"] = ""
		// apNode.NVRamValsAP["CEParamCh0"] = ""
		// apNode.NVRamValsAP["CEParamCh1"] = ""
		// apNode.NVRamValsAP["CEParamCh2"] = ""
		// apNode.NVRamValsAP["CEParamCh3"] = ""
		// apNode.NVRamValsAP["JAPParamCh0"] = ""
		// apNode.NVRamValsAP["JAPParamCh1"] = ""
		// apNode.NVRamValsAP["JAPParamCh2"] = ""
		// apNode.NVRamValsAP["JAPParamCh3"] = ""
		// apNode.NVRamValsAP["JAPW53ParamCh0"] = ""
		// apNode.NVRamValsAP["JAPW53ParamCh1"] = ""
		// apNode.NVRamValsAP["JAPW53ParamCh2"] = ""
		// apNode.NVRamValsAP["JAPW53ParamCh3"] = ""
		// apNode.NVRamValsAP["FixDfsLimit"] = "0"
		// apNode.NVRamValsAP["LongPulseRadarTh"] = "0"
		// apNode.NVRamValsAP["AvgRssiReq"] = "0"
		// apNode.NVRamValsAP["DFS_R66"] = "0"
		// apNode.NVRamValsAP["BlockCh"] = ""
		// apNode.NVRamValsAP["GreenAP"] = "0"
		// apNode.NVRamValsAP["PreAuth"] = "0;0;0"
		// apNode.NVRamValsAP["WapiPsk1"] = ""
		// apNode.NVRamValsAP["WapiPsk2"] = ""
		// apNode.NVRamValsAP["WapiPsk3"] = ""
		// apNode.NVRamValsAP["WapiPsk4"] = ""
		// apNode.NVRamValsAP["WapiPsk5"] = ""
		// apNode.NVRamValsAP["WapiPsk6"] = ""
		// apNode.NVRamValsAP["WapiPsk7"] = ""
		// apNode.NVRamValsAP["WapiPsk8"] = ""
		// apNode.NVRamValsAP["WapiPskType"] = ""
		// apNode.NVRamValsAP["Wapiifname"] = ""
		// apNode.NVRamValsAP["WapiAsCertPath"] = ""
		// apNode.NVRamValsAP["WapiUserCertPath"] = ""
		// apNode.NVRamValsAP["WapiAsIpAddr"] = ""
		// apNode.NVRamValsAP["WapiAsPort"] = ""
		// apNode.NVRamValsAP["RekeyInterval"] = "4194303"
		// apNode.NVRamValsAP["PMKCachePeriod"] = "10"
		// apNode.NVRamValsAP["MeshAutoLink"] = "0"
		// apNode.NVRamValsAP["MeshAuthMode"] = ""
		// apNode.NVRamValsAP["MeshEncrypType"] = ""
		// apNode.NVRamValsAP["MeshDefaultkey"] = "0"
		// apNode.NVRamValsAP["MeshWEPKEY"] = ""
		// apNode.NVRamValsAP["MeshWPAKEY"] = ""
		// apNode.NVRamValsAP["MeshId"] = ""
		// apNode.NVRamValsAP["Key1Type"] = ""
		// apNode.NVRamValsAP["Key1Str1"] = ""
		// apNode.NVRamValsAP["Key1Str2"] = ""
		// apNode.NVRamValsAP["Key1Str3"] = ""
		// apNode.NVRamValsAP["Key1Str4"] = ""
		// apNode.NVRamValsAP["HSCounter"] = "0"
		// apNode.NVRamValsAP["HT_HTC"] = "1"
		// apNode.NVRamValsAP["HT_RDG"] = "1"
		// apNode.NVRamValsAP["HT_LinkAdapt"] = "0"
		// apNode.NVRamValsAP["HT_OpMode"] = "0"
		// apNode.NVRamValsAP["HT_MpduDensity"] = "5"
		// apNode.NVRamValsAP["HT_EXTCHA"] = "0"
		// apNode.NVRamValsAP["HT_BW"] = "0"
		// apNode.NVRamValsAP["VHT_BW"] = "0"
		// apNode.NVRamValsAP["HT_AutoBA"] = "0"
		// apNode.NVRamValsAP["HT_BADecline"] = "0"
		// apNode.NVRamValsAP["HT_AMSDU"] = "0"
		// apNode.NVRamValsAP["HT_BAWinSize"] = "64"
		// apNode.NVRamValsAP["HT_GI"] = "1"
		// apNode.NVRamValsAP["HT_STBC"] = "1"
		// apNode.NVRamValsAP["HT_MCS"] = "33;33;33"
		// apNode.NVRamValsAP["HT_TxStream"] = "2"
		// apNode.NVRamValsAP["HT_RxStream"] = "2"
		// apNode.NVRamValsAP["HT_PROTECT"] = "1"
		// apNode.NVRamValsAP["HT_DisallowTKIP"] = "1"
		// apNode.NVRamValsAP["HT_BSSCoexistence"] = "0"
		// apNode.NVRamValsAP["WscConfMode"] = ""
		// apNode.NVRamValsAP["WscConfStatus"] = "1"
		// apNode.NVRamValsAP["WscVendorPinCode"] = ""
		// apNode.NVRamValsAP["WCNTest"] = ""
		// apNode.NVRamValsAP["WSC_UUID_Str1"] = ""
		// apNode.NVRamValsAP["WSC_UUID_E1"] = ""
		// apNode.NVRamValsAP["AccessPolicy0"] = ""
		// apNode.NVRamValsAP["AccessControlList0"] = ""
		// apNode.NVRamValsAP["WdsEnable"] = "0"
		// apNode.NVRamValsAP["WdsPhyMode"] = ""
		// apNode.NVRamValsAP["WdsEncrypType"] = "NONE"
		// apNode.NVRamValsAP["WdsList"] = ""
		// apNode.NVRamValsAP["Wds0Key"] = ""
		// apNode.NVRamValsAP["Wds1Key"] = ""
		// apNode.NVRamValsAP["Wds2Key"] = ""
		// apNode.NVRamValsAP["Wds3Key"] = ""
		// apNode.NVRamValsAP["RADIUS_Server"] = ""
		// apNode.NVRamValsAP["RADIUS_Port"] = "1812"
		// apNode.NVRamValsAP["RADIUS_Key1"] = ""
		// apNode.NVRamValsAP["RADIUS_Acct_Server"] = ""
		// apNode.NVRamValsAP["RADIUS_Acct_Port"] = "1813"
		// apNode.NVRamValsAP["RADIUS_Acct_Key"] = ""
		// apNode.NVRamValsAP["own_ip_addr"] = ""
		// apNode.NVRamValsAP["Ethifname"] = ""
		// apNode.NVRamValsAP["EAPifname"] = ""
		// apNode.NVRamValsAP["PreAuthifname"] = ""
		// apNode.NVRamValsAP["session_timeout_interval"] = "0"
		// apNode.NVRamValsAP["idle_timeout_interval"] = "0"
		// apNode.NVRamValsAP["WiFiTest"] = "0"
		// apNode.NVRamValsAP["TGnWifiTest"] = "0"
		// apNode.NVRamValsAP["ApCliEnable"] = "0"
		// apNode.NVRamValsAP["ApCliSsid"] = ""
		// apNode.NVRamValsAP["ApCliBssid"] = ""
		// apNode.NVRamValsAP["ApCliAuthMode"] = ""
		// apNode.NVRamValsAP["ApCliEncrypType"] = ""
		// apNode.NVRamValsAP["ApCliWPAPSK"] = ""
		// apNode.NVRamValsAP["ApCliDefaultKeyID"] = "0"
		// apNode.NVRamValsAP["ApCliKey1Type"] = "0"
		// apNode.NVRamValsAP["ApCliKey1Str"] = ""
		// apNode.NVRamValsAP["EfuseBufferMode"] = ""
		// apNode.NVRamValsAP["E2pAccessMode"] = ""
	}
	return true
}

func (apNode *APNodeSt) BuildSSIDRefence(SsidContainer map[string]*SSIDNodeSt) bool {
	if !apNode.HwEnable {
		log.Printf("AP[%s][%s] not allowed.\n", apNode.AddrMac, apNode.VerFirw)
		return false
	}

	if apNode.HW != "MR" {
		return apNode.BuildSSIDRefWR(SsidContainer)
	} else {
		return apNode.BuildSSIDRefMR(SsidContainer)
	}
}

func (user *APUserSt) ParseUserInfo(aInfo []string) (res error) {
	for i := 0; i < len(aInfo); i++ {
		fields := strings.Split(aInfo[i], "=")
		if len(fields) > 0 && fields[0] != "" {
			//log.Printf("User[%s]\n", aInfo[i])
			if len(fields) > 1 {
				user.StaVals[fields[0]] = fields[1]
			} else {
				user.StaVals[fields[0]] = "-"
			}
		}
	}
	//check idle time
	idle := 0
	fmt.Sscanf(user.StaVals["idle"], "%d", &idle)
	if idle > 180 {
		user.Status = "2" //sleeped
	} else {
		user.Status = "1" //online
		res = nil
	}

	return nil
}

func (user *APUserSt) SyncAddrIp(apm *APConfig, l3addr string) {
	m2i, ok := apm.Mac2IPs[user.AddrMac]
	if ok {
		if l3addr != "" {
			m2i.IPAddr = l3addr
			m2i.Timestamp = time.Now().Unix()
			user.AddrIp = l3addr
		} else {
			user.AddrIp = m2i.IPAddr
		}
	} else {
		if l3addr != "" {
			var n Mac2IpSt
			n.Timestamp = time.Now().Unix()
			n.IPAddr = l3addr
			apm.Mac2IPs[user.AddrMac] = &n
			user.AddrIp = l3addr
		} else {
			user.AddrIp = "waiting..."
		}
	}
}

func (apm *APConfig) UpdateUserInfoWR(AP string, wlface string, uid string, if2ssid map[string]string) (res error) {
	sUinfo, err := RequestAC([]string{"request", AP, "set", "user_info", uid + " " + wlface})
	if err != nil {
		return fmt.Errorf("request [%s] uinfo failed\n", uid)
	}
	if sUinfo == "" {
		return fmt.Errorf("request [%s] uinfo empty.\n", uid)
	}

	user := apm.Users[uid]
	if user == nil {
		user = &APUserSt{}
		user.StaVals = make(map[string]string, 0)
		apm.Users[uid] = user
	}
	//user not on this apm now
	user.AddrMac = uid
	user.APMac = AP

	//log.Printf("Rep uinfo[%s]\n", sUinfo)
	aUinfo := strings.Split(sUinfo, "\n")
	user.ParseUserInfo(aUinfo)

	//fixup ssid from ifname
	user.SSID = if2ssid[user.StaVals["wl_ifname"]]

	l3addr := user.StaVals["l3addr"]
	//translate mac 2 ip
	user.SyncAddrIp(apm, l3addr)

	return
}

func (apm *APConfig) UpdateUserInfoMR(apNode *APNodeSt) error {
	sUinfo, err := RequestAC([]string{"request", apNode.AddrMac, "get", "user_info"})
	if err != nil {
		return fmt.Errorf("request [%s] uinfo failed:%v\n", apNode.AddrMac, err)
	}
	if sUinfo == "" {
		return fmt.Errorf("request [%s] uinfo empty.\n", apNode.AddrMac)
	}

	//log.Println(sUinfo)
	asUsers := strings.Split(sUinfo, "\n\n")
	for i := 0; i < len(asUsers); i++ {
		sUser := asUsers[i]
		if len(sUser) < 32 {
			continue
		}
		user := &APUserSt{}
		user.StaVals = make(map[string]string, 0)
		//build user info.
		user.ParseUserInfo(strings.Split(sUser, "\n"))
		uID := user.StaVals["macaddr"]
		if uID == "" {
			continue
		}

		var idx uint8
		fmt.Sscanf(user.StaVals["ifidx"], "%d", &idx)
		if idx > 3 {
			idx = 0
		}
		user.SSID = apNode.SSIDs[idx]
		user.AddrMac = uID
		user.APMac = apNode.AddrMac
		user.SyncAddrIp(apm, "")
		apm.Users[uID] = user
	}

	return nil
}

func (apNode *APNodeSt) RefreshIPAddrs(mac2ip map[string]*Mac2IpSt) bool {
	sUsers, err := RequestAC([]string{"request", apNode.AddrMac, "get", "user_addrs"})
	if err != nil {
		log.Printf("refresh user addrs: [%v]\n", err)
		return false
	}

	//log.Println(sUsers)
	ts := time.Now().Unix()
	aUsrs := strings.Split(sUsers, "\n")
	for _, user := range aUsrs {
		oUsr := strings.Split(user, " ")
		if len(oUsr) > 1 { //mac,ip
			var IpNode Mac2IpSt
			IpNode.Timestamp = ts
			IpNode.IPAddr = oUsr[1]
			//追加新节
			mac2ip[oUsr[0]] = &IpNode
		}
	}

	return true
}

func (apm *APConfig) ApmListUsers() map[string]*APUserSt {
	apm.ApmInitStruct()

	//offline init
	for _, usr := range apm.Users {
		usr.Status = "0"
	}

	for apMac, apNode := range apm.APs {
		if apNode == nil {
			continue
		}

		//在线?
		// if apNode.Status == "0" {
		// 	continue
		// }
		if apNode.HW == "MR" {
			apm.UpdateUserInfoMR(apNode)
			continue
		}

		//SSID
		if2ssid := make(map[string]string, 0)
		index := 0
		for _, ssid := range apNode.SSIDs {
			if ssid == "" {
				continue
			}
			switch index {
			case 0:
				if2ssid["eth1"] = ssid
				if apNode.IsDBand {
					if2ssid["eth2"] = ssid
				}
			case 1, 2, 3:
				/* 虚拟接口不需要取用户信息,但是需要获取配置的SSID */
				if2ssid[fmt.Sprintf("wl0.%d", index)] = ssid
				if apNode.IsDBand {
					if2ssid[fmt.Sprintf("wl1.%d", index)] = ssid
				}
			}
			index++
		}

		var GetWlUserList = func(apId string, wlname string) []string {
			//resolve user list
			sMacs, err := RequestAC([]string{"request", apId, "set", "user_list", wlname})
			if err != nil {
				log.Println("Req users list failed:", err)
				return make([]string, 0)
			}

			return strings.Split(sMacs, " ")
		}

		aUserMacs := GetWlUserList(apMac, "eth1")
		if apNode.IsDBand {
			aUserMacs = append(aUserMacs, GetWlUserList(apMac, "eth2")[0:]...)
		}

		for _, uid := range aUserMacs {
			if len(uid) < 16 {
				continue
			}
			/* 新版SDK会匹配bsscfg来取sta_info */
			for vif, _ := range if2ssid {
				err := apm.UpdateUserInfoWR(apMac, vif, uid, if2ssid)
				if err != nil {
					//fmt.Printf("req [%s][%s] update failed.\n", apMac, uid)
				} else {
					fmt.Printf("req [%s][%s] info writeback.\n", apMac, uid)
					//成功返回用户, 取下一个用户信息.
					break
				}
			}
		}
	}

	//remove offline users
	for uMac, Usr := range apm.Users {
		if Usr.Status == "0" {
			//not online
			if len(apm.Users) > apm.NumUsrsLimits {
				delete(apm.Users, uMac)
			}
		}
	}

	return apm.Users
}

func (apNode *APNodeSt) Dumplicate() (newNode APNodeSt) {
	newNode = *apNode
	//copy map
	newNode.NVRamValsAP = make(map[string]string, 0)
	for k, v := range apNode.NVRamValsAP {
		newNode.NVRamValsAP[k] = v
	}
	return newNode
}

func (apNode *APNodeSt) SetStatus(s string) bool {
	if apNode.Status != s {
		apNode.Status = s
		return true
	}
	return false
}

func (apNode *APNodeSt) ConfCommit(apm *APConfig) bool {
	//reset flag
	apNode.NeedCommit = false

	//保存原始配置
	oriNode := apNode.Dumplicate()

	//重构SSID引用
	apNode.BuildSSIDRefence(apm.SSIDs)

	//check && write back
	oriNode.WriteNvramBack2Ap(apNode, false, false)

	//exec commit
	apNode.NvramCommit()

	return true
}

func (apm *APConfig) ApmConfCommit(aps []string) bool {
	for i := 0; i < len(aps); i++ {
		apNode, ok := apm.APs[aps[i]]
		if apNode == nil || !ok {
			log.Println("BUG ~@@@!!! new ap nil")
			continue
		}

		//下发配置
		apNode.ConfCommit(apm)
	}
	return true
}

func (apm *APConfig) SaveConfFiles() (res bool) {
	go Eval(fmt.Sprintf("AP.NumAPsOnline.set(%q)", apm.NumAPsOnline), &res)
	return
}

func (apm *APConfig) APMReconfAll() bool {
	for _, apNode := range apm.APs {
		if apNode == nil {
			continue
		}

		if !apNode.NeedCommit {
			log.Printf("AP[%s][%s] not need commit.\n", apNode.NameDisplay, apNode.AddrMac)
			continue
		}
		//下发配置
		apNode.ConfCommit(apm)

		//重启服务
		apNode.ExecCommands("rc restart")
	}
	return true
}

func (apNode *APNodeSt) NvramCommit() bool {
	return apNode.ExecCommands("nvram commit")
}

func (apNode *APNodeSt) ExecCommands(par string) bool {
	log.Printf("Execommand[%s]: %s\n", apNode.AddrMac, par)
	_, err := RequestAC([]string{"request", apNode.AddrMac, "set", "exec_cmds", par})
	if err != nil {
		log.Println(err)
		return false
	}

	return true
}

func (apNode *APNodeSt) UpdateFireware(par string) bool {
	if apNode.HW != "MR" {
		_, err := RequestAC([]string{"request", apNode.AddrMac, "set", "upgrade", par})
		if err != nil {
			log.Println(err)
			return false
		}
	} else {
		_, err := RequestAC([]string{"request", apNode.AddrMac, "set", "upgrade", "id.ip-com.com.cn:8081 MR7620"})
		if err != nil {
			log.Println(err)
			return false
		}
	}

	return true
}

func (apNode *APNodeSt) FetchFile(fn string, exec string) (res string, err error) {
	res, err = RequestAC([]string{"request", apNode.AddrMac, "set", "fetch", fn, exec})
	if err != nil {
		log.Println(err)
		return
	}

	return
}

func (apNode *APNodeSt) GetRtLogs() string {
	//create work dir
	exec.Command("mkdir", "-p", "/tmp/ugw/AP").Run()

	fname := fmt.Sprintf(`/tmp/ugw/AP/%d-%s-%s`, time.Now().Day(),
		strings.Replace(apNode.AddrMac, ":", "-", -1), apNode.NameDisplay)

	res, err := apNode.FetchFile("/var/log/messages", "")
	if err != nil {
		buff, err := ioutil.ReadFile(fname)
		if err == nil {
			log.Println("Get log from local cache:", fname)
			return string(buff) + fname
		} else {
			log.Println("Get log from cache err: ", err)
		}
	} else {
		err = ioutil.WriteFile(fname, []byte(res), os.ModePerm)
		if err != nil {
			log.Println("Log write to cache err:", err)
		}
	}

	//store
	apNode.LogRuntime = fname
	return res
}

func (apm *APConfig) ApmGetLogs(aps []string) bool {
	for i := 0; i < len(aps); i++ {
		apNode, ok := apm.APs[aps[i]]
		if apNode == nil || !ok {
			continue
		}

		apNode.GetRtLogs() //just fetch log & write to disk
	}

	return true
}

func (apm *APConfig) APRomsCleanup(prefix string) bool {

	file := `/www/userauthd/roms/` + prefix + `*.trx`
	err := exec.Command("sh", "-c", "rm -fr "+file).Run()
	if err != nil {
		log.Println(err)
		return false
	}
	log.Printf("ap roms cleanup: [%s]\n", file)
	return true
}

func (apm *APConfig) APRomsSync(host string, ver string) bool {

	e := strings.Index(ver, ".")
	if e > 0 || len(ver) >= 4 {
		if e <= 0 {
			e = len(ver)
		}
		//获取该类型AP的最新固件
		cmd := "/ugw/scripts/online_upgrade.sh " + host + " " + ver[0:e]
		log.Println(cmd)

		out, err := exec.Command("sh", "-c", cmd).Output()
		if err != nil {
			log.Printf("roms sync err: %v\n", err)
			return false
		} else {
			log.Println(string(out))
			return true
		}
	} else {
		log.Printf("Error ver not valid. %s\n", ver)
		return false
	}

	return true
}

func (ap *APConfig) ApmExecCommands(aps []string, par string) bool {
	for i := 0; i < len(aps); i++ {
		apNode, ok := ap.APs[aps[i]]
		if apNode == nil || !ok {
			log.Println("BUG ~@@@!!! new ap nil")
			continue
		}

		apNode.ExecCommands(par) //"services"
	}

	return true
}

func (ap *APConfig) ApmUpdateFireware(aps []string) bool {

	fname := ap.VerAcFirw + ".trx"

	for i := 0; i < len(aps); i++ {
		apNode, ok := ap.APs[aps[i]]
		if !ok || apNode == nil {
			log.Printf("BUG ~aha no ap for mac[%s]", aps[i])
			continue
		}
		if apNode.VerFirw == ap.VerAcFirw {
			log.Printf("AP[%s] ver[%s] is last pub.\n", apNode.AddrMac, apNode.VerFirw)
			continue
		}
		host := apNode.NVRamValsAP["ac_current"]
		if host == "" {
			host = apNode.NVRamValsAP["ac_ipaddr"]
		}
		url := "http://" + host + ":82" + "/roms/" + fname

		log.Printf("AP[%s] upgrade url[%s]\n", apNode.AddrMac, url)

		var doUpgrade = func() {
			if apNode.UpdateFireware(url) {
				apNode.Status = "2" //upgrading...
			}
		}

		go doUpgrade()
	}
	//time.Sleep(time.Second * 3)

	return true
}

func (ap *APConfig) ApmFirewareList() (res string) {
	files, err := ioutil.ReadDir("/www/userauthd/roms")
	if err != nil {
		log.Println(err)
		return
	}
	for _, fnode := range files {
		if fnode.IsDir() {
			continue
		}
		name := fnode.Name()
		if len(name) < 4 {
			continue
		}
		log.Println("ROM: ", name)
		if name[len(name)-4:] != ".trx" {
			continue
		}
		res += name + "\n"
	}

	return
}

func (apm *APConfig) ApmUpdateAps(aps []string, nAP APNodeSt) bool {
	mult := false
	if len(aps) > 1 {
		mult = true
	}

	for i := 0; i < len(aps); i++ {
		oApNode, ok := apm.APs[aps[i]]
		if oApNode == nil || !ok {
			log.Printf("BUG nil apm node[%s].\n", aps[i])
			continue
		}
		//SSIDs sync
		oApNode.SSIDs = nAP.SSIDs
		oApNode.DisableRadio2G = nAP.DisableRadio2G
		oApNode.DisableRadio5G = nAP.DisableRadio5G
		oApNode.Channel2G = nAP.Channel2G
		oApNode.Channel5G = nAP.Channel5G
		oApNode.TxPwr2G = nAP.TxPwr2G
		oApNode.TxPwr5G = nAP.TxPwr5G

		//nvram sync
		changed := oApNode.WriteNvramBack2Ap(&nAP, true, mult)
		if changed {
			log.Printf("apm[%s] conf updated && commit.\n", aps[i])
			//update to apm.
			oApNode.NvramCommit()
		}
	}

	return true
}

func (apm *APConfig) ApmDelUsers(uids []string) (res int) {
	res = 0
	for _, ukey := range uids {
		_, ok := apm.Users[ukey]
		if ok {
			delete(apm.Users, ukey)
		}
	}
	return
}

func (apm *APConfig) ApmRefreshMac2Addr(aps []string) bool {
	apm.ApmInitStruct()

	for i := 0; i < len(aps); i++ {
		apNode, ok := apm.APs[aps[i]]
		if apNode == nil || !ok {
			continue
		}
		//在线?
		if apNode.Status == "0" {
			continue
		}

		apNode.RefreshIPAddrs(apm.Mac2IPs)
	}

	//FIXME:  清理超时节点

	return true
}
