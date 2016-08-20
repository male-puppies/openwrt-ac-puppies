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

udp_map["authrule_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg
		local rid, rulename = p.rid, p.rulename

		-- check zid, ipgid existance
		local zid, ipgid = p.zid, p.ipgid
		local sql = string.format("select sum(count) as sum from (select 1,count(*) as count from ipgroup where ipgid=%s union select 2, count(*) as count from zone where zid=%s)t;", ipgid, zid)
		local rs, e = conn:select(sql) 		assert(rs, e)
		if tonumber(rs[1].sum) ~= 2 then 
			return nil, "invalid reference"
		end
	
		-- check rid exists and dup rulename
		local sql = string.format("select * from authrule where rid=%s or rulename='%s'", rid, conn:escape(rulename))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].rid == rid) then 
			return nil, "invalid rid or dup rulename"
		end
	
		-- check change 
		p.rid = nil
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
		
		-- update authrule
		local sql = string.format("update authrule set %s where rid=%s", conn:update_format(p), rid)
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end 
		
		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_authrule_set", code, p)
	-- local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["authrule_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg
		local rulename = p.rulename
		
		-- check zid/ipgid existance
		local zid, ipgid = p.zid, p.ipgid
		local sql = string.format("select sum(count) as sum from (select 1,count(*) as count from ipgroup where ipgid=%s union select 2, count(*) as count from zone where zid=%s)t;", ipgid, zid)
		local rs, e = conn:select(sql) 		assert(rs, e)
		if tonumber(rs[1].sum) ~= 2 then 
			return nil, "invalid reference"
		end

		-- check dup rulename
		local rs, e = conn:select("select * from authrule") 			assert(rs, e)
		local ids, priorities = {}, {}
		for _, r in ipairs(rs) do 
			local name = r.rulename
			local _ = table.insert(ids, r.rid), table.insert(priorities, r.priority)
			if name == rulename then 
				return nil, "exists rulename"
			end
		end

		-- get next rid 
		local id, e = conn:next_id(ids, 16)
		if not id then 
			return nil, e
		end

		local priority = 0
		if #priorities > 0 then 
			table.sort(priorities)
			priority = priorities[#priorities] + 1
		end 

		-- insert new authrule
		p.rid, p.priority = id, priority
		local sql = string.format("insert into authrule %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end 

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_authrule_add", code, p)
	-- local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["authrule_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local rids = js.decode(arg.rids)

		local in_part = table.concat(rids, ",")
		
		local sql = string.format("delete from authrule where rid in (%s)", in_part)
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_authrule_del", code, p)
	-- local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["authrule_adjust"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local rids = js.decode(arg.rids)
		local rid1, rid2 = rids[1], rids[2]

		local in_part = table.concat(rids, ",")
		
		local sql = string.format("select rid, priority from authrule where rid in (%s)", in_part)
		local rs, e = conn:select(sql) 	assert(rs, e)
		if not rs then 
			return nil, e 
		end

		if #rs ~= 2 then 
			return nil, "invalid rids"
		end 

		rs[1].priority, rs[2].priority = rs[2].priority, rs[1].priority
		local arr, e = conn:transaction(function()
			local arr = {}
			for _, r in ipairs(rs) do 
				local sql = string.format("update authrule set priority='%s' where rid='%s'", r.priority, r.rid)
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
	local r, e = dbrpc:fetch("cfgmgr_authrule_adjust", code, p)
	--local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
