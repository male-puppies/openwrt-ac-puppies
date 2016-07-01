local ski = require("ski")
local tcp = require("ski.tcp")
local js = require("cjson.safe")
local ngxrpc = require("ngxrpc")

local function main()
	local code = [[
		local mysql = require "common.mysql" 
		local js = require "cjson.safe"
		 local r, e = mysql.query(function(db)
			-- ngx.log(ngx.ERR, "-----------", js.encode(ngx.ctx.arg))
			return db:query(ngx.ctx.arg[1])
		end)

		local r = {r, e}
		return r
	]]
	local cli = ngxrpc.new("127.0.0.1", 80)
	local r, e = cli:query("test_key", code, {"select * from user limit 1"})	 assert(r, e)
	print(js.encode({r, e}))
end

ski.run(main)
