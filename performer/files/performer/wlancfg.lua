-- @author : xjx modify
-- @wlancfg.lua : 生效WLAN、Radio配置

local uci	= require("uci")
local ski	= require("ski")
local log	= require("log")
local pkey	= require("key")
local md5 	= require("md5")
local common	= require("common")
local country	= require("country")
local support	= require("support")
local version	= require("version")
local const		= require("constant")
local js		= require("cjson.safe")

js.encode_keep_buffer(false)

local tcp_map = {}
local wifi_dev_cfg = {}
local wifi_iface_cfg = {}
local custom_wifi_dev_cfg = {}
local read = common.read
local keys = const.keys
local s_const = {
	config		= "wireless",
	iface_t		= "wifi-iface",
	dev_t		= "wifi-device",
	custome_t	= "userdata",
	custome_n	= "stat",
	vap2g		= "ath2%03d",
	vap5g		= "ath5%03d",
}

local function get_channel(v)
	if v:upper() == "AUTO" then
		return "auto"
	end

	return v
end

local function get_power(v)
	if v:upper() == "AUTO" then
		return 31	--max power
	end
	v = tonumber(v)

	return tonumber(v)
end

local function get_hwmode(v, band)
	if v == "bgn" then
		return "11ng"
	end

	if v == "bg" or v == "b" or v == "g" then
		return "11g"
	end

	if v == "an" then
		return "11na"
	end

	if v == "a" then
		return "11na"
	end

	if v == "n" then
		if band == "2g" then
			return "11ng"
		else
			return "11na"
		end
	end

	return nil, "get_hwmode nil"
end

local function get_htmode(v, band)
	local valid, hw_version = version.get_hw_version()
	if not valid then
		return nil, "valid nil"
	end

	local wd = "20"
	if v:upper() == "AUTO" then
		wd = "20"	--todo, need impletemnting real auto
	elseif v == "20" then
		wd = "20"
	elseif v == "40-" or v == "40+" then
		wd = "40"
	elseif v == "80" then
		wd = "80"
	end

	--in 2g suituation, we just process	directly
	if band == "2g" then
		if wd == "20" or wd == "40" then
			return "HT"..wd
		end
		return nil, "wd nil"
	end

	--in 5g situation, we should distinguish 5g and 11ac
	local proto = support.get_5g_proto(hw_version)
	log.debug("proto：%s,%s", proto, wd)
	if proto == "5g" then
		return "HT"..wd
	elseif proto == "11ac" then
		--updating temporary
		if wd == "40" or wd == "20" then
			return "HT"..wd
		else
			return "VHT"..wd
		end
	else
		return nil, "proto nil"
	end
end

local function  construct_rate(band, rf_mode, rate)
	local rf_mode_type = 0
	if band == "2g" then
		if rf_mode == "bg" or rf_mode =="b" or rf_mode == "g" then
			rf_mode_type = 3
		elseif rf_mode == "bgn" or rf_mode == "n" then
			rf_mode_type = 5
		else
			log.debug("invalid rf_mode:%s", rf_mode)
		end
	else
		if rf_mode == "a" or rf_mode =="n" or rf_mode == "an" then
			rf_mode_type = 7
		else
			log.debug("invalid rf_mode:%s", rf_mode)
		end
	end

	rf_mode_type = rf_mode_type * 256
	if band == "2g" then
		rf_mode_type = rf_mode_type + 4096
	else
		rf_mode_type = rf_mode_type + 8192
	end
	rf_mode_type = rf_mode_type + rate

	return rf_mode_type
end

local function get_rs_rate(v)
	if not v then
		return "0"
	end
	if v == "0" then
		return "0"
	elseif v == "2" then
		return "2"
	elseif v == "4" then
		return "4"
	elseif v == "11" then
		return "11"
	end

	return "0"
end

