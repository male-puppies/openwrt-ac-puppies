local reply_e = require("admin.authlib").reply_e

-- 检查uri格式
local uri = ngx.var.uri
local cmd, ver = uri:match("/admin/api/(.-)/(.+)")
if not (cmd and ver) then
	return reply_e({e = "invalid request"})
end

local cmd_map = {}

-- curl 'http://127.0.0.1/admin/api/login/v01?username=wjrc&password=wjrc0409'
if cmd == "login" then 
	return require("admin.login").run()
end

-- curl 'http://127.0.0.1/admin/api/zone_get/v01?page=1&count=10'
if cmd:find("^zone_") then
	return require("admin.zone").run(cmd)
end 
