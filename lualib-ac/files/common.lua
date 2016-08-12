local function read(path, func)
	func = func and func or io.open
	local fp, err = func(path, "r")
	if not fp then
		return nil, err
	end
	local s = fp:read("*a")
	fp:close()
	return s
end

local function save(path, s)
	local fp, err = io.open(path, "w") 	assert(fp, err)
	fp:write(s)
	fp:flush()
	fp:close()
end

local function save_safe(path, s)
	local tmp = path .. ".tmp"
	save(tmp, s)

	local cmd = string.format("mv %s %s", tmp, path)
	os.execute(cmd)
end

local function arr2map(arr, k)
	local m = {}
	for _, r in ipairs(arr) do 
		m[r[k]] = r 
	end 
	return m 
end

local function map2arr(m)
	local arr = {}
	for _, r in pairs(m) do 
		table.insert(arr, r)
	end 
	return arr
end

local function escape_map(m, k)
	local narr = {}
	for _, r in pairs(m) do  
		table.insert(narr, string.format("'%s'", r[k]))
	end
	
	return table.concat(narr, ",")
end

local function escape_arr(m)
	local narr = {}
	for _, r in pairs(m) do  
		table.insert(narr, string.format("'%s'", r))
	end

	return table.concat(narr, ",")
end

local function limit(arr, from, count)
	local narr, total = {}, #arr
	local last = from + count - 1
	if last > total then 
		last = total
	end
	for i = from, last do 
		table.insert(narr, arr[i])
	end
	return narr
end

local function empty(m)
	for _ in pairs(m) do 
		return false 
	end 
	return true 
end

return {
	read = read,
	save = save,
	limit = limit, 
	empty = empty,
	arr2map = arr2map,
	map2arr = map2arr,
	save_safe = save_safe,
	escape_arr = escape_arr,
	escape_map = escape_map,
}
