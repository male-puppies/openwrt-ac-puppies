local js = require("cjson.safe")
local common = require("common")

local read = common.read

local function load_board()
	local path = "/etc/config/board.json"
	local s = read(path)	assert(s)
	local m = js.decode(s)	assert(m)
	local ports, options, networks = m.ports, m.options, m.networks	assert(ports and options and networks)
	local port_map = {}

	local vlan = 1
	for _, dev in ipairs(ports) do
		if dev.type == "switch" then
			for idx, port in ipairs(dev.outer_ports) do
				port_map[vlan] = {ifname = dev.ifname .. "." .. vlan, mac = port.mac}
				vlan = vlan + 1
			end
		elseif dev.type == "ether" then
			port_map[vlan] = {ifname = dev.ifname, mac = dev.outer_ports[1].mac}
			vlan = vlan + 1
		end
	end

	return {ports = port_map, options = options, networks = networks}
end

return {load = load_board}
