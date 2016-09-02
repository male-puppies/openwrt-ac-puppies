local arch

local fp = io.popen("uname -a")
local s = fp:read("*a")
fp:close()
if s:find("mips") then
	arch = "mips"
elseif s:find("x86") then
	arch = "x86"
else
	io.stderr:write("get arch fail", s or "", "\n")
	os.exit(-1)
end

local function ismips()
	return arch == "mips"
end

local function isx86()
	return arch == "x86"
end

local function configdir()
	return isx86() and "/ugw/etc/wac" or "/etc/config"
end

local function default_cfg()
	return isx86() and "/ugw/etc/wac/default_config.json" or "/etc/config/default_config.json"
end

return {ismips = ismips, isx86 = isx86, configdir = configdir, default_cfg = default_cfg}
