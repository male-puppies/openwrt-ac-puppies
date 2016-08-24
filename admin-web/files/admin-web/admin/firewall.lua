local js = require("cjson.safe")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern = adminlib.ip_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local validate_post_get_all = adminlib.validate_post_get_all
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_fwid = gen_validate_num(0, 63)
local v_fwname = gen_validate_str(1, 32, true)
local v_fwdesc = gen_validate_str(0, 32)
local v_enable = gen_validate_num(0, 1)
local v_priority = gen_validate_num(0, 99999)
local v_type = gen_validate_str(0, 8)
local v_action = gen_validate_str(0, 8)
local v_proto = gen_validate_str(0, 8)
local v_zid = gen_validate_num(0, 255)
local v_port = gen_validate_num(0, 65535)
local v_ip = gen_validate_str(0, 24)
local v_fwids = gen_validate_str(2, 256)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 	                end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local function validate_dnat(m)
	local to_dip = m.to_dip
	if not to_dip:find(ip_pattern) then
		return nil, "invalid Internal IP address(to_dip)"
	end
	return true
end

local valid_fields = {fwid = 1, fwname = 1, priority = 1}
function cmd_map.dnat_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(adminlib.search_opt(m, {order = valid_fields, search = valid_fields}))
	local sql = string.format("select * from firewall where firewall.type='redirect' and firewall.action='DNAT' %s %s %s", cond.like and string.format("and %s", cond.like) or "", "order by priority", cond.limit)
	local rs, e = mysql_select(sql)
	return rs and reply(rs) or reply_e(e)
end

local function dnat_update_common(cmd, ext)
	local check_map = {
		fwname			=	v_fwname,
		fwdesc			=	v_fwdesc,
		enable			=	v_enable,
		proto           =	v_proto,
		--type			=	v_type,
		--action			=	v_action,
		from_szid		=	v_zid,
		--from_dzid		=	v_zid,
		--from_sip		=	v_ip,
		--from_sport		=	v_port,
		--from_dip		=	v_ip,
		from_dport		=	v_port,
		to_dzid			=	v_zid,
		--to_sip			=	v_ip,
		--to_sport		=	v_port,
		to_dip			=	v_ip,
		to_dport		=	v_port,
	}

	for k, v in pairs(ext or {}) do
		check_map[k] = v
	end

	local m, e = validate_post_get_all(check_map)
	if not m then
		return reply_e(e)
	end
	local p = e

	local r, e = validate_dnat(m)
	if not r then
		return reply_e(e)
	end

	m.type = "redirect"
	m.action = "DNAT"
	m.from_dzid = 0
	m.from_sip = p.from_sip and v_ip(p.from_sip) or ""
	m.from_sport = p.from_sport and v_port(p.from_sport) or 0
	m.from_dip = p.from_dip and v_ip(p.from_dip) or ""
	m.to_sip = ""
	m.to_sport = 0

	return query_common(m, cmd)
end

function cmd_map.dnat_set()
	return dnat_update_common("firewall_set", {fwid = v_fwid})
end

function cmd_map.dnat_add()
	return dnat_update_common("firewall_add")
end

function cmd_map.dnat_del()
	local m, e = validate_post({fwids = v_fwids})

	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.fwids)
	if not (ids and type(ids) == "table")  then
		return reply_e("invalid fwids")
	end

	for _, id in ipairs(ids) do
		local tid = tonumber(id)
		if not (tid and tid >= 0 and tid < 64) then
			return reply_e("invalid fwids")
		end
	end

	return query_common(m, "firewall_del")
end

function cmd_map.dnat_adjust()
	local m, e = validate_post({fwids = v_fwids})

	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.fwids)
	if not (ids and #ids == 2) then
		return reply_e("invalid fwids")
	end

	for _, id in ipairs(ids) do
		local tid = tonumber(id)
		if not (tid and tid >= 0 and tid < 64) then
			return reply_e("invalid fwids")
		end
	end

	return query_common(m, "firewall_adjust")
end

return {run = run}
