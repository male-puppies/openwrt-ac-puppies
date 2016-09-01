local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local common = require("common")
local cfglib = require("cfglib")
local mwan = require("cfgmgr.mwan")

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

udp_map["mwan_get"] = function(p, ip, port)
	local mwan_m = mwan.load()

	local res = mwan_m
	reply(ip, port, 0, res)
end

udp_map["mwan_set"] = function(p, ip, port)
	local mwan_m = p.mwan

	local config = mwan_m
	local _ = mwan.save(config)
	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "mwan"}}))
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
