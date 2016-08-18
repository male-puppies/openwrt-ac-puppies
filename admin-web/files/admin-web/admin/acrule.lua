local js = require("cjson.safe")
local log = require("common.log")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern, mac_pattern = adminlib.ip_pattern, adminlib.mac_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_ruleid 		= gen_validate_num(0,255)
local v_rulename 	= gen_validate_str(1,64)
local v_ruletype	= gen_validate_str(1,16,true)
local v_ruledesc 	= gen_validate_str(0,63)
local v_srczids		= gen_validate_str(2,1024)
local v_dstzids 	= gen_validate_str(2,1024) 
local v_protoids	= gen_validate_str(2,10240)
local v_srcipgids	= gen_validate_str(2,1024)
local v_dstipgids	= gen_validate_str(2,1024)
local v_tmgrpids	= gen_validate_str(2,1024)
local v_actions		= gen_validate_str(2,63)
local v_ruleids		= gen_validate_str(2,256)
local v_enable		= gen_validate_num(0,1)
local v_priority	= gen_validate_num(0,9999)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end 

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
    return (not r) and reply_e(e) or ngx.say(r)
end

local acrule_fields = {ruleid = 1, rulename = 1, enable = 1, ruledesc = 1}

local function tmgrp_get(ids)
	local tids = js.decode(ids)
	local in_part = table.concat(tids, ", ")
	local sql = string.format("select tmgid, tmgrpname from timegroup where tmgid in (%s)", in_part)
	local rs, e = mysql_select(sql)
	if not rs then
		return nil, e
	end
	return rs
end

local function ipgrp_get(ids)
	local tids = js.decode(ids)
	local in_part = table.concat(tids, ", ")
	local sql = string.format("select ipgid, ipgrpname from ipgroup where ipgid in (%s)", in_part)
	local rs, e = mysql_select(sql)
	if not rs then
		return nil, e
	end
	return rs
end

local function proto_get(ids)
	local tids = js.decode(ids)
	local in_part = table.concat(tids, ", ")
	local sql = string.format("select proto_id, proto_name from acproto where proto_id in (%s)", in_part)
	local rs, e = mysql_select(sql)
	if not rs then
		return nil, e
	end
	return rs
end

function cmd_map.acrule_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then 
		return reply_e(e)
	end
	local rules_map = {}
	local cond = adminlib.search_cond(adminlib.search_opt(m, {order = acrule_fields, search = acrule_fields}))
	local sql = string.format("select * from acrule %s %s %s", cond.like and string.format("and %s",cond.like) or "", "order by priority", cond.limit)
	local rs, e = mysql_select(sql)
	if not e then 
		for _, v_rs in ipairs(rs) do
			local map = {}
			for k, v_r in pairs(v_rs) do 
				if k == "tmgrp_ids" then 
					local t_map = tmgrp_get(v_r)
					if not t_map then 
						map[k] = {}
					end
					map[k] = t_map
				end
				if k == "src_ipgids" then 
					local si_map = ipgrp_get(v_r)
					if not si_map then 
						map[k] = {}
					end
					map[k] = si_map
				end
				if k == "dest_ipgids" then
					local di_map = ipgrp_get(v_r)
					if not di_map then 
						map[k] = {}
					end
					map[k] = di_map
				end
				if k == "proto_ids" then 
					local pi_map = proto_get(v_r)
					if not pi_map then 
						map[k] = {}
					end
					map[k] = pi_map
				end
				if k ~= "tmgrp_ids" and k ~= "src_ipgids" and k ~= "dest_ipgids" and k ~= "proto_ids" then				
					map[k] = v_r
				end
			end
			table.insert(rules_map, map)
		end
	end
	return rs and reply(rules_map) or reply_e(e)
end 

local function validate_acrule(m)
	local src_ipgids, dest_ipgids = m.src_ipgids, m.dest_ipgids
	local actions, enable = m.actions, m.enable
	local tmgrp_ids, proto_ids = m.tmgrp_ids, m.proto_ids
	local rulename, ruledesc = m.rulename, m.ruledesc

	local sipids = js.decode(src_ipgids)
	if not sipids then
		return nil, "invalid src_ipgids"
	end
	for _, id in ipairs(sipids) do 
		local sid = tonumber(id)
		if not (sid and sid >= 0 and sid < 63) then 
			return nil, "invalid src_ipgids"
		end
	end

	local dipids = js.decode(dest_ipgids)
	if not dipids then 
		return nil, "invalid dest_ipgids"
	end
	for _, id in ipairs(dipids) do
		local did = tonumber(id)
		if not (did and did >= 0 and did < 63) then
			return nil, "invalid dest_ipgids"
		end
	end

	local tmids = js.decode(tmgrp_ids)
	if not tmids then 
		return nil, "invalid timeids"
	end
	for _, id in ipairs(tmids) do
		local tid = tonumber(id)
		if not (tid and tid >= 0 and tid < 255)then
			return nil, "invalid timeids"
		end
	end

	local ptids = js.decode(proto_ids)
	if not ptids then
		return nil, "invalid proto_ids"
	end

	local  iactions= js.decode(actions)
	if not iactions then 
		return nil, "invalid actions"
	end
	local flag = 0
	for i, vi in ipairs(iactions) do
		if not (vi == "ACCEPT" or vi == "REJECT" or vi == "ADUIT") then
			return nil, "invalid actions"
		end
		if (vi == "ACCEPT") then 
			flag = flag + 1
		end
		if (vi == "REJECT") then
			flag = flag + 1
		end
	end
	if flag == 2 then 
		return nil, "invalid actions"
	end
	return true
end

local function acrule_update_common(cmd, ext)
	local check_map = {
		rulename	= v_rulename,
		ruledesc 	= v_ruledesc,
		src_ipgids	= v_srcipgids,
		dest_ipgids	= v_dstipgids,
		tmgrp_ids	= v_tmgrpids,
		actions 	= v_actions,
		enable 		= v_enable,
		proto_ids 	= v_protoids,	
	}

	for k, v in pairs(ext or {}) do
		check_map[k] = v
	end
	local m, e = validate_post(check_map)
	if not m then 
		return reply_e(e)
	end

	local r, e = validate_acrule(m)
	if not r then 
		return reply_e(e)
	end

	return query_common(m, cmd)
end

function cmd_map.acrule_set()
	return acrule_update_common("acrule_set", {ruleid = v_ruleid, priority = v_priority})
end

function cmd_map.acrule_add()
	return acrule_update_common("acrule_add")	
end

function cmd_map.acrule_del()
	local m, e = validate_post({ruleids = v_ruleids})

	if not m then 
		return reply_e(e)
	end

	local ids = js.decode(m.ruleids)
	if not ids then 
		return reply_e("invalid ruleids")
	end

	for _, id in ipairs(ids) do 
		local rid = tonumber(id)
		if not (rid and rid >=0 and rid < 63) then
			return reply_e("invalid ruleids")
		end
	end

	return query_common(m, "acrule_del")
end

function cmd_map.acrule_adjust()
	local m, e = validate_post({ruleids = v_ruleids})

	if not m then 
		return reply_e(e)
	end

	local ids = js.decode(m.ruleids)
	if not (ids and #ids == 2) then 
		return reply_e("invalid ruleids")
	end

	for _, id in ipairs(ids) do
		local rid = tonumber(id)
		if not (rid and rid >= 0 and rid < 63) then
			return reply_e("invalid ruleids")
		end
	end 

	return query_common(m, "acrule_adjust")
end

return{run = run}
