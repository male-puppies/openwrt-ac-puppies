local ski = require("ski")
local log = require("log")
local cfg = require("cfg")
local nos = require("luanos")
local batch = require("batch")
local share = require("share")
local js = require("cjson.safe")
local authlib = require("authlib")

local map2arr, arr2map, limit, empty = share.map2arr, share.arr2map, share.limit, share.empty
local escape_map, escape_arr = share.escape_map, share.escape_arr

local find_missing, set_online, set_offline = authlib.find_missing, authlib.set_online, authlib.set_offline
local keepalive, insert_online = authlib.keepalive, authlib.insert_online
local get_rule_id, get_ip_mac = nos.user_get_rule_id, nos.user_get_ip_mac

local udp_map = {}
local myconn, udpsrv, mqtt
local login_trigger, on_login_batch
local keepalive_trigger, on_keepalive_batch
local loop_timeout_check

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
	login_trigger = batch.new(on_login_batch)
	keepalive_trigger = batch.new(on_keepalive_batch)
	ski.go(loop_timeout_check)
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

function on_login_batch(count, arr)
	local usermap = arr2map(arr, "username")
	local sql = string.format("select a.*,b.login from user a left outer join memo.online b using(username) where a.username in (%s)", escape_map(arr, "username"))
	local rs, e = myconn:query(sql) 	assert(rs, e)
	for _, r in ipairs(rs) do
		local username, p = r.username
		if r.login then 
			p, usermap[username] = usermap[username], nil
			reply(p.u_ip, p.u_port, 0, "already online")
			set_online(p.uid, p.magic, r.gid, username)
		end
	end

	local online, rsmap = {}, arr2map(rs, "username")
	for username, p in pairs(usermap) do
		local rp = rsmap[username]
		local r, e = check_user(rp, p)
		if not r then
			reply(p.u_ip, p.u_port, 1, e)
		else
			set_online(p.uid, p.magic, rsmap[username].gid, username)
			local _ = table.insert(online, username), reply(p.u_ip, p.u_port, 0, "web login success")
		end
	end

	if #online == 0 then
		return 
	end 
	
	local tmap, p = {} 
	for _, username in ipairs(online) do 
		p = usermap[username]
		p.ukey = string.format("%d_%d", p.uid, p.magic)
		tmap[username] = p
	end

	insert_online(myconn, tmap, "web")
end

udp_map["/cloudlogin"] = function(p, uip, uport)
	local magic, uid, ip, mac, username, password, rid = p.magic, p.uid, p.ip, p.mac, p.username, p.password, p.rid
	
	local krid = get_rule_id(uid, magic)
	local kip, kmac = get_ip_mac(uid, magic)
	local gid = cfg.get_gid(rid)
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

function on_keepalive_batch(count, arr) 
	local ukey_arr = map2arr(arr2map(arr, "ukey"))
	local step = 100
	for i = 1, #ukey_arr, step do 
		local exists, miss = find_missing(myconn, limit(ukey_arr, i, step))
		local _ = empty(exists) or keepalive(myconn, exists)
		local _ = empty(miss) or log.error("logical error %s", js.encode(miss))
	end
end

function loop_timeout_check()
	local get_offline_time = function()
		local rs, e = myconn:query("select v from disk.kv where k='auth_offline_time'") 	assert(rs, e)
		if #rs == 0 then 
			return 1801
		end 
		return tonumber(rs[1].v) or 1801
	end

	local offline = function(rs)
		for _, r in pairs(rs) do 
			local uid, magic = r.ukey:match("(%d+)_(%d+)")
			set_offline(tonumber(uid), tonumber(magic))
			print("set_offline", js.encode(r))
		end
		local sql = string.format("delete from memo.online where ukey in (%s)", escape_map(rs, "ukey"))
		local r, e = myconn:query(sql) 		assert(r, e)
	end

	while true do
		ski.sleep(60)
		local timeout = get_offline_time()
		local sql = string.format("select ukey,username,(active-login) as diff from memo.online where type='web' and active-login>%s;", timeout)
		local rs, e = myconn:query(sql) 		assert(rs, e)
		local _ = #rs > 0 and offline(rs)
	end
end

return {init = init, dispatch_udp = dispatch_udp}

