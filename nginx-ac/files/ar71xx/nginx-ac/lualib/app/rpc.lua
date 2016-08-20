local js = require("cjson.safe")
local cache = require("common.rpccache")
local function reply(d)
	ngx.print(type(d) == "table" and js.encode(d) or d)
end

ngx.req.read_body()
local s = ngx.req.get_body_data()
if not s then
	return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local rpc = js.decode(s)
if not rpc then
	return ngx.exit(ngx.HTTP_BAD_REQUEST)
end
local k, p, bt = rpc.k, rpc.p, rpc.f
if bt then
	ngx.log(ngx.ERR, "loadstring ", bt)
	local f, e = loadstring(bt)
	if not f then
		return reply({d = e, e = 1})
	end
	cache.set(k, f)
end
local f = cache.get(k)
if not f then
	return reply({d = "miss", e = 1})
end
ngx.ctx.arg = p
local r, e = f()
if not r then
	return reply({d = e, e = 1})
end
reply({d = r})