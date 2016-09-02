local log = require("log")
local const = require("constant")

local keys = const.keys
local bandmap = {["2g"] = 1, ["5g"] = 1}

-- {BAND, APID, WLANID}
local function fmt_key(pattern, r)
	assert(type(pattern) == "string" and type(r) == "table")
	local _ = pattern or log.fatal("pattern nil")
	local tk = pattern
	for k, v in pairs(r) do
		assert(type(v) == "string")
		tk = tk:gsub(k, v)
	end
	return tk
end

local function account(apid)
	assert(apid)
	return fmt_key(keys.c_account, {APID = apid})
end

local function ac_host(apid)
	assert(apid)
	return fmt_key(keys.c_ac_host, {APID = apid})
end

local function ac_port(apid)
	assert(apid)
	return fmt_key(keys.c_ac_port, {APID = apid})
end

local function desc(apid)
	assert(apid)
	return fmt_key(keys.c_desc, {APID = apid})
end

local function barr(apid)
	assert(apid)
	return fmt_key(keys.c_barr, {APID = apid})
end

local function version(apid)
	assert(apid)
	return fmt_key(keys.c_version, {APID = apid})
end

local function distr(apid)
	assert(apid)
	return fmt_key(keys.c_distr, {APID = apid})
end

local function ip(apid)
	assert(apid)
	return fmt_key(keys.c_ip, {APID = apid})
end

local function mask(apid)
	assert(apid)
	return fmt_key(keys.c_mask, {APID = apid})
end

local function gw(apid)
	assert(apid)
	return fmt_key(keys.c_gw, {APID = apid})
end

local function dns(apid)
	assert(apid)
	return fmt_key(keys.c_dns, {APID = apid})
end

local function mode(apid)
	assert(apid)
	return fmt_key(keys.c_mode, {APID = apid})
end

local function hbd_cycle(apid)
	assert(apid)
	return fmt_key(keys.c_hbd_cycle, {APID = apid})
end

local function hbd_time(apid)
	assert(apid)
	return fmt_key(keys.c_hbd_time, {APID = apid})
end

local function mnt_cycle(apid)
	assert(apid)
	return fmt_key(keys.c_mnt_cycle, {APID = apid})
end

local function mnt_time(apid)
	assert(apid)
	return fmt_key(keys.c_mnt_time, {APID = apid})
end

local function nml_cycle(apid)
	assert(apid)
	return fmt_key(keys.c_nml_cycle, {APID = apid})
end

local function nml_time(apid)
	assert(apid)
	return fmt_key(keys.c_nml_time, {APID = apid})
end

local function scan_chan(apid)
	assert(apid)
	return fmt_key(keys.c_scan_chan, {APID = apid})
end

local function wlanids(apid)
	assert(apid)
	return fmt_key(keys.c_wlanids, {APID = apid})
end

local function ampdu(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_ampdu, {APID = apid, BAND = band})
end

local function amsdu(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_amsdu, {APID = apid, BAND = band})
end

local function beacon(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_beacon, {APID = apid, BAND = band})
end

local function dtim(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_dtim, {APID = apid, BAND = band})
end

local function leadcode(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_leadcode, {APID = apid, BAND = band})
end

local function power(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_power, {APID = apid, BAND = band})
end

local function remax(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_remax, {APID = apid, BAND = band})
end

local function rts(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_rts, {APID = apid, BAND = band})
end

local function shortgi(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_shortgi, {APID = apid, BAND = band})
end

local function switch(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_switch, {APID = apid, BAND = band})
end

local function usrlimit(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_usrlimit, {APID = apid, BAND = band})
end

local function chanid(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_chanid, {APID = apid, BAND = band})
end

local function proto(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_proto, {APID = apid, BAND = band})
end

local function bandwidth(apid, band)
	assert(apid and band)
	return fmt_key(keys.c_bandwidth, {APID = apid, BAND = band})
end

local function state_hash(apid)
	assert(apid)
	return fmt_key(keys.s_state_hash, {APID = apid})
end

local function wband(wlanid)
	assert(wlanid)
	return fmt_key(keys.c_wband, {WLANID = wlanid})
end

local function wencry(wlanid)
	assert(wlanid)
	return fmt_key(keys.c_wencry, {WLANID = wlanid})
end

local function whide(wlanid)
	assert(wlanid)
	return fmt_key(keys.c_whide, {WLANID = wlanid})
end

local function wpasswd(wlanid)
	assert(wlanid)
	return fmt_key(keys.c_wpasswd, {WLANID = wlanid})
end

local function wssid(wlanid)
	assert(wlanid)
	return fmt_key(keys.c_wssid, {WLANID = wlanid})
end

local function wstate(wlanid)
	assert(wlanid)
	return fmt_key(keys.c_wstate, {WLANID = wlanid})
end

local function waplist(wlanid)
	assert(wlanid)
	return fmt_key(keys.c_waplist, {WLANID = wlanid})
end

local function key(k, r)
	local js  =require("cjson.safe")
	assert(k and r, js.encode(debug.getinfo(2, "lS")))
	return fmt_key(k, r)
end

local function short(kp, r)
	local kp = kp:gsub("APID#", "")
	if r then
		return fmt_key(kp, r)
	end
	return kp
end

return {
	account = account,
	ac_host = ac_host,
	ac_port = ac_port,
	desc = desc,
	barr = barr,
	version = version,
	distr = distr,
	ip = ip,
	mask = mask,
	gw = gw,
	dns = dns,
	mode = mode,
	hbd_cycle = hbd_cycle,
	hbd_time = hbd_time,
	mnt_cycle = mnt_cycle,
	mnt_time = mnt_time,
	nml_cycle = nml_cycle,
	nml_time = nml_time,
	scan_chan = scan_chan,
	wlanids = wlanids,
	ampdu = ampdu,
	amsdu = amsdu,
	beacon = beacon,
	dtim = dtim,
	leadcode = leadcode,
	power = power,
	remax = remax,
	rts = rts,
	shortgi = shortgi,
	switch = switch,
	usrlimit = usrlimit,
	chanid = chanid,
	proto = proto,
	bandwidth = bandwidth,
	state_hash = state_hash,
	wband = wband,
	wencry = wencry,
	whide = whide,
	wpasswd = wpasswd,
	wssid = wssid,
	wstate = wstate,
	waplist = waplist,
	key = key,
	short = short,
}