package config

import (
	"crypto/des"
	"crypto/dsa"
	"fmt"
	"io"
	"log"
	"math/big"
	"net"
	"os"
	"os/exec"
	"pkg/ugw/log/sys"
	"strings"
	"time"
)

const (
	NORMAL    = 0 //序列号正常
	SnDISABLE = 1 //功能未启用
	EXPIRED   = 2 //序列号过期

	SN_MAX_NUM = 9 //序列号支持的模块个数
)

/*序列号*/
type SerialNum struct {
	Module   string //序列号对应的模块
	Status   uint16 //序列号状态
	Deadline string //序列号过期时间
}

type SnConfig struct {
	SNIterms map[string]*SerialNum //序列号名称（功能模块名）
	Sn       string                //当前网关序列号
}

/*功能模块有效性验证--相关数据结构*/
type module_info struct {
	mod_id   uint8  //模块ID
	deadline uint32 //模块有效期
}

type SerialNumber struct {
	mods     [SN_MAX_NUM]module_info //目前支持9个模块开启序列号功能
	versionA uint8                   //主版本号
	versionB uint8                   //次版本号
	remain   uint8                   //保留
}

/*
函数功能：获取网关ID,网关ID不存储在设备上，
          每次加载时动态的计算出来
*/
func (snf *SnConfig) GetDeviceID() (devid string) {

	//var key = []byte{0xca, 0x8f, 0xca, 0x1f, 0x50, 0xc5, 0x7b, 0x49}
	plain_exp := append(getMACAddr("lan0"), 0xff, 0xff)

	out := make([]byte, len(plain_exp))
	// log.Println(plain_exp, "------------------")
	block, err := des.NewCipher(plain_exp)
	if err != nil {
		log.Panicln("Exec NewCipher Error!", err)
	}
	dids := getDiskId()
	cids := getCpuId()
	for i := 0; i < len(dids) && i < len(cids); i++ {
		dids[i] = dids[i] | ^cids[i]
	}
	//block.Encrypt(out, plain_exp)
	block.Encrypt(out, dids)

	return fmt.Sprintf("%02X", out)

}

/*内部函数：获取MAC地址*/
func getMACAddr(ethx string) []byte {
	infs, err := net.Interfaces()
	if err != nil {
		log.Panicln("EXEC Interfaces() Error!", err)
	}

	for _, v := range infs {
		log.Println(v)
		if v.Name == ethx {
			return v.HardwareAddr
			break
		}
	}
	return nil
}

/*获得硬盘的Id*/
func getDiskId() []byte {
	cmd := exec.Command("sh", "-c", `fdisk -l | grep identifier | awk -F: '{print $2}' | awk -F' ' '{print $1}'`)
	buf, err := cmd.Output()
	if err != nil {
		log.Panicln("EXEC Interfaces() Error!", err)
	}
	//buf 内容形如0x4f08521a
	buf = buf[2:] //去掉0x
	if len(buf) > 8 {
		buf = buf[:8]
	}
	buf = []byte(strings.ToUpper(string(buf)))
	//fmt.Printf("ddk is %s, len is %d\n", string(buf), len(buf))
	for i := 0; i < len(buf); i++ {
		var val byte
		if buf[i] >= '0' && buf[i] <= '9' {
			val = buf[i] - '0'
		} else {
			val = buf[i] - 'A' + 10
		}
		buf[i] = val
	}
	for i := 0; i < 8-len(buf); i++ {
		buf = append(buf, 0xff)
	}
	// fmt.Printf("ddk is %02X, len is %d\n", buf, len(buf))
	return buf
}

/*获得cpuid*/
func getCpuId() []byte {
	cmd := exec.Command("sh", "-c", `dmidecode -t 4 | grep ID | head -n 1 | awk -F: '{print $2}'`)
	buf, err := cmd.Output()
	if err != nil {
		log.Panicln("EXEC Interfaces() Error!", err)
	}
	cpuid := strings.ToUpper(strings.Replace(string(buf), " ", "", -1))
	//fmt.Printf("ccpx is %s, len is %d\n", cpuid, len(cpuid))
	var res [8]byte
	var i int = 0
	var cur int = 0
	var first bool = true
	for ; i < len(cpuid) && i < 16 && cpuid[i] != '\n'; i++ {
		var val byte
		if cpuid[i] >= '0' && cpuid[i] <= '9' {
			val = cpuid[i] - '0'
		} else {
			val = cpuid[i] - 'A' + 10
		}
		cur = i / 2
		if first == true {
			first = false
			res[cur] = val << 4
		} else {
			first = true
			res[cur] = res[cur] | val
		}
	}
	for i := cur + 1; i < len(res); i++ {
		res[i] = 0xff
	}
	// fmt.Printf("ccpx is %02X, len is %d\n", res[:], len(res))
	return res[:]
}

