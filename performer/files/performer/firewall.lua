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

-- XXX only support DNAT redirect for now
local function generate_firewall_cmds()
	local arr = {}
	arr["firewall"] = {}

	local rs, e = simple:mysql_select("select * from firewall where type='redirect' and action='DNAT' and enable=1 order by priority")
	local zones, e = simple:mysql_select("select * from zone")

	local zone_map = {}
	for _, zone in pairs(zones) do
		zone_map[zone.zid] = zone.zonename
	end

	table.insert(arr["firewall"], string.format("while uci delete firewall.@redirect[0] >/dev/null 2>&1; do :; done"))
	for _, rule in ipairs(rs) do
		table.insert(arr["firewall"], string.format("obj=`uci add firewall redirect`"))
		table.insert(arr["firewall"], string.format("test -n \"$obj\" && {"))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.name='rule%u'", rule.fwid))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.src='%s'", zone_map[rule.from_szid] or ""))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.dest='%s'", zone_map[rule.to_dzid] or ""))
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.proto='%s'", rule.proto))
		if rule.from_sip and rule.from_sip ~= "" then
			table.insert(arr["firewall"], string.format("	uci set firewall.$obj.src_ip='%s'", rule.from_sip))
		end
		if rule.from_sport and rule.from_sport ~= 0 then
			table.insert(arr["firewall"], string.format("	uci set firewall.$obj.src_port='%u'", rule.from_sport))
		end
		if rule.from_dip and rule.from_dip ~= "" then
			table.insert(arr["firewall"], string.format("	uci set firewall.$obj.src_dip='%s'", rule.from_dip))
		end
		if rule.from_dport and rule.from_dport ~= 0 then
			table.insert(arr["firewall"], string.format("	uci set firewall.$obj.src_dport='%u'", rule.from_dport))
		end
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.target='%s'", rule.action))
		if rule.to_dip and rule.to_dip ~= "" then
			table.insert(arr["firewall"], string.format("	uci set firewall.$obj.dest_ip='%s'", rule.to_dip))
		end
		if rule.to_dport and rule.to_dport ~= 0 then
			table.insert(arr["firewall"], string.format("	uci set firewall.$obj.dest_port='%u'", rule.to_dport))
		end
		table.insert(arr["firewall"], string.format("	uci set firewall.$obj.reflection='%u'", 0))
		table.insert(arr["firewall"], string.format("}"))
	end

	return arr
end

local function firewall_reload()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}

	arr["firewall"] = {}
	arr_cmd["firewall"] = {
		string.format("uci commit firewall"),
		string.format("/etc/init.d/firewall reload")
	}

	local firewall_arr = generate_firewall_cmds()

	for name, cmd_arr in pairs(arr) do
		for _, line in ipairs(firewall_arr[name]) do
			table.insert(cmd_arr, line)
		end

		cmd = table.concat(cmd_arr, "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = common.read(string.format("uci get %s.@version[0].firewall_md5 2>/dev/null | head -c32", name), io.popen)
		--print(new_md5, old_md5)
		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].firewall_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end
			cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end


local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)

	firewall_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

tcp_map["dbsync_firewall"] = function(p)
	firewall_reload()
end

return {init = init, dispatch_tcp = dispatch_tcp}
