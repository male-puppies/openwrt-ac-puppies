local fp 		= require("fp")
local ski 		= require("ski")
local log 		= require("log")
local cache		= require("cache")
local nos 		= require("luanos")
local batch		= require("batch")
local common	= require("common")
local js 		= require("cjson.safe")
local rpccli	= require("rpccli")
local authlib	= require("authlib")
local simplesql = require("simplesql")
local cache		= require("cache")

local escape_map, escape_arr = common.escape_map, common.escape_arr

local set_online = authlib.set_online
local insert_online = authlib.insert_online
local get_rule_id, get_ip_mac = nos.user_get_rule_id, nos.user_get_ip_mac
local limit, reduce, tomap, each, empty, reduce2 = fp.limit, fp.reduce, fp.tomap, fp.each, fp.empty, fp.reduce2

local udp_map = {}
local simple, udpsrv, mqtt, reply
local login_trigger, on_login
local keepalive_trigger, on_keepalive
local loop_timeout_check

local function init(u, p)
	udpsrv, mqtt = u, p

	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple 	= simplesql.new(dbrpc)
	reply 	= authlib.gen_reply(udpsrv)

	login_trigger 		= batch.new(on_login)
	keepalive_trigger 	= batch.new(on_keepalive)

	ski.go(loop_timeout_check)
end

-- 无效的expire
local numb_expire = {["0000-00-00 00:00:00"] = 1, ["1970-01-01 00:00:00"] = 1}

-- 检查web用户认证是否通过
local function check_user(r, p, isonline)
	if not r then
		return nil, "no such user"
	end

	if math.floor(tonumber(r.enable)) ~= 1 then
		return nil, "disable"
	end

	if r.password ~= p.password then
		return nil, "invalid password"
	end

	local bindip = r.bindip
	if #bindip > 0 and bindip ~= p.ip then
		return nil, "invalid ip"
	end

	local bindmac = r.bindmac
	if #bindmac > 0 and bindmac ~= p.mac then
		return nil, "invalid mac"
	end

	local expire = r.expire
	if #expire > 0 and not numb_expire[expire] and expire < os.date("%Y-%m-%d %H:%M:%S") then
		return nil, "expire"
	end

	if r.multi == 1 then
		return true
	end

	return not isonline
end

-- 批量web认证
function on_login(count, arr)
	local f = function(start, step)
		-- 查询已经存在的用户
		local users = limit(arr, start, step)
		local narr = reduce(users, function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.username)) end, {})
		local sql = string.format("select * from user where username in (%s)",  table.concat(narr, ","))

		local rs, e = simple:mysql_select(sql) 	assert(rs, e)
		local user_map = tomap(rs, "username")

		-- 排除并回复不存在的用户
		local exists = reduce(users, function(t, r)
			local user = user_map[r.username]
			if not user then
				reply(r.u_ip, r.u_port, 1, "invalid user")
				return t
			end

			r.gid = user.gid
			return rawset(t, #t + 1, r)
		end, {})

		-- format ukey
		local narr, name_map = {}, {}
		each(exists, function(_, r)
			local ukey = string.format("%s_%s", r.uid, r.magic)
			r.ukey = ukey
			table.insert(narr, string.format("'%s'", ukey))
			name_map[r.username] = 1
		end)
		
		local name_arr = reduce2(name_map, function(t, username) return rawset(t, #t + 1, string.format("'%s'", username)) end, {})

		-- 查询在线用户
		local sql = string.format("select ukey,username from memo.online where ukey in (%s) or username in (%s)",
			table.concat(narr, ","), table.concat(name_arr, ","))
		local rs, e = simple:mysql_select(sql) 	assert(rs, e)

		-- 过滤在线用户
		local online, online_names = tomap(rs, "ukey"), tomap(rs, "username")
		local offline = reduce(exists, function(t, info)
			local u_ip, u_port, ukey = info.u_ip, info.u_port, info.ukey

			-- 排除并回复已经在线的用户
			if online[ukey] then
				reply(u_ip, u_port, 0, "already online")
				return t
			end

			-- 检查用户属性
			local username = info.username
			local r, e = check_user(user_map[username], info, online_names[username])
			if not r then
				reply(u_ip, u_port, 1, e)
				return t
			end

			return rawset(t, ukey, info)
		end, {})

		-- 插入表online
		each(offline, function(_, r)
			set_online(r.uid, r.magic, r.gid, r.username)
			reply(r.u_ip, r.u_port, 0, "ok")
		end)
		local _ = empty(offline) or insert_online(simple, offline, "web")
	end

	local step = 100
	for i = 1, count, step do
		f(i, step)
	end
end

--[[
登陆验证
@param p  : {"username":"aaa","uid":70,"password":"aaa","cmd":"/cloudlogin","rid":0,"mac":"28:a0:2b:65:4d:62","magic":142,"ip":"172.16.24.186"}
@param uip, uport : nginx发送udp包的ip和端口
@return : 成功或失败的消息
]]
udp_map["/cloudlogin"] = function(p, uip, uport)
	local magic, uid, ip, mac, username, password, rid = p.magic, p.uid, p.ip, p.mac, p.username, p.password, p.rid

	local krid = get_rule_id(uid, magic)
	local kip, kmac = get_ip_mac(uid, magic)

	local gid = -1 	-- 占位
	if not (krid and kip and gid and ip == kip and mac == kmac and krid == rid) then
		return reply(uip, uport, 1, "invalid query")
	end

	p.u_ip, p.u_port, p.gid = uip, uport, gid
	login_trigger:emit(p)
end

udp_map["/cloudonline"] = function(p, ip, port)
	udpsrv:send(ip, port, js.encode({status = 1, data = {}}))
end

udp_map["web_keepalive"] = function(p)
	keepalive_trigger:emit(p)
end

-- 批量更新active
function on_keepalive(count, arr)
	local step = 100
	for i = 1, count, step do
		local narr = reduce(limit(arr, i, step), function(t, r) return rawset(t, #t + 1, string.format("'%s'", r.ukey)) end, {})
		local sql = string.format("update memo.online set active='%s' where ukey in (%s)", math.floor(ski.time()), table.concat(narr, ","))

		log.real1("%s", sql)
		local r, e = simple:mysql_execute(sql) 	assert(r, e)
	end
end

-- 定时/超时下线
function loop_timeout_check()
	while true do
		ski.sleep(cache.timeout_check_intervel())
		authlib.timeout_offline(simple, "web")
	end
end

return {init = init, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

