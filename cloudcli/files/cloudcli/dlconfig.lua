local se = require("se")
local const = require("constant")
local log = require("log")
local lfs = require("lfs")
local LAUNCH_FLAG 		= "launch_flag"
local FINISH_FLAG 		= "finish_flag"
local FAILED_FLAG 		= "failed_flag"
local MD5_SUFFIX_LEN 	= 6


local function read(path, func)
	func = func and func or io.open
	local fp = func(path, "r")
	if not fp then
		return
	end
	local s = fp:read("*a")
	fp:close()
	return s
end


--[[
	下载指定的文件url到指定的位置
	a.url下载路径
	b.dst_dir文件保存路径
	c.保存的文件名
	开始时，创建launch_flag，用于控制单个实例
	结束时，创建finish_flag，用于通知下载完成
--]]
local function download_pack(url, dst_dir, file_name)
	if type(url) ~= "string" or type(dst_dir) ~= "string" or type(file_name) ~= "string" then
		log.error("download_pack: invalid pars.")
		return false
	end

	local save_file = dst_dir.."/"..file_name
	if not lfs.attributes(dst_dir) then
		os.execute("mkdir -p "..dst_dir)
	end

	if lfs.attributes(dst_dir.."/"..file_name) then
		os.execute("rm -f "..dst_dir.."/"..file_name)
	end

	local wget_cmd = string.format("wget -O %s '%s'", save_file, url)
	if not wget_cmd then
		log.debug("construct wget failed.")
		return false
	end
	log.debug("Will Get:%s", wget_cmd)
	--todo:支持lua5.3的os.execute，再判断返回值
	local ret, err = os.execute(wget_cmd)
	if not lfs.attributes(save_file) then
		log.error("wget %s failed.", save_file)
		return false
	end

	log.debug("wget %s success.", save_file)
	return true
end


local function get_md5sum(file)
	if not lfs.attributes(file) then
		log.error(" %s isn't exist.", file)
		return nil
	end
	local md5sum_cmd = string.format("md5sum %s | awk '{print $1}'", file)
	if not md5sum_cmd then
		log.error("construct md5sum cmd failed.")
		return nil
	end
	log.debug("md5_cmd:%s", md5sum_cmd)
	local s = read(md5sum_cmd, io.popen)
	if not s then
		log.error("get md5sum of %s failed.", file)
		return nil
	end
	local md5sum_val = s:match("(.+)\n")
	log.debug("md5sum of %s:%s", file, md5sum_val)
	return md5sum_val
end


--[[xxxxxxxxxxxx.xxxxxxxxxx.xxxxxx.tgz 完整性检测--]]
local function  check_pack_inter(file)
	local file_name = string.match(file, ".+/([^/]*%.%w+)$")
	local exp_md5 =  string.match(file_name, "%w+%.%d+%.(.+)%.")
	if not file_name or not exp_md5 then
		log.error("check_pack_inter: invalid pars.")
		return false
	end

	local md5sum = get_md5sum(file)
	if not md5sum then
		return false
	end

	local md5sum_suffix = string.sub(md5sum, -MD5_SUFFIX_LEN)
	if not md5sum_suffix then
		log.error("get md5sum suffix failed of %s", md5sum)
		return false
	end
	if md5sum_suffix == exp_md5 then
		log.debug("md5 check passed of %s", file)
		return true
	end
	log.debug("md5 check failed of %s: %s ~= %s", file, md5sum_suffix, exp_md5)
	return false
end


local function config_to_dst(package, cfg_type)
	if not lfs.attributes(package) then
		return false
	end

	if cfg_type == "dev" then
		if not lfs.attributes(const.text_dir) then
			os.execute("mkdir -p "..const.text_dir)
		end
		os.execute("rm -f "..const.text_dir.."/*")

		local untar_cmd = string.format("tar xzvf %s -C %s", package, const.text_dir)
		local s = read(untar_cmd, io.popen)
		if not s then
			log.error("untar devcfg failed:%s", untar_cmd)
			return false
		end
		log.debug(" untar %s to %s success.", package, const.text_dir)
		return true

	elseif cfg_type == "ad" then
		if not lfs.attributes(const.package_dir) then
			os.execute("mkdir -p "..const.package_dir)
		end

		local cp_cmd = string.format("cp %s %s", package, const.package_dir.."/"..const.ad_package_file)
		if not cp_cmd then
			return false
		end
		os.execute(cp_cmd)
		log.debug("cp %s to %s success", package, const.package_dir)
		return true
	end

	return false
end


local function update_config(url, file_name, cfg_type)
	local ret

	ret = download_pack(url, const.download_dir, file_name)
	if not ret then
		return false
	end

	ret = check_pack_inter(const.download_dir.."/"..file_name)
	if not ret then
		return false
	end

	ret = config_to_dst(const.download_dir.."/"..file_name, cfg_type)
	if not ret then
		return false
	end
	return true
end


--删除临时文件
local function clear_tm_config(file)
	if lfs.attributes(file) then
		log.debug("rm %s", file)
		os.remove(file)
	end
end


--cfg_type:ad/dev
local url, file_name, cfg_type = ...
-- local url = "http://192.168.0.205/admin/ads_download/15.20160104114230.e09683.tgz"
-- local file_name = "15.20160104114230.e09683.tgz"
-- local cfg_type = "ad"
assert(url and file_name and cfg_type)

log.setdebug(true)

local launch_flag = const.download_dir.."/"..file_name.."."..LAUNCH_FLAG
local finish_flag = const.download_dir.."/"..file_name.."."..FINISH_FLAG
local failed_flag = const.download_dir.."/"..file_name.."."..FAILED_FLAG

if lfs.attributes(launch_flag) then
	os.execute("rm -rf "..launch_flag)
end

if lfs.attributes(finish_flag) then
	os.execute("rm -rf "..finish_flag)
end

if lfs.attributes(failed_flag) then
	os.execute("rm -rf "..failed_flag)
end

os.execute("touch "..launch_flag)

local ret = update_config(url, file_name, cfg_type)
if ret then
	os.execute("touch "..finish_flag)
else
	os.execute("touch "..failed_flag)
end
clear_tm_config(const.download_dir.."/"..file_name)

os.execute("rm -f "..launch_flag)