local redis = require "resty.redis" 

-- 访问redis的简单封装，set_keepalive会把连接放在连接池，查询失败调用close，成功调用reserve

local function get()
	local rds = redis:new()
	rds:set_timeout(1000)
	local r, e = rds:connect("127.0.0.1", 6379)
	if not r then
		return nil, e
	end
	return rds
end

local function reserve(rds, res)
	local _ = rds:set_keepalive(10000, 100) or rds:close()
	return res
end 

local function reserve_e(rds, err)
	local _ = rds:set_keepalive(10000, 100) or rds:close()
	return nil, err
end 

local function close(rds, e)
	rds:close()
	return nil, e
end

return {
	get = get,
	close = close,
	reserve = reserve,
	reserve_e = reserve_e, 
}
