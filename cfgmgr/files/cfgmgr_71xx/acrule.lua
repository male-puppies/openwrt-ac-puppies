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
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

udp_map["acrule_set"] = function(p, ip, port)
	print(js.encode(p))
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud, p = ins.conn, ins.ud, arg
		local ruleid, rulename = p.ruleid, p.rulename

		--check ipids tmids protoids existance
		local src_ipgids, dest_ipgids, tmgrp_ids, proto_ids = p.src_ipgids, p.dest_ipgids, p.tmgrp_ids, p.proto_ids
		local sipids = js.decode(src_ipgids)
		local n = #sipids
		local in_part = table.concat(sipids, ", ")
		local sql = string.format("select ipgid from ipgroup where ipgid in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid src_ipgroup"
		end
		local dipids = js.decode(dest_ipgids)
		local n = #dipids
		local in_part = table.concat(dipids, ", ")
		local sql = string.format("select ipgid from ipgroup where ipgid in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid dest_ipgroup"
		end

		local pids = js.decode(proto_ids)
		local n = #pids
		local in_part = table.concat(pids, ", ")
		local sql = string.format("select proto_id from acproto where proto_id in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid protocol"
		end

		local tids = js.decode(tmgrp_ids)
		local n = #tids
		local in_part = table.concat(tids, ", ")
		local sql = string.format("select tmgid from timegroup where tmgid in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid timegroup"
		end

		-- check ruleid exists and dup rulename
		local sql = string.format("select * from acrule where ruleid=%s or rulename='%s'", ruleid, conn:escape(rulename))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].ruleid == ruleid) then
			return nil, "invalid ruleid or dup rulename"
		end

		-- check change
		p.ruleid = nil
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

		--update acrule
		local sql = string.format("update acrule set %s where ruleid=%s", conn:update_format(p), ruleid)
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

udp_map["acrule_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud, p = ins.conn, ins.ud, arg
		local rulename = p.rulename

		--check ipids tmids protoids existance
		local src_ipgids, dest_ipgids, tmgrp_ids, proto_ids = p.src_ipgids, p.dest_ipgids, p.tmgrp_ids, p.proto_ids
		local sipids = js.decode(src_ipgids)
		local n = #sipids
		local in_part = table.concat(sipids, ", ")
		local sql = string.format("select ipgid from ipgroup where ipgid in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid src_ipgroup"
		end
		local dipids = js.decode(dest_ipgids)
		local n = #dipids
		local in_part = table.concat(dipids, ", ")
		local sql = string.format("select ipgid from ipgroup where ipgid in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid dest_ipgroup"
		end

		local pids = js.decode(proto_ids)
		local n = #pids
		local in_part = table.concat(pids, ", ")
		local sql = string.format("select proto_id from acproto where proto_id in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid protocol"
		end

		local tids = js.decode(tmgrp_ids)
		local n = #tids
		local in_part = table.concat(tids, ", ")
		local sql = string.format("select tmgid from timegroup where tmgid in (%s)", in_part)
		local rs, e = conn:select(sql)
		if not rs then
			return nil, e
		end
		if #rs < n then
			return nil, "invalid timegroup"
		end

		--check rulename existance
		local rs, e = conn:select("select * from acrule") 			assert(rs, e)
		local ruleids, priorities = {}, {}
		for _, r in ipairs(rs) do
			local name = r.rulename
			local _ = table.insert(ruleids, r.ruleid), table.insert(priorities, r.priority)
			if name == rulename then
				return nil, "exists rulename"
			end
		end
		--get ruleid priority
		local id, e = conn:next_id(ruleids, 16)
		if not id then
			return nil, e
		end

		local priority = 0
		if #priorities > 0 then
			table.sort(priorities)
			priority = priorities[#priorities] + 1
		end

		--insert new acrule
		p.ruleid, p.priority = id, priority
		local sql = string.format("insert into acrule %s values %s", conn:insert_format(p))
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

udp_map["acrule_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local ruleids = js.decode(arg.ruleids)

		local in_part = table.concat(ruleids, ", ")

		local sql = string.format("delete from acrule where ruleid in (%s)", in_part)
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

udp_map["acrule_adjust"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local ruleids = js.decode(arg.ruleids)
		local ruleid1, ruleid2 = ruleids[1], ruleids[2]

		local in_part = table.concat(ruleids, ", ")

		local sql = string.format("select ruleid, priority from acrule where ruleid in (%s)", in_part)
		local rs, e = conn:select(sql)  assert(rs, e)
		if not rs then
			return nil, e
		end

		if #rs ~= 2 then
			return nil, "invalid ruleids"
		end

		rs[1].priority, rs[2].priority = rs[2].priority, rs[1].priority
		local arr, e = conn:transaction(function()
			local arr = {}
			for _, r in ipairs(rs) do
				local sql = string.format("update acrule set priority='%s' where ruleid='%s'", r.priority, r.ruleid)
				local r, e = conn:execute(sql)
				if not r then
					return nil, e
				end
				table.insert(arr, sql)
			end
				print("arr in is  ", js.encode(arr))
			return arr
		end)
				print("arr out is   ", js.encode(arr))
		if not arr then
			print("arr nil")
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
