local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local common = require("common")
local ipops = require("ipops")
local md5 = require("md5")

local read = common.read

local function load_mwan()
	local path = "/etc/config/mwan.json"
	local s = read(path)
	local m = js.decode(s or "{}")
	return m
end

local function load_network()
	local path = "/etc/config/network.json"
	local s = read(path)	assert(s)
	local m = js.decode(s)	assert(m)
	return m.network
end

local function generate_mwan_cmds(mwan, network)
	local arr = {}
	arr["mwan3"] = {}

	table.insert(arr["mwan3"], string.format("while uci delete mwan3.@rule[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr["mwan3"], string.format("while uci delete mwan3.@policy[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr["mwan3"], string.format("while uci delete mwan3.@member[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr["mwan3"], string.format("while uci delete mwan3.@interface[0] >/dev/null 2>&1; do :; done"))

	local wans = {}
	for name, _ in pairs(network) do
		if name:find("^wan") then
			table.insert(wans, name)
		end
	end

	local mwan_ifaces = {}
	local mwan_line = 0
	local m = 2
	for i, iface in ipairs(mwan.ifaces or {}) do
		local found = false
		for _, name in ipairs(wans) do
			if name == iface.name then
				found = true
			end
		end
		if found and iface.enable == 1 then
			mwan_line = mwan_line + 1
			mwan_ifaces[iface.name] = {
				w = tonumber(iface.bandwidth) == 0 and 1 or tonumber(iface.bandwidth)
			}
			if mwan.policy == "backup" then
				mwan_ifaces[iface.name].m = m
				m = m + 1
				for _, name in ipairs(mwan.main_iface or {}) do
					if name == iface.name then
						mwan_ifaces[iface.name].m = 1
					end
				end
			else
				mwan_ifaces[iface.name].m = 1
			end
		end
	end

	if mwan_line >= 2 then
		table.insert(arr["mwan3"], string.format("uci set mwan3.%s=policy", mwan.policy))
		for name, value in pairs(mwan_ifaces) do
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s=interface", name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.enabled='1'", name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.reliability='1'", name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.count='1'", name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.timeout='2'", name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.interval='5'", name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.down='3'", name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.up='3'", name))
			table.insert(arr["mwan3"], string.format("uci add_list mwan3.%s.track_ip='114.114.114.114'", name))

			local member = string.format("%s_m%u_w%u", name, value.m, value.w)
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s=member", member))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.interface='%s'", member, name))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.metric='%u'", member, value.m))
			table.insert(arr["mwan3"], string.format("uci set mwan3.%s.weight='%u'", member, value.w))

			table.insert(arr["mwan3"], string.format("uci add_list mwan3.%s.use_member='%s'", mwan.policy, member))
		end
		table.insert(arr["mwan3"], string.format("uci set mwan3.%s.last_resort='unreachable'", mwan.policy))

		table.insert(arr["mwan3"], string.format("uci set mwan3.https='rule'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.https.sticky='1'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.https.dest_port='443'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.https.proto='tcp'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.https.use_policy='%s'", mwan.policy))

		table.insert(arr["mwan3"], string.format("uci set mwan3.default_rule='rule'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.default_rule.sticky='0'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.default_rule.dest_port='443'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.default_rule.proto='tcp'"))
		table.insert(arr["mwan3"], string.format("uci set mwan3.default_rule.use_policy='%s'", mwan.policy))
	end

	return arr
end

local function mwan_reload()
	local mwan = load_mwan()
	local network = load_network()
	local cmd = ""
	local new_md5, old_md5
	local arr = {}
	local arr_cmd = {}
	local orders = {}

	arr["mwan3"] = {}

	arr_cmd["mwan3"] = {
		string.format("uci commit mwan3"),
		string.format("/usr/sbin/mwan3 restart")
	}

	orders = {"mwan3"}

	local mwan_arr = generate_mwan_cmds(mwan, network)

	for _, name in ipairs(orders) do
		for _, line in ipairs(mwan_arr[name]) do
			table.insert(arr[name], line)
		end

		cmd = table.concat(arr[name], "\n")
		new_md5 = md5.sumhexa(cmd)
		old_md5 = common.read(string.format("uci get %s.@version[0].mwan_md5 2>/dev/null | head -c32", name), io.popen)
		--print(new_md5, old_md5)
		if new_md5 ~= old_md5 then
			table.insert(arr[name], string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version", name, name))
			table.insert(arr[name], string.format("uci set %s.@version[0].mwan_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(arr[name], line)
			end
			cmd = table.concat(arr[name], "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end

local tcp_map = {}
local mqtt
local function init(p)
	mqtt = p
	mwan_reload()
end

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd.data)
	end
end

tcp_map["mwan"] = function(p)
	mwan_reload()
end

return {init = init, dispatch_tcp = dispatch_tcp}
