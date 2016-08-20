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
		for k in pairs(m) do
			table.insert(narr, string.format("'%s'", k))
		end
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
	limit = limit,
	empty = empty,
	arr2map = arr2map,
	map2arr = map2arr,
	escape_arr = escape_arr,
	escape_map = escape_map,
}