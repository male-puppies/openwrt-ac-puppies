-- author: gl
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
	dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
end

udp_map["firewall_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check fwid exists and dup fwname
		local fwid, fwname = arg.fwid, arg.fwname
		local sql = string.format("select * from firewall where fwid=%s or fwname='%s'", fwid, conn:escape(fwname))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].fwid == fwid) then
			return nil, "invalid fwid or dup fwname"
		end

		-- check config change
		p.fwid = nil
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
		-- update firewall
		local sql = string.format("update firewall set %s where fwid=%s", conn:update_format(p), fwid)
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

udp_map["firewall_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg
		local fwname = p.fwname

		-- check dup fwname
		local rs, e = conn:select("select * from firewall") 			assert(rs, e)
		local ids, priorities = {}, {}
		for _, r in ipairs(rs) do
			local name = r.fwname
			local _ = table.insert(ids, r.fwid), table.insert(priorities, r.priority)
			if name == fwname then
				return nil, "exists fwname"
			end
		end

		-- get next fwid
		local id, e = conn:next_id(ids, 64)
		if not id then
			return nil, e
		end

		local priority = 0
		if #priorities > 0 then
			table.sort(priorities)
			priority = priorities[#priorities] + 1
		end

		-- insert new firewall
		p.fwid, p.priority = id, priority
		local sql = string.format("insert into firewall %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["firewall_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local fwids = js.decode(arg.fwids)


		-- check fwids valid
		local rs, e = conn:select("select * from firewall") 			assert(rs, e)
		local ids = {}
		for _, r in ipairs(rs) do
			local _ = table.insert(ids, r.fwid, r.fwid)
		end

		for _, nv in pairs(fwids) do
			if not ids[nv] then
				return nil, "invalid fwid"
			end
		end

		-- delete one or more firewall
		local sql = string.format("delete from firewall where fwid in (%s)", table.concat(fwids, ","))
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["firewall_adjust"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local fwids = js.decode(arg.fwids)
		local fwids1, fwids2 = fwids[1], fwids[2]


		local sql = string.format("select fwid, priority from firewall where fwid in (%s)", table.concat(fwids, ","))
		local rs, e = conn:select(sql) 	assert(rs, e)
		if not rs then
			return nil, e
		end

		if #rs ~= 2 then
			return nil, "invalid fwids"
		end

		rs[1].priority, rs[2].priority = rs[2].priority, rs[1].priority
		local arr, e = conn:transaction(function()
			local arr = {}
			for _, r in ipairs(rs) do
				local sql = string.format("update firewall set priority='%s' where fwid='%s'", r.priority, r.fwid)
				local r, e = conn:execute(sql)
				if not r then
					return nil, e
				end
				table.insert(arr, sql)
			end
			return arr
		end)
		if not arr then
			return nil, e
		end

		ud:save_log(arr, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}