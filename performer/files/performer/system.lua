-- cmq

local fp = require("fp")
local ski = require("ski")
local log = require("log")
local md5 = require("md5")
local pflib = require("pflib")
local common = require("common")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")

local tcp_map = {}
local mqtt, simple, system_reload

local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)

	system_reload()
end

local function generate_system_cmds()
	local kv, e = simple:mysql_select("select k,v from kv where k in ('zonename', 'timezone')")
	local _ = kv or log.fatal("%s", e)

	local system = fp.reduce(kv, function(t, r) return rawset(t, r.k, r.v) end, {})

	local arr = {}
	table.insert(arr, string.format("uci get system.@system[0] >/dev/null 2>&1 || uci add system system >/dev/null 2>&1"))
	table.insert(arr, string.format("uci set system.@system[0].zonename='%s'", system.zonename))
	table.insert(arr, string.format("uci set system.@system[0].timezone='%s'", system.timezone))

	return {system = arr}
end

function system_reload()
	local system_arr = generate_system_cmds()
	local arr_cmd = {system = {"uci commit system", "/etc/init.d/system reload"}}

	for name in pairs({system = 1}) do
		local cmd_arr = fp.reduce(system_arr[name], function(t, s) return rawset(t, #t + 1, s) end, {})

		local cmd = table.concat(cmd_arr, "\n")
		local new_md5 = md5.sumhexa(cmd)
		local old_md5 = common.read(string.format("uci get %s.@version[0].system_md5 2>/dev/null | head -c32", name), io.popen)

		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].system_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end

			local cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end

-- {"set":["auth_offline_time","auth_no_flow_timeout"]}
tcp_map["dbsync_kv"] = function(p)
	local map = {timezone = 1, zonename = 1}
	for _, key in ipairs(p.set or {}) do
		if map[key] == 1 then
			system_reload()
			return
		end
	end
end

return {init = init, dispatch_tcp = pflib.gen_dispatch_tcp(tcp_map)}