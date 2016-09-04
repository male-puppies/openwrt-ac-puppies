local js = require("cjson.safe")
local common = require("common")
local const = require("constant")

local cfgpath = const.cloud_config

local read, save_safe = common.read, common.save_safe
local firmware_detail = js.encode({major = "ac", minor = "9531"})

local g_kvmap, g_devid

-- 读取本唯一ID TODO
local function read_id()
	local id = read("ifconfig eth0 | grep HWaddr | awk '{print $5}'", io.popen):gsub("[ \t\n]", ""):lower() assert(#id == 17)
	g_devid = id
end

local function restore_cloud()
	if not lfs.attributes(const.default_cloud_config) then
		log.fatal("%s isn't exists.", const.default_cloud_config)
	return false
	end
	local cmd = string.format("cp -f %s %s", const.default_cloud_config, const.cloud_config)
	if cmd then
	os.execute(cmd)
	end
	log.debug(cmd)
	return true
end

local function set_default()
	g_kvmap = {account = "default", ac_host = "", ac_port = 61889, detail = firmware_detail}
end

local function get_devid()
	return g_devid
end

local function get_kvmap()
	return g_kvmap
end

local function get(k)
	return g_kvmap and g_kvmap[k] or nil
end

local function load()
	if not lfs.attributes(cfgpath) then
		restore_cloud()
	end

	local s = read(cfgpath)
	local map = js.decode(s)
	if not map then
		os.remove(cfgpath)
		return set_default()
	end

	g_kvmap = map
	g_kvmap.detail = firmware_detail
end

local function set_kvmap(m)
	g_kvmap = map
	g_kvmap.detail = firmware_detail
end

local function init()
	read_id()
	load()
end

return {
	get = get,
	init = init,
	restore_cloud = restore_cloud,
	set_default = set_default,
	get_devid = get_devid,
	get_kvmap = get_kvmap,
	set_kvmap = set_kvmap
}