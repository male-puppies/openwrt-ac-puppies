local fp = require("fp")
local ski = require("ski")
local log = require("log")
local md5 = require("md5")
local pflib = require("pflib")
local ipops = require("ipops")
local js = require("cjson.safe")
local common = require("common")
local mwan = require("cfgmgr.mwan")

local read = common.read

local tcp_map = {}
local mwan_reload

local function init(p)
	mwan_reload()
end

local function generate_mwan_cmds(mwan)
	local arr = {}

	table.insert(arr, string.format("while uci delete mwan3.@rule[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr, string.format("while uci delete mwan3.@policy[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr, string.format("while uci delete mwan3.@member[0] >/dev/null 2>&1; do :; done"))
	table.insert(arr, string.format("while uci delete mwan3.@interface[0] >/dev/null 2>&1; do :; done"))

	local mwan_line, m, mwan_ifaces = 0, 2, {}
	for i, iface in ipairs(mwan.ifaces or {}) do
		if iface.enable == 1 then
			mwan_line = mwan_line + 1
			mwan_ifaces[iface.name] = {
				track_ip = iface.track_ip or {},
				w = tonumber(iface.bandwidth) == 0 and 1 or tonumber(iface.bandwidth),
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
		table.insert(arr, string.format("uci set mwan3.%s=policy", mwan.policy))
		for name, value in pairs(mwan_ifaces) do
			table.insert(arr, string.format("uci set mwan3.%s=interface", name))
			table.insert(arr, string.format("uci set mwan3.%s.enabled='1'", name))
			table.insert(arr, string.format("uci set mwan3.%s.reliability='1'", name))
			table.insert(arr, string.format("uci set mwan3.%s.count='1'", name))
			table.insert(arr, string.format("uci set mwan3.%s.timeout='2'", name))
			table.insert(arr, string.format("uci set mwan3.%s.interval='5'", name))
			table.insert(arr, string.format("uci set mwan3.%s.down='3'", name))
			table.insert(arr, string.format("uci set mwan3.%s.up='3'", name))

			for _, track_ip in ipairs(value.track_ip) do
				table.insert(arr, string.format("uci add_list mwan3.%s.track_ip='%s'", name, track_ip))
			end

			local member = string.format("%s_m%u_w%u", name, value.m, value.w)
			table.insert(arr, string.format("uci set mwan3.%s=member", member))
			table.insert(arr, string.format("uci set mwan3.%s.interface='%s'", member, name))
			table.insert(arr, string.format("uci set mwan3.%s.metric='%u'", member, value.m))
			table.insert(arr, string.format("uci set mwan3.%s.weight='%u'", member, value.w))

			table.insert(arr, string.format("uci add_list mwan3.%s.use_member='%s'", mwan.policy, member))
		end
		table.insert(arr, string.format("uci set mwan3.%s.last_resort='unreachable'", mwan.policy))

		table.insert(arr, string.format("uci set mwan3.https='rule'"))
		table.insert(arr, string.format("uci set mwan3.https.sticky='1'"))
		table.insert(arr, string.format("uci set mwan3.https.dest_port='443'"))
		table.insert(arr, string.format("uci set mwan3.https.proto='tcp'"))
		table.insert(arr, string.format("uci set mwan3.https.use_policy='%s'", mwan.policy))

		table.insert(arr, string.format("uci set mwan3.default_rule='rule'"))
		table.insert(arr, string.format("uci set mwan3.default_rule.dest_ip='0.0.0.0/0'"))
		table.insert(arr, string.format("uci set mwan3.default_rule.use_policy='%s'", mwan.policy))
	end

	return {mwan3 = arr}
end

function mwan_reload()
	local mwan_m = mwan.load()
	local mwan_arr = generate_mwan_cmds(mwan_m)

	local arr_cmd = {mwan3 = {"uci commit mwan3", "/usr/sbin/mwan3 restart"}}
	for _, name in ipairs({"mwan3"}) do
		local cmd_arr = fp.reduce(mwan_arr[name], function(t, s) return rawset(t, #t + 1, s) end, {})


		local cmd = table.concat(cmd_arr, "\n")
		local new_md5 = md5.sumhexa(cmd)
		local old_md5 = common.read(string.format("uci get %s.@version[0].mwan_md5 2>/dev/null | head -c32", name), io.popen)

		if new_md5 ~= old_md5 then
			table.insert(cmd_arr, string.format("uci get %s.@version[0] 2>/dev/null || uci add %s version >/dev/null 2>&1", name, name))
			table.insert(cmd_arr, string.format("uci set %s.@version[0].mwan_md5='%s'", name, new_md5))
			for _, line in ipairs(arr_cmd[name]) do
				table.insert(cmd_arr, line)
			end

			local cmd = table.concat(cmd_arr, "\n")
			print(cmd)
			os.execute(cmd)
		end
	end
end

tcp_map["mwan"] = function(p)
	mwan_reload()
end

tcp_map["network_change"] = function(p)
	mwan_reload()
end

return {init = init, dispatch_tcp = pflib.gen_dispatch_tcp(tcp_map)}