//todo 配置提交通知

/*
合法性检测数字签名
96个字节的序列号
64个字节的签名签名信息
16个字节的网关ID
*/
func (snc *SnConfig) OnSnSet(snid string) bool {
	log.Println("Start on sn set....")
	/*序列号中包括了网关ID信息，验证当前网关ID的合法性*/
	if snid == "" {
		return false
	}

	/*验证网关ID有效性，网关ID应该与序列号中的网关ID一致*/
	infos := strings.SplitN(snid, "-", -1) //infos[0]:sn  infos[1]:r  infos[2]:s infos[3]:id
	if infos[3] != snc.GetDeviceID() {
		return false
	}

	/*验证License有效性*/
	if Verify_License(snid) == false {
		return false
	}

	log.Println("Verfiy ok ...")

	/*将序列号信息(状态、有效期)写入配置*/
	// snc.Check_expired(snid, "AV_SN")
	// snc.Check_expired(snid, "DPI_SN")
	// snc.Check_expired(snid, "UPDATE_SN")
	// snc.Check_expired(snid, "URL_SN")
	snc.Check_expired(snid, "AP_MANAGLE")
	snc.Check_expired(snid, "URLLOG")

	log.Println("Check expired ok....")

	return true
}

/*验证License的合法性*/
func Verify_License(license string) bool {

	var pub dsa.PublicKey

	/*初始化公钥*/
	pub.Y = new(big.Int)
	pub.Parameters.P = new(big.Int)
	pub.Parameters.Q = new(big.Int)
	pub.Parameters.G = new(big.Int)

	pub.Y.SetString("2D55D70BED4453807ACD67E9DFA54048D59EBA08FAD1EBB55239545CEF67028763511D8BF31AC24B6AFB857433A9ACC61246FAC5F32121EBD45C1D30B3C99AEF5258EF561E02993912F0DDD960DFBD6C8471002CA9DE747270F0137B465AD39C971E0AD906623DAB9F8ED2C4C945119C01D9728D13A47A981F4DEB6BCDCA357928F495F88D89FBA61FCF9BDDD1CAF5780CD12D8B15AC80871AAF45D7C98FD1C088492872126072B55F97A48EBB78F00598E01887C2176B02DF59F5C735402D5118FE6EDF0946676705E23384B248F9293033DC1E724DFD71702953934080EE4D4FE79E94021294AF707FD11C1C7A2CF75F433971506D727DB930C240D3FD15B3", 16)
	pub.Parameters.P.SetString("E72361B69CBBF44CD245D7938DE0500CECB3D20DC9882FA118356666215B5BE230EA43800EA6D920CFCAA5B240AAD3BBAFBF88A05813B7B301C5C6CCF3EA0DC89CA013E350D5BA202D040DC540512317D1D720790DCCBD1FCE4816269D77F7B0A4211395F2FD73F7C5E54EF1F8A63CE4A80C4419D23292FB73397B558010567FDB0F654A246E68C7DE17E8952B159C86A5BEA3FB8A5159CB156DDCE16D2BBBBDD1D9DDD61764D9C7230B1C0DBFF4428E9FF9846DE9181CE5129C459DB08C79CE6E543D4C7090C173DA0408ECBAF77979CD4EF121615369FC2C8529FAD3FA911993A80B474D4F5A308B30F318BA3634AEFD9D916D27E0F26EEB423B827BAA0839", 16)
	pub.Parameters.Q.SetString("FBB3B7D5298473BEAE3AB0090FC9D59E85AA7B7A8C3DD0B9CC6DA4ECB3DF7BE9", 16)
	pub.Parameters.G.SetString("8544A32B01DE75A634900AE1B123E504F80257201AF7390C48C72C8C3EA37784CB1E5C20E9D882D7B1C526BA651A78E505B3F3A26BF8DD3FA04961AFEC92D7485B2CC7D3E264D514582213B64882630554D5796556AAA2A2DBA4CD4F9EA2D3FE34F8D802986AB014C57BB6139654187EFE58C6363D2BB353BE868B6AF4009FB9B83FB02630A0FC9C308B4446C657282390DD65F51D5CC072F2EEDCEBAC450DBB2CE9280DE9C1D7DD844E258D312C57FBBDAFFA97DDC4CFE9AD0C7314F5DED92FEBF67E4B573E6DC1093ED038A0371A7FA787A048DF282B666C5B3252CAE7DBBBDEBD7075AC642916D381C52ADC56935A51FC7C6D45E12AFB2D35C6A716B70F5F", 16)

	/*初始化签名信息*/
	r := new(big.Int)
	s := new(big.Int)

	infos := strings.SplitN(license, "-", -1) /*infos[0]:sn  infos[1]:r  infos[2]:s infos[3]:id*/
	r.SetString(infos[1], 16)
	s.SetString(infos[2], 16)

	/*验证license合法性*/
	if dsa.Verify(&pub, []byte(infos[0]+infos[3]), r, s) {
		return true
	} else {
		log.Println("License verify False!")
		return false
	}
	return true
}

