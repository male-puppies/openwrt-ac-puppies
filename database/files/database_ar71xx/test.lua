for i = 1, 10 do
	local name = "group" .. i
	local sql = string.format("insert or ignore into acgroup (name) values ('%s')", name)
	local cmd = string.format('lua tool.lua w "%s"', sql)
	os.execute(cmd)
end


for i = 1, 60000 do
	local username, password = "username" .. i, "password" .. i
	local sql = string.format("insert or ignore into user (username, password, gid) values ('%s', '%s', %s)", username, password, math.random(1, 10))
	local cmd = string.format('lua tool.lua w "%s"', sql)
	os.execute(cmd)
end