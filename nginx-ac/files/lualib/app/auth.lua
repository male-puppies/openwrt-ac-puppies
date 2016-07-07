local js = require("cjson.safe")
local query = require("common.query")

local uri = ngx.var.uri
local host, port = "127.0.0.1", 51235
local function reply(r, d)
	ngx.say(js.encode({status = r, data = d}))
end

local function reply_s(s)
	
end

local function query_u(param)
	return query.query_u(host, port, param)
end

local uri_map = {}
uri_map["/auth/weblogin"] = function()
	local rip = ngx.var.remote_addr
	local p = ngx.req.get_uri_args()

	local magic, id, ip, mac, username, password = p.magic, p.id, p.ip, p.mac, p.username, p.password
	if not (magic and id and ip and mac and username and password) then 
		return reply(1, "invalid param")
	end

	-- ngx.req.read_body()
	-- local p, e = ngx.req.get_post_args()
	local param = {cmd = uri, magic = magic, id = id, ip = ip, mac = mac, username = username, password = password}
	local r, e = query_u(param)
	if not r then
		return reply(1, e)
	end
	return ngx.say(r)
end

-- ngx.log(ngx.ERR, uri)
local f = uri_map[uri]
local _ = f and f()
