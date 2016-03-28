package config

import (
	"os/exec"
	"pkg/eval/evalcli"
)

var (
	cfgcli = evalcli.NewEvalClient("tcp", "127.0.0.1:19999")
)

func Eval(cmd string, res interface{}) error {
	return cfgcli.Eval(cmd, res)
}

func NvramGet(key string, def string) (val string) {
	val = def //FIXME: http_webport
	out, err := exec.Command("nvram", "get", key).Output()
	if err != nil {
		return
	}
	if len(out) > 1 {
		val = string(out[:len(out)-1])
	}
	return
}

////////////////////////////////////////////////////////////////////////////////

type Config struct {
	User          UserConfig          //用户配置
	Group         GroupConfig         //组配置
	Admin         AdminConfig         //管理员账号配置
	SN            SnConfig            //序列号管理
	TC            TCConfig            //流控配置
	AP            APConfig            //无线控制管理结构
	UpdateSetting UpdateSettingConfig //自动升级配置
	TimeSet       TimeSetConfig       //时间管理
	Auth          AuthConfig
	AvoidControl  AvoidControlConfig //免审免控
	//DPI           DPIConfig          //DPI配置
	Ipsec         IpsecConfig
	RDS 		  GRedisConfig 		 //redis connection 
}

