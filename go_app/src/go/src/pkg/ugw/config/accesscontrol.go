package config

import (
	"hash/crc64"
	"log"
	"net/rpc"
)

//应用识别协议类型定义
// var L7proto_string = []string{
// 	"未知",            //DPI_PROTO_UNKNOWN
// 	"FTP",           //IPOQUE_PROTOCOL_FTP
// 	"POP3",          //IPOQUE_PROTOCOL_MAIL_POP
// 	"SMTP",          //IPOQUE_PROTOCOL_MAIL_SMTP
// 	"IMAP",          //IPOQUE_PROTOCOL_MAIL_IMAP
// 	"DNS",           //IPOQUE_PROTOCOL_DNS
// 	"IPP",           //IPOQUE_PROTOCOL_IPP
// 	"HTTP",          //IPOQUE_PROTOCOL_HTTP
// 	"MDNS",          //IPOQUE_PROTOCOL_MDNS
// 	"NTP",           //IPOQUE_PROTOCOL_NTP
// 	"NETBIOS",       //IPOQUE_PROTOCOL_NETBIOS
// 	"NFS",           //IPOQUE_PROTOCOL_NFS
// 	"SSDP",          //IPOQUE_PROTOCOL_SSDP
// 	"GBP",           //IPOQUE_PROTOCOL_BGP
// 	"SNMP",          //IPOQUE_PROTOCOL_SNMP
// 	"XDMCP",         //IPOQUE_PROTOCOL_XDMCP
// 	"Samba",         //IPOQUE_PROTOCOL_SMB
// 	"Syslog",        //IPOQUE_PROTOCOL_SYSLOG
// 	"DHCP",          //IPOQUE_PROTOCOL_DHCP
// 	"Postgres",      //IPOQUE_PROTOCOL_POSTGRES
// 	"Mysql",         //IPOQUE_PROTOCOL_MYSQL
// 	"TDS",           //IPOQUE_PROTOCOL_TDS
// 	"下载",            //IPOQUE_PROTOCOL_DIRECT_DOWNLOAD_LINK
// 	"I23v5",         //IPOQUE_PROTOCOL_I23V5
// 	"AppleJuice",    //IPOQUE_PROTOCOL_APPLEJUICE
// 	"DirectConnect", //IPOQUE_PROTOCOL_DIRECTCONNECT
// 	"Socrates",      //IPOQUE_PROTOCOL_SOCRATES
// 	"Winmx",         //IPOQUE_PROTOCOL_WINMX
// 	"Manolito",      //IPOQUE_PROTOCOL_MANOLITO
// 	"Pando",         //IPOQUE_PROTOCOL_PANDO
// 	"FileTopia",     //IPOQUE_PROTOCOL_FILETOPIA
// 	"Imesh",         //IPOQUE_PROTOCOL_IMESH
// 	"Kontiki",       //IPOQUE_PROTOCOL_KONTIKI
// 	"OpenFT",        //IPOQUE_PROTOCOL_OPENFT
// 	"FastRack",      //IPOQUE_PROTOCOL_FASTTRACK
// 	"Gnutella",      //IPOQUE_PROTOCOL_GNUTELLA
// 	"Edonkey",       //IPOQUE_PROTOCOL_EDONKEY
// 	"Bittorrent",    //IPOQUE_PROTOCOL_BITTORRENT
// 	"OFF",           //IPOQUE_PROTOCOL_OFF
// 	"AVI",           //IPOQUE_PROTOCOL_AVI
// 	"FLASH-V",       //IPOQUE_PROTOCOL_FLASH
// 	"OGG",           //IPOQUE_PROTOCOL_OGG
// 	"MPEG",          //IPOQUE_PROTOCOL_MPEG
// 	"QuickTime",     //IPOQUE_PROTOCOL_QUICKTIME
// 	"RealMedia",     //IPOQUE_PROTOCOL_REALMEDIA
// 	"Windows Media", //IPOQUE_PROTOCOL_WINDOWSMEDIA
// 	"MMS",           //IPOQUE_PROTOCOL_MMS
// 	"XBOX",          //IPOQUE_PROTOCOL_XBOX
// 	"QQ",            //IPOQUE_PROTOCOL_QQ
// 	"Moive",         //IPOQUE_PROTOCOL_MOVE
// 	"RTSP",          //IPOQUE_PROTOCOL_RTSP
// 	"沸点电视",          //IPOQUE_PROTOCOL_FEIDIAN
// 	"ICECast",       //IPOQUE_PROTOCOL_ICECAST
// 	"PPLive",        //IPOQUE_PROTOCOL_PPLIVE
// 	"PPSteam",       //IPOQUE_PROTOCOL_PPSTREAM
// 	"Zatto",         //IPOQUE_PROTOCOL_ZATTOO
// 	"搜狐视频",          //IPOQUE_PROTOCOL_SHOUTCAST
// 	"Sopcast",       //IPOQUE_PROTOCOL_SOPCAST
// 	"蚂蚁电视",          //IPOQUE_PROTOCOL_TVANTS
// 	"TVUPlayer",     //IPOQUE_PROTOCOL_TVUPLAYER
// 	"VeoHTV",        //IPOQUE_PROTOCOL_HTTP_APPLICATION_VEOHTV
// 	"QQLive",        //IPOQUE_PROTOCOL_QQLIVE
// 	"迅雷",            //IPOQUE_PROTOCOL_THUNDER
// 	"SoulSeek",      //IPOQUE_PROTOCOL_SOULSEEK
// 	"GaduGadu",      //IPOQUE_PROTOCOL_GADUGADU
// 	"IRC",           //IPOQUE_PROTOCOL_IRC
// 	"POPO",          //IPOQUE_PROTOCOL_POPO
// 	"Jabber",        //IPOQUE_PROTOCOL_UNENCRYPED_JABBER
// 	"MSN",           //IPOQUE_PROTOCOL_MSN
// 	"OSCar",         //IPOQUE_PROTOCOL_OSCAR
// 	"Yahoo",         //IPOQUE_PROTOCOL_YAHOO
// 	"战地",            //IPOQUE_PROTOCOL_BATTLEFIELD
// 	"雷神",            //IPOQUE_PROTOCOL_QUAKE
// 	"重生",            //IPOQUE_PROTOCOL_SECONDLIFE
// 	"Steam",         //IPOQUE_PROTOCOL_STEAM
// 	"半条命",           //IPOQUE_PROTOCOL_HALFLIFE2
// 	"魔兽",            //IPOQUE_PROTOCOL_WORLDOFWARCRAFT
// 	"Telnet",        //IPOQUE_PROTOCOL_TELNET
// 	"Stun",          //IPOQUE_PROTOCOL_STUN
// 	"IPSec",         //IPOQUE_PROTOCOL_IPSEC
// 	"GRE",           //IPOQUE_PROTOCOL_GRE
// 	"ICMP",          //IPOQUE_PROTOCOL_ICMP
// 	"IGMP",          //IPOQUE_PROTOCOL_IGMP
// 	"EGP",           //IPOQUE_PROTOCOL_EGP
// 	"SCTP",          //IPOQUE_PROTOCOL_SCTP
// 	"OSPF",          //IPOQUE_PROTOCOL_OSPF
// 	"IPinIP",        //IPOQUE_PROTOCOL_IP_IN_IP
// 	"RTP",           //IPOQUE_PROTOCOL_RTP
// 	"RDP",           //IPOQUE_PROTOCOL_RDP
// 	"VNC",           //IPOQUE_PROTOCOL_VNC
// 	"PCAnywhere",    //IPOQUE_PROTOCOL_PCANYWHERE
// 	"SSL",           //IPOQUE_PROTOCOL_SSL
// 	"SSH",           //IPOQUE_PROTOCOL_SSH
// 	"Usenet",        //IPOQUE_PROTOCOL_USENET
// 	"MGCP",          //IPOQUE_PROTOCOL_MGCP
// 	"IAX",           //IPOQUE_PROTOCOL_IAX
// 	"TFTP",          //IPOQUE_PROTOCOL_TFTP
// 	"AFP",           //IPOQUE_PROTOCOL_AFP
// 	"StealthNet",    //IPOQUE_PROTOCOL_STEALTHNET
// 	"AIMINI",        //IPOQUE_PROTOCOL_AIMINI
// 	"SIP",           //IPOQUE_PROTOCOL_SIP
// 	"TruPhone",      //IPOQUE_PROTOCOL_TRUPHONE
// 	"ICMPv6",        //IPOQUE_PROTOCOL_ICMPV6
// 	"DHCPv6",        //IPOQUE_PROTOCOL_DHCPV6
// 	"Armagetron",    //IPOQUE_PROTOCOL_ARMAGETRON
// 	"Crossfire",     //IPOQUE_PROTOCOL_CROSSFIRE
// 	"Dofus",         //IPOQUE_PROTOCOL_DOFUS
// 	"Fiesta",        //IPOQUE_PROTOCOL_FIESTA
// 	"Florensia",     //IPOQUE_PROTOCOL_FLORENSIA
// 	"GuildWars",     //IPOQUE_PROTOCOL_GUILDWARS
// 	"ActiveSyn",     //IPOQUE_PROTOCOL_HTTP_APPLICATION_ACTIVESYN
// 	"Kerberos",      //IPOQUE_PROTOCOL_KERBEROS
// 	"LDAP",          //IPOQUE_PROTOCOL_LDAP
// 	"MapleStory",    //IPOQUE_PROTOCOL_MAPLESTORY
// 	"MSSql",         //IPOQUE_PROTOCOL_MSSQL
// 	"PPTP",          //IPOQUE_PROTOCOL_PPTP
// 	"WarCraft3",     //IPOQUE_PROTOCOL_WARCRAFT3
// 	"拳皇",          //IPOQUE_PROTOCOL_WORLD_OF_KUNG_FU
// 	"Meebo"}         //IPOQUE_PROTOCOL_MEEBO

