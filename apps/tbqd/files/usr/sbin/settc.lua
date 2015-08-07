local js = require("cjson")

local function decode(s)
	return js.decode(s)
end 

local function encode(t)
	local s = js.encode(t)
	return s:gsub("{}", "[]")
end 

local function read(path, func)
	func = func and func or io.open
	local fp = func(path, "rb")
	if not fp then 
		return 
	end 
	local s = fp:read("*a")
	fp:close()
	return s
end

local function parseRateDesc(rate)
	local a, b, c = rate:match("^%s*(%d+)%s*([KM])%s*(bps)%s*$") 
	if not a then 
		a, b, c = rate:match("^%s*(%d+)%s*([KM])%s*(Bytes)%s*$")
	end 

	if not a then 
		return 0
	end 

	local num = tonumber(a)
	local factor = b == "K" and 1000 or 1000 * 1000
	local bps = c == "bps" and true or false 
	local maxRate = 2 * 1000 * 1000 * 1000
	maxRate = bps and maxRate * 8 or maxRate
	if num > maxRate/factor then 
		return 0
	end 
	num = num * factor
	num = bps and math.floor(num / 8) or num
	return num
end

local function tbqRateFromTCRate(rate)
	local num = parseRateDesc(rate)
	if not num then 
		return "0M"
	end 
	
	if math.mod(num, 1000000000) == 0 then 
		return string.format("%dG", math.floor(num / 1000000000))
	end 

	if math.mod(num, 1000000) == 0 then 
		return string.format("%dM", math.floor(num / 1000000))
	end 

	if math.mod(num, 1000) == 0 then 
		return string.format("%dK", math.floor(num / 1000))
	end 

	return string.format("%d", num)
end 

local function setTCRate(rule, sharedUpload, sharedDownload, perIpUpload, perIpDownload)
	rule.UploadLimit.Shared = tbqRateFromTCRate(sharedUpload)
	rule.UploadLimit.PerIp = tbqRateFromTCRate(perIpUpload)
	rule.DownloadLimit.Shared = tbqRateFromTCRate(sharedDownload)
	rule.DownloadLimit.PerIp = tbqRateFromTCRate(perIpDownload)
end

local function new_rule()
	return {
		Name = "UI-GLOBAL",
		IpIncluded = {},
		IpExcluded = {},
		AppIncluded = {},
		AppExcluded = {},
		UploadLimit = {Shared = "", PerIp = ""},
		DownloadLimit = {Shared = "", PerIp = ""},
	}
end 

local function convert(s)
	local tc = decode(s)
	local tbqcfg = {
		MaxBacklogPackets = 9999,
		Rules = {new_rule()},
	}
	setTCRate(tbqcfg.Rules[1], tc.GlobalSharedUpload, tc.GlobalSharedDownload, tc.GlobalSharedUpload, tc.GlobalSharedDownload)

	for _, rule in ipairs(tc.Rules) do 
		if rule.Enabled then
			local tbqrule = new_rule()
			tbqrule.Name = string.format("UI-<%s>", rule.Name)
			tbqrule.IpIncluded = {rule.Ip}
			setTCRate(tbqrule, rule.SharedUpload, rule.SharedDownload, rule.PerIpUpload, rule.PerIpDownload)
			table.insert(tbqcfg.Rules, tbqrule)
		end
	end

	return encode(tbqcfg)
end

local path = ... 	assert(path)
local s = read(path)
local s = convert(s)
print(s)
