-- @author : xjx
-- @wlanssid.lua

local ski	= require("ski")
local log	= require("log")
local pkey 	= require("key")
local js	= require("cjson.safe")
local rpccli	= require("rpccli")
local common	= require("common")
local cfglib	= require("cfglib")
local const 	= require("constant")

local read, save_safe  = common.read, common.save_safe
local keys = const.keys

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply

local function recover_default(path)
	local cmd = string.format("cp %s %s", "/usr/share/base-config/wireless.json", path)
	local ret = os.execute(cmd)		assert(ret)

	return ret
end

local function init(u, p)
	local path = "/etc/config/wireless.json"
	local s = read(path)
	if not s then
		recover_default(path)	assert(s)	-- 调用默认的配置文件
	end

	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

-- 将json文件译码成map
local function read_wireless()
	local path = "/etc/config/wireless.json"
	local s = read(path)	assert(s)
	local m = js.decode(s)	assert(m)

	local k = pkey.short(keys.c_wlanids)
	if not (type(m[k]) == "table") then
		m[k] = js.decode(m[k])
	end

	return m
end

udp_map["wlan_add"] = function(p, ip, port)
	local m = read_wireless()
	if not (m and p) then
		return nil, "miss parameter"
	end

	local v_ssid = p.ssid	assert(v_ssid)
	local ids = {}
	local t = 1
	local i, k

	for j, v in pairs(m) do    -- 检查是否存在相同的SSID
		if string.find(j, "#wssid") then
			if v_ssid == v then
				return reply(ip, port, 1, "identical ssid")
			end

			i = tonumber(string.sub(j, 3, 7))	-- 截取wlanid
			ids[i] = 1	-- 保存已存在的id
		end
	end

	for _, v in ipairs(ids) do   -- 选出 next id
		if t > 256 then
			return nil, "wlanid overflow"
		end

		if not(ids[t] == 1) then
			break
		end

		t = t + 1
	end

	t = string.format("%05d", t)

	k = pkey.short(keys.c_wband, {WLANID = t})
	m[k] = p.band

	k = pkey.short(keys.c_wencry, {WLANID = t})
	m[k] = p.encrypt

	k = pkey.short(keys.c_whide, {WLANID = t})
	m[k] = p.hide

	k = pkey.short(keys.c_wpasswd, {WLANID = t})
	m[k] = p.password

	k = pkey.short(keys.c_wssid, {WLANID = t})
	m[k] = p.ssid

	k = pkey.short(keys.c_wstate, {WLANID = t})
	m[k] = p.enable

	k = pkey.short(keys.c_wnetwork, {WLANID = t})
	m[k] = p.network

	k = pkey.short(keys.c_version)
	m[k] = os.date("%Y%m%d %H%M%S")  -- 获取版本时间

	k = pkey.short(keys.c_wlanids)
	table.insert(m[k], t)	-- id插入到wlanids表中

	log.info("wlan_add ok")

	local _ = m and save_safe("/etc/config/wireless.json", js.encode(m))

	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "wlancfg"}}))	-- 更新json文件，通知performer
end

