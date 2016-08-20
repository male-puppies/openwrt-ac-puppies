local js = require("cjson.safe")
local log = require("common.log")
local rds = require("common.rds")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local r1 = log.real1
local mac_pattern = adminlib.mac_pattern
local ip_pattern = adminlib.ip_pattern
local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str
local check_method_token, validate_token = adminlib.check_method_token, adminlib.validate_token

local v_setid = gen_validate_num(0, 5)
local v_setname = gen_validate_str(1, 24, true)
local v_setclass = gen_validate_str(1, 8, true)
local v_setdesc = gen_validate_str(0, 128, true)
local v_settype = gen_validate_str(1, 8, true)
local v_action = gen_validate_str(1, 8, true)
local v_content = gen_validate_str(1, 1024)
local v_enable = gen_validate_num(0,1)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 			end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
    return (not r) and reply_e(e) or ngx.say(r)
end

-- 数据获取函数
function cmd_map.acset_get()
	local p = ngx.req.get_uri_args()
	local token = p.token
	local r, e = check_method_token("GET", token)
	if not r then
		return nil, e
	end

	local r, e = validate_token(token)
	if not r then
		return nil, e
	end

	local setclass, action = p.setclass, p.action
	local sql = string.format("select * from acset where setclass = '%s' and action = '%s'", setclass, action)
		local r, e = mysql_select(sql)
		return r and reply(r) or reply_e(e)
end

-- ip地址的校验
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
    if not ranges then
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

-- mac地址的校验
function validate_mac(m)
	local mac_gather = js.decode(m)
	if not mac_gather then
		return nil, "invalid mac_gather"
	end

	for _, s in ipairs(mac_gather) do
		if not string.find(s, mac_pattern) then
			return nil, string.format("invalid mac_gather, that is mac: %s", s)
		end
	end

	return true
end

-- 数据校验
function validate_data(m)
	local v_acset = {"setid", "setname", "setdesc", "setclass", "settype", "content", "action", "enable"}
	for _, key in ipairs(v_acset) do
		if not m[key] then
			return nil, string.format("invalid data, miss key : %s", key)
		end
	end

	if m.enable ~= 0 and m.enable ~= 1 then
		return nil, "erro enable value"
	end

	if m.settype == "ip" then
		local r, e = validate_ranges(m.content)
		if not r then
			return r, "invalid ip set"
		end
	end

	if m.settype == "mac" then
		local r, e = validate_mac(m.content)
		if not r then
			return r, "invalid mac set"
		end
	end

	if not (m.setclass == "control") then -- 这句是限制为控制策略，如果审计的时候调用，可以把这句酌情删掉
		return nil, "invalid setclass"
	end

	if not (m.action == "bypass" or m.action == "check") then
		return nil, "invalid action"
	end

	return true
end

-- 数据设置函数
function cmd_map.acset_set()
	local m, e = validate_post({
		setid = v_setid,
		setname = v_setname,
		setdesc = v_setdesc,
		setclass = v_setclass,
		settype = v_settype,
		content = v_content,
		action = v_action,
		enable = v_enable
	})
	if not m then
		return reply_e(e)
	end

	local r, e = validate_data(m)
	if not r then
		return reply_e(e)
	end

	return query_common(m, "acset_set")
end

return {run = run}
















