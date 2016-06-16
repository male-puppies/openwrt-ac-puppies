local js = require("cjson.safe")

local method = {}
local mt = {__index = method} 

local function reply(d)
	return type(d) == "table" and js.encode(d) or d
end

local function execute(f, p, r)
	if p then 
		_G["arg"] = p 
	end
	local res, m = pcall(f)
	_G["arg"] = nil
	local res = {d = m or "error", e = (not res) and 1 or nil}
	return r and js.encode(res) or nil
end

function method:execute(rpc)
	local k, p, bt, r = rpc.k, rpc.p, rpc.f, rpc.r
	if not k then 		-- once or exec
		if not bt then 
			return 
		end 

		local f, e = load(bt, nil, "bt", _G)
		if not f then 
			return reply({d = e, e = 1})
		end
		return execute(f, p, r)
	end
	
	if bt then 
		local f, e = load(bt, nil, "bt", _G)
		if not f then 
			return reply({d = e, e = 1})
		end
		self.cache[k] = f
	end

	local f = self.cache[k]
	if not f then
		return reply({d = "miss", e = 1})
	end

	return execute(f, p, 1)
end

local function new()
	local obj = {cache = {}}
	setmetatable(obj, mt)
	return obj
end

return {new = new}

