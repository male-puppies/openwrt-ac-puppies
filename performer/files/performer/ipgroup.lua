-- cmq

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
local mqtt, simple, ipgrp_reload

local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)

	ipgrp_reload()
end

local function generate_ipgrp_cmds()
	local arr = {}

	local rs, e = simple:mysql_select("select * from ipgroup")
	local _ = rs or log.fatal("%s", e)

	table.insert(arr, string.format("while uci delete nos-ipgrp.@ipgrp[0] >/dev/null 2>&1; do :; done"))
	for _, ipgroup in ipairs(rs) do
		table.insert(arr, string.format("obj=`uci add nos-ipgrp ipgrp`"))
		table.insert(arr, string.format("test -n \"$obj\" && {"))
		table.insert(arr, string.format("	uci set nos-ipgrp.$obj.name='%s'", ipgroup.ipgrpname))
		table.insert(arr, string.format("	uci set nos-ipgrp.$obj.id='%s'", ipgroup.ipgid))

		local ipgrp = ipops.ipranges2ipgroup(js.decode(ipgroup.ranges))
		local ranges = ipops.ipgroup2ipranges(ipgrp)

		local type = ipgroup.ipgid == 255 and "all" or "range"
		for _, range in ipairs(ranges) do
			if range == "0.0.0.0-255.255.255.255" then
				type = 'all'
			end
			table.insert(arr, string.format("	uci add_list nos-ipgrp.$obj.network='%s'", range))
		end

		table.insert(arr, string.format("	uci set nos-ipgrp.$obj.type='%s'", type))
		table.insert(arr, string.format("}"))
	end

	return {["nos-ipgrp"] = arr}
end

function ipgrp_reload()
	local arr_cmd = {["nos-ipgrp"] = {"uci commit nos-ipgrp", "/etc/init.d/nos-ipgrp restart"}}

	local ipgrp_map = generate_ipgrp_cmds()
	for name in pairs({["nos-ipgrp"] = 1}) do
		local cmd_arr = fp.reduce(ipgrp_map[name], function(t, s) return rawset(t, #t + 1, s) end, {})
		local cmd = table.concat(cmd_arr, "\n")

		local new_md5 = md5.sumhexa(cmd)
		local old_md5 = common.read(string.format("uci get %s.@version[0].ipgroup_md5 2>/dev/null | head -c32", name), io.popen)

		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].ipgroup_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end

			local cmd = table.concat(cmd_arr, "\n")
			print(cmd) -- TODO
			os.execute(cmd)
		end
	end
end

tcp_map["dbsync_ipgroup"] = function(p)
	ipgrp_reload()
end

return {init = init, dispatch_tcp = pflib.gen_dispatch_tcp(tcp_map)}