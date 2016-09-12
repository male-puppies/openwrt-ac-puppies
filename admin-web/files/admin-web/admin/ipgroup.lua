-- yjs

local js = require("cjson.safe")
local log = require("common.log")
local rds = require("common.rds")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local ip_pattern = adminlib.ip_pattern
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_ipgid       = gen_validate_num(0, 63)
local v_ipgids      = gen_validate_str(1, 256)
local v_range_str   = gen_validate_str(2, 1024)
local v_desc        = gen_validate_str(0, 64)
local v_name        = adminlib.gen_validate_name(1, 32)


local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
    return (not r) and reply_e(e) or ngx.say(r)
end

function cmd_map.ipgroup_get()
	local m, e = validate_get({page = 1, count = 1})
	if not m then
		return reply_e(e)
	end

    local ipgrp_fields = {ipgid = 1, ipgrpname = 1, ipgrpdesc = 1, ranges = 1}
    local cond = adminlib.search_cond(adminlib.search_opt(m, {order = ipgrp_fields, search = ipgrp_fields}))
    local sql = string.format("select * from ipgroup %s %s %s", cond.like and string.format("where %s", cond.like) or "", cond.order, cond.limit)

    local r, e = mysql_select(sql)
    return r and reply(r) or reply_e(e)
end

local range_patterns = {
    {
        pattern = "^(.+)/(%d+)$",
        func = function(ip, mask)
            local bits = tonumber(mask)
            return bits and bits > 0 and bits < 32 and ip:find(ip_pattern)
        end
    },
    {
        pattern = "^(.+)%-(.+)$",
        func = function(ip, ip2)
            return ip:find(ip_pattern) and ip2:find(ip_pattern)
        end
    },
    {
        pattern = "^(.+)$",
        func = function(ip)
            return ip:find(ip_pattern)
        end
    },
}

local function validate_ranges(s)
    local ranges = js.decode(s)
    if not (ranges and #ranges <= 16) then
        return nil, "invalid ranges"
    end

    for _, part in ipairs(ranges) do
        for _, r in ipairs(range_patterns) do
            local a, b = part:match(r.pattern)
            if a then
                if not r.func(a, b) then
                    return nil, "invalid ranges"
                end
                break
            end
        end
    end

    return true
end

function cmd_map.ipgroup_set()
    local m, e = validate_post({
        ipgid       = v_ipgid,
        ipgrpname   = v_name,
        ipgrpdesc   = v_desc,
        ranges      = v_range_str
    })

    if not m then
        return reply_e(e)
    end

    local ipgid = m.ipgid
    if ipgid == 63 then
        return reply_e("cannot modify ALL")
    end

    local r, e = validate_ranges(m.ranges)
    if not r then
        return reply_e(e)
    end

    return query_common(m, "ipgroup_set")
end

function cmd_map.ipgroup_add()
    local m, e = validate_post({
        ipgrpname = v_name,
        ipgrpdesc = v_desc,
        ranges = v_range_str
    })

    if not m then
        return reply_e(e)
    end

    local r, e = validate_ranges(m.ranges)
    if not r then
        return reply_e(e)
    end

    return query_common(m, "ipgroup_add")
end

function cmd_map.ipgroup_del()
    local m, e = validate_post({ipgids = v_ipgids})

    if not m then
        return reply_e(e)
    end

    local ids = js.decode(m.ipgids)
    if not ids then
        return reply_e("invalid ipgids")
    end

    for _, id in ipairs(ids) do
        local tid = tonumber(id)
        if not (tid and tid >= 0 and tid < 63) then
            return reply_e("invalid ipgids")
        end
    end

    return query_common(m, "ipgroup_del")
end

return {run = run}
