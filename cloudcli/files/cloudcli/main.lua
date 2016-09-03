local ski = require("ski")
local log = require("log")
local lfs = require("lfs")
local cfg = require("cfg")
local common = require("common")
local js = require("cjson.safe")
local config = require("config")
local sandcproxy = require("sandcproxy")

local unique = "a/ac/cfgmgr"
local read, save_safe = common.read, common.save_safe
local get_devid, get_kvmap = cfg.get_devid, cfg.get_kvmap

local proxy

-- 检查/注册本机配置
local function upload()
	local register_topic = "a/ac/cfgmgr/register"
	local request = function(data)
		while true do
			local r, e = proxy:query_r(register_topic, data)
			if r then
				return r
			end

			log.error("register fail %s %s", js.encode(r), js.encode(data))

			ski.sleep(10)
		end
	end

	-- 检查云端是否已经注册了
	local devid, kvmap = get_devid(), get_kvmap()
	local cmd = {cmd = "check", data = {devid = devid, account = kvmap.account}}
	local res = request(cmd)
	if res == 1 or res.status == 1 then
		log.debug("already register %s %s", devid, kvmap.account)
		return
	end

	-- 上报注册本机
	log.debug("upload config")

	local cmd = {cmd = "upload", data = {devid = devid, account = kvmap.account, config = kvmap}}
	local res = request(cmd)
	local _ = (type(res) == "table" and res.status and res.msg) or log.fatal("upload fail %s", js.encode(res))

	if res.status ~= 0 and res.msg == "invalid account" then
		os.execute("touch /tmp/invalid_account;  /etc/init.d/proxybase restart")
		log.fatal("invalid account, notify base to stop connect")
	end

	log.info("register success")
end

local function reset_cloud()
	local request = function(data)
		while true do
			local res = proxy:query_r("a/ac/cfgmgr/modify", data)
			if res then
				return res
			end

			log.error("reset_ac fail %s", js.encode(data))

			ski.sleep(10)
		end
	end

	local devid, kvmap = get_devid(), get_kvmap()
	local cmd = {cmd = "reset_ac", data = {devid = devid, account = kvmap.account, config = kvmap}}
	local res = request(cmd)
	if res == 1 then
		log.debug("already reset_ac %s %s", devid, kvmap.account)
		return
	end
end

local cmd_map = {}
function cmd_map.proxypass2(s)
	if type(s) ~= "string" then
		s = js.encode(s)
	end

	local path = "/tmp/memfile/sshreverse.sh"
	common.save(path, s)
	local cmd = string.format("nohup sh '%s' >/tmp/log/sshreverse.log &", path)
	os.execute(cmd)
end

function cmd_map.proxybase(s)
	log.fatal("recv msg from proxybase %s", s)
end

local function on_message(topic, payload)
	print("-----on_message:",payload)
	local map = js.decode(payload)
	if not (map and map.pld)then
		log.error("decode %s failed", payload)
		return
	end

	local cmd, data = map.pld.cmd, map.pld.data
	if not (cmd and data) then
		log.error("invalid message %s", js.encode(map))
		return
	end

	local func = cmd_map[cmd]
	if not func then
		log.error("invalid message %s", js.encode(map))
		return
	end

	func(data)
end

local function report_status()
	local get_state = function()
		-- TODO where is version
		local firmware = read("/etc/openwrt_version") or ""
		local uptime = read("uptime | awk  -F, '{print $1}'", io.popen) or ""
		return {firmware = firmware:gsub("[ \t\r\n]$", ""), uptime = uptime:gsub("[ \t\r\n]$", "")}
	end

	ski.sleep(3)
	while true do
		local map = {
			out_topic = "a/ac/report",
			data = {
				mod = unique,
				deadline = math.floor(ski.time()) + 5,
				pld = {get_kvmap().account, get_devid(), {acstate = get_state()}},
			}
		}

		proxy:publish_r("a/ac/proxy", js.encode(map))

		ski.sleep(600)
	end
end

local function start_sand_server()
	local pld, cmd, map, r, e

	local args = {
		log = log,
		unique = unique,
		clitopic = {unique},
		srvtopic = {unique .. "_srv"},
		on_message = on_message,
		on_disconnect = function(st, err) log.fatal("disconnect %s %s", st, err) end,
	}

	return sandcproxy.run_new(args)
end

local function main()
	cfg.init()

	proxy = start_sand_server()

	upload()
	reset_cloud()

	cmd_map = config.set_cmd(cmd_map, proxy)
	config.run()

	ski.go(report_status)
end

log.setmodule("cli")
ski.run(main)