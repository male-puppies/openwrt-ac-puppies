local arch = require("arch")
-- 根据平台初始化配置文件目录
local config_dir = arch.configdir()

local keys = {
	c_account = 			"APID#a#account",
	c_ac_host = 			"APID#a#ac_host",
	c_ac_port = 			"APID#a#ac_port",

	c_desc = 				"APID#a#desc",
	c_barr = 				"APID#a#barr",
	c_version =				"APID#a#version",

	c_distr =				"APID#a#distr",
	c_ip =					"APID#a#ip",
	c_mask =				"APID#a#mask",
	c_gw = 					"APID#a#gw",
	c_dns = 				"APID#a#dns",

	c_mode =				"APID#a#mode",
	c_hbd_cycle =			"APID#a#hbd_cycle",
	c_hbd_time =			"APID#a#hbd_time",
	c_mnt_cycle =			"APID#a#mnt_cycle",
	c_mnt_time =			"APID#a#mnt_time",
	c_nml_cycle =			"APID#a#nml_cycle",
	c_nml_time =			"APID#a#nml_time",

	c_scan_chan =			"APID#a#scan_chan",
	c_wlanids =				"APID#a#wlanids",

	c_ampdu = 				"APID#a#BAND#ampdu",
	c_amsdu = 				"APID#a#BAND#amsdu",
	c_beacon = 				"APID#a#BAND#beacon",
	c_dtim = 				"APID#a#BAND#dtim",
	c_leadcode = 			"APID#a#BAND#leadcode",
	c_power = 				"APID#a#BAND#power",
	c_remax = 				"APID#a#BAND#remax",
	c_rts = 				"APID#a#BAND#rts",
	c_shortgi = 			"APID#a#BAND#shortgi",
	c_bswitch = 			"APID#a#BAND#bswitch",
	c_bandwidth = 			"APID#a#BAND#bandwidth",
	c_usrlimit = 			"APID#a#BAND#usrlimit",
	c_chanid = 				"APID#a#BAND#chanid",
	c_proto = 				"APID#a#BAND#proto",

	c_wband = 				"w#WLANID#wband",
	c_wencry = 				"w#WLANID#wencry",
	c_whide = 				"w#WLANID#whide",
	c_wpasswd = 			"w#WLANID#wpasswd",
	c_wssid = 				"w#WLANID#wssid",
	c_wvlanenable = 		"w#WLANID#wvlanenable",
	c_wvlanid = 			"w#WLANID#wvlanid",
	c_wstate = 				"w#WLANID#wstate",
	c_wnetwork =			"w#WLANID#wnetwork",
	c_waplist = 			"ww#WLANID#waplist",

	c_ag_reboot = 			"ag_reboot",
	c_ag_rs_switch 	=		"ag_rs_switch",
	c_ag_rs_mult	=		"ag_rs_mult",
	c_ag_rs_rate 	=		"ag_rs_rate",
	c_ag_rdo_cycle 	=		"ag_rdo_cycle",
	c_ag_sta_cycle 	=		"ag_sta_cycle",	--上报sta信息周期
	c_g_country 	=		"g_country",	-- 1 g_country
	c_g_ld_switch 	=		"g_ld_switch",
	c_wlan_list = 			"g_wlan_list",
	c_wlan_current = 		"g_wlan_current",
	c_ap_list = 			"g_ap_list",
	c_update_host = 		"g_update_host",
	c_upload_log = 			"g_upload_log",
	c_g_debug	=			"g_debug",		--调试开关
	c_g_ledctrl =			"g_ledctrl",
	c_g_abncheck = 			"g_abncheck",

	c_rs_iso =				"ag_rs_iso",			--启用AP隔离
	c_rs_inspeed =			"ag_rs_inspeed",		--广播提速
	c_tena_switch = 		"wg_tena_switch",		--防终端粘滞开关
	c_rssi_limit = 			"wg_rssi_limit",		--信号强度阈值
	c_flow_limit = 			"wg_flow_limit",		--流量阈值
	c_sensitivity = 		"wg_sensitivity",		--敏感度
	c_ten_black_time = 		"wg_ten_black_time",	--黑名单有效时间
	c_kick_interval = 		"wg_kick_interval",		--踢用户间隔，应大于
	c_wg_barr = 			"wg_barr",

	s_state_hash = 			"state#APID",
	s_fireware = 			"fireware",
	s_state = 				"state",
	s_active = 				"active",
	s_uptime = 				"uptime",

	s_naps = 				"BAND#nap",
	s_nwlans = 				"BAND#nwlan",
	s_sta = 				"BAND#sta",
	s_users = 				"BAND#users",
	s_chanid = 				"BAND#chanid",
	s_chanuse = 			"BAND#chanuse",
	s_power = 				"BAND#power",
	s_noise = 				"BAND#noise",
	s_maxpow = 				"BAND#maxpow",
	s_proto = 				"BAND#proto",
	s_bandwidth = 			"BAND#bandwidth",
	s_wlanid = 				"BAND#wlanid",
	s_run = 				"BAND#run",

	ws_hash_user = 			"h#user_status",
}

local const = {
	keys = 						keys,

	ap_config = 				config_dir .. "/wireless.json",
	default_config = 			arch.default_cfg(),
	ap_debug_dir  = 			"/tmp/ugw/sw/",
	ap_debug_flag = 			"/tmp/ugw/sw/" .. keys.c_g_debug , -- global debug switch for ap
	ap_abncheck_flag =			"/tmp/ugw/sw/" .. keys.c_g_abncheck,
	ap_ledctrl_flag = 			"/tmp/ugw/sw/" .. keys.c_g_ledctrl,
	ap_scan_dir = 				"/tmp/ugw/scan/",	-- scan info file for ap
}

local function check_part(p)
	local map = {}
	for k, v in pairs(keys) do
		if k:find(p) then
			local spec = v:match(".+#(.+)") or v
			if map[spec] then
				io.stderr:write(string.format("already exist key %s %s %s", k, v, spec))
				os.exit(-1)
			end
			map[spec] = 1
		end
	end
end

-- 为处理方便，后缀必须唯一
local function check_keys()
	check_part("^c_")
	check_part("^s_")
end

-- check_keys()

return const
