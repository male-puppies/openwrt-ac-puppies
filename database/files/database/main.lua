local ski = require("ski")
local log = require("log")
local mgr = require("mgr")
local sync = require("sync")
local udp = require("ski.udp")
local dc = require("dbcommon")
local js = require("cjson.safe")
local config = require("config")
local mysql = require("ski.mysql")
local rpcserv = require("rpcserv")
local updatelog = require("updatelog")
local sandcproxy = require("sandcproxy")

local dbrpc, proxy, udpsrv
local cmd_map = {}

local function broadcast(change)
	for _ in pairs(change) do 
		proxy:publish("a/ac/database_sync", js.encode({pld = {cmd = "dbsync", data = change}}))
		break
	end
end

function cmd_map.rpc(cmd, ctx)  
	local r = dbrpc:execute(cmd)
	local change = sync.sync()
	broadcast(change)
	local _ = r and proxy:publish(ctx.mod, js.encode({seq = ctx.seq, pld = r}))
end

local function start_sand_server()
	local unique, proxy = "a/local/database"
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
	local srv = udp.new()
	local r, e = srv:bind("127.0.0.1", 51234) 	assert(r, e)
	while true do 
		local r, e, p = srv:recv()
		if r then
			local m = js.decode(r)
			if m.cmd == "rpc" then 
				local r = dbrpc:execute(m)
				local _ = r and srv:send(e, p, type(r) == "string" and r or js.encode(r))
			end
		end
	end
end

local function init_config()
	local cfg, err = config.ins()
	local _ = cfg or log.fatal("load config fail %s", err)
	return cfg
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

local function test_sync() 
	while true do 
		for i = 1, 1 do 
			ski.sleep(1) 
		end
		sync.sync()
	end 
end

local function main()
	local cfg = init_config()
	local ud = updatelog.new(cfg)
	ud:prepare()
	local conn = dc.new(cfg:get_workdb(), {{path = cfg:get_memodb(), alias = "memo"}})
	local myconn = connect_mysql() 
	mgr.new(conn, myconn, ud, cfg)
	
	local st = ski.time()
	local change = sync.sync(true)
	log.info("sync init spends %ss", ski.time() - st)

	ski.go(start_udp_server)
	proxy = start_sand_server()
	dbrpc = rpcserv.new(proxy)
	broadcast(change)
	ski.go(test_sync)
end

log.setmodule("db")

ski.run(main)

