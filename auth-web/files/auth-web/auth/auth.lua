-- yjs

package.path = "/usr/share/auth-web/?.lua;" .. package.path

local fp 	= require("fp")
local rds 	= require("common.rds")
local js 	= require("cjson.safe")
local log 	= require("common.log")
local query = require("common.query")
local authlib 	= require("auth.authlib")

local mysql_select 		= authlib.mysql_select
local query_u, r1		= query.query_u, log.real1
local reply, reply_e 	= authlib.reply, authlib.reply_e
local ip_pattern, mac_pattern 	= authlib.ip_pattern, authlib.mac_pattern

local uri 			= ngx.var.uri
local host, port 	= "127.0.0.1", 50002 	-- 进程 authd

log.setlevel("1,2,3,4,d,i,e") 	-- TODO

-- 检查获取查询字符串中的必备参数
-- p = {"mac":"28-A0-2B-65-4D-62","uid":"1144","_t":"1549560","rid":"0","magic":"34952","ip":"172.16.20.43"}
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

	if rip ~= ip then
		return reply(1, "invalid request")
	end

	return {cmd = uri, magic = magic, uid = uid, ip = ip, mac = mac, rid = rid}
end

local function query_common(param)
	local r, e = query_u(host, port, param)
	local _ = not r and reply_e(e) or ngx.say(r)
end

-- 发送到redis-server执行的代码，一定要简单！
local set_redirect_code = [[
	local pc, index, timeout = redis.call, ARGV[1], ARGV[2]
	for _, item in ipairs(cjson.decode(ARGV[3])) do
		local r = pc("hset", "redirect", item[1], item[2]) 	assert(r)
		local r = pc("expire", "redirect", timeout) 		assert(r)
	end
	return true
]]

-- 获取rid对应的登陆页面类型，修改配置后，可能有一定时间的延迟
local function get_redirect_type(rid)
	local r, e = rds.query(function(rds)	return rds:hget("redirect", rid) end)
	if r and r ~= ngx.null then
		return r
	end

	-- redis中没有缓存，或者已经超时，重新从database获取，并缓存到redis
	local rs, e = mysql_select("select iscloud, rid from authrule")
	if not (rs and #rs > 0) then
		log.error("mysql error %s", e or "")
		return "webui"
	end

	local arr = fp.reduce(rs, function(t, r) return rawset(t, #t + 1, {r.rid, r.iscloud == 0 and "webui" or "cloud"})  end, {})
	local r, e = rds.query(function(rds)
		return rds:eval(set_redirect_code, 0, 0, 60, js.encode(arr))
	end)

	for _, r in ipairs(arr) do
		if r[1] == rid then
			return r[2]
		end
	end

	return "webui"
end

local function default_handler()
	local r, e = check_common_query_vars()
	local _ = not r and reply_e(e) or query_common(r)
end

local uri_map = {}
uri_map["/authopt"] 	= default_handler 		-- 获取本地页面的展示选项
uri_map["/cloudonline"] = default_handler 		-- 查询是否在线
uri_map["/bypass_host"] = default_handler 		-- bypass

-- 内核重定向页面，根据rid对应的策略，重定向到本地/云端模板。重定向会带有参数ip,mac,uid,magic,rid
uri_map["/index.html"] = function(r, e)
	local r, e = check_common_query_vars()
	if not r then
		return ngx.exit(ngx.ERROR)
	end

	local url = string.format("/%s/index.html?%s", get_redirect_type(r.rid), ngx.var.query_string)
	ngx.redirect(url)
end

-- 获取wechat登陆的信息
uri_map["/wxlogin2info"] = function()
	local r, e = check_common_query_vars()

	ngx.req.read_body()
	local p = ngx.req.get_post_args()
	if not (p and p.now) then
		return reply(1, "invalid param")
	end

	r.now = p.now
	return query_common(r)
end

local success_fields = {
	tid 	= function(v) return #v == 54 and v or nil end,
	sign 	= function(v) return #v == 32 and v or nil	end,
	openId 	= function(v) return #v > 10 and v or nil end,
	extend 	= function(v) return v:find("^.+,[%d]+$") and v or nil end,
	timestamp = function(v)	return #v == 10 and tonumber(v) and v or nil end,
}

--[[
微信认证成功后的回调函数
@param : {
	"sign":"016a4c3f2c06ecff12f482354b0e4e0e",
	"extend":"754,1510,596",
	"timestamp":"1471575829",
	"tid":"01000763362be566fc128e8695eba22daa71402fdcf1f5b35763ff",
	"openId":"oDN6gw-7L4k3sLCXGyKp5t09_tvg"
}
]]
uri_map["/weixin2_login"] = function()
	local p = ngx.req.get_uri_args()
	if type(p) ~= "table" then
		return ngx.exit(404)
	end

	local m = {}
	for field, f in pairs(success_fields) do
		local v = p[field]
		if not v then
			return ngx.exit(404)
		end

		local v = f(v)
		if not v then
			return ngx.exit(404)
		end

		m[field] = v
	end

	m.cmd = uri
	return query_common(m)
end

uri_map["/PhoneNo"] = function()
	return ngx.say("not implement")
end

-- web登陆
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