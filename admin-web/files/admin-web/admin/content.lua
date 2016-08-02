package.path = "/usr/share/admin-web/?.lua;" .. package.path
local reply_e = require("admin.authlib").reply_e

-- 检查uri格式
local uri = ngx.var.uri
local ver, cmd = uri:match("/(.-)/admin/api/(.+)")
if not (cmd and ver) then
	return reply_e({e = "invalid request"})
end

local cmd_map = {}

-- curl 'http://127.0.0.1/admin/api/login/v01?username=wjrc&password=wjrc0409'
if cmd == "login" then 
	return require("admin.login").run()
end

-- curl 'http://127.0.0.1/admin/api/zone_get/v01?token=1b2c3e72693b4cd49a17a9daa5e650b8&page=1&count=10'
-- curl 'http://127.0.0.1/admin/api/zone_del/v01?token=1b2c3e72693b4cd49a17a9daa5e650b8' -d "zids=0,1"
-- curl 'http://127.0.0.1/admin/api/zone_set/v01?token=1b2c3e72693b4cd49a17a9daa5e650b8' -d "zid=0&zonename=z1&zonetype=3&zonedesc=hello-gun"
-- curl 'http://127.0.0.1/admin/api/zone_add/v01?token=1b2c3e72693b4cd49a17a9daa5e650b8' -d "zonename=z1&zonetype=3&zonedesc=hello, 'world'"
if cmd:find("^zone_") then
	return require("admin.zone").run(cmd)
end 

if cmd:find("^iface_") then
	return require("admin.iface").run(cmd)
end 

