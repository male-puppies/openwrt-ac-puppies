package nlmsg

/*
#cgo LDFLAGS:-lnlumsg -lnosdbg
#include <stddef.h>
#include <sys/types.h>
#include "nos.h"
#include "nos_common.h"
#include "nos_dpi_proto_resolve.h"
#include "nos_user.h"
#include "nos_nodes.h"
#include "nos_nlmsg_cmds.h"
#include "nos_nlmsg.h"
#include "nos_fw.h"
#include "string.h"
*/
import "C"

import (
	"fmt"
	"log"
	"unsafe"
)

const (
	NLMSG_MAX_RCV_BUFF_SIZE = C.NLMSG_MAX_RCV_BUFF_SIZE //4k
	NLMSG_MAX_U32_PARS_NUM  = C.NLMSG_MAX_U32_PARS_NUM  //32*u32

	NOS_FLOW_TRACK_MAX = C.NOS_FLOW_TRACK_MAX
	NOS_USER_TRACK_MAX = C.NOS_USER_TRACK_MAX
)

//nos_cmd_type
const (
	NOS_CMD_SET_FLOW_DROP_FLAGS     = C.NOS_CMD_SET_FLOW_DROP_FLAGS
	NOS_CMD_SET_FLOW_STATUS         = C.NOS_CMD_SET_FLOW_STATUS
	NOS_CMD_CLR_FLOW_STATUS         = C.NOS_CMD_CLR_FLOW_STATUS
	NOS_CMD_SET_FLOW_TC_CLASSID     = C.NOS_CMD_SET_FLOW_TC_CLASSID
	NOS_CMD_UPDATE_USER_AUTH_STATUS = C.NOS_CMD_UPDATE_USER_AUTH_STATUS
	NOS_CMD_CONFIG_UPDATED          = C.NOS_CMD_CONFIG_UPDATED
	NOS_CMD_SET_NLMSG_PID           = C.NOS_CMD_SET_NLMSG_PID
	NOS_CMD_SET_DBG_LEVEL           = C.NOS_CMD_SET_DBG_LEVEL
	NOS_CMD_SET_DROPLIST            = C.NOS_CMD_SET_DROPLIST
	NOS_CMD_CLR_DROPLIST            = C.NOS_CMD_CLR_DROPLIST
	NOS_CMD_SET_TC_ENABLE           = C.NOS_CMD_SET_TC_ENABLE
	NOS_CMD_SET_QUEUE_ENABLE        = C.NOS_CMD_SET_QUEUE_ENABLE
	NOS_CMD_SET_TC_PUNISH_CHANNEL   = C.NOS_CMD_SET_TC_PUNISH_CHANNEL
	NOS_CMD_SET_USR_BW_LIMITS       = C.NOS_CMD_SET_USR_BW_LIMITS
	NOS_CMD_SET_MLINE_PARS          = C.NOS_CMD_SET_MLINE_PARS
)

//NLMSG PID 类型
const (
	NOS_NLMSG_PID_TYPE_NONE = C.NOS_NLMSG_PID_TYPE_NONE
	NOS_NLMSG_PID_TYPE_LOG  = C.NOS_NLMSG_PID_TYPE_LOG
	NOS_NLMSG_PID_TYPE_DBG  = C.NOS_NLMSG_PID_TYPE_DBG
)

//调试droplist的过来类型
const (
	NOS_FW_DROP_CLOSED      = C.NOS_FW_DROP_CLOSED
	NOS_FW_DROP_DEBUG       = C.NOS_FW_DROP_DEBUG
	NOS_FW_DROP_OPEN        = C.NOS_FW_DROP_OPEN
	NOS_FW_DROP_FILTER_FLOW = C.NOS_FW_DROP_FILTER_FLOW
	NOS_FW_DROP_FILTER_USER = C.NOS_FW_DROP_FILTER_USER
)

//丢包原因
const (
	NOS_FLOW_DROP_NONE = C.NOS_FLOW_DROP_NONE
	NOS_FLOW_DROP_AUTH = C.NOS_FLOW_DROP_AUTH
	NOS_FLOW_DROP_AC   = C.NOS_FLOW_DROP_AC
	NOS_FLOW_DROP_FW   = C.NOS_FLOW_DROP_FW
	NOS_FLOW_DROP_CC   = C.NOS_FLOW_DROP_CC
	NOS_FLOW_DROP_URL  = C.NOS_FLOW_DROP_URL
	NOS_FLOW_DROP_CT   = C.NOS_FLOW_DROP_CT
	NOS_FLOW_DROP_KV   = C.NOS_FLOW_DROP_KV
)

