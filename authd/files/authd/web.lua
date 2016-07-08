local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")

local cmd_map = {}
local myconn

local function init(m)
	myconn = m
end

local function dispatch(cmd)
	local f = cmd_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

-- curl 'http://1.0.0.8/auth/weblogin?magic=1&id=1&ip=192.168.0.3&mac=00:00:00:00:00:01&username=user&password=passwd'
cmd_map["/auth/weblogin"] = function(cmd)
	for k, v in pairs(cmd) do
		print(k, v)
	end
	return nil, "test"
end

return {init = init, dispatch = dispatch}

