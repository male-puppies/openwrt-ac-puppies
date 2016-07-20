local global = require("admin.global") 
local function redirect()
	ngx.redirect(login_html)
end

local uri = ngx.var.uri  
local login_html = "/admin/rs/login.html"
if uri == login_html then
	return
end

local cookie = ngx.req.get_headers().cookie
if not cookie then 
	return redirect()
end

cookie = cookie .. ";"
local token = cookie:match("token=(.-);")
local r, e = global.check_method_token("GET", token)
if not r then
	return redirect()
end

local r, e = global.validate_token(token)
if not r then 
	return redirect()
end
