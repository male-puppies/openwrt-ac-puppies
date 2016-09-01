local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local common = require("common")
local cfglib = require("cfglib")

local read, save_safe = common.read, common.save_safe

local udp_map = {}
local udpsrv, mqtt, dbrpc, reply

local function init(u, p)
	udpsrv, mqtt = u, p
	reply = cfglib.gen_reply(udpsrv)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

udp_map["tc_get"] = function(p, ip, port)
	local tc_path = '/etc/config/tc.json'
	local tc_s = read(tc_path) or '{}'
	local tc_m = js.decode(tc_s)	assert(tc_m)

	local res = {
		GlobalSharedDownload = tc_m.GlobalSharedDownload or "0Mbps",
		GlobalSharedUpload = tc_m.GlobalSharedUpload or "0Mbps",
		Rules = tc_m.Rules or {}
	}

	local Rules = {}
	if (p.page - 1) * p.count < #res.Rules then
		local count = p.page * p.count >= #res.Rules and #res.Rules or p.page * p.count
		for i = (p.page - 1) * p.count + 1, count do
			table.insert(Rules, res.Rules[i])
		end
	end

	res.Rules = Rules

	reply(ip, port, 0, res)
end

udp_map["tc_add"] = function(p, ip, port)
	local tc_path = '/etc/config/tc.json'
	local tc_s = read(tc_path) or '{}'
	local tc_m = js.decode(tc_s)    assert(tc_m)

	tc_m.Rules = tc_m.Rules or {}

	for _, rule in ipairs(tc_m.Rules) do
		if rule.Name == p.rule.Name then
			reply(ip, port, 1, string.format("dup Name '%s'", p.rule.Name))
			return
		end
	end

	table.insert(tc_m.Rules, p.rule)

	local config = tc_m
	local _ = config and save_safe("/etc/config/tc.json", js.encode(config))
	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "tc"}}))
end


udp_map["tc_set"] = function(p, ip, port)
	local tc_path = '/etc/config/tc.json'
	local tc_s = read(tc_path) or '{}'
	local tc_m = js.decode(tc_s)    assert(tc_m)

	tc_m.Rules = tc_m.Rules or {}

	local idx = nil
	for i, rule in ipairs(tc_m.Rules) do
		if rule.Name == p.rule.Name then
			idx = i
		end
	end
	if not idx then
		reply(ip, port, 1, string.format("not found '%s'", p.rule.Name))
		return
	end

	tc_m.Rules[idx] = p.rule

	local config = tc_m
	local _ = config and save_safe("/etc/config/tc.json", js.encode(config))
	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "tc"}}))
end

udp_map["tc_del"] = function(p, ip, port)
	local tc_path = '/etc/config/tc.json'
	local tc_s = read(tc_path) or '{}'
	local tc_m = js.decode(tc_s)    assert(tc_m)

	tc_m.Rules = tc_m.Rules or {}

	for _, name in ipairs(p.Names) do
		local idx = nil
		local Rules = {}
		for i, rule in ipairs(tc_m.Rules) do
			if rule.Name == name then
				idx = i
			else
				table.insert(Rules, rule)
			end
		end
		if not idx then
			reply(ip, port, 1, string.format("not found '%s'", name))
			return
		end
		tc_m.Rules = Rules
	end

	local config = tc_m
	local _ = config and save_safe("/etc/config/tc.json", js.encode(config))
	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "tc"}}))
end

udp_map["tc_gset"] = function(p, ip, port)
	local tc_path = '/etc/config/tc.json'
	local tc_s = read(tc_path) or '{}'
	local tc_m = js.decode(tc_s)    assert(tc_m)

	tc_m.GlobalSharedDownload = p.GlobalSharedDownload or "0Mbps"
	tc_m.GlobalSharedUpload = p.GlobalSharedUpload or "0Mbps"

	local config = tc_m
	local _ = config and save_safe("/etc/config/tc.json", js.encode(config))
	reply(ip, port, 0, "ok")
	mqtt:publish("a/local/performer", js.encode({pld = {cmd = "tc"}}))
end

return {init = init, dispatch_udp = cfglib.gen_dispatch_udp(udp_map)}
