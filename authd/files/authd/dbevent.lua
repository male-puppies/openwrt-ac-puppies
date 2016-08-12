local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local js = require("cjson.safe")
local authlib = require("authlib")

local tcp_map = {}
local mqtt, udpsrv
local function init(u, p)
	mqtt, udpsrv = p, u
end

tcp_map["dbsync"] = function(p)
	local authrule = p.authrule
	if not authrule then 
		return 
	end

	log.info("authrule change, reload. %s", js.encode(authrule))
	cfg.clear_authtype()
end

return {init = init, dispatch_tcp = authlib.gen_dispatch_udp(tcp_map)}

 