local ski = require("ski")
local log = require("log")
local udp = require("ski.udp") 
local js = require("cjson.safe")
local mysql = require("ski.mysql")
local sandcproxy = require("sandcproxy")

local proxy, udpsrv
local cmd_map = {}

local function start_sand_server()
	local unique, proxy = "a/local/authd"
	local on_message = function(topic, payload)
		local map = js.decode(payload)
		if not (map and map.pld) then return end
		local pld = map.pld
		local cmd = pld.cmd
		if not cmd then return end
		local func = cmd_map[cmd]
		if not func then return end 
		func(pld, map)
	end 
	local args = {
		log = log,
		unique = unique,
		clitopic = {unique}, 
		srvtopic = {unique .. "_srv"}, 
		on_message = on_message, 
		on_disconnect = function(st, err) log.fatal("disconnect %s %s", st, err) end,
	}
	proxy = sandcproxy.run_new(args)
	return proxy
end

local function start_udp_server()
	local parse = function(s)
		if s:byte() == 123 and s:byte(#s) == 125 then 
			return js.decode(s)
		end
		-- parse by call so
	end
	udpsrv = udp.new()
	local r, e = udpsrv:bind("127.0.0.1", 51235) 	assert(r, e)
	while true do 
		local r, e, p = udpsrv:recv()
		if r then
			local m = parse(r)
			if m and m.cmd then 
				local f = cmd_map[m.cmd]
				local _ = f and ski.go(f, m, e, p)
			else 
				print("invalid udp request")
			end
		end
	end
end

local function connect_mysql()
	local db = mysql.new()
    local ok, err, errno, sqlstate = db:connect({
		host = "127.0.0.1",
		port = 3306,
		database = "disk",
		user = "root",
		password = "wjrc0409",
		max_packet_size = 1024 * 1024,
		-- compact_arrays = true,
	})
   	return db
end

-- curl 'http://1.0.0.8/auth/weblogin?magic=1&id=1&ip=192.168.0.3&mac=00:00:00:00:00:01&username=user&password=passwd'
cmd_map["/auth/weblogin"] = function(param, ip, port)
	for k, v in pairs(param) do
		print(k, v)
	end
	udpsrv:send(ip, port, os.date())
end

local function main()
	log.setmodule("auth")
	log.setdebug(true)
	local myconn = connect_mysql() 
	ski.go(start_udp_server)
	proxy = start_sand_server()
end

ski.run(main)

