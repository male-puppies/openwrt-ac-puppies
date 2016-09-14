local fp = require("fp")
local ski = require("ski")
local log = require("log")
local md5 = require("md5")
local pflib = require("pflib")
local ipops = require("ipops")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local common = require("common")
local simplesql = require("simplesql")

local tcp_map = {}
local mqtt, simple, authrule_reload

local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)

	authrule_reload()
end

local function generate_authrule_cmds()
	local kv, e = simple:mysql_select("select k,v from kv where k in ('auth_redirect_ip', 'auth_no_flow_timeout', 'auth_offline_time', 'auth_bypass_dst')")
	local _ = kv or log.fatal("%s", e)

	local rs, e = simple:mysql_select("select * from authrule where enable=1 order by priority")
	local _ = kv or log.fatal("%s", e)

	local defaults = fp.reduce(kv, function(t, r) return rawset(t, r.k, r.v) end, {})
	defaults.auth_no_flow_timeout = js.decode(defaults.auth_no_flow_timeout)
	defaults.auth_offline_time = js.decode(defaults.auth_offline_time)
	local auth_no_flow_timeout = defaults.auth_no_flow_timeout.enable == 1 and defaults.auth_no_flow_timeout.time or defaults.auth_offline_time.time

	local arr = {}
	table.insert(arr, string.format("while uci delete nos-auth.@defaults[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr, string.format("obj=`uci add nos-auth defaults`"))
	table.insert(arr, string.format("test -n \"$obj\" && {"))
	table.insert(arr, string.format("	uci set nos-auth.$obj.redirect_ip='%s'", defaults.auth_redirect_ip))
	table.insert(arr, string.format("	uci set nos-auth.$obj.no_flow_timeout='%u'", auth_no_flow_timeout))

	for _, host in ipairs(js.decode(defaults.auth_bypass_dst) or {}) do
		local fmt = ipops.ipstr2int(host) == 0 and "	uci add_list nos-auth.$obj.bypass_http_host='%s'" or "	uci add_list nos-auth.$obj.bypass_dst_ip='%s'"
		table.insert(arr, string.format(fmt, host))
	end

	table.insert(arr, string.format("}"))

	table.insert(arr, string.format("while uci delete nos-auth.@rule[0] >/dev/null 2>&1; do :; done"))
	for _, rule in ipairs(rs) do
		table.insert(arr, string.format("obj=`uci add nos-auth rule`"))
		table.insert(arr, string.format("test -n \"$obj\" && {"))
		table.insert(arr, string.format("	uci set nos-auth.$obj.id='%u'", rule.rid))
		table.insert(arr, string.format("	uci set nos-auth.$obj.type='%s'", rule.authtype))
		table.insert(arr, string.format("	uci set nos-auth.$obj.szone='%u'", rule.zid))
		table.insert(arr, string.format("	uci set nos-auth.$obj.sipgrp='%u'", rule.ipgid))

		for _, ip in ipairs(js.decode(rule.white_ip) or {}) do
			table.insert(arr, string.format("	uci add_list nos-auth.$obj.bypass_src_ip='%s'", ip))
		end

		for _, mac in ipairs(js.decode(rule.white_mac) or {}) do
			table.insert(arr, string.format("	uci add_list nos-auth.$obj.bypass_src_mac='%s'", mac))
		end

		table.insert(arr, string.format("}"))
	end

	return {["nos-auth"] = arr}
end

function authrule_reload()
	local authrule_arr = generate_authrule_cmds()
	local arr_cmd = {["nos-auth"] = {"uci commit nos-auth", "/etc/init.d/nos-auth restart"}}

	for name in pairs({["nos-auth"] = 1}) do
		local cmd_arr = fp.reduce(authrule_arr[name], function(t, s) return rawset(t, #t + 1, s) end, {})

		local cmd = table.concat(cmd_arr, "\n")
		local new_md5 = md5.sumhexa(cmd)
		local old_md5 = common.read(string.format("uci get %s.@version[0].authrule_md5 2>/dev/null | head -c32", name), io.popen)

		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].authrule_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end

			local cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end

tcp_map["dbsync_authrule"] = function(p)
	authrule_reload()
end

-- p: {"cmd":"dbsync_kv","set":["auth_offline_time"]}
tcp_map["dbsync_kv"] = function(p)
	local map = {auth_no_flow_timeout = 1, auth_offline_time = 1, auth_redirect_ip = 1, auth_bypass_dst = 1}
	for _, key in ipairs(p.set or {}) do
		if map[key] == 1 then
			authrule_reload()
			return
		end
	end
end

return {init = init, dispatch_tcp = pflib.gen_dispatch_tcp(tcp_map)}
