local luv = require("luv")
local ski = require("ski.core")

local ski_cur_thread = ski.cur_thread

----------------------------------- tcp client ---------------------------------

local tcp_client_method = {}
local tcp_client_mt = {__index = tcp_client_method}

local function tcp_client_get_internel(self, size)
	local data, res = self.rbuf
	if size then
		res, self.rbuf = data:sub(1, size), data:sub(size + 1)
		return res
	end

	res, self.rbuf = data, ""
	return res
end

local function tcp_client_stop_return(cur, cli, data, err)
	local _ = cur.timer:stop(), cli:read_stop(), cur:setdata({data, err}):wakeup()
end

function tcp_client_method:read(size, timeout)
	if not self.client then
		return nil, "close"
	end

	local g = tcp_client_get_internel
	if #self.rbuf >= size then
		return g(self, size)
	end

	local cur, cli = ski_cur_thread(), self.client
	local timer, rt = cur.timer, tcp_client_stop_return

	local ret, err = cli:read_start(function(err, data)
		if not data then  	-- close
			return rt(cur, cli, nil, err or "close")	-- return rt(cur, cli, g(self, size), err or "close")
		end

		self.rbuf = self.rbuf .. data

		if err then  									-- error happend
			return rt(cur, cli, nil, err)				-- return rt(cur, cli, g(self, size), err)
		end

		if #self.rbuf >= size then 		-- size ok
			return rt(cur, cli, g(self, size))
		end

		-- not enough, go on read
		-- print("size not enough, go on", #self.rbuf, size)
	end)

	if not ret then
		return nil, err
	end

	local ret, err = timer:start(timeout * 1000, 0, function()
		return rt(cur, cli, g(self, #self.rbuf), "timeout") 	-- timeout, do not return any data
	end)

	assert(ret, err)

	return cur:yield()
end

function tcp_client_method:read2()
	if not self.client then
		return nil, "close"
	end

	local cur, cli = ski_cur_thread(), self.client
	local ret, err = cli:read_start(function(err, data)
		cli:read_stop()

		if not data then
			return cur:setdata({nil, err or "close"}):wakeup()
		end

		if #self.rbuf > 0 then
			data, self.rbuf = self.rbuf .. data, ""
		end

		cur:setdata({data, err}):wakeup()
	end)

	if not ret then
		return nil, err
	end

	return cur:yield()
end

function tcp_client_method:write(data)
	if not self.client then
		return nil, "close"
	end

	local cur, cli = ski_cur_thread(), self.client
	cli:write(data, function(err)
		if err then
			return cur:setdata({nil, err}):wakeup()
		end

		return cur:setdata({true}):wakeup()
	end)

	return cur:yield()
end

function tcp_client_method:close()
	self.client:close()
	self.client, self.rbuf = nil, nil
end

local function new_tcp_client(client)
	local obj = {client = client, rbuf = ""}
	setmetatable(obj, tcp_client_mt)
	return obj
end

----------------------------------- tcp server ---------------------------------

local tcp_server_method = {}
local tcp_server_mt = {__index = tcp_server_method}

function tcp_server_method:close()
	self.server:close()
	self.server = nil
end

function tcp_server_method:accept()
	if #self.cache > 0 then
		local item = table.remove(self.cache, 1)
		return item[1], item[2]
	end
	self.state = "yield"
	ski_cur_thread():yield()
	self.state = "run"
	assert(#self.cache > 0, #self.cache)
	local item = table.remove(self.cache, 1)
	return item[1], item[2]
end

local function new_tcp_server(server)
	local obj = {server = server, cache = {}, state = "yield"}
	setmetatable(obj, tcp_server_mt)
	return obj
end

local function create_tcp_server(host, port)
	assert(host and port)

	local server = luv.new_tcp()
	local r, err = server:bind(host, port)
	if not r then
		return nil, err
	end

	local cur = ski_cur_thread()
	local ins = new_tcp_server(server)
	local ret, err = server:listen(128, function(err)
		if err then
			table.insert(ins.cache, {nil, err})
			if ins.state == "yield" then
				cur:setdata({}):wakeup()
			end
		end
		local client = luv.new_tcp()
		server:accept(client)
		local ret, err = client:nodelay(true)
		table.insert(ins.cache, {new_tcp_client(client)})
		if ins.state == "yield" then
			cur:setdata({}):wakeup()
		end
	end)

	if not ret then
		return nil, err
	end

	return ins
end

local function tcp_connect(host, port)
	assert(host and port)

	local cur, client = ski_cur_thread(), luv.new_tcp()
	local ret, err = client:connect(host, port, function(err)
		if err then
			return cur:setdata({nil, err}):wakeup()
		end
		local ret, err = client:nodelay(true)
		return cur:setdata({new_tcp_client(client)}):wakeup()
	end)

	if not ret then
		return nil, err
	end

	return cur:yield()
end

return {
	connect = tcp_connect,
	listen = create_tcp_server,
}
