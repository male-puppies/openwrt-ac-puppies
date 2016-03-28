package config

import ( 
	"fmt"
	"net"
	// "errors"
	"unsafe"
	"time"
	"encoding/json"
)
 
type GRedisConfig struct {
	
}

type MessageHeader struct {
	DataLen  uint32 
}

func RecvN(conn net.Conn, buf []byte) {
	err := conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	if err != nil { 
		panic(err)
	}
	for {
		n, err := conn.Read(buf)
		if err != nil {
			fmt.Println("read error", err)
			return
		}
		if n == len(buf) {
			break
		}
		buf = buf[n:]
	}
}

func SendN(conn net.Conn, buf []byte) {
	err := conn.SetWriteDeadline(time.Now().Add(60 * time.Second))
	if err != nil {
		panic(err)
	}
	for {
		n, err := conn.Write(buf)
		if err != nil {
			fmt.Println("write error", err, n)
			return
		}
		if n == len(buf) {
			break
		}
		buf = buf[n:]
	} 
}


func fetch(content []byte, desc string) string {
	tcpAddr, err := net.ResolveTCPAddr("tcp4", "127.0.0.1:9997")
	if err != nil {
	 	return desc + ":" + err.Error()
	}
	conn, err := net.DialTCP("tcp", nil, tcpAddr)
	if err != nil {
	 	return desc + ":" + err.Error()
	}
	defer conn.Close()


	msgbuf := make([]byte, 4 + len(content))
	msghdr := (*MessageHeader)(unsafe.Pointer(&msgbuf[0]))
	msghdr.DataLen = uint32(len(content))
	copy(msgbuf[4:], content)
	fmt.Println("send", msghdr.DataLen, len(content))
	SendN(conn, msgbuf)

	var rmsghdr MessageHeader
	RecvN(conn, (*(*[4]byte)(unsafe.Pointer(&rmsghdr)))[:])
	if rmsghdr.DataLen > 1024*1024*10 {
		fmt.Println("invalid len ", rmsghdr.DataLen)
		return "network error"
	}

	buf := make([]byte, rmsghdr.DataLen)
	RecvN(conn, buf)

	return string(buf) 
}

func fetch_cmd(cmd, s string) string {
	var content string
	if len(s) == 0 {
		content = "none"
	} else {
		content = s
	}

	arr := [] string {cmd, content}
	b, _ := json.MarshalIndent(arr, "", "	")
	return fetch(b, cmd)
}

func (grds *GRedisConfig) ApmListAPs() string { 
	return fetch_cmd("ApmListAPs", "")
}

func (grds *GRedisConfig) ApmUpdateAps(s string) string {
	return fetch_cmd("ApmUpdateAps", s)
}

func (grds *GRedisConfig) ApmExecCommands(s string) string {
	return fetch_cmd("ApmExecCommands", s)
}

func (grds *GRedisConfig) ApmFirewareList(s string) string {
	return fetch_cmd("ApmFirewareList", s)
}

func (grds *GRedisConfig) ApmUpdateFireware(s string) string {
	return fetch_cmd("ApmUpdateFireware", s)
}

func (grds *GRedisConfig) WLANList(s string) string {
	return fetch_cmd("WLANList", s)
}

func (grds *GRedisConfig) WLANAdd(s string) string {
	return fetch_cmd("WLANAdd", s)
}

func (grds *GRedisConfig) WLANDelete(s string) string {
	return fetch_cmd("WLANDelete", s)
}

func (grds *GRedisConfig) WLANModify(s string) string {
	return fetch_cmd("WLANModify", s)
}

func (grds *GRedisConfig) WLANListAps(s string) string {
	return fetch_cmd("WLANListAps", s)
}

func (grds *GRedisConfig) RadioList(s string) string {
	return fetch_cmd("RadioList", s)
}
 
func (grds *GRedisConfig) NWLAN(s string) string {
	return fetch_cmd("NWLAN", s)
}

func (grds *GRedisConfig) ApmListUsers(s string) string {
	return fetch_cmd("ApmListUsers", s)
}

func (grds *GRedisConfig) ApmDelUsers(s string) string {
	return fetch_cmd("ApmDelUsers", s)
}

func (grds *GRedisConfig) ApmDeleteAps(s string) string {
	return fetch_cmd("ApmDeleteAps", s)
}

func (grds *GRedisConfig) DtHideColumns(s string) string {
	return fetch_cmd("DtHideColumns", s)
}

func (grds *GRedisConfig) GetHideColumns(s string) string {
	return fetch_cmd("GetHideColumns", s)
}  

func (grds *GRedisConfig) GetBandSupport(s string) string {
	return fetch_cmd("GetBandSupport", s)
}  

func (grds *GRedisConfig) GetApLog(s string) string {
	return fetch_cmd("GetApLog", s) 
}  

func (grds *GRedisConfig) DownloadApLog(s string) string {
	return fetch_cmd("DownloadApLog", s)
}  

func (grds *GRedisConfig) SmartInfo(s string) string {
	return fetch_cmd("SmartInfo", s)
}

func (grds *GRedisConfig) SmartPowerSet(s string) string {
	return fetch_cmd("SmartPowerSet", s)
}

func (grds *GRedisConfig) SmartChannelSet(s string) string {
	return fetch_cmd("SmartChannelSet", s)
}

func (grds *GRedisConfig) ImmePowerAdjust(s string) string {
	return fetch_cmd("ImmePowerAdjust", s)
}

func (grds *GRedisConfig) ImmeChannelAdjust(s string) string {
	return fetch_cmd("ImmeChannelAdjust", s)
}

func (grds *GRedisConfig) CheckImmePower(s string) string {
	return fetch_cmd("CheckImmePower", s)
}

func (grds *GRedisConfig) CheckImmeChannel(s string) string {
	return fetch_cmd("CheckImmeChannel", s)
}

func (grds *GRedisConfig) OnlineAplist(s string) string {
	return fetch_cmd("OnlineAplist", s)
}

func (grds *GRedisConfig) GetLoadBalance(s string) string {
	return fetch_cmd("GetLoadBalance", s)
}

func (grds *GRedisConfig) SaveLoadBalance(s string) string {
	return fetch_cmd("SaveLoadBalance", s)
}

func (grds *GRedisConfig) WLANState(s string) string {
	return fetch_cmd("WLANState", s)
}

func (grds *GRedisConfig) GetOptimization(s string) string {
	return fetch_cmd("GetOptimization", s)
}

func (grds *GRedisConfig) SaveOptimization(s string) string {
	return fetch_cmd("SaveOptimization", s)
}

