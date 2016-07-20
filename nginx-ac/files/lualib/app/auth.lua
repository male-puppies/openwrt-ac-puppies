local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")

local uri = ngx.var.uri
local host, port = "127.0.0.1", 50002
local function reply(r, d)
	ngx.say(js.encode({status = r, data = d}))
end

local function query_u(param)
	return query.query_u(host, port, param, 1000)
end

local function check_query_vars()
	local rip = ngx.var.remote_addr
	local p = ngx.req.get_uri_args()

	local magic, uid, ip, mac, rid = tonumber(p.magic), tonumber(p.uid), p.ip, p.mac, tonumber(p.rid)
	if not (magic and uid and ip and mac and rid) then
		return nil, "invalid param"
	end

	-- if rip ~= ip then
	-- 	return reply(1, "invalid request")
	-- end

	mac = mac:gsub("%-", ":"):lower()
	if #mac ~= 17 then
		return nil, "invalid mac"
	end

	return {cmd = uri, magic = magic, uid = uid, ip = ip, mac = mac, rid = rid}
end

local function query_common(param) 
	local r, e = query_u(param) 
	if not r then
		return reply(1, e) 
	end
	return ngx.say(r)
end

local function default()
	local param, e = check_query_vars()
	if not param then 
		return reply(1, e)
	end
	return query_common(param)
end 

local uri_map = {}

uri_map["/authopt"] = function()
	return ngx.say("not implement")
end

uri_map["/weixin2_login"] = function()
	return ngx.say("not implement")
end

uri_map["/PhoneNo"] = function()
	return ngx.say("not implement")
end

uri_map["/webui/login.html"] = function()
	return ngx.say("not implement")
end

uri_map["/authopt"] = default
uri_map["/cloudonline"] = default
uri_map["/bypass_host"] = default
uri_map["/cloudlogin"] = function()
	local param, e = check_query_vars()
	if not param then 
		return reply(1, e)
	end

	ngx.req.read_body()
	local p = ngx.req.get_post_args()
	if not p then 
		return reply(1, "invalid param")
	end

	local username, password = p.username, p.password
	if not (username and password and #username > 0 and #password > 0) then 
		return reply(1, "invalid param")
	end
	param.username, param.password = username, password
	return query_common(param)
end

local f = uri_map[uri]
local _ = f and f()