/*验证模块功能开启的有效期*/
/*	var sn_id = []byte{
	0x00, 0x00, 0x00, 0x00, 0x00, //每行第一个字节表示“模块”，后面4个字节表示到期时间,全0表示未开启。
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00}*/

func (snf *SnConfig) Get_Module_deadline(snid string, module_name string) string {
	var sn SerialNumber

	infos := strings.SplitN(snid, "-", -1) //infos[0]:sn  infos[1]:r  infos[2]:s infos[3]:id

	buf := make([]byte, len(infos[0])/2)
	for i := range buf {
		fmt.Sscanf(infos[0][:2], "%2X", &buf[i])
		infos[0] = infos[0][2:]
	}

	for i := range sn.mods {
		mod := &sn.mods[i]
		mod.mod_id = uint8(buf[0])
		mod.deadline = uint32(buf[1])<<24 | uint32(buf[2])<<16 | uint32(buf[3])<<8 | uint32(buf[4])
		buf = buf[5:]
	}

	sn.versionA = uint8(buf[0])
	sn.versionB = uint8(buf[1])
	sn.remain = uint8(buf[2])

	switch module_name {
	case "AV_SN":
		log.Println("AV_SN", formatTime(int64(sn.mods[0].deadline)))
		return formatTime(int64(sn.mods[0].deadline))

	case "DPI_SN":
		log.Println("DPI_SN", formatTime(int64(sn.mods[1].deadline)))
		return formatTime(int64(sn.mods[1].deadline))

	case "UPDATE_SN":
		log.Println("UPDATE_SN", formatTime(int64(sn.mods[2].deadline)))
		return formatTime(int64(sn.mods[2].deadline))

	case "URL_SN":
		log.Println("URL_SN", formatTime(int64(sn.mods[3].deadline)))
		return formatTime(int64(sn.mods[3].deadline))

	case "AP_MANAGLE":
		/* 这里保存的是ap个数限制 */
		log.Println("AP_MAN", sn.mods[4].deadline)
		if sn.mods[4].mod_id == 255 {
			return "0"
		}
		return fmt.Sprintf("%d", sn.mods[4].deadline)

	case "URLLOG":
		log.Println("URLLOG", formatTime(int64(sn.mods[3].deadline)))
		return formatTime(int64(sn.mods[5].deadline))

	default:
		log.Println("Para module_name of Get_Module_deadline() error!")

	}
	return "null"
}

/*
函数功能：根据序列号检测各模块的到期时间、状态
函数输出：直接对配置文件进行修改
*/
func (snc *SnConfig) Check_expired(snid string, module_name string) {

	now_day := formatTime(time.Now().Unix())
	date := snc.Get_Module_deadline(snid, module_name)

	//map check
	iterm, ok := snc.SNIterms[module_name]
	if !ok || iterm == nil {
		iterm = &SerialNum{}
		iterm.Status = SnDISABLE
		iterm.Module = ""
		iterm.Deadline = "0"
	}

	if date == "0" { /*未开启此功能*/
		iterm.Status = SnDISABLE
		iterm.Deadline = "-"
	} else if date != "null" {
		/* 无线控制器序列号管理 */
		switch module_name {
		case "AP_MANAGLE":
			iterm.Status = NORMAL
			iterm.Deadline = date /* 可管理的AP个数限制 */
			iterm.Module = "AP控制器"

		case "URLLOG":
			iterm.Status = NORMAL
			iterm.Deadline = date /* 可管理的AP个数限制 */
			iterm.Module = "URL审计"	

		default: /* 之前的那一坨序列号管理. */
			if date > now_day {
				iterm.Status = NORMAL
			} else {
				iterm.Status = EXPIRED
			}
			iterm.Deadline = date
		}
	}
	//write back
	snc.SNIterms[module_name] = iterm
}

