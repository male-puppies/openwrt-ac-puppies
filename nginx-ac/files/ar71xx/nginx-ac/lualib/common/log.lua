local mod, levels = "ng", {}
local unpack = table.unpack and table.unpack or unpack
local host, sys_port, real_port = "127.0.0.1", 50001, 50000

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

local function send_log(s, port)
	local cli = ngx.socket.udp()
	local r, e = cli:setpeername(host, port)
	local _ = r and cli:send(s)
	cli:close()
end

local function send_sys_log(s)  send_log(s, sys_port)  end
local function send_real_log(s) send_log(s, real_port) end
local function debug(fmt, ...)
	local s = logfmt('d', fmt, ...)
	send_sys_log(s)
	local _ = levels["d"] and send_real_log(s)
end

local function info(fmt, ...)
	local s = logfmt('i', fmt, ...)
	send_sys_log(s)
	local _ = levels["i"] and send_real_log(s)
end

local function error(fmt, ...)
	local s = logfmt('e', fmt, ...)
	send_sys_log(s)
	local _ = levels["e"] and send_real_log(s)
end

local function real1(fmt, ...)
	local _ = levels["1"] and send_real_log(logfmt("1", fmt, ...))
end

local function real2(fmt, ...)
	local _ = levels["2"] and send_real_log(logfmt("2", fmt, ...))
end

local function real3(fmt, ...)
	local _ = levels["3"] and send_real_log(logfmt("3", fmt, ...))
end

local function real4(fmt, ...)
	local _ = levels["4"] and send_real_log(logfmt("4", fmt, ...))
end

local function setlevel(level)
	levels = {}
	for k in string.gmatch(level .. ",", "(.-),") do
		levels[k] = 1
	end
end

return {
	debug = debug,
	info = info,
	error = error,
	real1 = real1,
	real2 = real2,
	real3 = real3,
	real4 = real4,
	setlevel = setlevel,
}

