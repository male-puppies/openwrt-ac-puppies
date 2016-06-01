package dpi

import (
	"log"
	"pkg/ugw/config"
)

var dpi *config.DPIConfig = nil

func initDpiConf() {
	if dpi == nil {
		var conf config.DPIConfig
		err := config.Eval("DPI.GetConfig()", &conf)
		if err != nil {
			log.Fatalln("dpi eval DPI failed.\n")
		}
		dpi = &conf
	}
}

func RealodConf() {
	var conf config.DPIConfig
	err := config.Eval("DPI.GetConfig()", &conf)
	if err != nil {
		log.Println("dpi reload conf failed:", err)
		return
	}
	dpi = &conf
}

func GetRules() map[string]uint16 {
	initDpiConf()
	return dpi.GetRules()
}

func GetApps() map[string][]string {
	initDpiConf()
	return dpi.GetAppRuleTree()
}

func GetTypeRules(app string) (map[string]uint16, error) {
	initDpiConf()
	return dpi.GetTypeRules(app)
}

func GetAppRules(app string) (map[string]uint16, error) {
	initDpiConf()
	return dpi.GetAppRules(app)
}

func GetIdByName(str string) uint16 {
	initDpiConf()
	return dpi.GetIdByName(str)
}

func GetNameById(id uint16) string {
	initDpiConf()
	return dpi.GetNameById(id)
}

func GetAppNameByProto(p uint16) string {
	initDpiConf()
	return dpi.GetAppNameByProto(p)
}

func GetAppTypeByProto(p uint16) string {
	initDpiConf()
	return dpi.GetAppTypeByProto(p)
}

func GetAppIdByName(s string) uint16 {
	initDpiConf()
	return dpi.GetAppIdByName(s)
}

func GetTypeIdByName(s string) uint16 {
	initDpiConf()
	return dpi.GetTypeIdByName(s)
}

func AppAll(s string) bool {
	initDpiConf()
	return dpi.IsAllRules(s)
}

func Unknown() uint16 {
	return config.DPI_RULE_ID_UNKNOWN
}