--config items of wifi device
local function wifi_dev_cfg_parse(map)
	log.debug("%s", "wifi_dev_cfg_parse ---")
	local k , v, dev, kvmap
	wifi_dev_cfg = {}
	log.debug("support:%s", js.encode(support.band_arr_support()))
	for _, band in ipairs(support.band_arr_support()) do
		kvmap = {}
		log.debug("band:%s", band)
		dev = support.get_wifi_dev(band)

		local k = pkey.short(keys.c_g_country)

		local v = country.short(map[k])  	assert(v)
		kvmap["country"] = v

		k = pkey.short(keys.c_proto, {BAND = band})
		v = get_hwmode(map[k], band)			assert(v)
		kvmap["hwmode"] = v 		--11b, 11g, 11a

		k = pkey.short(keys.c_bandwidth, {BAND = band})
		v = get_htmode(map[k], band) 		assert(v)
		kvmap["htmode"] = v
		k = pkey.short(keys.c_chanid, {BAND = band})
		v = get_channel(map[k]) 		assert(v)
		kvmap["channel"] = v

		k = pkey.short(keys.c_power, {BAND = band})
		v = get_power(map[k]) 			assert(v)
		kvmap["txpower"] = v

		k = pkey.short(keys.c_ag_rs_rate)
		v = tonumber(get_rs_rate(map[k]))  	assert(v)
		kvmap["rs_rate"] = v

		k = pkey.short(keys.c_ag_rs_switch)
		v = tonumber(map[k]) 	assert(v)
		kvmap["rs_switch"] = v

		k = pkey.short(keys.c_rs_inspeed)
		v = tonumber(map[k]) 	assert(v)
		kvmap["rs_inspeed"] = v


		k = pkey.short(keys.c_ag_rs_mult)
		v = map[k]	assert(v)
		kvmap["rs_mult"] = v or "0"

		k = pkey.short(keys.c_proto, {BAND = band})
		local rf_mode = map[k] assert(rf_mode)
		custom_wifi_dev_cfg[dev] = {
				["rs_rate"] = construct_rate(band, rf_mode, kvmap["rs_rate"]),
				["rs_switch"] = kvmap["rs_switch"],
				["rs_mult"] = kvmap["rs_mult"],
				["rs_inspeed"] = construct_rate(band, rf_mode, kvmap["rs_inspeed"]),
			}

		wifi_dev_cfg[dev] = kvmap
	end
	log.debug("wifi_dev_cfg:%s",js.encode(wifi_dev_cfg))
	log.debug("custom_wifi_dev_cfg:%s",js.encode(custom_wifi_dev_cfg))
	return true
end

local function get_cw_coext(v, band)
	local valid, hw_version = version.get_hw_version()
	if not valid then
		return nil, "valid nil"
	end
	local wd = "20"
	if v:upper() == "AUTO" then
		return 0, 0
	elseif v == "20" then
		return 0, 0
	elseif v == "40-" or v == "40+" then
		return 0, 1
	elseif v == "80" then
		return 0, 1
	end
end

