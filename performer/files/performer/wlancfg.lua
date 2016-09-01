-- @author : xjx modify
-- @radio.lua : 生效WLAN、Radio配置

local uci	= require("uci")
local ski	= require("ski")
local log	= require("log")
local lfs	= require("lfs")
local pkey	= require("key")
local common	= require("common")
local country	= require("country")
local support	= require("support")
local memfile	= require("memfile")
local compare	= require("compare")
local version	= require("version")
local const		= require("constant")
local js		= require("cjson.safe")

js.encode_keep_buffer(false)

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

local wl_uci
local dev_cfg_map = "dev_map"
local custom_wifi_dev_cfg = {}
local wifi_dev_cfg = {}
local iface_cfg_map = "iface_map"
local wifi_iface_cfg = {}
local mf_commit = memfile.ins("commit")
local file_exist = common.file_exist

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
	print("proto:", proto, wd)
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
	print("wifi_dev_cfg_parse ---")
	local k , v, dev, kvmap
	wifi_dev_cfg = {}
	print("support:", js.encode(support.band_arr_support()))
	for _, band in ipairs(support.band_arr_support()) do
		kvmap = {}
		print(band)
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
	print("wifi_dev_cfg:",js.encode(wifi_dev_cfg))
	print("custom_wifi_dev_cfg:", js.encode(custom_wifi_dev_cfg))
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
	print("wifi_iface_cfg:", js.encode(wifi_iface_cfg))
	return true
end

--check
local function wl_cfg_valid_check()
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
	ret = wl_cfg_valid_check()
	if not ret then
		return false
	end
	return true
end

local function compare_cfg()
	local change = false
	local o_dev_cfg = mf_commit:get(dev_cfg_map)
	local o_iface_cfg = mf_commit:get(iface_cfg_map)

	for dev, cfg in pairs(wifi_dev_cfg) do
		local o_cfg = o_dev_cfg[dev]
		if not o_cfg then
			change = true
			log.debug("%s add", dev)
		else
			for k, n_item in pairs(cfg) do
				local o_item = o_cfg[k]
				if n_item ~= o_item then
					change = true
					log.debug("%s %s->%s", k, o_item or "", n_item or "")
				end
			end
		end
	end

	for wlanid in pairs(wifi_iface_cfg) do
		if not o_iface_cfg[wlanid] then
			change = true
			log.debug("add %s", wlanid)
		end
	end

	for wlanid in pairs(o_iface_cfg) do
		if not wifi_iface_cfg[wlanid] then
			change = true
			log.debug("del %s", wlanid)
		end
	end

	for wlanid, wlan_cfg in pairs(wifi_iface_cfg) do
		local o_cfg = o_iface_cfg[wlanid]
		if o_cfg then
			for k, n_item in pairs(wlan_cfg) do
				local o_item = o_cfg[k]
				if n_item ~= o_item then
					change = true
					log.debug("%s %s %s->%s", wlanid, k, o_item or "", n_item or "")
				end
			end
		end
	end
	return change
end

----------------------------commit cfg to driver by uci----------------
local function  get_userdata_section()
	 local map = {}
	 map["cnt_2g"] = wl_uci:get(s_const.config, s_const.custome_n, "cnt_2g") or 0
	 map["cnt_5g"] = wl_uci:get(s_const.config, s_const.custome_n, "cnt_5g") or 0
	 return map
end

local function set_userdata_section(map)
	wl_uci:set(s_const.config, s_const.custome_n, s_const.custome_t)
	wl_uci:set(s_const.config, s_const.custome_n, "cnt_2g",  map["cnt_2g"] or 0)
	wl_uci:set(s_const.config, s_const.custome_n, "cnt_5g",  map["cnt_5g"] or 0)
	return true
end

local function  del_ano_wifi_iface_sections()
	local s  = read("cat /etc/config/wireless | grep wifi-iface | wc -l", io.popen)
	if not s then
		return
	end
	local num = tonumber(s) or 0
	if num > 0 then
		local idx = num - 1
		for i = 1, num do
			local cmd = string.format("uci delete wireless.@wifi-iface[%d]", idx)
			print("cmd:", cmd)
			os.execute(cmd)
			idx = idx - 1
		end
		print("del ", num, "ano vaps totally.")
	end
	os.execute("uci commit wireless")
end

local function create_wifi_dev_sections()
	for _, band in ipairs(support.band_arr_support()) do
		local wifi_dev, cfg_map

		wifi_dev = support.get_wifi_dev(band)
		print("wifi:",wifi_dev)
		cfg_map = wifi_dev_cfg[wifi_dev]
		if cfg_map then
			print("create section ", wifi_dev)
			local cmds ={}
			cmds["dev"] = string.format("uci set wireless.%s=%s", wifi_dev, s_const.dev_t)
			cmds["country"] = string.format("uci set wireless.%s.country=%s", wifi_dev, cfg_map["country"])
			cmds["hwmode"] = string.format("uci set wireless.%s.hwmode=%s", wifi_dev, cfg_map["hwmode"])
			cmds["htmode"] = string.format("uci set wireless.%s.htmode=%s", wifi_dev, cfg_map["htmode"])
			cmds["channel"] = string.format("uci set wireless.%s.channel=%s", wifi_dev, cfg_map["channel"])
			cmds["txpower"] = string.format("uci set wireless.%s.txpower=%d", wifi_dev, cfg_map["txpower"])
			cmds["noscan"] = string.format("uci set wireless.%s.noscan=1", wifi_dev)
			cmds["dcs_enable"] = string.format("uci set wireless.%s.dcs_enable=0", wifi_dev)
			for key, cmd in pairs(cmds) do
				os.execute(cmd)
			end
		end
	end
	os.execute("uci commit wireless")
	print("create_wifi_dev_sections")
