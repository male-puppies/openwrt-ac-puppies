-- author: yjs

package.path = "/usr/share/admin-web/?.lua;" .. package.path
local reply_e = require("admin.adminlib").reply_e

-- 检查uri格式
local uri = ngx.var.uri
local ver, cmd = uri:match("/(.-)/admin/api/(.+)")
if not (cmd and ver) then
	return reply_e({e = "invalid request"})
end

local cmd_map = {}

local cmd_arr = {
	{ pattern = "^login$", 		lib = "admin.login" },
	{ pattern = "^iface_", 		lib = "admin.iface" },
	{ pattern = "^ipgroup_", 	lib = "admin.ipgroup" },
	{ pattern = "^acrule_", 	lib = "admin.acrule" },
	{ pattern = "^authrule_", 	lib = "admin.authrule" },
	{ pattern = "^kv_", 		lib = "admin.kv" },
	{ pattern = "^dnat_", 		lib = "admin.firewall" },
	{ pattern = "^timegroup_", 	lib = "admin.timegroup" },
	{ pattern = "^acset_", 		lib = "admin.acset" },
	{ pattern = "^wlan_", 		lib = "admin.wlanssid" },
	{ pattern = "^mwan_", 		lib = "admin.mwan" },
	{ pattern = "^acgroup_", 	lib = "admin.acgroup" },
	{ pattern = "^user_", 		lib = "admin.user" },
	{ pattern = "^online_", 	lib = "admin.online" },
	{ pattern = "^route_",	 	lib = "admin.route" },
	{ pattern = "^tc_", 		lib = "admin.tc" },
	{ pattern = "^cloud_", 		lib = "admin.cloud" },
	{ pattern = "^nettool_", 	lib = "admin.nettool" },
	{ pattern = "^system_", 	lib = "admin.system" },
	{ pattern = "^radio_", 		lib = "admin.radio" },
}

for _, r in ipairs(cmd_arr) do
	if cmd:find(r.pattern) then
		return require(r.lib).run(cmd)
	end
end

