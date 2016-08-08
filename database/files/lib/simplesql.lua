local js = require("cjson.safe")
local code = [[
	local conn = require("mgr").ins().conn
	local param, isexec, memo = arg[1], arg[2], arg[3]
	if not isexec then 
		local r, e = conn:select(param)
		if not r then 
			return nil, e 
		end

		return r
	end

	if type(param) == "string" then 
		param = {param}
	end 

	return conn:transaction(function()
		for _, sql in ipairs(param) do 
			local r, e = conn:execute(sql) 	assert(r, e)
		end
		local _ = memo or require("mgr").ins().ud:save_log(param, true)
		return true
	end)
]]

local code_key = "sqlsingle_simple"
local method = {}
local mt = {__index = method}

function method:select(sql)
	assert(type(sql) == "string")
	return self.rpc:fetch(code_key, code, {sql})
end

function method:select2(sql)
	assert(type(sql) == "string")
	local r, e = self.rpc:fetch(code_key, code, {sql}) 	assert(r, e or sql)
	return r
end

function method:execute(sql) 
	assert(type(sql) == "string")
	return self.rpc:fetch(code_key, code, {sql, 1})
end

function method:execute2(sql)
	assert(type(sql) == "string")
	local r, e = self.rpc:fetch(code_key, code, {sql, 1}) 			assert(r, e or sql)
	return r
end

function method:exec_batch(sqls) 
	assert(type(sqls) == "table")
	return self.rpc:fetch(code_key, code, {sqls, 1})
end

function method:exec_batch2(sqls)
	assert(type(sqls) == "table")
	local r, e = self.rpc:fetch(code_key, code, {sqls, 1}) 			assert(r, e)
	return r
end

function method:executem(sql) 
	assert(type(sql) == "string")
	return self.rpc:fetch(code_key, code, {sql, 1, 1})
end

function method:executem2(sql)
	assert(type(sql) == "string")
	local r, e = self.rpc:fetch(code_key, code, {sql, 1, 1}) 		assert(r, e or sql)
	return r
end

function method:exec_batchm(sqls) 
	assert(type(sqls) == "table")
	return self.rpc:fetch(code_key, code, {sqls, 1, 1})
end

function method:exec_batchm2(sqls)
	assert(type(sqls) == "table")
	local r, e = self.rpc:fetch(code_key, code, {sqls, 1, 1}) 		assert(r, e)
	return r
end

----------------------------------
local mysql_code_key = "mysql_code_key"
local mysql_code = [[
	local myconn = require("mgr").ins().myconn
	local sql, isexec = arg[1], arg[2]
	if isexec then 
		return myconn:execute(sql)
	end 
	return myconn:select(sql)
]]

function method:mysql_select(sql)
	return self.rpc:fetch(mysql_code_key, mysql_code, {sql})
end

function method:mysql_execute(sql)
	return self.rpc:fetch(mysql_code_key, mysql_code, {sql, 1})
end

local function new(rpc)
	assert(rpc)
	local obj = {rpc = rpc}
	setmetatable(obj, mt)
	return obj 
end

return {new = new}
