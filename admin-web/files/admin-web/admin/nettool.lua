-- yjs

local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local reply_e = adminlib.reply_e
local validate_get = adminlib.validate_get
local gen_validate_str = adminlib.gen_validate_str

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

	local timeout_map = {ping = 30, traceroute = 60, nslookup = 30}
	local timeout = timeout_map[m.tool]
	if not timeout then
		return reply_e("invalid tool")
	end

	m.timeout = timeout
	return query_common(m, cmd, (timeout + 2) * 1000)
end

return {run = run}