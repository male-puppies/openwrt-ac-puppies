package config

import (
	"fmt"
	"time"
)

//云端的用户信息节点
type CloudUserInfo struct {
	GroupName string //组名
	UserName  string //用户名
	UserDesc  string //用户描述
	Password  string //认证密码

	ProhibitChange int //禁止修改密码 1. 禁止
	ChangePassword int //初次登录需要修改密码1. 需要

	ID           string //身份证号、手机号、QQ号、微信号、微博号.
	CheckPhoneNo int    //是否需要校验该手机号后才能上网

	AuthType int     //0，无需认证，1.用户名认证，3.身份证认证 3. 手机号认证，4. QQ号认证，5. 微信认证，6，微博认证
	Status   int     //帐号状态，启用，禁用，待审核不允许上网
	BindList []IPMAC //绑定列表，一个帐号可以绑定多个ip和mac

	MultiOnline int    //允许多人使用账号在线
	Account     string //用户所属客户账号
	UgwId       string //最后在线设备的网关ID
	LastLoginIP string //客户端最后一次登录的IP

	LastLoginTime  string //客户最后一次登录时间， date + time
	LastOnlineDate string //用户最后有数据日期
	LastOnlineTime string //用户最后有数据时间

	RegistTime  string //账号注册时间
	ExpiredDate string //帐号超期日期，形如2014-01-14
	ExpiredTime string //账号超期时间
	OnlineLimit int    //用户每天上线时长，单位分钟，0表示不限制
	OnlineTime  int    //当天已上网时间，单位分钟
}

/*在线用户信息*/
type CloudOnlineUserInfo struct {
	GroupName    string //组名
	UserName     string //用户名
	Account      string //账号名
	UgwId        string //设备ID
	OnlineStatus int    //用户状态
	IP           string //Mac
	Mac          string //IP
	DeviceName   string //设备名
}

/*同时包含两个信息*/
type CloudInfo struct {
	UserInfo       CloudUserInfo
	OnlineUserInfo CloudOnlineUserInfo
}

/*检查账号是否已过期*/
func (user *CloudUserInfo) IsExpired() bool {
	if user.ExpiredDate == "" {
		return false
	}

	now := time.Now()
	y, m, d := now.Date()
	date := fmt.Sprintf("%04d-%02d-%02d", y, m, d)

	if date > user.ExpiredDate {
		return true
	} else if date == user.ExpiredDate {
		if user.ExpiredTime != "" {
			time := fmt.Sprintf("%02d:%02d:%02d", now.Hour(), now.Minute(), now.Second())
			if time > user.ExpiredTime {
				return true
			}
		}
	}
	return false
}

/*账号是否启用*/
func (user *CloudUserInfo) Enable() bool {
	return user.Status == 1
}

/*检查登录是否成功*/
func (user *CloudUserInfo) OnLogin(logininfo *LoginInfoMsg) (bool, string) {
	if user.UserName != logininfo.UserName || user.Password != logininfo.UserName {
		return false, "用户名或密码输入有误，请重新输入！"
	}

	bindlist := user.BindList
	bindlistlen := len(user.BindList)
	if bindlistlen == 0 { //无绑定关系
		return true, "用户名和密码校验成功!"
	}

	var matched bool = false
	for i := 0; i < bindlistlen; i++ {
		if bindlist[i].Ip != "" && bindlist[i].Mac != "" {
			if bindlist[i].Ip == logininfo.IP && bindlist[i].Mac == logininfo.Mac {
				matched = true
				break
			}
		} else if bindlist[i].Ip != "" {
			if bindlist[i].Ip == logininfo.IP {
				matched = true
				break
			}
		} else if bindlist[i].Mac != "" {
			if bindlist[i].Mac == logininfo.Mac {
				matched = true
				break
			}
		}

	}
	if matched {
		return true, "用户名和密码校验成功"
	}
	return false, "该账号禁止在此终端上使用"
}
