local se = require("se")
local log = require("log")
local js = require("cjson.safe")
local baseclient = require("baseclient2")

local function cursec()
	return math.floor(se.time())
end

local function numb()  end

local mt_ext = {}
mt_ext.__index = {
	run = function(ins)
		return ins.base_ins:run()
	end,

	publish = function(ins, topic, payload)
		return ins.base_ins:publish(topic, payload, 0, false)
	end,

	-- request_common = function(ins, topic, payload)
	-- 	assert(topic and payload)

	-- 	local nseq
	-- 	nseq, ins.seq = ins.seq, ins.seq + 1

	-- 	local timeout = 3
	-- 	local map = {
	-- 		mod = ins.base_ins:get_topic(),
	-- 		seq = nseq,
	-- 		pld = payload,
	-- 	}

	-- 	ins.out_seq_map[nseq] = 1
	-- 	ins:publish(topic, js.encode(map))

	-- 	local res = baseclient.wait(ins.response_map, nseq, timeout)
	-- 	return res
	-- end,

	-- query = function(ins, group, karr)
	-- 	return ins:request_common("a/ac/cfgmgr/query", {group = group, karr = karr})
	-- end,

	request = function(ins, out_topic, payload, timeout)
		assert(out_topic and payload)

		local nseq
		nseq, ins.seq = ins.seq, ins.seq + 1

		local timeout = timeout or 3
		local map = {
			out_topic = out_topic,
			deadline = cursec() + timeout,
			data = {
				mod = ins.base_ins:get_topic(),
				seq = nseq,
				pld = payload,
			},
		}

		ins.out_seq_map[nseq] = 1
		ins:publish("a/ac/proxy", js.encode(map))

		local res = baseclient.wait(ins.response_map, nseq, timeout)
		return res
	end,

	set_callback = function(ins, name, func)
		assert(ins and name:find("^on_") and func)
		ins[name] = func
	end,
}

local function new()
	local unique = "a/local/cfgmgr"
	local param = {
		clientid = unique,
		topic = unique,
		port = 61886,
	}

	local ins = baseclient.new(param)

	local obj = {
		seq = 0,
		base_ins = ins,
		-- notify_arr = {},
		out_seq_map = {},
		on_message = numb,
		response_map = {},
	}
	setmetatable(obj, mt_ext)
	ins:set_callback("on_disconnect", function(...)
		log.fatal("%s", js.encode({...}))
	end)
	ins:set_callback("on_message", function(payload)
		local map = js.decode(payload)

		if not (map and map.pld) then
			return
		end

		if map.seq then
			if obj.out_seq_map[map.seq] then
				obj.response_map[map.seq], obj.out_seq_map[map.seq] = map.pld, nil
			end
			return
		end

		obj.on_message(map.pld)
	end)

	return obj
end

return {new = new}
