local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local nos = require("luanos") 
local js = require("cjson.safe")
local authlib = require("authlib")


local get_authtype = cfg.get_authtype
local get_ip_mac, get_status, get_rule_id = nos.user_get_ip_mac, nos.user_get_status, nos.user_get_rule_id
local dispatch_keepalive = function() end 

local udp_map = {}
local udpsrv, mqtt
local keepalive_trigger

local function init(u, p)
	udpsrv, mqtt = u, p
end

local function set_kernel_cb(cb)
	dispatch_keepalive = cb 
end 

udp_map["keepalive"] = function(p)
	local uid, magic = p.uid, p.magic
	local rid = get_rule_id(uid, magic) 	assert(rid)
	local ip, mac = get_ip_mac(uid, magic) 	assert(ip)
	local authtype = get_authtype(rid)
	if not authtype then 
		print("miss authtype for ", rid)
		return
	end

	p.ip, p.mac, p.rid, p.cmd, p.ukey = ip, mac, rid, authtype .. "_keepalive", string.format("%s_%s", uid, magic)
	dispatch_keepalive(p)
end

return {init = init, set_kernel_cb = set_kernel_cb, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

