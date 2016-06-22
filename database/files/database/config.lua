local dbconfig = {
	disk_dir = "/data/sqlite3/",
	work_dir = "/tmp/db",
	cache_log_count = 1,
	cache_log_timeout = 1,
	max_log_size = 102400,
	host = "127.0.0.1",
	port = 18883,
}

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

local function load()
	local map = dbconfig
	local obj = {kvmap = map}
	setmetatable(obj, mt)
	
	return obj
end

local g_ins
local function ins(cfgpath)
	if cfgpath then 
		config_path = cfgpath
	end
	if not g_ins then 
		g_ins, err = load()
		if not g_ins then 
			return nil, err 
		end 
	end 
	return g_ins
end 

return {ins = ins}

