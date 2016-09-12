-- author: yjs

local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern, mac_pattern = adminlib.ip_pattern, adminlib.mac_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str, gen_validate_name = adminlib.gen_validate_num, adminlib.gen_validate_str, adminlib.gen_validate_name

local v_rid         = gen_validate_num(0, 15)
local v_zid         = gen_validate_num(0, 255)
local v_ipgid       = gen_validate_num(0, 255)
local v_iscloud     = gen_validate_num(0, 1)
local v_enable      = gen_validate_num(0, 1)
local v_rulename    = gen_validate_name(1, 64)
local v_ruledesc    = gen_validate_str(0, 64)
local v_authtype    = gen_validate_str(1, 16, true)
local v_modules     = gen_validate_str(2, 32)
local v_while_ip    = gen_validate_str(2, 10240)
local v_while_mac   = gen_validate_str(2, 10240)
local v_wechat      = gen_validate_str(2, 1024)
local v_sms         = gen_validate_str(2, 1024)
local v_rids        = gen_validate_str(2, 256)
local v_priority    = gen_validate_num(0, 99999)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local valid_fields = {rid = 1, rulename = 1, ruledesc = 1, zonename = 1, ipgrpname = 1, authtype = 1, enable = 1, modules = 1}
function cmd_map.authrule_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(adminlib.search_opt(m, {order = valid_fields, search = valid_fields}))
	local sql = string.format("select * from authrule, zone, ipgroup where authrule.zid=zone.zid and authrule.ipgid=ipgroup.ipgid %s %s %s", cond.like and string.format("and %s", cond.like) or "", "order by priority", cond.limit)
	local rs, e = mysql_select(sql)
	return rs and reply(rs) or reply_e(e)
end

local function validate_authrule(m)
	local authtype, modules = m.authtype, js.decode(m.modules)
	local sms, wechat = js.decode(m.sms), js.decode(m.wechat)
	local white_ip, white_mac = js.decode(m.white_ip), js.decode(m.white_mac)

	if not (modules and sms and wechat and white_ip and white_mac) then
		return nil, "invalid param"
	end

	if not ({auto = 1, web = 1})[authtype] then
		return nil, "invalid authtype"
	end

	local module_map = {wechat = 1, sms = 1, web = 1}
	for _, mod in ipairs(modules) do
		if not module_map[mod] then
			return nil, "invalid module"
		end
	end

	if not (#white_ip <= 16 and #white_mac <= 16) then
		return nil, "too many"
	end

	for _, ip in ipairs(white_ip) do
		if not ip:find(ip_pattern) then
			return nil, "invalid white_ip"
		end
	end

	for _, mac in ipairs(white_mac) do
		if not mac:find(mac_pattern) then
			return nil, "invalid white_mac"
		end
	end

	for k in pairs({}) do
		if not sms[k] then
			return nil, "invalid sms"
		end
	end

	for k in pairs({}) do
		if not wechat[k] then
			return nil, "invalid wechat"
		end
	end

	return true
end

local function authrule_update_common(cmd, ext)
	local check_map = {
		rulename    = v_rulename,
		ruledesc    = v_ruledesc,
		zid         = v_zid,
		ipgid       = v_ipgid,
		authtype    = v_authtype,
		enable      = v_enable,
		modules     = v_modules,
		iscloud     = v_iscloud,
		white_ip    = v_while_ip,
		white_mac   = v_while_mac,
		wechat      = v_wechat,
		sms         = v_sms,
	}

	for k, v in pairs(ext or {}) do
		check_map[k] = v
	end

	local m, e = validate_post(check_map)
	if not m then
		return reply_e(e)
	end

	local r, e = validate_authrule(m)
	if not r then
		return reply_e(e)
	end

	return query_common(m, cmd)
end

function cmd_map.authrule_set()
	return authrule_update_common("authrule_set", {rid = v_rid, priority = v_priority})
end

function cmd_map.authrule_add()
	return authrule_update_common("authrule_add")
end

function cmd_map.authrule_del()
	local m, e = validate_post({rids = v_rids})

	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.rids)
	if not ids then
		return reply_e("invalid rids")
	end

	for _, id in ipairs(ids) do
		local tid = tonumber(id)
		if not (tid and tid >= 0 and tid < 16) then
			return reply_e("invalid rids")
		end
	end

	return query_common(m, "authrule_del")
end

function cmd_map.authrule_adjust()
	local m, e = validate_post({rids = v_rids})

	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.rids)
	if not (ids and #ids == 2) then
		return reply_e("invalid rids")
	end

	for _, id in ipairs(ids) do
		local tid = tonumber(id)
		if not (tid and tid >= 0 and tid < 16) then
			return reply_e("invalid rids")
		end
	end

	return query_common(m, "authrule_adjust")
end

return {run = run}