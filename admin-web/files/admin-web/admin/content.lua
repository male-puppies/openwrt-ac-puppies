package.path = "/usr/share/admin-web/?.lua;" .. package.path
local reply_e = require("admin.authlib").reply_e

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

-- curl 'http://127.0.0.1/v1/admin/api/iface_get?token=6c25a7e9589a1c46c4c1af881f0a50a3'
-- curl 'http://127.0.0.1/v1/admin/api/iface_set?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'arg=json_string'
if cmd:find("^iface_") then
	return require("admin.iface").run(cmd)
end 

-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_del?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'ipgids=[0,1,2,3]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_set?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'ipgid=1&ipgrpname=xxx&ipgrpdesc=yyy&ranges=["0.0.0.7/16"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_add?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'ipgid=63&ipgrpname=xxx2&ipgrpdesc=yyy&ranges=["0.0.0.7-0.0.0.999"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_get?token=6c25a7e9589a1c46c4c1af881f0a50a3&page=1&count=10&order=ipgrpname&desc=1&search=ipgrpname&like=ALL'
if cmd:find("^ipgroup_") then
	return require("admin.ipgroup").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/authrule_set?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'rid=0&rulename=rulename&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_get?token=6c25a7e9589a1c46c4c1af881f0a50a3&page=1&count=10'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_del?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'rids=[0,1,2,3,4]'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_add?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'rulename=rulename4&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_add?token=6c25a7e9589a1c46c4c1af881f0a50a3' -d 'rulename=rulename4&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
if cmd:find("^authrule_") then
	return require("admin.authrule").run(cmd)
end 
