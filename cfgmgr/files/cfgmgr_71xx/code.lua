local m = {}

m.authd_execute = [[
	local myconn = require("mgr").ins().myconn
	return myconn:execute(arg)
]]


m.authd_select = [[
	local myconn = require("mgr").ins().myconn
	return myconn:select(arg)
]]

local function get(k)
	return k, m[k]
end

local function simple_select(dbrpc, sql)
	local k, f = get("authd_select")
	return dbrpc:fetch(k, f, sql)
end

local function simple_execute(dbrpc, sql)
	local k, f = get("authd_execute")
	return dbrpc:fetch(k, f, sql)
end

return {get = get, select = simple_select, execute = simple_execute}