local js = require("cjson.safe")
local query = require("common.query")

local uri = ngx.var.uri
local host, port = "127.0.0.1", 50010
local function reply(r, d)
	ngx.say(js.encode({status = r, data = d}))
end

local function query_u(param)
	return query.query_u(host, port, param, 1000)
end

local uri_map = {}

local f = uri_map[uri]
local _ = f and f()
if not f then
	reply(1, string.format("not implement '%s'", uri))
end
