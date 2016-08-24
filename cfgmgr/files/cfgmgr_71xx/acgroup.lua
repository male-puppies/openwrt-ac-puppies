local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local cfglib = require("cfglib")

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

udp_map["acgroup_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check gid exists and dup groupname
		local gid, groupname, groupdesc, pid = arg.gid, arg.groupname, arg.groupdesc, arg.pid
		if pid ~= -1 then
			local sql = string.format("select count(*) as count from acgroup where gid=%s", pid)
			local rs, e = conn:select(sql) 			assert(rs, e)
			if tonumber(rs[1].count) == 0 then
				return nil, "invalid pid"
			end
		end

		local sql = string.format("select * from acgroup where gid=%s or groupname='%s'", gid, conn:escape(groupname))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].gid == gid) then
			return nil, "invalid gid or dup groupname"
		end

		-- check config change
		p.gid = nil
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

		-- update
		local sql = string.format("update acgroup set %s where gid=%s", conn:update_format(p), gid)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_acgroup_set", code, p)
	-- local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["acgroup_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check dup groupname
		local sql = string.format("select * from acgroup")
		local rs, e = conn:select(sql) 			assert(rs, e)

		-- check pid
		local pid = p.pid
		if pid ~= -1 then
			local find = false
			for _, r in ipairs(rs) do
				if pid == r.gid then
					find = true
					break
				end
			end

			if not find then
				return nil, "invalid pid"
			end
		end

		-- check dup groupname
		local ids, groupname = {}, p.groupname
		for _, r in ipairs(rs) do
			local id, name = r.gid, r.groupname
			table.insert(ids, id)
			if name == groupname then
				return nil, "dup groupname"
			end
		end

		-- get next rid
		local id, e = conn:next_id(ids, 64)
		if not id then
			return nil, e
		end

		-- insert
		p.gid = id
		local sql = string.format("insert into acgroup %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_acgroup_add", code, p)
	-- local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["acgroup_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud

		local gids = js.decode(arg.gids)

		-- TODO check more related tables
		local in_part = table.concat(gids, ",")
		local sql = string.format("select sum(count) as count from (select 1,count(*) as count from acgroup where pid in (%s) union select 2,count(*) as count from user where gid in (%s)) t;", in_part, in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end

		local count = tonumber(rs[1].count)
		if count ~= 0 then
			return nil, "referenced"
		end

		local sql = string.format("delete from acgroup where gid in (%s)", in_part)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_acgroup_del", code, p)
	-- local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}