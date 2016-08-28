local luasql = require("luasql.sqlite3")

local env = luasql.sqlite3()

local method = {}
local mt = {__index = method}

function method:escape(sql)	return self.conn:escape(sql) end
function method:close() self.conn:close() self.conn = nil end
function method:execute(sql) return self.conn:execute(sql) end

function method:select(sql)
	local cur, err = self.conn:execute(sql)
	if not cur then
		return nil, err
	end

	local arr = {}
	local row = cur:fetch({}, "a")
	while row do
		table.insert(arr, row)
		row, err = cur:fetch({}, "a")	-- reusing the table of results
		if err then
			return nil, err
		end
	end
	cur:close()

	return arr
end

local function rollback(conn, sql, err)
	return conn:execute("rollback")
end

function new(diskpath, attaches)
	local conn, err = env:connect(diskpath) 	assert(conn, err)

	for _, item in ipairs(attaches or {}) do
		local path, alias = item.path, item.alias 	assert(path and alias)
		local sql = string.format("attach database '%s' as '%s'", path, alias)
		local ret, err = conn:execute(sql) 	assert(ret, err)
	end

	-- local params = {"PRAGMA journal_mode=memory", "PRAGMA locking_mode=EXCLUSIVE", "PRAGMA foreign_keys = ON", "PRAGMA auto_vacuum=FULL"}
	local params = {"PRAGMA journal_mode=memory", "PRAGMA foreign_keys = ON", "PRAGMA auto_vacuum=FULL"}
	for _, sql in ipairs(params) do
		local r, e = conn:execute(sql) 	assert(r, e)
	end

	local obj = {conn = conn}
	setmetatable(obj, mt)
	return obj
end

return {new = new}

