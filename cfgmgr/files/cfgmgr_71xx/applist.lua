-- author: gx

local log = require("log")
local js = require("cjson.safe")
local common = require("common")
local rpccli = require("rpccli")
local simplesql = require("simplesql")


local simple
local read, file_exist = common.read, common.file_exist
local applist = "/etc/config/applist.json"

local function recover_default(path)
	local cmd = string.format("cp %s %s", "/usr/share/base-config/applist.json", path)
	local ret = os.execute(cmd)		assert(ret)
	return ret
end

local function load_applist()
	local app_map, sql_map, new_app = {}, {}, {}

	if not file_exist(applist) then
		recover_default(applist)
	end

	local s = read(applist) assert(s)
	new_app = js.decode(s) 	assert(new_app)
	if new_app then
		for k, v in pairs(new_app) do
			app_map[k] = v.version
		end
	end

	local rs, e = simple:mysql_select("select proto_id, version from acproto")
	if not e then
		for _, v in ipairs(rs) do
			sql_map[v.proto_id] = v.version
		end
	else
		log.fatal("fetch data from acproto failed for %s",e)
	end

	local v_del, v_add, v_set = {}, {}, {}
	for k, v in pairs(sql_map) do
		if not app_map[k] then
			local _ = table.insert(v_del, k)
		elseif not (app_map[k] == sql_map[k]) then
			local _ = table.insert(v_set, new_app[k])
		end
	end

	for k, v in pairs(app_map) do
		if not sql_map[k] then
			local _ = table.insert(v_add, new_app[k])
		end
	end
	local p = {
		dels = v_del,
		adds = v_add,
		sets = v_set,
	}

	local code = [[
		local js = require("cjson.safe")
		local ins = require("mgr").ins()
		local conn, ud, p = ins.conn, ins.ud, arg
		dels, adds, sets = p.dels, p.adds, p.sets
		local function svae_true(sql)
			local r, e = conn:execute(sql)
			if not e then
				ud:save_log(sql, ture)
			end
		end

		-- del protocol
		if next(dels) then
			for i, v in ipairs(dels) do
				local p = string.format("'%s'", v)
					dels[i] = p
				end
			local in_part = table.concat(dels, ", ")
			local sql = string.format("delete from acproto where proto_id in (%s)", in_part)
			svae_true(sql)
		end

		-- add protocol
		if next(adds) then
			for _, v in ipairs(adds) do
				local sql = string.format("insert into acproto %s values %s", conn:insert_format(v))
				svae_true(sql)
			end
		end

		-- set protocol
		if next(sets) then
			for _, v in ipairs(sets) do
				local sql = string.format("update acproto set %s where proto_id=%s", conn:update_format(v), v.proto_id)
				svae_true(sql)
			end
		end
		return true
	]]

	-- local r, e = dbrpc:fetch("cfgmgr_load_applist", code, p)
	local r, e = dbrpc:once(code, p)
	if not r then
		log.fatal("update acproto failed for %s", e)
	end
end

local function init(u, p)
	udpsrv, mqtt = u, p
	dbrpc = rpccli.new(mqtt, "a/ac/database_srv")
	simple = simplesql.new(dbrpc)
	load_applist()
end

return {init = init}
