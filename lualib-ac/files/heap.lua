local js = require("cjson.safe")
local insert, remove = table.insert, table.remove

local method = {}
local mt = {__index = method}
function method:enqueue(v)
	local arr, cmp = self.arr, self.cmp
	insert(arr, v)
	local child = #arr 
	local parent = (child - child % 2) / 2
	while child > 1 and cmp(arr[child], arr[parent]) do 
		arr[child], arr[parent] = arr[parent], arr[child]
		child = parent
		parent = (child - child % 2) / 2
	end 
end

function method:dequeue()
	local arr = self.arr
	if #arr < 2 then 
		return remove(arr)
	end 

	local root = 1 
	local r = arr[root]
	arr[root] = remove(arr)
	local size = #arr
	if size > 1 then	
		local child, cmp = 2 * root, self.cmp 
		while child <= size do 
			if child + 1 <= size and cmp(arr[child + 1], arr[child]) then 
				child = child + 1 
			end

			if cmp(arr[child], arr[root]) then 
				arr[root], arr[child] = arr[child], arr[root]
				root = child
			else
				break 
			end
			child = 2 * root 
		end
	end

	return r 
end

function method:peek()
	return self.arr[1]
end

local function new(cmp, init)
	local cmp = cmp or function(a, b) return a < b end 
	local obj = {count = 0, arr = {}, cmp = cmp}
	setmetatable(obj, mt)

	for _, v in ipairs(init or {}) do 
		obj:enqueue(v)
	end

	return obj
end

return {new = new}