--[[
curl 'http://127.0.0.1/v1/admin/api/login?username=root&password=admin'

curl 'http://127.0.0.1/v1/admin/api/iface_get?token=30810b31d61557198a749ebf5923f582'
curl 'http://127.0.0.1/v1/admin/api/iface_set?token=30810b31d61557198a749ebf5923f582' -d 'arg=json_string'

curl 'http://127.0.0.1/v1/admin/api/ipgroup_del?token=30810b31d61557198a749ebf5923f582' -d 'ipgids=[0,1,2,3]'
curl 'http://127.0.0.1/v1/admin/api/ipgroup_set?token=30810b31d61557198a749ebf5923f582' -d 'ipgid=1&ipgrpname=xxx&ipgrpdesc=yyy&ranges=["0.0.0.7/16"]'
curl 'http://127.0.0.1/v1/admin/api/ipgroup_add?token=30810b31d61557198a749ebf5923f582' -d 'ipgid=63&ipgrpname=xxx2&ipgrpdesc=yyy&ranges=["0.0.0.7-0.0.0.999"]'
curl 'http://127.0.0.1/v1/admin/api/ipgroup_get?token=30810b31d61557198a749ebf5923f582&page=1&count=10&order=ipgrpname&desc=1&search=ipgrpname&like=ALL'

curl 'http://127.0.0.1/v1/admin/api/acrule_set?token=30810b31d61557198a749ebf5923f582' -d 'ruleid=10&priority=4&rulename=rulename&ruledesc=ruledesc&src_ipgids=[1,2,3]&dest_ipgids=[2,6]&proto_ids=[3,4]&tmgrp_ids=[1]&actions=["ACCEPT"]&enable=1'
curl 'http://127.0.0.1/v1/admin/api/acrule_get?token=30810b31d61557198a749ebf5923f582&page=1&count=10'
curl 'http://127.0.0.1/v1/admin/api/acrule_del?token=30810b31d61557198a749ebf5923f582' -d 'ruleids=[9,10]'
curl 'http://127.0.0.1/v1/admin/api/acrule_add?token=30810b31d61557198a749ebf5923f582' -d 'rulename=uuuu&ruledesc=ruledesc&src_ipgids=[1,4]&dest_ipgids=[4]&proto_ids=[3,4]&tmgrp_ids=[1]&actions=["ACCEPT","ADUIT"]&enable=1'
curl 'http://127.0.0.1/v1/admin/api/acrule_adjust?token=30810b31d61557198a749ebf5923f582' -d 'ruleids=[1,2]'

curl 'http://127.0.0.1/v1/admin/api/authrule_set?token=9903f8226c387824266f87aba80116f3' -d 'rid=0&rulename=rulename&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
curl 'http://127.0.0.1/v1/admin/api/authrule_get?token=9903f8226c387824266f87aba80116f3&page=1&count=10'
curl 'http://127.0.0.1/v1/admin/api/authrule_del?token=9903f8226c387824266f87aba80116f3' -d 'rids=[0,1,2,3,4]'
curl 'http://127.0.0.1/v1/admin/api/authrule_add?token=9903f8226c387824266f87aba80116f3' -d 'rulename=rulename4&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
curl 'http://127.0.0.1/v1/admin/api/authrule_adjust?token=9903f8226c387824266f87aba80116f3' -d 'rids=[1,2]'

curl 'http://127.0.0.1/v1/admin/api/kv_get?token=30810b31d61557198a749ebf5923f582&keys=%5B%22auth_offline_time%22,%22auth_bypass_dst%22%5D'
curl 'http://127.0.0.1/v1/admin/api/kv_set?token=30810b31d61557198a749ebf5923f582' -d 'auth_offline_time=1900&auth_redirect_ip=1.1.1.1&auth_bypass_dst=[1]'

curl 'http://127.0.0.1/v1/admin/api/dnat_del?token=9903f8226c387824266f87aba80116f3' -d 'fwids=[1]'
curl 'http://127.0.0.1/v1/admin/api/dnat_set?token=9903f8226c387824266f87aba80116f3' -d 'fwid=1&fwname=gsl&fwdesc=123456&enable=1&proto=tcp&src_zid=0&dest_port=22&target_zid=0&target_ip=127.0.0.1&target_port=22'
curl 'http://127.0.0.1/v1/admin/api/dnat_add?token=9903f8226c387824266f87aba80116f3' -d 'fwname=test3&fwdesc=desc of dnat&enable=1&proto=tcp&src_zid=0&dest_port=22&target_zid=0&target_ip=127.0.0.1&target_port=22'
curl 'http://127.0.0.1/v1/admin/api/dnat_get?token=9903f8226c387824266f87aba80116f3&page=1&count=10'
curl 'http://127.0.0.1/v1/admin/api/dnat_adjust?token=9903f8226c387824266f87aba80116f3' -d 'fwids=[0,1]'

curl 'http://127.0.0.1/v1/admin/api/timegroup_del?token=6f8d0d5ccd80f4dec2a6636698d16e71' -d 'tmgids=[0,1,2,3,4,5]'
curl 'http://127.0.0.1/v1/admin/api/timegroup_set?token=6f8d0d5ccd80f4dec2a6636698d16e71' -d 'tmgid=0&tmgrpname=xxx&tmgrpdesc=yyy&days={"mon":1,"tues":1,"wed":1,"thur":1,"fri":1,"sat":0,"sun":0}&tmlist=[{"hour_start":8,"min_start":0,"hour_end":16,"min_end":0}, {"hour_start":14,"min_start":0,"hour_end":16,"min_end":0}]'
curl 'http://127.0.0.1/v1/admin/api/timegroup_add?token=6f8d0d5ccd80f4dec2a6636698d16e71' -d 'tmgid=1&tmgrpname=ggg&tmgrpdesc=yyy&days={"mon":0,"tues":0,"wed":0,"thur":0,"fri":0,"sat":0,"sun":0}&tmlist=[{"hour_start":0,"min_start":0,"hour_end":0,"min_end":0}]'
curl 'http://192.168.9.222/v1/admin/api/timegroup_get?token=6f8d0d5ccd80f4dec2a6636698d16e71&page=1&count=10&order=tmgrpname&desc=1&search=tmgrpname&like=ALL'
curl 'http://192.168.9.222/v1/admin/api/timegroup_get?token=6f8d0d5ccd80f4dec2a6636698d16e71&page=1&count=10'

curl 'http://127.0.0.1/v1/admin/api/acset_set?token=23e37eb5d14ee05ed142247332616b01' -d 'setid=2&setname=access_white_ip&setdesc=access white ip&setclass=control&settype=ip&content=["0.0.0.7-0.0.0.999"]&action=bypass&enable=1'
curl 'http://127.0.0.1/v1/admin/api/acset_set?token=23e37eb5d14ee05ed142247332616b01' -d 'setid=0&setname=access_white_mac&setdesc=access white mac&setclass=control&settype=mac&content=["0b:25:gg:8f:i6:tt"]&action=bypass&enable=1'
curl 'http://127.0.0.1/v1/admin/api/acset_get?token=23e37eb5d14ee05ed142247332616b01&setclass=control&action=bypass'

curl 'http://127.0.0.1/v1/admin/api/wlan_del?token=857a6d143d1982d267b7b989f5e9f692' -d 'wlanids=[0,1]'
curl 'http://127.0.0.1/v1/admin/api/wlan_set?token=857a6d143d1982d267b7b989f5e9f692' -d 'wlanid=0&enable=1&band="˫Ƶ"&ssid="yyy"&encrypt="psk2"&password="123456"&hide=0'
curl 'http://127.0.0.1/v1/admin/api/wlan_add?token=857a6d143d1982d267b7b989f5e9f692' -d 'enable=1&band="˫Ƶ"&ssid="yyy"&encrypt="psk2"&password="123456"&hide=0'
curl 'http://172.16.0.1/v1/admin/api/wlan_get?token=857a6d143d1982d267b7b989f5e9f692&page=1&count=10&order=tmgrpname&desc=1&search=tmgrpname&like=ALL'
curl 'http://172.16.0.1/v1/admin/api/wlan_get?token=857a6d143d1982d267b7b989f5e9f692&page=1&count=10'

curl 'http://127.0.0.1/v1/admin/api/mwan_get?token=30810b31d61557198a749ebf5923f582'
curl 'http://127.0.0.1/v1/admin/api/mwan_set?token=30810b31d61557198a749ebf5923f582' -d 'arg=json_string'

curl 'http://127.0.0.1/v1/admin/api/acgroup_del?token=30810b31d61557198a749ebf5923f582' -d 'gids=[0,1,2,3]'
curl 'http://127.0.0.1/v1/admin/api/acgroup_set?token=30810b31d61557198a749ebf5923f582' -d 'gid=63&groupname=xxx&groupdesc=yyy&pid=-1'
curl 'http://127.0.0.1/v1/admin/api/acgroup_add?token=30810b31d61557198a749ebf5923f582' -d 'groupname=xxx&groupdesc=yyy&pid=-1'
curl 'http://127.0.0.1/v1/admin/api/acgroup_get?token=30810b31d61557198a749ebf5923f582&page=1&count=10&order=gid&desc=1&search=groupname&like=default'

curl 'http://127.0.0.1/v1/admin/api/user_del?token=30810b31d61557198a749ebf5923f582' -d 'uids=[0,1,2,3]'
curl 'http://127.0.0.1/v1/admin/api/user_set?token=30810b31d61557198a749ebf5923f582' -d 'username=a22&password=aaa&enable=1&userdesc=desc&gid=63&bindip=1.3.6.9&bindmac=&expire=2016-09-01 00:01:02&register=2016-09-01 00:01:00&uid=0'
curl 'http://127.0.0.1/v1/admin/api/user_add?token=30810b31d61557198a749ebf5923f582' -d 'username=a2&password=aaa&enable=1&userdesc=desc&gid=63&bindip=1.3.6.9&bindmac=&expire=2016-09-01 00:01:02'
curl 'http://127.0.0.1/v1/admin/api/user_get?token=30810b31d61557198a749ebf5923f582&page=1&count=10&order=uid&desc=1&search=username&like=aaa'

curl 'http://127.0.0.1/v1/admin/api/online_del?token=30810b31d61557198a749ebf5923f582' -d 'ukeys=["1234_5678"]'
curl 'http://127.0.0.1/v1/admin/api/online_get?token=30810b31d61557198a749ebf5923f582&page=1&count=10&order=uid&desc=1&search=username&like=aaa'

curl 'http://127.0.0.1/v1/admin/api/route_del?token=9903f8226c387824266f87aba80116f3' -d 'rids=[1]'
curl 'http://127.0.0.1/v1/admin/api/route_set?token=9903f8226c387824266f87aba80116f3' -d 'rid=1&target=192.168.0.0&netmask=255.255.255.255&gateway=192.168.0.1&metric=6&mtu=1500&iface=lan0'
curl 'http://127.0.0.1/v1/admin/api/route_add?token=9903f8226c387824266f87aba80116f3' -d 'target=192.168.0.0&netmask=255.255.255.255&gateway=192.168.0.1&metric=6&mtu=1500&iface=lan0'
curl 'http://127.0.0.1/v1/admin/api/route_get?token=9903f8226c387824266f87aba80116f3&page=1&count=10'

curl 'http://127.0.0.1/v1/admin/api/tc_del?token=9903f8226c387824266f87aba80116f3' -d 'Names=["aaa","bbbb"]'
curl 'http://127.0.0.1/v1/admin/api/tc_gset?token=9903f8226c387824266f87aba80116f3' -d 'GlobalSharedUpload=1Mbps&GlobalSharedDownload=2Mbps'
curl 'http://127.0.0.1/v1/admin/api/tc_set?token=9903f8226c387824266f87aba80116f3' -d 'Enabled=1&Ip=0.0.0.0-1.1.1.1&Name=XX&SharedDownload=0MBytes&SharedUpload=1MBytes&PerIpDownload=1KBytes&PerIpUpload=0MBytes'
curl 'http://127.0.0.1/v1/admin/api/tc_add?token=9903f8226c387824266f87aba80116f3' -d 'Enabled=1&Ip=0.0.0.0-1.1.1.1&Name=XX&SharedDownload=0MBytes&SharedUpload=1MBytes&PerIpDownload=1KBytes&PerIpUpload=0MBytes'
curl 'http://127.0.0.1/v1/admin/api/tc_get?token=9903f8226c387824266f87aba80116f3&page=1&count=10'

curl 'http://127.0.0.1/v1/admin/api/cloud_get?token=4d80c3efd70160824fb5825638043a5f'
curl 'http://127.0.0.1/v1/admin/api/cloud_set?token=4d80c3efd70160824fb5825638043a5f' -d 'account=yjs&ac_host=192.168.0.213&ac_port=61886&description=hello'

curl 'http://127.0.0.1/v1/admin/api/nettool_get?token=d4ebd1ce9d867b0009213386f3b7a923&tool=ping&host=www.baidu.com'

curl 'http://127.0.0.1/v1/admin/api/system_get?token=f9eeb5c037ac033a969f6f806bdc4617&keys=%5B%22time%22,%22timezone%22%5D'
curl 'http://127.0.0.1/v1/admin/api/system_set?token=d77f1cd99f63302c212f926c37b94db3' -d 'cmd=synctime&sec=1472719031'
curl 'http://127.0.0.1/v1/admin/api/system_set?token=d77f1cd99f63302c212f926c37b94db3' -d 'cmd=timezone&zonename=xxx'
curl -F 'filename=@/tmp/memfile/test.txt' 'http://192.168.0.11/v1/admin/api/system_upload?token=291b9ffe3da7cbc6aad01ae1cd4fe3e3'
curl 'http://192.168.0.11/v1/admin/api/system_upgrade?token=ff4d10a28b1a3c14b310a7aedab880e3' -d 'keep=1'

curl 'http://127.0.0.1/v1/admin/api/radio_set?token=23260c3bc548d87ce16f8d82fd748adf' -d 'radio_2g:{"proto":"n","bandwidth":"auto","chanid":"auto","power":"auto"}&radio_5g:{"proto":"an","bandwidth":"auto","chanid":"auto","power":"auto"}&opt:{"mult":"0","rate":"2","inspeed":"0","enable":"1"}'
curl 'http://172.16.0.1/v1/admin/api/radio_get?token=23260c3bc548d87ce16f8d82fd748adf&page=1&count=10'
]]