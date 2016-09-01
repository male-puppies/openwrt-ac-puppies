local js = require("cjson.safe")
local common = require("common")

local read = common.read

local function load_board()
	local path = "/etc/config/board.json"
	local s = read(path)	assert(s)
	local m = js.decode(s)	assert(m)
	local port_map = {}

	for _, dev in ipairs(m.ports) do
		if dev.type == "switch" then
			for idx, port in ipairs(dev.outer_ports) do
				table.insert(port_map, {ifname = dev.ifname, mac = port.mac, type = dev.type, device = dev.device, num = port.num, inner_port = dev.inner_port})
			end
		elseif dev.type == "ether" then
			table.insert(port_map, {ifname = dev.ifname, mac = dev.outer_ports[1].mac, type = dev.type, device = dev.device})
		end
	end

	m.ports = port_map
	return m
end

return {
	load = load_board,
}
