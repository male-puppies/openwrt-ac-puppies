#!/usr/bin/lua

package.path = "../?.lua;" .. package.path

local lfs = require("lfs")
local dc = require("dbcommon")
local common = require("common")
local js = require("cjson.safe")
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

local cmd_map = {}

cmd_map.kv = {
	priority = 8,
	func = function(conn)
		local sql = string.format("select * from kv")
		local rs, e = conn:select(sql)
		local exist_map = {}
		for _, r in ipairs(rs) do
			exist_map[r.k] = r
		end

		local new_map = {
			{k = "auth_offline_time", v = "1800"},
			{k = "auth_redirect_ip", v = "1.0.0.8"},
			{k = "auth_no_flow_timeout", v = "1800"},
		}

		local miss, find = {}, false
		for _, r in ipairs(new_map) do
			if not exist_map[r.k] then
				miss[r.k], find = r, true
			end
		end

		if not find then
			return false
		end

		local arr = {}
		for k, r in pairs(miss) do
			table.insert(arr, string.format("('%s','%s')", k, r.v))
		end

		local sql = string.format("insert into kv (k, v) values %s", table.concat(arr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}

cmd_map.iface = {
	priority = 3,
	func = function(conn)
		local s = read("uci show network | grep device", io.popen)
		local map = {}
		for idx, ifname in s:gmatch("device%[(%d+)%]%.ifname='(.-)'") do
			map[idx] = {ifname = ifname}
		end
		for idx, mac in s:gmatch("device%[(%d+)%]%.macaddr='(.-)'") do
			map[idx].mac = mac
		end

		local sql = string.format("select * from iface")
		local rs, e = conn:select(sql)
		local exist_map, maxid = {}, 0
		for _, r in ipairs(rs) do
			exist_map[r.ifname] = r
			local fid = tonumber(r.fid)
			if fid > maxid then
				maxid = fid
			end
		end

		local miss, find = {}, false
		for idx, iface in pairs(map) do
			local ifname = iface.ifname
			if not exist_map[ifname] then
				miss[ifname], find = iface, true
			end
		end

		if not find then
			return false
		end

		local arr = {}
		for ifname, iface in pairs(miss) do
			maxid = maxid + 1
			table.insert(arr, string.format("(%s,'%s','ether',1500,'%s')", maxid, ifname, iface.mac))
		end

		local sql = string.format("insert into iface (fid,ifname,ethertype,mtu,mac) values %s", table.concat(arr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}

cmd_map.zone = {
	priority = 2,
	func = function(conn)
		local zonename = "all"
		local sql = string.format("select * from zone where zonename='%s'", zonename)
		local rs, e = conn:select(sql)
		if #rs ~= 0 then
			return
		end

		local zid, zonename, zonedesc, zonetype = 255, zonename, zonename, 3
		local sql = string.format("insert into zone (zid,zonename,zonedesc,zonetype) values ('%s','%s','%s','%s')", zid, zonename, zonedesc, zonetype)
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}

local function main()
	local cfg, e = config.ins() 		assert(cfg, e)
	local conn = dc.new(cfg:get_workdb())

	local arr = {}
	for _, r in pairs(cmd_map) do
		table.insert(arr, r)
	end
	table.sort(arr, function(a, b) return a.priority < b.priority end)
	local change = false
	for _, r in pairs(arr) do
		local r, e = r.func(conn)
		change = change and change or r
	end

	if change then
		backup_disk(cfg)
	end

	-- conn:close()
end

main()
