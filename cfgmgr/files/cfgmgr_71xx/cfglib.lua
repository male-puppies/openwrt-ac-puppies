local js = require("cjson.safe")

local function gen_dispatch_udp(udp_map)
	return function(cmd, ip, port)
		local f = udp_map[cmd.cmd]
		if f then
			return true, f(cmd, ip, port)
		end
	end
end

local function gen_dispatch_tcp(tcp_map)
	return function(cmd)
		local f = tcp_map[cmd.cmd]
		if f then
			return true, f(cmd.data)
		end
	end
end

local function gen_reply(udpsrv)
	return function(ip, port, r, d)
		udpsrv:send(ip, port, js.encode({status = r, data = d}))
		return true
	end
end

return {
	gen_reply = gen_reply,
	gen_dispatch_udp = gen_dispatch_udp,
	gen_dispatch_tcp = gen_dispatch_tcp,
}
