-- author: yjs

local fp 		= require("fp")
local ski 		= require("ski")
local log 		= require("log")
local cache		= require("cache")
local batch		= require("batch")
local common	= require("common")
local js 		= require("cjson.safe")
local rpccli	= require("rpccli")
local authlib	= require("authlib")
local simplesql	= require("simplesql")

local set_online = authlib.set_online
local keepalive, insert_online = authlib.keepalive, authlib.insert_online
local limit, reduce, each, empty, tomap = fp.limit, fp.reduce, fp.each, fp.empty, fp.tomap

local udp_map = {}
local simple, udpsrv, mqtt
local keepalive_trigger, on_keepalive_batch
local loop_timeout_check

local function init(u, p)
	udpsrv, mqtt = u, p

	local dbrpc  = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)
	keepalive_trigger = batch.new(on_keepalive_batch)

	ski.go(loop_timeout_check)
end

-- {"cmd":"auto_keepalive","uid":70,"rid":1,"ukey":"70_142","mac":"28:a0:2b:65:4d:62","magic":142,"ip":"172.16.24.186"}
udp_map["auto_keepalive"] = function(p)
	keepalive_trigger:emit(p)
end

-- 批量更新自动认证的状态。
function on_keepalive_batch(count, arr)
	local step = 100 	-- 每次最多更新100个
	for i = 1, #arr, step do
		local alive = limit(arr, i, step)

		-- 查询在线用户
		local narr = reduce(alive, function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.ukey)) end, {})
		local sql = string.format("select ukey from memo.online where ukey in (%s)", table.concat(narr, ","))
		local rs, e = simple:mysql_select(sql) 		assert(rs, e)

		local online = tomap(rs, "ukey")
		local offline = reduce(alive, function(t, r) return online[r.ukey] and t or rawset(t, r.ukey, r) end, {})

		-- 更新已经在线的用户的active
		if #rs > 0 then
			local narr = reduce(rs, function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.ukey)) end, {})
			local sql = string.format("update memo.online set active='%s' where ukey in (%s)", math.floor(ski.time()), table.concat(narr, ","))
			local r, e = simple:mysql_execute(sql) 	assert(r, e)
		end

		-- 插入新上线用户
		if not empty(offline) then
			each(offline, function(ukey, r)
				r.gid = 0
				r.username = r.mac
			end)
			insert_online(simple, offline, "auto")
		end
	end
end

-- 定时/超时下线
function loop_timeout_check()
	while true do
		ski.sleep(cache.timeout_check_intervel())
		authlib.timeout_offline(simple, "auto")
	end
end

return {init = init, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

