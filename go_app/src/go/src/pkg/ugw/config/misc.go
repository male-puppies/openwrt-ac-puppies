package config

import (
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"time"
)

/*
type IpRange struct {
	Start    string
	StartNIP uint32
	End      string
	EndNIP   uint32
}
*/
//IP相关
/*检查一个字符串是否为合法的ip地址
返回：
true 是
false 不是
*/
func IsVaildIP(sip string) bool {
	return nil != net.ParseIP(sip)
}

/*检查一个字符串是否为合法的mac地址
返回：
true 是
false 不是
*/
func IsVaildMAC(smac string) bool {
	_, err := net.ParseMAC(smac)
	if err != nil {
		return false
	}
	return true
}

/*网络字节序转换为主机字节序*/
func Ntohl(ip uint32) uint32 {
	buf := make([]uint8, 4)
	binary.BigEndian.PutUint32(buf, ip)
	return binary.LittleEndian.Uint32(buf)
}

/*将主机字节序转换为网络字节序*/
func Htonl(ip uint32) uint32 {
	buf := make([]uint8, 4)
	binary.LittleEndian.PutUint32(buf, ip)
	return binary.BigEndian.Uint32(buf)
}

/*根据x.x.x.x格式Ip取得主机字节序ip*/
func GetHlIP(sip string) (uint32, error) {

	ipsrc := net.ParseIP(sip)

	if ipsrc == nil {
		return 0, errors.New("bad ip format")
	}

	ipv4 := ipsrc.To4()

	if ipv4 == nil {
		return 0, errors.New("bad ip format")
	}
	return binary.LittleEndian.Uint32(ipv4), nil
}

/*根据x.x.x.x格式Ip取得网络字节序ip*/
func GetNlIP(sip string) (uint32, error) {

	hip, err := GetHlIP(sip)
	if err != nil {
		return 0, err
	}
	return Htonl(hip), nil
}

/*
将网络序转换为字符串形式
输入：网络序节序的网络地址
输出：x.x.x.x式地址(205.239.171.205)
*/
func NIPToString(ip uint32) string {
	buf := make([]uint8, 4)
	binary.BigEndian.PutUint32(buf, ip)
	return fmt.Sprintf("%v.%v.%v.%v", buf[0], buf[1], buf[2], buf[3])
}

/*
主机序转换为字符串形式
输入：主机序节序的网络地址
输出：x.x.x.x式地址(205.239.171.205)
*/
func HIPToString(ip uint32) string {
	return NIPToString(Htonl(ip))
}

/*通过掩码判断两个ip是否在同一网段*/
func IsSameNetSection(ip1 string, ip2 string, mask string) bool {
	var ipv4mask net.IPMask
	if len(mask) < 7 {
		var imask int
		fmt.Sscanf(mask, "%d", &imask)
		maskip := net.CIDRMask(imask, 32)
		ipv4mask = net.IPv4Mask(maskip[0], maskip[1], maskip[2], maskip[3])
	} else {
		maskip := net.ParseIP(mask).To4()
		ipv4mask = net.IPv4Mask(maskip[0], maskip[1], maskip[2], maskip[3])
	}
	return net.ParseIP(ip1).To4().Mask(ipv4mask).Equal(net.ParseIP(ip2).To4().Mask(ipv4mask))
}

func ConvertMask(mask string) string {
	if len(mask) < 7 {
		var imask int
		fmt.Sscanf(mask, "%d", &imask)
		maskip := net.CIDRMask(imask, 32)
		return fmt.Sprintf("%v.%v.%v.%v", maskip[0], maskip[1], maskip[2], maskip[3])
	} else {
		return mask
	}
}

func CalcBrd(ip string, mask string) (brd string, err error) {
	var a1, a2, a3, a4, m1, m2, m3, m4 uint8

	fmt.Sscanf(ip, "%d.%d.%d.%d", &a1, &a2, &a3, &a4)
	fmt.Sscanf(ConvertMask(mask), "%d.%d.%d.%d", &m1, &m2, &m3, &m4)

	fmt.Printf("\tip[%s]: %v.%v.%v.%v \n\t--- mask[%s]: %v.%v.%v.%v\n",
		ip, a1, a2, a3, a4, ConvertMask(mask), m1, m2, m3, m4)

	return fmt.Sprintf("%v.%v.%v.%v", a1|^m1, a2|^m2, a3|^m3, a4|^m4), nil
}

////////////////////////////////////////////////////////////
//时间相关
/*取得当前日期，格式20120101*/
func GetCurrentDay() string {
	y, m, d := time.Now().Date()
	return fmt.Sprintf("%04d%02d%02d", y, m, d)
}
