local fp = require("fp")
local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern, mac_pattern = adminlib.ip_pattern, adminlib.mac_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_rid         = gen_validate_num(0, 15)
local v_zid         = gen_validate_num(0, 255)
local v_ipgid       = gen_validate_num(0, 255)
local v_iscloud     = gen_validate_num(0, 1)
local v_enable      = gen_validate_num(0, 1)
local v_rulename    = gen_validate_str(1, 64, true)
local v_ruledesc    = gen_validate_str(0, 128)
local v_authtype    = gen_validate_str(1, 16, true)
local v_modules     = gen_validate_str(2, 32)
local v_while_ip    = gen_validate_str(2, 10240)
local v_while_mac   = gen_validate_str(2, 10240)
local v_wechat      = gen_validate_str(2, 1024)
local v_sms         = gen_validate_str(2, 1024)
local v_rids        = gen_validate_str(2, 256)
local v_priority    = gen_validate_num(0, 99999)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end 

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

function cmd_map.kv_get()
	local m, e = validate_get({keys = gen_validate_str(2, 256)})
	if not m then
		return reply_e(e)
	end

	local keys = js.decode(m.keys)
	if not keys then
		return reply_e("invalid param")
	end 

	if fp.contains_any(fp.tomap(keys), {"username", "password"}) then 
		return reply_e("invalid param")
	end

	local karr = fp.map(keys, function(k, v) return string.format("'%s'", v) end)
	local rs, e = mysql_select(string.format("select * from kv where k in (%s)", table.concat(karr, ",")))
	if not rs then 
		return reply_e(e)
	end 

	return reply(fp.reduce(rs, function(m, r) return fp.set(m, r.k, r.v) end, {}))
end

function cmd_map.kv_set()
	reply_e("not implement")
end

return {run = run}

