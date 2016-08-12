package.path = "/usr/share/auth-web/?.lua;" .. package.path 
local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local authlib = require("auth.authlib")

local query_u = query.query_u
local reply, reply_e = authlib.reply, authlib.reply_e
local ip_pattern, mac_pattern = authlib.ip_pattern, authlib.mac_pattern

local uri = ngx.var.uri
local host, port = "127.0.0.1", 50002 	-- 进程 authd

-- 检查获取查询字符串中的必备参数
local function check_common_query_vars()
	local p, rip = ngx.req.get_uri_args(), ngx.var.remote_addr

	-- rid ：策略id, ip/mac : 用户ip/mac, uid/magic ：内核用户标识
	local magic, uid, ip, mac, rid = tonumber(p.magic), tonumber(p.uid), p.ip, p.mac, tonumber(p.rid)
	if not (magic and uid and ip and mac and rid) then
		return nil, "invalid param"
	end

	mac = mac:gsub("%-", ":"):lower()
	if not (ip:find(ip_pattern) and mac:find(mac_pattern) and uid >= 0 and magic >= 0 and rid >= 0) then 
		return nil, "invalid param"
	end

	-- TODO
	-- if rip ~= ip then
	-- 	return reply(1, "invalid request")
	-- end

	return {cmd = uri, magic = magic, uid = uid, ip = ip, mac = mac, rid = rid}
end

local function query_common(param) 
	local r, e = query_u(host, port, param)
	local _ = not r and reply_e(e) or ngx.say(r)
end

local function default_handler()
	local r, e = check_common_query_vars()
	local _ = not r and reply_e(e) or query_common(r)
end 

local uri_map = {}
uri_map["/authopt"] 	= default_handler
uri_map["/cloudonline"] = default_handler
uri_map["/bypass_host"] = default_handler

-- 内核重定向页面，根据rid对应的策略，重定向到本地/云端模板。重定向会带有参数ip,mac,uid,magic,rid
uri_map["/index.html"] = function(r, e)
	local r, e = check_common_query_vars()
	if not r then
		return ngx.exit(ngx.ERROR)
	end

	local rid = r.rid

	-- TODO check rid
	ngx.redirect("/webui/index.html?" .. ngx.var.query_string)
end

uri_map["/authopt"] = function()
	return ngx.say("not implement")
end

uri_map["/weixin2_login"] = function()
	return ngx.say("not implement")
end

uri_map["/PhoneNo"] = function()
	return ngx.say("not implement")
end

uri_map["/cloudlogin"] = function()
	local r, e = check_common_query_vars()
	if not r then 
		return reply_e(e)
	end 

	-- 获取并检查post参数username, password 
	ngx.req.read_body()
	local p = ngx.req.get_post_args()
	if not p then 
		return reply(1, "invalid param")
	end

	local username, password = p.username, p.password
	if not (username and password and #username > 0 and #password > 0) then 
		return reply(1, "invalid param")
	end

	r.username, r.password = username, password

	return query_common(r)
end

local f = uri_map[uri]
if f then 
	return f()
end 

ngx.exit(404)

