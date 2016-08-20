package.path = "/usr/share/admin-web/?.lua;" .. package.path
local reply_e = require("admin.adminlib").reply_e

-- 检查uri格式
local uri = ngx.var.uri
local ver, cmd = uri:match("/(.-)/admin/api/(.+)")
if not (cmd and ver) then
	return reply_e({e = "invalid request"})
end

local cmd_map = {}

-- curl 'http://127.0.0.1/v1/admin/api/login?username=wjrc&password=wjrc0409'
if cmd == "login" then
	return require("admin.login").run()
end

-- curl 'http://127.0.0.1/v1/admin/api/iface_get?token=77d0aeb8ae53926a363f1eb6973bb7ca'
-- curl 'http://127.0.0.1/v1/admin/api/iface_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'arg=json_string'
if cmd:find("^iface_") then
	return require("admin.iface").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_del?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ipgids=[0,1,2,3]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ipgid=1&ipgrpname=xxx&ipgrpdesc=yyy&ranges=["0.0.0.7/16"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_add?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ipgid=63&ipgrpname=xxx2&ipgrpdesc=yyy&ranges=["0.0.0.7-0.0.0.999"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_get?token=77d0aeb8ae53926a363f1eb6973bb7ca&page=1&count=10&order=ipgrpname&desc=1&search=ipgrpname&like=ALL'
if cmd:find("^ipgroup_") then
	return require("admin.ipgroup").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/acrule_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ruleid=10&priority=4&rulename=rulename&ruledesc=ruledesc&src_ipgids=[1,2,3]&dest_ipgids=[2,6]&proto_ids=[3,4]&tmgrp_ids=[1]&actions=["ACCEPT"]&enable=1'
-- curl 'http://127.0.0.1/v1/admin/api/acrule_get?token=77d0aeb8ae53926a363f1eb6973bb7ca&page=1&count=10'
-- curl 'http://127.0.0.1/v1/admin/api/acrule_del?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ruleids=[9,10]'
-- curl 'http://127.0.0.1/v1/admin/api/acrule_add?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'rulename=uuuu&ruledesc=ruledesc&src_ipgids=[1,4]&dest_ipgids=[4]&proto_ids=[3,4]&tmgrp_ids=[1]&actions=["ACCEPT","ADUIT"]&enable=1'
-- curl 'http://127.0.0.1/v1/admin/api/acrule_adjust?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ruleids=[1,2]'
if cmd:find("^acrule_") then
        return require("admin.acrule").run(cmd)
end



-- curl 'http://127.0.0.1/v1/admin/api/authrule_set?token=9903f8226c387824266f87aba80116f3' -d 'rid=0&rulename=rulename&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_get?token=9903f8226c387824266f87aba80116f3&page=1&count=10'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_del?token=9903f8226c387824266f87aba80116f3' -d 'rids=[0,1,2,3,4]'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_add?token=9903f8226c387824266f87aba80116f3' -d 'rulename=rulename4&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_adjust?token=9903f8226c387824266f87aba80116f3' -d 'rids=[1,2]'
if cmd:find("^authrule_") then
	return require("admin.authrule").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/kv_get?token=77d0aeb8ae53926a363f1eb6973bb7ca&keys=%5B%22offline_time%22,%22bypass_dst%22%5D'
-- curl 'http://127.0.0.1/v1/admin/api/kv_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'offline_time=1900&redirect_ip=1.1.1.1&bypass_dst=[1]'
if cmd:find("^kv_") then
	return require("admin.kv").run(cmd)
end


-- curl 'http://127.0.0.1/v1/admin/api/firewall_del?token=9903f8226c387824266f87aba80116f3' -d 'fwids=[1]'
-- curl 'http://127.0.0.1/v1/admin/api/firewall_set?token=9903f8226c387824266f87aba80116f3' -d 'fwid=1&fwname=gsl&fwdesc=123456&enable=1&proto=tcp&src_zid=0&dest_port=22&target_zid=0&target_ip=127.0.0.1&target_port=22'
-- curl 'http://127.0.0.1/v1/admin/api/firewall_add?token=9903f8226c387824266f87aba80116f3' -d 'fwname=test3&fwdesc=desc of firewall&enable=1&proto=tcp&src_zid=0&dest_port=22&target_zid=0&target_ip=127.0.0.1&target_port=22'
-- curl 'http://127.0.0.1/v1/admin/api/firewall_get?token=9903f8226c387824266f87aba80116f3&page=1&count=10'
-- curl 'http://127.0.0.1/v1/admin/api/firewall_adjust?token=9903f8226c387824266f87aba80116f3' -d 'fwids=[0,1]'
if cmd:find("^firewall_") then
	return require("admin.firewall").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/timegroup_del?token=6f8d0d5ccd80f4dec2a6636698d16e71' -d 'tmgids=[0,1,2,3,4,5]'
-- curl 'http://127.0.0.1/v1/admin/api/timegroup_set?token=6f8d0d5ccd80f4dec2a6636698d16e71' -d 'tmgid=0&tmgrpname=xxx&tmgrpdesc=yyy&days={"mon":1,"tues":1,"wed":1,"thur":1,"fri":1,"sat":0,"sun":0}&tmlist=[{"hour_start":8,"min_start":0,"hour_end":16,"min_end":0}, {"hour_start":14,"min_start":0,"hour_end":16,"min_end":0}]'
-- curl 'http://127.0.0.1/v1/admin/api/timegroup_add?token=6f8d0d5ccd80f4dec2a6636698d16e71' -d 'tmgid=1&tmgrpname=ggg&tmgrpdesc=yyy&days={"mon":0,"tues":0,"wed":0,"thur":0,"fri":0,"sat":0,"sun":0}&tmlist=[{"hour_start":0,"min_start":0,"hour_end":0,"min_end":0}]'
-- curl 'http://192.168.9.222/v1/admin/api/timegroup_get?token=6f8d0d5ccd80f4dec2a6636698d16e71&page=1&count=10&order=tmgrpname&desc=1&search=tmgrpname&like=ALL'
-- curl 'http://192.168.9.222/v1/admin/api/timegroup_get?token=6f8d0d5ccd80f4dec2a6636698d16e71&page=1&count=10'
if cmd:find("^timegroup_") then
	return require("admin.timegroup").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/acset_set?token=23e37eb5d14ee05ed142247332616b01' -d 'setid=2&setname=access_white_ip&setdesc=access white ip&setclass=control&settype=ip&content=["0.0.0.7-0.0.0.999"]&action=bypass&enable=1'
-- curl 'http://127.0.0.1/v1/admin/api/acset_set?token=23e37eb5d14ee05ed142247332616b01' -d 'setid=0&setname=access_white_mac&setdesc=access white mac&setclass=control&settype=mac&content=["0b:25:gg:8f:i6:tt"]&action=bypass&enable=1'
-- curl 'http://127.0.0.1/v1/admin/api/acset_get?token=23e37eb5d14ee05ed142247332616b01&setclass=control&action=bypass'
if cmd:find("^acset_") then
	return require("admin.acset").run(cmd)
end


-- curl 'http://127.0.0.1/v1/admin/api/wlan_del?token=857a6d143d1982d267b7b989f5e9f692' -d 'wlanids=[0,1]'
-- curl 'http://127.0.0.1/v1/admin/api/wlan_set?token=857a6d143d1982d267b7b989f5e9f692' -d 'wlanid=0&enable=1&band="˫Ƶ"&ssid="yyy"&encrypt="psk2"&password="123456"&hide=0'
-- curl 'http://127.0.0.1/v1/admin/api/wlan_add?token=857a6d143d1982d267b7b989f5e9f692' -d 'enable=1&band="˫Ƶ"&ssid="yyy"&encrypt="psk2"&password="123456"&hide=0'
-- curl 'http://172.16.0.1/v1/admin/api/wlan_get?token=857a6d143d1982d267b7b989f5e9f692&page=1&count=10&order=tmgrpname&desc=1&search=tmgrpname&like=ALL'
-- curl 'http://172.16.0.1/v1/admin/api/wlan_get?token=857a6d143d1982d267b7b989f5e9f692&page=1&count=10'

if cmd:find("^wlan_") then
	return require("admin.wlanssid").run(cmd)
end