var dropReason = map[int]string{
	NOS_FLOW_DROP_NONE: "未丢包",
	NOS_FLOW_DROP_AUTH: "用户认证",
	NOS_FLOW_DROP_AC:   "上网控制",
	NOS_FLOW_DROP_FW:   "防火墙",
	NOS_FLOW_DROP_CC:   "并发控制",
	NOS_FLOW_DROP_KV:   "网关杀毒",
	NOS_FLOW_DROP_CT:   "内容过滤",
	NOS_FLOW_DROP_URL:  "URL过滤",
}

type NosFrameSt struct {
	Flags       uint64
	TimeStamp   uint64
	Size        uint16
	L7Offset    uint16
	Ip_src      uint32
	Mac_src     [6]uint8
	Mac_dst     [6]uint8
	Indev_name  [IF_NAME_SIZE]byte
	Outdev_name [IF_NAME_SIZE]byte
}

type NosPacketSt struct {
	Frame     NosFrameSt
	FlowID    uint32
	FlowMagic uint32
	Buffer    [1600]byte
	Reserved  [2<<10 - (SizeOfNosFrame) - 8 - 1600]byte
} //2k

const (
	IF_NAME_SIZE    = C.IF_NAME_SIZE
	NAME_SIZE_USER  = C.NAME_SIZE_USER
	NAME_SIZE_GROUP = C.NAME_SIZE_GROUP
)

const (
	SizeOfNosFrame  = int(unsafe.Sizeof(*(*NosFrameSt)(nil)))
	SizeOfNosPacket = int(unsafe.Sizeof(*(*NosPacketSt)(nil)))
)

//包标记位
const (
	NOS_FRAME_INFO_FLAGS_NONE    = C.NOS_FRAME_INFO_FLAGS_NONE
	NOS_FRAME_INFO_FLAGS_NEW     = C.NOS_FRAME_INFO_FLAGS_NEW
	NOS_FRAME_INFO_FLAGS_FIN_DPI = C.NOS_FRAME_INFO_FLAGS_FIN_DPI
)

//Flow的状态标记类型
const (
	NOS_FLOW_STATUS_NONE   = C.NOS_FLOW_STATUS_NONE
	NOS_FLOW_STATUS_AC     = C.NOS_FLOW_STATUS_AC
	NOS_FLOW_STATUS_FW     = C.NOS_FLOW_STATUS_FW
	NOS_FLOW_STATUS_TC     = C.NOS_FLOW_STATUS_TC
	NOS_FLOW_STATUS_ST     = C.NOS_FLOW_STATUS_ST
	NOS_FLOW_STATUS_QUEUE  = C.NOS_FLOW_STATUS_QUEUE //延迟发送的连接标记
	NOS_FLOW_STATUS_BYPASS = C.NOS_FLOW_STATUS_BYPASS
)

const (
	NOS_FLOW_DIR_UNKNOWN = C.NOS_FLOW_DIR_UNKNOWN
	NOS_FLOW_DIR_LAN2WAN = C.NOS_FLOW_DIR_LAN2WAN
	NOS_FLOW_DIR_WAN2LAN = C.NOS_FLOW_DIR_WAN2LAN
	NOS_FLOW_DIR_LAN2LAN = C.NOS_FLOW_DIR_LAN2LAN
	NOS_FLOW_DIR_WAN2WAN = C.NOS_FLOW_DIR_WAN2WAN
)

//user auth status
const (
	NOS_USER_STATUS_AUTHD_DEFAULT   = C.NOS_USER_STATUS_AUTHD_DEFAULT
	NOS_USER_STATUS_AUTHD_ASIGNED   = C.NOS_USER_STATUS_AUTHD_ASIGNED
	NOS_USER_STATUS_AUTHD_WEB       = C.NOS_USER_STATUS_AUTHD_WEB
	NOS_USER_STATUS_AUTHD_AUTH_OK   = C.NOS_USER_STATUS_AUTHD_AUTH_OK
	NOS_USER_STATUS_AUTHD_VOID      = C.NOS_USER_STATUS_AUTHD_VOID
	NOS_USER_STATUS_AUTHD_FORZEN    = C.NOS_USER_STATUS_AUTHD_FORZEN
	NOS_USER_STATUS_AUTHD_CANCELLED = C.NOS_USER_STATUS_AUTHD_CANCELLED
	NOS_USER_STATUS_AUTHD_TIMEOUT   = C.NOS_USER_STATUS_AUTHD_TIMEOUT
)

