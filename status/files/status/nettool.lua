local fp 		= require("fp")
local ski 		= require("ski")
local log 		= require("log")
local js 		= require("cjson.safe")
local lib		= require("statuslib")
local misc 		= require("ski.misc")

local udp_map = {}

local simple, udpsrv, mqtt, reply

local function init(u, p)
	udpsrv, mqtt = u, p

	-- local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	-- simple 	= simplesql.new(dbrpc)
	reply 	= lib.gen_reply(udpsrv)
end

local tool_map = {}

-- {"cmd":"nettool_get","timeout":30,"tool":"ping","host":"www.baidu.com"}
local ping_running = false
function tool_map.ping(p, ip, port)
	local cmd = string.format("timeout -t %s ping -c 4 '%s' 2>&1", p.timeout, p.host)
	local s = misc.execute(cmd)
	return reply(ip, port, 0, s)
end

-- {"cmd":"nettool_get","timeout":30,"tool":"ping","host":"www.baidu.com"}
udp_map["nettool_get"] = function(p, ip, port)
	return tool_map[p.tool](p, ip, port)
end

return {init = init, dispatch_udp = lib.gen_dispatch_udp(udp_map)}