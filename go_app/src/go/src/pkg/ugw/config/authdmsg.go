package config

/*消息接口，用于获取消息类型*/
//////////////////////////////////////////

//用户登录信息
type LoginInfoMsg struct {
	UgwId       string //用户所在设备id
	DeviceName  string //设备显示名
	UserName    string
	Password    string
	IP          string
	Mac         string
	DevType     int    //终端类型
	DevTypeName string //终端类型名称
}

//修改密码信息
type ChangePwdMsg struct {
	UserName string
	Password string
}

//用户漫游信息
type RoamingInfoMsg struct {
	IP         string
	Mac        string
	DeviceName string
}

//用户状态更新信息
type UpdateStautsMsg struct {
	UserName string
	Mac      string
	Status   uint8
}

//用户在线时间更新
type ActiveUserMsg struct {
	Mac         string
	DevType     int    //终端类型
	DevTypeName string //终端类型名称
	DeviceName  string
	TimeActive  uint64
	TimeAuthed  int64
}

//手机注册信息
type PhoneRegMsg struct {
	Mac     string
	PhoneNo string
}

/*客服端与服务端通信的消息定义*/
type AuthdMsg struct {
	MsgType string
	MsgBody interface{}
}

/*回复内容*/
type AuthdReply struct {
	ResCode    int         //返回码
	ResMsgBody interface{} //返回详细结果体
}

/*广告模版（重定向登录页）同步*/
type AdsSyncInfo struct {
	Account  string
	Password string
	AdsMD5   string
	UgwId    string //有设备名时传递设备名，无设备名传网关ID
}

type AdsTplInfo struct {
	Filename string
	Filesize int
	FileMD5  string
	Filebody []byte
}

type RemoteMsg struct {
	HostInfo []byte
	KeyInfo  []byte
}

func CreateAuthdMsg(msgType, msgBody interface{}) *AuthdMsg {
	var authdMsg AuthdMsg
	authdMsg.MsgType = msgType.(string)
	authdMsg.MsgBody = msgBody
	return &authdMsg
}
