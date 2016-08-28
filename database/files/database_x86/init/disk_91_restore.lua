#!/usr/bin/lua

package.path = "../?.lua;" .. package.path

local lfs = require("lfs")
local common = require("common")
local js = require("cjson.safe")
local rdsparser = require("rdsparser")
local dc = require("dbcommon")
local config = require("config")

local read = common.read
local shpath = "../db.sh"

local function fatal(fmt, ...)
	io.stderr:write(string.format(fmt, ...), "\n")
	os.exit(1)
end

local function backup_disk(cfg)
	local cmd = string.format("%s backup %s %s", shpath, cfg:disk_dir(), cfg:work_dir())
	local ret, err = os.execute(cmd)
	local _ = (ret == true or ret == 0) or fatal("backup_disk fail %s %s", cmd, err)
end

local function main()
	local cfg, e = config.ins() 		assert(cfg, e)
	local attr = lfs.attributes(cfg:get_logpath())
	if not (attr and attr.size > 0) then
		return
	end
	local conn = dc.new(cfg:get_workdb())
	local fp, err = io.open(cfg:get_logpath(), "rb")
	local _ = fp or fatal("open log path fail %s", err)

	local decoder = rdsparser.decode_new()

	local error_return = function(msg)
		io.stderr:write("decode update.log fail ", msg or "", "\n")
		local _ = decoder:decode_free(), fp:close(), backup_disk(cfg)
	end

	while true do
		local data = fp:read(8192)
		if not data then
			if decoder:empty() then
				return fp:close()
			end
			return error_return("decoder not empty")
		end

		local arr, err = decoder:decode(data)
		if err then
			return error_return("decode fail " .. err)
		end

		for _, narr in ipairs(arr) do
			local ohex, sql = narr[1], narr[2]
			if not (ohex and #ohex == 8 and sql) then
				return error_return("invalid cmd " .. js.encode(narr))
			end

			local nhex = rdsparser.hex(sql)
			if ohex ~= nhex then
				return error_return(string.format("invalid cmd %s %s", nhex, js.encode(narr)))
			end

			local ret, err = conn:execute(sql)
			if not ret then
				if not err:find("no such table") then
					io.stderr:write("database execute fail ", sql, err or "", "\n")
					os.exit(1)
				end
			end
		end
	end
	conn:close()
end

main()
