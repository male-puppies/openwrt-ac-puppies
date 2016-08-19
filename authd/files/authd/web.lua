local ski 	= require("ski")
local log 	= require("log")
local cfg 	= require("cfg")
local nos 	= require("luanos")
local batch = require("batch")
local common 	= require("common")
local js 	 	= require("cjson.safe")
local rpccli 	= require("rpccli")
local authlib 	= require("authlib")
local simplesql = require("simplesql")

local map2arr, arr2map, limit, empty = common.map2arr, common.arr2map, common.limit, common.empty
local escape_map, escape_arr = common.escape_map, common.escape_arr

local find_missing, set_online, set_offline = authlib.find_missing, authlib.set_online, authlib.set_offline
local keepalive, insert_online = authlib.keepalive, authlib.insert_online
local get_rule_id, get_ip_mac = nos.user_get_rule_id, nos.user_get_ip_mac

local udp_map = {}
local simple, udpsrv, mqtt, reply
local login_trigger, on_login_batch
local keepalive_trigger, on_keepalive_batch
local loop_timeout_check

local function init(u, p)
	udpsrv, mqtt = u, p

	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple 	= simplesql.new(dbrpc)

	reply 	= authlib.gen_reply(udpsrv)

	login_trigger 		= batch.new(on_login_batch)
	keepalive_trigger 	= batch.new(on_keepalive_batch)

	ski.go(loop_timeout_check)
end

-- 无效的expire
local numb_expire = {["0000-00-00 00:00:00"] = 1, ["1970-01-01 00:00:00"] = 1}

-- 检查web用户认证是否通过
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

-- 批量web认证
function on_login_batch(count, arr)
	-- TODO
	-- fp.each(arr, function(_, r) set_online(r.uid, r.magic, r.gid, r.username) end)

	local usermap = arr2map(arr, "username")
	local sql = string.format("select a.*,b.login from user a left outer join memo.online b using(username) where a.username in (%s)", escape_map(arr, "username"))
	local rs, e = simple:mysql_select(sql) 	assert(rs, e)
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

	insert_online(simple, tmap, "web")
end

udp_map["/cloudlogin"] = function(p, uip, uport)
	local magic, uid, ip, mac, username, password, rid = p.magic, p.uid, p.ip, p.mac, p.username, p.password, p.rid

	local krid = get_rule_id(uid, magic) 		assert(krid)
	local kip, kmac = get_ip_mac(uid, magic)

	local gid = 0 	-- TODO select gid
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
		local exists, miss = find_missing(simple, limit(ukey_arr, i, step))
		local _ = empty(exists) or keepalive(simple, exists)
		local _ = empty(miss) or log.error("logical error %s", js.encode(miss))
	end
end

function loop_timeout_check()
	local get_offline_time = function()
		local rs, e = simple:mysql_select("select v from kv where k='offline_time'") 	assert(rs, e)
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
		local r, e = simple:mysql_execute(sql) 	assert(r, e)
	end

	while true do
		ski.sleep(60)
		local timeout = get_offline_time()
		local sql = string.format("select ukey,username,(active-login) as diff from memo.online where type='web' and active-login>%s;", timeout)
		local rs, e = simple:mysql_select(sql) 	assert(rs, e)
		local _ = #rs > 0 and offline(rs)
	end
end

return {init = init, dispatch_udp = authlib.gen_dispatch_udp(udp_map)}

