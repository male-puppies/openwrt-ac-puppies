local log = require("log")
local js = require("cjson.safe")
local user = require("sync.user")
local sync_map = {
	user = user.sync,
}

local cache = {}
local function sync()
	for tb, action in pairs(cache) do 
		sync_map[tb](action)
	end
	cache = {}
end

local function init()
	for _, f in pairs(sync_map) do 
		f({}, true)
	end
end

local patterns = {
	{key = "update", pattern = "%s+(%w+)%s+set%s", 		action = "set"},
	{key = "insert", pattern = "%s+into%s+(%w+)%s", 	action = "add"},
	{key = "replace", pattern = "%s+into%s+(%w+)%s", 	action = "set"},
	{key = "delete", pattern = "delete%s+from%s+(%w+)", action = "del"},	
}

local function parse(sql)
	for _, item in ipairs(patterns) do 
		local key, pattern, action = item.key, item.pattern, item.action
		if sql:find(key, 1, true) then 
			local tb = sql:match(pattern)
			local _ = tb or log.fatal("invalid sql %s %s", key, sql:sub(1, 100))
			local _ = sync_map[tb] or log.fatal("not register table %s. %s", tb, sql:sub(1, 100))
			local tmp = cache[tb] or {}
			tmp[action] = 1 
			cache[tb] = tmp
			break
		end
	end
end

return {sync = sync, init = init, parse = parse}