end

local function create_wifi_iface_sections()
	local cnt_2g, cnt_5g, t = 0, 0, 0
	local vap_name = "vap"	-- vap2001, vap5002
	local userdata = {}
	local band_support = support.band_map_support()
	local dev_2g = support.get_wifi_dev("2g")
	local dev_5g = support.get_wifi_dev("5g")

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
			print(dev_2g, dev_5g)
		end
		print("vap:", if_cfg.ssid, "type:", if_cfg.type)
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
			print("create vap:", vap_name)
			local idx = -1
			local cmds = {}

			table.insert(cmds, string.format("uci add wireless wifi-iface"))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].device='%s'", dev))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].disabled='%d'", if_cfg["disabled"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].hidden='%d'", if_cfg["hidden"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].ssid='%s'", if_cfg["ssid"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].encryption='%s'", if_cfg["encryption"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].key='%s'", if_cfg["key"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].mode='ap'"))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].maxsta='%d'", if_cfg[band.."maxassoc"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].isolate='%d'", if_cfg["isolate"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].cwmenable='%d'", if_cfg[band.."cwmenable"]))
			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].disablecoext='%d'", if_cfg[band.."disablecoext"]))

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

			table.insert(cmds, string.format("uci set wireless.@wifi-iface[-1].network='%s'", if_cfg["network"]))
			--must excuting in order, so we using queue rather than map
			for i, cmd in ipairs(cmds) do
				os.execute(cmd)
			end

		end
		wifi_devs = {}
	end

	os.execute("uci commit wireless")
	os.execute([[
			vlans=`uci show wireless | grep network | grep -o "vlan[0-9]*" | sed 's/$/e/g'`
			uci show network | grep interface | grep -o "vlan[0-9]*" | while read line; do
				echo $vlans | grep -q ${line}e || uci delete network.$line
			done]])
	os.execute("uci commit network")
	set_userdata_section({["cnt_2g"] = cnt_2g, ["cnt_5g"] = cnt_5g})
	print("create_wifi_iface_sections")
end

local function commit_to_file()
	os.execute("uci commit wireless")	--save to /etc/config/wireless
	print("commit_to_file")
end

local function is_valid_iface(iface)
	local cmd = string.format("ifconfig %s 2>/dev/null | grep %s", iface, iface)
	local s = read(cmd, io.popen)
	if  s and s:find(iface) then
		return true
	end
	log.debug("%s invalid", iface)
	return false
end

local function commit_to_driver()
	os.execute("wifi")
	ski.sleep(2)
	os.execute("/etc/init.d/network reload")
	print("commit to driver")
end

local function wl_cfg_commit()
	del_ano_wifi_iface_sections()
	create_wifi_dev_sections()
	create_wifi_iface_sections()
	commit_to_file()
	commit_to_driver()
end

local function  save_cfg_to_memfile()
	mf_commit:set(dev_cfg_map, wifi_dev_cfg):save()
	mf_commit:set(iface_cfg_map, wifi_iface_cfg):save()

	return true
end

local function reset(nmap)
	local ret

	ret = wl_cfg_parse(nmap)
	if not ret then
		return
	end

	ret = compare_cfg()
	if not ret then
		log.debug("%s", "*** wireless config nothing change")
		return
	end

	wl_cfg_commit()
	save_cfg_to_memfile()
	log.debug("%s", "commit ok")
	local map = {radio = wifi_dev_cfg, wlan = wifi_iface_cfg}
end

function lua_print_callback(s)
	log.fromc(s)
end

local function check(nmap)
	local res
	res = mf_commit:get(dev_cfg_map) or mf_commit:set(dev_cfg_map, {["radio0"] = {}, ["radio1"] = {}}):save()
	res = mf_commit:get(iface_cfg_map) or mf_commit:set(iface_cfg_map, {}):save()
	reset(nmap)
end

local function create_debugsw_flag(debug_flag)
	local cmd = ""
	local debug_dir = const.ap_debug_dir
	debug_flag = debug_dir .. debug_flag
	cmd = string.format("test -e %s || mkdir -p %s", debug_dir, debug_dir) assert(cmd)
	os.execute(cmd)
	cmd = string.format("test -e %s || touch %s", debug_flag, debug_flag) assert(cmd)
	os.execute(cmd)
end

local function del_debugsw_flag(debug_flag)
	local cmd =""
	debug_flag = const.ap_debug_dir .. debug_flag
	cmd = string.format("test -e %s && rm %s;", debug_flag, debug_flag) assert(cmd)
	os.execute(cmd)
end

local function get_debug_sw(v)
	if v and v == "enable" then
		return true
	else
		return false
	end
end

local function set_debug_flag(nmap)
	local cmd
	local debug_file = const.ap_debug_flag
	local k_arr = {}
	table.insert(k_arr, keys.c_g_debug)
	table.insert(k_arr, keys.c_g_ledctrl)
	table.insert(k_arr, keys.c_g_abncheck)
	for _, debug_key in ipairs(k_arr) do
		local k = pkey.short(debug_key) assert(k)
		local v = get_debug_sw(nmap[k])
		if v then
			create_debugsw_flag(debug_key)
		else
			del_debugsw_flag(debug_key)
		end
	end
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
		set_debug_flag(nmap)
		check(nmap)
	end

end

local function init()
	support.init_band_support()
	wl_uci = uci.cursor(nil, "/var/state")

	if not wl_uci then
		log.error("wl uci init failed")
		return false
	end

	reload_cfg()
	local chk = compare.new_chk_file("sf")
	while true do
		if chk:check() then
			log.debug("config change")
			reload_cfg()
			chk:save()
		end
		ski.sleep(1)
	end

	return true
end

return {check = check, init = init}