local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50004, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd, timeout)
	m.cmd = cmd
	local r, e = query_u(m, timeout)
	return (not r) and reply_e(e) or ngx.say(r)
end

function cmd_map.nettool_get(cmd)
	local m, e = validate_get({tool = gen_validate_str(1, 256), host = gen_validate_str(1, 256)})
	if not m then
		return reply_e(e)
	end

	local timeout_map = {ping = 30000, traceroute = 60000, nslookup = 30000}
	local timeout = timeout_map[m.tool]
	if not timeout then
		return reply_e("invalid tool")
	end

	m.timeout = timeout
	return query_common(m, cmd, timeout)
end

return {run = run}