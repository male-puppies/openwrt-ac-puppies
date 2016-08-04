local ski = require("ski")
local log = require("log")
local code = require("code")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local common = require("common")

local read, save_safe, arr2map = common.read, common.save_safe, common.arr2map

local udp_map = {}
local udpsrv, mqtt, dbrpc

local function init(u, p)
	udpsrv, mqtt = u, p
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

local reply_obj = {status = 0, data = 0}
local function reply(ip, port, r, d)
	reply_obj.status, reply_obj.data = r, d
	udpsrv:send(ip, port, js.encode(reply_obj))
	return true
end

local function dispatch_udp(cmd, ip, port)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
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
	local r, e = dbrpc:fetch("cfgmgr_ipgroup_set", code, p)
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
		local ids = {}
		for _, r in ipairs(rs) do 
			local id, name = r.rid, r.rulename
			table.insert(ids, id)
			if name == rulename then 
				return nil, "exists rulename"
			end
		end

		-- get next rid 
		local id, e = conn:next_id(ids, 16)
		if not id then 
			return nil, e
		end

		-- insert new authrule
		p.rid = id
		local sql = string.format("insert into authrule %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end 

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_ipgroup_add", code, p)
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
	local r, e = dbrpc:fetch("cfgmgr_ipgroup_del", code, p)
	-- local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = dispatch_udp}
