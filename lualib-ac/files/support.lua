local log = require("log")
local uci = require("uci")
local version = require("version")
local js = require("cjson.safe")
local common = require("common")

local read = common.read
local s_const = {
	wl_cfg = "wireless",
	dev0 = "wifi0",
	dev1 = "wifi1",
	iface0 = "ath0",
	iface1 = "ath1",
	macaddr = "macaddr", --type name of dev path in wifi-device section
	wl_cfg_path = "/etc/config/wireless"
}


--define dev_5g proto:[dev1] = "11ac", ["dev2"] = "5g"
local dev_5g_proto_map = {
	["LG9563"] = "11ac",
	--new dev add here
}

local wl_uci
--["2g"] = "radioN", ["5g"] = "radioM"
local s_band_dev_map = {}
local s_band_iface_map = {}
local g_band_support = {}
local s_support_num = 1


local function init()
	wl_uci = uci.cursor()
	if not wl_uci then
		log.error("wl uci init failed")
		return false
	end
	return true
end


local function get_support_num()
	local s = read("iw list | grep Wiphy | wc -l", io.popen)
	if not s then
		log.error("Get wireless devs list failed.")
		return false
	end
	local num = tonumber(s)
	if not num then
		log.error("Get wireless devs list failed.")
		return false
	end
	s_support_num = num
	return true
end

--des: constructing map between wifi devices and "2g&5g"; wifi-ifaces and "3g&5g"
local function do_band_dev_map()
	print("do_band_dev_map")
	local dev0 = wl_uci:get(s_const.wl_cfg, s_const.dev0, s_const.macaddr)
	local dev1 = wl_uci:get(s_const.wl_cfg, s_const.dev1, s_const.macaddr)
	--print(dev0, dev1)
	if dev0 then
		s_band_dev_map["2g"] = s_const.dev0
		s_band_iface_map["2g"] = s_const.iface0
	end
	if dev1 then
		s_band_dev_map["5g"] = s_const.dev1
		s_band_iface_map["5g"] = s_const.iface1
	end

	--print("band_dev_map:", js.encode(s_band_dev_map))
	--print("band_iface_map:", js.encode(s_band_iface_map))
	--log.debug("support map:%s", js.encode(s_band_dev_map))

	return true
end

--dev map iface
local function init_band_support()
	g_band_support = {}
	if not init() then
		return false
	end

	if not do_band_dev_map() then
		return false
	end

	if s_band_dev_map["2g"] then
		g_band_support["2g"] = 1
	end

	if s_band_dev_map["5g"] then
		g_band_support["5g"] = 1
	end
	return true
end


local function is_support_band(band)
	if g_band_support[band] then
		return true
	end
	return false
end

local function band_arr_support()
	local arr = {}
	for band in pairs(g_band_support) do
		table.insert(arr, band)
	end
	return arr
end

local function band_map_support()
	return g_band_support
end


local function band_map_not_support()
	local not_support_map = {["2g"] = 1, ["5g"] = 1}
	for band in pairs(g_band_support) do
		not_support_map[band] = nil
	end
	return  not_support_map
end

--Input:2g or 5g
--Output: radio0 or radio1
local function get_wifi_dev(band)
	assert(band == "2g" or band == "5g")
	return band == "2g" and s_band_dev_map["2g"] or s_band_dev_map["5g"]
end

--Input:2g or 5g
--Output: wlan0 or wlan1
local function get_base_iface(band)
	assert(band == "2g" or band == "5g")
	return band == "2g" and s_band_iface_map["2g"] or s_band_iface_map["5g"]
end

--Input:hardware version
--Output:5g or 11ac (for compatible)
local function get_5g_proto(hw_version)
	if not hw_version then
		return nil
	end
	return dev_5g_proto_map[hw_version]
end

--Input:wlan0,wlan1,wlan0-1,wlan1-1
--Output:ath2xxx, ath5xxx
local function iface_to_vap(iface)
	local prefix, wlanid
	if not iface then
		log.debug("iface is invalid which is nil")
		return nil
	end
	local iface_2g = get_base_iface("2g")
	local iface_5g = get_base_iface("5g")
	if iface:find(iface_2g) then
		prefix = "ath2%03d"
	elseif iface:find(iface_5g) then
		prefix = "ath5%03d"
	end
	if not prefix then
		log.debug("iface:%s is not invalid(athX or athXX)", iface)
		return nil
	end
	wlanid = iface:match('ath[01](%d+)')
	if wlanid then
		wlanid = tonumber(wlanid)
	else
		wlanid = 0
	end
	--print("iface_to_vap:",iface, wlanid)
	return string.format(prefix, wlanid)
end


--Input:wlan0,wlan1,wlan0-1,wlan1-1
--Output:2g, 5g
local function iface_to_band(iface)
	if not iface then
		return nil
	end
	local iface_2g = get_base_iface("2g")
	local iface_5g = get_base_iface("5g")
	print(iface_2g, iface_5g)
	if iface:find(iface_2g) then
		return "2g"
	elseif iface:find(iface_5g) then
		return "5g"
	end
	return nil
end

return {
	init_band_support = init_band_support,
	band_arr_support = band_arr_support,
	band_map_support = band_map_support,
	band_map_not_support = band_map_not_support,
	get_wifi_dev = get_wifi_dev,
	get_base_iface = get_base_iface,
	get_5g_proto = get_5g_proto,
	iface_to_vap = iface_to_vap,
	iface_to_band = iface_to_band,
	is_support_band = is_support_band,
}
