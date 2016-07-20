local reply_e = require("admin.global").reply_e

-- 检查uri格式
local uri = ngx.var.uri
local cmd, ver = uri:match("/admin/api/(.-)/(.+)")
if not (cmd and ver) then
	return reply_e({e = "invalid request"})
end

local cmd_map = {}

-- curl 'http://192.168.0.213:8088/telecom/api/login/001?username=wjrc&password=wjrc0409'
function cmd_map.login() 		return require("admin.login").run() 			end

local f = cmd_map[cmd]
if f then return f(cmd) end

reply_e("invalid request")
