local js = require("cjson.safe")
local query = require("common.query")
local adminlib = require("admin.adminlib")

local mysql_select = adminlib.mysql_select
local reply_e, reply = adminlib.reply_e, adminlib.reply
local ip_pattern = adminlib.ip_pattern
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_fwid 			= gen_validate_num(0, 63)
local v_fwname    		= gen_validate_str(1, 32, true)
local v_fwdesc    		= gen_validate_str(0, 32)
local v_enable 			= gen_validate_num(0, 1)
local v_priority		= gen_validate_num(0, 99999)
local v_proto    		= gen_validate_str(0, 8)
local v_src_zid			= gen_validate_num(0, 255)
--local v_src_ip   		= gen_validate_str(0, 24)
--local v_src_port		= gen_validate_num(1, 65535)
--local v_dest_ip 	  	= gen_validate_str(0, 24)
local v_dest_port		= gen_validate_num(1, 65535)
local v_target_zid		= gen_validate_num(0, 255)
local v_target_ip   	= gen_validate_str(0, 24)
local v_target_port		= gen_validate_num(1, 65535)
local v_fwids           = gen_validate_str(2, 256)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end 

local cmd_map = {}

-- 到函数表中执行函数
-- @cmd : 命令的字符串
-- @return ：返回给前台的结果
local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 	                end

    local function query_common(m, cmd)
    	m.cmd = cmd
        local r, e = query_u(m)
        return (not r) and reply_e(e) or ngx.say(r)
    end

-- 检测传入数据是否合法
-- @m : 带有前台传入参数的表
-- @return ：nil和错误信息或者true
local function validate_firewall(m)
    local target_ip = m.target_ip
        if not target_ip:find(ip_pattern) then 
            return nil, "invalid target_ip"
        end

--[[
    这个版本不显示的字段
    local src_ip = m.src_ip
        if not target_ip:find(ip_pattern) then 
            return nil, "invalid src_ip"
        end
    local dest_ip = m.dest_ip
        if not target_ip:find(ip_pattern) then 
            return nil, "invalid dest_ip"
        end
]]

    return true
end

-- 获取端口映射信息
-- @return ：返回给前台的结果
local valid_fields = {fwid = 1, fwname = 1, priority = 1}
function cmd_map.firewall_get()
    local m, e = validate_get({page = 1, count = 1})
    if not m then 
        return reply_e(e) 
    end
	
    local cond = adminlib.search_cond(adminlib.search_opt(m, {order = valid_fields, search = valid_fields}))
    local sql = string.format("select * from firewall %s %s %s", cond.like and string.format("and %s", cond.like) or "", "order by priority", cond.limit)
	local rs, e = mysql_select(sql)
    return rs and reply(rs) or reply_e(e)
end

-- 返回服务器执行命令的结果
-- @cmd : 命令的字符串
-- @ext : 不同功能需要的字段
-- @return ：返回给前台的结果
local function firewall_update_common(cmd, ext)
	local check_map = 
	{
        fwname          = v_fwname,   
        fwdesc          = v_fwdesc,
        enable          = v_enable,
        proto           = v_proto,
        src_zid         = v_src_zid,
        --src_ip          = v_src_ip,
        --src_port        = v_src_port,
        --dest_ip         = v_dest_ip,
        dest_port       = v_dest_port,
        target_zid      = v_target_zid,
        target_ip       = v_target_ip,
        target_port     = v_target_port,
    }

    for k, v in pairs(ext or {}) do 
        check_map[k] = v 
    end 

  	local m, e = validate_post(check_map)
    if not m then 
        return reply_e(e)
    end

    local r, e = validate_firewall(m)
    if not r then 
        return reply_e(e)
    end

    return query_common(m, cmd)
end

-- 设置端口映射
-- @return ：返回给前台的结果
function cmd_map.firewall_set()
	return firewall_update_common("firewall_set", {fwid = v_fwid})
end

-- 增加端口映射
-- @return ：函数值
function cmd_map.firewall_add()
    return firewall_update_common("firewall_add")
end

-- 删除端口映射
-- @return ：返回给前台的结果
function cmd_map.firewall_del()
    local m, e = validate_post({fwids = v_fwids})

    if not m then 
        return reply_e(e)
    end

    local ids = js.decode(m.fwids)
    if not (ids and type(ids) == "table")  then 
        return reply_e("invalid fwids")
    end 

    for _, id in ipairs(ids) do 
        local tid = tonumber(id)
        if not (tid and tid >= 0 and tid < 64) then 
            return reply_e("invalid fwids")
        end
    end

    return query_common(m, "firewall_del")
end

-- 调整端口映射优先级
-- @return ：返回给前台的结果
function cmd_map.firewall_adjust()
    local m, e = validate_post({fwids = v_fwids})

    if not m then 
        return reply_e(e)
    end

    local ids = js.decode(m.fwids)
    if not (ids and #ids == 2) then 
        return reply_e("invalid fwids")
    end 

    for _, id in ipairs(ids) do 
        local tid = tonumber(id)
        if not (tid and tid >= 0 and tid < 64) then 
            return reply_e("invalid fwids")
        end
    end

    return query_common(m, "firewall_adjust")
end

return {run = run}
