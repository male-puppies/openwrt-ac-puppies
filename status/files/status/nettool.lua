-- yjs

local fp 	= require("fp")
local ski 	= require("ski")
local log 	= require("log")
local js 	= require("cjson.safe")
local lib	= require("statuslib")
local misc 	= require("ski.misc")

local udp_map = {}
local simple, udpsrv, mqtt, reply

local function init(u, p)
	udpsrv, mqtt = u, p

	-- local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	-- simple 	= simplesql.new(dbrpc)
	reply 	= lib.gen_reply(udpsrv)
end

local tool_map = {}

local function run_common(ip, port, check_cmd, run_cmd, max)
	local s = misc.execute(check_cmd)
	if tonumber(s) > max then
		return reply(ip, port, 0, "too many commands are running, please wait.")
	end

	return reply(ip, port, 0, misc.execute(run_cmd))
end

-- {"cmd":"nettool_get","timeout":30,"tool":"ping","host":"www.baidu.com"}
function tool_map.ping(p, ip, port)
	local check_cmd = "ps | grep ping | grep timeout | grep -v sh  | wc -l"
	local cmd = string.format("timeout -t %s ping -c 4 '%s' 2>&1", p.timeout, p.host)
	return run_common(ip, port, check_cmd, cmd, 5)
end

-- {"cmd":"nettool_get","timeout":30,"tool":"traceroute","host":"www.baidu.com"}
function tool_map.traceroute(p, ip, port)
	local check_cmd = "ps | grep traceroute | grep timeout | grep -v sh  | wc -l"
	local cmd = string.format("timeout -t %s traceroute '%s' -l -n 2>&1", p.timeout, p.host)
	return run_common(ip, port, check_cmd, cmd, 5)
end

-- {"cmd":"nettool_get","timeout":30,"tool":"nslookup","host":"www.baidu.com"}
function tool_map.nslookup(p, ip, port)
	local cmd = string.format("timeout -t %s nslookup '%s' 2>&1", p.timeout, p.host)
	local check_cmd = "ps | grep nslookup | grep timeout | grep -v sh  | wc -l"
	return run_common(ip, port, check_cmd, cmd, 5)
end

-- {"cmd":"nettool_get","timeout":30,"tool":"ping","host":"www.baidu.com"}
udp_map["nettool_get"] = function(p, ip, port)
	return ski.go(tool_map[p.tool], p, ip, port)
end

return {init = init, dispatch_udp = lib.gen_dispatch_udp(udp_map)}