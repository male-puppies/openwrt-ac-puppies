--[[
	global value detection, by yjs, 20140716
--]]
-- pre-defined global value
local global_value = {
	_=1,
	coroutine=1,
	assert=1,
	tostring=1,
	tonumber=1,
	io=1,
	rawget=1,
	xpcall=1,
	arg=1,
	ipairs=1,
	print=1,
	pcall=1,
	gcinfo=1,
	module=1,
	setfenv=1,
	pairs=1,
	jit=1,
	bit=1,
	package=1,
	error=1,
	debug=1,
	loadfile=1,
	rawequal=1,
	loadstring=1,
	rawset=1,
	table=1,
	require=1,
	_VERSION=1,
	newproxy=1,
	collectgarbage=1,
	dofile=1,
	next=1,
	math=1,
	load=1,
	os=1,
	_G=1,
	select=1,
	string=1,
	type=1,
	getmetatable=1,
	getfenv=1,
	setmetatable=1,
	define = 1,
	utf8 = 1,
	bit32 = 1,
	rawlen = 1,
	_LNUM = 1,
}

-- define new valid global, basically you should never call it
function define(k) global_value[k] = 1 end

-- proxy original require
local old_require = require
require = function(mod)
	local _ = mod or error("mod is nil")
	global_value[mod] = 1
	return old_require(mod)
end

local format = string.format
local mt = {
	__index = function(t, k) error(format('error get global "%s"', k)) end,
	__newindex = function(t, k, v) local _ = global_value[k] and rawset(t, k, v) or error(format('error set global "%s" = "%s"', tostring(k), tostring(v))) end,
}
setmetatable(_G, mt)

-- check pre-defined global values
local _ = function()
	for k, v in pairs(_G) do
		local _ = global_value[k] or error(format('detect invaid global variable "%s" = "%s"', k, v))
	end
end
_()
