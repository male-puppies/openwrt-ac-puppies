-- cmq

local fp = require("fp")
local ski = require("ski")
local log = require("log")
local md5 = require("md5")
local pflib = require("pflib")
local ipops = require("ipops")
local js = require("cjson.safe")
local common = require("common")
local rpccli = require("rpccli")
local board = require("cfgmgr.board")
local network = require("cfgmgr.network")

local tcp_map = {}
local on_event_cb, network_reload

local read = common.read

local function init(p)
	network_reload()
end

local function generate_network_cmds(board, network)
	local uci_zone = {
		lan = {id = 0, ifname = {}, network = {}},
		wan = {id = 1, ifname = {}, network = {}}
	}

	local switchs = {}
	local network_arr, dhcp_arr, nos_zone_arr, firewall_arr = {}, {}, {}, {}

	table.insert(dhcp_arr, string.format("while uci delete dhcp.@dhcp[0] >/dev/null 2>&1; do :; done"))
	table.insert(network_arr, string.format("while uci delete network.@interface[1] >/dev/null 2>&1; do :; done"))
	table.insert(network_arr, string.format("while uci delete network.@device[0] >/dev/null 2>&1; do :; done"))

	for name, option in pairs(network.network) do
		if name:find("^lan") or #option.ports > 1 then
			option.type = 'bridge'
		end

		option.ifname = ""
		local ifnames, vlan = {}

		for _, i in ipairs(option.ports) do
			local bp = board.ports[i]
			if bp.type == 'switch' then
				vlan = vlan or tostring(i)
				local bp_device = bp.device
				switchs[bp_device] = switchs[bp_device] or {}
				switchs[bp_device][vlan] = switchs[bp_device][vlan] or {}
				switchs[bp_device][vlan]["outer_ports"] = switchs[bp_device][vlan]["outer_ports"] or {}

				table.insert(switchs[bp_device][vlan]["outer_ports"], bp.num)

				switchs[bp_device][vlan]["inner_port"] = bp.inner_port
				ifnames[bp.ifname .. "." .. vlan] = tonumber(vlan)
			else
				ifnames[bp.ifname] = i
			end
		end

		for ifname, i in pairs(ifnames) do
			local opt_ifname, opt_mac, opt_mtu = option.ifname, option.mac, option.mtu
			option.ifname = opt_ifname == "" and ifname or string.format("%s %s", opt_ifname, ifname)

			table.insert(network_arr, string.format("obj=`uci add network device`"))
			table.insert(network_arr, string.format("test -n \"$obj\" && {"))
			table.insert(network_arr, string.format("	uci set network.$obj.name='%s'", ifname))

			if opt_mac and opt_mac ~= "" then
				table.insert(network_arr, string.format("	uci set network.$obj.macaddr='%s'", option.mac))
			else
				table.insert(network_arr, string.format("	uci set network.$obj.macaddr='%s'", board.ports[i].mac))
			end

			local _ = opt_mtu and opt_mtu ~= "" and table.insert(network_arr, string.format("	uci set network.$obj.mtu='%s'", option.mtu))
			table.insert(network_arr, string.format("}"))
		end

		table.insert(network_arr, string.format("uci set network.%s=interface", name))
		table.insert(network_arr, string.format("uci set network.%s.ifname='%s'", name, option.ifname))

		local opt_gateway, opt_dns, opt_ipaddr =  option.gateway, option.dns, option.ipaddr
		local opt_mac, opt_type, opt_mtu, opt_metric, opt_proto = option.mac, option.type, option.mtu, option.metric, option.proto

		local _ = opt_mac and opt_mac ~= "" and table.insert(network_arr, string.format("uci set network.%s.macaddr='%s'", name, opt_mac))
		local _ = opt_type and opt_type ~= "" and table.insert(network_arr, string.format("uci set network.%s.type='%s'", name, opt_type))
		local _ = opt_mtu and opt_mtu ~= "" and table.insert(network_arr, string.format("uci set network.%s.mtu='%s'", name, opt_mtu))
		local _ = opt_metric and opt_metric ~= "" and table.insert(network_arr, string.format("uci set network.%s.metric='%s'", name, opt_metric))

		if opt_proto == "static" then
			table.insert(network_arr, string.format("uci set network.%s.proto='static'", name))
			table.insert(network_arr, string.format("uci set network.%s.ipaddr='%s'", name, opt_ipaddr))
			local _ = opt_gateway and opt_gateway ~= "" and table.insert(network_arr, string.format("uci set network.%s.gateway='%s'", name, opt_gateway))

			if opt_dns and opt_dns ~= "" then
				local dns = opt_dns .. ","
				for ip in dns:gmatch("(.-),") do
					table.insert(network_arr, string.format("uci add_list network.%s.dns='%s'", name, ip))
				end
			end
		elseif opt_proto == "dhcp" then
			table.insert(network_arr, string.format("uci set network.%s.proto='dhcp'", name))
		elseif opt_proto == "pppoe" then
			table.insert(network_arr, string.format("uci set network.%s.proto='pppoe'", name))
			table.insert(network_arr, string.format("uci set network.%s.username='%s'", name, option.pppoe_account))
			table.insert(network_arr, string.format("uci set network.%s.password='%s'", name, option.pppoe_password))
		else
			table.insert(network_arr, string.format("uci set network.%s.proto='none'", name))
		end

		local opt_dhcpd = option.dhcpd
		if opt_proto == "static" and opt_dhcpd and opt_dhcpd["enabled"] == 1 then
			local ipaddr, netmask = ipops.get_ip_and_mask(opt_ipaddr)
			local startip = ipops.ipstr2int(opt_dhcpd["start"])
			local endip = ipops.ipstr2int(opt_dhcpd["end"])
			local s, e = ipops.bxor(startip, ipops.band(ipaddr, netmask)), ipops.bxor(endip, ipops.band(ipaddr, netmask))

			table.insert(dhcp_arr, string.format("uci set dhcp.%s=dhcp", name))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.interface='%s'", name, name))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.start='%u'", name, s))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.limit='%u'", name, 1 + e - s))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.leasetime='%s'", name, opt_dhcpd["leasetime"]))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.force='1'", name))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.subnet='%s'", name, option.ipaddr))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.dynamicdhcp='%u'", name, opt_dhcpd["dynamicdhcp"] or 1))

			local opt_dhcpd_dns = opt_dhcpd["dns"]
			local _ = opt_dhcpd_dns and opt_dhcpd_dns ~= "" and table.insert(dhcp_arr, string.format("uci add_list dhcp.%s.dhcp_option='6,%s'", name, opt_dhcpd_dns))
		end

		table.insert(name:find("^lan") and uci_zone.lan.network or uci_zone.wan.network, name)

		if opt_proto == "static" or opt_proto == "dhcp" then
			if option.type == 'bridge' then
				table.insert(name:find("^lan") and uci_zone.lan.ifname or uci_zone.wan.ifname, "br-" .. name)
			else
				table.insert(name:find("^lan") and uci_zone.lan.ifname or uci_zone.wan.ifname, option.ifname)
			end
		elseif opt_proto == "pppoe" then
			table.insert(name:find("^lan") and uci_zone.lan.ifname or uci_zone.wan.ifname, "pppoe-" .. name)
		end
	end

	table.insert(network_arr, string.format("while uci delete network.@switch[0] >/dev/null 2>&1; do :; done"))
	table.insert(network_arr, string.format("while uci delete network.@switch_vlan[0] >/dev/null 2>&1; do :; done"))

	for device, switch in pairs(switchs) do
		table.insert(network_arr, string.format("obj=`uci add network switch`"))
		table.insert(network_arr, string.format("test -n \"$obj\" && {"))
		table.insert(network_arr, string.format("	uci set network.$obj.name='%s'", device))
		table.insert(network_arr, string.format("	uci set network.$obj.reset='1'"))
		table.insert(network_arr, string.format("	uci set network.$obj.enable_vlan='1'"))
		table.insert(network_arr, string.format("}"))

		for vid, port in pairs(switch) do
			local ports = string.format("%s %st", table.concat(port.outer_ports, " "), port.inner_port)
			table.insert(network_arr, string.format("obj=`uci add network switch_vlan`"))
			table.insert(network_arr, string.format("test -n \"$obj\" && {"))
			table.insert(network_arr, string.format("	uci set network.$obj.device='%s'", device))
			table.insert(network_arr, string.format("	uci set network.$obj.vlan='%u'", vid))
			table.insert(network_arr, string.format("	uci set network.$obj.vid='%u'", vid))
			table.insert(network_arr, string.format("	uci set network.$obj.ports='%s'", ports))
			table.insert(network_arr, string.format("}"))
		end
	end

	table.insert(nos_zone_arr, string.format("while uci delete nos-zone.@zone[0] >/dev/null 2>&1; do :; done"))

	for name, zone in pairs(uci_zone) do
		table.insert(nos_zone_arr, string.format("obj=`uci add nos-zone zone`"))
		table.insert(nos_zone_arr, string.format("test -n \"$obj\" && {"))
		table.insert(nos_zone_arr, string.format("	uci set nos-zone.$obj.name='%s'", name))
		table.insert(nos_zone_arr, string.format("	uci set nos-zone.$obj.id='%s'", zone.id))

		for _, ifname in ipairs(zone.ifname) do
			table.insert(nos_zone_arr, string.format("	uci add_list nos-zone.$obj.ifname='%s'", ifname))
		end

		table.insert(nos_zone_arr, string.format("}"))
	end

	table.insert(firewall_arr, string.format("while uci delete firewall.@zone[0] >/dev/null 2>&1; do :; done"))
	for name, zone in pairs(uci_zone) do
		table.insert(firewall_arr, string.format("obj=`uci add firewall zone`"))
		table.insert(firewall_arr, string.format("test -n \"$obj\" && {"))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.name='%s'", name))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.id='%s'", zone.id))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.input='ACCEPT'"))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.output='ACCEPT'"))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.forward='%s'", name:find("^lan") and "ACCEPT" or "REJECT"))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.mtu_fix='1'"))

		for _, network in ipairs(zone.network) do
			table.insert(firewall_arr, string.format("	uci add_list firewall.$obj.network='%s'", network))
		end

		if name:find("^wan") then
			table.insert(firewall_arr, string.format("	uci set firewall.$obj.masq='1'"))
		end

	table.insert(firewall_arr, string.format("}"))
	end

	return {network = network_arr, dhcp = dhcp_arr, firewall = firewall_arr, ["nos-zone"] = nos_zone_arr}
