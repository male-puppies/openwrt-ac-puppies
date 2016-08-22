local fp 	= require("fp")
local ski 	= require("ski")
local log 	= require("log")
local js 	= require("cjson.safe")
local rpccli 	= require("rpccli")
local simplesql = require("simplesql")

local rid_map = {}
local simple, udpsrv, mqtt

-------------------------------------------- common ------------------------------------------------
local clear_map = {}
local function init(u, p)
	udpsrv, mqtt = u, p
	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)
end

local function clear(tbname, action)
	local f = clear_map[tbname]
	local _ = f and f(action)
end

---------------------------------------- memo.online ---------------------------------------------
local online_cache

-- 如果没有初始化online_cache，从memo.online初始化
local function check_module()
	if online_cache then
		return
	end

	local rs, e = simple:mysql_select("select ukey,type from memo.online") 	assert(rs, e)
	online_cache = fp.reduce(rs, function(t, r) return rawset(t, r.ukey, r.type) end, {})
	print("init mod",  js.encode(online_cache))
end

local function set_module(ukey, mod)
	print(ukey, mod)
	check_module()
	if not online_cache[ukey] then
		online_cache[ukey] = mod
	end
	print("set_module", js.encode(online_cache))
end

local function get_module(ukey)
	check_module()
	return online_cache[ukey]
end

---------------------------------------------- kv ---------------------------------------------
local kv_cache
local fields = {"offline_time"}

local function check_kv()
	if kv_cache then
		return
	end

	local narr = fp.reduce(fields, function(t, v) return rawset(t, #t + 1, string.format("'%s'", v)) end, {})
	local sql = string.format("select k,v from kv where k in (%s)", table.concat(narr, ","))
	local rs, e = simple:mysql_select(sql)		assert(rs, e)
	kv_cache = fp.reduce(rs, function(t, r) return rawset(t, r.k, r.v) end, {})
end

local function offline_time()
	check_kv()
	return tonumber(kv_cache.offline_time)
end

function clear_map.kv(action)
	kv_cache = nil
	log.debug("clear kv_cache %s", js.encode(action))
end

return {
	init 			= init,
	clear 			= clear,

	set_module 		= set_module,
	get_module 		= get_module,

	offline_time 	= offline_time,
}
