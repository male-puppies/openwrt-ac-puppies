-- tgb 20160903
local soft_arch = "openwrt"

local function isopenwrt()
	return soft_arch == "openwrt"
end


local function config_dir()
	return isopenwrt() and "/etc/config" or "/etc/config"
end

local function default_config()
	return isopenwrt() and "/etc/default_config.json" or "/etc/default_config.json"
end

return {isopenwrt = isopenwrt, config_dir = config_dir, default_config = default_config}
