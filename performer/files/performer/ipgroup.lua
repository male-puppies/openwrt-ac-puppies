local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")

local tcp_map = {}
local mqtt, simple

local function init(p)
	mqtt = p
	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

tcp_map["dbsync_ipgroup"] = function(p)
	print(js.encode(p))
	local rs, e = simple:mysql_select("select * from ipgroup")
	print(js.encode(rs))
end

return {init = init, dispatch_tcp = dispatch_tcp}
