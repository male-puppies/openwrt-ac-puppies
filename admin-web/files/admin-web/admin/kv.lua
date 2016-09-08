-- yjs

local fp = require("fp")
local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern, mac_pattern = adminlib.ip_pattern, adminlib.mac_pattern
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

	return reply(fp.reduce(rs, function(m, r) return rawset(m, r.k, r.v) end, {}))
end

local kvmap = {
	auth_offline_time = gen_validate_num(1, 8640000),
	auth_no_flow_timeout = gen_validate_num(1, 8640000),
}

function kvmap.auth_redirect_ip(ip)
	if ip:find(ip_pattern) then
		return ip
	end

	return nil, "invalid auth_redirect_ip"
end

function kvmap.auth_bypass_dst(s)
	local m = js.decode(s)
	if not m then
		return nil, "invalid auth_bypass_dst"
	end
	return s
end

function cmd_map.kv_set()
	local m, e = validate_post({})
    if not m then
        return reply_e(e)
    end

    local p, e = ngx.req.get_post_args()

    local m = {}
    for k, v in pairs(p) do
		local f = kvmap[k]
		if f then
			local v, e = f(v)
			if not v then
				return reply_e(e)
			end
			m[k] = v
		end
    end
	query_common(m, "kv_set")
end

return {run = run}
