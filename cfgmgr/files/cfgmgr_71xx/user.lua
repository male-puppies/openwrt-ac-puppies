local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local cfglib = require("cfglib")

local udp_map = {}
local udpsrv, mqtt, dbrpc

local reply

local function init(u, p)
	udpsrv, mqtt = u, p
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	reply = cfglib.gen_reply(udpsrv)
end

udp_map["user_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check gid existance
		local gid = p.gid
		local sql = string.format("select count(*) as count from acgroup where gid=%s", gid)
		local rs, e = conn:select(sql) 		assert(rs, e)
		if tonumber(rs[1].count) == 0 then
			return nil, "invalid gid"
		end

		-- check uid exists and dup username
		local uid, username = p.uid, p.username
		local sql = string.format("select * from user where uid=%s or username='%s'", uid, conn:escape(username))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].uid == uid) then
			return nil, "invalid rid or dup username"
		end

		-- check change
		p.uid = nil
		local change, r = false, rs[1]
		for k, nv in pairs(p) do
			if r[k] ~= nv then
				change = true
				break
			end
		end

		if not change then
			return true
		end

		-- update user
		local sql = string.format("update user set %s where uid=%s", conn:update_format(p), uid)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_user_set", code, p)
	-- local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["user_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg
		local username, gid = p.username, p.gid

		-- check gid existance
		local sql = string.format("select count(*) as count from acgroup where gid=%s", gid)
		local rs, e = conn:select(sql) 		assert(rs, e)
		if tonumber(rs[1].count) == 0 then
			return nil, "invalid gid"
		end

		-- check dup username
		local sql = string.format("select count(*) as count from user where username='%s'", conn:escape(username))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if tonumber(rs[1].count) ~= 0 then
			return nil, "dup username"
		end

		-- get next id
		local rs, e = conn:select("select max(uid) as max_uid from user") 			assert(rs, e)

		-- insert new user
		p.uid = (tonumber(rs[1].max_uid) or -1) + 1
		p.register = os.date("%Y-%m-%d %H:%M:%S")
		local sql = string.format("insert into user %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_user_add", code, p)
	-- local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["user_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud

		local uids = js.decode(arg.uids)

		local in_part = table.concat(uids, ",")
		local sql = string.format("delete from user where uid in (%s)", in_part)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_user_del", code, p)
	-- local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}