//user auth attr status
const (
	NOS_USER_STATUS_ATTR_DEFAULT = C.NOS_USER_STATUS_ATTR_DEFAULT
	NOS_USER_STATUS_ATTR_LEVEL1  = C.NOS_USER_STATUS_ATTR_LEVEL1
	NOS_USER_STATUS_ATTR_LEVEL2  = C.NOS_USER_STATUS_ATTR_LEVEL2
)

func (p *NosPacketSt) DumpOffsets() {
	fmt.Printf("\n%d :Frame:%d\n", unsafe.Offsetof(p.Frame), SizeOfNosFrame)
	fmt.Printf("\t%d :Flags\n", unsafe.Offsetof(p.Frame.Flags))
	fmt.Printf("\t%d :TimeStamp\n", unsafe.Offsetof(p.Frame.TimeStamp))
	fmt.Printf("\t%d :Size\n", unsafe.Offsetof(p.Frame.Size))
	fmt.Printf("\t%d :L7Offset\n", unsafe.Offsetof(p.Frame.L7Offset))
	fmt.Printf("\t%d :Mac_src\n", unsafe.Offsetof(p.Frame.Mac_src))
	fmt.Printf("\t%d :Indev, %d :Outdev\n", unsafe.Offsetof(p.Frame.Indev_name), unsafe.Offsetof(p.Frame.Outdev_name))
	fmt.Printf("\t%d :FlowID\n", unsafe.Offsetof(p.FlowID))
	fmt.Printf("\t%d :FlowMagic\n", unsafe.Offsetof(p.FlowMagic))
	fmt.Printf("\t%d :FrameBuffer\n", unsafe.Offsetof(p.Buffer))
	fmt.Printf("\t%d :Reserved, size{%d}\n", unsafe.Offsetof(p.Reserved), unsafe.Sizeof(p.Reserved))
}

var (
	NosUsers []C.struct_nos_user_info
	NosFlows []C.struct_nos_flow_info
)

type NosTuple struct {
	Src   uint32
	Dst   uint32
	Sport uint16
	Dport uint16
	Proto uint8
	Dir   uint8 //LAN2LAN, WAN2WAN, LAN2WAN, WAN2LAN
}

type NosUserStat struct {
	Xmit_bytes   uint64
	Recv_bytes   uint64
	Conn_counter uint64
	Xmit_limits  uint16
	Recv_limits  uint16
}

type NosFlowStat struct {
	Up_bytes uint64
	Up_pkgs  uint64
	Dn_bytes uint64
	Dn_pkgs  uint64
	Stamps   uint64
}

type NosQQInfo struct {
	Number  uint64
	Version uint32
	Command uint32
}

/************* GO进程之间传递接口 **************/
func travFlow() {
	counter := 0
	for i := 0; i < len(NosFlows); i++ {
		if NosFlows[i].magic&1 == 0 {
			//log.Printf("trav flow[%v] magic[%x]\n", i, NosFlows[i].magic)
			counter++
		}
	}

	var p NosPacketSt
	p.DumpOffsets()
	log.Printf("NosFlow size: %d, FrameSt size:%d, NosPackSt %d, counter: %v\n",
		unsafe.Sizeof(NosFlows[0]),
		unsafe.Sizeof(*(*NosFrameSt)(nil)),
		unsafe.Sizeof(*(*NosPacketSt)(nil)), counter)
}

type NosFlowPtr struct {
	ptr *C.struct_nos_flow_info
}
type NosUserPtr struct {
	ptr *C.struct_nos_user_info
}

func (flow NosFlowPtr) GetUserPtr() *NosUserPtr {
	uid := uint32(flow.ptr.usr_src_id)
	if uid >= C.NOS_USER_TRACK_MAX {
		log.Printf("pkg get user info invalid uid:%d", uid)
		return nil
	}
	return &NosUserPtr{ptr: (*C.struct_nos_user_info)(unsafe.Pointer(&NosUsers[uid]))}
}

