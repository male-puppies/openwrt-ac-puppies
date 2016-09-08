--[[
	author:tgb
	date:2016-08-25 1.0 add basic code
]]
local ski = require("ski")
local lfs = require("lfs")
local log = require("log")
local js = require("cjson.safe")
local udp 	= require("ski.udp")
local common = require("common")
local sandcproxy = require("sandcproxy")

local udpsrv, mqtt
local read = common.read
local tcp_chan, udp_chan
local encode, decode = js.encode, js.decode
local modules = {
	dbevent = 	require("dbevent"),
	aclog = 	require("aclog"),
}

-- 循环处理udp命令
local function dispatch_udp_loop()
	-- 选择一个模块处理，一个命令只能由一个模块处理
	-- @param cmd : {cmd = "xxx", ...}
	-- @param ip,port  : 客户端ip,port
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

local function loop_check_debug()
	local path = "/tmp/debug_acmgr"
	while true do
		if lfs.attributes(path) then
			local s = read(path), os.remove(path)
			local _ = (#s == 0 and log.real_stop or log.real_start)(s)
		end
		ski.sleep(5)
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

local handlers = {}
local function on_ext_event(cmd)
	local arr = handlers[cmd.cmd]
	if arr then
		for _, f in ipairs(arr) do
			f(cmd)
		end
		return
	end

	local arr = {}
	for _, mod in pairs(modules) do
		local f = mod.dispatch_tcp
		if f and f(cmd) then
			table.insert(arr, f)
		end
	end

	handlers[cmd.cmd] = arr
	local _ = #arr == 0 and print("no one deal with cmd", js.encode(cmd))
end

local function start_udp_server()
	local udpsrv = udp.new()
	local r, e = udpsrv:bind("127.0.0.1", 60000) 			assert(r, e)

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

local function start_sand_server()
	local pld, cmd, map, r, e
	local unique = "a/ac/acmgr"

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

local function main()
	log.setmodule("acmgr")
	tcp_chan, udp_chan = ski.new_chan(100), ski.new_chan(100)
	udpsrv, mqtt = start_udp_server(), start_sand_server()

	for _, mod in pairs(modules) do
		mod.init(udpsrv, mqtt)
		if mod.set_event_cb then
			mod.set_event_cb(on_ext_event)
		end
	end

	local _ = ski.go(dispatch_udp_loop), ski.go(loop_check_debug), ski.go(dispatch_tcp_loop)
end

ski.run(main)
