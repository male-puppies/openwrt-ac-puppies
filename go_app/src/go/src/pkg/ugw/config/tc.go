package config

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"regexp"
	"strconv"
)

type TCConfig struct {
	GlobalSharedDownload string
	GlobalSharedUpload   string
	Rules                []TCRule
}

type TCRule struct {
	Enabled        bool
	Name           string
	Ip             string
	SharedDownload string
	SharedUpload   string
	PerIpDownload  string
	PerIpUpload    string
}

type tbqConfig struct {
	MaxBacklogPackets int
	Rules             []tbqRule
}

type tbqRule struct {
	Name          string
	IpIncluded    []string
	IpExcluded    []string
	AppIncluded   []int
	AppExcluded   []int
	UploadLimit   tbqRateLimit
	DownloadLimit tbqRateLimit
}

type tbqRateLimit struct {
	Shared string
	PerIp  string
}

func tbqRateFromTCRate(rate string) string {
	num, err := parseRateDesc(rate)
	if err != nil {
		log.Println(fmt.Errorf("tbqRateFromTCRate(%s) failed, %v", rate, err))
		return "0M"
	}
	if num%1000000000 == 0 {
		return fmt.Sprintf("%dG", num/1000000000)
	}
	if num%1000000 == 0 {
		return fmt.Sprintf("%dM", num/1000000)
	}
	if num%1000 == 0 {
		return fmt.Sprintf("%dK", num/1000)
	}
	return fmt.Sprintf("%d", num)
}

func (rule *tbqRule) setTCRate(sharedUpload, sharedDownload, perIpUpload, perIpDownload string) {
	rule.UploadLimit.Shared = tbqRateFromTCRate(sharedUpload)
	rule.UploadLimit.PerIp = tbqRateFromTCRate(perIpUpload)
	rule.DownloadLimit.Shared = tbqRateFromTCRate(sharedDownload)
	rule.DownloadLimit.PerIp = tbqRateFromTCRate(perIpDownload)
}

func (tc *TCConfig) OnLoad() error {
	tc.Apply()
	return nil
}

func (tc *TCConfig) Apply() bool {
	tbqcfg := tbqConfig{
		MaxBacklogPackets: 9999,
		Rules: []tbqRule{  },
	}

	tmp_map := make(map[string]tbqRule)

	rname := "UI-GLOBAL"
	tbqrule := tbqRule{
		Name:     rname ,
	}
	tbqrule.setTCRate(tc.GlobalSharedUpload, tc.GlobalSharedDownload, tc.GlobalSharedUpload, tc.GlobalSharedDownload)
	tmp_map[rname] = tbqrule

	for _, rule := range tc.Rules {
		rname = fmt.Sprintf("UI-<%s>", rule.Name)
		tbqrule := tbqRule{
			Name:       rname,
			IpIncluded: []string{rule.Ip},
		}
		tbqrule.setTCRate(rule.SharedUpload, rule.SharedDownload, rule.PerIpUpload, rule.PerIpDownload)
		tmp_map[rname] = tbqrule
	} 

	rname = "UI-GLOBAL" 
	if v, ok := tmp_map[rname]; ok {
		tbqcfg.Rules = append(tbqcfg.Rules, v)
		delete(tmp_map, rname) 
	}

	rname = "UI-<Free>" 
	if v, ok := tmp_map[rname]; ok {
		tbqcfg.Rules = append(tbqcfg.Rules, v)
		delete(tmp_map, rname) 
	}

	rname = "UI-<VIP>" 
	if v, ok := tmp_map[rname]; ok {
		tbqcfg.Rules = append(tbqcfg.Rules, v)
		delete(tmp_map, rname) 
	}

	for _, v := range tmp_map { 
		tbqcfg.Rules = append(tbqcfg.Rules, v) 
	}

	data, err := json.MarshalIndent(&tbqcfg, "", "\t")
	if err != nil {
		log.Println(err)
		return false
	}

	fmt.Println(string(data))

	err = ioutil.WriteFile("/sys/module/nos/tbq", data, 0644)
	if err != nil {
		log.Println(err)
		return false
	}

	return true
}

func (rule *TCRule) OnNew() bool {
	return rule.OnIpSet(rule.Ip) &&
		rule.OnSharedDownloadSet(rule.SharedDownload) &&
		rule.OnSharedUploadSet(rule.SharedUpload) &&
		rule.OnPerIpDownloadSet(rule.PerIpDownload) &&
		rule.OnPerIpUploadSet(rule.PerIpUpload)
}

