for i = 1, 10000 do 
	local username, password = "username" .. i, "password" .. i 
	local sql = string.format("insert or ignore into user (username, password, active) values ('%s', '%s', datetime('now', 'localtime'))", username, password)
	local cmd = string.format('lua tool.lua w "%s"', sql)
	os.execute(cmd)
end 