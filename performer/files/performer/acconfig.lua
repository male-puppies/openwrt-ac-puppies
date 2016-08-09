--local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")

local ConfigType = {"Rule", "Set"}		--two type config
local ConfigCate = {"Control", "Audit"}	--every type contains two categories config

local ControlSet 		= "ControlSet"
local ControlRule 		= "ControlRule"
local AuditSet 			= "AuditSet"
local AuditRule 		= "AuditRule"

local MacWhiteListSet   = "MacWhiteListSet"
local IpWhiteListSet 	= "IpWhiteListSet"
local MacBlackListSet 	= "MacBlackListSet"
local IpBlackListSet 	= "IpBlackListSet"

local MacWhiteListSetName   = "MacWhiteListSetName"
local IpWhiteListSetName 	= "IpWhiteListSetName"
local MacBlackListSetName 	= "MacBlackListSetName"
local IpBlackListSetName	= "IpBlackListSetName"

--[[
Both rules and sets support disable and enable option.
When disable is set, all rules or ip&mac are cleared in kernel
When enable is set, rules or ip&mac are set to kernel
fixme: it's not a good practice:it always do check option in kernel, even disable is set.
this will cost cpu, of course, the cost is very low.
--]]

--[[
ac rules process flow:
a.fetch config from db: periodical timer timeout or receiving config update news
b.translate the config to new_ac_rules
c.compare cur_ac_rules and new_ac_rules:if they are different, reset config to kernel, and then update cur_ac_rules with new_ac_rules
Notice:control rules and audit rules are independently.
rules = {[ControlRule] = {xxx}, [AuditRule] = {xxx}}

ip & mac blacklist or whitelist.Support ip range and single ip.
ac sets process flow:
a.fetch config from db:receving config update news
b.translate the config to new_ac_sets:add/del items of ip or mac;disable or enable is set
c.compare cur_ac_sets and new_ac_sets:if they are different, reset config to kernel with ipset, 
	and then update cur_ac_sets with new_ac_sets
--]]

--raw configs
local all_raw_ac_config = {}  
--translated config of current config 
local cur_ac_config = {["Rule"] = {["Audit"] = {}, ["Control"] = {}}, ["Set"] = {["Audit"] = {}, ["Control"] = {}}}
--translated config of lastest config
local new_ac_config =  {["Rule"] = {["Audit"] = {}, ["Control"] = {}}, ["Set"] = {["Audit"] = {}, ["Control"] = {}}}	

--[[
	audit/control rule fromat:
	{		
		"Id":,
		"SrcZoneIds":[],
		"SrcIpgrpIds":[],
		"DstZoneIds":[],
		"DstIpgrpIds":[],
		"ProtoIds":[],
		"Action":["ACCEPT", "AUDIT"]
	},
	
	structure of acconfig that ruletable can parse.
	{
		"ControlSet":{
				"MacWhiteListSetName":,
				"IpWhiteListSetName":,
				"MacBlackListSetName":,
				"IpBlackListSetName":,
		},

		"ControlRule": [],

		"AuditSet": {
				"MacWhiteListSetName":,
				"IPWhiteListSetName":,
		},

		"AuditRule":[]
	}
--]]


--[[
config map 
--]]
local function set_name_cmp(old, new, key_arr)
	for _, key in ipairs(key_arr) do
		if (old[key] == nil and new[key] ~= nil) or 
			(old[key] ~= nil and new[key] == nil) then
			return true

		elseif (old[key] and new[key] and old[key] ~= new[key]) then
			return true

		end
	end

	return false
end