-- config items of vap
local function wifi_iface_cfg_parse(map)
	local k, v, kvmap

	wifi_iface_cfg = {}
	k = pkey.short(keys.c_wlanids)
	if not (type(map[k]) == "table") then
		map[k] = js.decode(map[k])
	end

	for _, wlanid in ipairs(map[k]) do
		kvmap = {}

		kvmap["wlanid"] = tonumber(wlanid)

		k = pkey.short(keys.c_wband, {WLANID = wlanid})
		v = map[k]						assert(v)
		kvmap["type"] = v == "2g" and 1 or (v == "5g" and 2 or 3)

		k = pkey.short(keys.c_wstate, {WLANID = wlanid})
		v = tonumber(map[k]) 			assert(v)
		if v == 0 then
			kvmap["disabled"] = 1
		else
			kvmap["disabled"] = 0
		end

		k = pkey.short(keys.c_whide, {WLANID = wlanid})
		v = tonumber(map[k]) 			assert(v)
		kvmap["hidden"] = v

		k = pkey.short(keys.c_wssid, {WLANID = wlanid})
		v = map[k]						assert(v)
		kvmap["ssid"] = v

		k = pkey.short(keys.c_wnetwork, {WLANID = wlanid})
		v = map[k]						assert(v)
		kvmap["network"] = v

		k = pkey.short(keys.c_wencry, {WLANID = wlanid})
		v = map[k]						assert(v)
		kvmap["encryption"] = v

		k = pkey.short(keys.c_wpasswd, {WLANID = wlanid})
		v = map[k] or "none"						assert(v)
		kvmap["key"] = v

		--2g_maxassoc, 5g_maxassoc for support 2g&5g ssids have different max stas
		local bands = {}
		if kvmap["type"] == 1 then
			table.insert(bands, "2g")
		elseif kvmap["type"] == 2 then
			table.insert(bands, "5g")
		else
			table.insert(bands, "2g")
			table.insert(bands, "5g")
		end

		for _, band in ipairs(bands) do
			local maxassoc = band .. "maxassoc"
			k = pkey.short(keys.c_usrlimit, {BAND = band})
			v = tonumber(map[k])	assert(v)
			kvmap[maxassoc] = v

			k = pkey.short(keys.c_bandwidth, {BAND = band})
			local v1, v2 = get_cw_coext(map[k], band)
			kvmap[band .. "cwmenable"] = v1
			kvmap[band .. "disablecoext"] = v2

		end

		--for history reason, compatibility need be considered
		k = pkey.short(keys.c_rs_iso)
		v = tonumber(map[k])
		if not v then
			kvmap["isolate"] = 0
		else
			if v > 0 then
				kvmap["isolate"] = 0
			else
				kvmap["isolate"] = 1
			end
		end

		wifi_iface_cfg[wlanid] = kvmap
	end

	log.debug("wifi_iface_cfg:%s",js.encode(wifi_iface_cfg))
	return true
end

local function wl_cfg_parse(map)
	local ret =  wifi_dev_cfg_parse(map)
	if not ret then
		return false
	end

	ret = wifi_iface_cfg_parse(map)
	if not ret then
		return false
	end

	return true
end

