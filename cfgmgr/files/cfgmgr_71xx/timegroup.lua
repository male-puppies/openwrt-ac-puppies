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

udp_map["timegroup_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js   = require("cjson.safe")
		local conn, ud, p = ins.conn, ins.ud, arg
		
		-- check dup timegrpname
		local sql = string.format("select * from timegroup")
		local rs, e = conn:select(sql) 			assert(rs, e)

		local ids, tmgrpname = {}, p.tmgrpname
		for _, r in ipairs(rs) do 
			local id, name = r.tmgid, r.tmgrpname
			table.insert(ids, id)
			if name == tmgrpname then 
				return nil, "exists tmgrpname"
			end
		end

		-- get next rid 
		local id, e = conn:next_id(ids, 256)
		print(id, e)
		if not id then 
			return nil, e
		end

		-- insert 
		p.tmgid = id
		local sql = string.format("insert into timegroup %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end 

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_timegroup_add", code, p)
	-- local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["timegroup_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local tmgids = js.decode(arg.tmgids)

		-- TODO check more related tables
		local in_part = table.concat(tmgids, ",")
		local sql = string.format("select tmgrp_ids from acrule")
		local rs, e = conn:select(sql)
		 if not rs then 
		 	return nil, e
		 end

		 -- judge cited id 判断被引用的id号
		local refer_tmgids = {}
		for _, tmgrp in ipairs(rs) do
			local detail = js.decode(tmgrp.tmgrp_ids)  assert(detail)
			for _, tmgrpid in ipairs(detail) do
				table.insert(refer_tmgids, tmgrpid)
			end
		end
		local _ = #refer_tmgids > 0 and  table.sort(refer_tmgids)
		for _, tmgrpid in ipairs(tmgids) do
			for _, refer_tmgid in ipairs(refer_tmgids) do
				if refer_tmgid == tmgrpid then
					return nil, "referenced"
				end
			end
		end

		local sql = string.format("delete from timegroup where tmgid in (%s)", in_part)
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end

		ud:save_log(sql, true)
		return true
	]]


	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_timegroup_del", code, p)
	--local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end


udp_map["timegroup_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check tmgid exists and dup tmgrpname
		local tmgid, tmgrpname, tmgrpdesc, days, tmlist = arg.tmgid, arg.tmgrpname, arg.tmgrpdesc, arg.days, arg.tmlist
		local sql = string.format("select * from timegroup where tmgid=%s or tmgrpname='%s'", tmgid, conn:escape(tmgrpname))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].tmgid == tmgid) then 
			return nil, "invalid tmgid or dup tmgrpname"
		end

		-- check config change
		p.tmgid = nil
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
		local sql = string.format("update timegroup set %s where tmgid=%s", conn:update_format(p), tmgid)
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end 

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_timegroup_set", code, p)
	-- local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp =  cfglib.gen_dispatch_udp(udp_map)}
