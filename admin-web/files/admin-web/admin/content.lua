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

-- curl 'http://192.168.0.176/v1/admin/api/iface_get?token=d17b8cc68817b19a1cd01320d607782b'
-- curl 'http://192.168.0.176/v1/admin/api/iface_set?token=d17b8cc68817b19a1cd01320d607782b' -d 'arg=json_string'
if cmd:find("^iface_") then
	return require("admin.iface").run(cmd)
end 

-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_del?token=d17b8cc68817b19a1cd01320d607782b' -d 'ipgids=[0,1,2,3]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_set?token=d17b8cc68817b19a1cd01320d607782b' -d 'ipgid=1&ipgrpname=xxx&ipgrpdesc=yyy&ranges=["0.0.0.7/16"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_add?token=d17b8cc68817b19a1cd01320d607782b' -d 'ipgid=63&ipgrpname=xxx2&ipgrpdesc=yyy&ranges=["0.0.0.7-0.0.0.999"]'
-- curl 'http://192.168.0.176/v1/admin/api/ipgroup_get?token=d17b8cc68817b19a1cd01320d607782b&page=1&count=10&order=ipgrpname&desc=1&search=ipgrpname&like=ALL'
if cmd:find("^ipgroup_") then
	return require("admin.ipgroup").run(cmd)
end

-- curl 'http://192.168.0.176/v1/admin/api/authrule_set?token=d17b8cc68817b19a1cd01320d607782b' -d 'rid=0&rulename=rulename&ruledesc=ruledesc&zid=0&ipgid=255&authtype=auto&enable=1&modules=["web"]&iscloud=0&while_ip=[]&while_mac=[]&wechat={}&sms={}'
-- curl 'http://192.168.0.176/v1/admin/api/authrule_get?token=d17b8cc68817b19a1cd01320d607782b&page=1&count=10'

if cmd:find("^authrule_") then
	return require("admin.authrule").run(cmd)
end 
