local mysql = require "resty.mysql"

-- 访问mysql的简单封装，set_keepalive会把连接放在连接池，查询失败调用close，成功调用reserve

local function get(dbname)
	local db, err = mysql:new()
	if not db then 
		return nil, err
	end

	local ok, err, errno, sqlstate = db:connect{
		host = "127.0.0.1",
		port = 3306,
		database = "mysql",
		user = "root",
		password = "wjrc0409",
		max_packet_size = 1024 * 1024
	}

	if not ok then
		db:close()
		return nil, string.format("fail to connect mysql %s %s %s", err, errno, sqlstate)
	end

	return db
end

local function reserve(db, res)
	local _ = db:set_keepalive(10000, 100) or db:close() 
	return res
end 

local function reserve_e(db, err)
	local _ = db:set_keepalive(10000, 100) or db:close() 
	return nil, err
end 

local function close(db, e)
	db:close()
	return nil, e
end

local function transaction_aux(f, db)
	local r, e = db:query("START TRANSACTION")
	if not r then 
		return nil, e
	end

	local r, e = f(db)
	if not r then
		local r1, e1 = db:query("ROLLBACK")
		if not r1 then 
			return nil, e1
		end 
		return nil, e
	end

	local r, e = db:query("COMMIT")
	if not r then
		local r1, e1 = db:query("ROLLBACK")
		if not r1 then 
			return nil, e1
		end
		return nil, e
	end

	return true
end

local function transaction(f)
	local db, e = get()
	if not db then 
		return nil, e
	end

	local r, e = transaction_aux(f, db)
	if not r then 
		close(db)
		return nil, e
	end

	return reserve(db, r)
end

local function query(f)
	local db, e = get()
	if not db then 
		return nil, e
	end

	local r, e = f(db)
	if not r then 
		close(db)
		return nil, e
	end

	return reserve(db, r)
end

return {
	get = get,
	close = close,
	reserve = reserve,
	reserve_e = reserve_e, 

	query = query,
	transaction = transaction,
}