func (user NosUserPtr) GetUsrGrpName() (string, string) {
	if user.ptr != nil {
		ulen := C.int(user.ptr.uname[0])
		glen := C.int(user.ptr.gname[0])
		return C.GoStringN((*C.char)(unsafe.Pointer(&user.ptr.uname[1])), ulen),
			C.GoStringN((*C.char)(unsafe.Pointer(&user.ptr.gname[1])), glen)
	}
	return "", ""
}

func (user NosUserPtr) GetAuthStatus() uint8 {
	if user.ptr != nil {
		return uint8(user.ptr.status & 0xff)
	}
	return 0xff
}

func (user NosUserPtr) GetIpAddr() uint32 {
	if user.ptr != nil {
		return uint32(user.ptr.ip)
	}
	return 0
}

func TravNodesFlow(start int, cb func(unsafe.Pointer, unsafe.Pointer) bool) int {
	counter := 0
	for i := start; i < len(NosFlows); i++ {
		counter++
		if cb(unsafe.Pointer(&NosFlows[i]), unsafe.Pointer(&NosUsers[NosFlows[i].usr_src_id])) != true {
			return counter
		}
	}
	return counter
}

func TravNodesUser(start int, cb func(unsafe.Pointer) bool) int {
	counter := 0
	for i := start; i < len(NosUsers); i++ {
		counter++
		if cb(unsafe.Pointer(&NosUsers[i])) != true {
			return counter
		}
	}
	return counter
}

func (p *NosPacketSt) GetUrlType() string {
	flow := p.GetFlowInfo()
	if flow == nil {
		return ""
	}
	info := (*C.struct_dpi_url_st)(unsafe.Pointer(&flow.reserved[0]))
	if info.magic == (C.DPI_EXT_MAGIC_URL | C.DPI_URL_FINISHED) {
		return C.GoStringN((*C.char)(unsafe.Pointer(&info.url_type[1])), C.int(info.url_type[0]))
	}
	return ""
}

func (p *NosPacketSt) GetUrlStr() string {
	info := (*C.struct_dpi_url_st)(unsafe.Pointer(&p.Reserved[0]))
	if info.magic == (C.DPI_EXT_MAGIC_URL | C.DPI_URL_FINISHED) {
		return C.GoStringN((*C.char)(unsafe.Pointer(&p.Buffer[info.host_start])), C.int(info.host_len)) +
			C.GoStringN((*C.char)(unsafe.Pointer(&p.Buffer[info.url_start])), C.int(info.url_len))
	}
	return ""
}

func (p *NosPacketSt) GetQQInfo() *NosQQInfo {
	info := (*C.struct_dpi_QQ_st)(unsafe.Pointer(&p.Reserved[0]))
	if info.magic == (C.DPI_EXT_MAGIC_QQ | C.DPI_QQ_OK) {
		var QQ NosQQInfo
		QQ.Number = uint64(info.number)
		QQ.Command = uint32(info.command)
		QQ.Version = uint32(info.version)
		return &QQ
	}
	return nil
}

func (p *NosPacketSt) GetQQNumber() uint64 {
	info := (*C.struct_dpi_QQ_st)(unsafe.Pointer(&p.Reserved[0]))
	if info.magic == (C.DPI_EXT_MAGIC_QQ | C.DPI_QQ_OK) {
		return uint64(info.number)
	}
	return 0
}

func (p *NosPacketSt) GetUserInfo(src bool) *C.struct_nos_user_info {
	flow := p.GetFlowInfo()
	if flow == nil {
		return nil
	}
	if uint32(flow.magic) == p.FlowMagic {
		uid := uint32(0)
		if src {
			uid = uint32(flow.usr_src_id)
		} else {
			uid = uint32(flow.usr_dst_id)
		}
		if uid >= C.NOS_USER_TRACK_MAX {
			log.Printf("pkg get user info invalid uid:%d", uid)
			return nil
		}
		return (*C.struct_nos_user_info)(unsafe.Pointer(&NosUsers[uid]))
	}
	log.Printf("Get UserInfo[%d] magic[%x] flow_magic[%x]\n", p.FlowID, p.FlowMagic, flow.magic)
	return nil
}

