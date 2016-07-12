local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local batch = require("batch")

local udp_map, tcp_map = {}, {}
local myconn, udpsrv, mqtt
local login_trigger, on_batch

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
	login_trigger = batch.new(on_batch)
end

local function dispatch_udp(cmd, ip, port)
	print(js.encode(cmd))
	local f = udp_map[cmd.cmd]
	if f then
		return true, f(cmd, ip, port)
	end
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

local function get_userinfo(magic, uid)
	return {}
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

function on_batch(count, arr)
	local usermap, narr = {}, {} 
	for _, p in ipairs(arr) do  
		usermap[p.username] = p
	end

	for username in pairs(usermap) do 
		table.insert(narr, string.format("'%s'", myconn:escape(username)))
	end 

	local sql = string.format("select username,password,enable,bindip,bindmac,expire from user where username in (%s)", table.concat(narr, ","))
	local rs, e = myconn:query(sql) 	assert(rs, e)
	
	local rsmap = {}
	for _, r in ipairs(rs) do 
		rsmap[r.username] = r
	end
	
	local res, online, r, e = {status = 0, data = ""}, {}
	for username, p in pairs(usermap) do
		r, e = check_user(rsmap[username], p)
		if not r then
			res.status, res.data = 1, e
		else 
			res.status, res.data = 0, "success", table.insert(online, username)
		end
		
		udpsrv:send(p.ip, p.port, js.encode(res))
	end

	-- update online
	if #online > 0 then 
		local now = math.floor(ski.time())
		local arr, p, r, e = {}
		for _, username in ipairs(online) do 
			p = usermap[username]
			table.insert(arr, string.format("('web','%s','%s','%s',%s)", username, p.ip, p.mac, now))
		end

		local sql = string.format([[insert into memo.online (type,username,ip,mac,uptime) values %s on duplicate key update type='web',state=1]], table.concat(arr, ","))
		r, e = myconn:query(sql) 	assert(r, e)
	end
end

-- curl 'http://1.0.0.8/auth/weblogin?ip=192.168.72.56&mac=D0-50-99-41-7C-B4&uid=4033&magic=8068&username=15914180656&password=123456'
udp_map["/cloudlogin"] = function(p, ip, port) 
	local magic, uid, uip, mac, username, password = p.magic, p.uid, p.ip, p.mac, p.username, p.password
	local map = get_userinfo(magic, uid)
	p.ip, p.port = ip, port
	login_trigger:emit(p)
end

udp_map["/cloudonline"] = function(p, ip, port) 
	udpsrv:send(ip, port, js.encode({status = 1, data = {}}))
end

return {init = init, dispatch_udp = dispatch_udp, dispatch_tcp = dispatch_tcp}

