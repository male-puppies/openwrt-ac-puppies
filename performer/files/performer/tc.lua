local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local common = require("common")
local ipops = require("ipops")
local md5 = require("md5")

local read = common.read

local function tc_reload()
	local cmd = string.format("/etc/init.d/nos-tbqd restart")
	print(cmd)
	os.execute(cmd)
end

local tcp_map = {}
local mqtt
local function init(p)
	mqtt = p
	tc_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd.data)
	end
end

tcp_map["tc"] = function(p)
	tc_reload()
end

return {init = init, dispatch_tcp = dispatch_tcp}
