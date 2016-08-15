package.path = "/usr/share/admin-web/?.lua;" .. package.path
local reply_e = require("admin.adminlib").reply_e

-- 检查uri格式
local uri = ngx.var.uri
local ver, cmd = uri:match("/(.-)/admin/api/(.+)")
if not (cmd and ver) then
	return reply_e({e = "invalid request"})
end

local cmd_map = {}

-- curl 'http://127.0.0.1/v1/admin/api/login?username=wjrc&password=wjrc0409'
if cmd == "login" then
	return require("admin.login").run()
end

-- curl 'http://127.0.0.1/v1/admin/api/iface_get?token=77d0aeb8ae53926a363f1eb6973bb7ca'
-- curl 'http://127.0.0.1/v1/admin/api/iface_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'arg=json_string'
if cmd:find("^iface_") then
	return require("admin.iface").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_del?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ipgids=[0,1,2,3]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ipgid=1&ipgrpname=xxx&ipgrpdesc=yyy&ranges=["0.0.0.7/16"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_add?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'ipgid=63&ipgrpname=xxx2&ipgrpdesc=yyy&ranges=["0.0.0.7-0.0.0.999"]'
-- curl 'http://127.0.0.1/v1/admin/api/ipgroup_get?token=77d0aeb8ae53926a363f1eb6973bb7ca&page=1&count=10&order=ipgrpname&desc=1&search=ipgrpname&like=ALL'
if cmd:find("^ipgroup_") then
	return require("admin.ipgroup").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/authrule_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'rid=0&rulename=rulename&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_get?token=77d0aeb8ae53926a363f1eb6973bb7ca&page=1&count=10'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_del?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'rids=[0,1,2,3,4]'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_add?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'rulename=rulename4&ruledesc=ruledesc&zid=0&ipgid=63&authtype=auto&enable=1&modules={"web":1}&iscloud=0&white_ip=[]&white_mac=[]&wechat={}&sms={}'
-- curl 'http://127.0.0.1/v1/admin/api/authrule_adjust?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'rids=[1,2]'
if cmd:find("^authrule_") then
	return require("admin.authrule").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/kv_get?token=77d0aeb8ae53926a363f1eb6973bb7ca&keys=%5B%22offline_time%22,%22bypass_dst%22%5D'
-- curl 'http://127.0.0.1/v1/admin/api/kv_set?token=77d0aeb8ae53926a363f1eb6973bb7ca' -d 'offline_time=1900&redirect_ip=1.1.1.1&bypass_dst=[1]'
if cmd:find("^kv_") then
	return require("admin.kv").run(cmd)
end

-- curl 'http://127.0.0.1/v1/admin/api/timegroup_del?token=857a6d143d1982d267b7b989f5e9f692' -d 'tmgids=[0,1,2,3,4,5]'
-- curl 'http://127.0.0.1/v1/admin/api/timegroup_set?token=857a6d143d1982d267b7b989f5e9f692' -d 'tmgid=0&tmgrpname=xxx&tmgrpdesc=yyy&days={"mon":1,"tues":1,"wed":1,"thur":1,"fri":1,"sat":0,"sun":0}&tmlist=[{"hour_start":8,"min_start":0,"hour_end":16,"min_end":0}, {"hour_start":14,"min_start":0,"hour_end":16,"min_end":0}]'
-- curl 'http://127.0.0.1/v1/admin/api/timegroup_add?token=857a6d143d1982d267b7b989f5e9f692' -d 'tmgid=1&tmgrpname=ggg&tmgrpdesc=yyy&days={"mon":0,"tues":0,"wed":0,"thur":0,"fri":0,"sat":0,"sun":0}&tmlist=[{"hour_start":0,"min_start":0,"hour_end":0,"min_end":0}]'
-- curl 'http://192.168.9.222/v1/admin/api/timegroup_get?token=857a6d143d1982d267b7b989f5e9f692&page=1&count=10&order=tmgrpname&desc=1&search=tmgrpname&like=ALL'
-- curl 'http://192.168.9.222/v1/admin/api/timegroup_get?token=857a6d143d1982d267b7b989f5e9f692&page=1&count=10'
if cmd:find("^timegroup_") then
	return require("admin.timegroup").run(cmd)
end
