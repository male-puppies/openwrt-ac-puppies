-- yjs

local ski = require("ski")
local log = require("log")
local lfs = require("lfs")
local tcp = require("ski.tcp")
local sandc = require("sandc")
local common = require("common")
local sandc1 = require("sandc1")
local js = require("cjson.safe")
local sandcproxy = require("sandcproxy")
local const = require("constant")

local remote_mqtt, local_mqtt
local read, save_safe = common.read, common.save_safe

local cfgpath = const.cloud_config

local g_kvmap, g_devid

-- 读取本唯一ID
local function read_id()
	local id = read("ifconfig eth0 | grep HWaddr | awk '{print $5}'", io.popen):gsub("[ \t\n]", ""):lower() assert(#id == 17)
	g_devid = id
end

local function set_default()
	g_kvmap = {account = "default", ac_host = "", ac_port = 61886, description = ""}
end

local function restore_cloud()
	if not lfs.attributes(const.default_cloud_config) then
		log.fatal("%s isn't exists.", const.default_cloud_config)
	return false
	end
	local cmd = string.format("cp -f %s %s", const.default_cloud_config, const.cloud_config)
	local _ = cmd and os.execute(cmd)
	log.debug(cmd)
	return true
end

-- 加载cloud的配置，如果没有，设置为default
local function load()
	if not lfs.attributes(cfgpath) then
		restore_cloud()
	end

	local s = read(cfgpath)
	local map = s and js.decode(s)
	if not map then
		os.remove(cfgpath)
		return set_default()
	end
	g_kvmap = map
end

-- 保存状态到文件
local function save_status(st, host, port)
	local m = {state = st, host = host, port = port}
	save_safe("/tmp/memfile/cloudcli.json", js.encode(m))
end

-- 附加认证内容
local function get_connect_payload()
	local account = g_kvmap.account
	local map = {account = account, devid = g_devid}
	return account, map
end

local function remote_topic()
	return "a/dev/" .. g_devid
end

-- 查找host对应的ip，测试host/port是否可连接
local function try_connect(host, port)
	local ip = host
	local pattern = "^%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?$"
	if not ip:find(pattern) then
		local cmd = string.format("nslookup '%s' 2>/dev/null | grep -A 1 'Name:' | grep Addr | awk '{print $3}'", host) -- TODO
		-- local cmd = string.format("timeout nslookup '%s' 2>/dev/null | grep -A 1 'Name:' | grep Addr | awk '{print $3}'", host)
		ip = read(cmd, io.popen)
		if not ip then
			log.error("%s fail", cmd)
			return
		end

		ip = ip:gsub("[ \t\r\n]", "")
		if not ip:find(pattern) then
			log.error("%s fail", cmd)
			return
		end
	end

	local max_timeout = 10
	local start = ski.time()

	for i = 1, 3 do
		if ski.time() - start > max_timeout then
			return
		end

		local cli = tcp.connect(ip, port)
		if cli then
			print("connect ok", ip, port)
			cli:close()
			return ip, port
		end

		log.debug("try connect %s %s fail", ip, port)
		ski.sleep(3)
	end
end

-- 测试云端服务器，直到可以连接
local function get_active_addr()
	while true do
		local host, port = try_connect(g_kvmap.ac_host, g_kvmap.ac_port)
		if host then
			return host, port
		end

		log.debug("try connect %s %s fail", g_kvmap.ac_host or "", g_kvmap.ac_port or "")
		ski.sleep(3)
	end
end

-- 本地sands客户端
local function start_local()
	local unique, ip, port = "a/ac/proxy", "127.0.0.1", 61886
	local mqtt = sandc.new(unique)
	mqtt:set_auth("ewrdcv34!@@@zvdasfFD*s34!@@@fadefsasfvadsfewa123$", "1fff89167~!223423@$$%^^&&&*&*}{}|/.,/.,.,<>?")
	mqtt:pre_subscribe(unique)
	mqtt:set_callback("on_disconnect", function(st, e) log.fatal("mqtt disconnect %s %s %s %s %s", unique, ip, port, st, e) end)

	mqtt:set_callback("on_message", function(topic, payload)
		if not remote_mqtt then
			log.error("skip %s %s", topic, payload:sub(1, 100))
			return
		end

		local map = js.decode(payload)
		if not (map and map.data and map.out_topic) then
			log.error("invalid payload %s %s", topic, payload:sub(1, 100))
			return
		end

		map.data.tpc = remote_topic()
		remote_mqtt:publish(map.out_topic, js.encode(map.data))
	end)

	local r, e = mqtt:connect(ip, port)
	local _ = r or log.fatal("connect fail %s", e)

	mqtt:run()
	log.info("connect ok %s %s %s", unique, ip, port)

	local_mqtt = mqtt
end

-- 远程客户端
local function start_remote()
	local ip, port = get_active_addr()
	local unique = remote_topic()

	local mqtt = sandc1.new(unique)
	mqtt:set_auth("ewrdcv34!@@@zvdasfFD*s34!@@@fadefsasfvadsfewa123$", "1fff89167~!223423@$$%^^&&&*&*}{}|/.,/.,.,<>?")
	mqtt:pre_subscribe(unique)
	mqtt:set_callback("on_connect", function(st, err) save_status(1, ip, port) end)
	mqtt:set_callback("on_disconnect", function(st, e)
		save_status(0, host, port)
		local _ = local_mqtt and local_mqtt:publish("a/ac/cloudcli", js.encode({pld = {cmd = "proxybase", data = "exit"}}))
		log.fatal("mqtt disconnect %s %s %s %s %s", unique, ip, port, st, e)
	end)

	mqtt:set_callback("on_encode_type", function(n, o)
		mqtt:set_encode_type(n) 	-- 设置加密方式
		log.info("encode type change %s->%s", o, n)
	end)

	local account, connect_data = get_connect_payload()
	mqtt:set_connect("a/ac/query/connect", js.encode({pld = connect_data}))
	mqtt:set_will("a/ac/query/will", js.encode({devid = g_devid, account = account}))
	mqtt:set_extend(js.encode({account = account, devid = g_devid}))

	mqtt:set_callback("on_message", function(topic, payload)
		if not local_mqtt then
			log.error("skip %s %s", topic, payload)
			return
		end

		local map = js.decode(payload)
		if not (map and map.mod and map.pld) then
			log.error("invalid message %s %s", topic, payload)
			return
		end

		local_mqtt:publish(map.mod, payload)
	end)

	local r, e = mqtt:connect(ip, port)
	local _ = r or log.fatal("connect fail %s", e)

	mqtt:run()
	log.info("connect ok %s %s %s", unique, ip, port)

	remote_mqtt = mqtt
end

local function start_sand_server()
	local pld, cmd, map, r, e
	local unique = "a/ac/proxybase"

	local on_message = function(topic, payload)
		log.info("recv and exit. %s", payload)
		save_status(0)
		os.exit(0) 		-- cloud.json变了，重启进程
	end

	local args = {
		log = log,
		unique = unique,
		clitopic = {unique},
		srvtopic = {},
		on_message = on_message,
		on_disconnect = function(st, err) log.fatal("disconnect %s %s", st, err) end,
	}

	return sandcproxy.run_new(args)
end

local function main()
	save_status(0)
	local _ = read_id(), load()

	-- cloudcli会向云端注册，如果帐号不对，会touch /tmp/invalid_account
	if not lfs.attributes("/tmp/invalid_account") then
		ski.go(start_local)

		-- ac_host默认是""
		while g_kvmap.ac_host == "" do
			ski.sleep(1)
		end

		ski.go(start_remote)
		start_sand_server()
	end
end

ski.run(main)
