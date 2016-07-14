local ski = require("ski")
local log = require("log")
local nos = require("luanos")
local batch = require("batch")
local js = require("cjson.safe")
local authlib = require("authlib")

local map2arr, arr2map, limit = authlib.map2arr, authlib.arr2map, authlib.limit 
local escape_map, escape_arr, empty = authlib.escape_map, authlib.escape_arr, authlib.empty
local set_status, set_gid_ucrc = nos.user_set_status, nos.user_set_gid_ucrc
local get_ip_mac, get_status, get_rule_id = nos.user_get_ip_mac, nos.user_get_status, nos.user_get_rule_id

local udp_map = {}
local myconn, udpsrv, mqtt
local login_trigger, keepalive_trigger, on_login_batch

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
	login_trigger = batch.new(on_login_batch)
	keepalive_trigger = batch.new(on_keepalive_batch)
end

local reply_obj = {status = 0, data = 0}
local function reply(ip, port, r, d)
	reply_obj.status, reply_obj.data = r, d
	udpsrv:send(ip, port, js.encode(reply_obj))
end

local function dispatch_udp(cmd, ip, port)
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
end

local numb_expire = {["0000-00-00 00:00:00"] = 1, ["1970-01-01 00:00:00"] = 1}
local function check_user(r, p)
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

	return true
end

local function set_online(uid, magic, gid) 
	local _ = set_status(uid, magic, 1), set_gid_ucrc(uid, magic, gid, 1)
end

local function insert_online(ukey_map)
	local now = math.floor(ski.time())
	local arr, r, e = {}
	for ukey, p in pairs(ukey_map) do
		table.insert(arr, string.format("('%s','web','%s','%s','%s',%s,%s,%s)", p.ukey, p.username or p.mac, p.ip, p.mac, p.rid, now, now))
	end

	local sql = string.format([[insert into memo.online (ukey,type,username,ip,mac,rid,login,active) values %s on duplicate key update type='web',state=1]], table.concat(arr, ","))
	r, e = myconn:query(sql) 	assert(r, e)
end 

on_login_batch = function(count, arr)
	local usermap, narr = {}, {} 
	for _, p in ipairs(arr) do  
		usermap[p.username] = p
	end

	for username in pairs(usermap) do 
		table.insert(narr, string.format("'%s'", myconn:escape(username)))
	end 

	local sql = string.format("select a.*,b.state from user a left outer join memo.online b using(username) where username in (%s)", table.concat(narr, ","))
	local rs, e = myconn:query(sql) 	assert(rs, e)

	local rsmap, p, uid, magic, rp, gid = {}
	for _, r in ipairs(rs) do
		local username = r.username
		if r.state ~= 1 then
			rsmap[username] = r
		else 
			p, usermap[username] = usermap[username], nil
			reply(p.u_ip, p.u_port, 0, "already online") 
			set_online(p.uid, p.magic, r.gid)
		end
	end

	local online, r, e = {}
	for username, p in pairs(usermap) do
		rp = rsmap[username]
		r, e = check_user(rp, p)
		if not r then
			reply(p.u_ip, p.u_port, 1, e)
		else
			set_online(p.uid, p.magic, rsmap[username].gid)
			local _ = table.insert(online, username), reply(p.u_ip, p.u_port, 0, "web login success")
		end
	end

	-- update online
	if #online == 0 then
		return 
	end 
	
	local tmap, p = {} 
	for _, username in ipairs(online) do 
		p = usermap[username]
		p.ukey = p.mac 
		tmap[username] = p
	end

	insert_online(tmap)
end

udp_map["/cloudlogin"] = function(p, uip, uport)
	local magic, uid, ip, mac, username, password, rid = p.magic, p.uid, p.ip, p.mac, p.username, p.password, p.rid
	
	local krid = get_rule_id(uid, magic)
	local kip, kmac = get_ip_mac(uid, magic)

	if not (krid and kip and ip == kip and mac == kmac and krid == rid) then 
		return reply(uip, uport, 1, "invalid query") 
	end

	p.u_ip, p.u_port = uip, uport
	login_trigger:emit(p)
end

udp_map["/cloudonline"] = function(p, ip, port) 
	udpsrv:send(ip, port, js.encode({status = 1, data = {}}))
end

udp_map["web_keepalive"] = function(p)
	keepalive_trigger:emit(p)
end

local function find_missing(ukey_arr)
	local ukey_map = arr2map(ukey_arr, "ukey")
	local sql = string.format("select ukey from memo.online where ukey in (%s)", escape_map(ukey_map, "ukey"))
	local rs, e = myconn:query(sql) 		assert(rs, e) 
	local exists, miss, find = {}, {}
	for _, r in ipairs(rs) do
		ukey = r.ukey
		exists[ukey] = ukey_map[ukey]
	end

	for ukey, r in pairs(ukey_map) do 
		if not exists[ukey] then
			miss[ukey], find = r, true
		end 
	end 

	return exists, miss
end

-- [{"cmd":"web_keepalive","uid":33703,"rid":3,"mac":"00:0c:29:04:3f:d0","magic":67408,"ip":"192.168.1.56","ukey":"00:0c:29:04:3f:d0"}]
on_keepalive_batch = function(count, arr)
	local ukey_map = arr2map(arr, "ukey")
	local ukey_arr = map2arr(ukey_map)

	local step, now, exists, miss, r, e, s, sql = 100, math.floor(ski.time())
	for i = 1, #ukey_arr, step do 
		exists, miss = find_missing(limit(ukey_arr, i, step))
		s = escape_map(exists, "ukey")
		if s then
			sql = string.format("update memo.online set active='%s' where ukey in (%s)", now, s)
			r, e = myconn:query(sql) 		assert(r, e)
		end

		local _ = empty(miss) or insert_online(miss)
	end
	
	-- ski.sleep(10) 	-- TODO
end

return {init = init, dispatch_udp = dispatch_udp}

