local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local nos = require("luanos") 
local js = require("cjson.safe")


local get_authtype = cfg.get_authtype
local get_ip_mac, get_status, get_rule_id = nos.user_get_ip_mac, nos.user_get_status, nos.user_get_rule_id
local dispatch_keepalive = function() end 

local udp_map = {}
local udpsrv, mqtt
local keepalive_trigger

local function init(u, p)
	udpsrv, mqtt =u, p
end

local function set_kernel_cb(cb)
	dispatch_keepalive = cb 
end 

local function dispatch_udp(cmd, ip, port)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
end

udp_map["keepalive"] = function(p)
	local uid, magic = p.uid, p.magic
	local rid = get_rule_id(uid, magic) 	assert(rid)
	local ip, mac = get_ip_mac(uid, magic) 	assert(ip)

	local authtype = get_authtype(rid) 
	p.ip, p.mac, p.rid, p.cmd, p.ukey = ip, mac, rid, authtype .. "_keepalive", string.format("%s_%s", uid, magic)
	dispatch_keepalive(p)
end

return {init = init, dispatch_udp = dispatch_udp, set_kernel_cb = set_kernel_cb}

