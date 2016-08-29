local js = require("cjson.safe")
local query = require("common.query")
local adminlib = require("admin.adminlib")
local common = require("common")
local ipops = require("ipops")

local read = common.read

local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern = adminlib.ip_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local validate_post_get_all = adminlib.validate_post_get_all
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_rid = gen_validate_num(0, 65535)

local v_target = gen_validate_str(0, 24)
local v_netmask = gen_validate_str(0, 24)
local v_gateway = gen_validate_str(0, 24)
local v_metric = gen_validate_num(0, 65535)
local v_mtu = gen_validate_num(500, 65500)
local v_iface = gen_validate_str(0, 16)
local v_rids = gen_validate_str(2, 256)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 	                end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local function load_iface_map()
	local board_s = read("/etc/config/board.json")	assert(board_s)
	local board_m = js.decode(board_s)	assert(board_m)
	local ports = board_m.ports
	local port_map = {}

	for _, dev in ipairs(ports) do
		if dev.type == "switch" then
			for idx, port in ipairs(dev.outer_ports) do
				table.insert(port_map, {ifname = dev.ifname, mac = port.mac, type = dev.type, device = dev.device, num = port.num, inner_port = dev.inner_port})
			end
		elseif dev.type == "ether" then
			table.insert(port_map, {ifname = dev.ifname, mac = dev.outer_ports[1].mac, type = dev.type, device = dev.device})
		end
	end

	local path = "/etc/config/network.json"
	local network_s = read("/etc/config/network.json")	assert(network_s)
	local network_m = js.decode(network_s)	assert(network_m)
	local network = network_m.network

	local iface_map = {}
	local uci_network = {}

	for name, option in pairs(network) do
		uci_network[name] = option
		if name:find("^lan") or #option.ports > 1 then
			uci_network[name].type = 'bridge'
		end

		uci_network[name].ifname = ""
		local ifnames = {}
		local vlan = nil
		for _, i in ipairs(option.ports) do
			if port_map[i].type == 'switch' then
				vlan = vlan or tostring(i)
				ifnames[port_map[i].ifname .. "." .. vlan] = tonumber(vlan)
			else
				ifnames[port_map[i].ifname] = i
			end
		end

		for ifname, i in pairs(ifnames) do
			if uci_network[name].ifname == "" then
				uci_network[name].ifname = ifname
			else
				uci_network[name].ifname = uci_network[name].ifname .. " " .. ifname
			end
		end

		if uci_network[name].proto == "static" or uci_network[name].proto == "dhcp" then
			if uci_network[name].type == 'bridge' then
				iface_map["br-" .. name] = name
			else
				iface_map[uci_network[name].ifname] = name
			end
		elseif uci_network[name].proto == "pppoe" then
			iface_map["pppoe-" .. name] = name
		end
	end

	return iface_map
end

local function load_active_route()
	local iface_map = load_iface_map()
	local s = read("/proc/net/route")
	local h = {}
	for iface, target, gateway, _, _, _, metric, netmask, mtu, _, _ in s:gmatch("(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\n") do
		if target ~= "Destination" and iface_map[iface] then
			local r = {
				iface = iface_map[iface],
				target = ipops.hexstr2ipstr(target),
				netmask = ipops.hexstr2ipstr(netmask),
				gateway = ipops.hexstr2ipstr(gateway),
				metric = tonumber(metric),
				mtu = tonumber(mtu),
				status = 255,
			}
			h[string.format("%s%s%s%s%u%u", r.iface, r.target, r.netmask, r.gateway, r.metric, r.mtu)] = r
		end
	end
	return h
end

function cmd_map.route_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

	local cond = adminlib.search_cond(m)
	local sql = string.format("select * from route %s", cond.limit)
	local rs, e = mysql_select(sql)
	if not rs then
		return reply_e(e)
	end

	local h = load_active_route()
	for _, rule in ipairs(rs) do
		local r = h[string.format("%s%s%s%s%u%u", rule.iface, rule.target, rule.netmask, rule.gateway, rule.metric, rule.mtu)]
		if not r then
			rule.status = 1
		else
			rule.status = 0
			r.status = 0
		end
		rule.metric = rule.metric == 0 and "" or rule.metric
		rule.mtu = rule.mtu == 0 and "" or rule.mtu
	end

	for _, rule in pairs(h) do
		if rule.status == 255 then
			rule.metric = rule.metric == 0 and "" or rule.metric
			rule.mtu = rule.mtu == 0 and "" or rule.mtu
			table.insert(rs, rule)
		end
	end

	return rs and reply(rs) or reply_e(e)
end

local function route_update_common(cmd, ext)
	local check_map = {
		target			=	v_target,
		netmask			=	v_netmask,
		gateway			=	v_gateway,
		--metric			=	v_metric,
		--mtu				=	v_mtu,
		iface			=	v_iface,
	}

	for k, v in pairs(ext or {}) do
		check_map[k] = v
	end

	local m, e = validate_post_get_all(check_map)
	if not m then
		return reply_e(e)
	end

	local p = e

	m.metric = p.metric and v_metric(p.metric) or 0
	m.mtu = p.mtu and v_metric(p.mtu) or 0

	return query_common(m, cmd)
end

function cmd_map.route_set()
	return route_update_common("route_set", {rid = v_rid})
end

function cmd_map.route_add()
	return route_update_common("route_add")
end

function cmd_map.route_del()
	local m, e = validate_post({rids = v_rids})

	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.rids)
	if not (ids and type(ids) == "table")  then
		return reply_e("invalid rids")
	end

	for _, id in ipairs(ids) do
		local rid = tonumber(id)
		if not (rid and rid >= 0 and rid < 65535) then
			return reply_e("invalid rids")
		end
	end

	return query_common(m, "route_del")
end

return {run = run}
