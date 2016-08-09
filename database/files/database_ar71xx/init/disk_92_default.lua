#!/usr/bin/lua

package.path = "../?.lua;" .. package.path

local lfs = require("lfs")
local dc = require("dbcommon")
local common = require("common")
local js = require("cjson.safe")
local config = require("config")

local read, arr2map = common.read, common.arr2map
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
			{k = "bypass_dst", v = "[]"},
			{k = "offline_time", v = "1800"},
			{k = "redirect_ip", v = "1.0.0.8"},
			{k = "no_flow_timeout", v = "1800"},
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

--[[
cmd_map.iface = {
	priority = 3,
	func = function(conn)
		local sql = "select count(*) as count from iface"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then 
			return
		end

		local default = {
			ifname = "",
			ifdesc = "",
			ethertype = "",
			iftype = "",
			proto = "",
			mtu = "",
			mac = "",
			metric = "",
			gateway = "",
			pppoe_account = "",
			pppoe_password = "",
			static_ip = "",
			dhcp_enable = "",
			dhcp_start = "",
			dhcp_end = "",
			dhcp_time = "",
			dhcp_dynamic = "",
			dhcp_lease = "",
			dhcp_dns = "",
		}
		local set_default = function(r)
			for field, v in pairs(default) do 
				if not r[field] then 
					r[field] = v
		end
			end
		end

		local ifarr = require("parse_network").parse()
		for _, r in ipairs(ifarr) do 
			set_default(r)
			end
		local ifmap = arr2map(ifarr, "ifname")
		-- set zid
		local rs, e = conn:select("select * from zone") 					assert(rs, e)
		local zonemap = arr2map(rs, "zonename")
		for _, r in pairs(ifmap) do
			local n = zonemap[r.ifname:find("^wan") and "WAN" or "LAN"] 	assert(n)
			r.zid, r.pid = n.zid, -1
		end

		-- set pid 
		for _, r in pairs(ifmap) do
			local parent = r.parent
			if parent then 
				local n = ifmap[parent]
				r.pid = n.zid
			end 
		end

		local fields = {
			"fid",
			"ifname",
			"ifdesc",
			"ethertype",
			"iftype",
			"proto",
			"mtu",
			"mac",
			"metric",
			"gateway",
			"pppoe_account",
			"pppoe_password",
			"static_ip",
			"dhcp_enable",
			"dhcp_start",
			"dhcp_end",
			"dhcp_time",
			"dhcp_dynamic",
			"dhcp_lease",
			"dhcp_dns",
			"zid",
			"pid",
		}
		local narr = {}
		for i, r in ipairs(ifarr) do
			local arr = {}
			r.fid = i - 1
			for _, field in ipairs(fields) do 
				table.insert(arr, string.format("'%s'", r[field]))
		end 
			local s = string.format("(%s)", table.concat(arr, ","))
			table.insert(narr, s)
		end

		local sql = string.format("insert into iface(%s) values %s", table.concat(fields, ","), table.concat(narr, ","))
		local r, e = conn:execute(sql)
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}
]]
cmd_map.zone = {
	priority = 2,
	func = function(conn)
		local sql = "select count(*) as count from zone"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then 
			return 
		end 

		local arr = {
			{zid = 0, 	zonename = "LAN", zonedesc = "LAN", zonetype = 3},
			{zid = 1, 	zonename = "WAN", zonedesc = "WAN", zonetype = 3},
			{zid = 255, zonename = "ALL", zonedesc = "ALL", zonetype = 3},
		}

		local narr = {}
		for _, r in ipairs(arr) do 
			table.insert(narr, string.format("('%s','%s','%s','%s')", r.zid, r.zonename, r.zonedesc, r.zonetype))
		end
		local sql = string.format("insert into zone (zid,zonename,zonedesc,zonetype) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql) 	
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}

cmd_map.ipgroup = {
	priority = 4,
	func = function(conn)
		local sql = "select count(*) as count from ipgroup"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then 
			return 
		end 

		local arr = {
			{ipgid = 63, ipgrpname = "ALL", ipgrpdesc = "ALL", ranges = js.encode({"0.0.0.0-255.255.255.255"})},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s')", r.ipgid, r.ipgrpname, r.ipgrpdesc, r.ranges))
		end
		local sql = string.format("insert into ipgroup (ipgid,ipgrpname,ipgrpdesc,ranges) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql) 	
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}

cmd_map.timegroup = {
	priority = 9,
	func = function(conn)
		local sql = "select count(*) as count from timegroup where tmgrpname='ALL'"
		local rs, e = conn:select(sql) 				assert(rs, e)
		if rs[1].count ~= 0 then 
			return 
		end 

		local days = {mon = 1, tues = 1, wed = 1, thur = 1, fri = 1, sat = 1, sun = 1}
		local tmlist = {{hour_start = 0, min_start = 0, hour_end = 23, min_end = 59}}
		local arr = {
			{tmgid = 255, tmgrpname = "ALL", tmgrpdesc = "ALL", days = js.encode(days), tmlist = js.encode(tmlist)},
		}

		local narr = {}
		for _, r in ipairs(arr) do
			table.insert(narr, string.format("('%s','%s','%s','%s','%s')", r.tmgid, r.tmgrpname, r.tmgrpdesc, r.days, r.tmlist))
		end
		local sql = string.format("insert into timegroup (tmgid,tmgrpname,tmgrpdesc,days,tmlist) values %s", table.concat(narr, ","))
		local r, e = conn:execute(sql) 	
		local _ = r or fatal("%s %s", sql , e)
		return true
	end
}


local function main()
	local cfg, e = config.ins() 					assert(cfg, e)
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
