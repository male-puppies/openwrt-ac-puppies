local fp = require("fp")
local ski = require("ski")
local log = require("log")
local misc = require("ski.misc")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local cfglib = require("cfglib")

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

-- {"cmd":"system_synctime","sec":"1472719031"}
udp_map["system_synctime"] = function(p, ip, port)
	local t = os.date("*t", tonumber(p.sec))
	local cmd = string.format("date -s '%04d-%02d-%02d %02d:%02d:%02d'", t.year, t.month, t.day, t.hour, t.min, t.sec)
	log.info("cmd %s", cmd)
	misc.execute(cmd)
	reply(ip, port, 0, "ok")
end


-- {"cmd":"system_upgrade","keep":1}
udp_map["system_upgrade"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		ins.ud:backup()
		return true
	]]

	-- 备份数据库
	local r, e = dbrpc:once(code)
	if not r then
		return reply(ip, port, 1, e)
	end

	-- 先回复前端，再进行升级
	reply(ip, port, 0, {eta = 180})

	local cmd = string.format("nohup sysupgrade %s %s >/dev/sysupgrade.txt 2>&1 &", p.keep == 0 and "-n" or "", p.path)
	os.execute(cmd)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
