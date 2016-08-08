local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")

local rid_map = {}
local simple, udpsrv, mqtt

local function init(u, p)
	udpsrv, mqtt = u, p
	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	local simple = simplesql.new(dbrpc)
end

local function reset_authtype()
	local rs, e = simple:mysql_select("select * from authrule") 	assert(rs, e)
	
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