func (p *NosPacketSt) GetUserAuthStatus(isSrc bool) uint8 {
	uinfo := p.GetUserInfo(isSrc)
	if uinfo != nil {
		return uint8(uinfo.status & 0xff)
	}
	return 0xff
}

func (p *NosPacketSt) GetUserGroupName() (string, string) {
	u := p.GetUserInfo(true)
	if u != nil {
		ulen := C.int(u.uname[0])
		glen := C.int(u.gname[0])
		return C.GoStringN((*C.char)(unsafe.Pointer(&u.uname[1])), ulen), C.GoStringN((*C.char)(unsafe.Pointer(&u.gname[1])), glen)
	}
	return "", ""
}

func (p *NosPacketSt) GetUserName() string {
	u := p.GetUserInfo(true)
	if u != nil {
		ulen := C.int(u.uname[0])
		return C.GoStringN((*C.char)(unsafe.Pointer(&u.uname[1])), ulen)
	}
	return ""
}

func (p *NosPacketSt) GetGroupName() string {
	u := p.GetUserInfo(true)
	if u != nil {
		glen := C.int(u.gname[0])
		return C.GoStringN((*C.char)(unsafe.Pointer(&u.gname[1])), glen)
	}
	return ""
}

func (p *NosPacketSt) GetPeerIp() (uint32, bool) {
	uinfo := p.GetUserInfo(false)
	if uinfo != nil {
		return uint32(uinfo.ip), true
	}
	return 0xffffffff, false
}

func (p *NosPacketSt) GetUserIp(isSrc bool) (uint32, bool) {
	uinfo := p.GetUserInfo(isSrc)
	if uinfo != nil {
		return uint32(uinfo.ip), true
	}
	return 0xffffffff, false
}

func (p *NosPacketSt) GetUserStats() *NosUserStat {
	var stat NosUserStat
	uinfo := p.GetUserInfo(true)
	if uinfo != nil {
		stat.Conn_counter = uint64(uinfo.refcnt)
		stat.Xmit_bytes = uint64(uinfo.xmit_bytes)
		stat.Recv_bytes = uint64(uinfo.recv_bytes)
		stat.Xmit_limits = uint16(uinfo.xmit_limits)
		stat.Recv_limits = uint16(uinfo.recv_limits)
		return &stat
	}
	return nil
}

func GetUsserIdByIpSlow(ip uint32) uint64 {
	for i := 0; i < len(NosUsers); i++ {
		if NosUsers[i].magic&1 == 0 && ip == uint32(NosUsers[i].ip) {
			uid := uint64(NosUsers[i].magic)
			uid = uid<<32 | uint64(NosUsers[i].ip)
			return uid
		}
	}
	return 0
}

func (p *NosPacketSt) GetUID(isSrc bool) uint64 {
	uinfo := p.GetUserInfo(isSrc)
	if uinfo != nil {
		uid := uint64(uinfo.magic)
		uid = uid<<32 | uint64(uinfo.id)
		return uid
	}
	return 0
}

func (p *NosPacketSt) GetUserId() uint64 {
	return p.GetUID(true)
}

func (p *NosPacketSt) GetPeerId() uint64 {
	return p.GetUID(false)
}

func (p *NosPacketSt) GetUserMac() [6]uint8 {
	addr, ok := p.GetUserIp(true)
	if ok {
		if addr == p.Frame.Ip_src {
			return p.Frame.Mac_src
		} else {
			return p.Frame.Mac_dst
		}
	}
	return p.Frame.Mac_src
}

func (p *NosPacketSt) GetMacSrc() [6]uint8 {
	return p.Frame.Mac_src
}

func (p *NosPacketSt) GetMacDst() [6]uint8 {
	return p.Frame.Mac_dst
}

func (p *NosPacketSt) GetL4Payload() ([]byte, uint16) {
	return p.Buffer[:], p.Frame.Size
}

func (p *NosPacketSt) GetL7Payload() ([]byte, uint16) {
	offset := p.Frame.L7Offset
	return p.Buffer[offset:], p.Frame.Size - p.Frame.L7Offset
}

