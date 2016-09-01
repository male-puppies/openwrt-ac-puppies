local ski = require("ski")
local lfs = require("lfs")
local log = require("log")
local js = require("cjson.safe")
local common = require("common")
local dbevent = require("dbevent")
local sandcproxy = require("sandcproxy")

js.encode_keep_buffer(false)
js.encode_sparse_array(true)

local read = common.read
local modules = {
	ipgroup = 	require("ipgroup"),
	network = 	require("network"),
	dbevent = 	require("dbevent"),
	acconfig = 	require("acconfig"),
	authrule = 	require("authrule"),
	firewall = 	require("firewall"),
	route = 	require("route"),
	mwan  = 	require("mwan"),
	tc	=	 	require("tc"),
	wlancfg	=	require("wlancfg"),
}

local encode, decode = js.encode, js.decode
local udp_chan, tcp_chan, mqtt

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

	-- 第一次收到命令cmd.cmd时，遍历所有模块，把接收模块的处理函数缓存起来
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

local function start_sand_server()
	local pld, cmd, map, r, e
	local unique = "a/local/performer"

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

local function loop_check_debug()
	local path = "/tmp/debug_performer"
	while true do
		if lfs.attributes(path) then
			local s = read(path), os.remove(path)
			local _ = (#s == 0 and log.real_stop or log.real_start)(s)
		end
		ski.sleep(5)
	end
end

local function main()
	log.setmodule("pf")
	tcp_chan, udp_chan = ski.new_chan(100), ski.new_chan(100)
	mqtt = start_sand_server()
	for _, mod in pairs(modules) do
		mod.init(mqtt)
		if mod.set_event_cb then
			mod.set_event_cb(on_ext_event)
		end
	end
	local _ = ski.go(dispatch_tcp_loop), ski.go(loop_check_debug)
end

ski.run(main)
