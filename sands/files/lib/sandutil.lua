local function tomap(arr)
	local map = {}
	for i = 1, #arr do
		local s = arr[i]
		map[s:sub(1, 2)] = s:sub(3)
	end
	return map
end

local function toarr(map)
	local arr = {}
	for k, v in pairs(map) do
		table.insert(arr, string.format("%s%s", k, v))
	end
	return arr
end

local function checkarr(arr)
	if not arr then
		return false
	end

	for _, s in ipairs(arr) do
		if #s < 3 then
			return false
		end
	end
	return true
end

return {toarr = toarr, tomap = tomap, checkarr = checkarr}