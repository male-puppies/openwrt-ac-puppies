local ski = require("ski")
local lfs = require("lfs")
local log = require("log")
local cfg = require("cfg")
local udp = require("ski.udp")
local js = require("cjson.safe")
local common = require("common")
local mysql = require("ski.mysql")
local sandcproxy = require("sandcproxy")

local read = common.read
local modules = {
	-- web = 		require("web"),
	-- sms = 		require("sms"),
	iface = 	require("iface"),
	zone = 		require("zone"),
	dbevent = 	require("dbevent"),
}

local encode, decode = js.encode, js.decode
local udp_chan, tcp_chan, mqtt, udpsrv, myconn

local function dispatch_udp_loop()
	local f = function(cmd, ip, port)
		for _, mod in pairs(modules) do
			local f = mod.dispatch_udp
			if f and f(cmd, ip, port) then
				return
			end
		end
		print("invalid cmd", js.encode(cmd))
	end

	local r, e
	while true do
		r, e = udp_chan:read() 					assert(r, e)
		f(r[1], r[2], r[3])
	end
end

local function dispatch_tcp_loop()
	local f = function(map)
		local match, r, e, s
		local cmd, topic, seq = map.pld, map.mod, map.seq
		for _, mod in pairs(modules) do
			local f = mod.dispatch_tcp
			if f and f(cmd) then
				local _ = mod and seq and mqtt:publish(topic, js.encode({seq = seq, pld = {r, e}}))
				return
			end
		end
		print("invalid cmd", js.encode(cmd))
	end

	local r, e
	while true do
		r, e = tcp_chan:read()					assert(r, e)
		f(r)
	end
end

local function start_sand_server()
	local pld, cmd, map, r, e
	local unique = "a/ac/cfgmgr"

	local on_message = function(topic, payload)
		map = decode(payload)
		if not (map and map.pld) then
			return
		end
		pld = map.pld
		cmd = pld.cmd
		r, e = tcp_chan:write(map) 				assert(r, e)
	end

	local args = {
		log = log,
		unique = unique,
		clitopic = {unique, "a/ac/database_sync"},
		srvtopic = {unique .. "_srv"},
		on_message = on_message,
		on_disconnect = function(st, err) log.fatal("disconnect %s %s", st, err) end,
	}

	return sandcproxy.run_new(args)
end

local function start_udp_server()
	local udpsrv = udp.new()
	local r, e = udpsrv:bind("127.0.0.1", 50003) 			assert(r, e)

	ski.go(function()
		local r, e, m, ip, port
		while true do
			r, ip, port = udpsrv:recv()
			if r then
				m = decode(r)
				if m and m.cmd then
					r, e = udp_chan:write({m, ip, port}) 	assert(r, e)
				else
					print("invalid udp request")
				end
			end
		end
	end)

	return udpsrv
end

local function loop_check_debug()
	local path = "/tmp/debug_cfgmgr"
	while true do
		if lfs.attributes(path) then
			local s = read(path), os.remove(path)
			local _ = (#s == 0 and log.real_stop or log.real_start)(s)
		end
		ski.sleep(5)
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
	})

	local env = require("luasql.sqlite3").sqlite3()
	local conn, e = env:connect(":memory:") 			assert(conn, e)
	db.escape = function(db, s) return conn:escape(s) end
	return db
end

local function test()
	local unique, proxy = "a/ac/authd_test"
	local on_message = function(topic, payload)
		local map = js.decode(payload)
		if not (map and map.pld) then return end
		local pld = map.pld
		local cmd = pld.cmd
		return dispatch(pld.cmd)
	end
	local args = {
		log = log,
		unique = unique,
		clitopic = {unique},
		srvtopic = {unique .. "_srv"},
		on_message = on_message,
		on_disconnect = function(st, err) log.fatal("disconnect %s %s", st, err) end,
	}
	local proxy = sandcproxy.run_new(args)
	while true do
		local r, e = proxy:query("a/ac/authd_srv", {cmd = "dbevent", data = {user = {1,2,3,4}}})
		print(js.encode({r, e}))
		ski.sleep(1)
	end
end

local function main()
	log.setmodule("cm")
	tcp_chan, udp_chan = ski.new_chan(100), ski.new_chan(100)
	myconn, udpsrv, mqtt = connect_mysql(), start_udp_server(), start_sand_server()
	for _, mod in pairs(modules) do
		mod.init(myconn, udpsrv, mqtt)
	end
	cfg.init(myconn, udpsrv, mqtt)

	local _ = ski.go(dispatch_udp_loop), ski.go(dispatch_tcp_loop), ski.go(loop_check_debug)
end

ski.run(main)

