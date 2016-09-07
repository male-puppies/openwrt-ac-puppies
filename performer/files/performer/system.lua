local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")
local md5 = require("md5")
local common = require("common")

local tcp_map = {}
local mqtt, simple

local function generate_system_cmds()
	local arr = {}
	arr["system"] = {}

	local kv, e = simple:mysql_select("select k,v from kv where k in ('zonename', 'timezone')")

	local system = {}
	for _, r in ipairs(kv) do
		system[r.k] = r.v
	end

	table.insert(arr["system"], string.format("uci get system.@system[0] >/dev/null 2>&1 || uci add system system >/dev/null 2>&1"))
	table.insert(arr["system"], string.format("uci set system.@system[0].zonename='%s'", system.zonename))
	table.insert(arr["system"], string.format("uci set system.@system[0].timezone='%s'", system.timezone))

	return arr
end

local function system_reload()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}

	arr["system"] = {}
	arr_cmd["system"] = {
		string.format("uci commit system"),
		string.format("/etc/init.d/system reload")
	}

	local system_arr = generate_system_cmds()

	for name, cmd_arr in pairs(arr) do
		for _, line in ipairs(system_arr[name]) do
			table.insert(cmd_arr, line)
		end

		cmd = table.concat(cmd_arr, "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = common.read(string.format("uci get %s.@version[0].system_md5 2>/dev/null | head -c32", name), io.popen)
		--print(new_md5, old_md5)
		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].system_md5='%s'", name, new_md5))
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

	system_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

tcp_map["dbsync_kv"] = function(p)
	local map = {
		["timezone"] = 1,
		["zonename"] = 1,
	}

	for _, key in ipairs(p.set or {}) do
		if map[key] == 1 then
			system_reload()
			return
		end
	end
end

return {init = init, dispatch_tcp = dispatch_tcp}
