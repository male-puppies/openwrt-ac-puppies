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

local log_limit, ctrl_log,  audit_log = 300
local udp_srv, mqtt, dbrpc, reply

local udp_map = {}
--cmd from ntrackd
udp_map["aclog_add"] = function(p, ip, port)
	local fetch_rulename = function(rule_id)
		local sql = string.format("select rulename from acproto where proto_id = %s", rule_id)
		if not sql then
			return nil, "construct sql failed"
		end

		local tmp, err = simple:mysql_select(sql)
		if err then
			return nil, err
		end
		return #tmp > 0 and tmp[1].proto_name or "unknow proto"
	end

	local fetch_protoname = function(proto_id)
		local sql = string.format("select proto_name from acproto where proto_id = %s", proto_id)
		if not sql then
			return nil, "construct sql failed"
		end

		local tmp, err = simple:mysql_select(sql)
		if err then
			return nil, err
		end
		return #tmp > 0 and tmp[1].proto_name or "unknow proto"
	end

	local rulename, protoname
	if p.subtype == "RULE" then
		rulename = fetch_rulename(p.rule.proto_id)
		protoname = fetch_protoname(p.rule.proto_id)
	else
		rulename = p.rule.set_name
		protoname = "set"
	end

	local aclog = {
		user	= {ip = p.user.ip, mac = p.user.mac},
		rule 	= rulename,
		proto 	= protoname,
		tm		= p.time_stamp,
		ext		= {flow = {}}
	}

	if p.ruletype == "CONTROL" then
		ctrl_log:push(aclog)
	else
		audit_log:push(aclog)
	end
	return true
end

--cmd from webui
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
	ctrl_log = queue.new(log_limit) assert(ctrl_log)
	audit_log = queue.new(log_limit) assert(audit_log)
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