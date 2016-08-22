local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")

local udp_srv, mqtt

local udp_map = {}
udp_map["aclog"] = function(cmd)
	print("aclog:", js.encode(cmd))

end

local function dispatch_udp(cmd)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

local function init(p, u)
	udp_srv, mqtt = p, u
end

return {init = init, dispatch_udp = dispatch_udp}