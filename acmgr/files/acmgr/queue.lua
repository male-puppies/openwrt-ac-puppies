--[[
	author:tgb
	date:2016-08-25 1.0 add basic code
]]
local js = require("cjson.safe")
local log = require("log")
local lfs = require("lfs")
local common = require("common")

local read = common.read
local save = common.save_safe

local method = {}
local metatable = {__index = method}

function method:push(item)
	if #self.arr >= self.limit then
		table.remove(self.arr)
	end
	table.insert(self.arr, 1, item)
	self.updated = true
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

function method:save()
	if not self.updated then
		return true
	end
	save(self.path, js.encode(self.arr))
	self.updated = false
end

local function new(path,limit)
	local old_arr = path and read(path) or "{}"
	old_arr = js.decode(old_arr)
	local obj = {
		arr = old_arr or {},
		limit = limit or 300,
		updated = false,
		path = path or "/tmp/memfile/aclog.json",
	}
	setmetatable(obj, metatable)
	return obj
end

return {new = new}