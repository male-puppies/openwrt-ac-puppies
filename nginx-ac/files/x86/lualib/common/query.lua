local tcp = ngx.socket.tcp
local js = require("cjson.safe")

local function query(host, port, map, timeout)
    local sock, err = tcp()
    if not sock then 
        return nil, err 
    end

    sock:settimeout(timeout or 10000)

    local ret, err = sock:connect(host, port)
    if not ret then
        return nil, err
    end 

    local s = js.encode(map)
    local ret, err = sock:send(#s .. "\r\n" .. s)
    if not ret then 
        sock:close()
        return nil, err 
    end

    local iter = sock:receiveuntil("\r\n")
    local data, err = iter()
    if not data then 
        sock:close()
        return nil, err 
    end

    local len = tonumber(data)
    if not len then
        sock:close()
        return nil, "invalid len" 
    end

    local data, err = sock:receive(len)
    if not data then 
        sock:close()
        return nil, err
    end

    sock:close()
    return data
end

local function query_u(host, port, un, timeout)
    local cli = ngx.socket.udp()
    local r, e = cli:setpeername(host, port)
    if not r then return nil, e end 
    local r, e = cli:send(type(un) == "table" and js.encode(un) or un)
    if not r then return nil, e end
    cli:settimeout(timeout or 3000)
    local r, e = cli:receive()
    cli:close()
    if not r then return nil, e end
    return r
end

return {query = query, query_u = query_u}
