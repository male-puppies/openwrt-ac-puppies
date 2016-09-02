local log = require("log")
local country

local country_map = {
	["China"]			=	{code = 156, short = "CN"},
	["US"]				=  	{code = 840, short = "US"},
	["Japan"]			=	{code = 392, short = "JP"},
	["South Korea"]		=	{code = 410, short = "KR"},
	["Malaysia"]		=	{code = 458, short = "MY"},
	["India"]			=	{code = 356, short = "IN"},
	["Thailand"]		=	{code = 764, short = "TH"},
	["Vietnam"]			=	{code = 704, short = "VN"},
	["Indonesia"]		=	{code = 360, short = "ID"},
	["United Kingdom"]	=  	{code = 826, short = "GB"},
	["Singapore"]		=	{code = 702, short = "SG"},
}

local function short(ctry)
	local item = country_map[ctry]
	if item then
		return item.short
	end
end

local function code(ctry)
	local item = country_map[ctry]
	if item then
		return item.code
	end
	log.fatal("not support country %s", ctry)
end

return {
	code = code,
	short = short,
}
