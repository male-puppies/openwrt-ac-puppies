local log = require("log")
local lfs = require("lfs")
local common = require("common")

local read = common.read
local s_const = {
	dev_info_path	= "/etc/device_info",
	op_release_path	= "/etc/openwrt_release",
	op_version_path = "/etc/openwrt_version",
	board_info_path = "/tmp/sysinfo/board_name",
};
--soft release related
local s_release_version = "-"
local s_valid_release_info = false

--dev info related
local s_hw_version = "-"
local s_valid_dev_info = false

--soft version which is timestamp
local s_soft_version = "-"
local s_valid_soft_info = false

--boardname
local s_boardname = "-"
local s_valid_board = false


--success:true,version;failed:false, "-"
local function get_release_version()
	if s_valid_release_info then
		return s_valid_release_info, s_release_version
	end
	local version = "-"
	local cmd = string.format("cat %s | grep DISTRIB_CODENAME", s_const.op_release_path);
	local s = read(cmd, io.popen)
	if not s then
		return s_valid_release_info, s_release_version
	end
	--DISTRIB_CODENAME='V.0'
	version =  s:match('.+"(.+)".*')
	if not version then
		version = "-"
	else
		s_valid_release_info = true
	end
	s_release_version = version
	log.debug("release_version:%s", s_release_version)
	return s_valid_release_info, s_release_version
end

--success:true,version;failed:false, "-"
local function get_hw_version()
	if s_valid_dev_info then
		return s_valid_dev_info, s_hw_version
	end
	local version = "-"
	if not lfs.attributes(s_const.dev_info_path) then
		return s_valid_dev_info, s_hw_version
	end
	local cmd = string.format("cat %s | grep DEVICE_REVISION", s_const.dev_info_path);
	local s = read(cmd, io.popen)
	if not s then
		s_hw_version = version
		return s_valid_dev_info, s_hw_version
	end
	--DEVICE_REVISION='Hardware Version'
	version = s:match(".+%'(.+)%'.*")
	if not version then
		s_hw_version = '-'
	else
		s_valid_dev_info = true
	end
	s_hw_version = version
	--log.debug("hw_version:%s", s_hw_version)
	return s_valid_dev_info, s_hw_version
end

local function get_soft_version()
	if s_valid_soft_info then
		return s_valid_soft_info, s_soft_version
	end
	local version = "-"
	local cmd = string.format("cat %s", s_const.op_version_path)
	local s = read(cmd, io.popen)
	if not s then
		return s_valid_soft_info, s_soft_version
	end
	--DISTRIB_CODENAME='V.0'
	version = s:match(".-(%d+)\n")
	if not version then
		version = "-"
	else
		s_valid_soft_info = true
	end
	s_soft_version = version
	log.debug("soft_version:%s", s_soft_version)
	return s_valid_soft_info, s_soft_version
end

local function get_boardname()
	if s_valid_board then
		return s_valid_board, s_boardname
	end
	local boardname = "-"
	local cmd = string.format("cat %s", s_const.board_info_path)
	local s = read(cmd, io.popen)
	if not s then
		return s_valid_board
	end

	boardname = s:match("%s*(.+)\n")
	if not boardname then
		boardname = "-"
	else
		s_valid_board = true
	end
	s_boardname = boardname
	log.debug("boardname:%s", s_boardname)
	return s_valid_board, s_boardname
end


return {get_hw_version = get_hw_version, get_soft_version = get_soft_version, get_release_version = get_release_version, get_boardname = get_boardname}