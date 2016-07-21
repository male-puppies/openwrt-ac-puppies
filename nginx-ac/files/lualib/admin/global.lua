local js = require("cjson.safe")
local rds = require("common.rds")

local function reply_e(e)
	ngx.say(js.encode({status = 1, data = e}))
end

local function reply(d)
	ngx.say(js.encode({status = 0, data = d}))
end

local function check_method_token(expect_method, token)
	if expect_method ~= ngx.req.get_method() then 
		return nil, "invalid request"
	end 

	token = token or ngx.req.get_uri_args().token
	if not (token and #token == 32) then
		return nil, "invalid token"
	end

	return true
end

local token_ttl_code = [[
	local token, left, index = ARGV[1], ARGV[2], ARGV[3]
	local pc, rp = redis.call, function(r, d) return cjson.encode({r = r, d = d}) end

	local r = pc("SELECT", index)
	if r.ok ~= "OK" then 
		return rp(1, "select fail") 
	end

	local key = "admin_" .. token
	r = pc("TTL", key)
	if r < tonumber(left) then 
		return rp(1, "timeout " .. r)
	end

	r = pc("hmget", key, "username", "perm")
	return rp(0, r)
]]
local function validate_token(token)
	local r, e = rds.query(function(db) return db:eval(token_ttl_code, 0, token, 300, 9) end)
	if not r then 
		return nil, e
	end 

	local m = js.decode(r)
	if not (m and m.r and m.d) then
		return nil, "eval token fail"
	end

	if m.r ~= 0 then 
		return nil, m.d
	end 

	return true
end

return { 
	reply = reply,
	reply_e = reply_e,
	validate_token = validate_token,
	check_method_token = check_method_token,
}