--[[
compare rule one by one
--]]
local function ac_rule_cmp(old, new)
	local cmp_sorted_ids = function(old, new)
		if #old ~= #new then
			return true
		end
		for j=1, #old do
			if old[j] ~= new[j] then
				return true
			end
		end
		return false
	end
	print("#old:", #old)
	print("#new:", #new)
	
	if #old ~= #new then
		return true
	end

	for i=1, #old do
		local old_item, new_item = old[i], new[i]
		local old_ids, new_ids = {}, {}

		if old_item["Id"] ~= new_item["Id"] then
			return true
		end

		if cmp_sorted_ids(old_item["SrcZoneIds"], old_item["SrcZoneIds"]) then
			print("SrcZoneIds diff")
			return true
		end
		
		if cmp_sorted_ids(old_item["SrcIpgrpIds"], old_item["SrcIpgrpIds"]) then
			print("SrcIpgrpIds diff")
			return true
		end

		if cmp_sorted_ids(old_item["DstZoneIds"], old_item["DstZoneIds"]) then
			print("DstZoneIds diff")
			return true
		end

		if cmp_sorted_ids(old_item["DstIpgrpIds"], old_item["DstIpgrpIds"]) then
			print("DstIpgrpIds diff")
			return true
		end

		if cmp_sorted_ids(old_item["ProtoIds"], old_item["ProtoIds"]) then
			print("ProtoIds diff")
			return true
		end
 		
 		for _, key in pairs({"ACCEPT", "REJECT", "AUDIT"}) do
 			if old_item[key] ~= new_item[key] then
 				print("action diff")
 				return true
 			end
 		end
	end

	return false
end

-- config_map["ControlSet"] = function(old, new)
-- 	local key_arr = {"MacWhiteListSetName", "IpWhiteListSetName",
-- 						"MacBlackListSetName", "IpBlackListSetName"}
-- 	return set_name_cmp(old, new, key_arry)
-- end

-- config_map["ControlRule"] = function(old, new)
-- 	return ac_rule_cmp(old, new)
-- end

-- config_map["AuditSet"] = function(old, new)
-- 	local key_arr = {"MacWhiteListSetName", "IpWhiteListSetName"}
-- 	return set_name_cmp(old, new, key_arry)
-- end

-- config_map["AuditRule"] = function(old, new)
-- 	return ac_rule_cmp(old, new)
-- end


--[[
Compare old_config and new_ac_rules, if they are different, return true; otherwise, return false.
Notice:
1.there are four parts should be considered: ControlSet, ControlRule, AuditSet, and AuditRule.
2.old_config and new_ac_rules must be non-nil !!!
--]]
-- local function compare_config(old_config, new_ac_rules)
-- 	local changed = false

-- 	if old_config == nil or new_ac_rules == nil then
-- 		print("invalid parameter")
-- 		return false
-- 	end

-- 	for _, item in pairs(config_map) do
-- 		local func = config_map[item] assert(func)
-- 		if old_config[item] and new_ac_rules[item] then
-- 			if func(old_config[item], new_ac_rules[item]) then
-- 				changed = true
-- 				break
-- 			end
		
-- 		elseif not (old_config[item] == nil and new_ac_rules[item] == nil) then
-- 			changed = true
-- 			break
-- 		end
-- 	end

-- 	return changed
-- end


--[[
Check whether tm is contained by tmlist
the tmgrp format is {days = {}, tmlist = []}
tm is provided by os.time()
--]]
local function tm_contained(tmgrp, tm)
	local cur_tm = tm
	local cur_weekday = tostring(os.date("%w", tm)) --0~6 sunday~saturday
	local cur_year = os.date("%Y", tm)
	local cur_month = os.date("%m", tm)
	local cur_day = os.date("%d", tm)

	local day_map = {
		["0"] = "sun",
		["1"] = "mon",
		["2"] = "tues",
		["3"] = "wed",
		["4"] = "thur",
		["5"] = "fri",
		["6"] = "sat",
	}

	local day_key = day_map[cur_weekday] assert(day_key)
	for day_name, day_value in pairs(tmgrp.days) do
		if day_name == day_key then
			if day_value ~= 1 then
				return false
			end
			break
		end
	end

	for _, tm_item in ipairs(tmgrp.tmlist) do
		local start_tm = os.time({year = cur_year, month = cur_month, day = cur_day, 
									hour = tm_item.hour_start, min = tm_item.min_start})
		local end_tm = os.time({year = cur_year, month = cur_month, day = cur_day, 
									hour = tm_item.hour_end, min = tm_item.min_end})
		if os.difftime(tm, start_tm) >= 0 and os.difftime(end_tm, tm) >= 0 then
			return true
		end
	end
	
	return false
end


--[[
		"Id":,
		"SrcZoneIds":[],
		"SrcIpgrpIds":[],
		"DstZoneIds":[],
		"DstIpgrpIds":[],
		"ProtoIds":[],
		"Action":["ACCEPT", "AUDIT"]
		"TmGrp":{days = "{}", tmlist = ""}
--]]
local function generate_rule_config(rule_config, cur_tm)
	local tmp_config = {}
	local tmp_rule = {}

	for _, rule_item in ipairs(rule_config) do 
		if tm_contained(rule_item["TmGrp"], cur_tm) then
			tmp_rule["Id"] = rule_item["Id"]
			tmp_rule["SrcZoneIds"] = rule_item["Id"]
			tmp_rule["SrcIpgrpIds"] = rule_item["Id"]
			tmp_rule["DstZoneIds"] = rule_item["Id"]
			tmp_rule["DstIpgrpIds"] = rule_item["Id"]
			tmp_rule["ProtoIds"] = table.sort(rule_item["ProtoIds"])
			tmp_rule["Actions"] = rule_item["Actions"]
			table.insert(tmp_config, tmp_rule)
		else
			print("time diff")
		end
	end
	return tmp_config
end

--[[
	generate config from all_raw_ac_rules based on current time
--]]
local function generate_config()
	local tmp_config = {}
	local cur_tm = os.time()

	local audit_rule = all_raw_ac_rules[AuditRule]
	local control_rule = all_raw_ac_rules[ControlRule]

	tmp_config[AuditRule] = generate_rule_config(audit_rule, cur_tm)
	tmp_config[ControlRule] = generate_rule_config(control_rule, cur_tm)
	return tmp_config
end

--[[
commit config to kernel
cate:audit or control
sub_cate:ipblack/white, macblack/white

{
	"Id":1,"SrcZoneIds":[1,2],"SrcIpgrpIds":[3,4],
	"DstZoneIds":[5,6],"DstIpgrpIds":[7,8],
	"ProtoIds":[0,9],"Action":["ACCEPT","AUDIT"]
}
--]]
local commit_config = {}
commit_config["Rule"] = function(cate, sub_cate)
	local rule_config = cur_ac_config["Rule"]
	local cate_config = rule_config[cate]
	local cmd_str = string.format("ruletalbe -s '%s'", js.encode(cate_config))
	if cmd_str then
		print(cmd_str)
		--os.execute(cmd_str)
		return true
	end
	return false
end

commit_config["Set"] = function(cate, sub_cate)

end


--[[
compare config:
a.input parameters:old and old[cate] and new and new[cate] must be true
return format {ret = true/false, list = [{cate = Audit/Control, sub_cate = xx}, {}]}
Rule concerns only cate
--]]
local compare_config = {} 
compare_config["Rule"] = function(old, new)
	local ret, cmp_res = true, {}

	if old == nil or new == nil then
		print("new or old is nil")
		return false
	end

	print("old:", js.encode(old))
	print("new:", js.encode(new))
	for _, cate in ipairs(ConfigCate) do
		
		if old[cate] == nil or new[cate] == nil then
			print("old or new ", cate, "is nil")
			return false
		end
		print("old cate:", js.encode(old[cate]))
		print("new cate:", js.encode(new[cate]))
		ret = ac_rule_cmp(old[cate], new[cate])
		print("ac_rule_cmp:", ret)
		if ret and ret == true then
			table.insert(cmp_res, {["cate"] = cate})
		end
	end
	return ret, cmp_res
end

--[[
compare set config
return format {ret = true/false, list = [{cate = Audit/Control, sub_cate = xx}, {}]}
Set concerns both cate and subcate
--]]
compare_config["Set"] = function(old, new)
end


local translate_config = {}
--generate two categories rule config:audit and control
translate_config["Rule"] = function(raw_rule_config)
	local rule_config, cur_tm = {}, os.time()
	for _, cate in ipairs(ConfigCate) do
		rule_config[cate] = generate_rule_config(raw_rule_config[cate], cur_tm)
	end
	return rule_config
end

--generate two categories set config:audit and control
translate_config["Set"] = function()
end

local fetch_raw_config = {}
--fetch two categories rule config:audit and control
fetch_raw_config["Rule"] = function()
	local fetch_rule = function(cate)
		if cate == "Control" then
			
			local rule =  {
					["Id"] = 1, ["SrcZoneIds"]= {1,2}, ["SrcIpgrpIds"] = {3,4},
					["DstZoneIds"] = {5,6}, ["DstIpgrpIds"]={7,8},
					["ProtoIds"] = {0,9}, ["Action"] = {"ACCEPT","AUDIT"},
					["TmGrp"] = {
									days = {mon = 1, tues = 1, wed = 1, thur = 1, fri = 1, sat = 1, sun = 1}, 
									tmlist = {{hour_start = 14, min_start = 0, hour_end = 23, min_end = 59}}
								}
				}

			local rule_2 = {
					["Id"] = 1, ["SrcZoneIds"]= {1,2}, ["SrcIpgrpIds"] = {3,4},
					["DstZoneIds"] = {5,6}, ["DstIpgrpIds"]={7,8},
					["ProtoIds"] = {0,9}, ["Action"] = {"ACCEPT","AUDIT"},
					["TmGrp"] = {
									days = {mon = 1, tues = 1, wed = 1, thur = 1, fri = 1, sat = 1, sun = 1}, 
									tmlist = {{hour_start = 15, min_start = 0, hour_end = 23, min_end = 59}}
								}
				}

			local rule_arr = {}
			table.insert(rule_arr, rule)
			table.insert(rule_arr, rule_2)
			return rule_arr
		else
			return {}
		end
	end

	local rule_config = {}
	for _, cate in ipairs(ConfigCate) do
		rule_config[cate] = fetch_rule(cate) or {}
	end
	return rule_config
end

--fetch two categories set config:audit and control
fetch_raw_config["Set"] = function()
	local fetch_set = function(cate)

	end

	local set_config = {}
	for _, cate in ipairs(ConfigCate) do
		set_config[cate] = fetch_set(cate) or {}
	end
	return set_config
end


--load config
local function load_config()
	for _, config_type in ipairs(ConfigType) do
		local func = fetch_raw_config[config_type] assert(func)
		all_raw_ac_config[config_type] = func()
		print("-----------load_config:", config_type, js.encode(all_raw_ac_config[config_type]))
	end
	print("\n\n")
	return true
end

--[[
check config whether need update and commit
--]]
local function check_config_update()

	if not load_config() then
		return false
	end

	for _, config_type in ipairs(ConfigType) do	
		local ret, cmp_res = false, {}	--a array which contains  {[cate = Audit/Control, sub_cate = xx], []}
		local trans_func = translate_config[config_type] 	assert(trans_func)
		local cmp_func =  compare_config[config_type]		assert(cmp_func)
		local commit_func = commit_config[config_type]		assert(commit_func)

		print("--------check_config_update------:", config_type, js.encode(all_raw_ac_config[config_type]))
		new_ac_config[config_type] = (all_raw_ac_config[config_type])

		print("\n----cur_ac_config:", config_type, js.encode(cur_ac_config[config_type]))
		print("\n----new_ac_config:", config_type, js.encode(new_ac_config[config_type]))
		-- ret, cmp_res = cmp_func(cur_ac_config[config_type], new_ac_config[config_type])
		-- print("cmp res:", ret, cmp_res and js.encode(cmp_res))
		-- if not ret then
		-- 	print("cmp failed of ", config_type)
		-- else
		-- 	if commit_func(cmp_res) then
		-- 		print("commit ", config_type, " success")
		-- 	else
		-- 		print("commit ", config_type, " failed")
		-- 	end
		-- end
	end

end

--[[
fetch config immediately when receiving 
--]]
local function force_check_config_update()
	load_config()
	check_config_update()
end

--periodical routine
local function run()
	while true do
		check_config_update()
		--ski.sleep(60)
	end
end

--fetch raw config from db
local function init()	
	load_config()
end


check_config_update()
-- return {init = init, run = run}