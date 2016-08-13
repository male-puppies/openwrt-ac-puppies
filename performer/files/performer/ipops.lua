local bit = require("bit")

local function _lshift(a, i)
	return a * 2^i
end

local function _rshift(a, i)
	return a / 2^i
end

local function _band(a, b)
	local r = 0
	a = bit.band(a, b)
	for i = 0, 31 do
		local x = bit.lshift(1, i)
		if bit.band(x, a) ~= 0 then
			r = r + 2^i
		end
	end
	return r
end

local function _bor(a, b)
	local r = 0
	a = bit.bor(a, b)
	for i = 0, 31 do
		local x = bit.lshift(1, i)
		if bit.band(x, a) ~= 0 then
			r = r + 2^i
		end
	end
	return r
end

local function _bxor(a, b)
	local r = 0
	a = bit.bxor(a, b)
	for i = 0, 31 do
		local x = bit.lshift(1, i)
		if bit.band(x, a) ~= 0 then
			r = r + 2^i
		end
	end
	return r
end

local function _bnot(a)
	local r = 0
	a = bit.bnot(a)
	for i = 0, 31 do
		local x = bit.lshift(1, i)
		if bit.band(x, a) ~= 0 then
			r = r + 2^i
		end
	end
	return r
end

local function get_parts_as_number(ipstr)
	local t = {}
	for part in string.gmatch(ipstr, "%d+") do
		t[#t+1] = tonumber(part, 10)
	end
	return t
end

local function ipstr2int(ipstr)
	local ip = get_parts_as_number(ipstr)
	if #ip == 4 then
		return (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
	end
	return 0
end

local function int2ipstr(ip)
	local n = {}
	n[1] = _band(_rshift(ip, 24), 0x000000FF)
	n[2] = _band(_rshift(ip, 16), 0x000000FF)
	n[3] = _band(_rshift(ip, 8), 0x000000FF)
	n[4] = _band(_rshift(ip, 0), 0x000000FF)

	return string.format("%u.%u.%u.%u", n[1], n[2], n[3], n[4])
end

local function cidr2int(cidr)
	local x = 0;
	for i = 0, cidr - 1, 1 do
		x = x + _lshift(1, 31 - i)
	end
	return x
end

local function int2cidr(ip)
	for i = 0, 31, 1 do
		if _band(ip, _lshift(1, 31 - i)) == 0 then
			return i
		end
	end
	return 32
end

local function cidr2maskstr(cidr)
	local ip = cidr2int(cidr)
	return int2ipstr(ip)
end

local function maskstr2cidr(maskstr)
	local ip = ipstr2int(maskstr)
	return int2cidr(ip)
end

local function get_ip_and_mask(ipaddr)
	local n = get_parts_as_number(ipaddr)
	return (((n[1] * 256 + n[2]) * 256 + n[3]) * 256 + n[4]), cidr2int(n[5])
end

local function get_ipstr_and_maskstr(ipaddr)
	local ip, mask = get_ip_and_mask(ipaddr)
	return int2ipstr(ip), int2ipstr(mask)
end

local function ipstr2range(ipstr)
	ip = get_parts_as_number(ipstr)
	if #ip == 4 then
		local i = (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
		return {i, i}
	elseif #ip == 5 and ip[5] >=1 and ip[5] <= 32 then
		local i = (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
		local m = cidr2int(ip[5])
		local s = _band(i, m)
		local e = _bor(i, _bnot(m))
		return {s, e}
	elseif #ip == 8 then
		local s = (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
		local e = (((ip[5] * 256 + ip[6]) * 256 + ip[7]) * 256 + ip[8])
		if s <= e then
			return {s, e}
		end
	end

	return nil
end

local function ipgroup_add(ipgrp, ipstr)
	local range = ipstr2range(ipstr)
	if not range then
		return ipgrp
	end

	ipgrp = ipgrp or {}
	if #ipgrp == 0 then
		table.insert(ipgrp, range)
		return ipgrp
	end

	local ipgrp_new = {}
	for _, r in ipairs(ipgrp) do
		if range[1] < r[1] then
			if range[2] < r[1] then
				table.insert(ipgrp_new, range)
				range = r
			elseif range[2] >= r[1] and range[2] <= r[2] then
				range = {range[1], r[2]}
			end
		elseif range[1] >= r[1] and range[1] <= r[2] then
			if range[2] <= r[2] then
				range = {r[1], r[2]}
			elseif range[2] > r[2] then
				range = {r[1], range[2]}
			end
		else
			table.insert(ipgrp_new, r)
		end
	end
	table.insert(ipgrp_new, range)

	return ipgrp_new
end

--[[
local ipranges = {
	"1.1.1.1-2.2.2.2",
	"192.168.0.0/16",
	"192.168.0.1-192.168.0.2",
	"192.168.255.254-192.169.0.100",
	"172.16.0.1-172.16.0.100"
}
]]
local function ipranges2ipgroup(ipranges)
	local ipgrp = {}
	for _, ipstr in ipairs(ipranges) do
		ipgrp = ipgroup_add(ipgrp, ipstr)
	end
	return ipgrp
end

local function ipgroup2ipranges(ipgrp)
	local ipranges = {}
	for _, range in ipairs(ipgrp) do
		table.insert(ipranges, string.format("%s-%s", int2ipstr(range[1]), int2ipstr(range[2])))
	end
	return ipranges
end

--[[
local ipgrp = ipranges2ipgroup(ipranges)
ipranges = ipgroup2ipranges(ipgrp)
for _, ipstr in ipairs(ipranges) do
	print(ipstr)
end
]]

return {
	ipstr2int = ipstr2int,
	int2ipstr = int2ipstr,
	cidr2int = cidr2int,
	int2cidr = int2cidr,
	cidr2maskstr = cidr2maskstr,
	maskstr2cidr = maskstr2cidr,
	get_ip_and_mask = get_ip_and_mask,
	get_ipstr_and_maskstr = get_ipstr_and_maskstr,

	lshift = _lshift,
	rshift = _rshift,
	band = _band,
	bor = _bor,
	bxor = _bxor,
	bnot = _bnot,

	ipranges2ipgroup = ipranges2ipgroup,
	ipgroup2ipranges = ipgroup2ipranges,
	ipgroup_add = ipgroup_add,
	ipstr2range = ipstr2range
}
