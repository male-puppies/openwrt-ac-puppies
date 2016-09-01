local js = require("cjson.safe")
local common = require("common")
local board = require("cfgmgr.board")

local read, save_safe = common.read, common.save_safe

local function load_network()
	local path = "/etc/config/network.json"
	local s = read(path) 	assert(s)
	local m = js.decode(s) 	assert(m)

	return m
end

local function save_network(config)
	local _ = config and save_safe("/etc/config/network.json", js.encode(config))
end

-- @return iface_map, ifname_map
-- iface_map["br-lan1"] = "lan1"
-- ifname_map["lan1"] = "br-lan1"
local function load_network_map()
	local board_m = board.load()
	local ports = board_m.ports

	local network_m = load_network()
	local network = network_m.network

	local iface_map = {}
	local ifname_map = {}
	local uci_network = {}

	for name, option in pairs(network) do
		uci_network[name] = option
		if name:find("^lan") or #option.ports > 1 then
			uci_network[name].type = 'bridge'
		end

		uci_network[name].ifname = ""
		local ifnames = {}
		local vlan = nil
		for _, i in ipairs(option.ports) do
			if ports[i].type == 'switch' then
				vlan = vlan or tostring(i)
				ifnames[ports[i].ifname .. "." .. vlan] = tonumber(vlan)
			else
				ifnames[ports[i].ifname] = i
			end
		end

		for ifname, i in pairs(ifnames) do
			if uci_network[name].ifname == "" then
				uci_network[name].ifname = ifname
			else
				uci_network[name].ifname = uci_network[name].ifname .. " " .. ifname
			end
		end

		if uci_network[name].proto == "static" or uci_network[name].proto == "dhcp" then
			if uci_network[name].type == 'bridge' then
				iface_map["br-" .. name] = name
				ifname_map[name] = "br-" .. name
			else
				iface_map[uci_network[name].ifname] = name
				ifname_map[name] = uci_network[name].ifname
			end
		elseif uci_network[name].proto == "pppoe" then
			iface_map["pppoe-" .. name] = name
			ifname_map[name] = "pppoe-" .. name
		end
	end

	return iface_map, ifname_map
end

return {
	load = load_network,
	save = save_network,
	load_network_map = load_network_map,
}
