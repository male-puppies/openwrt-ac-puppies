local bit = require("bit")

local function get_parts_as_number(ipstr)
	local t = {}
	for part in string.gmatch(ipstr, "%d+") do
		t[#t+1] = tonumber(part, 10)
	end
	return t
end

local function ipstr2int(ipstr)
	ip = get_parts_as_number(ipstr)
	if #ip == 4 then
		return (((ip[1] * 256 + ip[2]) * 256 + ip[3]) * 256 + ip[4])
	end
	return 0
end

local function int2ipstr(ip)
	local n = {}
	n[1] = bit.band(bit.rshift(ip, 24), 0x000000FF)
	n[2] = bit.band(bit.rshift(ip, 16), 0x000000FF)
	n[3] = bit.band(bit.rshift(ip, 8), 0x000000FF)
	n[4] = bit.band(bit.rshift(ip, 0), 0x000000FF)

	return string.format("%u.%u.%u.%u", n[1], n[2], n[3], n[4])
end

local function cidr2int(cidr)
	local x = 0;
	for i = 0, cidr - 1, 1 do
		x = x + bit.lshift(1, 31 - i)
	end
	return x
end

local function int2cidr(ip)
	for i = 0, 31, 1 do
		if bit.band(ip, bit.lshift(1, 31 - i)) == 0 then
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

return {
	ipstr2int = ipstr2int,
	int2ipstr = int2ipstr,
	cidr2int = cidr2int,
	int2cidr = int2cidr,
	cidr2maskstr = cidr2maskstr,
	maskstr2cidr = maskstr2cidr,
	get_ip_and_mask = get_ip_and_mask,
	get_ipstr_and_maskstr = get_ipstr_and_maskstr
}
