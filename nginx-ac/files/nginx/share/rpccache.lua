local cache = {}

local function get(k)
	return cache[k]
end 

local function set(k, f)
	cache[k] = f
end

return {get = get, set = set}