// const (
// 	IPOQUE_LAST_IMPLEMENTED_PROTOCOL = 118
// 	DPI_MAX_SUPPORTED_PROTOCOLS      = IPOQUE_LAST_IMPLEMENTED_PROTOCOL
// )

const (
	ACRINGBUF = "/tmp/ringpkgs_ac" //环形缓冲区文件
)

//策略控制对象
type ObjectOfPolicy struct {
	ObjType uint8  //0-用户 1-组 2-全局
	ObjName string //对象名称（标识组名，用户名等）
}

//上网策略信息
type AccessControlPolicy struct {
	ACPolicyId         uint64           //全局唯一上网策略ID
	ACPolicyObj        ObjectOfPolicy   //策略控制对象
	ACAppDefaultReject bool             //受控应用默认拒绝
	ACAppPolicy        map[string]uint8 //受控应用
	acAppPolicyId      map[uint16]string
	ACUrlDefaultReject bool             //受控Url默认拒绝
	ACUrlPolicy        map[string]uint8 //URL访问控制
	ValidTime          string           //生效时间段（时间片集合）
	Enable             uint8            //策略启用或禁用状态
}

type ACConfig struct {
	ACPolicy map[string]*AccessControlPolicy
	//DPI        map[string][]string
	//URLCLASSIC []string
}

