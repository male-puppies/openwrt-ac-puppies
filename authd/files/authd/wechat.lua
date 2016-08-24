local fp 		= require("fp")
local ski 		= require("ski")
local log 		= require("log")
local nos 		= require("luanos")
local js 		= require("cjson.safe")
local lib 		= require("authlib")
local batch		= require("batch")
local md5 		= require("md5")
local rpccli	= require("rpccli")
local simplesql	= require("simplesql")
local authlib	= require("authlib")
local cache		= require("cache")

local sumhexa = md5.sumhexa
local set_status, set_online	= nos.user_set_status, authlib.set_online
local keepalive, insert_online	= authlib.keepalive, authlib.insert_online
local set_module = cache.set_module

local udp_map = {}
local udpsrv, mqtt, simple, reply
local wechat_timeout, on_wechat_timeout
local login_trigger, on_login
local keepalive_trigger, on_keepalive
local loop_timeout_check
local reduce, tomap, each, empty, limit = fp.reduce, fp.tomap, fp.each, fp.empty, fp.limit

local function init(u, p)
	udpsrv, mqtt 	= u, p

	reply 			= lib.gen_reply(udpsrv)

	local dbrpc 	= rpccli.new(mqtt, "a/local/database_srv")
	simple 			= simplesql.new(dbrpc)

	-- 批处理
	wechat_timeout 	= batch.new(on_wechat_timeout)
	login_trigger 	= batch.new(on_login)
	keepalive_trigger = batch.new(on_keepalive)

	ski.go(loop_timeout_check)
end

--[[
微信认证校验
/wxlogin2info：在界面上选择微信认证，会缓存终端的信息，并且有超时时间
/weixin2_login：认证成功，并把bypass_wait_map[extend]删除
认证失败时，并且临时放通时间超时后，会在on_wechat_timeout把bypass_wait_map[extend]删除
]]
local wechat_wait_map = {}
function on_wechat_timeout(count, arr)
	local idx = 1
	while idx <= #arr do
		local r, now = arr[idx], ski.time()
		if r[1] >= now then
			ski.sleep(1)
		else
			idx = idx + 1

			local mac, ssid, extend = r[2], r[3], r[4]
			if wechat_wait_map[extend] then
				wechat_wait_map[extend] = nil
				log.real1("wechat timeout %s %s %s", mac, ssid, extend)
			end
		end
	end
end

--[[
接受前端发来的请求，并临时放通数据
@param p  : 前端数据，{"mac":"00:24:54:45:4e:3a","uid":519,"rid":1,"cmd":"/bypass_host","magic":115498,"ip":"172.16.125.26"}
@param ip, port : nginx发送udp包的ip和端口
@return : 回复成功或失败的消息
]]
udp_map["/bypass_host"] = function(p, ip, port)
	local uid, magic, mac = p.uid, p.magic, p.mac
	local r, e = set_status(uid, magic, 1)
	if not r then
		log.error("set_status fail %s", e)
		return reply(ip, port, 1, e)
	end

	log.real1("bypass %s %s %s", uid, magic, mac)

	cache.bypass(mac, {ski.time() + 15, uid, magic, mac})

	reply(ip, port, 0, "ok")
end

