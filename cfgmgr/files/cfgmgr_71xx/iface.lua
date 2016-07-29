local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local code = require("code")
local common = require("common")

local read = common.read

local udp_map = {}
local udpsrv, mqtt, dbrpc, simple

local function init(u, p)
	udpsrv, mqtt = u, p
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

local reply_obj = {status = 0, data = 0}
local function reply(ip, port, r, d)
	reply_obj.status, reply_obj.data = r, d
	udpsrv:send(ip, port, js.encode(reply_obj))
end

local function dispatch_udp(cmd, ip, port)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
end

udp_map["iface_get"] = function(p, ip, port)
	local load = require("board").load
	local r = load()
	local ports, options, networks = r.ports, r.options, r.networks	
	local path = "/etc/config/network.json"
	local s = read(path) 	assert(s)
	local m = js.decode(s) 	assert(m)
	local net_name, net_cfg = m.name, m.network

	local custom_map = {}
	if net_name ~= "custom" then 
		local lan0, wan0 = {}, {#ports}
		for i = 1, #ports - 1 do 
			table.insert(lan0, i)
		end
		custom_map.lan0,custom_map.wan0 = lan0, wan0
	else 
		for iface, r in pairs(net_cfg) do 
			custom_map[iface] = r.ports
		end
	end
	table.insert(options,  {name = "custom", map = custom_map})
	local res = {ports = ports, options = options, networks = networks, network = m}
	reply(ip, port, 0, res)
end

udp_map["iface_set"] = function(p, ip, port)
	reply(ip, port, 0, "test")
end

udp_map["iface_add"] = function(p, ip, port)
	reply(ip, port, 0, "test")
end

udp_map["iface_del"] = function(p, ip, port)
	reply(ip, port, 0, "test")
end

return {init = init, dispatch_udp = dispatch_udp}
