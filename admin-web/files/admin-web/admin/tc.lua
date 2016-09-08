-- cmq

local js = require("cjson.safe")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern = adminlib.ip_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local validate_post_get_all = adminlib.validate_post_get_all
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_Name 	= gen_validate_str(1, 32)
local v_Names 	= gen_validate_str(2, 1024)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 	                end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

function cmd_map.tc_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	return query_common(m, "tc_get")
end

local v_Enabled = gen_validate_num(0, 1)

local function v_Ip(v)
	return string.match(v, "%d+%.%d+%.%d+%.%d+-%d+%.%d+%.%d+%.%d+$") or string.match(v, "%d+%.%d+%.%d+%.%d+$")
end

local function v_Bytes(v)
	return string.match(v, "^(%d+[MK]Bytes)$")
end

local function v_bps(v)
	return string.match(v, "^(%d+Mbps)$")
end

local function tc_update_common(cmd, ext)
	local check_map = {
		Enabled			=	v_Enabled,
		Ip				=	v_Ip,
		Name			=	v_Name,
		SharedDownload	=	v_Bytes,
		SharedUpload	=	v_Bytes,
		PerIpDownload	=	v_Bytes,
		PerIpUpload		=	v_Bytes,
	}

	for k, v in pairs(ext or {}) do
		check_map[k] = v
	end

	local m, e = validate_post(check_map)
	if not m then
		return reply_e(e)
	end

	return query_common({rule = m}, cmd)
end

function cmd_map.tc_gset()
	local check_map = {
		GlobalSharedDownload = v_bps,
		GlobalSharedUpload = v_bps,
	}

	local m, e = validate_post(check_map)
	if not m then
		return reply_e(e)
	end

	return query_common(m, "tc_gset")
end

function cmd_map.tc_set()
	return tc_update_common("tc_set")
end

function cmd_map.tc_add()
	return tc_update_common("tc_add")
end

function cmd_map.tc_del()
	local m, e = validate_post({Names = v_Names})

	if not m then
		return reply_e(e)
	end

	local Names = js.decode(m.Names)
	if not (Names and type(Names) == "table")  then
		return reply_e("invalid Names")
	end

	m.Names = Names

	return query_common(m, "tc_del")
end

return {run = run}