func (p *NosPacketSt) GetFlowInfo() *C.struct_nos_flow_info {
	if p.FlowID >= C.NOS_FLOW_TRACK_MAX {
		log.Printf("pkg get flow info invalid fid: %d\n", p.FlowID)
		return nil
	}
	flow := &NosFlows[p.FlowID]
	if uint32(flow.magic) == p.FlowMagic {
		return (*C.struct_nos_flow_info)(unsafe.Pointer(flow))
	}
	return nil
}

func (p *NosPacketSt) GetSessionId() uint64 {
	session_id := uint64(p.FlowMagic)
	session_id = session_id<<32 | uint64(p.FlowID)
	return session_id
}

func (p *NosPacketSt) GetFlowStatus(status uint32) uint32 {
	info := p.GetFlowInfo()
	if info != nil {
		return uint32(info.status) & status
	}
	return 0
}

func (p *NosPacketSt) GetFlowStat() *NosFlowStat {
	var stat NosFlowStat
	info := p.GetFlowInfo()
	if info != nil {
		stat.Up_bytes = uint64(info.up_bytes)
		stat.Dn_bytes = uint64(info.down_bytes)
		stat.Up_pkgs = uint64(info.up_pkgs)
		stat.Dn_pkgs = uint64(info.down_pkgs)
		return &stat
	}
	return nil
}

func (p *NosPacketSt) GetFlowTuple() *NosTuple {
	var tuple NosTuple
	info := p.GetFlowInfo()
	if info != nil {
		tuple.Src = uint32(info.tuple.ip_src)
		tuple.Dst = uint32(info.tuple.ip_dst)
		tuple.Sport = uint16(info.tuple.port_src)
		tuple.Dport = uint16(info.tuple.port_dst)
		tuple.Proto = uint8(info.tuple.proto)
		tuple.Dir = uint8(info.tuple.dir)
		return &tuple
	}
	return nil
}

func (p *NosPacketSt) GetFlowSrc() uint32 {
	info := p.GetFlowInfo()
	if info != nil {
		return uint32(info.tuple.ip_src)
	}
	return 0
}

func (p *NosPacketSt) GetFlowDst() uint32 {
	info := p.GetFlowInfo()
	if info != nil {
		return uint32(info.tuple.ip_dst)
	}
	return 0
}

func (p *NosPacketSt) GetFlowUpPkgs() uint64 {
	info := p.GetFlowInfo()
	if info != nil {
		return uint64(info.up_pkgs)
	}
	return 0
}

func (p *NosPacketSt) GetFlowReserved() []uint8 {
	info := p.GetFlowInfo()
	if info != nil {
		return *(*[]uint8)(unsafe.Pointer(&info.reserved[0]))
	}
	return nil
}

func (p *NosPacketSt) GetDpiRuleId() uint16 {
	info := p.GetFlowInfo()
	if info != nil {
		return uint16(info.rule_id)
	}
	return 0
}

func (p *NosPacketSt) GetDpiAppId() uint16 {
	info := p.GetFlowInfo()
	if info != nil {
		return uint16(info.app_id)
	}
	return 0
}

func (p *NosPacketSt) GetLineNo() int8 {
	info := p.GetFlowInfo()
	if info != nil {
		return int8(info.line_no)
	}
	return 127
}

func (p *NosPacketSt) GetFrameTimeStamp() uint64 {
	return p.Frame.TimeStamp
}

func (p *NosPacketSt) GetFlowDir() uint16 {
	info := p.GetFlowInfo()
	if info != nil {
		return uint16(info.tuple.dir)
	}
	return NOS_FLOW_DIR_UNKNOWN
}

/************* 消息通知接口 ***************/
func GetDropReason(reason int) string {
	if v, ok := dropReason[reason]; ok {
		return v
	}
	for k, v := range dropReason {
		if reason&k != 0 {
			return v
		}
	}
	return "未知原因"
}

/*用户层消息接口*/
/*初始化接口*/
func NlumsgInit() int32 {
	C.nos_nlumsg_init((*C.struct_go_slice)(unsafe.Pointer(&NosUsers)), (*C.struct_go_slice)(unsafe.Pointer(&NosFlows)))
	travFlow()
	return 0
}

/*清理接口*/
func NlumsgCleanup() {
	C.nos_nlumsg_cleanup()
}

/*
 * 发送命令给内核
 * @cmd 命令识别字段
 * @参数列表
 *
 * @return 成功0, 否则出错.
 * int nos_nlcmd2kernel(int cmd, int argc, int *args);
 */
