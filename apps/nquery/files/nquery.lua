-- tail the realtime statistaics file 

local js = require("cjson.safe")

local num_points = 15
local num_node = 5
local floor_value = 1
local dir_statflow = '/var/run/stat_flow/'
local dir_statuser = '/var/run/stat_user/'

function spairs(t, comp)
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end

	if comp then
		table.sort(keys, function (a, b) return comp(t, a, b) end)
	else
		table.sort(keys)
	end

	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

function tail_N_sec(dir)
	local ts_files = assert(io.popen('ls -lt '..(dir)..' 2>&1', 'r'))
	local counter = 0
	local StatRect = {}
	local StatXmit = {}
	-- StatRX[key][time] = data
	for ts_file in ts_files:lines() do
		-- -rwxr-xr-x    1 root     root         20324 Sep  7 14:49 nquery
		local ts = ts_file:match("(%d+).dump")
		-- print(ts)
		local stats = assert(io.open(dir..ts..'.dump', 'r'))
		for line in stats:lines() do
			-- print(line)
			local key, time, recv, xmit = line:match("%[(.*)%]%s(%d+)%s(%d+)%s(%d+)")
			if key and time and recv ~= 0 then
				StatRect[key] = StatRect[key] or {}
				StatRect[key][time] = recv
			end
			if key and time and xmit ~= 0 then
				StatXmit[key] = StatXmit[key] or {}
				StatXmit[key][time] = xmit
			end
		end
		-- 
		counter = counter + 1
		if counter >= num_points then
			break
		end
	end
	--sort
	local output = {}
	function sort_output(stat, prefix)
		local sec2key = {}
		for key, V in pairs(stat) do
			local sec_prev
			for sec, _ in spairs(V) do
				if sec_prev then
					-- calc realtime flux stat.
					local sec_off = sec - sec_prev
					local rt_flux = (V[sec] - V[sec_prev]) / sec_off
					if rt_flux >= floor_value then
						sec2key[sec] = sec2key[sec] or {}
						sec2key[sec][key] = math.ceil(rt_flux)
					end
				end
				sec_prev = sec
			end
		end
		print('****'..prefix..'****')
		local Sorted = {}
		for sec, V in spairs(sec2key) do
			print('\t----'..sec..'----')
			local counter = 0
			-- sort & trunk num nodes format json.
			for key, rt_flux in spairs(V, function(t, a, b) return t[a] > t[b] end) do
				print(key, ' ', rt_flux)
				local stack = {}
				stack[1] = sec * 1000
				stack[2] = rt_flux

				Sorted[key] = Sorted[key] or {}
				Sorted[key]['data'] = Sorted[key]['data'] or {}

				Sorted[key]['name'] = prefix
				table.insert(Sorted[key]['data'], stack)

				counter = counter + 1
				if counter > num_node then
					break
				end
			end
		end
		-- flush output to json
		for key, v in pairs(Sorted) do
			local node = {}
			node['name'] = key ..'-'.. v['name']
			node['data'] = v['data']
			table.insert(output, node)
		end
	end
	sort_output(StatRect, "Recv")
	sort_output(StatXmit, "Xmit")

	-- print(js.encode(output))
	return output
end

function stat_flow()
	assert(os.execute("mkdir -p " .. dir_statflow))
	os.execute("nquery stat flow &")
	return tail_N_sec(dir_statflow)
end

function stat_user()
	assert(os.execute("mkdir -p " .. dir_statuser))
	os.execute("nquery stat user &")
	return tail_N_sec(dir_statuser)
end

return {
	flow = stat_flow,
	user = stat_user,
}

-- init()
-- tail_N_sec(dir_statflow)
-- tail_N_sec(dir_statuser)

-- function help()
	-- print('usage: lua /usr/share/nquery/stat_rt.lua <flow|user>')
-- end

-- function main()
	--print(arg[0])
-- end

-- main()