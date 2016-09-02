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

-- {"cmd":"system_auth","password_md5":"e00cf25ad42683b3df678c61f42c6bda","oldpassword":"admin","oldpassword_md5":"21232f297a57a5a743894a0e4a801fc3","password":"admin1"}
udp_map["system_auth"] = function(p, ip, port)
	local code = [[
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg

		local rs, e = conn:select("select * from kv where k='password'") 	assert(rs, e)
		if #rs ~= 1 then
			return nil, "miss password"
		end

		local cur_password = rs[1].v
		if #cur_password == 32 then
			if cur_password ~= p.oldpassword_md5 then
				return nil, "invalid oldpassword"
			end
		elseif cur_password ~= p.oldpassword then
			return nil, "invalid oldpassword"
		end

		local sql = string.format("update kv set v='%s' where k='password'", p.password_md5)
		local r, e = conn:execute(sql)
		if not r then
			return nil, e
		end

		ud:save_log(sql, true)
		return true
	]]

	p.cmd = nil
	local r, e = dbrpc:once(code, p)
	return r and reply(ip, port, 0, r) or reply(ip, port, 1, e)
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

	local cmd = string.format("nohup sysupgrade %s %s >/tmp/sysupgrade.txt 2>&1 &", p.keep == 0 and "-n" or "", p.path)
	os.execute(cmd)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
