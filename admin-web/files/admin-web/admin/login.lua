-- yjs

local js = require("cjson.safe")
local rds = require("common.rds")
local adminlib = require("admin.adminlib")

local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply

local function check()
	local p = ngx.req.get_uri_args()
	local username, password = p.username, p.password
	if not (username and password and #username > 0 and #password > 0) then
		return nil, "invalid param"
	end

	return {username = username, password = password}
end

local function auth(p)
	local username = p.username
	local sql = string.format("select v from kv where k='username' and v='%s'", username)
	local rs, e = mysql_select(sql)
	if not (rs and #rs == 1) then
		return nil, "auth fail"
	end

	local sql = string.format("select v from kv where k='password'")
	local rs, e = mysql_select(sql)
	if not (rs and #rs == 1) then
		return nil, "auth fail"
	end

	local admin_password, password = rs[1].v, p.password
	if #admin_password == 32 then
		if ngx.md5(password) ~= admin_password then
			return nil, "invalid password"
		end
	elseif admin_password ~= password then
		return nil, "invalid password"
	end

	return {username = username, count = 1, perm = js.encode({})}
end

local cache_auth_code = [[
	local m = cjson.decode(ARGV[1])
	local pc, rp = redis.call, function(r, e) return cjson.encode({r = r, d = e}) end

	local r = pc("SELECT", 9)
	if r.ok ~= "OK" then
		return rp(1, "select fail")
	end

	local key = "admin_" .. m.token
	r = pc("HMSET", key, "username", m.username, "perm", m.perm, "rtoken", m.rtoken)
	if r.ok ~= "OK" then
		return rp(1, "HMSET fail")
	end

	r = pc("EXPIRE", key, m.timeout)
	if r ~= 1 then
		return rp(1, "EXPIRE fail")
	end

	return rp(0, "ok")
]]
local function cache_auth(r)
	local now = math.floor(ngx.now())
	local k1, k2 = math.random(1, 9999), math.random(1, 9999)
	local key, refreshkey = string.format("%s-%04d", now, k1), string.format("%s-%04d", now, k2)
	local token, refreshtoken = ngx.md5(key), ngx.md5(refreshkey)

	local args = {
		username = r.username,
		perm = r.perm,
		token = token,
		rtoken = refreshtoken,
		timeout = 3600,
	}

	local s = js.encode(args)
	local r, e = rds.query(function(db) return db:eval(cache_auth_code, 0, s) end)
	if not r then
		return reply_e(e)
	end

	local m = js.decode(r)
	if not (m and m.r and m.d) then
		return reply_e("eval fail " .. r)
	end

	if m.r ~= 0 then
		return reply_e("cache fail")
	end

	reply({token = token, refresh = refreshtoken})
end

local function run()
	local p, e = check()
	if not p then
		return reply_e(e)
	end

	local r, e = auth(p)
	if not r then
		return reply_e(e)
	end

	return cache_auth(r)
end

return {run = run}
