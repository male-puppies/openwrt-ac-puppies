local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")

local tcp_map = {}
local mqtt, on_event_cb

local function init(p)
	mqtt = p
end

local function set_event_cb(cb)
	on_event_cb = cb
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd.data)
	end
end

tcp_map["dbsync"] = function(p)
	for tbname, n in pairs(p) do
		on_event_cb({cmd = "dbsync_" .. tbname, data = n})
	end
end

return {init = init, dispatch_tcp = dispatch_tcp, set_event_cb = set_event_cb}
