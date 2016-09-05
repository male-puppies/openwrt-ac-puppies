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

udp_map["acset_set"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg
		local js = require("cjson.safe")

		for _, acset in pairs(p) do
			local setid, setname, setclass, settype, action = acset.setid, acset.setname, acset.class, acset.settype, acset.action
		local sql = string.format("select * from acset where setname = '%s'", conn:escape(setname))
		local r, e = conn:select(sql)	assert(r, e)
		if not (#r == 1 and r[1].setid == setid and r[1].setname == setname ) then
			return nil, "invalid setid or setname"
		end

		-- update
			if #acset.content ~= 0 then
				acset.content = js.encode(acset.content)
			else
				acset.content = "[]"
			end
			local sql = string.format("update acset set %s where setid = %s", conn:update_format(acset), setid)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		end
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:fetch("cfgmgr_acset_set", code, p)
	--local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}