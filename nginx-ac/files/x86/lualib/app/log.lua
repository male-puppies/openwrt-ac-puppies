local share = require("common.share")
local log = require("common.log")
if ngx.var.remote_addr ~= "127.0.0.1" then
	return ngx.exit(ngx.HTTP_FORBIDDEN)
end
local s = ngx.req.get_uri_args().level
local s = type(s) == "string" and s or ""
log.setlevel(s)
ngx.log(ngx.ERR, "set log level to ", s)
