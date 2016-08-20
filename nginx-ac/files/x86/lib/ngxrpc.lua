local ski = require("ski")
local tcp = require("ski.tcp")
local js = require("cjson.safe")

local function build_query(key, code, arg)
	local cmd = {k = key, p = arg, f = code}
	local s = js.encode(cmd)
	return string.format("GET /rpc HTTP/1.0\r\nHost: localhost:80\r\nUser-Agent: curl/7.48.0\r\nAccept: \r\nContent-Length: %s\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\n%s", #s, s)
end

local function query_aux(host, port, key, code, arg)
	local cli, e = tcp.connect(host, port) 			assert(cli, e)
	local s = build_query(key, code, arg)
	local r, e = cli:write(s) 						assert(r, e)
	local data, conent_length, state = ""
	while true do
		local s, e = cli:read2()
		if s then
			data = data .. s
			-- print(data)
			if not state then
				-- HTTP/1.1 200 OK
				state = data:match("^HTTP/1.1 (%d+) ")
				if state and state ~= "200" then
					return nil, state
				end
			end

			-- Content-Length: 377001
			if not conent_length then
				conent_length = tonumber(string.match(data, "Content%-Length: (%d+)\r\n"))
			end
		end

		if e then
			cli:close()
			break
		end
	end

	if not (state and conent_length) then
		return nil, "invalid response"
	end

	local s, e = data:find("\r\n\r\n")
	if #data - e ~= conent_length then
		return nil, "invalid Content-Length"
	end
	-- print(data)
	return data:sub(e + 1)
end

local method = {}
local mt = {__index = method}
function method:query(key, code, arg)
	local r, e = query_aux(self.host, self.port, key, nil, arg)
	if not r then
		return nil, e
	end

	local r, e = js.decode(r)
	if not r then
		return nil, e
	end

	if not r.e then
		return r.d
	end

	if r.d ~= "miss" then
		return nil, r.d
	end

	local r, e = query_aux(self.host, self.port, key, code, arg)
	if not r then
		return nil, e
	end

	local r, e = js.decode(r)
	if not r then
		return nil, e
	end

	if not r.e then
		return r.d
	end

	return nil, r.d
end

local function new(host, port)
	local obj = {host = host or "127.0.0.1", port = port or 8080}
	setmetatable(obj, mt)
	return obj
end

return {new = new}
