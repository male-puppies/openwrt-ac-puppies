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
	local firewall = {
		zones = {
			lan = {id = 0, ifnames = {}, networks = {}, input = "ACCEPT", ouput = "ACCEPT", forward = "ACCEPT", mtu_fix = 1, masq = 0},
			wan = {id = 1, ifnames = {}, networks = {}, input = "ACCEPT", ouput = "ACCEPT", forward = "REJECT", mtu_fix = 1, masq = 1},
		},
		defaults = {syn_flood = 1, input = "ACCEPT", output = "ACCEPT", forward = "REJECT"},
		forwardings = {
			{src = 'lan', dest = 'wan'},
		},
		-- rules = {}, TODO setup rule
	}

	local switchs = {}
	local network_arr, dhcp_arr, nos_zone_arr, firewall_arr = {}, {}, {}, {}

	table.insert(dhcp_arr, string.format("while uci delete dhcp.@dhcp[0] >/dev/null 2>&1; do :; done"))
	table.insert(network_arr, string.format("while uci delete network.@interface[1] >/dev/null 2>&1; do :; done"))
	table.insert(network_arr, string.format("while uci delete network.@device[0] >/dev/null 2>&1; do :; done"))

	-- setup network
	for name, option in pairs(network.network) do
		local ifnames, vlan = {}, nil

		option.zone = name:find("^lan") and "lan" or "wan"
		if name:find("^lan") or #option.ports > 1 then
			option.type = 'bridge'
		end

		-- make the switchs
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

		-- setup devices
		option.ifname = ""
		for ifname, i in pairs(ifnames) do
			option.ifname = option.ifname == "" and ifname or string.format("%s %s", option.ifname, ifname)
			table.insert(network_arr, string.format("obj=`uci add network device`"))
			table.insert(network_arr, string.format("test -n \"$obj\" && {"))
			table.insert(network_arr, string.format("	uci set network.$obj.name='%s'", ifname))
			table.insert(network_arr, string.format("	uci set network.$obj.macaddr='%s'", option.mac and option.mac ~= "" and option.mac or board.ports[i].mac))
			local _ = option.mtu and option.mtu ~= "" and table.insert(network_arr, string.format("	uci set network.$obj.mtu='%s'", option.mtu))
			table.insert(network_arr, string.format("}"))
		end

		table.insert(network_arr, string.format("uci set network.%s=interface", name))
		table.insert(network_arr, string.format("uci set network.%s.ifname='%s'", name, option.ifname))

		local _ = option.mac and option.mac ~= "" and table.insert(network_arr, string.format("uci set network.%s.macaddr='%s'", name, option.mac))
		local _ = option.type and option.type ~= "" and table.insert(network_arr, string.format("uci set network.%s.type='%s'", name, option.type))
		local _ = option.mtu and option.mtu ~= "" and table.insert(network_arr, string.format("uci set network.%s.mtu='%s'", name, option.mtu))
		local _ = option.metric and option.metric ~= "" and table.insert(network_arr, string.format("uci set network.%s.metric='%s'", name, option.metric))

		if option.proto == "static" then
			table.insert(network_arr, string.format("uci set network.%s.proto='static'", name))
			table.insert(network_arr, string.format("uci set network.%s.ipaddr='%s'", name, option.ipaddr))
			local _ = option.gateway and option.gateway ~= "" and table.insert(network_arr, string.format("uci set network.%s.gateway='%s'", name, option.gateway))
			if option.dns and option.dns ~= "" then
				local dns = option.dns .. ","
				for ip in dns:gmatch("(.-),") do
					table.insert(network_arr, string.format("uci add_list network.%s.dns='%s'", name, ip))
				end
			end
		elseif option.proto == "dhcp" then
			table.insert(network_arr, string.format("uci set network.%s.proto='dhcp'", name))
		elseif option.proto == "pppoe" then
			table.insert(network_arr, string.format("uci set network.%s.proto='pppoe'", name))
			table.insert(network_arr, string.format("uci set network.%s.username='%s'", name, option.pppoe_account))
			table.insert(network_arr, string.format("uci set network.%s.password='%s'", name, option.pppoe_password))
		else
			table.insert(network_arr, string.format("uci set network.%s.proto='none'", name))
		end

		-- setup dhcpd
		if option.proto == "static" and option.dhcpd and option.dhcpd.enabled == 1 then
			local ipaddr, netmask = ipops.get_ip_and_mask(option.ipaddr)
			local startip = ipops.ipstr2int(option.dhcpd.start)
			local endip = ipops.ipstr2int(option.dhcpd.end)
			local s, e = ipops.bxor(startip, ipops.band(ipaddr, netmask)), ipops.bxor(endip, ipops.band(ipaddr, netmask))

			table.insert(dhcp_arr, string.format("uci set dhcp.%s=dhcp", name))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.interface='%s'", name, name))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.start='%u'", name, s))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.limit='%u'", name, 1 + e - s))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.leasetime='%s'", name, option.dhcpd.leasetime))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.force='1'", name))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.subnet='%s'", name, option.ipaddr))
			table.insert(dhcp_arr, string.format("uci set dhcp.%s.dynamicdhcp='%u'", name, option.dhcpd.dynamicdhcp or 1))

			local _ = option.dhcpd.dns and option.dhcpd.dns ~= "" and table.insert(dhcp_arr, string.format("uci add_list dhcp.%s.dhcp_option='6,%s'", name, option.dhcpd.dns))
		end

		table.insert(firewall.zones[option.zone].networks, name)
		if option.proto == "static" or option.proto == "dhcp" then
			table.insert(firewall.zones[option.zone].ifnames, option.type == 'bridge' and "br-" .. name or option.ifname)
		elseif option.proto == "pppoe" then
			table.insert(firewall.zones[option.zone].ifnames, "pppoe-" .. name)
		end
	end

	-- setup switchs and vlans
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

	-- setup zone and firewall
	local defaults = firewall.defaults
	table.insert(firewall_arr, string.format("while uci delete firewall.@defaults[0] >/dev/null 2>&1; do :; done"))
	table.insert(firewall_arr, string.format("obj=`uci add firewall defaults`"))
	table.insert(firewall_arr, string.format("test -n \"$obj\" && {"))
	table.insert(firewall_arr, string.format("	uci set firewall.$obj.syn_flood='%u'", defaults.syn_flood))
	table.insert(firewall_arr, string.format("	uci set firewall.$obj.input='%s'", defaults.input))
	table.insert(firewall_arr, string.format("	uci set firewall.$obj.output='%s'", defaults.output))
	table.insert(firewall_arr, string.format("	uci set firewall.$obj.forward='%s'", defaults.forward))
	table.insert(firewall_arr, string.format("}"))

	table.insert(nos_zone_arr, string.format("while uci delete nos-zone.@zone[0] >/dev/null 2>&1; do :; done"))
	table.insert(firewall_arr, string.format("while uci delete firewall.@zone[0] >/dev/null 2>&1; do :; done"))
	for name, zone in pairs(firewall.zones) do
		table.insert(nos_zone_arr, string.format("obj=`uci add nos-zone zone`"))
		table.insert(nos_zone_arr, string.format("test -n \"$obj\" && {"))
		table.insert(nos_zone_arr, string.format("	uci set nos-zone.$obj.name='%s'", name))
		table.insert(nos_zone_arr, string.format("	uci set nos-zone.$obj.id='%s'", zone.id))
		for _, ifname in ipairs(zone.ifnames) do
			table.insert(nos_zone_arr, string.format("	uci add_list nos-zone.$obj.ifname='%s'", ifname))
		end
		table.insert(nos_zone_arr, string.format("}"))

		table.insert(firewall_arr, string.format("obj=`uci add firewall zone`"))
		table.insert(firewall_arr, string.format("test -n \"$obj\" && {"))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.name='%s'", name))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.input='%s'", zone.input))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.output='%s'", zone.output))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.forward='%s'", zone.forward))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.mtu_fix='%u'", zone.mtu_fix))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.masq='%s'", zone.masq))
		for _, network in ipairs(zone.networks) do
			table.insert(firewall_arr, string.format("	uci add_list firewall.$obj.network='%s'", network))
		end
		table.insert(firewall_arr, string.format("}"))
	end

	table.insert(firewall_arr, string.format("while uci delete firewall.@forwarding[0] >/dev/null 2>&1; do :; done"))
	for _, forwarding in ipairs(firewall.forwardings) do
		table.insert(firewall_arr, string.format("obj=`uci add firewall forwarding`"))
		table.insert(firewall_arr, string.format("test -n \"$obj\" && {"))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.src='%s'", forwarding.src))
		table.insert(firewall_arr, string.format("	uci set firewall.$obj.dest='%s'", forwarding.dest))
		table.insert(firewall_arr, string.format("}"))
	end

	-- TODO setup rule

	return {["network"] = network_arr, ["dhcp"] = dhcp_arr, ["firewall"] = firewall_arr, ["nos-zone"] = nos_zone_arr}
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
