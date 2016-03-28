package config

import (
	"hash/crc64"
)

const (
	USERINFO = "User.Users"
)

const (
	ONLINELIST  = "/tmp/onlineuser"     //在线用户列表
	AUTHRINGBUF = "/tmp/ringpkgs_authd" //环形缓冲区文件
)

//认证类型
const (
	PROHIBIT  = 0 //禁止认证
	WEBAUTH   = 1 //web认证
	AUTOAUTH  = 2 //自动认证
	GUESTAUTH = 3 //访客模式

)

//账号状态
const (
	DISABLE        = 0 //禁用
	ENABLE         = 1 //启用
	UNAUDIT        = 2 //未审核能上网
	UNAUDITDISABLE = 3 //未审核不能上网
)

//绑定方式
const (
	BIND_NONE  = 0 //不绑定
	BIND_IP    = 1 //绑定ip
	BIND_MAC   = 2 //绑定mac
	BIND_IPMAC = 3 //绑定ip mac
	BIND_ALL   = 4 //混合绑定, 既有ip，也有mac，也有ip+mac，通过界面添加的用户都认为是这种绑定方式
	BIND_AID   = 5 //身份证号码绑定
)

const (
	UTYPE_NORNAL =  0x00 //普通用户
	UTYPE_SCRATCH = 0x01 //刮刮卡VIP
)

type IPMAC struct {
	Ip  string //ip
	Mac string //mac
}

/*认证过程中用的认证方法*/
type AuthMethod struct {
	IpMac     IPMAC     //待认证的ip+mac
	AuthType  uint8     //认证方式
	BindType  uint8     //绑定方式
	Userinfo  *UserInfo //对应的用户信息
	GroupName string    //所属组
}

//用户信息节点（用于保存用户信息，程序内部使用+页面显示）
type UserInfo struct {
	UserId         uint64  //全局唯一用户id(crc)
	UserName       string  //用户名
	UserDesc       string  //用户描述
	FullAID        string  //身份证认证的完整身份证号码和手机认证专用字段，其他功能请勿用.
	AuthType       uint8   //认证方式
	Status         uint8   //帐号状态，启用，禁用，未审核能上网, 未审核不能上网
	GroupId        uint64  //全局唯一组id
	GroupName      string  //组名
	MultiOnline    uint8   //允许多人使用账号在线
	TimeStamp      int64   //刷身份证录入时的时间戳
	ClientIP       string  //客户端最后一次登录的IP
	LastOnlineTime string  //客户最后一次登录时间
	RegistTime     string  //账号注册时间
	ExpectedTime   string  //帐号超期日期
	ExpiredTime    string  //账号超期时间
	BindType       uint8   //绑定方式
	BindList       []IPMAC //绑定列表，一个帐号可以绑定多个ip和mac
	Password       string  //认证密码
	ProhibitChange uint8   //禁止修改密码 1. 禁止
	ChangePassword uint8   //初次登录需要修改密码
	IsThirdUser    int     //第三方认证用户
	IsPhoneUser    uint8   //是否为手机注册用户
	IsPhoneCheck   uint8   //手机号是否已校验过
	UserType	   uint8   //用户类型	
	VIPDeadline    string  //VIP最后一天
}

func (usr *UserInfo) OnNew() bool {
	usr.UserId = crc64.Checksum([]byte(usr.UserName), crc64.MakeTable(crc64.ECMA))
	usr.GroupId = crc64.Checksum([]byte(usr.GroupName), crc64.MakeTable(crc64.ECMA))
	return true
}

func (usr *UserInfo) OnUserIdSet(val uint64) bool {
	return val == crc64.Checksum([]byte(usr.UserName), crc64.MakeTable(crc64.ECMA))
}

func (usr *UserInfo) OnUserNameSet(val string) bool {
	usr.UserId = crc64.Checksum([]byte(val), crc64.MakeTable(crc64.ECMA))
	return true
}

