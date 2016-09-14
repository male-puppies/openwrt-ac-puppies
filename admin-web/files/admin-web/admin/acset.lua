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

local v_bypass = gen_validate_str(1, 25600)
local v_check = gen_validate_str(1, 25600)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 			end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
    return (not r) and reply_e(e) or ngx.say(r)
end

local function sql_data_get(a, s)
	local sql = string.format("select * from acset where setclass = 'control' and action = '%s' and settype = '%s'", a, s)
	local r, e = mysql_select(sql)
	if not r then
		return nil, e
	end
	return r
end
-- 数据获取函数
function cmd_map.acset_get()
	local p = ngx.req.get_uri_args()
	local token = p.token
	local r, e = check_method_token("GET", token)
	if not r then
		return reply_e(e)
	end

	local r, e = validate_token(token)
	if not r then
		return reply_e(e)
	end

    local map = {bypass = { mac = {}, ip =  {}, enable = 0 }, check = { mac = {}, ip =  {}, enable = 0 }}
    local r, e = sql_data_get("bypass", "mac")
    if not r then
        return reply_e(e)
    end
	local bypass_mac, bypass_enable = r[1].content, r[1].enable

    local r, e = sql_data_get("bypass", "ip")
    if not r then
        return reply_e(e)
    end
	local bypass_ip, bypass_enable = r[1].content, r[1].enable

    local r, e = sql_data_get("check", "mac")
    if not r then
        return reply_e(e)
    end
	local check_mac, check_enable = r[1].content, r[1].enable

    local r, e = sql_data_get("check", "ip")
    if not r then
        return reply_e(e)
    end
	local check_ip, check_enable = r[1].content, r[1].enable

	local pass, chk = p.bypass, p.check
	if not (pass and chk) then
            map.bypass.mac = js.decode(bypass_mac)
            map.check.mac =js.decode(check_mac)
            map.bypass.ip = js.decode(bypass_ip)
            map.check.ip = js.decode(check_ip)
            map.bypass.enable = bypass_enable
            map.check.enable = check_enable
	end
	if pass and (not chk) then
            map.bypass.mac = js.decode(bypass_mac)
            map.bypass.ip = js.decode(bypass_ip)
            map.bypass.enable = bypass_enable
	end
	if chk and (not pass) then
            map.check.mac = js.decode(check_mac)
            map.check.ip = js.decode(check_ip)
            map.check.enable = check_enable
	end
	return map and reply(map) or reply_e("made data error")
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

local function validate_ip(s)
    if not s then
        return nil, "invalid ranges"
    end

    for _, part in ipairs(s) do
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
	if not m then
		return nil, "invalid mac_gather"
	end

	for _, s in ipairs(m) do
		if not string.find(s, mac_pattern) then
			return nil, string.format("invalid mac_gather, that is mac: %s", s)
		end
	end

	return true
end

-- 数据校验
function validate_data(m)
    if not (m.bypass or m.check) then
        return nil, "invalid data"
		end
    local bypass, check = js.decode(m.bypass), js.decode(m.check)

-- 校验bypass字段
    local r, e = validate_mac(bypass.mac)
    if not r then
        return nil, e
	end

    local r, e = validate_ip(bypass.ip)
		if not r then
        return nil, e
		end
-- 校验check字段
    local r, e = validate_mac(check.mac)
    if not r then
        return nil, e
	end

    local r, e = validate_ip(check.ip)
		if not r then
        return nil, e
		end

    return true
	end

local function limit_len(m)
    local mac, ip = m.mac, m.ip     assert(mac, ip)

    if not (#mac >= 0 and #mac <= 64) then
        return nil, "mac can not pass 512"
	end

    if not (#ip >= 0 and #ip <= 64) then
        return nil, "ip can not pass 256"
	end

	return true
end

-- 数据设置函数
function cmd_map.acset_set()
	local m, e = validate_post({
                    bypass = v_bypass,
                    check = v_check,
	})
	if not m then
		return reply_e(e)
	end

	local r, e = validate_data(m)
	if not r then
		return reply_e(e)
	end

            local m_bypass = js.decode(m.bypass)    assert(m_bypass)
            local m_check = js.decode(m.check)    assert(m_check)
            local r, e = limit_len(m_bypass)
            if not r then
                return reply_e(e)
            end
            local r, e = limit_len(m_check)
            if not r then
                return reply_e(e)
            end
            local r, e = sql_data_get("bypass", "mac")
            if not r then
                return reply_e(e)
            end
            r[1].content, r[1].enable = m_bypass.mac, m_bypass.enable
            local m, e = sql_data_get("bypass", "ip")
            if not m then
                return reply_e(e)
            end
            m[1].content, m[1].enable = m_bypass.ip, m_bypass.enable
            local n, e = sql_data_get("check", "mac")
            if not n then
                return reply_e(e)
            end
            n[1].content, n[1].enable = m_check.mac, m_check.enable
            local o, e = sql_data_get("check", "ip")
            if not o then
                return reply_e(e)
            end
            o[1].content, o[1].enable = m_check.ip, m_check.enable
            -- 构造数据，把所有数据放入一个map
            local acset = {
                [r[1].setname] = r[1],
                [m[1].setname] = m[1],
                [n[1].setname] = n[1],
                [o[1].setname] = o[1],
            }
	return query_common(acset, "acset_set")
end

return {run = run}
