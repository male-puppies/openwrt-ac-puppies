local js = require("cjson.safe")
local query = require("common.query")

local query_u = query.query_u

local cache = {}

local function get(k)
	return cache[k]
end 

local function set(k, f)
	cache[k] = f
end

local mac_pattern = (function()
	local arr = {}
	for i = 1, 6 do table.insert(arr, "[0-9a-zA-z][0-9a-zA-z]") end 
	return string.format("^%s$", table.concat(arr, ":"))
end)()

local ip_pattern = (function()
	local arr = {}
	for i = 1, 4 do table.insert(arr, "[0-9][0-9]?[0-9]?") end 
	return string.format("^%s$", table.concat(arr, "%."))
end)()

local function reply_e(e)
	ngx.say(js.encode({status = 1, data = e}))
	return true
end

local function reply(d)
	ngx.say(js.encode({status = 0, data = d}))
	return true
end

local function merge(to, from)
	for k, v in pairs(from) do 
		to[k] = v 
	end 
	return to 
end

local sqlite3_select_code = [[
	local myconn = require("mgr").ins().myconn
	return myconn:select(arg)
]]

local function sqlite3_select_common(sql, code, timeout)
	return query_u("127.0.0.1", 51234, {cmd = "rpc", k = "sqlite3_select_code", p = sql, f = code, r = 1}, timeout or 3000)
end

local function sqlite3_select(sql, timeout)
	local r, e = sqlite3_select_common(sql, nil, timeout)
	if not r then 
		return nil, e 
	end 
	
	local r, e = js.decode(r)   
	if not r then 
		return nil, e
	end

	if not r.e then
		return r.d
	end

	if r.d ~= "miss" then 
		return nil, r.d 
	end

	local r, e = sqlite3_select_common(sql, sqlite3_select_code, timeout)
	if not r then 
		return nil, e 
	end 

	local r, e = js.decode(r)
	if not r then 
		return nil, e
	end

	if not r.e then
		return r.d 
	end

	return nil, r.d
end

return {
	get = get, 
	set = set,
	merge = merge,
	reply = reply,
	reply_e = reply_e,
	ip_pattern = ip_pattern,
	mac_pattern = mac_pattern,
	mysql_select = sqlite3_select,
}
