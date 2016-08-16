local fp = require("fp")
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

udp_map["kv_set"] = function(p, ip, port)
	local code = [[
		local fp = require("fp")
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, fp.map(arg, function(_, v) return tostring(v) end)

		-- 选择数据库中keys对应的值
		local karr = fp.reduce2(p, function(t, k) return rawset(t, #t + 1, string.format("'%s'", k)) end, {})
		local sql = string.format("select * from kv where k in (%s)", table.concat(karr, ","))
		local rs, e = conn:select(sql) 	assert(rs, e)
		local tmap = fp.reduce2(rs, function(t, _, r) return rawset(t, r.k, tostring(r.v)) end, {})

		-- 对比提交的数据是否有变化
		if fp.same(p, tmap) then
			return true
		end

		-- 提交数据
		return conn:transaction(function()
			local arr = {}
			for k, v in pairs(diff) do
				local sql = string.format("update kv set v='%s' where k='%s'", conn:escape(v), conn:escape(k))
				local r, e = conn:execute(sql)
				if not r then
					return nil, e
				end
				table.insert(arr, sql)
			end

			-- 写数据库日志
			ud:save_log(arr, true)
			return true
		end)
	]]

	p.cmd = nil
	-- local r, e = dbrpc:fetch("cfgmgr_ipgroup_set", code, p)
	local r, e = dbrpc:once(code, p)
	local _ = r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
