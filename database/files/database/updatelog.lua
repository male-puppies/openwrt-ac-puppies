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

function method:copy_disk()
	local cfg = self.cfg
	local cmd = string.format("%s copy %s %s", shpath, cfg:disk_dir(), cfg:work_dir())
	local ret, err = os.execute(cmd)
	local _ = (ret == true or ret == 0) or log.fatal("copy_disk fail %s %s", cmd, err)
end

function method:backup_disk()
	local s, cfg = ski.time(), self.cfg
	
	local cmd = string.format("%s backup %s %s", shpath, cfg:disk_dir(), cfg:work_dir())
	local ret, err = os.execute(cmd)
	local _ = (ret == true or ret == 0) or log.fatal("backup_disk fail %s %s", cmd, err)
	
	log.debug("backup_disk spends %s seconds", ski.time() - s)
end

function method:do_recover(conn)
	local cfg = self.cfg
	local fp, err = io.open(cfg:get_logpath(), "rb")
	local _ = fp or log.fatal("open log path fail %s", err)

	local decoder = rdsparser.decode_new()

	local error_return = function(msg)
		log.error("decode update.log fail. %s", msg or "")
		local _ = decoder:decode_free(), fp:close(), self:backup_disk()
	end

	while true do
		local data = fp:read(8192)
		if not data then
			if decoder:empty() then return fp:close() end
			return error_return("decoder not empty")
		end
		
		local arr, err = decoder:decode(data)
		if err then return error_return("decode fail " .. err) end

		for _, narr in ipairs(arr) do
			local ohex, sql = narr[1], narr[2]
			if not (ohex and #ohex == 8 and sql) then return error_return("invalid cmd " .. js.encode(narr)) end

			local nhex = rdsparser.hex(sql)
			if ohex ~= nhex then return error_return(string.format("invalid cmd %s %s", nhex, js.encode(narr))) end 
			
			local ret, err = conn:execute(sql)
			if not ret then
				if not err:find("no such table") then 
					log.fatal("database execute fail %s %s", sql, err or "")
				end 
			end 
		end
	end
end

function method:init_db(cmd) 
	local ret, err = os.execute(string.format("lua dbinit.lua %s %s", cmd, self.cfg:work_dir()))
	local _ = (ret == true or ret == 0) or log.fatal("dbinit fail %s", err or "")
end

function method:recover()
	local cfg = self.cfg 
	self:copy_disk()

	local attr = lfs.attributes(cfg:get_logpath())
	if not (attr and attr.size > 0) then return end

	self:init_db("disk")
	
	local conn = dc.new(cfg:get_workdb())
	local _ = self:do_recover(conn), conn:close()
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
	local _ = self:init_db("disk"), self:init_db("memo"), self:init_log()
	ski.go(timeout_save, self)
	log.debug("init update log ok")
end

local function new(cfg)
	local obj = {cfg = cfg, sql_cache = {}, sleep_count = 0, fp = nil}
	setmetatable(obj, mt)
	return obj
end

return {new = new}

