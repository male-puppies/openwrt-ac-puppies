local fp 		= require("fp")
local ski 		= require("ski")
local log 		= require("log")
local nos 		= require("luanos")
local js 		= require("cjson.safe")
local cache		= require("cache")

local set_status, set_gid_ucrc = nos.user_set_status, nos.user_set_gid_ucrc
local each, reduce2 = fp.each, fp.reduce2

local function gen_dispatch_udp(udp_map)
	return function(cmd, ip, port)
		local f = udp_map[cmd.cmd]
		if f then
			return true, f(cmd, ip, port)
		end
	end
end

local function gen_dispatch_tcp(tcp_map)
	return function(cmd)
		local f = tcp_map[cmd.cmd]
		if f then
			return true, f(cmd.data)
		end
	end
end

local function gen_reply(udpsrv)
	return function(ip, port, r, d)
		udpsrv:send(ip, port, js.encode({status = r, data = d}))
		return true
	end
end

local function set_online(uid, magic, gid, username)
	local _ = set_status(uid, magic, 1), set_gid_ucrc(uid, magic, gid, 1)
end

local function set_offline(uid, magic)
	set_status(uid, magic, 0)
end

local set_module = cache.set_module
local function insert_online(simple, user_map, authtype)
	each(user_map, function(_, r) set_online(r.uid, r.magic, r.gid, r.username) end)

	local now = math.floor(ski.time())
	local arr = reduce2(user_map, function(t, ukey, p)
		local s = string.format("('%s','%s','%s','%s','%s','%s',%s,%s,%s,%s)", p.ukey, authtype, p.username, p.ip, p.mac, p.ext or '{}', p.rid, p.gid, now, now)
		return rawset(t, #t + 1, s)
	end, {})

	local sql = string.format([[insert or replace into memo.online (ukey,type,username,ip,mac,ext,rid,gid,login,active) values %s]], table.concat(arr, ","))
	local r, e = simple:mysql_execute(sql) 	assert(r, e)

	each(user_map, function(_, r) set_module(r.ukey, authtype) end)
end

local function timeout_offline(simple, mod)
	local active_timeout = 600
	local now = math.floor(ski.time())

	-- 选择属于模块mod，active太久没有更新、定时下线的用户
	local sql = string.format("select ukey,username from memo.online where type='%s' and (active-login>%s or %s-active>%s);",
		mod, cache.auth_offline_time(), now, active_timeout)
	local rs, e = simple:mysql_select(sql) 	assert(rs, e)
	if #rs == 0 then
		return
	end

	-- 从内核下线
	each(rs, function(_, r)
		local uid, magic = r.ukey:match("(%d+)_(%d+)")
		authlib.set_offline(tonumber(uid), tonumber(magic))
		log.real1("set_offline %s", js.encode(r))
	end)

	-- 从memo.online删除
	local narr = reduce(rs, function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.ukey)) end, {})
	local sql = string.format("delete from memo.online where ukey in (%s)", table.concat(narr, ","))
	local r, e = simple:mysql_execute(sql) 	assert(r, e)

	-- 删除缓存
	each(rs, function(_, r) set_module(r.ukey, nil) end)
end

return {
	gen_reply 			= gen_reply,
	set_online 			= set_online,
	set_offline 		= set_offline,
	insert_online 		= insert_online,
	timeout_offline 	= timeout_offline,
	gen_dispatch_udp 	= gen_dispatch_udp,
	gen_dispatch_tcp 	= gen_dispatch_tcp,
}