--[[
{"origin_sw":"0",
"shop_name":"wxtest",
"ssid":"WX_WIFI",
"appid":"wx3ae592d54767e201",
"origin_id":"",
"shop_id":"4248433",
"secretkey":"eaee288fe2a5924c8012f0522a4ea524"
]]

--[[
接受前端发来的请求，返回微信登陆需要的信息
@param p  : 前端数据，{"cmd":"/wxlogin2info","uid":5241,"now":"1471490987172","rid":1,"mac":"28:a0:2b:65:4d:62","magic":125186,"ip":"172.16.24.186"}
	p.now : 额外的参数，终端的当前时间
@param ip, port : nginx发送udp包的ip和端口
@return : 成功回复微信登陆的信息
]]
udp_map["/wxlogin2info"] = function(p, cli_ip, cli_port)
	local sec, mac = math.floor(ski.time()), p.mac
	local extend = table.concat({mac, sec}, ",")

	-- local n = {appid = "wx3ae592d54767e201", shop_id = 4248433, ssid = "WX_WIFI", secretkey = "eaee288fe2a5924c8012f0522a4ea524"}
	local rid = p.rid
	local authrule = cache.authrule(rid)

	if not authrule then
		log.real1("miss authrule for %s", rid)
		return
	end

	local n = js.decode(authrule.wechat) 					assert(n)
	local redirect_url = string.format("http://%s/weixin2_login", cache.auth_redirect_ip())
	local appid, timestamp, shop_id, authurl, ssid, bssid, secretkey = n.appid, p.now, n.shop_id, redirect_url, n.ssid, "", n.secretkey
	local arr = {appid, extend, timestamp, shop_id, authurl, mac, ssid, bssid, secretkey}
	local sign = md5.sumhexa(table.concat(arr))
	local r = {
		AppID 		= appid,
		Extend 		= extend,
		TimeStamp 	= timestamp,
		Sign 		= sign,
		ShopID 		= shop_id,
		AuthUrl 	= authurl,
		Mac 		= mac,
		SSID 		= ssid,
		BSSID 		= bssid,
	}

	wechat_wait_map[extend] = {
		uid 		= p.uid,
		magic 		= p.magic,
		ip 			= p.ip,
		mac 		= mac,
		username 	= nil,
		rid 		= rid,
		gid 		= 63, 	-- default组
		type 		= "wechat",
		ssid 		= ssid,
	}

	-- TODO set timeout
	wechat_timeout:emit({sec + 15, mac, ssid, extend})
	reply(cli_ip, cli_port, 0, r)
end

--[[
微信认证成功后的回调函数，nignx已经简单校验过一次参数
@param p  : 微信发送的数据（正常）
{
    "cmd": "/weixin2_login",
    "extend": "754,1510,596", 		# 正常情况下，extend是/wxlogin2info处理函数分配的
    "timestamp": "1471575829",
    "openId": "oDN6gw-7L4k3sLCXGyKp5t09_tvg",
    "sign": "016a4c3f2c06ecff12f482354b0e4e0e",
    "tid": "01000763362be566fc128e8695eba22daa71402fdcf1f5b35763ff"
}
@param ip, port : nginx发送udp包的ip和端口
@return : 成功回复微信登陆的信息
]]
udp_map["/weixin2_login"] = function(p, ip, port)
	local extend = p.extend
	local r = wechat_wait_map[extend] 	-- 由"/wxlogin2info"填充
	if not r then
		return reply(ip, port, 1, "wechat login timeout")
	end

	local mac = extend:match("(.+),")
	if not mac then
		return reply(ip, port, 1, "invalid extend")
	end

	wechat_wait_map[extend] = nil
	cache.bypass_cancel(mac)

	r.username = p.openId
	login_trigger:emit(r)

	reply(ip, port, 0, "ok")
end

-- 如果有新用户，插入表user
local function insert_new(arr)
	local narr = reduce(arr, function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.username)) end, {})
	local in_part = table.concat(narr, ",")

	-- 查找表user中存在的用户
	local sql = string.format("select username from user where username in (%s)", in_part)
	local rs, e = simple:mysql_select(sql) 	assert(rs, e)

	-- 找出不存在的用户
	local exists = tomap(rs, "username")
	local miss = reduce(arr, function(t, r)
		local username = r.username
		return exists[username] and t or rawset(t, #t + 1, username)
	end, {})

	if #miss == 0 then
		return true
	end

	-- 插入新用户
	local tmap, now = tomap(arr, "username"), os.date("%Y-%m-%d %H:%M:%S")
	local parts = reduce(miss, function(t, username)
		return rawset(t, #t + 1, string.format("('%s','1234','%s','%s')", username, now, tmap[username].gid))
	end, {})

	local sql = string.format("insert into user(username, password, register, gid) values %s", table.concat(parts, ","))
	local r, e = simple:execute(sql)
	local _ = r or log.error("sql fail %s %s", sql, e)

	return r
end

-- 登陆处理
function on_login(count, arr)
	each(arr, function(_, r) r.ukey = string.format("%s_%s", r.uid, r.magic) end)

	-- 如果表user中没有username，插入
	if not insert_new(arr) then
		return
	end

	-- 检查离线用户
	local narr = reduce(arr, function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.ukey)) end, {})
	local sql = string.format("select ukey from memo.online where ukey in (%s)", table.concat(narr, ","))
	local rs, e = simple:mysql_select(sql) 		assert(rs, e)

	local rs_map = tomap(rs, "username")
	local new_users = reduce(arr, function(t, r)
		local username = r.username
		if rs_map[username] then
			return t
		end

		r.ukey, r.ext = string.format("%s_%s", r.uid, r.magic), js.encode({ssid = r.ssid})
		return rawset(t, username, r)
	end, {})

	-- 插入离线用户到online
	local _ = empty(new_users) or insert_online(simple, new_users, "wechat")
end

--[[
心跳
@param p  : 心跳消息
{
	"cmd": "wechat_keepalive",
	"uid": 754,
	"magic": 1510,
    "ukey": "754_1510",
    "rid": 1,
	"ip": "172.16.24.186"
    "mac": "28:a0:2b:65:4d:62",
}
]]
udp_map["wechat_keepalive"] = function(p)
	keepalive_trigger:emit(p)
end

-- 更新active
function on_keepalive(count, arr)
	local step = 100 			-- 可能有很多，分批更新
	for i = 1, #arr, step do
		local narr = reduce(limit(arr, i, step), function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.ukey)) end, {})
		local sql = string.format("update memo.online set active='%s' where ukey in (%s)", math.floor(ski.time()), table.concat(narr, ","))
		local r, e = simple:mysql_execute(sql) 	assert(r, e)
	end
end

-- 定时/超时下线
function loop_timeout_check()
	while true do
		ski.sleep(cache.timeout_check_intervel())
		authlib.timeout_offline(simple, "wechat")
	end
end

return {init = init, dispatch_udp = lib.gen_dispatch_udp(udp_map)}