func Nlcmd2kernel(cmd uint32, args []uint32) int32 {
	argc := len(args)
	if argc == 0 {
		args = append(args, 0)
	}
	if argc > NLMSG_MAX_U32_PARS_NUM {
		log.Fatalln("传入参数过多.")
	}
	return int32(C.nos_nlcmd2kernel(C.uint32_t(cmd), C.uint32_t(argc), (*C.uint32_t)(unsafe.Pointer(&args[0]))))
}

/*
 * 发送通知命令到内核系统中的某个指定节点
 * (可能是flow,也可能是某个user
 * 具体看参数ct/usrc_ip/udst_ip的设置).
 *
 * @sip, 连接发起用户的ip
 * @dip, 连接目标节点的ip
 * @sport, dport, proto. 端口和协议号.
 * @cmd, 命令类型
 * @args, 参数数组.
 *
 * @return 0 发送成功.
 *
 * int nos_nlcmd2target( unsigned long ct, unsigned int sip, unsigned int dip,
 *                            int cmd, int argc, int *args);
 */
func Nlcmd2target(
	sip uint32, dip uint32, sport uint16, dport uint16, proto uint8,
	cmd uint32, args []uint32) int32 {
	//处理参数个数
	argc := len(args)
	if argc == 0 {
		args = append(args, 0)
	}
	if argc > NLMSG_MAX_U32_PARS_NUM {
		log.Fatalln("参数过多...")
	}
	return int32(C.nos_nlcmd2target(
		C.uint32_t(sip), C.uint32_t(dip), C.uint16_t(sport), C.uint16_t(dport), C.uint8_t(proto),
		C.uint32_t(cmd), C.uint32_t(argc), (*C.uint32_t)(unsafe.Pointer(&args[0]))))
}

func Nlcmd2Flow(SID uint64, cmd uint32, args []uint32) int32 {
	//直接通知应用层映射内存块
	argc := len(args)
	if argc == 0 {
		args = append(args, 0)
	}
	if argc > NLMSG_MAX_U32_PARS_NUM {
		log.Fatalln("参数过多...")
	}
	return int32(C.nos_nlcmd2flow(
		C.uint64_t(SID), C.uint32_t(cmd), C.uint32_t(argc), (*C.uint32_t)(unsafe.Pointer(&args[0]))))
}

func Nlcmd2User(UID uint64, cmd uint32, args []uint32) int32 {
	argc := len(args)
	if argc == 0 {
		args = append(args, 0)
	}
	if argc > NLMSG_MAX_U32_PARS_NUM {
		log.Fatalln("参数过多....")
	}

	return int32(C.nos_nlcmd2user(
		C.uint64_t(UID), C.uint32_t(cmd), C.uint32_t(argc), (*C.uint32_t)(unsafe.Pointer(&args[0]))))
}

func NlBuff2User(UID uint64, cmd uint32, buffer []byte) int32 {
	//整块内存,通过内存映射拷贝
	argc := (len(buffer) + 3) / 4
	if argc > (NLMSG_MAX_U32_PARS_NUM) {
		log.Fatalln("传入参数过多...")
	}
	return int32(C.nos_nlcmd2user(
		C.uint64_t(UID), C.uint32_t(cmd), C.uint32_t(argc), (*C.uint32_t)(unsafe.Pointer(&buffer[0]))))
}

func Nlbuff2user(src uint32, cmd uint32, buffer []byte) int32 {
	//整块内存拷贝到内核,通过netlink消息.
	argc := (len(buffer) + 3) / 4
	if argc > (NLMSG_MAX_U32_PARS_NUM) {
		log.Fatalln("传入参数过多...")
	}
	return int32(C.nos_nlcmd2target(C.uint32_t(src), 0, 0, 0, 0,
		C.uint32_t(cmd), C.uint32_t(argc), (*C.uint32_t)(unsafe.Pointer(&buffer[0]))))
}

/*接受消息*/
func NlumsgRecv() ([]byte, int32) {
	buffer := make([]byte, NLMSG_MAX_RCV_BUFF_SIZE)

	return buffer, int32(C.nos_nlumsg_recv(unsafe.Pointer(&buffer[0]), NLMSG_MAX_RCV_BUFF_SIZE))
}
