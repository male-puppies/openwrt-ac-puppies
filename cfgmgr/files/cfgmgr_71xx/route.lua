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

udp_map["route_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check rid exists
		local rid = arg.rid
		local sql = string.format("select * from route where rid=%s", rid)
		local rs, e = conn:select(sql) 			assert(rs, e)
		if not (#rs == 1 and rs[1].rid == rid) then
			return nil, "invalid rid"
		end

		-- check config change
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
		-- update route
		local sql = string.format("update route set %s where rid=%s", conn:update_format(p), rid)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_route_set", code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["route_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		-- check dup rid
		local rs, e = conn:select("select * from route") 			assert(rs, e)
		local ids = {}
		for _, r in ipairs(rs) do
			table.insert(ids, r.rid)
		end

		-- get next rid
		local id, e = conn:next_id(ids, 65536)
		if not id then
			return nil, e
		end

		-- insert new route
		p.rid = id
		local sql = string.format("insert into route %s values %s", conn:insert_format(p))
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_route_add", code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

udp_map["route_del"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local js = require("cjson.safe")
		local conn, ud = ins.conn, ins.ud
		local rids = js.decode(arg.rids)

		local in_part = table.concat(rids, ",")

		-- check rids valid
		local rs, e = conn:select("select * from route") 			assert(rs, e)
		local ids = {}
		for _, r in ipairs(rs) do
			local _ = table.insert(ids, r.rid, r.rid)
		end

		for _, nv in pairs(rids) do
			if not ids[nv] then
				return nil, "invalid rid"
			end
		end

		-- delete one or more route
		local sql = string.format("delete from route where rid in (%s)", in_part)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_route_del", code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
