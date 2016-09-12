local fp = require("fp")
local ski = require("ski")
local log = require("log")
local misc = require("ski.misc")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local cfglib = require("cfglib")
local common = require("common")
local simplesql = require("simplesql")
local board = require("cfgmgr.board")
local network = require("cfgmgr.network")

local read = common.read

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply
local simple

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple  = simplesql.new(dbrpc)
end

-- {"cmd":"system_synctime","sec":"1472719031"}
udp_map["system_synctime"] = function(p, ip, port)
	local t = os.date("*t", tonumber(p.sec))
	local cmd = string.format("date -s '%04d-%02d-%02d %02d:%02d:%02d'", t.year, t.month, t.day, t.hour, t.min, t.sec)
	log.info("cmd %s", cmd)
	misc.execute(cmd)
	reply(ip, port, 0, "ok")
end

udp_map["system_reboot"] = function(p, ip, port)
	local cmd = string.format("sleep 3 && reboot &")
	reply(ip, port, 0, "ok")
	log.info("cmd %s", cmd)
	misc.execute(cmd)
end

udp_map["system_reset"] = function(p, ip, port)
	local cmd = string.format("sleep 1 && system_reset -f &")
	reply(ip, port, 0, "ok")
	log.info("cmd %s", cmd)
	misc.execute(cmd)
end

udp_map["system_sysinfo"] = function(p, ip, port)
	local sysinfo = js.decode(read("ubus call system info", io.popen))
	local boardinfo = js.decode(read("ubus call system board", io.popen))
	local a1, a2, a3, a4, a5, a6, a7 = read("/proc/stat"):match("[cpu  ](%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)")
	local rs, e = simple:mysql_select("select count(*) as count from online")
	--local conn_count = tonumber(read("/proc/sys/kernel/nt_flow_count"))
	local conn_count = 0 ---TODO FIXME
	local conn_max = tonumber(read("/proc/sys/kernel/nt_flow_max"))

	local res = {
		distribution = boardinfo.release.distribution,
		version = boardinfo.release.version,
		uptime = sysinfo.uptime,
		time = os.date("%Y-%m-%d %H:%M:%S"),
		cpu_stat = {user = a1, nice = a2, system = a3, idle = a4, iowait = a5, irq = a6, softirq = a7},
		memory = {total = sysinfo.memory.total, used = sysinfo.memory.total - sysinfo.memory.free - sysinfo.memory.buffered},
		connection = {max = conn_max, count = conn_count},
		onlineuser = {max = 200, count = rs and rs[1] and rs[1].count or 0},
	}

	reply(ip, port, 0, res)
end

local function get_port_stat(port)
	local stat = {is_up = 0, speed = "", duplex = ""}
	if port.type == 'switch' then
		local cmd = string.format("swconfig dev %s port %u show", port.device, port.num)
		local s = read(cmd, io.popen) or ""
		local speed, duplex = s:match("speed:(%d+)baseT (.-)%-duplex")
		stat.speed = speed and speed .. "Mbps" or ""
		stat.duplex = duplex  or ""
		stat.is_up = speed and 1 or 0
	else
		local cmd = string.format("ethtool %s", port.ifname)
		local s = read(cmd, io.popen) or ""
		local is_up = s:match("Link detected: (.-)\n")
		if is_up == 'yes' then
			local speed = s:match("Speed: (%d+)Mb/s") or "0"
			local duplex = s:match("Duplex: (.-)\n")
			stat.speed = speed .. "Mbps"
			stat.duplex = duplex and string.lower(duplex) or ""
			stat.is_up = 1
		end
	end
	return stat
end

udp_map["system_ifaceinfo"] = function(p, ip, port)
	local board_m = board.load()
	local network_m = network.load()
	local ports, options = board_m.ports, board_m.options
	local net_cfg = network_m.network

	local layout = {}
	for iface, cfg in pairs(net_cfg) do
		for _, i in ipairs(cfg.ports) do
			layout[i] = {name = iface, enable = 1, fixed = 0}
		end
	end

	for i = 1, #ports do
		if not layout[i] then
			layout[i] = {name = "", enable = 0, fixed = 0}
		end
		layout[i].fixed = options[1].layout[i].fixed
		local port_stat = get_port_stat(ports[i])
		layout[i].is_up = port_stat.is_up
		layout[i].speed = port_stat.speed
		layout[i].duplex = port_stat.duplex
	end

	local netm = require "luci.model.network".init()
	local rv   = {}

	for iface, _ in pairs(net_cfg) do
		local net = netm:get_network(iface)
		local device = net and net:get_interface()
		if device then
			local data = {
				proto      = net:proto(),
				uptime     = net:uptime(),
				gwaddr     = net:gwaddr(),
				ipaddrs    = net:ipaddrs(),
				dnsaddrs   = net:dnsaddrs(),
				macaddr    = device:mac(),
				is_up      = device:is_up(),
				rx_bytes   = device:rx_bytes(),
				tx_bytes   = device:tx_bytes(),
				rx_packets = device:rx_packets(),
				tx_packets = device:tx_packets(),
			}
			rv[iface] = data
		end
	end

	local res = {stat = rv, layout = layout}

	reply(ip, port, 0, res)
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

-- {"cmd":"system_backup"}
udp_map["system_backup"] = function(p, ip, port)
	local path = string.format("/tmp/sysbackup%s.bin", os.date("%Y%m%d%H%M%S"))
	local r, e = os.execute("./sysbackup.sh backup " .. path)
	if r ~= 0 then
		return reply(ip, port, 1, "backup fail")
	end
	reply(ip, port, 0, path)
end

-- {"cmd":"system_restore","path":"/tmp/mysysbackup.bin"}
udp_map["system_restore"] = function(p, ip, port)
	local s = read(string.format("./sysbackup.sh restore %s 2>&1 &", p.path), io.popen)
	local s = s:match("result:(.-)\n")
	if s:find("ok") then
		return reply(ip, port, 0, "ok")
	end
	return reply(ip, port, 1, "版本不一致！")
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
