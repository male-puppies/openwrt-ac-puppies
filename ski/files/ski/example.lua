-- local ski = require("ski")
local ski = require("ski")
local sfs = require("ski.fs")
local tcp = require("ski.tcp")
local misc = require("ski.misc")

local function test1(arg1, arg2)
	print(os.time(), arg1, arg2[1])
	ski.sleep(3)
	print(os.time())
end

local function test2(m)
	for k = 1, m do
		ski.go(function(i) ski.sleep(i) print(os.date(), i) end, k)
	end
	print(os.date(), "go done")
end

local function test3()
	ski.go(function() ski.sleep(1) print("call error") string.format() end)
	ski.go(function() ski.sleep(2) print("impossible") end)
end

local function test4()
	local ch = ski.new_chan(3)
	ski.go(function()
		print(os.date(), "read start")
		for i = 1, 100000 do
			print(os.date(), "try read")
			local ret, err = ch:read()
			if not ret then
				print("read error", err)
				break
			end
			print(os.date(), "read", ret)
		end
		ch:close()
		print("read done")
	end)
	ski.go(function()
		ski.sleep(3)
		print(os.date(), "write start")
		for i = 1, 100000 do
			print(os.date(), "try write", i)
			local ret, err = ch:write(i)
			if not ret then
				print("write error", err)
				break
			end
			print(os.date(), "write", i)
		end
		ch:close()
		print("write done")
	end)
	ski.go(function()
		ski.sleep(3.1)
		ch:close()
	end)
	for i = 1, 5 do
		ski.sleep(1)
		print(os.date())
	end
end

local function test5()
	local ch = ski.new_chan(3)
	ski.go(function()
		ski.sleep(3)
		print(os.date(), "read start")
		for i = 1, 100000 do
			print(os.date(), "try read")
			local ret, err = ch:read()
			if not ret then
				print("read error", err)
				break
			end
			print(os.date(), "read", ret)
		end
		ch:close()
		print("read done")
	end)
	ski.go(function()
		print(os.date(), "write start")
		for i = 1, 100000 do
			print(os.date(), "try write", i)
			local ret, err = ch:write(i)
			if not ret then
				print("write error", err)
				break
			end
			print(os.date(), "write", i)
		end
		ch:close()
		print("write done")
	end)
	ski.go(function()
		ski.sleep(3.1)
		ch:close()
	end)
	for i = 1, 5 do
		ski.sleep(1)
		print(os.date())
	end
end

local function test6()
	local rch, wch = ski.new_chan(5), ski.new_chan(5)
	ski.go(function()
		local skirver, err = tcp.listen("127.0.0.1", 8998) 	assert(skirver, err)
		for i = 1, 2000 do
			local cli, err = skirver:accept()	assert(cli, err)
			ski.go(function()
				local close = function(err)
					cli:close()
					print("server:client close", err)
				end

				while true do
					local data, err = cli:read(4, 1)
					if data then
						if #data < 4 then
							print(#data, err)
						end
						local num = string.unpack("I", data)
						local len = tonumber(num) 	assert(len > 0)
						local data, err = cli:read(len, 1)
						if not data then
							return close(err)
						end

						-- print("server recv", data)
					elseif err ~= "timeout" then
						return close(err)
					end
				end
			end)
		end
	end)

	local rch = ski.new_chan(3)
	ski.go(function()
		for i = 1, 10000000 do
			-- print("r->", i)
			local ret, err = rch:write(os.date())
			if not ret then
				assert(err == "close")
				rch:close()
				break
			end
		end
		print("rch close")
	end)

	ski.go(function()
		for i = 1, 100 do
			local cli, err = tcp.connect("127.0.0.1", 8998) 	assert(cli, err)
			for j = 1, 100 do
				local s, err = rch:read() 	assert(s, err)
				local s = string.format("%d %d %s", i, j, s)
				local data = string.pack("I", #s) .. s
				local ret, err = cli:write(data)		assert(ret, err)
				-- ski.sleep(0.01)
			end
			cli:close()
		end
		rch:close()
		print("writer close")
	end)

	ski.sleep(1)
end

local function test7()
	local path = "not_exist1"
	local stat, err = sfs.stat(path)
	print(path, stat, err)
	ski.go(function()
		local path = "not_exist2"
		local stat, err = sfs.stat(path)
		print(path, stat, err)
	end)

	local pm = function(t) for k, v in pairs(t) do print(k, v) end print("-----------") end
	local path = "test1.lua"
	local stat, err = sfs.stat(path)
	print(path, err) 	pm(stat)
	ski.go(function()
		local path = "test1.lua"
		local stat, err = sfs.stat(path)
		print(path, err) 	pm(stat)
	end)
end

local function test8()
	print(ski.time())
end

local function pt(t)
	for k, v in pairs(t) do print(k, v) end
	print("-------------")
end

local function test9()
	print(misc.exepath())
end

local function test10()
	-- ski.go(function()
	-- 	for i = 1, 10 do
	-- 		-- print(i)
	-- 		ski.sleep(1)
	-- 	end
	-- end)
	local ret, err = misc.spawn("./test.sh")
	print(#ret, err)
	-- print("done")
end

local function test11()
	local ret, err = misc.spawn("sh", "-c", "sleep 4; date")
	print(ret, err)
end

local function test12()
	-- print(sfs.access("noe_exist"))
	-- print(sfs.access("test1.lua"))
	-- pt(sfs.scandir("."))
	local fp, err = sfs.open("/usr/lib/lua/redis.lua", "r")
	local wfp, err = sfs.open("/tmp/redis.lua.tmp", "a")
	for i = 1, 1000 do
		local s, err = fp:read(1600)
		if not s then
			assert(err == "eof")
			print(s and #s, err)
			break
		end
		local ret, err = wfp:write(s)	assert(ret, err)
		if err then
			print(err)
		end
	end
	fp:close()
	local ret, err = wfp:fsync()	assert(ret, err)
	wfp:close()
end

-- ski.run(test1, 1, {2})
-- ski.run(test2, 10)
-- ski.run(test3)
-- ski.run(test4)
-- ski.run(test5)
-- ski.run(test6)
-- ski.run(test7)
-- ski.run(test8)
-- ski.run(test9)
-- ski.run(test10)
-- ski.run(test11)
ski.run(test12)
