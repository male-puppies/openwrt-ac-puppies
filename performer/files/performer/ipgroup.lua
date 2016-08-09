local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")

local tcp_map = {}
local mqtt, simple

local function generate_ipgrp_cmds()
	local cmd = ""
	local arr = {}

	local rs, e = simple:mysql_select("select * from ipgroup")

	table.insert(arr, string.format("while uci delete nos-ipgrp.@ipgrp[0] >/dev/null 2>&1; do :; done"))
	for _, ipgroup in ipairs(rs) do
		local ranges = js.decode(ipgroup.ranges)
		local type = "range"

		table.insert(arr, string.format("obj=`uci add nos-ipgrp ipgrp`"))
		table.insert(arr, string.format("test -n \"$obj\" && {"))
		table.insert(arr, string.format("	uci set nos-ipgrp.$obj.name='%s'", ipgroup.ipgrpname))
		table.insert(arr, string.format("	uci set nos-ipgrp.$obj.id='%s'", ipgroup.ipgid))
		if ipgroup.ipgid == 255 then
			type = "all"
		end
		for _, range in ipairs(ranges) do
			if range == "0.0.0.0-255.255.255.255" then
				type = 'all'
			end
			table.insert(arr, string.format("	uci add_list nos-ipgrp.$obj.network='%s'", range))
		end
		table.insert(arr, string.format("	uci set nos-ipgrp.$obj.type='%s'", type))
		table.insert(arr, string.format("}"))
	end

	cmd = table.concat(arr, "\n")
	return cmd
end

local function ipgrp_reload()
	local cmd = ""
	local arr = {}

	table.insert(arr, generate_ipgrp_cmds())
	table.insert(arr, string.format("uci commit nos-ipgrp"))
	table.insert(arr, string.format("/etc/init.d/nos-ipgrp restart"))

	cmd = table.concat(arr, "\n")
	print(cmd)
	os.execute(cmd)
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
