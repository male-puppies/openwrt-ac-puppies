-- author: yjs

local js = require("cjson.safe")
local common = require("common")
local adminlib = require("admin.adminlib")

local arr2map = common.arr2map
local ip_pattern, mac_pattern = adminlib.ip_pattern, adminlib.mac_pattern

local validate_map = {
	mac = function(v)
		if v == "" or v:find(mac_pattern) then
			return v
		end
		return nil, "invalid mac"
	end,
	proto = function(v)
		local proto_map = {static = 1, dhcp = 1, pppoe = 1}
		if proto_map[v] then
			return v
		end
		return nil, "invalid proto"
	end,
	dns = function(v)
		for ip in (v .. ","):gmatch("(.-),") do
			if ip ~= "" and not ip:find(ip_pattern) then
				return nil, "invalid dns"
			end
		end
		return v
	end,
	mtu = function(v)
		if v ~= "" then
			local nv = tonumber(v)
			if not (nv and nv > 0 and nv <= 1500) then
				return nil, "invalid mtu"
			end
		end
		return v
	end,
	ports = function(v)
		if type(v) ~= "table" then
			return nil, "invalid ports"
		end
		for _, p in ipairs(v) do
			if not (type(p) == "number" and p > 0) then
				return nil, "invalid ports"
			end
		end
		return v
	end,
	pppoe_account = function(v)
		if #v >= 0 and #v <= 32 then
			return v
		end
		return nil, "invalid pppoe_account"
	end,
	pppoe_password = function(v)
		if #v >= 0 and #v <= 32 then
			return v
		end
		return nil, "invalid pppoe_password"
	end,
	gateway = function(v)
		if v == "" or v:find(ip_pattern) then
			return v
		end
		return nil, "invalid gateway"
	end,
	metric = function(v)
		if v ~= "" then
			local nv = tonumber(v)
			if not (nv and nv > 0 and nv <= 1500) then
				return nil, "invalid mtu"
			end
		end
		return v
	end,
	ipaddr = function(v)
		if v == "" then
			return v
		end
		local ip, bits = v:match("(.-)/(%d+)")
		bits = tonumber(bits)
		if not (ip and ip:find(ip_pattern) and bits >= 0 and bits <= 32) then
			return nil, "invalid ipaddr"
		end
		return v
	end,
	dhcpd = {
	    enabled = function(v)
			if v == 0 or v == 1 then
				return v
			end
			return nil, "invalid gateway"
		end,
		leasetime = function(v)
			local p1, p2 = v:match("(%d+)(.)")
			if not (p1 and tonumber(p1) > 0) then
				return nil, "invald leasetime"
			end
			if not (p2 == "m" or p2 == "h" or p2 == "d") then
				return nil, "invald leasetime"
			end
			return v
	    end,
	    dns = function(v)
			for ip in (v .. ","):gmatch("(.-),") do
				if ip ~= "" and not ip:find(ip_pattern) then
					return nil, "invalid dns"
				end
			end
			return v
		end,
	    start = function(v)
			if v == "" or v:find(ip_pattern) then
				return v
			end
			return nil, "invalid start"
		end,
	    ["end"] = function(v)
			if v == "" or v:find(ip_pattern) then
				return v
			end
			return nil, "invalid end"
		end,
		dynamicdhcp = function(v)
			if v == 0 or v == 1 then
				return v
			end
			return nil, "invalid dynamicdhcp"
		end,
	    staticlease = function(v)
			if type(v) == "table" then
				return v
			end
			return nil, "invalid staticlease"
		end,
	},
}

local function validate_network(s)
	local m = js.decode(s)
	if not m then
		return nil, "invalid param 1"
	end

	local name, network = m.name, m.network
	if not (name and network) then
		return nil, "invalid param 2"
	end

	local check = function(f, v, field)
		if not v then
			return nil, "miss " .. field
		end
		local r, e = f(v)
		if not r then
			return nil, e
		end
		return true
	end

	for iface, cfg in pairs(network) do
		for field, f in pairs(validate_map) do
			if type(f) == "function" then
				local r, e = check(f, cfg[field], field)
				if not r then
					return nil, e
				end
			else
				local vs = cfg[field]
				for field2, f2 in pairs(f) do
					local r, e = check(f2, vs[field2], field2)
					if not r then
						return nil, e
					end
				end
			end
		end
	end

	return m
end

return {validate = validate_network}
