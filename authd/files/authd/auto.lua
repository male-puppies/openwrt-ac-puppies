local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local batch = require("batch")
local common = require("common")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local authlib = require("authlib")
local simplesql = require("simplesql")

local map2arr, arr2map, limit, empty = common.map2arr, common.arr2map, common.limit, common.empty
local find_missing, set_online = authlib.find_missing, authlib.set_online
local keepalive, insert_online = authlib.keepalive, authlib.insert_online

local udp_map = {}
local simple, udpsrv, mqtt
local keepalive_trigger, on_keepalive_batch

local function init(u, p)
	udpsrv, mqtt = u, p
	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)
	keepalive_trigger = batch.new(on_keepalive_batch)
end

udp_map["auto_keepalive"] = function(p)
	keepalive_trigger:emit(p)
end

function on_keepalive_batch(count, arr)
	local ukey_arr = map2arr(arr2map(arr, "ukey"))
	local step = 100
	for i = 1, #ukey_arr, step do 
		local exists, miss = find_missing(simple, limit(ukey_arr, i, step))
		local _ = empty(exists) or keepalive(simple, exists)

		if not empty(miss) then
			for _, r in pairs(miss) do 
				r.username = r.mac
				r.gid = 1 --TODO select gid 
				local _ = gid and set_online(r.uid, r.magic, r.gid, r.username)
			end
			insert_online(simple, miss, "auto")
		end
	end
end

return {init = init, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

