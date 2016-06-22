local log = require("log")
local mgr = require("mgr") 
local js = require("cjson.safe")

local method = {}
local mt = {__index = method}

local function clear_all(myconn, tbname)
	local sql = string.format("delete from %s", tbname)
	local r, e = myconn:query(sql) 
	local _ = r or log.fatal("%s %s", sql, e)
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

local function sync_all(conn, myconn, tbname)
	local sql = "select * from " .. tbname 
	local rs, e = conn:select(sql)
	local _ = rs or log.fatal("%s %s", sql, e)
	
	if #rs == 0 then 
		return 
	end
	
	local sql = format_replace(conn, rs, tbname)
	local r, e = myconn:query(sql) 	
	local _ = r or log.fatal("%s %s", sql, e)
end

local function sync_set(conn, myconn, tbname, last_active, total) 
	local sql = string.format("select max(active) as active, count(*) as count from %s", tbname)
	local rs, e = myconn:query(sql) 	
	local _ = rs or log.fatal("%s %s", sql, e)

	local last_mysql_active, last_mysql_total = rs[1].active, tonumber(rs[1].count)  			assert(total >= last_mysql_total)
	if last_mysql_total == 0 then 
		last_mysql_active = "0000-00-00 00:00:00"
	end 

	local sql = string.format("select * from %s where active>'%s'", tbname, last_mysql_active)
	local rs, e = conn:select(sql) 	
	local _ = rs or log.fatal("%s %s", sql, e)

	if #rs == 0 then 
		return 
	end

	local sql = format_replace(conn, rs, tbname)
	local r, e = myconn:query(sql) 	
	local _ = r or log.fatal("%s %s", sql, e)
end

local function sync_del(conn, myconn, tbname, keyname) 
	local old, new, del = {}, {}, {}
	local sql =string.format("select %s from %s", keyname, tbname)
	local rs, e = myconn:query(sql) 
	local _ = rs or log.fatal("%s %s", sql, e)

	for _, r in ipairs(rs) do 
		old[r[keyname]] = 1 
	end

	local rs, e = conn:select(sql) 	
	local _ = rs or log.fatal("%s %s", sql, e)

	for _, r in ipairs(rs) do 
		new[r[keyname]] = 1 
	end

	for k in pairs(old) do 
		local _ = new[k] or table.insert(del, string.format("'%s'", k)) 
	end

	if #del > 0 then
		local sql = string.format("delete from %s where %s in (%s)", tbname, keyname, table.concat(del, ","))
		local r, e = myconn:query(sql) 				
		local _ = r or log.fatal("%s %s", sql, e)
	end
end

local function sync_part(conn, myconn, tbname, keyname, action) 
	local sql = string.format("select max(active) as active, count(*) as count from %s", tbname)
	local rs, e =  conn:select(sql)
	local _ = rs or log.fatal("%s %s", sql, e)

	local active, total, now = rs[1].active, tonumber(rs[1].count), os.date("%Y-%m-%d %H:%M:%S")
	-- active = "2020-06-21 10:54:37"
	if active > now then
		print("invalid system time", active, now, "sync all")
		return sync_all(conn, myconn, tbname)
	end

	local _ = action.del and sync_del(conn, myconn, tbname, keyname) 		-- 同一次修改中有增删改时，先执行删除的同步
	local _ = (action.add or action.set) and sync_set(conn, myconn, tbname, active, total)
end

function method:sync(action, init)
	if init then 
		-- 程序启动时，清空mysql并同步所有
		local ins = mgr.ins()
		self.conn, self.myconn = ins.conn, ins.myconn 
		local conn, myconn, tbname, keyname = self.conn, self.myconn, self.tbname, self.keyname assert(conn and myconn and tbname and keyname) 
		return clear_all(myconn, tbname), sync_all(conn, myconn, tbname)
	end
	
	local conn, myconn, tbname, keyname = self.conn, self.myconn, self.tbname, self.keyname assert(conn and myconn and tbname and keyname) 
	return sync_part(conn, myconn, tbname, keyname, action)
end 

local function new(tbname, keyname)
	local obj = {tbname = tbname, keyname = keyname, conn = nil, myconn = nil}
	setmetatable(obj, mt)
	return obj
end

return {new = new}
