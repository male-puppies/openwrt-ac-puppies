local lfs = require("lfs")
local pkey = require("key")
local js = require("cjson.safe")
local const = require("constant")
local memfile = require("memfile")

local keys = const.keys
local cfg_path = const.ap_config

local function parse_cfg(path)
	local fp = io.open(path)
	if not fp then
		print("open fail", path)
		return {}
	end
	local s = fp:read("*a")
	fp:close()
	local map, err = js.decode(s)
	if not map then
		print("decode fail", path, err)
		return {}
	end
	return map
end

local function short_k(k)
	return k:match(".+#(.+)")
end

local mt_chk_file = {}
mt_chk_file.__index = {
	check = function(ins)
		local attr = lfs.attributes(ins.path)
		if not attr then
			return false
		end
		if attr.modification == ins.mf:get("lasttime") then
			return false
		end

		ins.mf:set("lasttime", attr.modification)
		return true
	end,

	save_current = function(ins)
		local attr = lfs.attributes(ins.path)
		local _ = attr and ins.mf:set("lasttime", attr.modification):save()
	end,

	save = function(ins)
		ins.mf:save()
	end,

	clear = function(ins)
		ins.mf:clear()
	end,
}

local function new_chk_file(mod, npath)
	assert(mod)
	local mf = memfile.ins("fc_" .. mod)
	local obj = {path = npath or cfg_path, mf = mf}
	setmetatable(obj, mt_chk_file)
	return obj
end

local function check_common(path, karr, mf)
	local kvmap = parse_cfg(path)
	local all, change = {}, false

	for _, k in ipairs(karr) do
		local v = kvmap[k] 				assert(v, k)
		all[short_k(k)] = v
		if mf:get(k) ~= v then
			print("change", k, mf:get(k) or "", v)
			change = true, mf:set(k, v)
		end
	end
	return change, all
end

local mt_common = {}
mt_common.__index = {
	check = function(ins)
		return check_common(ins.path, ins.karr, ins.mf)
	end,

	save = function(ins)
		ins.mf:save()
	end,

	clear = function(ins)
		ins.mf:clear()
	end,
}

local function new_cmp_common(path, module, kparr, apid)
	assert(path and module)

	local karr, rt = {}, {APID = apid}
	for _, kp in ipairs(kparr) do
		table.insert(karr, pkey.short(kp, rt))
	end

	local mf = memfile.ins(module)
	local obj = {mf = mf, path = path, karr = karr}
	setmetatable(obj, mt_common)
	return obj
end

return {
	new_chk_file = new_chk_file,
}
