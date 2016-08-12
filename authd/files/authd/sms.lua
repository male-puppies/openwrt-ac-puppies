local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local authlib = require("authlib")

local udp_map = {}
local function init(u, p)
	udpsrv, mqtt = u, p
	reply = authlib.gen_reply(udpsrv)
end

return {init = init, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

