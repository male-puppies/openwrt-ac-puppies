-- author: yjs

local js = require("cjson.safe")
local log = require("common.log")
local rds = require("common.rds")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern, mac_pattern = adminlib.ip_pattern, adminlib.mac_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50002, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local online_fields = {ukey = 1, username = 1}
function cmd_map.online_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(adminlib.search_opt(m, {order = online_fields, search = online_fields}))
	local sql = string.format("select * from online %s %s %s", cond.like and string.format("where %s", cond.like) or "", cond.order, cond.limit)
	local r, e = mysql_select(sql)
	return r and reply(r) or reply_e(e)
end

function cmd_map.online_del()
	local m, e = validate_post({ukeys = gen_validate_str(2, 256)})
	if not m then
		return reply_e(e)
	end

	local ukeys = js.decode(m.ukeys)
	if not ukeys then
		return reply_e("invalid ukeys")
	end
	ngx.log(ngx.ERR, m.ukeys)
	for _, ukey in ipairs(ukeys) do
		if not (type(ukey) == "string" and ukey:find("^%d+_%d+$")) then
			return reply_e("invalid ukeys")
		end
	end

	return query_common(m, "online_del")
end

return {run = run}
