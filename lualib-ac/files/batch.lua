local ski = require("ski")

local method = {}
local mt = {__index = method}

function method:trigger(p)
	self.count = self.count + 1
	local _ = p and table.insert(self.cache, p)
	if self.running then 
		return
	end

	self.running = true

	local f = function()
		local tmp, count
		while self.count > 0 do
			tmp, self.cache, count, self.count = self.cache, {}, self.count, 0
			self.cb(count, tmp)
		end
		ski.sleep(self.timeout)
		self.running = false
	end

	ski.go(f)
end

local function new(cb, timeout)
	assert(cb)
	local obj = {cb = cb, timeout = timeout or 30, running = false, cache = {}, count = 0}
	setmetatable(obj, mt)
	return obj
end

-- local function main()
-- 	local f = function(count, arr)
-- 		print("runnnn", count, table.concat(arr, "-"))
-- 		ski.sleep(5)
-- 	end

-- 	local ins = new(f, 3)
-- 	for i = 1, 100 do 
-- 		ins:trigger(i)
-- 		ski.sleep(1)
-- 		print("main")
-- 	end
-- end 

-- ski.run(main)

return {new = new}
