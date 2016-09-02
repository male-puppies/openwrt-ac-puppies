local log = require("log")
local lfs = require("lfs")
local js = require("cjson.safe")

local basedir = "/tmp/memfile"
local _ = lfs.attributes(basedir) or lfs.mkdir(basedir)

local function save_file(path, map)
	local tmp, del = path .. ".tmp", path .. ".del"

	local s = js.encode(map)
	local fp, err = io.open(tmp, "wb")
	local _ = fp or log.fatal("open %s fail %s", tmp, err)

	fp:write(s)
	fp:flush()
	fp:close()

	local cmd = string.format("mv %s %s", tmp, path)
	os.execute(cmd)
end

local function load_file(path)
	local map = {}
	local fp = io.open(path, "rb")

	if fp then
		local s = fp:read("*a")
		fp:close()

		map = js.decode(s)
		if not map then
			log.error("decode %s %s fail. remove", path, s)
			os.remove(path)
			map = {}
		end
	end
	return map
end

local mt = {}
mt.__index = {
	get = function(ins, k)
		assert(type(k) == "string")

		return ins.map[k]
	end,

	set = function(ins, k, v)
		assert(type(k) == "string")

		if type(v) ~= "table" then
			local ov = ins.map[k]
			if ov ~= v then
				ins.change, ins.map[k] = true, v
			end
		else
			ins.change, ins.map[k] = true, v
		end

		return ins -- for ins:set(k, v):set(k2, v2):save()
	end,

	setchange = function(ins)
		ins.change = true
		end,

	force_save = function(ins)
		ins.change = false, save_file(ins.path, ins.map)
	end,

	save = function(ins)
		if ins.change then
			ins.change = false, save_file(ins.path, ins.map)
			return true
		end
		return false
	end,

	reload = function(ins)
		ins.map = load_file(ins.path)
		return ins
	end,

	clear = function(ins)
		ins.map = {}
		return ins
	end,
}

local function new(filename)
	local path = string.format("%s/%s.json", basedir, filename)
	local map = load_file(path)
	local obj = {map = map, change = false, path = path}

	setmetatable(obj, mt)

	return obj
end

local g_ins = {}
local function instance(filename)
	if not g_ins[filename] then
		g_ins[filename] = new(filename)
	end
	return g_ins[filename]
end

return {ins = instance}
