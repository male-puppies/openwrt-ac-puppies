local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local common = require("common")
local rpccli = require("rpccli")
local ipops = require("ipops")
local md5 = require("md5")
local board = require("cfgmgr.board")
local network = require("cfgmgr.network")

local tcp_map = {}
local on_event_cb

local read = common.read

local function generate_network_cmds(board, network)
	local switchs = {}
	local uci_network = {}
	local uci_zone = {
		lan = {id = 0, ifname = {}, network = {}},
		wan = {id = 1, ifname = {}, network = {}}
	}
	local arr = {}
	arr["network"] = {}
	arr["dhcp"] = {}
	arr["nos-zone"] = {}
	arr["firewall"] = {}

	table.insert(arr["dhcp"], string.format("while uci delete dhcp.@dhcp[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr["network"], string.format("while uci delete network.@interface[1] >/dev/null 2>&1; do :; done"))
	table.insert(arr["network"], string.format("while uci delete network.@device[0] >/dev/null 2>&1; do :; done"))
	for name, option in pairs(network.network) do
		uci_network[name] = option
		if name:find("^lan") or #option.ports > 1 then
			uci_network[name].type = 'bridge'
		end

		uci_network[name].ifname = ""
		local ifnames = {}
		local vlan = nil
		for _, i in ipairs(option.ports) do
			if board.ports[i].type == 'switch' then
				vlan = vlan or tostring(i)
				switchs[board.ports[i].device] = switchs[board.ports[i].device] or {}
				switchs[board.ports[i].device][vlan] = switchs[board.ports[i].device][vlan] or {}
				switchs[board.ports[i].device][vlan]["outer_ports"] = switchs[board.ports[i].device][vlan]["outer_ports"] or {}
				table.insert(switchs[board.ports[i].device][vlan]["outer_ports"], board.ports[i].num)
				switchs[board.ports[i].device][vlan]["inner_port"] = board.ports[i].inner_port
				ifnames[board.ports[i].ifname .. "." .. vlan] = tonumber(vlan)
			else
				ifnames[board.ports[i].ifname] = i
			end
		end
		for ifname, i in pairs(ifnames) do
			if uci_network[name].ifname == "" then
				uci_network[name].ifname = ifname
			else
				uci_network[name].ifname = uci_network[name].ifname .. " " .. ifname
			end

			table.insert(arr["network"], string.format("obj=`uci add network device`"))
			table.insert(arr["network"], string.format("test -n \"$obj\" && {"))
			table.insert(arr["network"], string.format("	uci set network.$obj.name='%s'", ifname))
			if uci_network[name].mac and uci_network[name].mac ~= "" then
				table.insert(arr["network"], string.format("	uci set network.$obj.macaddr='%s'", uci_network[name].mac))
			else
				table.insert(arr["network"], string.format("	uci set network.$obj.macaddr='%s'", board.ports[i].mac))
			end
			table.insert(arr["network"], string.format("}"))
		end

		table.insert(arr["network"], string.format("uci set network.%s=interface", name))
		table.insert(arr["network"], string.format("uci set network.%s.ifname='%s'", name, uci_network[name].ifname))
		if uci_network[name].mac and uci_network[name].mac ~= "" then
			table.insert(arr["network"], string.format("uci set network.%s.macaddr='%s'", name, uci_network[name].mac))
		end
		if uci_network[name].type and uci_network[name].type ~= "" then
			table.insert(arr["network"], string.format("uci set network.%s.type='%s'", name, uci_network[name].type))
		end
		if uci_network[name].mtu and uci_network[name].mtu ~= "" then
			table.insert(arr["network"], string.format("uci set network.%s.mtu='%s'", name, uci_network[name].mtu))
		end
		if uci_network[name].metric and uci_network[name].metric ~= "" then
			table.insert(arr["network"], string.format("uci set network.%s.metric='%s'", name, uci_network[name].metric))
		end
		if uci_network[name].proto == "static" then
			table.insert(arr["network"], string.format("uci set network.%s.proto='static'", name))
			table.insert(arr["network"], string.format("uci set network.%s.ipaddr='%s'", name, uci_network[name].ipaddr))
			if uci_network[name].gateway and uci_network[name].gateway ~= "" then
				table.insert(arr["network"], string.format("uci set network.%s.gateway='%s'", name, uci_network[name].gateway))
			end
			if uci_network[name].dns and uci_network[name].dns ~= "" then
				local dns = uci_network[name].dns .. ","
				for ip in dns:gmatch("(.-),") do
					table.insert(arr["network"], string.format("uci add_list network.%s.dns='%s'", name, ip))
				end
			end
		elseif uci_network[name].proto == "dhcp" then
			table.insert(arr["network"], string.format("uci set network.%s.proto='dhcp'", name))
		elseif uci_network[name].proto == "pppoe" then
			table.insert(arr["network"], string.format("uci set network.%s.proto='pppoe'", name))
			table.insert(arr["network"], string.format("uci set network.%s.username='%s'", name, uci_network[name].pppoe_account))
			table.insert(arr["network"], string.format("uci set network.%s.password='%s'", name, uci_network[name].pppoe_password))
		else
			table.insert(arr["network"], string.format("uci set network.%s.proto='none'", name))
		end

		if uci_network[name].proto == "static" and uci_network[name].dhcpd and uci_network[name].dhcpd["enabled"] == 1 then
			local ipaddr, netmask = ipops.get_ip_and_mask(uci_network[name].ipaddr)
			local startip = ipops.ipstr2int(uci_network[name].dhcpd["start"])
			local endip = ipops.ipstr2int(uci_network[name].dhcpd["end"])
			local s, e = ipops.bxor(startip, ipops.band(ipaddr, netmask)), ipops.bxor(endip, ipops.band(ipaddr, netmask))

			table.insert(arr["dhcp"], string.format("uci set dhcp.%s=dhcp", name))
			table.insert(arr["dhcp"], string.format("uci set dhcp.%s.interface='%s'", name, name))
			table.insert(arr["dhcp"], string.format("uci set dhcp.%s.start='%u'", name, s))
			table.insert(arr["dhcp"], string.format("uci set dhcp.%s.limit='%u'", name, 1 + e - s))
			table.insert(arr["dhcp"], string.format("uci set dhcp.%s.leasetime='%s'", name, uci_network[name].dhcpd["leasetime"]))
			table.insert(arr["dhcp"], string.format("uci set dhcp.%s.force='1'", name))
			table.insert(arr["dhcp"], string.format("uci set dhcp.%s.subnet='%s'", name, uci_network[name].ipaddr))
			table.insert(arr["dhcp"], string.format("uci set dhcp.%s.dynamicdhcp='%u'", name, uci_network[name].dhcpd["dynamicdhcp"] or 1))
			if uci_network[name].dhcpd["dns"] and uci_network[name].dhcpd["dns"] ~= "" then
				table.insert(arr["dhcp"], string.format("uci add_list dhcp.%s.dhcp_option='6,%s'", name, uci_network[name].dhcpd["dns"]))
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

	table.insert(arr["network"], string.format("while uci delete network.@switch[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr["network"], string.format("while uci delete network.@switch_vlan[0] >/dev/null 2>&1; do :; done"))
	for device, switch in pairs(switchs) do
		table.insert(arr["network"], string.format("obj=`uci add network switch`"))
		table.insert(arr["network"], string.format("test -n \"$obj\" && {"))
		table.insert(arr["network"], string.format("	uci set network.$obj.name='%s'", device))
		table.insert(arr["network"], string.format("	uci set network.$obj.reset='1'"))
		table.insert(arr["network"], string.format("	uci set network.$obj.enable_vlan='1'"))
		table.insert(arr["network"], string.format("}"))
		for vid, port in pairs(switch) do
			local ports = table.concat(port.outer_ports, " ")
			ports = ports .. " " .. port.inner_port .. "t"
			table.insert(arr["network"], string.format("obj=`uci add network switch_vlan`"))
			table.insert(arr["network"], string.format("test -n \"$obj\" && {"))
			table.insert(arr["network"], string.format("	uci set network.$obj.device='%s'", device))
			table.insert(arr["network"], string.format("	uci set network.$obj.vlan='%u'", vid))
			table.insert(arr["network"], string.format("	uci set network.$obj.vid='%u'", vid))
			table.insert(arr["network"], string.format("	uci set network.$obj.ports='%s'", ports))
			table.insert(arr["network"], string.format("}"))
		end
	end

	table.insert(arr["nos-zone"], string.format("while uci delete nos-zone.@zone[0] >/dev/null 2>&1; do :; done"))
	for name, zone in pairs(uci_zone) do
		table.insert(arr["nos-zone"], string.format("obj=`uci add nos-zone zone`"))
		table.insert(arr["nos-zone"], string.format("test -n \"$obj\" && {"))
		table.insert(arr["nos-zone"], string.format("	uci set nos-zone.$obj.name='%s'", name))
		table.insert(arr["nos-zone"], string.format("	uci set nos-zone.$obj.id='%s'", zone.id))
		for _, ifname in ipairs(zone.ifname) do
			table.insert(arr["nos-zone"], string.format("	uci add_list nos-zone.$obj.ifname='%s'", ifname))
		end
		table.insert(arr["nos-zone"], string.format("}"))
	end

	table.insert(arr["firewall"], string.format("while uci delete firewall.@zone[0] >/dev/null 2>&1; do :; done"))
	for name, zone in pairs(uci_zone) do
		table.insert(arr["firewall"], string.format("obj=`uci add firewall zone`"))
		table.insert(arr["firewall"], string.format("test -n \"$obj\" && {"))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.name='%s'", name))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.id='%s'", zone.id))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.input='ACCEPT'"))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.output='ACCEPT'"))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.forward='%s'", name:find("^lan") and "ACCEPT" or "REJECT"))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.mtu_fix='1'"))
		for _, network in ipairs(zone.network) do
			table.insert(arr["firewall"], string.format("	uci add_list firewall.$obj.network='%s'", network))
		end
		if name:find("^wan") then
			table.insert(arr["firewall"], string.format("	uci set firewall.$obj.masq='1'"))
		end
		table.insert(arr["firewall"], string.format("}"))
	end

	return arr
