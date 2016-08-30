local js = require("cjson.safe")
local common = require("common")
local cfgpath = "/etc/config/cloud.json"

local read, save_safe = common.read, common.save_safe
local firmware_detail = js.encode({major = "ac", minor = "9563"})

local g_kvmap, g_devid

-- 读取本唯一ID TODO
local function read_id()
	local id = read("ifconfig eth0 | grep HWaddr | awk '{print $5}'", io.popen):gsub("[ \t\n]", ""):lower() assert(#id == 17)
	g_devid = id
end

local function set_default()
	-- TODO
	g_kvmap = {account = "yjs", ac_host = "", ac_port = 61889, detail = firmware_detail}
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
		return set_default()
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
	set_default = set_default,
	get_devid = get_devid,
	get_kvmap = get_kvmap,
	set_kvmap = set_kvmap
}