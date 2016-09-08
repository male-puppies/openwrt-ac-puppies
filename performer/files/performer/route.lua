local fp = require("fp")
local ski = require("ski")
local log = require("log")
local md5 = require("md5")
local pflib = require("pflib")
local ipops = require("ipops")
local common = require("common")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")
local network = require("cfgmgr.network")

local tcp_map = {}
local mqtt, simple, route_reload
local read, save = common.read, common.save

local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)

	route_reload()
end

local function generate_route_cmds()
	local rs, e = simple:mysql_select("select * from route")
	local _ = rs or log.fatal("%s", e)

	local _, ifname_map = network.load_network_map()
	local network_arr, route_add_arr, route_del_arr = {}, {}, {}

	table.insert(network_arr, string.format("while uci delete network.@route[0] >/dev/null 2>&1; do :; done"))
	for _, rule in ipairs(rs) do
		table.insert(network_arr, string.format("obj=`uci add network route`"))
		table.insert(network_arr, string.format("test -n \"$obj\" && {"))
		table.insert(network_arr, string.format("	uci set network.$obj.target='%s'", rule.target))
		table.insert(network_arr, string.format("	uci set network.$obj.netmask='%s'", rule.netmask))
		table.insert(network_arr, string.format("	uci set network.$obj.gateway='%s'", rule.gateway))
		table.insert(network_arr, string.format("	uci set network.$obj.metric='%u'", rule.metric))
		local _ = rule.mtu ~= 0 and table.insert(network_arr, string.format("	uci set network.$obj.mtu='%u'", rule.mtu))
		table.insert(network_arr, string.format("	uci set network.$obj.interface='%s'", rule.iface))
		table.insert(network_arr, string.format("}"))

		if ifname_map[rule.iface] then
			local cmd = string.format("%s/%u via %s dev %s metric %u %s", rule.target, ipops.maskstr2cidr(rule.netmask),
				rule.gateway, ifname_map[rule.iface], rule.metric, rule.mtu ~= 0 and "mtu " .. rule.mtu or "")
			table.insert(route_add_arr, "ip route add " .. cmd)
			table.insert(route_del_arr, "ip route del " .. cmd)
		end
	end

	return {network = network_arr, route_add = route_add_arr, route_del = route_del_arr}
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

function route_reload()
	local arr_cmd = {network = {"uci commit network"}}
	local route_arr = generate_route_cmds()

	for name in pairs({network = 1}) do
		local cmd_arr = fp.reduce(route_arr[name], function(t, s) return rawset(t, #t + 1, s) end, {})

		local cmd = table.concat(cmd_arr, "\n")
		local new_md5 = md5.sumhexa(cmd)
		local old_md5 = common.read(string.format("uci get %s.@version[0].route_md5 2>/dev/null | head -c32", name), io.popen)

		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].route_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end

			if name == "network" then
				exec_route_add(route_arr["route_add"])
				save_route_del(route_arr["route_del"], new_md5)
			end

			local cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end

tcp_map["dbsync_route"] = function(p)
	route_reload()
end

return {init = init, dispatch_tcp = pflib.gen_dispatch_tcp(tcp_map)}