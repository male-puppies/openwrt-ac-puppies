local luv = require("luv") 
local ski = require("ski.core")

local ski_cur_thread = ski.cur_thread

local function check_ret_yield(cur, ret, err)
	if not ret then
		return nil, err 
	end

	return cur:yield()	
end

local function simple_check(cur, err)
	if err then 
		return cur:setdata({nil, err}):wakeup()
	end 
	return cur:setdata({true}):wakeup()
end

local fs_method = {}
local fs_mt = {__index = fs_method}
function fs_method:read(size, offset) 
	local cur = ski_cur_thread()
	local ret, err = luv.fs_read(self.fd, size, offset or -1, function(err, chunk) 
		if err then
			return cur:setdata({chunk, err}):wakeup()
		end
		
		if #chunk == 0 then
			return cur:setdata({nil, "eof"}):wakeup()
		end

		return cur:setdata({chunk}):wakeup()
	end)
	return check_ret_yield(cur, ret, err)
end

function fs_method:write(data, offset)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_write(self.fd, data, offset or -1, function(err, pos)
		if err then 
			return cur:setdata({nil, err}):wakeup() 
		end 
		return cur:setdata({pos}):wakeup() 
	end)
	return check_ret_yield(cur, ret, err)
end

function fs_method:fsync()
	local cur = ski_cur_thread()
	local ret, err = luv.fs_fsync(self.fd, function(err)
		return simple_check(cur, err)
	end)
	return check_ret_yield(cur, ret, err)
end

function fs_method:fstat()
	local cur = ski_cur_thread()
	local ret, err = luv.fs_fstat(self.fd, function(err, stat)
		return cur:setdata({stat, err}):wakeup()
	end)
	return check_ret_yield(cur, ret, err) 
end

function fs_method:close()
	luv.fs_close(self.fd)
	self.fd = nil
end

local function new_file(fd)
	local obj = {fd = fd}
	setmetatable(obj, fs_mt)
	return obj
end

--[[
flags:r/rs/r+/rs+/w/wx/w+/wx+/a/ax/ax+
mode: "0644"
]]
local function open(path, flags, mode)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_open(path, flags, mode or tonumber("644", 8), function(err, fd)
		if err then 
			return cur:setdata({nil, err}):wakeup()
		end

		return cur:setdata({new_file(fd)}):wakeup()
	end)
	return check_ret_yield(cur, ret, err) 
end

local function stat(path)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_stat(path, function(err, stat)
		return cur:setdata({stat, err}):wakeup()
	end)
	return check_ret_yield(cur, ret, err) 
end

-- mode: r/w/x
local function access(path, mode)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_access(path, mode or "r", function(err, ok) 
		if err then 
			return cur:setdata({nil, err}):wakeup()
		end
		return cur:setdata({ok}):wakeup()
	end)
	return check_ret_yield(cur, ret, err) 
end

local function scandir(dir)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_scandir(dir, function(err, req)
		if err then 
			return cur:setdata({nil, err}):wakeup()
		end 
		local iter = function() return luv.fs_scandir_next(req) end
		local arr = {}
		for k in iter do 
			table.insert(arr, k)
		end
		return cur:setdata({arr}):wakeup()
	end)
	return check_ret_yield(cur, ret, err) 	
end

local function unlink(path)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_unlink(path, function(err) 
		return simple_check(cur, err)
	end)

	return check_ret_yield(cur, ret, err) 	
end

local function rmdir(path)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_rmdir(path, function(err)  
		return simple_check(cur, err)
	end)

	return check_ret_yield(cur, ret, err) 	
end

-- mode "0755"
local function mkdir(path, mode)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_mkdir(path, mode or tonumber("755", 8), function(err) 
		return simple_check(cur, err)
	end)

	return check_ret_yield(cur, ret, err) 	
end

local function rename(old, new)
	local cur = ski_cur_thread()
	local ret, err = luv.fs_rename(old, new, function(err, ...) 
		return simple_check(cur, err)
	end)

	return check_ret_yield(cur, ret, err) 	
end

return {
	open = open,
	stat = stat,
	rmdir = rmdir,
	mkdir = mkdir,
	unlink = unlink,
	rename = rename,
	access = access,
	scandir = scandir,
}