end

function network_reload()
	local board_m = board.load()
	local network_m = network.load()
	local network_arr = generate_network_cmds(board_m, network_m)

	local arr_cmd = {
		["network"] 	= 	{"uci commit network", "/etc/init.d/network reload"},
		["dhcp"] 		= 	{"uci commit dhcp", "/etc/init.d/dnsmasq reload"},
		["nos-zone"] 	= 	{"uci commit nos-zone","/etc/init.d/nos-zone restart"},
		["firewall"] 	= 	{"uci commit firewall","/etc/init.d/firewall reload"},
	}

	local orders = {"network", "dhcp", "nos-zone", "firewall"}
	for _, name in ipairs(orders) do
		local cmd_arr = fp.reduce(network_arr[name], function(t, s) return rawset(t, #t + 1, s) end, {})
		local cmd = table.concat(cmd_arr, "\n")

		local new_md5 = md5.sumhexa(cmd)
		local old_md5 = common.read(string.format("uci get %s.@version[0].network_md5 2>/dev/null | head -c32", name), io.popen)

		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].network_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end

			local cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)

			if name == "network" and on_event_cb then
				on_event_cb({cmd = "network_change"})
			end
		end
	end
end

local function set_event_cb(cb)
	on_event_cb = cb
end

tcp_map["network"] = function(p)
	network_reload()
end

return {init = init, dispatch_tcp = pflib.gen_dispatch_tcp(tcp_map), set_event_cb = set_event_cb}