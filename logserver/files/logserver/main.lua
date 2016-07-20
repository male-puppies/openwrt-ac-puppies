local ski = require("ski")
local lfs = require("lfs")
local udp = require("ski.udp")
local common = require("common")
local read, save = common.read, common.safe

local function start_real_server()
	local srv = udp.new()
	local r, e = srv:bind("127.0.0.1", 50000) 	assert(r, e)
	while true do 
		local r = srv:recv(50)
		local _ = r and print(r)
	end
end

------------------------------------------------------------------
local gfp 
local maxfiles = 5

local max_logsize = 1024 * 200
local max_cache, flush_timeout = 10, 5

local logdir = "/tmp/ugw/log"
local function openlog()
	if not gfp then
		local path, e = string.format("%s/log.current", logdir)
		gfp, e = io.open(path, "a") 	assert(gfp, e)
	end	
	return gfp 
end

local function closelog()
	if gfp then 
		gfp:close()
		gfp = nil 
	end
end

local function get_current_id()
	local cmd = "ls /tmp/ugw/log/1* | tail -1"
	local lastfile = read(cmd, io.popen)
	local id = lastfile:match("(1%d%d%d%d%d%d%d)_")
	return id or 10000000
end

local function get_new_file()
	local id = get_current_id() + 1
	local t = os.date("*t")
	return string.format("%08d_%04d%02d%02d%02d%02d%02d", id, t.year, t.month, t.day, t.hour, t.min, t.sec)
end

local function limit_files()
	local arr = {}
	for filename in lfs.dir(logdir) do
		local id = tonumber(filename:match("(%d%d%d%d%d%d%d%d)_"))
		if id then 
			table.insert(arr, filename)
		end
	end

	table.sort(arr, function(a, b) return a > b end)

	local del = {}
	for i = maxfiles, #arr do 
		local fullpath = string.format("%s/%s", logdir, arr[i])
		os.remove(fullpath) 
	end
end

local function flush(cache)
	local fp = openlog()
	local size = fp:seek()
	if size > max_logsize then 
		closelog()

		local path = get_new_file()
		local cmd = string.format("cd %s; tar -czf %s log.current; rm log.current", logdir, path)
		os.execute(cmd)
		ski.go(limit_files)
		fp = openlog()
	end

	fp:write(table.concat(cache, "\n"))
	fp:flush()
end

local function start_log_server()
	local srv = udp.new()
	local r, e = srv:bind("127.0.0.1", 50001) 	assert(r, e)

	local cache = {}

	ski.go(function()
		while true do 
			ski.sleep(flush_timeout)
			if #cache > 0 then 
				flush(cache)
				cache = {}
			end
		end
	end)

	while true do 
		local r = srv:recv(5)
		if r then 
			table.insert(cache, r)
			if #cache > max_cache then 
				flush(cache)
				cache = {}
			end
		end 
	end
end

local function main(isreal)
	local _ = (isreal and start_real_server or start_log_server)()
end

ski.run(main, ...)

