local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local batch = require("batch")
local share = require("share")
local js = require("cjson.safe")
local authlib = require("authlib")

local map2arr, arr2map, limit, empty = share.map2arr, share.arr2map, share.limit, share.empty
local find_missing, set_online = authlib.find_missing, authlib.set_online
local keepalive, insert_online = authlib.keepalive, authlib.insert_online

local udp_map = {}
local myconn, udpsrv, mqtt
local keepalive_trigger, on_keepalive_batch

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
	keepalive_trigger = batch.new(on_keepalive_batch)
end

local function dispatch_udp(cmd, ip, port)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
end

udp_map["auto_keepalive"] = function(p)
	keepalive_trigger:emit(p)
end

function on_keepalive_batch(count, arr)
	local ukey_arr = map2arr(arr2map(arr, "ukey"))
	local step = 100
	for i = 1, #ukey_arr, step do 
		local exists, miss = find_missing(myconn, limit(ukey_arr, i, step))
		local _ = empty(exists) or keepalive(myconn, exists)

		if not empty(miss) then
			for _, r in pairs(miss) do 
				r.username = r.mac
				r.gid = cfg.get_gid(r.rid)
				local _ = gid and set_online(r.uid, r.magic, r.gid, r.username)
			end
			insert_online(myconn, miss, "auto")
		end
	end
end

return {init = init, dispatch_udp = dispatch_udp}

