require("global")
local se = require("se")
local log = require("log")
local lfs = require("lfs")
local common = require("common")
local js = require("cjson.safe")
local sandc = require("sandclient")
local const = require("constant")
local defaultcfg = require("defaultcfg")

local cfgpath = "/etc/config/cloud.json"
local read, save, save_safe = common.read, common.save, common.save_safe
local g_kvmap, g_devid = {}

local mqtt

-- 读取本唯一ID
local function read_id()
	local id = read("ifconfig eth0 | grep HWaddr | awk '{print $5}'", io.popen):gsub("[ \t\n]", ""):lower() assert(#id == 17)
	g_devid = id
end

local function upload()
	local register_topic = "a/ac/cfgmgr/register"
	local request = function(data)
		while true do
			local res = mqtt:request(register_topic, data)
			if res ~= nil then
				return res
			end
			log.error("register fail %s %s", js.encode(res), js.encode(data))
			se.sleep(10)
		end
	end

	local cmd = {cmd = "check", data = {devid = g_devid, account = g_kvmap.account}}
	local res = request(cmd)
	if res == 1 then
		log.debug("already register %s %s", g_devid, g_kvmap.account)
		return
	end

	log.debug("upload config")
	local cmd = {cmd = "upload", data = {devid = g_devid, account = g_kvmap.account, config = g_kvmap}}
	local res = request(cmd)
	local _ = (type(res) == "table" and res.status and res.msg) or log.fatal("upload fail %s", js.encode(res))
	if res.status ~= 0 and res.msg == "invalid account" then
		os.execute("touch /tmp/invalid_account;  /etc/init.d/base restart")
		log.fatal("invalid account, notify base to stop connect")
	end
	log.info("register success")
end

local function reset_cloud()
	local request = function(data)
		while true do
			local res = mqtt:request("a/ac/cfgmgr/modify", data)
			if res ~= nil then
				return res
			end
			log.error("reset_ac fail %s", js.encode(data))
			se.sleep(10)
		end
	end
	local cmd = {cmd = "reset_ac", data = {devid = g_devid, account = g_kvmap.account, config = g_kvmap}}
	local res = request(cmd)
	if res == 1 then
		log.debug("already reset_ac %s %s", g_devid, g_kvmap.account)
		return
	end
end

local function set_detail()
	g_kvmap.detail = js.encode({major = "ac", minor = "7621"})
end

local function set_default()
	g_kvmap = defaultcfg.default_cloud()
	set_detail()
end

local function load()
	if not lfs.attributes(cfgpath) then
		return set_default()
	end
	local s = read(cfgpath)
	local map = js.decode(s)
	if not map then
		os.remove(cfgpath)
		return set_default()
	end
	g_kvmap = map
	set_detail()
end

local cmd_map = {}
function cmd_map.replace(map)
	local field_map = {account = 1, ac_host = 1, ac_port = 1, descr = 1}
	for k in pairs(map) do
		if not field_map[k] then
			log.error("invalid replace %s", js.encode(map))
			return
		end
	end

	local change, need_exit = false, false
	local check_field = {account = 1, ac_host = 1, ac_port = 1}
	for k, v in pairs(map) do
		local ov = g_kvmap[k]
		if v ~= ov then
			change = true
			if check_field[k] then
				need_exit = true
			end
			log.debug("%s change %s->%s", k, ov, v)
		end
	end

	if not change then
		return
	end

	g_kvmap = map

	do return end
	local s = js.encode(g_kvmap)
	save_safe(cfgpath, s)
	if need_exit then
		os.execute("killstr 'base/main.lua'")
		os.exit(0)
	end
end

local sshreverse_running = false
local proxypass_sh = "/ugw/script/sshreverse.sh"
function cmd_map.proxypass(map)
	if sshreverse_running then
		log.error("sshreverse is already running")
		return
	end

	local respath = "/tmp/sshresult.txt"
	local cmd = string.format("%s '%s' '%s' '%s' '%s' '%s' '%s' '%s' &", proxypass_sh, map.username, map.cloudport, map.localport, map.remote_ip, map.remote_port, map.footprint, respath)
	se.go(function()
		if sshreverse_running then
			return
		end

		os.remove(respath)
		os.execute(cmd)

		local start = se.time()
		sshreverse_running = true
		while true do
			if lfs.attributes(respath) then
				os.remove(respath)
				log.debug("sshreverse use time %s", se.time() - start)
				break
			end
			if se.time() - start > 30 then
				log.error("sshreverse timeout")

				break
			end
			se.sleep(0.3)
		end
		sshreverse_running = false
	end)
end

--config_version.json
local cfg_ver_info = {}
local NORMAL_QUERY_INTVAL = 3600
local EMERGY_QUERY_INTVAL = 60
local query_version_intval = NORMAL_QUERY_INTVAL

local function notify_auth(type)
	log.debug("get new %s package.", type)
end

local function  get_server_ip()
	if g_kvmap and g_kvmap["ac_host"] then
		return g_kvmap["ac_host"]
	end
	return nil
end


local function get_account()
	return g_kvmap and g_kvmap["account"] or "default"
end


local function get_devid()
	if g_devid then
		return g_devid
	end
	return nil
end


local function get_switch()
	return g_kvmap and g_kvmap["switch"] or "1"
end


local function restore_cfg_ver_info()
	if not lfs.attributes(const.default_version) then
		log.fatal("%s isn't exists.", const.default_version)
		return false
	end
	local cmd = string.format("cp -f %s %s", const.default_version, const.config_version)
	if cmd then
		os.execute(cmd)
	end
	log.debug(cmd)
	return true
end

local function check_valid_cfg_ver_info(map)
	if not map then
		return false
	end
	if not (map["ad"] and map["dev"]) then
		return false
	end
	if not (map["ad"]["version"] and map["ad"]["files"]) then
		return false
	end
	if not (map["dev"]["version"] and map["dev"]["files"]) then
		return false
	end

	if #map["ad"]["files"] == 0 then
		return false
	end

	if #map["dev"]["files"] == 0 then
		return false
	end

	return true
end


local function get_cfg_ver_info()
	local cfg_ver_file = const.config_version
	if not lfs.attributes(cfg_ver_file) then
		local ret = restore_cfg_ver_info()
		if not ret then
			log.error("read %s failed.", cfg_ver_file)
			return false
		end
	end
	local s = read(cfg_ver_file)
	if not s then
		log.error("read %s fail.", cfg_ver_file)
		return false
	end
	local map, err = js.decode(s)
	if not map then
		log.fatal("decode %s failed.", cfg_ver_file)
		return false
	end
	if not check_valid_cfg_ver_info(map) then
		log.error("config_version invalid, will restore default_version")
		restore_cfg_ver_info()
		return false
	end
	cfg_ver_info =  map
	--log.debug("cfg_ver_info:%s", js.encode(cfg_ver_info))
	return true
end


local function set_cfg_ver_info()
	local path = const.config_version
	local tmp, del = path .. ".tmp", path .. ".del"

	local s = js.encode(cfg_ver_info)
	s = s:gsub(',"', ',\n"')
	log.debug("update cfg version:%s", s)
	local fp, err = io.open(tmp, "wb")
	local _ = fp or log.fatal("open %s fail %s", tmp, err)

	fp:write(s)
	fp:flush()
	fp:close()

	local cmd = string.format("mv %s %s", tmp, path)
	os.execute(cmd)
	return true
end


local function get_cfg_version(cfg_type)
	if type(cfg_type) ~= "string" then
		local version_map = {}
		if cfg_ver_info then
			version_map["dev"] = cfg_ver_info["dev"] and cfg_ver_info["dev"]["version"]
			version_map["ad"] = cfg_ver_info["ad"] and cfg_ver_info["ad"]["version"]
			return version_map
		end
		return nil
	end
	if cfg_ver_info and cfg_ver_info[cfg_type] and cfg_ver_info[cfg_type]["version"] then
		return cfg_ver_info[cfg_type]["version"]
	end
	log.error("get %s cfg version failed.", cfg_type)
	return nil
end


local function set_cfg_version(cfg_type, version, file_map)
	if not (version and type(cfg_type) == "string" and (cfg_type == "ad" or cfg_type == "dev"))  then
		log.error("set_cfg_version: invalid pars.")
		return false
	end

	cfg_ver_info[cfg_type]["version"] = version

	if file_map then
		for _, file_info in ipairs(cfg_ver_info[cfg_type]["files"]) do
			if file_map[file_info["name"]]  == "1" then
				file_info["exist"] = "1"
			else
				file_info["exist"] = "0"
			end
			log.debug("set exist:%s = %s", file_info["name"], file_map[file_info["name"]])
		end
	end
	set_cfg_ver_info()
	return true
end


local function set_cfg_version_to_default(cfg_type)
	local def_ver = "1970-01-01 00:00:00"
	return set_cfg_version(cfg_type, def_ver)
end


local function get_cfg_files(cfg_type)
	if type(cfg_type) ~= "string" then
		log.error("get_cfg_files: invalid pars.")
		return false
	end
	local file_arr
	if cfg_ver_info and cfg_ver_info[cfg_type]["files"] then
		return cfg_ver_info[cfg_type]["files"]
	end
	return nil
end


--[[
	???????package_dirĿ¼
--]]
local function clear_adcfg()
	local dst_file = const.config_dir.."/"..const.ad_package_file
	local cmd = string.format("rm %s", dst_file)
	if lfs.attributes(dst_file) then
		log.debug("cmd:%s", cmd)
		os.execute("rm "..dst_file)
	end
	return true
end


local function override_adcfg()
	local cmd
	local o_ad = const.config_dir.."/"..const.ad_package_file
	local n_ad = const.package_dir.."/"..const.ad_package_file

	if not lfs.attributes(n_ad) then
		log.debug("%s isn't exist.", n_ad)
		return false
	end

	if lfs.attributes(o_ad) then
		cmd = string.format("mv %s %s", o_ad, o_ad..".".."del")
		os.execute(cmd)
	end

	if lfs.attributes(n_ad) then
		cmd = string.format("mv %s %s", n_ad, o_ad)
		os.execute(cmd)
		log.debug("override_adcfg:%s success.", cmd)
	end

	if lfs.attributes(o_ad..".".."del") then
		os.execute("rm "..o_ad..".".."del")
	end
	os.execute("/ugw/script/resetcfg.sh ad &")
	return true
end


local function get_text_cfg_files()
	local file_map = {}

	for file in lfs.dir(const.text_dir) do
		if file ~= "." and file ~= ".." then
			local f = const.text_dir..'/'..file
			local attr = lfs.attributes (f, "mode")
			if attr.mode ~= "directory" then
				if string.find(file, ".json") then
					file_map[file] = "1"
				end
			end
		end
	end

	return file_map
end


local function override_devcfg()
	local del_files = {}
	local def_files = get_cfg_files("dev")
	local file_map = get_text_cfg_files()
	if not file_map then
		log.debug("there no file in %s.", const.text_dir)
		return false, nil
	end
	if def_files then
		for _, file_info in ipairs(def_files) do
			if file_info["exist"] == "1" and file_info["name"] then
				if lfs.attributes(const.config_dir.."/"..file_info["name"]) then
					local file_name = file_info["name"]
					local cmd = string.format("mv %s %s", file_name, file_name..".".."del")
					os.execute(cmd)
					table.insert(del_files, file_name..".".."del")
				end
			end
		end
	end

	for name, exist in pairs(file_map) do
		local cmd = string.format("mv %s %s", const.text_dir.."/"..name, const.config_dir.."/"..name)
		os.execute(cmd)
	end

	if del_files then
		for _, name in ipairs(del_files) do
			local cmd = string.format("rm %s", const.config_dir.."/"..name)
			os.execute(cmd)
		end
	end

	os.execute("/ugw/script/resetcfg.sh dev &")
	return true, file_map
end


local function commit_notify(cmd)
	if type(cmd) == "string" then
		log.debug("%s notify related process.", cmd)
		notify_auth(cmd)
	end
	--todo restart related process
end


local function get_complete_url(url)
	if type(url) ~= "string" then
		return nil
	end
	if string.find(url, "http:") then
		return url
	end
	local srv_ip = get_server_ip()
	if not srv_ip then
		log.debug("get server ip failed.")
		return nil
	end
	url = "http://"..srv_ip.."/"..url
	return url
end


--data = {subcmd = "GET/KEEP/CLEAR", url = ""/xxx, version = xxx}
local function check_notify_valid(cfg_type, map)
	if type(map) ~= "table" then
		log.debug(" %s cfg invalid pars:nil", cfg_type)
		return false
	end
	if not (map["subcmd"] and map["url"] and map["version"]) then
		log.debug("%s cfg invalid pars:%s", cfg_type, js.encode(map))
		return false
	end
	return true
end


local function process_dlconfig(cfg_type, file_name)
	local timeout, cnt, intval = 240, 0, 2
	local finish, failed = 0, 0
	local file = const.download_dir.."/"..file_name
	local launch_flag = file..".".."launch_flag"
	local finish_flag = file..".".."finish_flag"
	local failed_flag = file..".".."failed_flag"
	while cnt <= timeout do
		if lfs.attributes(finish_flag) then
			os.execute("rm "..finish_flag)
			finish = 1
			break
		elseif lfs.attributes(failed_flag) then
			os.execute("rm "..failed_flag)
			failed = 1
			break
		end
		cnt = cnt + intval
		se.sleep(intval)
	end
	if finish == 1 then
		if cfg_type == "ad" then
			return override_adcfg()
		elseif cfg_type == "dev" then
			return override_devcfg()
		end
	end
	if (finish == 0 and failed == 0) or failed == 1 then
		return false
	end
end


local function process_cfg_notify(cfg_type, map)
	local valid = check_notify_valid(cfg_type, map)
	if not valid then
		return false
	end
	log.debug("recv %scfg_notify which subcmd is %s.", cfg_type, map["subcmd"])

	local version = get_cfg_version(cfg_type)
	if not version then
		return false
	end
	log.debug("current %scfg version:%s", cfg_type, version)

	if version == map["version"] then
		log.debug("cur_%s[%s] == notify_ver[%s], ignore.", cfg_type, version, map["version"])
		return true
	end

	if map["subcmd"] == "KEEP" then
		return true
	end

	if map["subcmd"] == "GET" then
		local url = get_complete_url(map["url"])
		if not url then
			log.error("construct url failed.")
			return false
		end
		log.debug("package url:%s", url)

		local file_name = string.match(url, ".+/([^/]*%.%w+)$")
		if not file_name then
			return false
		end
		log.debug("package name:%s", file_name)

		--keep singleton
		os.execute("killstr dlconfig.lua")
		local cmd = string.format("nohup lua ./dlconfig.lua %s %s %s >/tmp/ugw/log/apmgr.error 2>&1 &", url, file_name, cfg_type)
		os.execute(cmd)
		local ret, file_map = process_dlconfig(cfg_type, file_name)
		if not ret then
			log.debug("subcmd[%s] process failed.", map["subcmd"])
			os.execute("killstr dlconfig.lua")
			return false
		end

		if cfg_type == "ad" then
			set_cfg_version("ad", map["version"], {["ad.tgz"] = "1" })
		elseif cfg_type == "dev" then
			set_cfg_version("dev", map["version"], file_map)
		end
		commit_notify(cfg_type)
		log.debug("subcmd[%s] process success.", map["subcmd"])
		return  true
	end

	if map["subcmd"] == "CLEAR" then
		if cfg_type == "ad" then
			if clear_adcfg() then
				set_cfg_version("ad", map["version"], {["ad.tgz"] = "0" })
			end
		end
		commit_notify(cfg_type)
		log.debug("subcmd[%s] process success.", map["subcmd"])
		return true
	end

	log.debug("subcmd[%s] nonsupport.", map["subcmd"])
	return false
end


function cmd_map.devcfg_notify(map)
	local switch = get_switch()
	if switch ~= "1" then
		return
	end
	local ret = process_cfg_notify("dev", map)
	if ret then
		query_version_intval = NORMAL_QUERY_INTVAL
	else
		query_version_intval = EMERGY_QUERY_INTVAL
	end

end


function cmd_map.adcfg_notify(map)
	local switch = get_switch()
	if switch ~= "1" then
		return
	end
	local ret = process_cfg_notify("ad", map)
	if ret then
		query_version_intval = NORMAL_QUERY_INTVAL
	else
		query_version_intval = EMERGY_QUERY_INTVAL
	end
end


--[[
	???Ҫ?????evcfg??dcfg;
	??devcfg??????basic(ap_config.json), sms, wx, user?? ????ĸ???,ͳһ?devcfg_version
	??adcfg?adcfg_version
--]]
local function send_query_version_req()
	local ret = get_cfg_ver_info()
	local devid = get_devid()
	local account = get_account()
	if ret and devid and account then
		local version_map = get_cfg_version()
		if not version_map then
			version_map = {["ad"] = "1970-01-01 00:00:00", ["dev"]="1970-01-01 00:00:00"}
		end

		mqtt:request("a/ac/query/version", {["account"] = account, ["devid"] = devid, ["version"] = version_map}, 1)
	end
end


local function query_cfg_version()
	while true do
		local switch = get_switch()
		if switch == "1" then
			send_query_version_req()
		end

		se.sleep(query_version_intval)
	end
end


local function on_message(map)
	local cmd, data = map.cmd, map.data
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

local function connect_mqtt()
	mqtt = sandc.new()
	mqtt:set_callback("on_message", on_message)
	mqtt:run()
end

local function check_cfg_change()
	local lasttime
	local check_field = {account = 1, ac_host = 1, ac_port = 1}
	while true do
		local attr = lfs.attributes(cfgpath)
		if attr then
			if not lasttime then
				lasttime = attr.modification
			else
				lasttime = attr.modification
				local s = read(cfgpath)
				local map = js.decode(s) 	assert(map)
				for k, v in pairs(map) do
					if check_field[k] and v ~= g_kvmap[k] then
						log.debug("field change %s %s %s. kill base, exit and reload", k, g_kvmap[k], v)
						os.execute("killstr 'base/main.lua'")
						os.exit(0)
					end
				end
			end
		end
		se.sleep(1)
	end
end


--todo??С???ָ?????ȣ??ad??devΪ??λ?????ǻָ???
local function check_cfg_version()
	local timeout = 300
	local file_dir, continue = const.config_dir, true

	local func = function(cfg_type, info)
		for _, file_info in ipairs(info["files"]) do
			if file_info["exist"] == "1" then
				if not lfs.attributes(file_dir.."/"..file_info["name"]) then
					log.error("%s isn't exist, need restore.", file_info["name"])
					restore_cfg_ver_info()
					--set_cfg_version_to_default(cfg_type)
					return false
				end
			end
		end
		return true
	end

	while true do
		local switch = get_switch()
		if switch == "1" then
			local ret = get_cfg_ver_info()
			if ret then
				for type, info in pairs(cfg_ver_info) do
					if not func(type, info) then
						send_query_version_req()
						break
					end
				end
			end
		end
		se.sleep(timeout)
	end
end


local function report_status()
	local get_state = function()
		local firmware = read("/etc/openwrt_version") or ""
		local uptime = read("uptime | awk  -F, '{print $1}'", io.popen) or ""
		return {firmware = firmware:gsub("[ \t\r\n]$", ""), uptime = uptime:gsub("[ \t\r\n]$", "")}
	end

	se.sleep(3)
	while true do
		local map = {
			out_topic = "a/ac/report",
			data = {
				mod = "a/local/cloudcli",
				deadline = math.floor(se.time()) + 5,
				pld = {g_kvmap.account, g_devid, {acstate = get_state()}},
			},
		}
		mqtt:publish("a/ac/proxy", js.encode(map))
		se.sleep(600)
	end
end

local function main()
	read_id()
	connect_mqtt()
	load()
	upload()
	reset_cloud()
	se.go(report_status)
	se.go(query_cfg_version)
	se.go(check_cfg_version)
	se.go(check_cfg_change)
end

log.setmodule("cm")
log.setdebug(true)
se.run(main)