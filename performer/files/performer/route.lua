local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")
local md5 = require("md5")
local common = require("common")
local ipops = require("ipops")

local tcp_map = {}
local mqtt, simple

local read = common.read
local save = common.save

local function load_iface_map()
	local board_s = read("/etc/config/board.json")	assert(board_s)
	local board_m = js.decode(board_s)	assert(board_m)
	local ports = board_m.ports
	local port_map = {}

	for _, dev in ipairs(ports) do
		if dev.type == "switch" then
			for idx, port in ipairs(dev.outer_ports) do
				table.insert(port_map, {ifname = dev.ifname, mac = port.mac, type = dev.type, device = dev.device, num = port.num, inner_port = dev.inner_port})
			end
		elseif dev.type == "ether" then
			table.insert(port_map, {ifname = dev.ifname, mac = dev.outer_ports[1].mac, type = dev.type, device = dev.device})
		end
	end

	local path = "/etc/config/network.json"
	local network_s = read("/etc/config/network.json")	assert(network_s)
	local network_m = js.decode(network_s)	assert(network_m)
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
			if port_map[i].type == 'switch' then
				vlan = vlan or tostring(i)
				ifnames[port_map[i].ifname .. "." .. vlan] = tonumber(vlan)
			else
				ifnames[port_map[i].ifname] = i
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

local function generate_route_cmds()
	local _, ifname_map = load_iface_map()
	local arr = {}
	arr["network"] = {}
	arr["route_add"] = {}
	arr["route_del"] = {}

	local rs, e = simple:mysql_select("select * from route")

	table.insert(arr["network"], string.format("while uci delete network.@route[0] >/dev/null 2>&1; do :; done"))
	for _, rule in ipairs(rs) do
		table.insert(arr["network"], string.format("obj=`uci add network route`"))
		table.insert(arr["network"], string.format("test -n \"$obj\" && {"))
		table.insert(arr["network"], string.format("	uci set network.$obj.target='%s'", rule.target))
		table.insert(arr["network"], string.format("	uci set network.$obj.netmask='%s'", rule.netmask))
		table.insert(arr["network"], string.format("	uci set network.$obj.gateway='%s'", rule.gateway))
		table.insert(arr["network"], string.format("	uci set network.$obj.metric='%u'", rule.metric))
		if rule.mtu and rule.mtu ~= 0 then
			table.insert(arr["network"], string.format("	uci set network.$obj.mtu='%u'", rule.mtu))
		end
		table.insert(arr["network"], string.format("	uci set network.$obj.interface='%s'", rule.iface))
		table.insert(arr["network"], string.format("}"))

		if ifname_map[rule.iface] then
			local cmd = string.format("%s/%u via %s dev %s metric %u %s",
				rule.target,
				ipops.maskstr2cidr(rule.netmask),
				rule.gateway,
				ifname_map[rule.iface],
				rule.metric,
				rule.mtu ~= 0 and "mtu " .. rule.mtu or "")
			table.insert(arr["route_add"], "ip route add " .. cmd)
			table.insert(arr["route_del"], "ip route del " .. cmd)
		end
	end

	return arr
end

local function exec_route_add(route_add)
	local cmd_arr = {}

	table.insert(cmd_arr, "test -f /tmp/performer.route.del.sh && sh /tmp/performer.route.del.sh")
	for _, line in ipairs(route_add) do
		table.insert(cmd_arr, line)
	end

	local cmd = table.concat(cmd_arr, "\n")
	os.execute(cmd)
end

local function save_route_del(route_del, new_md5)
	local cmd_arr = {}

	table.insert(cmd_arr, string.format("[ x`uci get network.@version[0].route_md5 2>/dev/null | head -c32` = x%s ] || exit 0", new_md5))
	for _, line in ipairs(route_del) do
		table.insert(cmd_arr, line)
	end

	local cmd = table.concat(cmd_arr, "\n")
	save("/tmp/performer.route.del.sh", cmd)
end

local function route_reload()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}

	arr["network"] = {}
	arr_cmd["network"] = {
		string.format("uci commit network"),
		--string.format("/etc/init.d/network reload")
	}

	local route_arr = generate_route_cmds()

	for name, cmd_arr in pairs(arr) do
		for _, line in ipairs(route_arr[name]) do
			table.insert(cmd_arr, line)
		end

		cmd = table.concat(cmd_arr, "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = common.read(string.format("uci get %s.@version[0].route_md5 2>/dev/null | head -c32", name), io.popen)
		--print(new_md5, old_md5)
		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].route_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end
			cmd = table.concat(cmd_arr, "\n")
			print(cmd)

			if name == "network" then
				exec_route_add(route_arr["route_add"])
				save_route_del(route_arr["route_del"], new_md5)
			end

			os.execute(cmd)
		end
	end
end


local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)

	route_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

tcp_map["dbsync_route"] = function(p)
	route_reload()
end

return {init = init, dispatch_tcp = dispatch_tcp}
