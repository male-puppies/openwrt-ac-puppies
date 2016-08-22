local js = require("cjson.safe")
local log = require("common.log")
local rds = require("common.rds")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post

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

local function mwan_validate(s)
	local m = js.decode(s)
	if not m then
		return nil, "invalid param 1"
	end

	return m
end

function cmd_map.mwan_get()
	local m, e = validate_get({})
	if not m then return reply_e(e) end
	return query_common(m, "mwan_get")
end
function cmd_map.mwan_set()
	ngx.req.read_body()
	local p = ngx.req.get_post_args()
	local arg = p.arg
	local cfg, e = mwan_validate(arg)
	if not cfg then
		return reply_e(e)
	end
	return query_common({cmd = "mwan_set", mwan = cfg}, "mwan_set")
end

return {run = run}
