-- author: yjs

local js = require("cjson.safe")
local log = require("common.log")
local rds = require("common.rds")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local ip_pattern = adminlib.ip_pattern
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_gid	 = gen_validate_num(0, 63)
local v_pid	 = gen_validate_num(-1, 63)
local v_gids = gen_validate_str(1, 256)
local v_desc = gen_validate_str(1, 64, true)
local v_name = gen_validate_str(1, 32, true)


local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local acgroup_fields = {gid = 1, groupname = 1, groupdesc = 1, pid = 1}
function cmd_map.acgroup_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(adminlib.search_opt(m, {order = acgroup_fields, search = acgroup_fields}))
	local sql = string.format("select * from acgroup %s %s %s", cond.like and string.format("where %s", cond.like) or "", cond.order, cond.limit)
	local r, e = mysql_select(sql)
	return r and reply(r) or reply_e(e)
end

function cmd_map.acgroup_set()
	local m, e = validate_post({groupname = v_name, groupdesc = v_desc, pid = v_pid, gid = v_gid})
	if not m then
		return reply_e(e)
	end

	local gid = m.gid
	if gid == 63 then
		return reply_e("cannot modify default")
	end

	return query_common(m, "acgroup_set")
end

function cmd_map.acgroup_add()
	local m, e = validate_post({groupname = v_name, groupdesc = v_desc, pid = v_pid})

	if not m then
		return reply_e(e)
	end

	return query_common(m, "acgroup_add")
end

function cmd_map.acgroup_del()
	local m, e = validate_post({gids = v_gids})

	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.gids)
	if not ids then
		return reply_e("invalid gids")
	end

	for _, id in ipairs(ids) do
		local tid = tonumber(id)
		if not (tid and tid >= 0 and tid < 63) then
			return reply_e("invalid gids")
		end
	end

	return query_common(m, "acgroup_del")
end

return {run = run}
