package config

import (
	"log"
	"net"
	"net/http"
	"net/rpc"
)

type NotifyMsgSt struct {
	Cmd  string
	Args []string
}

type NotifyObjectSt struct {
	addr         string
	port         string
	serverMethod string
}

//需要通知的程序注册结构
const (
	NOTIFY_ADDR_SERV    = "127.0.0.1"
	NOTIFY_PORT_NET     = "5230"
	NOTIFY_ADDR_NET     = "127.0.0.1"
	NOTIFY_PORT_TC      = "5200"
	NOTIFY_ADDR_TC      = "127.0.0.1"
	NOTIFY_PORT_FW      = "1984"
	NOTIFY_PORT_UA      = "1990"
	NOTIFY_PORT_CF      = "1998"
	NOTIFY_PORT_CF_SE   = "1999"
	NOTIFY_PORT_DPI     = "5240"
	NOTIFY_PORT_UPGRADE = "9981"
	NOTIFY_PORT_CFGBAK  = "6954"
)

var TcNotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_TC,
	port:         NOTIFY_PORT_TC,
	serverMethod: "NotifyTargetTc.MessageHandler",
}

var NetNotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_NET,
	port:         NOTIFY_PORT_NET,
	serverMethod: "NotifyTargetNet.MessageHandler",
}

var FwNotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_SERV,
	port:         NOTIFY_PORT_FW,
	serverMethod: "FireWall.ReceiveCmd",
}

var UserAuthdNotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_SERV,
	port:         NOTIFY_PORT_UA,
	serverMethod: "UserAuthd.ReceiveCmd",
}

var CFNotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_SERV,
	port:         NOTIFY_PORT_CF,
	serverMethod: "CFNotify.ReceiveCmd",
}

var CFNotify_SE = NotifyObjectSt{
	addr:         NOTIFY_ADDR_SERV,
	port:         NOTIFY_PORT_CF_SE,
	serverMethod: "CFNotify.ReceiveCmd",
}

var DPINotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_SERV,
	port:         NOTIFY_PORT_DPI,
	serverMethod: "NotifyTargetDPI.MessageHandler",
}

var UPgradeNotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_SERV,
	port:         NOTIFY_PORT_UPGRADE,
	serverMethod: "NotifyTargetUPGRADE.MessageHandler",
}

var CfgBakNotify = NotifyObjectSt{
	addr:         NOTIFY_ADDR_SERV,
	port:         NOTIFY_PORT_CFGBAK,
	serverMethod: "NotifyTargetCFGBAK.MessageHandler",
}

//END :-)

func (notify *NotifyObjectSt) SendMsg(cmd string, args []string) bool {
	cli, err := rpc.DialHTTP("tcp", notify.addr+":"+notify.port)
	if err != nil {
		log.Println("dial notify failed: ", notify.serverMethod, err)
		return false
	}
	defer cli.Close()

	//package
	var rep int
	var msg = NotifyMsgSt{Cmd: cmd, Args: args}
	err = cli.Call(notify.serverMethod, &msg, &rep)
	if err != nil {
		log.Println("call failed: ", notify.serverMethod, err)
		return false
	}
	return true
}

func (notify *NotifyObjectSt) Services(recv interface{}) error {
	rpc.Register(recv)
	rpc.HandleHTTP()
	listen, err := net.Listen("tcp", notify.addr+":"+notify.port)
	if err != nil {
		log.Println("listen failed: ", notify.addr+":"+notify.port, err)
		return err
	}
	http.Serve(listen, nil)
	return nil
}
