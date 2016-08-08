local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local common = require("common")
local ipops = require("ipops")
local bit = require("bit")

local read = common.read

local function load_board()
	local path = "/etc/config/board.json"
	local s = read(path)	assert(s)
	local m = js.decode(s)	assert(m)
	local ports, options, networks = m.ports, m.options, m.networks	assert(ports and options and networks)
	local port_map = {}
	local switchs = {}

	for _, dev in ipairs(ports) do
		if dev.type == "switch" then
			local ports = {}
			for idx, port in ipairs(dev.outer_ports) do
				table.insert(port_map, {ifname=dev.ifname .. "." .. idx, mac = port.mac})
				table.insert(ports, {vlan = idx, ports = port.num .. " " .. dev.inner_port .. "t"})
			end
			table.insert(switchs, {device = dev.device, ports = ports})
		elseif dev.type == "ether" then
			table.insert(port_map, {ifname=dev.ifname, mac = dev.outer_ports[1].mac})
		end
	end

	return {switchs = switchs, ports = port_map, options = options, networks = networks}
end

local function generate_board_cmds(board)
	local arr = {}
	for idx, switch in ipairs(board.switchs) do
		table.insert(arr, string.format("while uci delete network.@switch[0] >/dev/null 2>&1; do :; done"))
		table.insert(arr, string.format("obj=`uci add network switch`"))
		table.insert(arr, string.format("test -n \"$obj\" && {"))
		table.insert(arr, string.format("	uci set network.$obj.name='%s'", switch.device))
		table.insert(arr, string.format("	uci set network.$obj.reset='1'"))
		table.insert(arr, string.format("	uci set network.$obj.enable_vlan='1'"))
		table.insert(arr, string.format("	uci set network.$obj.enable_vlan='1'"))
		table.insert(arr, string.format("}"))
		table.insert(arr, string.format("while uci delete network.@switch_vlan[0] >/dev/null 2>&1; do :; done"))
		for i, port in ipairs(switch.ports) do
			table.insert(arr, string.format("obj=`uci add network switch_vlan`"))
			table.insert(arr, string.format("test -n \"$obj\" && {"))
			table.insert(arr, string.format("	uci set network.$obj.device='%s'", switch.device))
			table.insert(arr, string.format("	uci set network.$obj.vlan='%u'", port.vlan))
			table.insert(arr, string.format("	uci set network.$obj.ports='%s'", port.ports))
			table.insert(arr, string.format("}"))
		end
	end
	return table.concat(arr, "\n")
end

local function load_network()
	local path = "/etc/config/network.json"
	local s = read(path)	assert(s)
	local m = js.decode(s)	assert(m)
	return m.network
end

