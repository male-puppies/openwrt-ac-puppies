-- author: gx

local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern, mac_pattern = adminlib.ip_pattern, adminlib.mac_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout)	end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd)	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd)					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local valid_fields = {proto_id = 1, proto_name = 1, proto_desc = 1, enable = 1, pid = 1, node_type = 1, ext = 1}
function cmd_map.acproto_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(adminlib.search_opt(m, {order = valid_fields, search = valid_fields}))
	local sql = string.format("select * from acproto %s %s %s", cond.like and string.format("where %s", cond.like) or "", cond.order, cond.limit)
	local rs, e = mysql_select(sql)
	return rs and reply(rs) or reply_e(e)
end

return {run = run}