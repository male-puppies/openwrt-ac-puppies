local fp = require("fp")
local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

function cmd_map.cloud_get()
	local m, e = validate_get({})
	if not m then
		return reply_e(e)
	end

	query_common(m, "cloud_get")
end

function cmd_map.cloud_set()
	local m, e = validate_post({
		ac_host 	= gen_validate_str(0, 250),
		ac_port 	= gen_validate_num(0, 65535),
		account 	= gen_validate_str(0, 16),
		descr		= gen_validate_str(0, 64),
		switch		= gen_validate_num(0, 1),
	})
	if not m then
		return reply_e(e)
	end

	local account, ac_host, descr = m.account, m.ac_host, m.descr
	if #account > 0 or #ac_host > 0 then
		if not (#account > 0 and #ac_host > 0 and #descr > 0) then
			return reply_e("invalid param")
		end
	end

	query_common(m, "cloud_set")
end

return {run = run}
