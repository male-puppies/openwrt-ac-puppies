local js = require("cjson.safe")
local common = require("common")

local read = common.read 

local function parse_board()
	local path = "/etc/config/board.json"
	local s = read(path) 	assert(s)
	local m = js.decode(s) 	assert(m)
	local board, default = m.board, m.default 	assert(board and default)
	
	local port_map, idx = {}, 0
	for chip, r in pairs(board) do
		local type = r.type
		if type == "switch" then 
			for _, port in ipairs(r.outer_ports) do 
				idx = idx + 1
				port_map[idx] = {chip = chip, type = r.type}
			end
		elseif type == "ether" then 
			idx = idx + 1
			port_map[idx] = {chip = chip, type = r.type}
		end
	end

	local default_cfg = {}
	for _, r in pairs(default) do 
		local name = r.name 
		assert(not default_cfg[name])
		default_cfg[name] = r.map
	end

	return {port_map = port_map, default_cfg = default_cfg}
end

local function parse_network(board)
	local path = "/etc/config/network.json"
	local s = read(path) 	assert(s)
	local m = js.decode(s) 	assert(m)
	local name, network = m.name, m.network 		assert(name and network)
	if name ~= "custom" then 
		local default = board.default_cfg[name] 	assert(default)
	end

	local port_map = board.port_map 				assert(port_map)
	local split = {lan = {}, wan = {}}
	for net, m in pairs(network) do 
		if net:find("^lan") then
			m.net_name = net
			table.insert(split.lan, m)
		elseif net:find("^wan") then
			m.net_name = net
			table.insert(split.wan, m)
		end
	end

	-- lan 
	local cmp = function(a, b) return a.net_name < b.net_name end 
	table.sort(split.lan, cmp)
	table.sort(split.wan, cmp)

	local narr = {}
	for idx, r in ipairs(split.lan) do 
		local ifname = "br-lan" .. (idx - 1)
		local m = {
			ifname = ifname,
			ifdesc = ifname,
			ethertype = "bridge",
			iftype = 3,
			proto = r.proto,
			mtu = r.mtu,
			mac = r.mac:lower(),
			static_ip = r.ipaddr,
		}
		
		local dhcpd = r.dhcpd
		if dhcpd then 
			m.dhcp_enable = dhcpd.enabled
			m.dhcp_start = dhcpd.start
			m.dhcp_end = dhcpd["end"]
			m.dhcp_lease = dhcpd.leasetime
			m.dhcp_dynamic = dhcpd.dynamicdhcp
			m.dhcp_lease = js.encode(dhcpd.staticleases)
			m.dns = dhcpd.dns
		end

		table.insert(narr, m)
		for _, idx in pairs(r.ports) do
			local port = port_map[idx] 			assert(port)
			local chip = port.chip
			local name = chip .. "." .. idx
			local m = {
				ifname = name,
				ifdesc = name,
				ethertype = "8021q",
				iftype = 2,
				parent = ifname,
			}	
			table.insert(narr, m)
		end
	end

	for wan_id, r in ipairs(split.wan) do 
		local idx = r.ports[1] 					assert(idx)
		local port = port_map[idx] 				assert(port, idx)

		local ifname = "wan" .. (wan_id - 1)
		local m = {
			ifname = ifname,
			ifdesc = ifname,
			iftype = 3,
			ethertype = port.type == "switch" and "8021q" or "ether",
			proto = r.proto,
			mtu = r.mtu,
			metric = r.metric,
			mac = r.mac:lower()
		}

		local proto = r.proto
		if proto == "static" then 
			m.static_ip, m.gateway, m.dns = r.ipaddr, r.gateway, r.dns
		elseif proto == "pppoe" then
			m.pppoe_account, m.pppoe_password = r.pppoe_account, r.pppoe_password
		end

		table.insert(narr, m)
	end

	return narr
end

local function parse()
	local board = parse_board()
	local narr = parse_network(board)
	return narr
end

return {parse = parse}
