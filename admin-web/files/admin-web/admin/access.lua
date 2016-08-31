-- author: yjs

package.path = "/usr/share/admin-web/?.lua;" .. package.path
local adminlib = require("admin.adminlib")

local login_html = "/view/admin_login/tologin.html"
local function redirect()
	ngx.redirect(login_html)
end

local uri = ngx.var.uri
if uri:find("tologin.html$") then
	return
end

local cookie = ngx.req.get_headers().cookie
if not cookie then
	return redirect()
end

cookie = cookie .. ";"
local token = cookie:match("token=(.-);")
local r, e = adminlib.check_method_token("GET", token)
if not r then
	return redirect()
end

local r, e = adminlib.validate_update_token(token)
if not r then
	return redirect()
end
