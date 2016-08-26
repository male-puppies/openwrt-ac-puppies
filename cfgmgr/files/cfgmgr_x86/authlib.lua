local ski = require("ski")
local log = require("log")
local nos = require("luanos")
local share = require("share")

local map2arr, arr2map, limit = share.map2arr, share.arr2map, share.limit
local set_status, set_gid_ucrc = nos.user_set_status, nos.user_set_gid_ucrc
local escape_map, escape_arr, empty = share.escape_map, share.escape_arr, share.empty

local function find_missing(myconn, ukey_arr)
	local ukey_map = arr2map(ukey_arr, "ukey")
	local sql = string.format("select ukey from memo.online where ukey in (%s)", escape_map(ukey_map, "ukey"))
	local rs, e = myconn:query(sql) 		assert(rs, e)
	local exists, miss, find = {}, {}
	for _, r in ipairs(rs) do
		local ukey = r.ukey
		exists[ukey] = ukey_map[ukey]
	end

	for ukey, r in pairs(ukey_map) do
		if not exists[ukey] then
			miss[ukey], find = r, true
		end
	end

	return exists, miss
end

local function set_online(uid, magic, gid, username)
	local _ = set_status(uid, magic, 1), set_gid_ucrc(uid, magic, gid, 1)
end

local function set_offline(uid, magic)
	set_status(uid, magic, 3)
end

local function insert_online(myconn, ukey_map, authtype)
	local arr, r, e = {}
	local now = math.floor(ski.time())
	for ukey, p in pairs(ukey_map) do
		table.insert(arr, string.format("('%s','%s','%s','%s','%s',%s,%s,%s,%s)", p.ukey, authtype, p.username, p.ip, p.mac, p.rid, p.gid, now, now))
	end

	local sql = string.format([[insert into memo.online (ukey,type,username,ip,mac,rid,gid,login,active) values %s on duplicate key update type='%s']], table.concat(arr, ","), authtype)
	r, e = myconn:query(sql) 	assert(r, e)
end

local function keepalive(myconn, exists)
	local s = escape_map(exists, "ukey")
	local sql = string.format("update memo.online set active='%s' where ukey in (%s)", math.floor(ski.time()), s)
	local r, e = myconn:query(sql) 		assert(r, e)
end

return {
	find_missing = find_missing,
	set_online = set_online,
	set_offline = set_offline,
	insert_online = insert_online,
	keepalive = keepalive,
}
