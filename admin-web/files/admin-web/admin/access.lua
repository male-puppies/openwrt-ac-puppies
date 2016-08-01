package.path = "/usr/share/admin-web/?.lua;" .. package.path
local authlib = require("authlib") 

local function redirect()
	ngx.redirect(login_html)
end

local uri = ngx.var.uri  
local login_html = "/v1/admin/rs/login.html"
if uri == login_html then
	return
end

local cookie = ngx.req.get_headers().cookie
if not cookie then 
	return redirect()
end

cookie = cookie .. ";"
local token = cookie:match("token=(.-);")
local r, e = authlib.check_method_token("GET", token)
if not r then
	return redirect()
end

local r, e = authlib.validate_token(token)
if not r then
	return redirect()
end