local function generate_network_cmds(board, network)
	local uci_network = {}
	local uci_zone = {
		lan = {id = 0, ifname = {}, network = {}},
		wan = {id = 1, ifname = {}, network = {}}
	}
	local arr = {}

	table.insert(arr, string.format("while uci delete dhcp.@dhcp[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr, string.format("while uci delete network.@interface[1] >/dev/null 2>&1; do :; done"))

	for name, option in pairs(network) do
		uci_network[name] = option
		if #option.ports > 1 then
			uci_network[name].type = 'bridge'
		end

		if not option.mac or option.mac == "" then
			uci_network[name].mac = board.ports[option.ports[1]].mac
		end

		uci_network[name].ifname = ""
		for _, i in ipairs(option.ports) do
			if uci_network[name].ifname == "" then
				uci_network[name].ifname = board.ports[i].ifname
			else
				uci_network[name].ifname = uci_network[name].ifname .. " " .. board.ports[i].ifname
			end
		end

		table.insert(arr, string.format("uci set network.%s=interface", name))
		table.insert(arr, string.format("uci set network.%s.macaddr='%s'", name, uci_network[name].mac))
		table.insert(arr, string.format("uci set network.%s.ifname='%s'", name, uci_network[name].ifname))

		if uci_network[name].type and uci_network[name].type ~= "" then
			table.insert(arr, string.format("uci set network.%s.type='%s'", name, uci_network[name].type))
		end
		if uci_network[name].mtu and uci_network[name].mtu ~= "" then
			table.insert(arr, string.format("uci set network.%s.mtu='%s'", name, uci_network[name].mtu))
		end
		if uci_network[name].metric and uci_network[name].metric ~= "" then
			table.insert(arr, string.format("uci set network.%s.metric='%s'", name, uci_network[name].metric))
		end
		if uci_network[name].proto == "static" then
			table.insert(arr, string.format("uci set network.%s.proto='static'", name))
			table.insert(arr, string.format("uci set network.%s.ipaddr='%s'", name, uci_network[name].ipaddr))
		elseif uci_network[name].proto == "dhcp" then
			table.insert(arr, string.format("uci set network.%s.proto='dhcp'", name))
		elseif uci_network[name].proto == "pppoe" then
			table.insert(arr, string.format("uci set network.%s.proto='pppoe'", name))
			table.insert(arr, string.format("uci set network.%s.username='%s'", name, uci_network[name].pppoe_account))
			table.insert(arr, string.format("uci set network.%s.password='%s'", name, uci_network[name].pppoe_password))
		else
			table.insert(arr, string.format("uci set network.%s.proto='none'", name))
		end

		if uci_network[name].proto == "static" and uci_network[name].dhcpd and uci_network[name].dhcpd["enabled"] == 1 then
			local ipaddr, netmask = ipops.get_ip_and_mask(uci_network[name].ipaddr)
			local startip = ipops.ipstr2int(uci_network[name].dhcpd["start"])
			local endip = ipops.ipstr2int(uci_network[name].dhcpd["end"])
			local s, e = bit.bxor(startip, bit.band(ipaddr, netmask)), bit.bxor(endip - bit.band(ipaddr, netmask))

			table.insert(arr, string.format("uci set dhcp.%s=dhcp", name))
			table.insert(arr, string.format("uci set dhcp.%s.interface='%s'", name, name))
			table.insert(arr, string.format("uci set dhcp.%s.start='%u'", name, s))
			table.insert(arr, string.format("uci set dhcp.%s.end='%u'", name, e))
			table.insert(arr, string.format("uci set dhcp.%s.leasetime='%s'", name, uci_network[name].dhcpd["leasetime"]))
			table.insert(arr, string.format("uci set dhcp.%s.force='1'", name))
			table.insert(arr, string.format("uci set dhcp.%s.subnet='%s'", name, uci_network[name].ipaddr))
			table.insert(arr, string.format("uci set dhcp.%s.dynamicdhcp='%u'", name, uci_network[name].dhcpd["dynamicdhcp"] or 1))
			if uci_network[name].dhcpd["dns"] then
				table.insert(arr, string.format("uci add_list dhcp.%s.dhcp_option='6,%s'", name, uci_network[name].dhcpd["dns"]))
			end
		end

		if name:find("^lan") then
			table.insert(uci_zone.lan.network, name)
		else
			table.insert(uci_zone.wan.network, name)
		end

		if uci_network[name].proto == "static" or uci_network[name].proto == "dhcp" then
			if uci_network[name].type == 'bridge' then
				if name:find("^lan") then
					table.insert(uci_zone.lan.ifname, "br-" .. name)
				else
					table.insert(uci_zone.wan.ifname, "br-" .. name)
				end
			else
				if name:find("^lan") then
					table.insert(uci_zone.lan.ifname, uci_network[name].ifname)
				else
					table.insert(uci_zone.wan.ifname, uci_network[name].ifname)
				end
			end
		elseif uci_network[name].proto == "pppoe" then
			if name:find("^lan") then
				table.insert(uci_zone.lan.ifname, "pppoe-" .. name)
			else
				table.insert(uci_zone.wan.ifname, "pppoe-" .. name)
			end
		end
	end

	table.insert(arr, string.format("while uci delete nos-zone.@zone[0] >/dev/null 2>&1; do :; done"))
	for name, zone in pairs(uci_zone) do
		table.insert(arr, string.format("obj=`uci add nos-zone zone`"))
		table.insert(arr, string.format("test -n \"$obj\" && {"))
		table.insert(arr, string.format("	uci set nos-zone.$obj.name='%s'", name))
		table.insert(arr, string.format("	uci set nos-zone.$obj.id='%s'", zone.id))
		for _, ifname in ipairs(zone.ifname) do
			table.insert(arr, string.format("	uci add_list nos-zone.$obj.ifname='%s'", ifname))
		end
		table.insert(arr, string.format("}"))
	end

	table.insert(arr, string.format("while uci delete firewall.@zone[0] >/dev/null 2>&1; do :; done"))
	for name, zone in pairs(uci_zone) do
		table.insert(arr, string.format("obj=`uci add firewall zone`"))
		table.insert(arr, string.format("test -n \"$obj\" && {"))
		table.insert(arr, string.format("	uci set firewall.$obj.name='%s'", name))
		table.insert(arr, string.format("	uci set firewall.$obj.id='%s'", zone.id))
		table.insert(arr, string.format("	uci set firewall.$obj.input='ACCEPT'"))
		table.insert(arr, string.format("	uci set firewall.$obj.output='ACCEPT'"))
		table.insert(arr, string.format("	uci set firewall.$obj.forward='%s'", name:find("^lan") and "ACCEPT" or "REJECT"))
		table.insert(arr, string.format("	uci set firewall.$obj.mtu_fix='1'"))
		for _, network in ipairs(zone.network) do
			table.insert(arr, string.format("	uci add_list firewall.$obj.network='%s'", network))
		end
		table.insert(arr, string.format("}"))
	end

	return table.concat(arr, "\n")
end

local function network_reload()
	local board = load_board()
	local network = load_network()
	local cmd = ""
	local arr = {}

	table.insert(arr, generate_board_cmds(board))
	table.insert(arr, generate_network_cmds(board, network))
	table.insert(arr, string.format("uci commit network"))
	table.insert(arr, string.format("uci commit dhcp"))
	table.insert(arr, string.format("uci commit nos-zone"))
	table.insert(arr, string.format("uci commit firewall"))
	table.insert(arr, string.format("sleep 1"))
	table.insert(arr, string.format("/etc/init.d/network restart"))
	table.insert(arr, string.format("/etc/init.d/dnsmasq restart"))
	table.insert(arr, string.format("/etc/init.d/nos-zone restart"))
	table.insert(arr, string.format("/etc/init.d/firewall restart"))

	cmd = table.concat(arr, "\n")
	print(cmd)
	os.execute(cmd)
end

local tcp_map = {}
local mqtt
local function init(p)
	mqtt = p
	network_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd.data)
	end
end

tcp_map["network"] = function(p)
	network_reload()
end

return {init = init, dispatch_tcp = dispatch_tcp}
