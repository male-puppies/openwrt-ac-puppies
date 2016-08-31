--[[
	author:tgb
	date:2016-08-25 1.0 add basic code
]]
local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")
local aclib = require("aclib")
local queue = require("queue")
local rpccli = require("rpccli")
local simplesql = require("simplesql")

local ctrl_path = "/tmp/memfile/ctrllog.json"
local audit_path = "/tmp/memfile/auditlog.json"
local log_limit, ctrl_log,  audit_log = 300
local udp_srv, mqtt, dbrpc, reply

local udp_map = {}
-- cmd from ntrackd
udp_map["aclog_add"] = function(p, ip, port)
	local fetch_property = function(sql, name)
		local _ = assert(sql), assert(name)
		local tmp, err = simple:mysql_select(sql)
		print(sql, name, js.encode(tmp))
		if err then
			return nil, err
		end
		return #tmp > 0 and tmp[1][name] or "unknown"
	end

	local rulename, protoname
	if p.subtype == "RULE" then
		local sql = string.format("select rulename from acrule where ruleid = %s", p.rule.rule_id)
		rulename = fetch_property(sql, "rulename")
		-- !!!todo lua can't represent uint32
		-- local sql = string.format("select proto_name from acproto where proto_id='%s'", string.format("%x", tonumber(p.rule.proto_id)))
		-- protoname = fetch_property(sql, "proto_name")
	else
		local sql = string.format("select setdesc from acset where setname = '%s'", p.rule.set_name)
		rulename = fetch_property(sql, "setdesc")

		local sql = string.format("select settype from acset where setname = '%s'", p.rule.set_name)
		protoname = fetch_property(sql, "settype")
	end

	local aclog = {
		user		= {ip = p.user.ip, mac = p.user.mac},
		rulename	= rulename,
		proto		= protoname,
		tm			= p.time_stamp,
		actions		= p.actions,
		ext			= {flow = p.flow}
	}

	if p.ruletype == "CONTROL" then
		ctrl_log:push(aclog)
		ctrl_log:save()
	else
		audit_log:push(aclog)
		audit_log:save()
	end
	return true
end

-- cmd from webui
udp_map["ctrllog_get"] = function (p, ip, port)
	local page, count, res = p.page, p.count, {}	assert(count > 0)
	local idx = page > 1 and ((page - 1) * count + 1)  or 1	assert(idx > 0)
	local arr = ctrl_log:all()	assert(arr)

	if idx <= #arr then
		for i = 0, count - 1 do
			table.insert(res, arr[i + idx])
		end
	end

	reply(ip, port, 0, res)
end

local function gen_dispatch_udp(udp_map)
	return function(cmd, ip, port)
		local f = udp_map[cmd.cmd]
		if f then
			return true, f(cmd, ip, port)
		end
	end
end

local function init(p, u)
	udp_srv, mqtt = p, u
	ctrl_log = queue.new(ctrl_path, log_limit) assert(ctrl_log)
	audit_log = queue.new(audit_path, log_limit) assert(audit_log)
	reply = aclib.gen_reply(udp_srv) assert(reply)
	dbrpc = rpccli.new(mqtt, "a/local/database_srv")
	if not dbrpc then
		log.error("create rpccli failed")
		return false
	end

	simple = simplesql.new(dbrpc)
	if not simple then
		log.error("create simple sql failed")
		return false
	end
end

return {init = init, dispatch_udp = aclib.gen_dispatch_udp(udp_map)}