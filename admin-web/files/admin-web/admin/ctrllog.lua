--[[
	author:tgb
	date:2016-08-25 1.0 add basic code
]]

local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local cmd_map = {}
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local function query_u(p, timeout)	return query.query_u("127.0.0.1", 60000, p, timeout) end

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
    return (not r) and reply_e(e) or ngx.say(r)
end

function cmd_map.ctrllog_get()
    local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

    return query_common(m, "ctrllog_get")
end

return {run = run}
