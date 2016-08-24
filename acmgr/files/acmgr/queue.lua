--[[
	author:tgb
	date:2016-08-25 1.0 add basic code
]]
local js = require("cjson.safe")
local log = require("log")

local method = {}
local metatable = {__index = method}

function method:push(item)
	if #self.arr >= self.limit then
		table.remove(self.arr)
	end
	table.insert(self.arr, 1, item)
end

function method:pop()
	if #self.arr > 0 then
		return self.arr[1]
	end
	return nil
end

function method:clear()
	self.arr = {}
	return true
end

function method:size()
	return #self.arr
end

function method:capacity()
	return self.limit
end

function method:all()
	return self.arr
end

local function new(limit)
	local obj = {arr = {}, limit = limit or 300}
	setmetatable(obj, metatable)
	return obj
end

return {new = new}