local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")

local udp_map = {}
local myconn, udpsrv, mqtt, dbrpc

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

local reply_obj = {status = 0, data = 0}
local function reply(ip, port, r, d)
	reply_obj.status, reply_obj.data = r, d
	udpsrv:send(ip, port, js.encode(reply_obj))
end

local function dispatch_udp(cmd, ip, port)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
end

udp_map["zone_get"] = function(p, ip, port)
	print(111, p, js.encode(p))
	reply(ip, port, 0, p)
end

udp_map["zone_set"] = function(p, ip, port)
	reply(ip, port, 0, p)
end

udp_map["zone_add"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn = ins.conn
		return conn:protect(function()
			local r, e = conn:select("select * from kv") 		assert(r, e) 
			return r
		end)
	]]

	local r, e = dbrpc:fetch("cfgmgr_zone_add", code)
	if e then io.stderr:write("error ", e, "\n") os.exit(-1) end 	
	log.debug("%s", js.encode({r, e}))
	reply(ip, port, 0, {r, e})
end

udp_map["zone_del"] = function(p, ip, port)
	reply(ip, port, 0, p)
end

return {init = init, dispatch_udp = dispatch_udp}
