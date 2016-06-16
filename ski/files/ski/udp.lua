local luv = require("luv") 
local ski = require("ski.core") 

local method = {}
local mt = {__index = method}

local ski_cur_thread = ski.cur_thread 

function method:bind(host, port)
	assert(not self.isserver)
	local r, e = self.udp:bind(host, port)
	if not r then 
		return nil, e 
	end
	self.isserver = true
	return true
end

function method:recv(timeout)
	assert(self.isserver, "nerver call bind")
	local cur, udp = ski_cur_thread(), self.udp
	if not self.recving then
		local r, e = udp:recv_start(function(e, d, a)
			if e then 
				table.insert(self.cache, {nil, e})
				return self.state == "yield" and cur:setdata({}):wakeup()
			end

			if not (d and a) then
				return
			end 

			table.insert(self.cache, {d, a.ip, a.port})
			return self.state == "yield" and cur:setdata({}):wakeup()
		end)

		if not r then 
			return nil, e 
		end

		self.recving = true 
	end

	if #self.cache > 0 then 
		local item = table.remove(self.cache, 1) 
		return item[1], item[2], item[3]
	end

	local timer = cur.timer
	local r, e = timer:start((timeout or 3) * 1000, 0, function()
		table.insert(self.cache, {nil, "timeout"})
		cur:setdata({}):wakeup()
	end)
	if not r then 
		return nil, e
	end

	self.state = "yield"
	ski_cur_thread():yield()
	self.state = "run"
	timer:stop()
	local count = #self.cache
	assert(count > 0, count)
	local _ = count > 20 and io.stderr:write("too many udp cache ", count, "\n")
	local item = table.remove(self.cache, 1) 
	return item[1], item[2], item[3]
end

function method:send(host, port, data)
	local cur, udp = ski_cur_thread(), self.udp
	local r, e = udp:send(data, host, port, function(e)
		cur:setdata(e and {nil, e} or {true}):wakeup()
	end)
	if not r then 
		return nil, e 
	end
	return cur:yield()
end

function method:close()
	self.udp:recv_stop()
	self.udp:close()
	self.udp = nil
end

local function new()
	local obj = {
		udp = luv.new_udp(), 
		isserver = false, 
		recving = false,
		state = "yield",
		cache = {}, 
	}
	setmetatable(obj, mt)
	return obj
end

return {new = new}
