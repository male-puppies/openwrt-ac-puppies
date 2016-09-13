-- author: yjs

local fp 	= require("fp")
local ski 	= require("ski")
local log 	= require("log")
local batch	= require("batch")
local nos 	= require("luanos")
local js 	= require("cjson.safe")
local rpccli 	= require("rpccli")
local simplesql = require("simplesql")

local rid_map = {}
local simple, udpsrv, mqtt
local reduce, tomap, reduce2 = fp.reduce, fp.tomap, fp.reduce2
local bypass_timeout, on_bypass_timeout

-------------------------------------------- common ------------------------------------------------
local clear_map = {}
local function init(u, p)
	udpsrv, mqtt = u, p
	local dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)

	bypass_timeout 	= batch.new(on_bypass_timeout)
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
	online_cache = reduce(rs, function(t, r) return rawset(t, r.ukey, r.type) end, {})
end

-- 设置或者删除ukey对应的mod
local function set_module(ukey, mod)
	check_module()

	if not mod then
		online_cache[ukey] = nil
	elseif not online_cache[ukey] then
		online_cache[ukey] = mod
	end
end

local function get_module(ukey)
	check_module()
	return online_cache[ukey]
end

---------------------------------------------- kv ---------------------------------------------
local kv_cache
local function check_kv()
	if kv_cache then
		return
	end

	local fields = {auth_offline_time = 1, auth_redirect_ip = 0, auth_no_flow_timeout = 1}
	local narr = reduce2(fields, function(t, k) return rawset(t, #t + 1, string.format("'%s'", k)) end, {})
	local sql = string.format("select k,v from kv where k in (%s)", table.concat(narr, ","))
	local rs, e = simple:mysql_select(sql)		assert(rs, e)

	kv_cache = reduce(rs, function(t, r)
		local k, v = r.k, r.v
		t[k] = fields[k] == 1 and js.decode(v) or v
		return t
	end, {})
end

local function kv_get_common(field)
	check_kv()
	return kv_cache[field]
end

local function auth_offline_time()
	return kv_get_common("auth_offline_time")
end

local function auth_redirect_ip()
	return kv_get_common("auth_redirect_ip")
end

local function auth_no_flow_timeout()
	return kv_get_common("auth_no_flow_timeout")
end

function clear_map.kv(action)
	kv_cache = nil
	log.debug("clear kv_cache %s", js.encode(action))
end

---------------------------------------------- authrule ---------------------------------------------
local authrule_cache

function clear_map.authrule(action)
	authrule_cache = nil
	log.debug("clear authrule_cache %s", js.encode(action))
end

local function check_authrule()
	if authrule_cache then
		return
	end

	local rs, e = simple:mysql_select("select * from authrule")		assert(rs, e)
	authrule_cache = tomap(rs, "rid")
end

local function authrule(rid)
	check_authrule()
	return authrule_cache[rid]
end

------------------------------------------------ other ---------------------------------------------------
local function timeout_check_intervel()
	return 30 -- TODO
end

------------------------------------------------ bypass ---------------------------------------------------


--[[
临时放通：
/bypass_host：收到临时放通请求，存放到bypass_wait_map，以终端mac作为key。
/weixin2_login：认证成功，会从extend中提取mac，并把bypass_wait_map[mac]删除
认证失败时，并且临时放通时间超时后，会在on_bypass_timeout把bypass_wait_map[mac]删除，并且把对应的终端下线
]]
local bypass_wait_map = {}
function on_bypass_timeout(count, arr)
	local idx = 1
	local f = function()
		local r, now = arr[idx], ski.time()
		if r.deadline >= now then
			return ski.sleep(1)
		end

		idx = idx + 1

		local mac = r.mac
		if not bypass_wait_map[mac] then
			return
		end

		bypass_wait_map[mac] = nil

		local uid, magic = r.uid, r.magic
		log.real1("bypass timeout %s %s %s", uid, magic, mac)

		local r, e = nos.user_set_offline(uid, magic)
		local _ = r or log.error("set_offline fail %s", e)
	end

	while idx <= #arr do f() end
end

local function bypass(mac, p)
	local uid, magic = p.uid, p.magic

	local r, e = nos.user_set_bypass(uid, magic)
	if not r then
		return nil, e
	end

	bypass_wait_map[mac] = 1
	bypass_timeout:emit({deadline = ski.time() + 20, uid = uid, magic = magic, mac = mac})
	log.real1("bypass %s", js.encode(p))

	return true
end

local function bypass_cancel(mac)
	bypass_wait_map[mac] = nil
end

------------------------------------------------ end ---------------------------------------------------
return {
	init 			= init,
	clear 			= clear,

	set_module 		= set_module,
	get_module 		= get_module,

	authrule 		= authrule,

	bypass 			= bypass,
	bypass_cancel 	= bypass_cancel,

	auth_offline_time 		= auth_offline_time,
	auth_redirect_ip 		= auth_redirect_ip,
	auth_no_flow_timeout 	= auth_no_flow_timeout,

	timeout_check_intervel 	= timeout_check_intervel,
}
