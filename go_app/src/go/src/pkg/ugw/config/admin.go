package config

import (
	"crypto/sha512"
	"fmt"
)

const (
	UNKNOWNUSER = 0 //未认证用户
	SUPERUSER   = 1 //超级管理员
	COMMONUSER  = 2 //普通管理员
	AIDUSER     = 3 //身份证认证页面录入员
)

const (
	ADMINS = "Admin.Admins"
)

type AdminConfig struct {
	Admins map[string]*Admin
}

//系统管理员
type Admin struct {
	UserName    string    //账号
	UserDesc    string    //账号描述
	IPList      []IpRange //允许登录的ip或ip范围
	Password    string    //密码
	Oldpassword string    //旧密码
	UserType    uint8     //用户类型
}

func (a *Admin) OnNew() bool {

	if a.Oldpassword == "" || a.Oldpassword != a.Password {
		hash := sha512.New()
		hash.Write([]byte(a.Password))
		a.Password = fmt.Sprintf("%02X", hash.Sum(nil))
	}

	return true
}

func (u *AdminConfig) OnAdminInsert(admins map[string]*Admin, key string, val *Admin) bool {
	if val.UserName == "" ||
		(val.UserType != SUPERUSER && val.UserType != COMMONUSER) {
		return false
	}

	for i := 0; i < len(val.IPList); i++ {
		if !IsVaildIP(val.IPList[i].Start) || !IsVaildIP(val.IPList[i].End) {
			return false
		}
	}

	return true
}

func (u *AdminConfig) OnAdminUpdate(admins map[string]*Admin, key string, val *Admin) bool {
	if val.UserName == "" ||
		(val.UserType != SUPERUSER && val.UserType != COMMONUSER) {
		return false
	}

	for i := 0; i < len(val.IPList); i++ {
		if !IsVaildIP(val.IPList[i].Start) || !IsVaildIP(val.IPList[i].End) {
			return false
		}
	}

	return true
}
