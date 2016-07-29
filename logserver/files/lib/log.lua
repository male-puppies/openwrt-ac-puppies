local ski = require("ski")
local udp = require("ski.udp")

local mod, levels, debug_on = "", {}, os.getenv("DEBUG_ON")
local unpack = table.unpack and table.unpack or unpack 
local host, server_port, real_port = "127.0.0.1", 50001, 50000

local method = {}
local mt = {__index = method}
function method:send_sys(s) 
	self.cli:send(host, server_port, s) 
end

function method:send_real(s) 
	self.real_cli:send(host, real_port, s) 
end

function method:real_start()
	if not self.real_cli then 
		self.real_cli = udp.new() 
	end
end

function method:real_stop()
	local real_cli = self.real_cli
	if not real_cli then 
		return 
	end 
	real_cli:close()
	self.real_cli = nil
end

local function new()
	local cli = udp.new() 
	local obj = {cli = cli, real_cli = nil}
	setmetatable(obj, mt)
	return obj 
end

-------------------------------------------------------------------------

local log_client = new()
local function logfmt(level, fmt, ...) 
	local info = debug.getinfo(3, "lS")
	local src = info.short_src:match(".+/(.*.lua)$") or info.short_src 
	local t = os.date("*t")
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
	return ret and s or msg
end

local function debug_print(s)
	local _ = debug_on and print(s)
end

local function debug(fmt, ...)
	local s = logfmt("d", fmt, ...)
	log_client:send_sys(s)
	local _ = levels["d"] and log_client:send_real(s)
	debug_print(s)
end

local function info(fmt, ...)
	local s = logfmt("i", fmt, ...)
	log_client:send_sys(s)
	local _ = levels["i"] and log_client:send_real(s)
	debug_print(s)
end

local function error(fmt, ...)
	local s = logfmt("e", fmt, ...)
	log_client:send_sys(s)
	local _ = levels["e"] and log_client:send_real(s)
	debug_print(s)
end

local function fatal(fmt, ...)
	local s = logfmt("f", fmt, ...)
	log_client:send_sys(s)
	local _ = levels["f"] and log_client:send_real(s)
	debug_print(s)
	os.exit(-1)
end

local function real1(fmt, ...)
	local s = logfmt("1", fmt, ...)
	local _ = levels["1"] and log_client:send_real(s)
	debug_print(s)
end

local function real2(fmt, ...)
	local s = logfmt("2", fmt, ...) 
	local _ = levels["2"] and log_client:send_real(s)
	debug_print(s)
end

local function real3(fmt, ...)
	local s = logfmt("3", fmt, ...) 
	local _ = levels["3"] and log_client:send_real(s)
	debug_print(s)
end

local function real4(fmt, ...)
	local s = logfmt("4", fmt, ...) 
	local _ = levels["4"] and log_client:send_real(s)
	debug_print(s)
end

local function real_start(level)
	levels = {}
	for k in string.gmatch(level .. ",", "(.-),") do 
		levels[k] = 1
	end
	log_client:real_start()
end

local function real_stop()
	levels = {}, log_client:real_stop()
end

local function setmodule(m)
	mod = m
end

local function setdebug(b) end

return {
	debug = debug,
	info = info,
	error = error,
	fatal = fatal,
	real1 = real1,
	real2 = real2,
	real3 = real3,
	real4 = real4,
	setdebug = setdebug,
	setmodule = setmodule,
	real_start = real_start,
	real_stop = real_stop,
}

