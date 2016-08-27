local js = require("cjson.safe")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern = adminlib.ip_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local validate_post_get_all = adminlib.validate_post_get_all
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_rid = gen_validate_num(0, 65535)

local v_target = gen_validate_str(0, 24)
local v_netmask = gen_validate_str(0, 24)
local v_gateway = gen_validate_str(0, 24)
local v_metric = gen_validate_num(0, 65535)
local v_mtu = gen_validate_num(500, 65500)
local v_iface = gen_validate_str(0, 16)
local v_rids = gen_validate_str(2, 256)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 	                end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

function cmd_map.route_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(m)
	local sql = string.format("select * from route %s", cond.limit)
	local rs, e = mysql_select(sql)
	if not rs then
		return reply_e(e)
	end

	for _, rule in ipairs(rs) do
		rule.metric = rule.metric == 0 and "" or rule.metric
		rule.mtu = rule.mtu == 0 and "" or rule.mtu
		rule.status = 0
	end
	return rs and reply(rs) or reply_e(e)
end

local function route_update_common(cmd, ext)
	local check_map = {
		target			=	v_target,
		netmask			=	v_netmask,
		gateway			=	v_gateway,
		--metric			=	v_metric,
		--mtu				=	v_mtu,
		iface			=	v_iface,
	}

	for k, v in pairs(ext or {}) do
		check_map[k] = v
	end

	local m, e = validate_post_get_all(check_map)
	if not m then
		return reply_e(e)
	end

	local p = e

	m.metric = p.metric and v_metric(p.metric) or 0
	m.mtu = p.mtu and v_metric(p.mtu) or 0

	return query_common(m, cmd)
end

function cmd_map.route_set()
	return route_update_common("route_set", {rid = v_rid})
end

function cmd_map.route_add()
	return route_update_common("route_add")
end

function cmd_map.route_del()
	local m, e = validate_post({rids = v_rids})

	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.rids)
	if not (ids and type(ids) == "table")  then
		return reply_e("invalid rids")
	end

	for _, id in ipairs(ids) do
		local rid = tonumber(id)
		if not (rid and rid >= 0 and rid < 65535) then
			return reply_e("invalid rids")
		end
	end

	return query_common(m, "route_del")
end

return {run = run}
