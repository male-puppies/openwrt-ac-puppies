local js = require("cjson.safe")
local common = require("common")

local read = common.read

local function load_board()
	local path = "/etc/config/board.json"
	local s = read(path)	assert(s)
	local m = js.decode(s)	assert(m)
	local ports, options, networks = m.ports, m.options, m.networks	assert(ports and options and networks)

	return {options = options, networks = networks}
end

local board = load_board()

local network = {}

if board.options[1] then
	network.name = board.options[1].name
	network.network = {}
	for i, port in ipairs(board.options[1].layout) do
		network.network[port.name] = board.networks[port.name]
		network.network[port.name].ports = network.network[port.name].ports or {}
		table.insert(network.network[port.name].ports, i)
	end
end

print(js.encode(network))
