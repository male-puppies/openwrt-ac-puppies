local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local batch = require("batch")

local udp_map, tcp_map = {}, {}
local myconn, udpsrv, mqtt

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
end

local function dispatch_udp(cmd, ip, port)
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

-- curl 'http://1.0.0.8/auth/weblogin?ip=192.168.72.56&mac=D0-50-99-41-7C-B4&uid=4033&magic=8068&username=15914180656&password=123456'
local login_trigger
udp_map["auto_login"] = function(p, ip, port)
	if not login_trigger then 
		login_trigger = batch.new(function(count, arr)
			local usermap, narr = {}, {} 
			for _, p in ipairs(arr) do  
				usermap[p.username] = p  
			end

			for username in pairs(usermap) do 
				table.insert(narr, string.format("'%s'", username)) 	-- TODO escape username
			end 

			local sql = string.format("select username,password,enable,bindip,bindmac,expire from user where username in (%s)", table.concat(narr, ","))
			local rs, e = myconn:query(sql) 	assert(rs, e)
			local rsmap = {}
			for _, r in ipairs(rs) do 
				rsmap[r.username] = r
			end

			for username, p in pairs(usermap) do
				local r, res = rsmap[username], {status = 1, data = ""}
				if not r then 
					res.data = "no such user"
				elseif r.password ~= p.password then 
					res.data = "invalid password"
				else 
					res.status, res.data = 0, "ok"
				end
				udpsrv:send(p.ip, p.port, js.encode(res))
			end
			ski.sleep(3)
		end)
	end

	local magic, uid, uip, mac, username, password = p.magic, p.uid, p.ip, p.mac, p.username, p.password
	local map = get_userinfo(magic, uid)
	p.ip, p.port = ip, port
	login_trigger:emit(p)
end

return {init = init, dispatch_udp = dispatch_udp, dispatch_tcp = dispatch_tcp}

