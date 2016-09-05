local log = require("log")
local mgr = require("mgr")
local js = require("cjson.safe")

local sync_tables

local function parse_sync_tables()
	local conn = mgr.ins().conn 								assert(conn)
	local rs, e = conn:select("select distinct tbl_name from sqlite_master where type='trigger'")  	assert(rs, e)
	local arr = {}
	for _, r in ipairs(rs) do
		table.insert(arr, r.tbl_name)
	end
	return arr
end

local function format_replace(conn, rs, tbname)
	local fields = {}
	for k in pairs(rs[1]) do
		table.insert(fields, k)
	end

	local narr = {}
	for _, r in ipairs(rs) do
		local arr = {}
		for _, field in ipairs(fields) do
			table.insert(arr, string.format("'%s'", conn:escape(r[field])))
		end
		table.insert(narr, string.format("(%s)", table.concat(arr, ",")))
	end

	return string.format("replace into %s (%s) values %s", tbname, table.concat(fields, ","), table.concat(narr, ","))
end

local function format_delete(conn, rs, tbname)
	local field = rs[1].key

	local map, arr = {}, {}
	for _, r in ipairs(rs) do
		map[string.format("'%s'", conn:escape(r.val))] = 1
	end
	for k in pairs(map) do table.insert(arr, k) end

	return string.format("delete from %s where %s in (%s)", tbname, field, table.concat(arr, ","))
end

local function sync_all_tables()
	local ins = mgr.ins()
	local conn, myconn = ins.conn, ins.myconn

	local sync_one_table = function(tbname)
		local sql = "delete from " .. tbname
		local r, e = myconn:execute(sql)
		local _ = r or log.fatal("%s %s", sql, e)

		local sql = "select * from " .. tbname
		local rs, e = conn:select(sql)
		local _ = rs or log.fatal("%s %s", sql, e)

		if #rs == 0 then
			return
		end
		local sql = format_replace(conn, rs, tbname)
		local r, e = myconn:execute(sql)
		local _ = r or log.fatal("%s %s", sql, e)
	end

	local broad = {}
	for _, tbname in ipairs(sync_tables) do
		sync_one_table(tbname)
		broad[tbname] = {all = 1}
	end

	local r, e = conn:execute("delete from trigger") 	assert(r, e)
	return broad
end

local function sync_trigger()
	local ins = mgr.ins()
	local conn, myconn = ins.conn, ins.myconn

	local sql = "select count(*) as count from trigger"
	local rs, e = conn:select(sql)
	local _ = rs or log.fatal("%s %s", sql, e)
	if tonumber(rs[1].count) == 0 then
		return {}
	end

	local sql = "select * from trigger order by rowid"
	local rs, e = conn:select(sql)
	local _ = rs or log.fatal("%s %s", sql, e)

	local tbmap = {}
	for _, r in ipairs(rs) do
		local tbname = r.tb
		local actions = tbmap[tbname] or {del = {}, set = {}, add = {}}
		table.insert(actions[r.act], r)
		tbmap[tbname] = actions
	end

	for tbname, actions in pairs(tbmap) do
		local arr = actions.del
		if #arr > 0 then
			local sql = format_delete(conn, arr, tbname)
			local r, e = myconn:execute(sql)
			local _ = r or log.fatal("%s %s", sql, e)
		end

		arr = actions.set
		for _, r in ipairs(actions.add) do
			table.insert(arr, r)
		end

		actions.add = nil

		if #arr > 0 then
			local map = {}
			for _, r in ipairs(arr) do
				map[string.format("'%s'", conn:escape(r.val))] = 1
			end

			local arr = {}
			for k in pairs(map) do table.insert(arr, k) end

			local sql = string.format("select * from %s where %s in (%s)", tbname, rs[1].key, table.concat(arr, ","))
			local rs, e = conn:select(sql)
			local _ = rs or log.fatal("%s %s", sql, e)
			local sql = format_replace(conn, rs, tbname)
			local r, e = myconn:execute(sql)
			local _ = r or log.fatal("%s %s", sql, e)
		end
	end

	local r, e = conn:execute("delete from trigger") 	assert(r, e)

	local get_keys = function(arr)
		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, r.val)
		end
		return narr
	end

	local broad = {}
	for tbname, actions in pairs(tbmap) do
		local item = {}
		local del, set = actions.del, actions.set
		if #del > 0 then
			item.del = get_keys(del)
		end
		if #set > 0 then
			item.set = get_keys(set)
		end
		if item.set or item.del then
			broad[tbname] = item
		end
	end

	return broad
end

local function sync()
	if not sync_tables then
		sync_tables = parse_sync_tables() 	assert(sync_tables)
		return sync_all_tables()
	end

	return sync_trigger()
end

return {sync = sync}
