local js = require("cjson.safe")
local log = require("common.log")
local adminlib = require("admin.adminlib")
local rds = require("common.rds")
local mysql = require("common.mysql")
local query = require("common.query")

local r1 = log.real1
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local validate_zid = gen_validate_num(0, 255) 
local validate_zids = gen_validate_str(1, 256)
local validate_zonetype = gen_validate_num(2, 3)
local validate_zonedesc = gen_validate_str(1, 32)
local validate_zonename = gen_validate_str(1, 32, true)

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

function cmd_map.zone_get()
	local m, e = validate_get({page = 1, count = 1})

	if not m then 
		return reply_e(e)
	end

	return query_common(m, "zone_get")
end
log.setlevel("1,2,3")

function cmd_map.zone_add()
	local m, e = validate_post({
		zonedesc = validate_zonedesc,
		zonetype = validate_zonetype,
		zonename = validate_zonename,
	})

	if not m then 
		return reply_e(e)
	end

	return query_common(m, "zone_add")
end

function cmd_map.zone_set()
	local m, e = validate_post({
		zid = validate_zid,
		zonedesc = validate_zonedesc,
		zonetype = validate_zonetype,
		zonename = validate_zonename,
	})

	if not m then
		return reply_e(e)
	end

	if m.zid == 255 then 
		return reply_e("invalid zid")
	end

	return query_common(m, "zone_set")
end

function cmd_map.zone_del()
	local m, e = validate_post({zids = validate_zids})
	if not m then 
		return reply_e(e)
	end
	
	local s, zids = m.zids .. ",", {}
	for zid in s:gmatch("(%d-),") do 
		local v = validate_zid(tonumber(zid)) 
		if not (v and v ~= 255) then 
			return reply_e("invalid zids " .. m.zids)
		end 
		table.insert(zids, v)
	end

	return query_common({zids = zids}, "zone_del")
end

return {run = run}

