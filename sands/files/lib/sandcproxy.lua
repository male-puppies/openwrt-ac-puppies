local ski = require("ski") 
local sandc = require("sandc")
local js = require("cjson.safe") 

local function numb()  end

local method = {}
local mt = {__index = method}

function method:running() return self.mqtt:running() end
function method:set_callback(name, cb) self.mqtt:set_callback(name, cb) end
function method:publish(...) return self.mqtt:publish(...) end
function method:disconnect() return self.mqtt:disconnect() end
function method:connect(...) return self.mqtt:connect(...) end 
function method:set_auth(...) return self.mqtt:set_auth(...) end
function method:set_will(...) return self.mqtt:set_will(...) end
function method:set_connect(...) return self.mqtt:set_connect(...) end
function method:set_keepalive(...) return self.mqtt:set_keepalive(...) end
function method:set_message_cb(cb) self.on_message = cb end 
function method:set_proxy_topic(t) self.proxy_topic = t end
function method:run() 
	local timeout_item = {nil, "timeout"}
	ski.go(function()
		while self.mqtt:running() do 
			ski.sleep(1)
			local now, del, out_seq_map = ski.time(), {}, self.out_seq_map
			for seq, v in pairs(out_seq_map) do
				local _ = now - v.t > v.m and table.insert(del, seq)
			end
			for _, seq in ipairs(del) do
				out_seq_map[seq].ch:write(timeout_item) 
			end
		end
	end)
	return self.mqtt:run() 
end 

function method:pre_subscribe(client_topics, server_topics)
	local arr = {}
	for _, tp in ipairs(client_topics) do 
		self.cli_topics[tp] = 1, table.insert(arr, tp)
		self.cli_topic = self.cli_topic and self.cli_topic or tp
	end
	for _, tp in ipairs(server_topics or {}) do 
		self.srv_topics[tp] = 1, table.insert(arr, tp)
	end

	assert(self.cli_topic)
	return self.mqtt:pre_subscribe(unpack(arr))  
end

function method:query(topic, data, timeout)
	local seq, ch = self.seq, ski.new_chan(1)
	self.seq = self.seq + 1 

	local r, seq_item = self.query_item, {}
	r.seq, r.pld, r.mod = seq, data, self.cli_topic	
	seq_item.ch, seq_item.m, seq_item.t = ch, timeout or 3, ski.time()
	self.out_seq_map[seq] = seq_item
	local s = js.encode(r)
	local ret, err = self.mqtt:publish(topic, s)	 	assert(ret, err)
	local r, e = ch:read()		 						assert(r, e)
	self.out_seq_map[seq] = nil
	ch:close()
	return r[1], r[2]
end

function method:query_r(topic, data, timeout)
	local seq, ch = self.seq, ski.new_chan(1)
	self.seq = self.seq + 1 
	local r, seq_item = {out_topic = topic, data = {mod = self.cli_topic, seq = seq, pld = data}}, {}
	seq_item.ch, seq_item.m, seq_item.t = ch, timeout or 3, ski.time()
	self.out_seq_map[seq] = seq_item
	local s = js.encode(r) 
	local ret, err = self.mqtt:publish(self.proxy_topic, s)	 	assert(ret, err)
	local r, e = ch:read()		 								assert(r, e)
	self.out_seq_map[seq] = nil
	ch:close()
	return r[1], r[2]
end

function method:publish_r(topic, data)   
	local s = js.encode({out_topic = topic, data = {pld = data}})
	return self.mqtt:publish(self.proxy_topic, s)
end

local function new(clientid)
	local mqtt = sandc.new(clientid) 

	local obj = {
		seq = 0, 
		mqtt = mqtt, 
		cli_topic = nil,
		cli_topics = {},
		srv_topics = {},
		out_seq_map = {},  
		on_message = numb, 
		query_item = {},
		proxy_topic = "a/ac/proxy",
	}

	local content = {}
	mqtt:set_callback("on_message", function(topic, payload)
		if topic ~= obj.cli_topic then
			return obj.on_message(topic, payload)
		end

		local map = js.decode(payload)
		if not (map and map.seq and map.pld) then 
			return obj.on_message(topic, payload)
		end

		local seq = math.floor(tonumber(map.seq))
		local n = obj.out_seq_map[seq]
		if n then
			content[1] = map.pld
			n.ch:write(content)
		end
	end)

	setmetatable(obj, mt)
	return obj
end

local function run_new(map)
	assert(map and map.on_message and map.on_disconnect and map.unique and map.log)
	local proxy = new(map.unique)
	proxy:set_auth("ewrdcv34!@@@zvdasfFD*s34!@@@fadefsasfvadsfewa123$", "1fff89167~!223423@$$%^^&&&*&*}{}|/.,/.,.,<>?")
	proxy:pre_subscribe(map.clitopic or {}, map.srvtopic or {})
	proxy:set_message_cb(map.on_message) 
	local _ = map.on_disconnect and proxy:set_callback("on_disconnect", map.on_disconnect)
	local host, port = "127.0.0.1", 61886
	local ret, err = proxy:connect(map.host or "127.0.0.1", map.port or 61886)
	local _ = ret or map.log.fatal("connect fail %s", err)
	proxy:run()
	return proxy 
end

return {new = new, run_new = run_new}

