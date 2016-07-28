local js = require("cjson.safe")
local log = require("common.log")
local authlib = require("admin.authlib")
local rds = require("common.rds")
local mysql = require("common.mysql")
local query = require("common.query")

local r1 = log.real1
local reply_e, reply = authlib.reply_e, authlib.reply
local validate_get, validate_post = authlib.validate_get, authlib.validate_post
local gen_validate_num, gen_validate_str = authlib.gen_validate_num, authlib.gen_validate_str

local validate_type = gen_validate_num(2, 3)
local validate_zid = gen_validate_num(0, 255) 
local validate_zids = gen_validate_str(2, 256)
local validate_des = gen_validate_str(1, 32, true)
local validate_name = gen_validate_str(1, 32, true)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end 

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	if not r then 
		return reply_e(e)
	end
	ngx.say(r)
end

function cmd_map.iface_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then return reply_e(e) end
	return query_common(m, "iface_get")
end

log.setlevel("1,2,3")

function cmd_map.iface_add()
	local m, e = validate_post({
		des = validate_des,
		type = validate_type,
		name = validate_name,
	})

	if not m then 
		return reply_e(e)
	end

	return query_common(m, "iface_add")
end

function cmd_map.iface_set()
	local m, e = validate_post({
		zid = validate_zid,
		des = validate_des,
		type = validate_type,
		name = validate_name,
	})

	if not m then 
		return reply_e(e)
	end

	return query_common(m, "iface_set")
end

function cmd_map.iface_del()
	local m, e = validate_post({zids = validate_zids})
	if not m then 
		return reply_e(e)
	end
	
	local s, zids = m.zids .. ",", {}
	for zid in s:gmatch("(%d-),") do 
		local v = validate_zid(tonumber(zid))
		if not v then 
			return reply_e("invalid zids " .. m.zids)
		end 
		table.insert(zids, v)
	end

	return query_common({zids = zids}, "iface_del")
end

return {run = run}

