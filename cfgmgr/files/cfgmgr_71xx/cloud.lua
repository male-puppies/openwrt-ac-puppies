local fp = require("fp")
local ski = require("ski")
local lfs = require("lfs")
local log = require("log")
local js = require("cjson.safe")
local common = require("common")
local cfglib = require("cfglib")
local const = require("constant")

local read, save_safe = common.read, common.save_safe

local udp_map = {}
local udpsrv, mqtt, reply

local default_cloud = {ac_host = "", ac_port = 61886, account = "", descr = ""}

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
end

udp_map["cloud_get"] = function(p, ip, port)
	local path = const.cloud_config
	if not lfs.attributes(path) then
		return reply(ip, port, 0, default_cloud)
	end

	local s = read(path)
	local res = js.decode(s)
	local s = read("/tmp/memfile/cloudcli.json") or '{"state":0}'
	for k, v in pairs(js.decode(s)) do
		res[k] = v
	end

	reply(ip, port, 0, js.encode(res))
end

udp_map["cloud_set"] = function(p, ip, port)
	p.cmd = nil

	local path = const.cloud_config
	if lfs.attributes(path) then
		local s = read(path)
		if s then
			local m = js.decode(s) or {}
			if fp.same(m, p) then
				return reply(ip, port, 0, "ok")
			end
		end
	end

	local s = js.encode(p)
	save_safe(path, s)

	log.info("cloud change %s", s)

	-- 发送消息给proxybase & cloudcli
	local update = js.encode({pld = {cmd = "cloud_set", data = ""}})
	mqtt:publish("a/ac/proxybase", update)
	mqtt:publish("a/local/cfgmgr", update)
	reply(ip, port, 0, "ok")
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
