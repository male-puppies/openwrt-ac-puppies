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

local function generate_ipgrp_cmds()
	local arr = {}
	arr["nos-ipgrp"] = {}

	local rs, e = simple:mysql_select("select * from ipgroup")

	table.insert(arr["nos-ipgrp"], string.format("while uci delete nos-ipgrp.@ipgrp[0] >/dev/null 2>&1; do :; done"))
	for _, ipgroup in ipairs(rs) do
		local ranges = js.decode(ipgroup.ranges)
		local type = "range"

		table.insert(arr["nos-ipgrp"], string.format("obj=`uci add nos-ipgrp ipgrp`"))
		table.insert(arr["nos-ipgrp"], string.format("test -n \"$obj\" && {"))
		table.insert(arr["nos-ipgrp"], string.format("	uci set nos-ipgrp.$obj.name='%s'", ipgroup.ipgrpname))
		table.insert(arr["nos-ipgrp"], string.format("	uci set nos-ipgrp.$obj.id='%s'", ipgroup.ipgid))
		if ipgroup.ipgid == 255 then
			type = "all"
		end

		local ipgrp = ipops.ipranges2ipgroup(ranges)
		ranges = ipops.ipgroup2ipranges(ipgrp)
		for _, range in ipairs(ranges) do
			if range == "0.0.0.0-255.255.255.255" then
				type = 'all'
			end
			table.insert(arr["nos-ipgrp"], string.format("	uci add_list nos-ipgrp.$obj.network='%s'", range))
		end
		table.insert(arr["nos-ipgrp"], string.format("	uci set nos-ipgrp.$obj.type='%s'", type))
		table.insert(arr["nos-ipgrp"], string.format("}"))
	end

	return arr
end

local function ipgrp_reload()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}

	arr["nos-ipgrp"] = {}
	arr_cmd["nos-ipgrp"] = {
		string.format("uci commit nos-ipgrp"),
		string.format("/etc/init.d/nos-ipgrp restart")
	}

	local ipgrp_arr = generate_ipgrp_cmds()

	for name, cmd_arr in pairs(arr) do
		for _, line in ipairs(ipgrp_arr[name]) do
			table.insert(cmd_arr, line)
		end

		cmd = table.concat(cmd_arr, "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = common.read(string.format("uci get %s.@version[0].md5 | head -c32", name), io.popen)
		--print(new_md5, old_md5)
		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] || uci add %s version", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].md5='%s'", name, new_md5))
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

	ipgrp_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

tcp_map["dbsync_ipgroup"] = function(p)
	print(js.encode(p))

	ipgrp_reload()
end

return {init = init, dispatch_tcp = dispatch_tcp}
