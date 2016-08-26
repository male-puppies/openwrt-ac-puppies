-- author: yjs

local ski 	= require("ski")
local lfs 	= require("lfs")
local log 	= require("log")
local cache 	= require("cache")
local udp 	= require("ski.udp")
local js  	= require("cjson.safe")
local kernel = require("kernel")
local common = require("common")
local sandcproxy = require("sandcproxy")

js.encode_keep_buffer(false)
js.encode_sparse_array(true)

local read = common.read
local encode, decode = js.encode, js.decode
local udp_chan, tcp_chan, mqtt, udpsrv

--[[
认证模块化划分，一种认证一个模块，每个模块包括函数
init:			初始化
dispatch_udp:	处理从nginx、ntrackd等进程发来的udp命令
dispatch_tcp:	处理从data等进程发来的udp命令
]]
local modules = {
	act 	= 	require("act"),
	web 	= 	require("web"),
	sms 	= 	require("sms"),
	auto 	= 	require("auto"),
	wechat 	= 	require("wechat"),
	kernel 	= 	require("kernel"),
	dbevent = 	require("dbevent"),
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

-- ntrackd发过来的udp消息不直接在kernel模块中处理，转到各个具体的认证模块
-- @param cmd : {cmd = "xxx", ...}
local function on_kernel_msg(cmd)
	for _, mod in pairs(modules) do
		local f = mod.dispatch_udp
		if f and f(cmd) then
			return
		end
	end
	print("invalid cmd", js.encode(cmd))
end

-- 循环处理sands命令
local function dispatch_tcp_loop()
	-- 选择一个模块处理，一个命令只能由一个模块处理
	-- @param map : {mod = "mod"/nil, seq = "seq"/nil, pld = xxx}
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
	local unique = "a/local/authd"

	local on_message = function(topic, payload)
		map = decode(payload)
		if not (map and map.pld) then
			return
		end

		pld  = map.pld
		cmd  = pld.cmd
		r, e = tcp_chan:write(map) 				assert(r, e)
	end

	local args = {
		log 		= log,
		unique 		= unique,
		clitopic 	= {unique, "a/ac/database_sync"},
		srvtopic 	= {unique .. "_srv"},
		on_message 	= on_message,
		on_disconnect = function(st, err) log.fatal("disconnect %s %s", st, err) end,
	}

	return sandcproxy.run_new(args)
end

local function start_udp_server()
	local udpsrv = udp.new()
	local r, e = udpsrv:bind("127.0.0.1", 50002) 			assert(r, e)

	ski.go(function()
		local r, e, m, ip, port
		while true do
			r, ip, port = udpsrv:recv()
			if r then
				print("main", r)
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

-- 开启或关闭实时日志。开启：echo 1,2,3,4,d,i,e,f > /tmp/debug_authd；关闭：echo > /tmp/debug_authd
local function loop_check_debug()
	local path = "/tmp/debug_authd"
	while true do
		if lfs.attributes(path) then
			local s = read(path), os.remove(path)
			local _ = (#s == 0 and log.real_stop or log.real_start)(s)
		end

		ski.sleep(5)
	end
end

local function main()
	log.setmodule("auth")

	tcp_chan, udp_chan = ski.new_chan(100), ski.new_chan(100)
	udpsrv, mqtt = start_udp_server(), start_sand_server()

	-- 各模块初始化
	for _, mod in pairs(modules) do
		mod.init(udpsrv, mqtt)
	end
	cache.init(udpsrv, mqtt)

	-- kernel模块回调函数
	kernel.set_kernel_cb(on_kernel_msg)

	-- 开始监听
	local _ = ski.go(dispatch_udp_loop), ski.go(dispatch_tcp_loop), ski.go(loop_check_debug)
end

ski.run(main)

