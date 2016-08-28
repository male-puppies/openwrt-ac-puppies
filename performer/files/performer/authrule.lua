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

local function generate_authrule_cmds()
	local arr = {}
	arr["nos-auth"] = {}

	local kv, e = simple:mysql_select("select k,v from kv where k in ('auth_redirect_ip', 'auth_no_flow_timeout', 'auth_bypass_dst')")
	local rs, e = simple:mysql_select("select * from authrule where enable=1 order by priority")

	local defaults = {}
	for _, r in ipairs(kv) do
		defaults[r.k] = r.v
	end

	table.insert(arr["nos-auth"], string.format("while uci delete nos-auth.@defaults[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr["nos-auth"], string.format("obj=`uci add nos-auth defaults`"))
	table.insert(arr["nos-auth"], string.format("test -n \"$obj\" && {"))
	table.insert(arr["nos-auth"], string.format("	uci set nos-auth.$obj.redirect_ip='%s'", defaults.auth_redirect_ip))
	table.insert(arr["nos-auth"], string.format("	uci set nos-auth.$obj.no_flow_timeout='%u'", defaults.auth_no_flow_timeout))
	for _, host in ipairs(js.decode(defaults.auth_bypass_dst) or {}) do
		if ipops.ipstr2int(host) == 0 then
			table.insert(arr["nos-auth"], string.format("	uci add_list nos-auth.$obj.bypass_http_host='%s'", host))
		else
			table.insert(arr["nos-auth"], string.format("	uci add_list nos-auth.$obj.bypass_dst_ip='%s'", host))
		end
	end
	table.insert(arr["nos-auth"], string.format("}"))

	table.insert(arr["nos-auth"], string.format("while uci delete nos-auth.@rule[0] >/dev/null 2>&1; do :; done"))
	for _, rule in ipairs(rs) do
		table.insert(arr["nos-auth"], string.format("obj=`uci add nos-auth rule`"))
		table.insert(arr["nos-auth"], string.format("test -n \"$obj\" && {"))
		table.insert(arr["nos-auth"], string.format("	uci set nos-auth.$obj.id='%u'", rule.rid))
		table.insert(arr["nos-auth"], string.format("	uci set nos-auth.$obj.type='%s'", rule.authtype))
		table.insert(arr["nos-auth"], string.format("	uci set nos-auth.$obj.szone='%u'", rule.zid))
		table.insert(arr["nos-auth"], string.format("	uci set nos-auth.$obj.sipgrp='%u'", rule.ipgid))
		for _, ip in ipairs(js.decode(rule.white_ip) or {}) do
			table.insert(arr["nos-auth"], string.format("	uci add_list nos-auth.$obj.bypass_src_ip='%s'", ip))
		end
		for _, mac in ipairs(js.decode(rule.white_mac) or {}) do
			table.insert(arr["nos-auth"], string.format("	uci add_list nos-auth.$obj.bypass_src_mac='%s'", mac))
		end
		table.insert(arr["nos-auth"], string.format("}"))
	end

	--print(table.concat(arr["nos-auth"], "\n"))
	return arr
end

local function authrule_reload()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}

	arr["nos-auth"] = {}
	arr_cmd["nos-auth"] = {
		string.format("uci commit nos-auth"),
		string.format("/etc/init.d/nos-auth restart")
	}

	local authrule_arr = generate_authrule_cmds()

	for name, cmd_arr in pairs(arr) do
		for _, line in ipairs(authrule_arr[name]) do
			table.insert(cmd_arr, line)
		end

		cmd = table.concat(cmd_arr, "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = common.read(string.format("uci get %s.@version[0].authrule_md5 2>/dev/null | head -c32", name), io.popen)
		--print(new_md5, old_md5)
		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].authrule_md5='%s'", name, new_md5))
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
	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)

	authrule_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

tcp_map["dbsync_authrule"] = function(p)
	authrule_reload()
end

-- p: {"cmd":"dbsync_kv","set":["auth_offline_time"]}
tcp_map["dbsync_kv"] = function(p)
	local map = {
		["auth_offline_time"] = 1,
		["auth_redirect_ip"] = 1,
		["auth_bypass_dst"] = 1,
	}

	for _, key in ipairs(p.set) do
		if map[key] == 1 then
			authrule_reload()
			return
		end
	end
end

return {init = init, dispatch_tcp = dispatch_tcp}
