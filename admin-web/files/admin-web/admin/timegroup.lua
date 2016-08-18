local js = require("cjson.safe")
local log = require("common.log")
local rds = require("common.rds")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local TMGRP_MAX_ID = 255
local r1 = log.real1
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_tmgid       = gen_validate_num(0, TMGRP_MAX_ID)
local v_tmgids      = gen_validate_str(1, 256)    
local v_desc        = gen_validate_str(0, 256)
local v_name        = gen_validate_str(1, 32)
local v_days        =   gen_validate_str(1, 256)
local v_tmlist      =   gen_validate_str(1, 1024)

local cmd_map = {}

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end 

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 			end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
    return (not r) and reply_e(e) or ngx.say(r)
end

-- 检测数据格式内容正确性
-- 遍历数据标准表
local function validate_keys(s, m)
    if not s then
        return nil, "invalid data structure"
    end
    for _, key in ipairs(m) do 
        if not s[key]  then
            return nil, string.format("miss key : %s ",  key)
        end
    end

    return true 
end

-- 判断days的数据合法性
local function validate_days(s)
    local days_keys = {"mon", "tues", "wed", "thur", "fri", "sat", "sun"}

    local r, e = validate_keys(s, days_keys)
    if not r then
        return nil, "error keys"
    end

   for k, v in pairs(s) do
        if v ~= 0 and v ~= 1 then
            return nil, string.format("invalid data value:[%s] = %s", k, v)
        end
    end

    return true 
end

-- 时间段合法性的判断
local function validate_time(s)
    if not s then
        return nil, "invalid data structure"
    end

    if s.hour_start > 23 or s.hour_start < 0 then
        return nil, "invalid time value"
    end

    if s.hour_end > 23 or s.hour_end < 0 then
        return nil, "invalid time value"
    end

    if s.min_start > 59 or s.min_start < 0 then
        return nil, "invalid time value"
    end

    if s.min_end > 59 or s.min_end < 0 then
        return nil, "invalid time value"
    end

    return true 
end

-- 判断tmlist的数据合法性
local function validate_tmlist(s)
    local tmlist_keys = {"hour_start", "min_start", "hour_end", "min_end"}
    for i = 1, #s do
        local r, e = validate_keys(s[i], tmlist_keys)
        if not r then
            return r, "error tmlist keys"
        end
    end

    for i = 1, #s  do
        local r, e = validate_time(s[i])
        if not r then
            return nil, "error time"
        end
    end
    
    return true 
end


-- 对整个数据的合法性检测
local function validate_std(days, tmlist)
    local v_days = js.decode(days)
    local v_tmlist = js.decode(tmlist)

    if not v_days then
        return nil, "miss days"
    end

    if not v_tmlist then
        return nil, "miss tmlist"
    end

   local r, e = validate_days(v_days)
   if not r then
        return nil, "error days"
   end

   local r, e = validate_tmlist(v_tmlist)
   if not r then
        return nil , "error tmlist"
   end

    return true 
end


function cmd_map.timegroup_add() --添加时间组
    local m, e = validate_post({
            tmgrpname = v_name,
            tmgrpdesc = v_desc,
            days = v_days,
            tmlist = v_tmlist
    })

    if not m then 
        return reply_e(e)
    end

    local r, e = validate_std(m.days, m.tmlist)
    if not r then
        return reply_e(e)
    end

    return query_common(m, "timegroup_add")
end


function cmd_map.timegroup_set() -- 设置时间组
    local m, e = validate_post({
        tmgid       = v_tmgid,
        tmgrpname   = v_name,
        tmgrpdesc   = v_desc,
        days = v_days,
        tmlist = v_tmlist
    })

    if not m then 
        return reply_e(e)
    end

    local tmgid = m.tmgid
    if tmgid == TMGRP_MAX_ID then 
        return reply_e("cannot modify ALL")
    end

    local r, e = validate_std(m.days, m.tmlist)
    if not r then
        return reply_e(e)
    end

    return query_common(m, "timegroup_set")
end

function cmd_map.timegroup_get()
    local m, e = validate_get({page = 1, count = 1})
    if not m then 
        return reply_e(e) 
    end

    local tmgrp_fields = {tmgid = 1, tmgrpname = 1, tmgrpdesc = 1, days = 1, tmlist = 1}
    local cond = adminlib.search_cond(adminlib.search_opt(m, {order = tmgrp_fields, search = tmgrp_fields}))
    local sql = string.format("select * from timegroup %s %s %s", cond.like and string.format("where %s", cond.like) or "", cond.order, cond.limit)

    local r, e = mysql_select(sql)
    return r and reply(r) or reply_e(e)
end

-- 删除时间组
function cmd_map.timegroup_del()
    local m, e = validate_post({tmgids = v_tmgids})

    if not m then 
        return reply_e(e)
    end

    local ids = js.decode(m.tmgids)
    if not ids then 
        return reply_e("invalid tmgids")
    end 

    for _, id in ipairs(ids) do 
        local tid = tonumber(id)
        if not (tid and tid >= 0 and tid < TMGRP_MAX_ID) then 
            return reply_e("invalid tmgids")
        end
    end

    return query_common(m, "timegroup_del")
end

return {run = run}


