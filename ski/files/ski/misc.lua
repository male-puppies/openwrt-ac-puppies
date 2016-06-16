local luv = require("luv") 
local ski = require("ski.core")

local ski_cur_thread = ski.cur_thread

local function total_memory()
	return luv.get_total_memory()
end

local function rss()
	return luv.resident_set_memory()
end

local function getrusage()
	return luv.getrusage()
end

local function cpu_info()
	return luv.cpu_info()
end

local function interface_addresses()
	return luv.interface_addresses()
end

local function loadavg()
	return luv.loadavg()
end 

local function exepath()
	return luv.exepath()
end 

local function cwd()
	return luv.cwd()
end 

local function chdir()
	return luv.chdir()
end 

local function getpid()
	return luv.getpid()
end

local function spawn(path, ...)
	local args = {...}

	local cur = ski_cur_thread()
	local stdout = luv.new_pipe(false)
	
	local data, finish, handle, pid = "", false
	handle, pid = luv.spawn(path, {args = args, stdio = {nil, stdout}}, function(code, sig)
		assert(not finish)
		finish = true, luv.close(stdout), luv.close(handle)
		return cur:setdata({data, code}):wakeup()
	end)
	
	if not handle then
		finish = true, luv.close(stdout)
		return nil, pid 
	end

	local ret, err = luv.read_start(stdout, function(err, chunk)
		assert(not finish)
		if chunk then 
			data = data .. chunk
		end
		local _ = err and io.strderr:write(err, "\n")
	end)

	if not ret then
		finish = true, luv.close(stdout), luv.close(handle)
		return nil, err 
	end

	return cur:yield()
end

local function execute(cmd)
	return spawn("sh", "-c", cmd)
end

return {
	rss = rss,
	cwd = cwd,
	chdir = chdir,
	spawn = spawn,
	getpid = getpid,
	loadavg = loadavg,
	exepath = exepath,
	execute = execute,
	cpu_info = cpu_info,
	getrusage = getrusage,
	total_memory = total_memory,
	interface_addresses = interface_addresses,
}

