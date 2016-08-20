local js = require("cjson.safe")

local strip = false
local method = {}
local mt = {__index = method}
function method:fetch(name, f, arg)
	assert(name and type(f) == "string")
	local data = {cmd = "rpc", k = name, p = arg} 		-- do not trans f for the first time
	local r, e = self.proxy:query(self.topic, data)
	if e then
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

	local data = {cmd = "rpc", k = name, p = arg, f = f}
	local r, e = self.proxy:query(self.topic, data)
	if e then
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

function method:once(f, arg)
	assert(type(f) == "string")
	local data = {cmd = "rpc", p = arg, f = f, r = 1}
	local r, e = self.proxy:query(self.topic, data)
	if e then
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

function method:exec(f, arg)
	assert(type(bt) == "string")
	local data = {pld = {cmd = "rpc", p = arg, f = f}}
	self.proxy:publish(self.topic, js.encode(data))
	return true
end

local function new(proxy, topic)
	local obj = {proxy = proxy, cache = {}, topic = topic}
	setmetatable(obj, mt)
	return obj
end

return {new = new}
