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

udp_map["ipgroup_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check ipgid exists and dup ipgrpname
		local ipgid, ipgrpname, ipgrpdesc, ranges = arg.ipgid, arg.ipgrpname, arg.ipgrpdesc, arg.ranges
		local sql = string.format("select * from ipgroup where ipgid=%s or ipgrpname='%s'", ipgid, conn:escape(ipgrpname))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].ipgid == ipgid) then
			return nil, "invalid ipgid or dup ipgrpname"
		end

		-- check config change
		p.ipgid = nil
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
		local sql = string.format("update ipgroup set %s where ipgid=%s", conn:update_format(p), ipgid)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["ipgroup_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check dup ipgrpname
		local sql = string.format("select * from ipgroup")
		local rs, e = conn:select(sql) 			assert(rs, e)

		local ids, ipgrpname = {}, p.ipgrpname
		for _, r in ipairs(rs) do
			local id, name = r.ipgid, r.ipgrpname
			table.insert(ids, id)
			if name == ipgrpname then
				return nil, "exists ipgrpname"
			end
		end

		-- get next rid
		local id, e = conn:next_id(ids, 64)
		print(id, e)
		if not id then
			return nil, e
		end

		-- insert
		p.ipgid = id
		local sql = string.format("insert into ipgroup %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["ipgroup_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local ipgids = js.decode(arg.ipgids)

		local in_part = table.concat(ipgids, ",")

		-- TODO check authrule tables
		local sql = string.format("select sum(count) as count from (select 1,count(*) as count from authrule where ipgid in (%s) union select 2,count(*) as count from authrule where ipgid in (%s)) t;", in_part, in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end

		local count = tonumber(rs[1].count)
		if count ~= 0 then
			return nil, "referenced"
		end

		-- TODO check acrule tables
		local ipgid_map = {"src_ipgids", "dest_ipgids"}
		for _, v in ipairs(ipgid_map) do
			local sql = string.format("select %s from acrule", v)
			local rs, e = conn:select(sql)
			if not rs then
				return nil, e
			end

			-- judge cited id
			local refer_ipgids = {}
			for _, ipgrp in ipairs(rs) do
				local detail = js.decode(ipgrp[v]) 	assert(detail)
				for _, ipgrpid in ipairs(detail) do
					refer_ipgids[ipgrpid] = true
				end
			end
			local _ = #refer_ipgids > 0 and  table.sort(refer_ipgids)
			for _, ipgrpid in ipairs(ipgids) do
				if refer_ipgids[ipgrpid] then
					return nil, "referenced"
				end
			end
		end

		local sql = string.format("delete from ipgroup where ipgid in (%s)", in_part)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
