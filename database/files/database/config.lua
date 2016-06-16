local lfs = require("lfs")
local common = require("common")
local js = require("cjson.safe")

local read = common.read 
local config_path = "db.json"

local method = {}
local mt = {__index = method}

function method:get(k) 		return self.kvmap[k] end 
function method:work_dir() 	return self:get("work_dir") end
function method:disk_dir() 	return self:get("disk_dir") end
function method:host() 		return self:get("host") end
function method:port()		return self:get("port") end 

function method:get_workdb() 	return string.format("%s/disk.db", self:work_dir()) end
function method:get_memodb() 	return string.format("%s/memo.db", self:work_dir()) end 
function method:get_logpath() 	return string.format("%s/log.bin", self:disk_dir()) end

local function validate(map)
	local must_field = {
		"host",
		"port",
		"disk_dir",
		"work_dir",
		"max_log_size",
		"cache_log_count",
		"cache_log_timeout",
	}

	for _, k in ipairs(must_field) do 
		if not map[k] then 
			return nil, "missing " .. k
		end
	end
	return true
end

local function load()
	local map = js.decode((read(config_path)))
	if not map then
		return nil, "load config fail " .. config_path
	end 

	local ret, err = validate(map)
	if not ret then 
		return nil, err 
	end

	local _ = lfs.attributes(map.disk_dir) or lfs.mkdir(map.disk_dir)
	
	local obj = {kvmap = map}
	setmetatable(obj, mt)
	
	return obj
end

local g_ins
local function ins()
	if not g_ins then 
		g_ins, err = load()
		if not g_ins then 
			return nil, err 
		end 
	end 
	return g_ins
end 

return {ins = ins}

