local ski = require("ski")
local log = require("log")
local mgr = require("mgr")
local udp = require("ski.udp")
local dc = require("dbcommon")
local js = require("cjson.safe")
local config = require("config")
local rpcserv = require("rpcserv")
local updatelog = require("updatelog")
local sandcproxy = require("sandcproxy")

local dbrpc, proxy, udpsrv
local cmd_map = {}
function cmd_map.rpc(cmd, ctx)  
	local r = dbrpc:execute(cmd)
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

local function main()
	local cfg = init_config()
	local ud = updatelog.new(cfg)
	local _ = ud:recover(), ud:prepare()
	local conn = dc.new(cfg:get_workdb(), {{path = cfg:get_memodb(), alias = "memo"}})
	mgr.new(conn, ud, cfg)
	
	ski.go(start_udp_server)
	proxy = start_sand_server()
	dbrpc = rpcserv.new(proxy)
end

log.setmodule("db")
log.setdebug(true)

ski.run(main)

