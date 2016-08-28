local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local cfglib = require("cfglib")
local simplesql = require("simplesql")

local udp_map = {}
local myconn, udpsrv, mqtt, dbrpc, simple, reply

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)
end

udp_map["zone_get"] = function(p, ip, port)
	local page, count = p.page, p.count
	local sql = string.format("select * from zone a, iface b where a.zid=b.zid")
	local rs, e = simple:select(sql)
	if not rs then
		return reply(ip, port, 1, e)
	end

	local map = {}
	for _, r in ipairs(rs) do
		local zid = r.zid
		local arr = map[zid] or {}
		table.insert(arr, r)
		map[zid] = arr
	end

	local rs = {}
	for zid, arr in pairs(map) do
		local r = arr[1]
		local zonename, zonedesc, zonetype = r.zonename, r.zonedesc, r.zonetype
		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, r.ifname)
		end
		table.insert(rs, {zid = zid, zonename = zonename, zonedesc = zonedesc, zonetype = zonetype, ifnames = narr})
	end

	reply(ip, port, 0, rs)
end

udp_map["zone_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud = ins.conn, ins.ud
		local zid, zonedesc, zonetype = arg.zid, arg.zonedesc, arg.zonetype
		local rs, e = conn:select("select zid,zonename from zone") 			assert(rs, e)

		local exists, find = {}, false
		for _, r in ipairs(rs) do
			local k = tonumber(r.zid)
			if k == zid then
				find = true
			end
		end

		if not find then
			return nil, "miss zid"
		end

		local sql = string.format("update zone set zonedesc='%s',zonetype='%s' where zid='%s'", conn:escape(zonedesc), zonetype, zid)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_zone_set", code, p)
	if not r then
		return reply(ip, port, 1, e)
	end

	reply(ip, port, 0, r)
end

udp_map["zone_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud = ins.conn, ins.ud
		local zonename, zonedesc, zonetype = arg.zonename, arg.zonedesc, arg.zonetype
		local rs, e = conn:select("select zid,zonename from zone") 			assert(rs, e)

		local exists, max_id = {}, -1
		for _, r in ipairs(rs) do
			local k = tonumber(r.zid)
			if k ~= 255 and k > max_id then
				max_id = k
			end
			if r.zonename == zonename then
				return nil, "dup zone zonename"
			end
		end

		local zid = max_id + 1
		if zid >= 255 then
			return nil, "zid full"
		end

		local sql = string.format("insert into zone(zid,zonename,zonedesc,zonetype) values ('%s','%s','%s','%s')", zid, conn:escape(zonename), conn:escape(zonedesc), zonetype)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return zid
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_zone_add", code, p)
	if not r then
		return reply(ip, port, 1, e)
	end

	reply(ip, port, 0, r)
end

udp_map["zone_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud = ins.conn, ins.ud
		local zids = arg.zids
		local in_part = table.concat(zids, ",")

		local arr, tables = {}, {"iface", "ipgroup", "authrule"}
		for i, tbname in ipairs(tables) do
			local sql = string.format("select %s,count(*) as count from %s where zid in (%s)", i, tbname, in_part)
			table.insert(arr, sql)
		end

		local sql = string.format("select sum(count) as count from (select 1,count(*) as count from iface where zid in (%s) union select 2,count(*) as count from ipgroup where zid in (%s) union select 3,count(*) as count from authrule where zid in (%s)) t;", in_part, in_part, in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end

		local count = tonumber(rs[1].count)
		if count ~= 0 then
			return nil, "zid referenced"
		end

		local sql = string.format("delete from zone where zid in (%s)", in_part)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_zone_del", code, p)
	if not r then
		return reply(ip, port, 1, e)
	end

	reply(ip, port, 0, r)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
