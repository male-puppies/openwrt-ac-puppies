package main
/*
#include <stdio.h>

void sayHi() {
  printf("Hi-------------------------\n");
}
*/
import "C"

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"os"
	"pkg/eval/evalsrv"
	"pkg/ugw/config"
	"pkg/ugw/log/sys"
	"reflect"
	"strings"
	"os/exec"
	"time"
)

const (
	ConfigDirectory = "/tmp/config/"
)

var (
	configCache = map[string]*ConfigInfo{}
	evalServer  = evalsrv.NewEvalServer()
)

type ConfigInfo struct {
	valjson []byte
	valptr  interface{}
}

func check_sn() {
	path := "/tmp/021356548798221354654"
	for {
		_, err := os.Stat(path)
		if config.Check_SN() {
			if err == nil {
				exec.Command("rm", path).Run()
			}
		} else {
			if err != nil {
				exec.Command("touch", path).Run()
			}
		}
		
		time.Sleep(2 * time.Second)
	}
}

func save_deviceid() {
	idfile := "/ugw/etc/wacid"
	id := config.GetDeviceID()
	data, err := ioutil.ReadFile(idfile)
	if err == nil {
		if string(data) == id {
			return
		} 
	}

	syslog.Info("reset device id\n", id)
	ioutil.WriteFile(idfile, []byte(id), 0666)
}



func main() {
	InitConfig()
	save_deviceid()
	go check_sn()
	go config.ModulesCheckSN()
	evalServer.Listen("tcp", ":19999")
}

func InitConfig() {
	typ := reflect.TypeOf((*config.Config)(nil)).Elem()
	for i := 0; i < typ.NumField(); i++ {
		cfgname := typ.Field(i).Name
		val := reflect.New(typ.Field(i).Type)
		cfg := &ConfigInfo{valptr: val.Interface()}
		if LoadConfig(cfgname, cfg) {
			if method := val.MethodByName("OnLoad"); method.IsValid() {
				syslog.Info("call %s.OnLoad()\n", cfgname)
				ret := method.Call(nil)
				if len(ret) != 1 || ret[0].Kind() != reflect.Interface || !ret[0].IsNil() {
					syslog.Error("%s.OnLoad() failed\n", cfgname)
					continue
				}
			}
			configCache[cfgname] = cfg
			evalServer.AddVar(cfgname, cfg.valptr)
		}
	}
	evalServer.OnDirty(OnConfigDirty)
}

func LoadConfig(cfgname string, cfg *ConfigInfo) bool {
	valjson, err := ioutil.ReadFile(configFile(cfgname))
	if err != nil {
		syslog.Error("read %s.json error: %v\n", cfgname, err)
		return false
	}

	err = json.Unmarshal(valjson, cfg.valptr)
	if err != nil {
		syslog.Error("json.Unmarshal %s.json error: %30s\n", cfgname, err)
		return false
	}

	cfg.valjson, err = json.MarshalIndent(cfg.valptr, "", "\t")
	if err != nil {
		syslog.Error("Load %s.json error: %v\n", cfgname, err)
		return false
	}

	syslog.Info("Load %s.json OK\n", cfgname)

	return true
}

func SaveConfig(cfgname string, cfg *ConfigInfo) bool {
	valjson, err := json.MarshalIndent(cfg.valptr, "", "\t")
	if err != nil {
		syslog.Error("json.Marshal %s.json error: %30s\n", cfgname, err)
		return false
	}

	if bytes.Compare(valjson, cfg.valjson) == 0 {
		return true
	}

	if !saveFile(cfgname, valjson) {
		return false
	}

	cfg.valjson = valjson

	syslog.Info("Save %s.json OK\n", cfgname)

	notify_cfgbak(cfgname)
	return true
}

func OnConfigDirty() bool {
	clean := true
	for cfgname, cfg := range configCache {
		if !SaveConfig(cfgname, cfg) {
			clean = false
		}
	}
	return clean
}

func configFile(name string) string {
	return ConfigDirectory + strings.ToLower(name) + ".json"
}

func saveFile(name string, data []byte) bool {
	cfgfile := configFile(name)
	tmpfile := cfgfile + ".tmp"

	if err := ioutil.WriteFile(tmpfile, data, 0644); err != nil {
		syslog.Error("write %s error: %v\n", tmpfile, err)
		return false
	}

	if err := os.Rename(tmpfile, cfgfile); err != nil {
		syslog.Error("rename %s error: %v\n", cfgfile, err)
		return false
	}

	return true
}

func notify_cfgbak(cmd string) {
	go config.CfgBakNotify.SendMsg(cmd, []string{""})
}
