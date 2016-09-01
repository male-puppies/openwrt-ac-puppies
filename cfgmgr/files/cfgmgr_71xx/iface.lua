local ski = require("ski")
local log = require("log")
local board = require("board")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local common = require("common")
local cfglib = require("cfglib")

local read, save_safe, arr2map = common.read, common.save_safe, common.arr2map

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

udp_map["iface_get"] = function(p, ip, port)
	local r = board.load()
	local ports, options, networks = r.ports, r.options, r.networks
	local path = "/etc/config/network.json"
	local s = read(path) 	assert(s)
	local m = js.decode(s) 	assert(m)
	local net_name, net_cfg = m.name, m.network

	local layout = {}
	for iface, cfg in pairs(net_cfg) do
		for _, i in ipairs(cfg.ports) do
			layout[i] = {name = iface, enable = 1, fixed = 0}
		end
	end
	for i = 1, #ports do
		if not layout[i] then
			layout[i] = {name = "", enable = 0, fixed = 0}
		end
		layout[i].fixed = options[1].layout[i].fixed
	end

	table.insert(options,  {name = "custom", layout = layout})
	local res = {ports = ports, options = options, networks = networks, network = m}
	reply(ip, port, 0, res)
end

udp_map["iface_list"] = function(p, ip, port)
	local path = "/etc/config/network.json"
	local s = read(path) 	assert(s)
	local m = js.decode(s) 	assert(m)
	local net_name, net_cfg = m.name, m.network

	local ifaces = {}
	for iface, _ in pairs(net_cfg) do
		table.insert(ifaces, iface)
	end
	table.sort(ifaces)
	local res = ifaces
	reply(ip, port, 0, res)
end

udp_map["iface_set"] = function(p, ip, port)
	local config = p.network

	local _ = config and save_safe("/etc/config/network.json", js.encode(config))
	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "network"}}))
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
