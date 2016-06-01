/*
功能：设备管理->时间设置后台功能:日期、时间设置，网络系统同步
日期：2012-12-31
作者：WJ
*/

package config

import (
	"log"
	"os/exec"
	"time"
)

const (
	INTERVAL_TIMESET = 2 * time.Second
)

type TimeSetConfig struct {
	TimeZone string
	TimeSvr  string
}

/*获取系统时间*/
func (T *TimeSetConfig) GetSysTime() string {
	return time.Now().Format("2006-01-02T15:04:05Z07:00")
}

/*设置系统日期时，需要连带系统时间一起写入*/
func (T *TimeSetConfig) SetSysDate(sdate string) bool {

	//合法性检查TODO，需要防止命令注入
	if sdate == "" {
		return false
	}

	err := exec.Command("date", "-s", sdate).Run()
	if err != nil {
		log.Println("Exec command data -s Failure!")
		return false
	}

	// 系统时间与硬件时钟同步
	/* yjs : 没有时钟硬件，hwclock注释掉
	err = exec.Command("hwclock", "-w").Run()
	if err != nil {
		log.Panicln("Exec command hwclock -w Failure!")
		return false
	}*/

	return true
}

/*设置系统时间*/
func (T *TimeSetConfig) SetSysTime(stime string) bool {

	//合法性检查TODO，需要防止命令注入
	if stime == "" {
		return false
	}

	err := exec.Command("date", "-s", stime).Run()
	if err != nil {
		log.Println("Exec command data -s Failure!")
		return false
	}

	//系统时钟与硬件时钟同步
	/*yjs : 没有时钟硬件，hwclock注释掉
	err = exec.Command("hwclock", "-w").Run()
	if err != nil {
		log.Panicln("Exec command hwclock -w Failure!")
		return false
	}*/

	return true
}

/*设置时间时区*/
func (T *TimeSetConfig) SetSysZone(szone string) bool {

	//合法性检查
	if szone == "" {
		return false
	}
	switch szone {
	case "GMT-12:00":
		return cpTimeZone("/usr/share/zoneinfo/right/Etc/GMT-12")
	case "GMT-11:00":
		return cpTimeZone("/usr/share/zoneinfo/Pacific/Midway")
	case "GMT-10:00":
		return cpTimeZone("/usr/share/zoneinfo/right/Etc/GMT-10")
	case "GMT-09:00":
		return cpTimeZone("/usr/share/zoneinfo/Pacific/Gambier")
	case "GMT-08:00":
		return cpTimeZone("/usr/share/zoneinfo/Canada/Yukon")
	case "GMT-07:00":
		return cpTimeZone("/usr/share/zoneinfo/US/Arizona")
	case "GMT-06:00":
		return cpTimeZone("/usr/share/zoneinfo/Canada/Saskatchewan")
	case "GMT-05:00":
		return cpTimeZone("/usr/share/zoneinfo/America/Cayman")
	case "GMT-04:00":
		return cpTimeZone("/usr/share/zoneinfo/Canada/Pacific")
	case "GMT-03:00":
		return cpTimeZone("/usr/share/zoneinfo/America/Argentina/Buenos_Aires")
	case "GMT-02:00":
		return cpTimeZone("/usr/share/zoneinfo/right/Etc/GMT-2")
	case "GMT-01:00":
		return cpTimeZone("/usr/share/zoneinfo/right/Etc/GMT-1")
	case "GMT":
		//log.Println("GMT")
		return cpTimeZone("/usr/share/zoneinfo/GMT")
	case "GMT+01:00":
		return cpTimeZone("/usr/share/zoneinfo/Europe/Berlin")
	case "GMT+02:00":
		return cpTimeZone("/usr/share/zoneinfo/Africa/Cairo")
	case "GMT+03:00":
		return cpTimeZone("/usr/share/zoneinfo/Europe/Moscow")
	case "GMT+04:00":
		return cpTimeZone("/usr/share/zoneinfo/Asia/Baku")
	case "GMT+05:00":
		return cpTimeZone("/usr/share/zoneinfo/Asia/Tashkent")
	case "GMT+06:00":
		return cpTimeZone("/usr/share/zoneinfo/Asia/Dacca")
	case "GMT+07:00":
		return cpTimeZone("/usr/share/zoneinfo/Asia/Bangkok")
	case "GMT+08:00":
		return cpTimeZone("/usr/share/zoneinfo/Asia/Shanghai")
	case "GMT+09:00":
		return cpTimeZone("/usr/share/zoneinfo/Asia/Tokyo")
	case "GMT+10:00":
		return cpTimeZone("/usr/share/zoneinfo/Australia/Sydney")
	case "GMT+11:00":
		return cpTimeZone("/usr/share/zoneinfo/Pacific/Noumea")
	case "GMT+12:00":
		return cpTimeZone("/usr/share/zoneinfo/Pacific/Fiji")
	default:
		log.Println("Para of TIMEZONE Error!")
	}
	return true

}

