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
local fp = require("fp")

local reduce = fp.reduce
local ctrl_path = "/tmp/memfile/ctrllog.json"
local audit_path = "/tmp/memfile/auditlog.json"
local log_limit, ctrl_log,  audit_log = 300
local udp_srv, mqtt, dbrpc, reply


-- fixme:a temporary method
local set_name_adapter = {
	MACWHITELIST	= "access_white_mac",
	IPWHITELIST		= "access_white_ip",
	MACBLACKLIST	= "access_black_mac",
	IPBLACKLIST		= "access_black_ip",
}

--[[
	proto_map:{"3057439406"=b63cd2ae};
	rule_map:
	set_map:
]]
local proto_map, rule_map, set_map = {}, {}, {}
local udp_map, tcp_map = {}, {}
-- cmd from ntrackd
udp_map["aclog_add"] = function(p, ip, port)

	local rulename, protoname
	if p.subtype == "RULE" then
		rulename = rule_map[tostring(p.rule.rule_id)] or "unknow rule"
		proto_name = proto_map[tostring(p.rule.proto_id)] or "unknow proto"
	else
		local set_info = set_map[set_name_adapter[p.rule.set_name]]
		rulename = set_info and set_info.setdesc or "unknown"
		protoname = set_info and set_info.settype or "unknow"
	end

	local aclog = {
		user		= {ip = p.user.ip, mac = p.user.mac},
		rulename	= rulename,
		protoname	= protoname,
		-- todo: convert jiffies to datetime
		tm			= os.date("%Y-%m-%d %H:%M:%S"),
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

local function fetch_proto_map()
	local sql = string.format("select proto_id from acproto where node_type = 'leaf'")
	local protos, err = simple:mysql_select(sql)
	if not protos then
		log.fatal("fetch proto ids failed:%s", err)
	end
	proto_map = reduce(protos, function(t, r)
		return rawset(t, tostring(tonumber(r.proto_id, 16)), r.proto_id)
		end, {})
	log.real1("new proto map:%s", js.encode(proto_map))
end

local function fetch_rule_map()
	local sql = "select rulename, ruleid from acrule"
	local rules, err = simple:mysql_select(sql)
	if not rules then
		log.fatal("fetch rules failed:%s", err)
	end
	rule_map = reduce(rules, function(t,r)
		return rawset(t, tostring(r.ruleid), r.rulename)
		end, {})
	log.real1("new rule map:%s", js.encode(rule_map))
end

local function fetch_set_map()
	local sql = "select setname, setdesc, settype from acset"
	local sets, err = simple:mysql_select(sql)
	if not sets then
		log.fatal("fetch sets failed:%s", err)
	end
	set_map = reduce(sets, function(t,r)
		return rawset(t, r.setname, {setdesc = r.setdesc, settype = r.settype})
		end, {})
	log.real1("new set map:%s", js.encode(set_map))
end

tcp_map["dbsync_acproto"] = fetch_proto_map
tcp_map["dbsync_acset"] = fetch_set_map
tcp_map["dbsync_acrule"] = fetch_rule_map

local function dispatch_tcp(cmd)
	local f = tcp_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end

local function init(p, u)
	udp_srv, mqtt = p, u
	ctrl_log = queue.new(ctrl_path, log_limit) assert(ctrl_log)
	audit_log = queue.new(audit_path, log_limit) assert(audit_log)
	reply = aclib.gen_reply(udp_srv) assert(reply)
	dbrpc = rpccli.new(mqtt, "a/ac/database_srv")

	simple = simplesql.new(dbrpc)

	fetch_proto_map()
	fetch_set_map()
	fetch_rule_map()
end

return {init = init, dispatch_udp = aclib.gen_dispatch_udp(udp_map), dispatch_tcp = dispatch_tcp}