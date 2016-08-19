local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local nos = require("luanos")
local js = require("cjson.safe")
local authlib = require("authlib")

local get_authtype = cfg.get_authtype
local get_ip_mac, get_status, get_rule_id = nos.user_get_ip_mac, nos.user_get_status, nos.user_get_rule_id
local set_status = nos.user_set_status
local get_module = cfg.get_module

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

--[[
ntrackd发送来的内核上报道心跳
@param p : {"cmd":"keepalive","magic":1510,"uid":754}
]]
udp_map["keepalive"] = function(p)
	local uid, magic = p.uid, p.magic
	local ukey = string.format("%s_%s", uid, magic)

	local mod = get_module(ukey)
	if not mod then
		-- TODO offline 先放到cache，一定次数后，还找不到就下线
		-- set_status(uid, magic, 0)
		-- log.error("miss ukey %s. force offline", ukey)
		return
	end

	-- 查询参数rid，ip，mac
	local rid = get_rule_id(uid, magic)
	local ip, mac = get_ip_mac(uid, magic)
	if not (rid and ip) then
		return
	end

	p.ip, p.mac, p.rid, p.cmd, p.ukey = ip, mac, rid, mod .. "_keepalive", ukey
	dispatch_keepalive(p)
end

return {init = init, set_kernel_cb = set_kernel_cb, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

