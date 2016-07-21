local js = require("cjson.safe")
local log = require("common.log")
local global = require("admin.global")
local rds = require("common.rds")
local mysql = require("common.mysql")

local reply_e, reply = global.reply_e, global.reply
local check_method_token = global.check_method_token

local cmd_map = {}
local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function check()
	local p = ngx.req.get_uri_args()
	local username, password = p.username, p.password
	if not (username and password and #username > 0 and #password > 0) then 
		return nil, "invalid param"
	end

	return {username = username, password = password}
end

local function auth(p)
	local sql = string.format("select count(*) as count, perm from csadmin where username='%s' and password='%s'", p.username, p.password)
	
	-- local r, e = mysql.query(function(db)
	-- 	local rs, e = db:query(sql) 	
	-- 	if not rs then 
	-- 		return nil, e 
	-- 	end 
	-- 	return rs[1]
	-- end)

	-- if not r then 
	-- 	return nil, e
	-- end 
	local r = {username = p.username, count = 1, perm = js.encode({})}
	if tonumber(r.count) == 0 then 
		return nil, "invalid auth"
	end 

	r.username = p.username
	return r
end

local token_ttl_code = [[
	local pc, index, token = redis.call, ARGV[1], ARGV[2]
	local r = pc("SELECT", index) 		assert(r.ok == "OK")

	r = pc("TTL", "admin_" .. token)
	return r
]]
local function check_access_token(index, token)
	local left, e = rds.query(function(rds) return rds:eval(token_ttl_code, 0, 9, token) end)
	if not left then 
		return nil, "redis error"
	end

	
	log.real1("%s", js.encode({left, e, type(left)}))

	return true
end
log.setlevel("1,2,3,4,d,i,e")
function cmd_map.zone_get()
	local check = function() 
		local r, e = check_method_token("GET")
		if not r then 
			return nil, e
		end

		local p = ngx.req.get_uri_args()
		local r, e = check_access_token(9, p.token)
		
		
		if not r then
			return nil, e
		end
		
		return {}
	end

	local p, e = check()
	if not p then
		return reply_e(e)
	end

	reply(p)
end

return {run = run}