func (rule *TCRule) OnNameSet(name string) bool {
	log.Println("TCRule.Name.set() is disabled")
	return false
}

func (rule *TCRule) OnIpSet(desc string) bool {
	re := regexp.MustCompile(`^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*(?:-\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*)?$`)
	matches := re.FindStringSubmatch(desc)
	if len(matches) != 9 {
		panic(fmt.Errorf("bad ip desc: %s", desc))
		return false
	}
	for _, numstr := range matches[1:] {
		if len(numstr) != 0 {
			num, err := strconv.Atoi(numstr)
			if err != nil || num < 0 || num > 255 {
				panic(fmt.Errorf("bad ip number: %s", numstr))
				return false
			}
		}
	}
	return true
}

func parseRateDesc(rate string) (uint64, error) {
	re := regexp.MustCompile(`^\s*(\d+)\s*(K|M)\s*(bps|Bytes)\s*$`)
	matches := re.FindStringSubmatch(rate)
	if len(matches) != 4 {
		return 0, fmt.Errorf("bad rate desc: %s", rate)
	}

	num, err := strconv.ParseUint(matches[1], 10, 64)
	if err != nil {
		return 0, fmt.Errorf("bad rate desc: %s, %v", rate, err)
	}

	var factor uint64
	switch matches[2] {
	case "K":
		factor = 1000
	case "M":
		factor = 1000 * 1000
	}

	bps := false
	if matches[3] == "bps" {
		bps = true
	}

	var maxRate uint64 = 2 * 1000 * 1000 * 1000
	if bps {
		maxRate *= 8
	}
	if num > maxRate/factor {
		return 0, fmt.Errorf("rate out of range [0, %d]: %s", maxRate, rate)
	}
	num *= factor
	if bps {
		num /= 8
	}
	return num, nil
}

func (rule *TCRule) OnSharedDownloadSet(rate string) bool {
	if _, err := parseRateDesc(rate); err != nil {
		log.Println(fmt.Errorf("bad shared download rate: %s, %v", rate, err))
		return false
	}
	return true
}

func (rule *TCRule) OnSharedUploadSet(rate string) bool {
	if _, err := parseRateDesc(rate); err != nil {
		log.Println(fmt.Errorf("bad shared upload rate: %s, %v", rate, err))
		return false
	}
	return true
}

func (rule *TCRule) OnPerIpDownloadSet(rate string) bool {
	if _, err := parseRateDesc(rate); err != nil {
		log.Println(fmt.Errorf("bad per ip download rate: %s, %v", rate, err))
		return false
	}
	return true
}

func (rule *TCRule) OnPerIpUploadSet(rate string) bool {
	if _, err := parseRateDesc(rate); err != nil {
		log.Println(fmt.Errorf("bad per ip upload rate: %s, %v", rate, err))
		return false
	}
	return true
}

func (tc *TCConfig) OnNew() bool {
	if !tc.OnGlobalSharedDownloadSet(tc.GlobalSharedDownload) ||
		!tc.OnGlobalSharedUploadSet(tc.GlobalSharedUpload) {
		return false
	}
	for _, rule := range tc.Rules {
		if !rule.OnNew() {
			return false
		}
	}
	return true
}

func (tc *TCConfig) OnGlobalSharedDownloadSet(bandwidth string) bool {
	if _, err := parseRateDesc(bandwidth); err != nil {
		log.Println(fmt.Errorf("bad global shared download bandwidth: %s, %v", bandwidth, err))
		return false
	}
	return true
}

func (tc *TCConfig) OnGlobalSharedUploadSet(bandwidth string) bool {
	if _, err := parseRateDesc(bandwidth); err != nil {
		log.Println(fmt.Errorf("bad global shared upload bandwidth: %s, %v", bandwidth, err))
		return false
	}
	return true
}

func checkDuplicateRuleName(rules []TCRule, rule *TCRule) bool {
	for _, r := range rules {
		if r.Name == rule.Name {
			log.Println(fmt.Errorf("duplicate rule name: %s", rule.Name))
			return false
		}
	}
	return true
}

func (tc *TCConfig) OnRulesInsert(rules []TCRule, index int, rule *TCRule) bool {
	return checkDuplicateRuleName(rules, rule)
}

func (tc *TCConfig) OnRulesUpdate(rules []TCRule, index int, rule *TCRule) bool {
	return checkDuplicateRuleName(rules[:index], rule) &&
		checkDuplicateRuleName(rules[index+1:], rule)
}