udp_map["wlan_set"] = function(p, ip, port)
	local m = read_wireless()
	if not (m and p) then
		return nil, "miss parameter"
	end

	local v_wlanid = string.format("%05d", p.wlanid)	assert(v_wlanid and #v_wlanid == 5)

	local v_ssid = p.ssid	assert(v_ssid and #v_ssid >= 1 and #v_ssid <= 32)

	local t = false
	local k

	k = pkey.short(keys.c_wlanids)
	for _, v in ipairs(m[k]) do	-- 判断wlanid是否存在wlanids中
		if(v_wlanid == v) then
			t = true
			break
		end
	end

	if not t then
		return nil, "invaild wlanid"
	end

	for i, v in pairs(m) do	-- 检查是否设置相同的SSID
		if not string.find(i, v_wlanid) then	-- 除去本身的id
			if string.find(i, "#wssid") then
				if v_ssid == v then	-- 判断SSID是否相同
					return reply(ip, port, 1, "identical ssid")
				end
			end
		end
	end

	t = true	-- 判断参数是否发生改变

	k = pkey.short(keys.c_wband, {WLANID = v_wlanid})
	t = (m[k] == p.band) and t or false
	m[k] = t and m[k] or p.band

	k = pkey.short(keys.c_wencry, {WLANID = v_wlanid})
	t = (m[k] == p.encrypt) and t or false
	m[k] = t and m[k] or p.encrypt

	k = pkey.short(keys.c_whide, {WLANID = v_wlanid})
	t = (m[k] == p.hide) and t or false
	m[k] = t and m[k] or p.hide

	k = pkey.short(keys.c_wpasswd, {WLANID = v_wlanid})
	t = (m[k] == p.password) and t or false
	m[k] = t and m[k] or p.password

	k = pkey.short(keys.c_wssid, {WLANID = v_wlanid})
	t = (m[k] == p.ssid) and t or false
	m[k] = t and m[k] or p.ssid

	k = pkey.short(keys.c_wstate, {WLANID = v_wlanid})
	t = (m[k] == p.enable) and t or false
	m[k] = t and m[k] or p.enable

	k = pkey.short(keys.c_wnetwork, {WLANID = v_wlanid})
	t = (m[k] == p.network) and t or false
	m[k] = t and m[k] or p.network

	if t then
		return reply(ip, port, 0, "ok")
	end

	k = pkey.short(keys.c_version)
	m[k] = os.date("%Y%m%d %H%M%S")	 -- 获取新版本时间

	log.info("wlan_set ok")

	local _ = m and save_safe("/etc/config/wireless.json", js.encode(m))

	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "wlancfg"}}))	-- 更新json文件，通知performer
end

udp_map["wlan_get"] = function(p, ip, port)
	local m = read_wireless()
	if not (m and p) then
		return nil, "miss parameter"
	end

	local t = {}

	local j = pkey.short(keys.c_wlanids)
	for _, v in ipairs(m[j]) do
		local i, k = {}

		k = pkey.short(keys.c_wband, {WLANID = v})
		i.band = m[k]

		k = pkey.short(keys.c_wencry, {WLANID = v})
		i.encrypt = m[k]

		k = pkey.short(keys.c_whide, {WLANID = v})
		i.hide = m[k]

		k = pkey.short(keys.c_wpasswd, {WLANID = v})
		i.password = m[k]

		k = pkey.short(keys.c_wssid, {WLANID = v})
		i.ssid = m[k]

		k = pkey.short(keys.c_wstate, {WLANID = v})
		i.enable = m[k]

		k = pkey.short(keys.c_wnetwork, {WLANID = v})
		i.network = m[k]

		i.wlanid = v
		t[v] = i
	end

	log.info("wlan_get ok")

	reply(ip, port, 0, t)
end

udp_map["wlan_del"] = function(p, ip, port)
	local m = read_wireless()
	if not (m and p) then
		return nil, "miss parameter"
	end

	local v_wlanids = js.decode(p.wlanids)	assert(v_wlanids)
	local k

	for _,v in ipairs(v_wlanids) do
		if(tonumber(v.wlanid) < 0 or tonumber(v.wlanid) > 256) then
			return nil, "invaild wlanid"
		end

		k = pkey.short(keys.c_wband, {WLANID = v.wlanid})
		m[k] = nil

		k = pkey.short(keys.c_wencry, {WLANID = v.wlanid})
		m[k] = nil

		k = pkey.short(keys.c_whide, {WLANID = v.wlanid})
		m[k] = nil

		k = pkey.short(keys.c_wpasswd, {WLANID = v.wlanid})
		m[k] = nil

		k = pkey.short(keys.c_wssid, {WLANID = v.wlanid})
		m[k] = nil

		k = pkey.short(keys.c_wstate, {WLANID = v.wlanid})
		m[k] = nil

		k = pkey.short(keys.c_wnetwork, {WLANID = v.wlanid})
		m[k] = nil

		k = pkey.short(keys.c_wlanids)
		for i, j in ipairs(m[k]) do
			if(j == v.wlanid) then
				table.remove(m[k], i)
			end
		end
	end

	k = pkey.short(keys.c_version)
	m[k] = os.date("%Y%m%d %H%M%S")	 -- 获取新版本时间

	log.info("wlan_del ok")

	local _ = m and save_safe("/etc/config/wireless.json", js.encode(m))

	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "wlancfg"}}))
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}