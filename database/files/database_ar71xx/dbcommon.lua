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

function method:transaction(f)
	local r, e = self:execute("begin transaction")
	local _ = r or os.exit(-1)

	local res, msg, e = pcall(f, self)
	if not res then
		local r, e = self:execute("rollback")
		local _ = r or os.exit(-1)
		return nil, msg
	end

	local r, e = self:execute("commit")
	local _ = r or os.exit(-1)

	return msg
end

function method:update_format(m)
	local arr, conn = {}, self.conn
	for k, v in pairs(m) do
		table.insert(arr, string.format("%s='%s'", k, conn:escape(v)))
	end
	return table.concat(arr, ",")
end

function method:insert_format(m)
	local fields = {}
	for field in pairs(m) do
		table.insert(fields, field)
	end

	local arr, conn = {}, self.conn
	for _, field in ipairs(fields) do
		table.insert(arr, string.format("'%s'", conn:escape(m[field])))
	end

	return string.format("(%s)", table.concat(fields, ",")), string.format("(%s)", table.concat(arr, ","))
end

function method:next_id(ids, max)
	table.sort(ids)
	if #ids == max then
		return nil, "full"
	end

	if #ids == 0 then
		return 0
	end

	for i, v in ipairs(ids) do
		local vv = i - 1
		if v > vv then
			return vv
		end
	end

	return #ids
end
function new(diskpath, attaches)
	local conn, err = env:connect(diskpath) 	assert(conn, err)

	-- for _, item in ipairs(attaches or {}) do
	-- 	local path, alias = item.path, item.alias 	assert(path and alias)
	-- 	local sql = string.format("attach database '%s' as '%s'", path, alias)
	-- 	local ret, err = conn:execute(sql) 	assert(ret, err)
	-- end

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

