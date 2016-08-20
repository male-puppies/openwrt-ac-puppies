local ski = require("ski")
local method = {}
local mt = {__index = method}

function method:emit(p)
	self.count = self.count + 1
	local _ = p and table.insert(self.cache, p)
	if self.running then
		return
	end

	self.running = true

	local f = function()
		while self.count > 0 do
			local tmp, count
			while self.count > 0 do
				tmp, self.cache, count, self.count = self.cache, {}, self.count, 0
				self.cb(count, tmp)
			end
		end
		self.running = false
	end

	ski.go(f)
end

local function new(cb)
	assert(cb)
	local obj = {cb = cb, running = false, cache = {}, count = 0}
	setmetatable(obj, mt)
	return obj
end

return {new = new}
