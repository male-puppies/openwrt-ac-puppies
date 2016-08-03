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

-- curl 'http://192.168.0.176/v1/admin/api/iface_get?token=a8b7aaa79d5963ee3303633c1b9d4a4e'
-- curl 'http://192.168.0.176/v1/admin/api/iface_set?token=a8b7aaa79d5963ee3303633c1b9d4a4e' -d 'arg=json_string'
if cmd:find("^iface_") then
	return require("admin.iface").run(cmd)
end 

-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_del?token=a8b7aaa79d5963ee3303633c1b9d4a4e' -d 'ipgids=[0,1,2,3]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_set?token=a8b7aaa79d5963ee3303633c1b9d4a4e' -d 'ipgid=1&ipgrpname=xxx&ipgrpdesc=yyy&ranges=["0.0.0.7/16"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_add?token=a8b7aaa79d5963ee3303633c1b9d4a4e' -d 'ipgid=63&ipgrpname=xxx2&ipgrpdesc=yyy&ranges=["0.0.0.7-0.0.0.999"]'
-- curl 'http://192.168.0.176/v1/admin/api/ipgroup_get?token=a8b7aaa79d5963ee3303633c1b9d4a4e&page=1&count=10&order=ipgrpname&desc=1&search=ipgrpname&like=ALL'
if cmd:find("^ipgroup_") then
	return require("admin.ipgroup").run(cmd)
end 
