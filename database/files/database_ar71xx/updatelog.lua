local ski = require("ski")
local log = require("log")
local lfs = require("lfs")
local common = require("common")
local js = require("cjson.safe")
local rdsparser = require("rdsparser")
local dc = require("dbcommon")

local read = common.read
local shpath = "./db.sh"

local method = {}
local mt = {__index = method}

function method:backup() self:save(true) end

function method:backup_disk()
	local s, cfg = ski.time(), self.cfg
	
	local cmd = string.format("%s backup %s %s", shpath, cfg:disk_dir(), cfg:work_dir())
	local ret, err = os.execute(cmd)
	local _ = (ret == true or ret == 0) or log.fatal("backup_disk fail %s %s", cmd, err)
	
	log.debug("backup_disk spends %s seconds", ski.time() - s)
end

function method:init_log()
	local fp, err = io.open(self.cfg:get_logpath(), "a")
	local _ = fp or log.fatal("open log fail %s", err)
	self.fp = fp
end 

function method:save(force_backup)
	local sqlarr, fp = self.sql_cache, self.fp
	self.sql_cache, self.sleep_count = {}, 0

	if #sqlarr > 0 then 
		local arr = {}
		for _, sql in ipairs(sqlarr) do
			table.insert(arr, rdsparser.encode({rdsparser.hex(sql), sql}))
		end
		local ret, err = fp:write(table.concat(arr))
		local _ = ret or log.fatal("write fail %s", err)
		-- print("flush")
		fp:flush()
	end	

	if not force_backup then
		local size, err = fp:seek()
		local _ = size or log.fatal("seek fail")
		if size < self.cfg:get("max_log_size") then return end
	end 

	local _ = fp:close(), self:backup_disk(), self:init_log()

	log.info("backup disk.db force=%s", force_backup and "1" or "0")
end

function method:save_log(v, force_flush)
	if type(v) == "string" then 
		table.insert(self.sql_cache, v)
	else 
		for _, sql in pairs(v) do
			table.insert(self.sql_cache, sql)
		end
	end
	local _ = (force_flush or #self.sql_cache >= self.cfg:get("cache_log_count")) and self:save()
end

local function timeout_save(ins)
	local cache_log_timeout = ins.cfg:get("cache_log_timeout") 		assert(cache_log_timeout)
	while true do 
		while ins.sleep_count < cache_log_timeout do
			ins.sleep_count = ins.sleep_count + 1, ski.sleep(1)
		end  
		ins:save()
	end 
end

function method:prepare()
	self:init_log()
	ski.go(timeout_save, self)
	log.debug("init update log ok")
end

local function new(cfg)
	local obj = {cfg = cfg, sql_cache = {}, sleep_count = 0, fp = nil}
	setmetatable(obj, mt)
	return obj
end

return {new = new}

