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

udp_map["ipgroup_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud = ins.conn, ins.ud
		local ipgid, ipgrpname, ipgrpdesc, ranges = arg.ipgid, arg.ipgrpname, arg.ipgrpdesc, arg.ranges
		local sql = string.format("select * from ipgroup where ipgid=%s or ipgrpname='%s'", ipgid, conn:escape(ipgrpname))
		local rs, e = conn:select(sql) 			assert(rs, e)
		if #rs == 0 then 
			return nil, "miss ipgid"
		end

		if #rs > 1 then 
			return nil, "exists ipgrpname"
		end

		local r = rs[1] 
		if ipgrpname == r.ipgrpname and ipgrpdesc == r.ipgrpdesc and ranges == r.ranges then 
			print("nothing change")
			return true
		end 

		local sql = string.format("update ipgroup set ipgrpname='%s',ipgrpdesc='%s',ranges='%s' where ipgid='%s'", conn:escape(ipgrpname), conn:escape(ipgrpdesc), conn:escape(ranges), ipgid)
		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end 

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_ipgroup_set", code, p)
	if not r then 
		return reply(ip, port, 1, e)
	end

	reply(ip, port, 0, r)
end

udp_map["ipgroup_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud = ins.conn, ins.ud
		local ipgrpname, ipgrpdesc, ranges = arg.ipgrpname, arg.ipgrpdesc, arg.ranges
		local sql = string.format("select * from ipgroup order by ipgid")
		local rs, e = conn:select(sql) 			assert(rs, e)

		local ids = {}
		for _, r in ipairs(rs) do 
			local id, name = r.ipgid, r.ipgrpname
			local _ = id == 63 or table.insert(ids, id)
			if name == ipgrpname then 
				return nil, "exists ipgrpname"
			end
		end

		if #ids == 63 then 
			return nil, "ipgroup full"
		end

		local id = (#ids == 0 and -1 or ids[#ids]) + 1
		if id >= 63 then
			for k, v in ipairs(ids) do 
				if k ~= v then
					id = k 
					break 
				end 
			end 
		end 
		
		local sql = string.format("insert into ipgroup (ipgid, ipgrpname, ipgrpdesc, ranges) values ('%s', '%s', '%s', '%s')", id, conn:escape(ipgrpname), conn:escape(ipgrpdesc), conn:escape(ranges))

		local r, e = conn:execute(sql)
		if not r then 
			return nil, e 
		end 

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_ipgroup_add", code, p)
	local _ = r and reply(ip, port, 0, "ok") or reply(ip, port, 1, e)
end

udp_map["ipgroup_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local ipgids = js.decode(arg.ipgids)

		-- TODO check more related tables
		local in_part = table.concat(ipgids, ",")
		local sql = string.format("select sum(count) as count from (select 1,count(*) as count from authrule where ipgid in (%s) union select 2,count(*) as count from authrule where ipgid in (%s)) t;", in_part, in_part)

		local rs, e = conn:select(sql)
		if not rs then 
			return nil, e
		end

		local count = tonumber(rs[1].count)
		if count ~= 0 then 
			return nil, "ipgids referenced"
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
	local r, e = dbrpc:fetch("cfgmgr_ipgroup_del", code, p)
	local _ = r and reply(ip, port, 0, "ok") or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = dispatch_udp}
