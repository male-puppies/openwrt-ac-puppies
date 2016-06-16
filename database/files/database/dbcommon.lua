local log = require("log")
local luasql = require("luasql.sqlite3")

local env = luasql.sqlite3()

local method = {}
local mt = {__index = method}

function method:escape(sql)	return self.conn:escape(sql) end
function method:close() self.conn:close() self.conn = nil end 
function method:execute(sql) return self.conn:execute(sql) end

local function select_cb_common(conn, sql, cb)
	local cur, err = conn:execute(sql)
	if not cur then return nil, err end

	local row = cur:fetch({}, "a")
	while row do
		cb(row)
		row, err = cur:fetch(row, "a")	-- reusing the table of results
		if err then return nil, err end
	end
	cur:close()

	return true
end

function method:select(sql) 
	local arr = {}
	local ret, err = select_cb_common(self.conn, sql, function(row)
		local nmap = {}
		for k, v in pairs(row) do nmap[k] = v end 
		table.insert(arr, nmap)
	end) 
	if not ret then return nil, err end 
	return arr
end

local function rollback(conn, sql, err)
	log.error("rollback for %s %s", sql or "", err or "")
	return conn:execute("rollback")
end

function method:transaction(f)
	local ret, err = self:execute("begin transaction") 	assert(ret, err)
	local r, d = pcall(f, self)
	if r then 
		local ret, err = self:execute("commit")  		assert(ret, err)
		return d
	end
	local ret, err = self:execute("rollback") 		assert(ret, err)
	assert(false, d)
end

function method:protect(f)
	local r, d = pcall(f, self)
	if r then 
		return d
	end
	assert(false, d)
end


function new(diskpath, attaches)
	local conn, err = env:connect(diskpath)
	local _ = conn or log.fatal("connect %s fail %s", diskpath, err or "")
	
	for _, item in ipairs(attaches or {}) do 
		local path, alias = item.path, item.alias 	assert(path and alias)
		local sql = string.format("attach database '%s' as '%s'", path, alias)
		local ret, err = conn:execute(sql)
		local _ = ret or log.fatal("attach fail %s", err)
	end

	local obj = {conn = conn}
	setmetatable(obj, mt)
	return obj
end

return {new = new}

