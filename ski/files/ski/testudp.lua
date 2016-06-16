local ski = require("ski")
local udp = require("ski.udp")

local function server()
	print("server")
	local srv = udp.new()
	local r, e = srv:bind("127.0.0.1", 12345) 	assert(r, e)
	while true do 
		local r, e, p = srv:recv() 				--	assert(r, e)
		if not r then 
			print(e)
			break 	
		end 
		print(#r, e, p)
		-- print("main server", r, e, p)
		-- ski.sleep(0.7)
	end
end

local function client() 
	local cli = udp.new()
	local i = 1
	local p = "1234567890"
	for j = 1, 3000 do 
		local r, e = cli:send("127.0.0.1", 12345, p:rep(i)) 	assert(r, e)
		i = i + 1
		ski.sleep(0.1)
	end
	print(cli:close())
	print("client close")
end

local function server2()
	print("server")
	local srv = udp.new()
	local r, e = srv:bind("127.0.0.1", 12345) 		assert(r, e)
	
	while true do
		local r, e, p = srv:recv() 					assert(r, e)
		print(r, e)
	end
end

local function client2()
	local cli = udp.new()
	local r, e = cli:bind("127.0.0.1", 12346) 	assert(r, e)
	while true do
		local r, e = cli:send("127.0.0.1", 12345, os.date()) 	assert(r, e)
		local r, e, p = cli:recv() 								assert(r, e)
		-- print(r, e, p)
		-- ski.sleep(0.5)
	end
end

local function main()
	ski.go(server)
	ski.go(client)
	-- ski.go(server2)
	-- ski.go(client2)
end

ski.run(main)
