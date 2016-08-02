local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")

local tcp_map = {}
local mqtt
local function init(p)
	mqtt = p
end

local function dispatch_tcp(cmd)
	print(11111111, js.encode(cmd))
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd.data)
	end
end

tcp_map["network"] = function(p)
	print(2222, js.encode(p))

end

return {init = init, dispatch_tcp = dispatch_tcp}

 