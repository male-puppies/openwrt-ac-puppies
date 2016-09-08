-- author: yjs

local fp  	= require("fp")
local ski 	= require("ski")
local log 	= require("log")
local cache	= require("cache")
local js  	= require("cjson.safe")
local authlib = require("authlib")

local each = fp.each

local tcp_map = {}
local mqtt, udpsrv

local function init(u, p)
	mqtt, udpsrv = p, u
end

--[[
{
    "cmd": "dbsync",
    "data": {
        "authrule": {
            "set":{"add":{...},"set":{...}}
        },
        "kv": {
            "all": 1
        }
    }
}
]]
tcp_map["dbsync"] = function(p)
	each(p.data, cache.clear)
end

return {init = init, dispatch_tcp = authlib.gen_dispatch_udp(tcp_map)}
