local ski = require("ski")
local js = require("cjson.safe")
local rpccli = require("rpccli")
local simplesql = require("simplesql")
local sandcproxy = require("sandcproxy")

local function start_sand_server()
	local unique = "a/local/dump_client"
	local numb = function(...)
		print(...)
	end
	local args = {
		log = 1,
		unique = unique,
		clitopic = {unique},
		on_message = numb,
		on_disconnect = numb,
		srvtopic = {unique .. "_srv"},
	}
	proxy = sandcproxy.run_new(args)
	return proxy
end

local function rpc()
	local dbrpc = rpccli.new(start_sand_server(), "a/local/database_srv")
	return simplesql.new(dbrpc), dbrpc
end

local cmd_map = {}
function cmd_map.r(sql)
	assert(sql)
	local r = rpc():select2(sql)
	for i, v in ipairs(r) do print(i, js.encode(v)) end
end

function cmd_map.w(sql)
	assert(sql, "sql")
	rpc():execute2(sql)
end

function cmd_map.backup()
	local code = [[
		local ins = require("mgr").ins()
		return ins.conn:protect(function()
			ins.ud:backup()
			return true
		end)
	]]
	local _, dbrpc = rpc()
	local r, e = dbrpc:fetch("backup_db", code)
	if e then io.stderr:write("error ", e, "\n") os.exit(-1) end
	print(r)
end

local function main(cmd, ...)
	cmd_map[cmd](...)
	os.exit(0)
end

ski.run(main, ...)