// 在线用户信息结构（用于显示在线用户信息，程序内部使用）
type UserOnlineInfo struct {
	Uid         uint64 //用于访问用户节点的共享缓存id
	UserId      uint64 //全局唯一用户id(crc)
	UserName    string //用户名
	AuthType    uint8  //认证类型
	GroupId     uint64 //全局唯一组id
	GroupName   string //组名，冗余字段，用户显示
	UserStatus  uint8  //在线状态, 在线/冻结
	IpMac       IPMAC  //使用该帐号的ip和mac
	TimeAuthed  int64  //用户已上线时长，单位分钟
	TimeFrozon  int64  //用户被冻结时长, 单位分钟
	TimeActive  uint64 //用户最后有数据的时间，用于检查超时下线
	PushedTime  uint64 //上一次推送时间
	DevType     int    //设备类型
	DevTypeName string //设备类型名称
	ClientIp    string //接入设备ip
	UgwId       string //上线设备id
	DeviceName  string //上线设备名
	Password    string //密码
	LogInfo     string //上线信息
	ApMac       string //apmac
	SSID        string //ssid
	UserType	uint8   //用户类型	
}

//全局在线用户信息
type UserOnlineInfoMap map[string]*UserOnlineInfo //ip(x.x.x.x) -->User_Online_info

type SmsHInfo struct {
	Status   bool   //是否已发送成功
	SendInfo string //发送信息
	ReSend   bool   //是否需要重新发送
	SendTime string //发送时间
}

type SmsInfo struct {
	SmsMsg        string //msg消息
	OnTimerEnable bool   //是否定时发送
	SendTime      string //定时发送时间
	SendDate      string //定时发送日期
}

type UserConfig struct {
	Users          map[string]*UserInfo
	Sms            SmsInfo
	SmsSendList    map[string]bool      //待发送列表
	SmsHistoryInfo map[string]*SmsHInfo //历史发送信息
}

func (u *UserConfig) OnSmsSendListSet(val map[string]bool) bool {
	vtmp := make(map[string]bool)
	for k, _ := range val {
		var found bool
		for _, user := range u.Users {
			if user.GroupName == k || user.UserName == k || k == "全部用户/组" {
				if user.FullAID != "" && len(user.FullAID) < 15 { //不为身份证
					vtmp[user.UserName] = false
				}
				found = true
			}
		}
		if found == false { //手动添加的其他账号
			vtmp[k] = false
		}
		delete(val, k)
	}
	for k, v := range vtmp {
		val[k] = v
	}
	return true
}

func notifyAuthd(cmd string, arg string) bool {
	return UserAuthdNotify.SendMsg(cmd, []string{arg})
}

//发送短信
func (u *UserConfig) SendSms() bool {
	go notifyAuthd("sendsms", "")
	return true
}

//重新发送
func (u *UserConfig) ReSendSms() bool {
	go notifyAuthd("resendsms", "")
	return true
}

func (u *UserConfig) OnUsersInsert(users map[string]*UserInfo, key string, val *UserInfo) bool {
	go notifyAuthd("insertuser", key)
	return true
}

func (u *UserConfig) OnUsersUpdate(users map[string]*UserInfo, key string, val *UserInfo) bool {
	go notifyAuthd("updateuser", key)
	return true
}

func (u *UserConfig) OnUsersDelete(users map[string]*UserInfo, key string, val *UserInfo) bool {
	go notifyAuthd("deleteuser", key)
	return true
}

func (u *UserConfig) GetGroupUsers() map[string][]string {
	result := make(map[string][]string)
	for k, v := range u.Users {
		result[v.GroupName] = append(result[v.GroupName], k)
	}
	return result
}

func (u *UserConfig) GetSmsGroupUsers() map[string][]string {
	result := make(map[string][]string)
	for k, v := range u.Users {
		if v.FullAID != "" && len(v.FullAID) < 15 { //不为身份证
			result[v.GroupName] = append(result[v.GroupName], k)
		}
	}

	return result
}

func (u *UserConfig) GetSmsGroups() []string {
	var result []string
	tmp_result := make(map[string]bool)
	for _, v := range u.Users {
		if v.FullAID != "" && len(v.FullAID) < 15 { //不为身份证
			tmp_result[v.GroupName] = true
		}
	}
	for k, _ := range tmp_result {
		result = append(result, k)
	}
	return result
}
