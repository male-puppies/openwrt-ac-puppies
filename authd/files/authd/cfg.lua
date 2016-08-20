local fp 	= require("fp")
local ski 	= require("ski")
local log 	= require("log")
local js 	= require("cjson.safe")
local rpccli 	= require("rpccli")
local simplesql = require("simplesql")

local rid_map = {}
local simple, udpsrv, mqtt

local function init(u, p)
	udpsrv, mqtt = u, p
	local dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	simple = simplesql.new(dbrpc)
end

-- 重新查询并缓存表authrule
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

local function check_module()
	if ukey_module_map then
		return
	end

	local rs, e = simple:mysql_select("select ukey,type from memo.online") 	assert(rs, e)
	ukey_module_map = fp.reduce(rs, function(t, r) return rawset(t, r.ukey, r.type) end, {})
	print("init mod",  js.encode(ukey_module_map))
end

local function set_module(ukey, mod)
	check_module()
	if not ukey_module_map[ukey] then
		ukey_module_map[ukey] = mo
	end
	print("set_module", js.encode(ukey_module_map))
end

local function get_module(ukey)
	check_module()
	return ukey_module_map[ukey]
end

-- 根据rid返回对应的authtyle
local function get_authtype(rid)
	local r = rid_map[rid]
	if not r then
		reset_authtype()
		r = rid_map[rid]
	end
	return r and r.authtype or nil
end

-- 根据rid返回对应的组id
local function get_gid(rid)
	local r = rid_map[rid]
	if not r then
		reset_authtype()
		r = rid_map[rid]
	end

	return r and r.gid or nil
end

-- 清空缓存的authrule
local function clear_authtype()
	rid_map = {}
end

return {
	init 			= init,
	get_gid 		= get_gid,
	get_authtype 		= get_authtype,
	clear_authtype 		= clear_authtype,

	set_authtype		= set_authtype,
	set_module 		= set_module,
	get_module 		= get_module,
}

