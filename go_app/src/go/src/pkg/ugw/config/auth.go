package config

import (
	"hash/crc64"
)

const (
	AUTHPOLICY       = "Auth.AuthPolicy"
	GLOBLEAUTHOPTION = "Auth.GlobaleAuthOption"
	AID_AUTH_POLICY  = "Auth.AIDAuthPolicy"
)

type AuthConfig struct {
	AuthPolicy        []AuthPolicy      //认证策略
	AIDAuthPolicy     AIDAuthPolicy     //AID 策略
	GlobaleAuthOption GlobaleAuthOption //认证选项
}

type IpRange struct {
	Start    string
	StartNIP uint32
	End      string
	EndNIP   uint32
}

type AutoAuthPolicy struct { //自动认证策略
	BindType     uint8  //绑定方式，IP，MAC，IP+MAC
	AutoAuthType uint8  //允许添加到本地组，仅作为guest用户在线（不添加到本地在线用户列表），不允许新用户认证
	GroupName    string //组名
}

type WebAuthPolicy struct { //web认证策略
	AllowRegist uint8  //1.允许注册web认证用户,2.允许手机号注册
	AllowOnline uint8  //允许新注册web认证用户上网
	BindType    uint8  //绑定方式，IP, MAC, IP+MAC
	Tips        string //提示消息
}

type SMS_Server struct {
	Host    string //host
	DefHost string //default host
	Port    uint32 //port
}

type AIDAuthPolicy struct {
	SMS_TYPE       uint8 //短信认证供应商类型
	SMS_SNO        string
	SMS_KEY        string
	SMS_USR        string
	SMS_PWD        string
	SMS_MSG        string
	SMS_SGN        string //认证短信签名
	SMS_SUC_CNT    int    //短信发送条数，成功
	SMS_FAIL_CNT   int    //短信发送条数，失败
	DefGroupName   string
	DefExpireDay   uint32
	DefEnable      uint8
	CheckEveryTime string
}

//认证策略信息（用于保存认证策略）
type AuthPolicy struct {
	AuthPolicyId   uint64         //全局唯一用户认证策略id
	AuthPolicyName string         //认证策略名
	AuthPolicyDesc string         //认证策略描述
	AuthType       uint8          //认证方式(目前仅支持web认证，自动认证)
	Enable         uint8          //策略是否启用
	IpRange        []IpRange      //该该策略生效的ip范围（网络字节序）
	AutoAuthPolicy AutoAuthPolicy //自动认证选项
	WebAuthPolicy  WebAuthPolicy  //web认证选项
}

//全局的用户策略信息
type GlobaleAuthOption struct {
	ServName          string    //服务账号
	ServPswd          string    //服务密码
	ControlCenter     string    //中心端
	ThirdAuthCenter   string    //第三方认证中心地址
	DeviceName        string    //当前设备在中心端的显示名
	RedictUrl         string    //认证成功后的跳转url地址
	CheckOffline      uint32    //下线检测间隔
	PushInterVal      int32     //推送间隔，-1，不推送；0,上线时推送；其他，间隔推送，单位小时
	RangeEnable       int32     //是否开启推送范围检查
	AccessAfterPushed int32     //推送之后才允许访问网络
	PushRange         []IpRange //推送IP范围
	PushTitle         string    //推送页面的标题
	L3Switch          uint8     //三层交换环境
	Auth_White_List   []string
}

func (authpolicy *AuthPolicy) OnNew() bool {
	authpolicy.AuthPolicyId = crc64.Checksum([]byte(authpolicy.AuthPolicyName), crc64.MakeTable(crc64.ECMA))
	return true
}

func (u *AuthConfig) OnAuthPolicyInsert(auth []AuthPolicy, i int, val *AuthPolicy) bool {

	if val.AuthPolicyName == "" || len(val.IpRange) == 0 {
		return false
	}

	for i := 0; i < len(val.IpRange); i++ {
		if !IsVaildIP(val.IpRange[i].Start) || !IsVaildIP(val.IpRange[i].End) {
			return false
		}
	}

	go notifyAuthd("insertpolicy", "")
	return true
}

func (u *AuthConfig) OnAuthPolicyUpdate(auth []AuthPolicy, i int, val *AuthPolicy) bool {
	if val.AuthPolicyName == "" || len(val.IpRange) == 0 {
		return false
	}

	for i := 0; i < len(val.IpRange); i++ {
		if !IsVaildIP(val.IpRange[i].Start) || !IsVaildIP(val.IpRange[i].End) {
			return false
		}
	}
	val.AuthPolicyId = crc64.Checksum([]byte(val.AuthPolicyName), crc64.MakeTable(crc64.ECMA))
	go notifyAuthd("updatepolicy", "")
	return true
}

func (u *AuthConfig) OnAuthPolicyDelete(auth []AuthPolicy, i int, val *AuthPolicy) bool {
	go notifyAuthd("deletepolicy", "")
	return true
}

func (u *AuthConfig) OnAuthPolicySwap(auth []AuthPolicy, i, j int) bool {
	go notifyAuthd("swappolicy", "")
	return true
}

func (u *AuthConfig) OnGlobaleAuthOptionSet(val *GlobaleAuthOption) bool {
	go notifyAuthd("setauthoption", "")
	return true
}

func (g *GlobaleAuthOption) OnPushInterValSet(val int32) bool {
	go notifyAuthd("setauthoption", "")
	return true
}