local function generate_wlancfg_cmds()
	local arr = {}
	arr["wireless"] = {}
	local cnt_2g, cnt_5g, t = 0, 0, 0
	local vap_name = "vap"	-- vap2001, vap5002
	local userdata = {}
	local band_support = support.band_map_support()
	local dev_2g = support.get_wifi_dev("2g")
	local dev_5g = support.get_wifi_dev("5g")

	-- del
	local s  = read("cat /etc/config/wireless | grep wifi-iface | wc -l", io.popen)
	if not s then
		return
	end
	local num = tonumber(s) or 0
	if num > 0 then
		local idx = num - 1
		for i = 1, num do
			table.insert(arr["wireless"], string.format("uci delete wireless.@wifi-iface[%d]", idx))
			idx = idx - 1
		end
	end

	-- create wifi dev
	for _, band in ipairs(support.band_arr_support()) do
		local wifi_dev, cfg_map
		wifi_dev = support.get_wifi_dev(band)
		cfg_map = wifi_dev_cfg[wifi_dev]
		if cfg_map then
			log.debug("create section:%s",wifi_dev)
			table.insert(arr["wireless"], string.format("uci set wireless.%s=%s", wifi_dev, s_const.dev_t))
			table.insert(arr["wireless"], string.format("uci set wireless.%s.country=%s", wifi_dev, cfg_map["country"]))
			table.insert(arr["wireless"], string.format("uci set wireless.%s.hwmode=%s", wifi_dev, cfg_map["hwmode"]))
			table.insert(arr["wireless"], string.format("uci set wireless.%s.htmode=%s", wifi_dev, cfg_map["htmode"]))
			table.insert(arr["wireless"], string.format("uci set wireless.%s.channel=%s", wifi_dev, cfg_map["channel"]))
			table.insert(arr["wireless"], string.format("uci set wireless.%s.txpower=%d", wifi_dev, cfg_map["txpower"]))
			table.insert(arr["wireless"], string.format("uci set wireless.%s.noscan=1", wifi_dev))
			table.insert(arr["wireless"], string.format("uci set wireless.%s.dcs_enable=0", wifi_dev))
		end
	end

	-- create wifi iface
	for _, if_cfg in pairs(wifi_iface_cfg) do
		local wifi_devs = {}
		if if_cfg.type == 1 then
			if band_support["2g"] then
				table.insert(wifi_devs, dev_2g)
			end
		elseif if_cfg.type == 2 then
			if band_support["5g"] then
				table.insert(wifi_devs, dev_5g)
			end
		elseif if_cfg.type == 3 then
			if band_support["2g"] then
				table.insert(wifi_devs, dev_2g)
			end
			if band_support["5g"] then
				table.insert(wifi_devs, dev_5g)
			end
			log.debug("dev_2g:%s , dev_5g:%s", dev_2g, dev_5g)
		end
		log.debug("vap:%s , type:%s", if_cfg.ssid, if_cfg.type)
		for _, dev in ipairs(wifi_devs) do
			local band
			if dev == dev_2g then
				vap_name = string.format(s_const.vap2g, cnt_2g)
				cnt_2g = cnt_2g + 1
				band = "2g"
			else
				vap_name = string.format(s_const.vap5g, cnt_5g)
				cnt_5g = cnt_5g + 1
				band = "5g"
			end
			local idx = -1

			table.insert(arr["wireless"], string.format("uci add wireless wifi-iface"))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].device='%s'", dev))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].disabled='%d'", if_cfg["disabled"]))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].hidden='%d'", if_cfg["hidden"]))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].ssid='%s'", if_cfg["ssid"]))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].encryption='%s'", if_cfg["encryption"]))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].key='%s'", if_cfg["key"]))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].mode='ap'"))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].maxsta='%d'", if_cfg[band.."maxassoc"]))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].isolate='%d'", if_cfg["isolate"]))
			table.insert(arr["wireless"], string.format("uci set wireless.@wifi-iface[-1].cwmenable='%d'", if_cfg[band.."cwmenable"]))
			table.insert(arr["wireless"],  string.format("uci set wireless.@wifi-iface[-1].disablecoext='%d'", if_cfg[band.."disablecoext"]))

			-- 判断 network
			t = read("uci show network |grep interface|grep lan", io.popen)
			if not string.find(t, if_cfg["network"]) then
				if string.find(t, "lan1") then
					if_cfg["network"] = "lan1"
				elseif string.find(t, "lan2") then
					if_cfg["network"] = "lan2"
				elseif string.find(t, "lan3") then
					if_cfg["network"] = "lan3"
				elseif string.find(t, "lan4") then
					if_cfg["network"] = "lan4"
				end
			end

			table.insert(arr["wireless"],  string.format("uci set wireless.@wifi-iface[-1].network='%s'", if_cfg["network"]))
		end
		wifi_devs = {}
	end

	return arr
end

-- 判断md5值
local function wl_cfg_commit()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}

	arr["wireless"] = {}
	arr_cmd["wireless"] = {
		string.format("uci commit network"),
		string.format("uci commit wireless"),
		string.format("wifi reload_legacy"),
		string.format("/etc/init.d/network reload")
	}

	local wlancfg_arr = generate_wlancfg_cmds()

	for name, cmd_arr in pairs(arr) do
		for _, line in ipairs(wlancfg_arr[name]) do
			table.insert(cmd_arr, line)
		end

		cmd = table.concat(cmd_arr, "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = read(string.format("uci get %s.@version[0].wlancfg_md5 2>/dev/null | head -c32", name), io.popen)
		log.debug("new_md5:%s , old_md5:%s", new_md5, old_md5)

		if new_md5 ~= old_md5 then
			log.debug("new_md5 ~= old_md5")
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].wlancfg_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end
			cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end

local function reset(nmap)
	local ret
	ret = wl_cfg_parse(nmap)
	if not ret then
		return
	end

	wl_cfg_commit()
end

local function get_new_cfg()
	local path = "/etc/config/wireless.json"
	local s = read(path)
	if not s then
		log.error("read %s fail", path)
		return
	end

	local map = js.decode(s)
	local _ = map or log.error("parse %s fail", path)
	return map
end

local function reload_cfg()
	local nmap = get_new_cfg()
	if nmap then
		reset(nmap)
	end
end

local function init()
	support.init_band_support()
	reload_cfg()
	return true
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd.data)
	end
end

tcp_map["wlancfg"] = function(p)
	reload_cfg()
end

return {init = init, dispatch_tcp = dispatch_tcp}