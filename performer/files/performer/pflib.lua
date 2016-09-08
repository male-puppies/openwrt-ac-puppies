-- author: yjs

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

return {
	gen_dispatch_udp 	= gen_dispatch_udp,
	gen_dispatch_tcp 	= gen_dispatch_tcp,
}