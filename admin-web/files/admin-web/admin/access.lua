package.path = "/usr/share/admin-web/?.lua;" .. package.path
local authlib = require("admin.authlib") 

local login_html = "/login/admin_login/tologin.html"
local function redirect()
	ngx.redirect(login_html)
end

local uri = ngx.var.uri  
if uri:find("login.html$") then
	return
end

local cookie = ngx.req.get_headers().cookie
if not cookie then 
	return redirect()
end

cookie = cookie .. ";"
local token = cookie:match("token=(.-);") or cookie:match("md5psw=(.-);")
local r, e = authlib.check_method_token("GET", token)
if not r then
	return redirect()
end

local r, e = authlib.validate_update_token(token)
if not r then
	return redirect()
end
