-- @author : xjx
-- @radio.lua : 保存数据到json文件中、从json文件中取数据

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
		s = recover_default(path)	assert(s)	-- 调用默认的配置文件
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

	return m
end

udp_map["radio_set"] = function(p, ip, port)
	local m = read_wireless()
	if not (m and p) then
		return nil, "miss parameter"
	end

	p.radio_2g = js.decode(p.radio_2g)	assert(p.radio_2g)
	p.radio_5g = js.decode(p.radio_5g)	assert(p.radio_5g)
	p.opt = js.decode(p.opt)	assert(p.opt)

	local t = true	-- 判断数据是否改变的标志位
	local k
	local band = "2g"

	-- 2g
	k = pkey.short(keys.c_proto, {BAND = band})
	t = (m[k] == p.radio_2g.proto) and t or false
	m[k] = t and m[k] or p.radio_2g.proto

	k = pkey.short(keys.c_power, {BAND = band})
	t = (m[k] == p.radio_2g.power) and t or false
	m[k] = t and m[k] or p.radio_2g.power

	k = pkey.short(keys.c_chanid, {BAND = band})
	t = (m[k] == p.radio_2g.chanid) and t or false
	m[k] = t and m[k] or p.radio_2g.chanid

	k = pkey.short(keys.c_bandwidth, {BAND = band})
	t = (m[k] == p.radio_2g.bandwidth) and t or false
	m[k] = t and m[k] or p.radio_2g.bandwidth

	-- 5g
	band = "5g"

	k = pkey.short(keys.c_proto, {BAND = band})
	t = (m[k] == p.radio_5g.proto) and t or false
	m[k] = t and m[k] or p.radio_5g.proto

	k = pkey.short(keys.c_power, {BAND = band})
	t = (m[k] == p.radio_5g.power) and t or false
	m[k] = t and m[k] or p.radio_5g.power

	k = pkey.short(keys.c_chanid, {BAND = band})
	t = (m[k] == p.radio_5g.chanid) and t or false
	m[k] = t and m[k] or p.radio_5g.chanid

	k = pkey.short(keys.c_bandwidth, {BAND = band})
	t = (m[k] == p.radio_5g.bandwidth) and t or false
	m[k] = t and m[k] or p.radio_5g.bandwidth

	-- opt
	k = pkey.short(keys.c_ag_rs_mult)
	t = (m[k] == p.opt.mult) and t or false
	m[k] = t and m[k] or p.opt.mult

	k= pkey.short(keys.c_ag_rs_rate)
	t = (m[k] == p.opt.rate) and t or false
	m[k] = t and m[k] or p.opt.rate

	k = pkey.short(keys.c_ag_rs_switch)
	t = (m[k] == p.opt.enable) and t or false
	m[k] = t and m[k] or p.opt.enable

	k = pkey.short(keys.c_rs_inspeed)
	t = (m[k] == p.opt.inspeed) and t or false
	m[k] = t and m[k] or p.opt.inspeed

	if t then	-- 判断是否更新了数据
		return reply(ip, port, 0, "ok")
	end

	k = pkey.short(keys.c_version)
	m[k] = os.date("%Y%m%d %H%M%S")

	log.info("radio_set ok")

	local _ = m and save_safe("/etc/config/wireless.json", js.encode(m))

	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "wlancfg"}}))	-- 更新json文件，通知performer
end

udp_map["radio_get"] = function(p, ip, port)
	local m = read_wireless()
	if not (m and p) then
		return nil, "miss parameter"
	end

	local s, t_opt = {}, {}
	local band = {"2g", "5g"}
	local k

	-- 2g, 5g
	for _, v in ipairs(band) do
		local t = {}
		k = pkey.short(keys.c_proto, {BAND = v})
		t.proto		= m[k]

		k = pkey.short(keys.c_power, {BAND = v})
		t.power		= m[k]

		k = pkey.short(keys.c_bandwidth, {BAND = v})
		t.bandwidth	= m[k]

		k = pkey.short(keys.c_chanid, {BAND = v})
		t.chanid	= m[k]

		if v == "2g" then
			s.radio_2g	= t
		end

		if v == "5g" then
			s.radio_5g	= t
		end
	end

	-- opt
	k = pkey.short(keys.c_ag_rs_mult)
	t_opt.mult		= m[k]

	k = pkey.short(keys.c_ag_rs_rate)
	t_opt.rate		= m[k]

	k = pkey.short(keys.c_rs_inspeed)
	t_opt.inspeed	= m[k]

	k = pkey.short(keys.c_ag_rs_switch)
	t_opt.enable	= m[k]

	s.opt			= t_opt

	k = pkey.short(keys.c_g_country)	-- 国家码
	s.country		= m[k]

	log.info("radio_get ok")

	reply(ip, port, 0, s)
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}