-- @author : xjx
-- @radio.lua : 接收前端数据并判断合法性

local js	= require("cjson.safe")
local log	= require("common.log")
local rds	= require("common.rds")
local query	= require("common.query")
local adminlib	= require("admin.adminlib")

local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local v_radio_2g	= gen_validate_str(1,256)
local v_radio_5g	= gen_validate_str(1,256)
local v_opt			= gen_validate_str(1,256)

local cmd_map = {}

local function query_u(p, timeout)
	return query.query_u("127.0.0.1", 50003, p, timeout)
end

local function run(cmd)
	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd)
end

function cmd_map.numb(cmd)
	reply_e("invalid cmd " .. cmd)
end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)

    return (not r) and reply_e(e) or ngx.say(r)
end

-- 检验2g数据的合法性
local function validate_std_2g(s)
	if not s then
		return nil, "miss validate_std"
	end

	local m = s
	m = js.decode(m)	assert(m)

	local protos = {b = 1, g = 1, n = 1, bg = 1, bgn = 1}
	if not protos[m.proto] then
		return nil, "error proto"
	end

	local bandwidths = {["auto"] = 1, ["20"] = 1, ["40+"] = 1, ["40-"] = 1}
	if not bandwidths[m.bandwidth] then
		return nil, "error bandwidth"
	end

	if not (m.chanid == "auto") then
		m.chanid = tonumber(m.chanid)
		if not (m.chanid >= 1 and m.chanid <= 11) then
			return nil, "error chanid"
		end
	end

	if not (m.power == "auto") then
		m.power = tonumber(m.power)
		if not (m.power >= 3 and m.power <= 26) then
			return nil, "error power"
		end
	end

	return true
end

-- 检验5g数据的合法性
local function validate_std_5g(s)
	if not s then
		return nil, "miss validate_std"
	end

	local m = s
	m = js.decode(m)	assert(m)

	local protos = {a = 1, n = 1, an = 1}
	if not protos[m.proto] then
		return nil, "error proto"
	end

	local bandwidths = {["auto"] = 1, ["20"] = 1, ["40+"] = 1, ["40-"] = 1}
	if not bandwidths[m.bandwidth] then
		return nil, "error bandwidth"
	end

	if not (m.chanid == "auto") then
		m.chanid = tonumber(m.chanid)
		if not ((m.chanid/4 >= 9 and m.chanid/4 <= 16) or ((m.chanid-145)/4 >= 1 and (m.chanid-145)/4 <= 5)) then
			return nil, "error chanid"
		end
	end

	if not (m.power == "auto") then
		m.power = tonumber(m.power)
		if not (m.power >= 3 and m.power <= 26) then
			return nil, "error power"
		end
	end

	return true
end

-- 检验opt数据的合法性
local function validate_std_opt(s)
	if not s then
		return nil, "miss validate_std"
	end

	local m = s
	m = js.decode(m)	assert(m)

	if not (m.mult == "0" or m.mult == "1") then
		return nil, "error mult"
	end

	local rates = {["0"] = 1, ["2"] = 1, ["4"] = 1, ["11"] = 1}
	if not rates[m.rate] then
		return nil, "error rate"
	end

	local inspeeds = {["0"] = 1, ["2"] = 1, ["5.5"] = 1, ["11"] = 1, ["18"] = 1, ["36"] = 1}
	if not inspeeds[m.inspeed] then
		return nil, "error inspeed"
	end

	if not (m.enable == "1" or m.enable == "0") then
		return nil, "error enable"
	end

	return true
end

-- 设置radio数据
function cmd_map.radio_set()
	local m, e = validate_post({
		radio_2g	= v_radio_2g,
		radio_5g	= v_radio_5g,
		opt			= v_opt,
	})

	if not m then
		return reply_e(e)
	end

	local r, e = validate_std_2g(m.radio_2g)
	if not r then
		return reply_e(e)
	end

	local r, e = validate_std_5g(m.radio_5g)
	if not r then
		return reply_e(e)
	end

	local r, e = validate_std_opt(m.opt)
	if not r then
		return reply_e(e)
	end

	ngx.log(ngx.ERR, "---radio_set ok!---")

	return query_common(m, "radio_set")
end

-- 取radio数据
function cmd_map.radio_get()
	local m, e = validate_get({})
	if not m then
		return reply_e(e)
	end

	ngx.log(ngx.ERR, "---radio_get ok!---")

	return query_common(m, "radio_get")
end

return {run = run}