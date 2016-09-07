-- tail the realtime statistaics file 

local num_points = 15
local dir_statflow = '/var/run/stat_flow/'
local dir_statuser = '/var/run/stat_user/'

function tail_N_sec(dir)
	local ts_files = assert(io.popen('ls -lt '..(dir)..' 2>&1', 'r'))
	local counter = 0
	local stat = {}
	for ts_file in ts_files:lines() do
		-- -rwxr-xr-x    1 root     root         20324 Sep  7 14:49 nquery
		local ts = ts_file:match("(%d+).dump")
		-- print(ts)
		stat[ts] = {}
		local stats = assert(io.open(dir..ts..'.dump', 'r'))
		for line in stats:lines() do
			-- print(line)
			local key, time, recv, xmit = line:match("%[(.*)%]%s(%d+)%s(%d+)%s(%d+)")
			if key and time and (recv + xmit) ~= 0 then
				-- print('key:'.. key)	print('ts:'..time)
				-- print('recv:'..recv) print('xmit:'..xmit)
				-- print('\n')
				
			end
		end

		-- 
		counter = counter + 1
		if counter >= num_points then
			break
		end
	end
end

function init()
	assert(os.execute("mkdir -p " .. dir_statflow))
	assert(os.execute("mkdir -p " .. dir_statuser))
end

init()
tail_N_sec(dir_statflow)