end

local function network_reload()
	local board_m = board.load()
	local network_m = network.load()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}
	local orders = {}

	arr["network"] = {}
	arr["dhcp"] = {}
	arr["nos-zone"] = {}
	arr["firewall"] = {}

	arr_cmd["network"] = {
		string.format("uci commit network"),
		string.format("/etc/init.d/network reload")
	}
	arr_cmd["dhcp"] = {
		string.format("uci commit dhcp"),
		string.format("/etc/init.d/dnsmasq reload")
	}
	arr_cmd["nos-zone"] = {
		string.format("uci commit nos-zone"),
		string.format("/etc/init.d/nos-zone restart")
	}
	arr_cmd["firewall"] = {
		string.format("uci commit firewall"),
		string.format("/etc/init.d/firewall reload")
	}

	orders = {"network", "dhcp", "nos-zone", "firewall"}

	local network_arr = generate_network_cmds(board_m, network_m)

	for _, name in ipairs(orders) do
		for _, line in ipairs(network_arr[name]) do
			table.insert(arr[name], line)
		end

		cmd = table.concat(arr[name], "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = common.read(string.format("uci get %s.@version[0].network_md5 2>/dev/null | head -c32", name), io.popen)
		--print(new_md5, old_md5)
		if new_md5 ~= old_md5 then
			table.insert(arr[name], string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(arr[name], string.format("uci set %s.@version[0].network_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(arr[name], line)
			end
			cmd = table.concat(arr[name], "\n")
			print(cmd)
			os.execute(cmd)

			local call = on_event_cb
			if name == "network" and call then
				call({cmd = "network_change"})
			end
		end
	end
end

local function init(p)
	network_reload()
end

local function set_event_cb(cb)
	on_event_cb = cb
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

return {init = init, dispatch_tcp = dispatch_tcp, set_event_cb = set_event_cb}