/*内部函数：把秒数转化成日期格式
输入：int64型整数1389692064
输出：string 2014-01-14
*/
func formatTime(ssec int64) string {
	if ssec == 0 {
		return "0"
	}

	t := time.Unix(ssec, 0)
	date := strings.SplitN(t.Format("2006-01-02T15:04:05Z07:00"), "T", -1) //RFC3339 = "2006-01-02T15:04:05Z07:00" //RFC3339 = "2006-01-02T15:04:05Z07:00"
	return date[0]

}

/*备份SN配置文件
函数功能：每次保存网关序列号成功之后，对sn.json文件备份，
          避免每次恢复默认配置后，导致序列号丢失。
*/
func (snf *SnConfig) SN_bak() bool {

	err := os.MkdirAll("/ugw/etc/un_recover/", 0666)
	if err != nil {
		syslog.Debug("mkdirall /ugw/etc/un_recover failed,%s", err)
		fmt.Println(err.Error())
		return false
	}

	_, err = CopyFile("/tmp/config/sn.json", "/ugw/etc/un_recover/sn.json")
	if err != nil {
		syslog.Debug("copyfile sn failed: %s", err)
		fmt.Println(err.Error())
		return false
	}

	return true

}

func CopyFile(src, dst string) (w int64, err error) {
	srcFile, err := os.Open(src)
	if err != nil {
		fmt.Println(err.Error())
		return
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)

	if err != nil {
		fmt.Println(err.Error())
		return
	}

	defer dstFile.Close()

	return io.Copy(dstFile, srcFile)

}

/*
函数功能: 检查序列号是否过期，重新设置状态.
*/
func Check_Expired() bool {

	var snid string

	err := Eval(`SN.Sn`, &snid)
	if err != nil {
		log.Printf("Get SN failed, Err: %s\n", err)
		return false
	}

	var ret bool
	err = Eval(fmt.Sprintf(`SN.Sn.set(%q)`, snid), &ret)

	if err != nil || !ret {
		log.Printf("Set SN failed, Err: %s\n", err)
		return false
	}
	return true
}

/*
函数功能: 如果序列号不正确, 死循环30秒检查一次. 直到正常.
*/
func Check_SN() bool {
	var snid string
	var snc SnConfig
	err := Eval(`SN.Sn`, &snid)
	if err != nil {
		log.Printf("Get SN failed, Err: %s\n", err)
		return false
	}

	/*验证网关ID有效性，网关ID应该与序列号中的网关ID一致*/
	infos := strings.SplitN(snid, "-", -1) //infos[0]:sn  infos[1]:r  infos[2]:s infos[3]:id
	if infos[3] != snc.GetDeviceID() {
		return false
	}

	// 验证序列号有效性
	return Verify_License(snid)
}

func Check_URLLOG() bool {
	var snid string
	var snc SnConfig
	err := Eval(`SN.Sn`, &snid)
	if err != nil {
		log.Printf("Get SN failed, Err: %s\n", err)
		return false
	}
	dline := snc.Get_Module_deadline(snid, "URLLOG")
	if dline == "0" || dline == "null" {
		fmt.Println("URLLOG disable", dline)
		return false
	}
	
	return true
}

/*
 */
func ModulesCheckSN() {
	for Check_SN() != true {
		//syslog.Error("SN check failed.\n")
		err := exec.Command("touch", "/tmp/serialnumber_invalid").Run()
		if err != nil {
			fmt.Println("touch invalid flag", err)
		}
		time.Sleep(30 * time.Second)
	}
	err := exec.Command("rm", "/tmp/serialnumber_invalid").Run()
	if err != nil {
		fmt.Println("remove invalid flag", err)
	}
}

func GetDeviceID() string {
	var snc SnConfig
	return snc.GetDeviceID()
}