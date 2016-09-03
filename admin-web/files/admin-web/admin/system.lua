local fp = require("fp")
local common = require("common")
local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")
local timezoneinfo = require("admin.timezoneinfo")

local read = common.read
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	return (not r) and reply_e(e) or ngx.say(r)
end

local get_timezones = timezoneinfo.get_timezones
local key_map = {}

function key_map.timezones()
	return get_timezones()
end

function key_map.time()
	return os.date()
end

function key_map.lease()
	local map = {}
	local file = io.open("/tmp/dhcp.leases")
	if not file then
		return {}
	end

	local now = os.time()
	local time_map = {{s = 86400, d = "d"}, {s = 3600, d = "h"}, {s = 60, d = "m"}, {s = 1, d = "s"}}
	while true do
		local line = file:read("*l")
		if not line then
			file:close()
			break
		end

		local ts, mac, ip, name, duid = line:match("^(%d+) (%S+) (%S+) (%S+) (%S+)")
		if ts then
			if not ip:match(":") then
				map[ip] = {
					expires  = os.difftime(tonumber(ts), now) ,
					hostname = (name ~= "*") and name or "",
					macaddr  = mac,
					ipaddr   = ip
				}
			end
		end
	end

	local arr = {}
	for _, v in pairs(map) do
		table.insert(arr, v)
	end

	return arr
end

function key_map.zonename()
	return read("uci get system.@system[0].zonename", io.popen):gsub("%s", "")
end

function cmd_map.system_get()
	local m, e = validate_get({keys = gen_validate_str(1, 256)})
	if not m then
		return reply_e(e)
	end

	local keys = js.decode(ngx.unescape_uri(m.keys))
	if not (keys and #keys > 0) then
		return reply_e("invalid request")
	end

	local rs = {}
	for _, k in ipairs(keys) do
		local f = key_map[k]
		if not f then
			return reply_e("invalid keys")
		end
		rs[k] = f()
	end

	reply(rs)
end

local check_map = {}
function check_map.timezone(p)
	local check = function()
		local zonename = p.zonename
		if not zonename then
			return nil, "invalid zonename"
		end

		local m = {}
		for _, r in ipairs(get_timezones()) do
			local name, zone = r[1], r[2]
			if zonename == name then
				m.zonename = zonename
				m.timezone = zone
				return m
			end
		end

		return nil, "invalid zonename"
	end

	local m, e = check()
	if not m then
		return reply_e(e)
	end

	query_common(m, "kv_set")
end

function check_map.synctime(p)
	local sec = p.sec
	if not (sec and sec:find("^%d%d%d%d%d%d%d%d%d%d$")) then
		return reply_e("invalid synctime")
	end

	query_common({sec = sec}, "system_synctime")
end

function cmd_map.system_set()
	local m, e = validate_post({})
	if not m then
		return reply_e(e)
	end

	local p, e = ngx.req.get_post_args()
	if not (p and p.cmd) then
		return reply_e("invalid request")
	end

	local f = check_map[p.cmd]
	if not f then
		return reply_e("invalid request")
	end

	f(p)
end

local function savefile(path, maxsize)
	local upload = require("resty.upload")

	local form, err = upload:new(8192)
	if not form then
		return nil, err
	end

	form:set_timeout(1000)

	local filelen, fp = 0
	while true do
		local typ, res, err = form:read()
		if not typ then
			return nil, err
		end

		if typ == "header" then
			if res[1] ~= "Content-Type" then
				if fp then
					fp:close()
					return nil, "already open file"
				end

				fp, err = io.open(path, "w")
				if not fp then
					return nil, err
				end
			end
		elseif typ == "body" then
			if not fp then
				return nil, "not open file"
			end

			filelen = filelen + #res
			if filelen > maxsize then
				local _ = fp:close(), os.remove(path)
				return nil, "file too large"
			end

			fp:write(res)
		elseif typ == "part_end" then
			if not fp then
				return nil, "not open file"
			end

			fp:close()
			return {size = filelen}
		elseif typ == "eof" then
			local _ = fp and fp:close()
			os.remove(path)
			return nil, "eof"
		end
	end
end

function cmd_map.system_upload()
	local token = ngx.req.get_uri_args().token
	local r, e = adminlib.check_method_token("POST", token)
	if not r then
		return reply_e(e)
	end

	local r, e = adminlib.validate_token(token)
	if not r then
		return reply_e(e)
	end

	local firmware = "/tmp/firmware.img"
	local r, e = savefile(firmware, 16 * 1024 * 1024)
	if not r then
		return reply_e(e)
	end

	-- TODO the following commands will hurt performance badly!

	-- validate
	local cmd = string.format("sysupgrade -T %s 2>&1", firmware)
	local s = read(cmd, io.popen)
	if s:find("Invalid") then
		return reply_e("Invalid image")
	end

	-- get md5sum
	local cmd = string.format("md5sum %s", firmware)
	local s = read(cmd, io.popen)
	local md5 = s:match("(.-)%s")
	reply({md5 = md5, size = r.size})
end

function cmd_map.system_upgrade()
	local m, e = validate_post({keep = gen_validate_num(0, 1)})
	if not m then
		return reply_e(e)
	end

	local firmware = "/tmp/firmware.img"
	if not require("lfs").attributes(firmware) then
		return reply_e("not find " .. firmware)
	end

	m.path = firmware
	query_common(m, "system_upgrade")
end

function cmd_map.system_auth()
	local m, e = validate_post({password = gen_validate_str(1, 32), oldpassword = gen_validate_str(1, 32)})
	if not m then
		return reply_e(e)
	end

	if m.password == m.oldpassword then
		return reply_e("invalid password")
	end

	m.password_md5, m.oldpassword_md5 = ngx.md5(m.password), ngx.md5(m.oldpassword)

	query_common(m, "system_auth")
end

function cmd_map.system_backup()
	local m, e = validate_get({})
	if not m then
		return reply_e(e)
	end

	m.cmd = "system_backup"
	local r, e = query_u(m)
	if not r then
		return reply_e(e)
	end

	local m = js.decode(r)
	if m.status ~= 0 then
		return reply_e(m.data)
	end

	local path = m.data
	local s = read(path)
	local filename = path:match(".+/(.+)")
	ngx.header["Content-Disposition"] = string.format("attachment; filename=%s", filename)
	ngx.print(s)
end

function cmd_map.system_backupload()
	local token = ngx.req.get_uri_args().token
	local r, e = adminlib.check_method_token("POST", token)
	if not r then
		return reply_e(e)
	end

	local r, e = adminlib.validate_token(token)
	if not r then
		return reply_e(e)
	end

	local cfgpath = "/tmp/mysysbackup.bin"
	local r, e = savefile(cfgpath, 1024 * 1024)
	if not r then
		return reply_e(e)
	end
	reply("ok")
end

function cmd_map.system_restore()
	local cfgpath = "/tmp/mysysbackup.bin"
	if not require("lfs").attributes(cfgpath) then
		return reply_e("not find " .. cfgpath)
	end
	query_common({path = cfgpath}, "system_restore")
end

return {run = run}