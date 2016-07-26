local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local code = require("code")

local rid_map = {}
local dbrpc, udpsrv, mqtt
local mysql_select = code.select

local function init(u, p)
	udpsrv, mqtt = u, p
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
end

local function reset_authtype()
	local rs, e = mysql_select(dbrpc, "select * from authrule") 	assert(rs, e)
	
	rid_map = {}
	for _, r in ipairs(rs) do 
		local tp, authtype = r.authtype, "web"
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

local function get_gid(rid)
	local r = rid_map[rid]
	if not r then 
		reset_authtype()
		r = rid_map[rid]
	end
	
	return r and r.gid or nil
end

local function clear_authtype()
	rid_map = {}
end

return {
	init = init, 
	get_gid = get_gid, 
	get_authtype = get_authtype, 
	clear_authtype = clear_authtype,
}

