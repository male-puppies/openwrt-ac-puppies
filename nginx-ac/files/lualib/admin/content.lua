local reply_e = require("admin.global").reply_e

-- 检查uri格式
local uri = ngx.var.uri
local cmd, ver = uri:match("/admin/api/(.-)/(.+)")
if not (cmd and ver) then
	return reply_e({e = "invalid request"})
end

local cmd_map = {}

-- curl 'http://127.0.0.1/admin/api/login/v01?username=wjrc&password=wjrc0409'
function cmd_map.login() 		require("admin.login").run() 			end

-- curl 'http://127.0.0.1/admin/api/zone_get/v01?page=1&count=10'
function cmd_map.zone_get(cmd) 	require("admin.zone").run(cmd) 			end

function cmd_map.numb() 		reply_e("invalid request " .. uri)		end

local _ = (cmd_map[cmd] or cmd_map.numb)(cmd)

