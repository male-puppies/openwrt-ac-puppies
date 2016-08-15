-- {"a", "b", "c"}, "a"
local function contains(arr, expect)
	for _, v in ipairs(arr) do 
		if v == expect then 
			return true 
		end 
	end
	return false
end

-- {"a", "b", "c"}, {"a"}			-> {a = 1, b = 1, c = 1}, {"a"} 
-- {"a", "b", "c"}, {a = 1}			-> {a = 1, b = 1, c = 1}, {a = 1}
-- {a = 1, b = 1, c = 1}, {"a"} 	
-- {a = 1, b = 1, c = 1}, {a = 1}
local function contains_any(t, other)
	local c1, c2, ma_tmp = #t, #other, t 
	if c1 > 0 then 
		ma_tmp = {}
		for _, v in ipairs(t) do 
			ma_tmp[v] = v 
		end 
	end

	if c2 == 0 then 
		for k in pairs(other) do 
			if ma_tmp[k] then 
				return true 
			end 
		end 
		return false 
	end 
	
	for _, k in ipairs(other) do 
		if ma_tmp[k] then 
			return true
		end 
	end

	return false
end 

local function tomap(arr, k)
	local m = {}
	if not k then
		for _, v in ipairs(arr) do 
			m[v] = 1
		end
		return m 
	end

	for _, v in ipairs(arr) do
		m[v[k]] = v 
	end

	return m 
end

local function map(t, f, ...)
	local m = {}
	for k, v in pairs(t) do 
		m[k] = f(k, v, ...)
	end 
	return m
end 

local function reduce(t, f, state)
	for _, v in pairs(t) do
		state = state and f(state, v) or v 
	end
	return state
end

local function set(t, k, v)
	t[k] = v 
	return t
end

local function each(t, f, ...)
	for k, v in pairs(t) do 
		f(k, v, ...)
	end
end

local function eachi(t, f, ...)
	for k, v in ipairs(t) do 
		f(k, v, ...)
	end
end

local function count(t, expect)
	local cnt = 0
	if not expect then
		for _ in pairs(t) do
			cnt = cnt + 1
		end 
		return cnt
	end 

	for _, v in pairs(t) do 
		if v == expect then
			cnt = cnt + 1
		end 
	end 
	return cnt
end

local function countf(t, f, ...)
	local cnt = 0
	for k, v in pairs(t) do 
		if f(k, v, ...) then 
			cnt = cnt + 1
		end
	end
	return cnt 
end

local function empty(t)
	for k in pairs(t) do 
		return false 
	end
	return true
end

local function emptyf(t, f, ...)
	for k, v in pairs(t) do 
		if f(k, v, ...) then 
			return false 
		end 
	end 
	return true
end

local function toarr(t)
	local arr = {}
	for k, v in pairs(t) do 
		table.insert(arr, v)
	end 
	return arr
end

local function keys(t)
	local ks = {}
	for k in pairs(t) do 
		table.insert(ks, k)
	end 
	return ks 
end

local function values(t)
	local vs = {}
	for _, v in pairs(t) do 
		table.insert(vs, v)
	end 
	return vs 
end 

local function filter(t, f, ...)
	local m = {}
	for k, v in pairs(t) do 
		if f(k, v, ...) then 
			m[k] = v
		end 
	end
	return m 
end

return {
	set 			= set,
	map 			= map,
	filter 			= filter,
	each 			= each,
	eachi 			= eachi,
	count 			= count,
	countf 			= countf,
	empty 			= empty,
	emptyf 			= emptyf,
	reduce			= reduce,
	tomap 			= tomap,
	toarr 			= toarr,
	keys 			= keys,
	values 			= values,
	contains 		= contains,
	contains_any 	= contains_any,
}