/*内部函数供设置时区调用*/
func cpTimeZone(zone_path string) bool {
	//复制相应的文件替换/etc/localtime
	output, err := exec.Command("rm", "-f", "/etc/localtime").CombinedOutput()
	if err != nil {
		log.Printf("Exec command RM timezone Failure! Err output:%s\n", string(output))
	}
	output, err = exec.Command("cp", zone_path, "/etc/localtime", "-f").CombinedOutput()
	if err != nil {
		log.Printf("Exec command COPY timezone Failure! Err output:%s\n", string(output))
		return false
	}

	return true
}

/*同步网络服务器时间*/
func (T *TimeSetConfig) SyncNetTime(timesvr string) bool {
	/*1、停止NTPD服务*/
	//stopNtpd() //加了 -u 参数, 不需要停掉 ntpd.

	/*2、同步服务器时钟*/
	if syncNtpd(timesvr) == false {
		return false
	}

	/*3、重新启动NTPD服务*/
	//if startNtpd() == false {
	//	return false
	//}

	/*系统时钟与硬件时钟同步*/
	/*yjs : 没有时钟硬件，hwclock注释掉
	err := exec.Command("hwclock", "-w").Run()
	if err != nil {
		log.Panicln("Exec command hwclock -w Failure!")
		return false
	}
	*/

	return true
}

/*停止NTP服务，仅供内部函数SyncNetTime使用*/
/* yjs: 没有systemctl，先注释掉
func stopNtpd() bool {
	err := exec.Command("systemctl", "stop", "ntpd.service").Run()
	if err != nil {
		log.Printf("Exec command Stop NTPD Failure! ERROR:%s\n", err.Error())
		//return false

		//服务停止失败，2秒后重试一下
		select {
		case <-time.After(INTERVAL_TIMESET):
			err = exec.Command("systemctl", "stop", "ntpd.service").Run()
		}
	}
	return true
}
*/

/*同步网络时间服务器，仅供内部函数SyncNetTime使用*/
func syncNtpd(net_timeSvr string) bool {
	err := exec.Command("ntpd", "-n", "-q", "-p", net_timeSvr).Run()
	if err != nil {
		log.Printf("Exec command ntpd Failure! ERROR:%s\n", err.Error())

		//同步网络时间失败，2秒后重试一下
		select {
		case <-time.After(INTERVAL_TIMESET):
			err = exec.Command("ntpd", "-n", "-q", "-p", net_timeSvr).Run()
		}
		return false
	}
	return true
}

/*启动Ntp服务，仅供内部函数SyncNetTime使用*/
/* yjs: 没有systemctl，先注释掉
func startNtpd() bool {
	err := exec.Command("systemctl", "start", "ntpd.service").Run()
	if err != nil {
		log.Printf("Exec command start ntpd Failure! ERROR:%s\n", err.Error())

		//服务启动失败，2秒后重试一下
		time.AfterFunc(INTERVAL_TIMESET, func() {
			err = exec.Command("systemctl", "start", "ntpd.service").Run()
		})
		return false
	}
	return true
}
*/
