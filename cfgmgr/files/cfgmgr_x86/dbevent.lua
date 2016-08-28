local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local js = require("cjson.safe")

local tcp_map = {}
local mqtt, udpsrv, db
local function init(p, u, m)
	mqtt, udpsrv, db = p, u, m
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd.data)
	end
end

tcp_map["dbsync"] = function(p)
	local authrule = p.authrule
	if not authrule then
		return
	end

	log.info("authrule change, reolad. %s", js.encode(authrule))
	cfg.clear_authtype()
end

return {init = init, dispatch_tcp = dispatch_tcp}

