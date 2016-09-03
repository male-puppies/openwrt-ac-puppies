local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local common = require("common")
local cfglib = require("cfglib")
local board = require("cfgmgr.board")
local network = require("cfgmgr.network")

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
end

udp_map["iface_get"] = function(p, ip, port)
	local board_m = board.load()
	local network_m = network.load()
	local ports, options, networks = board_m.ports, board_m.options, board_m.networks
	local net_name, net_cfg = network_m.name, network_m.network

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
	local res = {ports = ports, options = options, networks = networks, network = network_m}
	reply(ip, port, 0, res)
end

udp_map["iface_list"] = function(p, ip, port)
	local m = network.load()
	local net_name, net_cfg = m.name, m.network

	local ifaces = {}
	for iface, _ in pairs(net_cfg) do
		table.insert(ifaces, iface)
	end
	local res = ifaces
	reply(ip, port, 0, res)
end

udp_map["iface_set"] = function(p, ip, port)
	local config = p.network

	local _ = network.save(config)
	reply(ip, port, 0, "ok")
	mqtt:publish("a/ac/performer", js.encode({pld = {cmd = "network"}}))
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
