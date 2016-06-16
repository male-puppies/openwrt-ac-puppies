local log = require("log")
local dc = require("dbcommon")

local cmdmap = {}
local disk_map = {}
local memo_map = {}

local function get_diskdb(work_dir) return work_dir .. "/disk.db" end 
local function get_memodb(work_dir) return work_dir .. "/memo.db" end 

local function execute(cmd)
	local ret, err = os.execute(cmd)
	local _ = (ret == true or ret == 0) or log.fatal("cmd fail %s %s", cmd, err)
end

local function close_db(db, path)
	db:close()
	local _ = remove and os.remove(path)
end 

local function do_common(work_dir, funcmap, dbfunc)
	execute("mkdir -p " .. work_dir)

	local path = dbfunc(work_dir)
	local db = dc.new(path)
	for k, func in pairs(funcmap) do 
		local ret, err = func(db)
		if not ret then 
			log.error("init %s fail %s", k, err)
			return close_db(path)
		end
	end
	db:close()
end

function cmdmap.disk(work_dir)
	do_common(work_dir, disk_map, get_diskdb)
end

function cmdmap.memo(work_dir)
	do_common(work_dir, memo_map, get_memodb)
end

local function main(cmd, ...)
	local func = cmdmap[cmd]
	local _ = func and func(...)
end

log.setmodule("dbinit")
log.setdebug(true)

------------------------------------------------------------------------------------------

function memo_map.memo(db)
	local sql = [[
		create table if not exists memo (
			memoid 		integer 	primary key autoincrement,
			str_time	varchar(32) not null default '',
			str_date	varchar(32) not null default ''
		)
	]]
	return db:execute(sql)
end

main(...)
