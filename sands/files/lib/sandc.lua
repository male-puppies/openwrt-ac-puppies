local ski = require("ski")
local tcp = require("ski.tcp")
local sandutil = require("sandutil")
local rdsparser = require("rdsparser")

local tomap, toarr, checkarr = sandutil.tomap, sandutil.toarr, sandutil.checkarr

local st_new, st_run, st_stop = "new", "run", "stop"
local function fatal(fmt, ...)
	io.stderr:write(string.format(fmt, ...))
	os.exit(-1)
end

local method = {}
local mt = {__index = method}

function method.set_auth(ins, username, password)
	ins.param.username, ins.param.password = username, password
end

function method.set_will(ins, topic, payload)
	ins.param.will_topic, ins.param.will_payload = topic, payload
end

function method.set_connect(ins, topic, payload)
	ins.param.connect_topic, ins.param.connect_payload = topic, payload
end

function method.pre_subscribe(ins, ...)
	ins.param.topics = {...}
end

function method.set_keepalive(ins, s)
	ins.param.keepalive = s
end

function method.running(ins)
	return ins.state ~= st_stop
end

local function close_client(ins, err)
	print("close on error", err, ins.param.clientid)
	ins.client:close()
	ins.decoder:decode_free()
	ins.state, ins.client,ins.decoder = st_stop, nil, nil
	ins.on_disconnect(1, err)
end

function method.publish(ins, topic, payload)
	assert(ins and topic and payload)
	if not ins:running() then
		return false
	end

	local map = ins.pb_item
	map.tp, map.pl = topic, payload

	local ret, err = ins.client:write(rdsparser.encode(toarr(map)))
	if not ret then
		close_client(ins, err)
		return false
	end
	return true
end

function method.disconnect(ins)
	if ins.state ~= st_run then
		return
	end

	ins.client:write(rdsparser.encode(toarr({id = "dc"})))
	ins.client:close()
	ins.client = nil
	ins.state = st_stop
	ins.on_disconnect(0, "close by user")
end

function method.connect(ins, host, port)
	local cli, err = tcp.connect(host, port)
	if not cli then
		return nil, err
	end

	local m = ins.param
	if not (m.clientid and #m.clientid > 0 and m.username and #m.username > 0 and m.password and #m.password > 0
		and m.version and #m.version > 0 and m.keepalive and m.keepalive >= 5 and #m.topics > 0) then
		return nil, "invalid param"
	end

	local _ = (m.will_topic or m.will_payload) and assert(#m.will_topic > 0 and #m.will_payload > 0)
	local _ = (m.connect_topic or m.connect_payload) and assert(#m.connect_topic > 0 and #m.connect_payload > 0)

	local map = {
		id = "cn",
		cd = m.clientid,
		vv = m.version,
		un = m.username,
		pw = m.password,
		kp = m.keepalive,
		tp = table.concat(m.topics, "\t"),
		ct = m.connect_topic,
		cp = m.connect_payload,
		wt = m.will_topic,
		wp = m.will_payload,
	}

	local ret, err = cli:write(rdsparser.encode(toarr(map)))
	if err then
		cli:close()
		ins.state = st_stop
		return nil, err
	end

	ins.client = cli
	ins.state = st_run
	return true
end

function method.set_callback(ins, name, cb)
	assert(ins[name])
	ins[name] = cb
end

local function timeout_ping(ins)
	local last = ski.time()
	local s = rdsparser.encode(toarr({id = "pi"}))
	local keepalive = ins.param.keepalive
	while ins:running() do
		while ins:running() do
			local now = ski.time()

			-- timeout
			if now - ins.active >= keepalive * 2.1 then
				return close_client(ins, "timeout")
			end

			if now - last >= keepalive then
				break
			end

			ski.sleep(5)
		end

		last = ski.time()
		if not ins:running() then
			break
		end

		-- send ping
		local ret, err = ins.client:write(s)
		if err then
			return close_client(ins, err)
		end
	end
end

local cmd_map = {}
function cmd_map.pb(ins, map)
	ins.on_message(map.tp, map.pl)
	return true
end

function cmd_map.ca(ins, map)
	if not (map.st and tonumber(map.st) == 0 and map.da) then
		return nil, map.data or "undefined"
	end
	ins.on_connect()
	return true
end

function cmd_map.po(ins, map)
	return true
end

local function run_internal(ins)
	local dispatch = function(map)
		local id = map.id
		if not id then
			return true
		end
		local func = cmd_map[id]
		if not func then
			return true
		end

		return func(ins, map)
	end

	local decoder, client = ins.decoder, ins.client
	while ins:running() do
		local data, rerr = client:read2()
		if data then
			ins.active = ski.time() 			-- recv data, update active time
			local r, e = decoder:decode(data)
			if not r then
				close_client(ins, r)
				return
			end

			for _, arr in ipairs(r) do
				local r, e = dispatch(tomap(arr))
				if not r then
					close_client(ins, e)
					return
				end
			end
		end

		-- check recv error
		if rerr and rerr ~= "timeout" then
			close_client(ins, rerr)
			break
		end
	end
end

function method.run(ins)
	ski.go(timeout_ping, ins) 			-- ping routine
	ski.go(run_internal, ins)
end

local function numb() end
local function new(clientid)
	assert(clientid)
	local obj = {
		-- param
		param = {
			clientid = clientid,
			username = "",
			password = "",
			version = "v0.1",
			keepalive = 30,
			topics = {},
			connect_topic = nil,
			connect_payload = nil,
			will_topic = nil,
			will_payload = nil,
		},

		-- client conenction
		client = nil,

		data = "",
		state = st_new,
		active = ski.time(),

		on_message = numb,
		on_connect = numb,
		on_disconnect = numb,

		pb_item = {id = "pb"},

		decoder = rdsparser.decode_new(),
	}

	setmetatable(obj, mt)
	return obj
end

return {new = new}
