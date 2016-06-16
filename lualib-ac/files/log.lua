local sk = require("socket") 

local enable_debug = false
local host, port = "127.0.0.1", 9999

local mod = "un"

local unpack = table.unpack and table.unpack or unpack 

local client = sk.udp()
local ret, err = client:setpeername(host, port)
if not ret then 
	io.stderr:write(string.format("setpeername fail %s %s %s", host, port, err))
	os.exit(-1)
end

local function send(msg)
	client:send(msg)
end

local function logfmt(level, fmt, ...)
	assert(type(fmt) == "string")
	local info = debug.getinfo(3, "lS")
	local src = info.short_src:match(".+/(.*.lua)$") or info.short_src 
	local t = os.date("*t")
	if string.byte(fmt:sub(-1)) ~= 10 then 
		fmt = fmt .. "\n"
	end
	local vars = {...}
	local s, func
	func = function()
		if info.currentline == 0 then 
			s = string.format("%s %s %02d%02d-%02d:%02d:%02d %s " .. fmt, level, mod, t.month, t.day, t.hour, t.min, t.sec, src, unpack(vars))
			return
		end
		s = string.format("%s %s %02d%02d-%02d:%02d:%02d %s %d " .. fmt, level, mod, t.month, t.day, t.hour, t.min, t.sec, src, info.currentline, unpack(vars))
	end

	local ret, msg = pcall(func)
	if ret then
		return s
	end
	return msg
end

local function fromc(s)
	local t = os.date("*t")
	local s = string.format("%s %02d%02d-%02d:%02d:%02d %s\n", mod, t.month, t.day, t.hour, t.min, t.sec, s)
	send(s)
	local _ = enable_debug and io.stdout:write(s)
end

local function debug(fmt, ...)
	local s = logfmt("d", fmt, ...)
	send(s)
	local _ = enable_debug and io.stdout:write(s)
end

local function info(fmt, ...)
	local s = logfmt("i", fmt, ...)
	send(s)
	local _ = enable_debug and io.stdout:write(s)
end

local function error(fmt, ...)
	local s = logfmt("e", fmt, ...)
	send(s)
	local _ = enable_debug and io.stdout:write(s)
end

local function fatal(fmt, ...)
	local s = logfmt("f", fmt, ...)
	send(s)
	local _ = enable_debug and io.stdout:write(s)
	os.exit(-1)
end

local function setdebug(b) 
	enable_debug = b
end

local function setmodule(m)
	assert(type(m) == "string")
	mod = m
end

return {
	debug = debug,
	info = info,
	error = error,
	fatal = fatal,
	fromc = fromc,
	setdebug = setdebug,
	setmodule = setmodule,
}