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

udp_map["mwan_get"] = function(p, ip, port)
	local mwan_path = '/etc/config/mwan.json'
	local mwan_s = read(mwan_path) or '{}'
	local mwan_m = js.decode(mwan_s)	assert(mwan_m)
	local network_path = '/etc/config/network.json'
	local network_s = read(network_path)	assert(network_path)
	local network_m = js.decode(network_s)	assert(network_m)

	local res = {
		ifaces = {},
		policy = mwan_m.policy or "balanced",
		main_iface = mwan_m.main_iface or {},
	}

	for iface, _ in pairs(network_m.network) do
		if iface:find("^wan") then
			local iface_exist = false
			local new_ifc = nil
			for _, ifc in ipairs(mwan_m.ifaces or {}) do
				if ifc.name == iface then
					iface_exist = true
					new_ifc = ifc
					break
				end
			end
			if iface_exist then
				table.insert(res.ifaces, new_ifc)
			else
				table.insert(res.ifaces, {name = iface, bandwidth = 0, enable = 0})
			end
		end
	end
	reply(ip, port, 0, res)
end

udp_map["mwan_set"] = function(p, ip, port)
	local mwan_m = p.mwan
	--local network_path = '/etc/config/network.json'
	--local network_s = read(network_path)	assert(network_path)
	--local network_m = js.decode(network_s)	assert(network_m)

	local config = mwan_m
	local _ = config and save_safe("/etc/config/mwan.json", js.encode(config))
	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "mwan"}}))
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