func (acp *AccessControlPolicy) InsertRuleId(p uint16, name string) {
	if acp.acAppPolicyId == nil {
		acp.acAppPolicyId = make(map[uint16]string, 0)
	}
	acp.acAppPolicyId[p] = name
}

func (acp *AccessControlPolicy) MatchRuleId(proto uint16) bool {
	_, ok := acp.acAppPolicyId[proto]
	return ok
}

func (acp *AccessControlPolicy) MatchUrlType(url string) bool {
	_, ok := acp.ACUrlPolicy[url]
	return ok
}

func (acp *AccessControlPolicy) OnNew() bool {
	//合法性检查TODO
	acp.ACPolicyId = crc64.Checksum([]byte(acp.ACPolicyObj.ObjName), crc64.MakeTable(crc64.ECMA))
	return true
}

func (acf *ACConfig) OnACPolicyInsert(acp map[string]*AccessControlPolicy, key string, val *AccessControlPolicy) bool {
	//合法性检测
	log.Println("onACPolicyInsert was called!")
	//TODO 通知
	go notifyAC("InsertPolicy", "")
	go CFNotify.SendMsg("acpolicy", nil)
	go CFNotify_SE.SendMsg("acpolicy", nil)
	return true
}
func (acf *ACConfig) OnACPolicyUpdate(acp map[string]*AccessControlPolicy, key string, val *AccessControlPolicy) bool {
	//合法性检测
	log.Println("OnACPolicyUpdate was called!")
	//TODO 通知
	go notifyAC("UpdatePolicy", "")
	go CFNotify.SendMsg("acpolicy", nil)
	go CFNotify_SE.SendMsg("acpolicy", nil)
	return true
}
func (acf *ACConfig) OnACPolicyDelete(acp map[string]*AccessControlPolicy, key string, val *AccessControlPolicy) bool {
	//合法性检测
	log.Println("OnACPolicyDelete was called!")
	//TODO 通知
	go notifyAC("DeletePolicy", "")
	go CFNotify.SendMsg("acpolicy", nil)
	go CFNotify_SE.SendMsg("acpolicy", nil)
	return true
}

//命令参数结构体，被notifyAC(cmd string, arg string)使用
type ACCmd struct {
	Cmd string //命令
	Arg string //参数
}

/*事件通知上网策略后台(例如：上网策略发生改变)*/
func notifyAC(cmd string, arg string) bool {
	client, err := rpc.DialHTTP("tcp", "127.0.0.1"+":7963")
	if err != nil {
		log.Println("dialing:", err)
		return false
	}
	defer client.Close()
	args := &ACCmd{cmd, arg}
	var result bool
	err = client.Call("Communication.ReceiveCmd", args, &result)
	if err != nil || result == false {
		log.Println("AC ReceiveCmd:", err)
		return false
	}
	return true
}
