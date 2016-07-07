for i = 1, 60000 do 
	local username, password = "username" .. i, "password" .. i 
	local sql = string.format("insert or ignore into user (username, password) values ('%s', '%s')", username, password)
	local cmd = string.format('lua tool.lua w "%s"', sql)
	os.execute(cmd)
end 