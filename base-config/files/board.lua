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
	for ifname, ports in pairs(board.options[1].map) do
		network.network[ifname] = board.networks[ifname]
		network.network[ifname].ports = ports
	end
end

print(js.encode(network))
