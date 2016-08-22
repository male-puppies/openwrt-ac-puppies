local fp 		= require("fp")
local ski 		= require("ski")
local log 		= require("log")
local nos 		= require("luanos")
local js 		= require("cjson.safe")
local cache		= require("cache")

local set_status, set_gid_ucrc 		= nos.user_set_status, nos.user_set_gid_ucrc

local function set_online(uid, magic, gid, username)
	local _ = set_status(uid, magic, 1), set_gid_ucrc(uid, magic, gid, 1)
end

local function set_offline(uid, magic)
	set_status(uid, magic, 0)
end

local set_module = cache.set_module
local function insert_online(simple, user_map, authtype)
	local now = math.floor(ski.time())

	local arr = fp.reduce2(user_map, function(t, ukey, p)
		local s = string.format("('%s','%s','%s','%s','%s','%s',%s,%s,%s,%s)", p.ukey, authtype, p.username, p.ip, p.mac, p.ext or '{}', p.rid, p.gid, now, now)
		return rawset(t, #t + 1, s)
	end, {})

	local sql = string.format([[insert or replace into memo.online (ukey,type,username,ip,mac,ext,rid,gid,login,active) values %s]], table.concat(arr, ","))
	local r, e = simple:mysql_execute(sql) 	assert(r, e)

	fp.each(user_map, function(_, r) set_module(r.ukey, authtype) end)
end

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

return {
	gen_reply 			= gen_reply,
	set_online 			= set_online,
	set_offline 		= set_offline,
	insert_online 		= insert_online,
	gen_dispatch_udp 	= gen_dispatch_udp,
	gen_dispatch_tcp 	= gen_dispatch_tcp,
}
