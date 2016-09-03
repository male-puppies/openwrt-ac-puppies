-- author: yjs

local fp 		= require("fp")
local ski 		= require("ski")
local log 		= require("log")
local js 		= require("cjson.safe")
local rpccli	= require("rpccli")
local authlib	= require("authlib")
local simplesql	= require("simplesql")

local udp_map = {}
local simple, udpsrv, mqtt

local function init(u, p)
	udpsrv, mqtt = u, p

	local dbrpc  = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)
end

-- {"ukeys":"[\"4889_189738\"]","cmd":"online_del"}
udp_map["online_del"] = function(p, ip, port)
	local s = p.ukeys

	log.info("force offline %s", s)

	authlib.offline_ukeys(simple, js.decode(s))
	udpsrv:send(ip, port, js.encode({status = 0, data = "ok"}))
end

return {init = init, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}