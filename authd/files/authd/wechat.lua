local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")

local udp_map = {}
local udpsrv, mqtt

local function init(u, p)
	udpsrv, mqtt = u, p
end

local function reply(ip, port, r, d) 
	udpsrv:send(ip, port, js.encode({status = r, data = d}))
end

local function dispatch_udp(cmd, ip, port)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
end

udp_map["/bypass_host"] = function(p, ip, port) 
	reply(ip, port, 0, "ok")
end

return {init = init, dispatch_udp = dispatch_udp}

