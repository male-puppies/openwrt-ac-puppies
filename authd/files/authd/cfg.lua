local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")

local rid_map = {}
local myconn, udpsrv, mqtt

local function init(m, u, p)
	myconn, udpsrv, mqtt = m, u, p
end

local function reset_authtype()
	local rs, e = myconn:query("select * from authrule") 	assert(rs, e)
	
	rid_map = {}
	for _, r in ipairs(rs) do 
		local tp, authtype = r.type, "web"
		if tp:find("auto") then 
			authtype = "auto" 
		elseif tp:find("radius") then 
			authtype = "radius"
		end 
		r.authtype = authtype
		rid_map[r.rid] = r
	end
end

local function get_authtype(rid)
	local r = rid_map[rid]
	if not r then 
		reset_authtype()
		r = rid_map[rid]
	end
	return r.authtype
end

return {init = init, get_authtype = get_authtype, reset_authtype = reset_authtype}

