local ski = require("ski")
local log = require("log")
local js = require("cjson.safe")

local cmd_map = {}

local function init(m)

end


local function dispatch(cmd)
	local f = cmd_map[cmd.cmd]
	if f then
		return true, f(cmd)
	end
end


return {init = init, dispatch = dispatch}

