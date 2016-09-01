local ski = require("ski")
local redis = require("redis2")
local js = require("cjson.safe")

local function main()
	local ins = redis.new()
	local r, e = ins:connect("127.0.0.1", 6379)	assert(r, e)

	local r, e = ins:call("set", "a", 222)
	print(js.encode({r, e}))

	local r, e = ins:call("get", "a")
	print(js.encode({r, e}))

	local r, e = ins:call("select", 0)
	print(js.encode({r, e}))

	local r, e = ins:call("rpush", "aaaa", "fdafads")
	print(js.encode({r, e}))

	local r, e = ins:call("llen", "aaaa")
	print(js.encode({r, e}))

	local auth_index = 9
	local token_ttl_code = [[
		local pc, index, token = redis.call, ARGV[1], ARGV[2]
		local r = pc("SELECT", index) 		assert(r.ok == "OK")
		r = pc("TTL", "admin_" .. token)
		return r
	]]

	local r, e = ins:call("eval", token_ttl_code, 0, auth_index, "94445e8c9a49fb09d3dbd1c235216bb2")
	print(js.encode({r, e}))

	ins:close()
end

ski.run(main)