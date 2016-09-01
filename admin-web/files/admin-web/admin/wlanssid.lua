-- @author : xjx
-- @wlanssid.lua : 接收前端数据并判断合法性

local js	= require("cjson.safe")
local log	= require("common.log")
local rds	= require("common.rds")
local query	= require("common.query")
local adminlib	= require("admin.adminlib")

local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local WLAN_MAX_ID = 256

local v_hide 		= gen_validate_str(0,1)
local v_enable 		= gen_validate_str(0,1)
local v_wlanid		= gen_validate_num(1, WLAN_MAX_ID)
local v_wlanids		= gen_validate_str(1, 1024)	-- 保存 del 数据
local v_ssid		= gen_validate_str(1, 32)
local v_band		= gen_validate_str(1, 4)
local v_encrypt		= gen_validate_str(1, 4)
local v_password	= gen_validate_str(0, 32)
local v_network		= gen_validate_str(1, 4)

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

-- 检验数据的合法性
local function validate_std(m)
	if not m then
		return nil, "miss validate_std"
	end

	if not m.ssid then
		return nil,"invalid ssid"
	end

	if not (m.enable == "0" or m.enable == "1") then
		return nil, "invalid enable"
	end

	if not (m.hide == "0" or m.hide == "1") then
		return nil, "invalid hide"
	end

	local bands = {["all"] = 1, ["2g"] = 1, ["5g"] = 1}
	if not bands[m.band] then
		return nil, "invalid band"
	end

	local encrypts = {["none"] = 1, ["psk"] = 1, ["psk2"] = 1}
	if not encrypts[m.encrypt] then
		return nil, "invalid encrypt"
	end

	if m.encrypt == "psk" or m.encrypt == "psk2" then
		if not m.password:find("^[%w]+$") then   -- 数字、字母
			return nil,"invalid password"
		end
	end

	local networks = {["lan0"] = 1, ["lan1"] = 1, ["lan2"] = 1, ["lan3"] = 1, ["lan4"] = 1}
	if not networks[m.network] then
		return nil, "invalid network"
	end

	return true
end

-- 添加wlan参数
function cmd_map.wlan_add()
	local m, e= validate_post({
		enable		= v_enable,
		band		= v_band,
		hide		= v_hide,
		encrypt		= v_encrypt,
		ssid		= v_ssid,
		password	= v_password,
		network		= v_network,
	})

	if not m then
		return reply_e(e)
	end

	local r, e = validate_std(m)  -- 检测合法性
	if not r then
		return reply_e(e)
	end

	ngx.log(ngx.ERR, "---wlan_add ok!---")

	return query_common(m, "wlan_add")
end

-- 设置wlan参数
function cmd_map.wlan_set()
	local m, e= validate_post({
		enable		= v_enable,
		band		= v_band,
		hide		= v_hide,
		encrypt		= v_encrypt,
		wlanid		= v_wlanid,
		ssid		= v_ssid,
		password	= v_password,
		network		= v_network,
	})

	if not m then
		return reply_e(e)
	end

	local r, e = validate_std(m)
	if not r then
		return reply_e(e)
	end

	ngx.log(ngx.ERR, "---wlan_set ok!---")

	return query_common(m, "wlan_set")
end

-- 取wlan数据
function cmd_map.wlan_get()
	local m, e = validate_get({})
	if not m then
		return reply_e(e)
	end

	ngx.log(ngx.ERR, "---wlan_get ok!---")

	return query_common(m, "wlan_get")
end

-- 删除wlan数据
function cmd_map.wlan_del()
	local m, e = validate_post({wlanids = v_wlanids})
	if not m then
		return reply_e(e)
	end

	local ids = js.decode(m.wlanids)
	if not ids then
		return reply_e("invalid wlanids")
	end

	for k, v in ipairs(ids) do   -- 检查id合法性
		local tid = v.wlanid
		local tid = tonumber(tid)

		if not (tid and tid >= 1 and tid <= WLAN_MAX_ID) then
			return reply_e("invalid wlanid")
		end
	end

	ngx.log(ngx.ERR, "---wlan_del ok!---")

	return query_common(m, "wlan_del")
end

return {run = run}