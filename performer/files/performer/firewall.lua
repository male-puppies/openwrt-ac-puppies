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

local tcp_map = {}
local mqtt, simple, firewall_reload

local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)

	firewall_reload()
end

-- XXX only support DNAT redirect for now
local function generate_firewall_cmds()
	local rs, e = simple:mysql_select("select * from firewall where type='redirect' and action='DNAT' and enable=1 order by priority")
	local _ = rs or log.fatal("%s", e)

	local zones, e = simple:mysql_select("select * from zone")
	local _ = zones or log.fatal("%s", e)

	local zone_map = fp.reduce(zones, function(t, r) return rawset(t, r.zid, r.zonename) end, {})

	local arr = {string.format("while uci delete firewall.@redirect[0] >/dev/null 2>&1; do :; done")}
	for _, rule in ipairs(rs) do
		table.insert(arr, string.format("obj=`uci add firewall redirect`"))
		table.insert(arr, string.format("test -n \"$obj\" && {"))
		table.insert(arr, string.format("	uci set firewall.$obj.name='rule%u'", rule.fwid))
		table.insert(arr, string.format("	uci set firewall.$obj.src='%s'", zone_map[rule.from_szid] or ""))
		table.insert(arr, string.format("	uci set firewall.$obj.dest='%s'", zone_map[rule.to_dzid] or ""))
		table.insert(arr, string.format("	uci set firewall.$obj.proto='%s'", rule.proto))

		local _ = rule.from_sip ~= "" and table.insert(arr, string.format("	uci set firewall.$obj.src_ip='%s'", rule.from_sip))
		local _ = rule.from_sport ~= 0 and table.insert(arr, string.format("	uci set firewall.$obj.src_port='%u'", rule.from_sport))
		local _ = rule.from_dip ~= "" and table.insert(arr, string.format("	uci set firewall.$obj.src_dip='%s'", rule.from_dip))
		local _ = rule.from_dport ~= 0 and table.insert(arr, string.format("	uci set firewall.$obj.src_dport='%u'", rule.from_dport))

		table.insert(arr, string.format("	uci set firewall.$obj.target='%s'", rule.action))

		local _ = rule.to_dip ~= "" and	table.insert(arr, string.format("	uci set firewall.$obj.dest_ip='%s'", rule.to_dip))
		local _ = rule.to_dport ~= 0 and table.insert(arr, string.format("	uci set firewall.$obj.dest_port='%u'", rule.to_dport))

		table.insert(arr, string.format("	uci set firewall.$obj.reflection='%u'", 0))
		table.insert(arr, string.format("}"))
	end

	return {firewall = arr}
end

function firewall_reload()
	local arr_cmd = {firewall = {"uci commit firewall", "/etc/init.d/firewall reload"}}
	local firewall_arr = generate_firewall_cmds()

	for name in pairs({firewall = 1}) do
		local cmd_arr = fp.reduce(firewall_arr[name], function(t, s) return rawset(t, #t + 1, s) end, {})

		local cmd = table.concat(cmd_arr, "\n")
		local new_md5 = md5.sumhexa(cmd)
		local old_md5 = common.read(string.format("uci get %s.@version[0].firewall_md5 2>/dev/null | head -c32", name), io.popen)

		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].firewall_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end

			local cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end

tcp_map["dbsync_firewall"] = function(p)
	firewall_reload()
end

return {init = init, dispatch_tcp = pflib.gen_dispatch_tcp(tcp_map)}