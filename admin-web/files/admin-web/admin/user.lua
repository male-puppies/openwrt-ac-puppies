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

local v_username	= gen_validate_str(1, 64, true)
local v_password	= gen_validate_str(1, 64, true)
local v_userdesc 	= gen_validate_str(1, 64)
local v_enable 		= gen_validate_num(0, 1)
local v_multi 		= gen_validate_num(0, 1)
local v_expire 		= gen_validate_str(0, 19)
local v_register	= gen_validate_str(0, 19)
local v_gid 		= gen_validate_num(0, 63)
local v_uid 		= gen_validate_num(0, 9999999)
local v_uids 		= gen_validate_str(2, 256)
local v_bindmac 	= gen_validate_str(0, 32)
local v_bindip 		= gen_validate_str(0, 32)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local ipgrp_fields = {ipgid = 1, ipgrpname = 1, ipgrpdesc = 1, ranges = 1}
function cmd_map.user_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(adminlib.search_opt(m, {order = ipgrp_fields, search = ipgrp_fields}))
	local sql = string.format("select * from user %s %s %s", cond.like and string.format("where %s", cond.like) or "", cond.order, cond.limit)

	local r, e = mysql_select(sql)
	return r and reply(r) or reply_e(e)
end

function cmd_map.user_set()
	local m, e = validate_post({
		username 	= v_username,
		password 	= v_password,
		userdesc	= v_userdesc,
		enable		= v_enable,
		expire		= v_expire,
		gid 		= v_gid,
		bindmac 	= v_bindmac,
		bindip 		= v_bindip,
		uid 		= v_uid,
		register 	= v_register,
		multi 		= v_multi,
	})

	if not m then
		return reply_e(e)
	end

	local expire, register = m.expire, m.register
	if expire ~= "" and not expire:find("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$") then
		return reply_e("invalid expire")
	end

	if register ~= "" and not register:find("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$") then
		return reply_e("invalid register")
	end

	local bindmac, bindip = m.bindmac, m.bindip
	if bindip ~= "" and not bindip:find(ip_pattern) then
		return reply_e("invalid bindip")
	end

	if bindmac ~= "" and not bindmac:find(mac_pattern) then
		return reply_e("invalid bindmac")
	end

	return query_common(m, "user_set")
end

function cmd_map.user_add()
	local m, e = validate_post({
		username 	= v_username,
		password 	= v_password,
		userdesc	= v_userdesc,
		enable		= v_enable,
		expire		= v_expire,
		gid 		= v_gid,
		bindmac 	= v_bindmac,
		bindip 		= v_bindip,
		multi 		= v_multi,
	})

	if not m then
		return reply_e(e)
	end

	local expire = m.expire
	if expire ~= "" and not expire:find("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$") then
		return reply_e("invalid expire")
	end

	local bindmac, bindip = m.bindmac, m.bindip
	if bindip ~= "" and not bindip:find(ip_pattern) then
		return reply_e("invalid bindip")
	end

	if bindmac ~= "" and not bindmac:find(mac_pattern) then
		return reply_e("invalid bindmac")
	end

	return query_common(m, "user_add")
end

function cmd_map.user_del()
	local m, e = validate_post({uids = v_uids})
	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.uids)
	if not ids then
		return reply_e("invalid uids")
	end

	for _, id in ipairs(ids) do
		local tid = tonumber(id)
		if not (tid and tid >= 0 ) then
			return reply_e("invalid uids")
		end
	end

	return query_common(m, "user_del")
end

return {run = run}
