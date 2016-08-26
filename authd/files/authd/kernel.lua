-- author: yjs

local fp 	= require("fp")
local ski 	= require("ski")
local log 	= require("log")
local cache	= require("cache")
local nos 	= require("luanos")
local js 	= require("cjson.safe")
local authlib = require("authlib")

local reduce2, each = fp.reduce2, fp.each
local get_module, set_module = cache.get_module, cache.set_module
local get_ip_mac, get_rule_id = nos.user_get_ip_mac, nos.user_get_rule_id

local dispatch_keepalive = function() end

local udp_map = {}
local udpsrv, mqtt

local miss_map = {}
local miss_timeout_offline

local function init(u, p)
	udpsrv, mqtt = u, p
	ski.go(miss_timeout_offline)
end

local function set_kernel_cb(cb)
	dispatch_keepalive = cb
end

local function incr_miss(ukey, p)
	local r = miss_map[ukey]
	if r then
		if r.count >= 5 then
			log.info("force offline %s %s", ukey, js.encode(p))
			return nos.user_set_offline(p.uid, p.magic)
		end

		r.count, r.active = r.count + 1, ski.time()
		return
	end

	miss_map[ukey] = {count = 1, active = ski.time()}
end

local function clear_miss(ukey)
	miss_map[ukey] = nil
end

--[[
ntrackd发送来的内核上报道心跳
@param p : {"cmd":"keepalive","magic":1510,"uid":754}
]]
udp_map["keepalive"] = function(p)
	local uid, magic = p.uid, p.magic

	-- 查询参数rid，ip，mac
	local rid = get_rule_id(uid, magic)
	local ip, mac = get_ip_mac(uid, magic)
	if not (rid and ip) then
		log.error("invalid uid/magic")
		return
	end

	local ukey = string.format("%s_%s", uid, magic)

	-- web/sms/wechat等会在上线时设置mod，auto需要查询authrule
	local mod = get_module(ukey)
	if not mod then
		local authrule = cache.authrule(rid)
		if not authrule then
			log.error("miss authrule and mod for %s %s", rid, ukey)
			return incr_miss(ukey, p)
		end

		if authrule.authtype ~= "auto" then
			return incr_miss(ukey, p)
		end

		mod = "auto"
		set_module(ukey, mod)
	end

	clear_miss(ukey)
	p.ip, p.mac, p.rid, p.cmd, p.ukey = ip, mac, rid, mod .. "_keepalive", ukey
	dispatch_keepalive(p)
end

-- 可能出现ukey认证类型无法识别的keepalive消息，缓存在miss_map，一定次数后强制下线
function miss_timeout_offline()
	while true do
		ski.sleep(10)

		local now = ski.time()
		local del = reduce2(miss_map, function(t, k, r)	return now - r.active > 60 and rawset(t, #t + 1, k) or t end, {})
		each(del, function(k) miss_map[k] = nil end)

		local count = fp.count(miss_map)
		local _ = count > 10 and log.error("too many miss_map %s", count)
	end
end

return {init = init, set_kernel_cb = set_kernel_cb, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

