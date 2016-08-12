local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local authlib = require("authlib")

local udp_map = {}
local udpsrv, mqtt, reply

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = authlib.gen_reply(udpsrv)
end

udp_map["/bypass_host"] = function(p, ip, port) 
	reply(ip, port, 0, "ok")
end

return {init = init, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

