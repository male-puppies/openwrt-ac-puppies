--#!/usr/bin/lua

local js = require("cjson.safe")


local dn_conf = '/etc/nproto'
local fn_crc = dn_conf..'/applist.conf'
local fn_inner_dump = '/proc/nproto/dump'
local f_conf, js_conf;

local function init()
	os.execute("mkdir ".." -p ".. dn_conf)
	f_conf = io.open(fn_crc, "r")
	if f_conf then
		js_conf = js.decode(f_conf:read("*a"))
		f_conf:close()
	end
	if not js_conf then
		js_conf = js.decode('{"build-in":{},"user-defined":{}}')
	end
end

local function parse_dump()
	-- print(js.encode(js_conf))
	local list = io.popen("sort -u 2>/dev/null "..fn_inner_dump)
	js_conf["build-in"] = {}
	for line in list:lines() do
		-- print(line)
		local crc, name = line:match("(%x*)|(%a.*)")
		if crc and name then
			-- print(crc.." "..name)
			js_conf["build-in"][name] = crc
		end
	end
	list:close()
	-- print(js.encode(js_conf))
	--write back
	f_conf = io.open(fn_crc, "w+")
	if f_conf then
		f_conf:write(js.encode(js_conf))
		f_conf:close()
	end
end

init()

parse_dump()
