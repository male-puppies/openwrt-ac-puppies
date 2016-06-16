local luv = require("luv") 
---------------------------- ski --------------------------------
local yt_none, yt_self, yt_chan = 0, 1, 2
local ski_chan_map, ski_thread_map, ski_running_list = {}, {}, {}

local ski_cur_thread, yield, go, run, sleep
---------------------------- thread --------------------------------

local function wakeup_chan(th, curseq)
	if th.wait_seq == curseq then 
		-- print("match wakeup", th.wait_seq, curseq)
		return th:chan_wakeup()
	end 
	-- print("not match", th.wait_seq, curseq)
end

local thread_method = {}
local thread_mt = {__index = thread_method}

function thread_method:close()
	self.timer = nil, luv.close(self.timer) 	assert(ski_thread_map[self])
	ski_thread_map[self] = nil 		-- register in thread map 
	for chan in pairs(self.chan_map) do 
		chan:close()
	end
end

function thread_method:setdata(data)
	self.data = data 
	return self
end

function thread_method:unregister(chan)
	if self.chan_map[chan] then 
		self.chan_map[chan] = nil 
		wakeup_chan(self, chan.seq) 
	end
end

function thread_method:register(chan)
	assert(not self.chan_map[chan])
	self.chan_map[chan] = 1
end

function thread_method:clear_sig()
	local sig_type = self.sig_type
	sig_type[1], sig_type[2] = yt_none, false
end

local function yield_common(sig_type, sig)
	if sig_type[1] == yt_none then 
		assert(not sig_type[2])
		sig_type[1] = sig
		return coroutine.yield()
	end
	print("already block", sig_type[1], sig_type[2], sig)
	error("logical error")	
end

function thread_method:yield()
	return yield_common(self.sig_type, yt_self)
end

function thread_method:chan_yield()
	yield_common(self.sig_type, yt_chan)
end

local function wakeup_common(thread, sig)
	local cur_yt = thread.sig_type[1]
	if cur_yt == yt_none then
		return 
	end

	if cur_yt == sig then
		if not thread.sig_type[2] then 
			thread.sig_type[2] = true, table.insert(ski_running_list, thread) 
		end 
	end 
end

function thread_method:wakeup()
	wakeup_common(self, yt_self) 
end

function thread_method:chan_wakeup()
	wakeup_common(self, yt_chan)
end

local function new_thread(f, param)
	local thread =  {
		co = coroutine.create(f),
		timer = luv.new_timer(),
		wait_seq = 0,
		chan_map = {},
		sig_type = {yt_self, false},
		data = param,
	}
	setmetatable(thread, thread_mt)

	ski_thread_map[thread] = 1 		-- register in thread map 
	
	return thread
end

---------------------------- chan --------------------------------

local chan_method = {}
local chan_mt = {__index = chan_method}

function chan_method:read()
	if not self.active then 
		return nil, "close"
	end

	local cur = ski_cur_thread

	if not self.r then
		self.r = cur, cur:register(self) 				-- chan's first reader routine
	end 

	local r, w = self.r, self.w 	assert(r == cur) 	-- promise only one reader routine 

	local _ = w and wakeup_chan(w, self.seq) 
	if #self.list > 0 then 								
		return table.remove(self.list, 1)
	end
	
	assert(r.wait_seq == 0 and self.seq)
	r.wait_seq = self.seq
	-- print("r yield", self.seq)
	r:chan_yield() 	
	assert(r.wait_seq == self.seq)
	r.wait_seq = 0

	if not self.active then 
		return nil, "close"
	end

	local w = self.w 	assert(#self.list > 0 and w) 	-- only writer should notify

	wakeup_chan(w, self.seq) 
	return table.remove(self.list, 1)
end

function chan_method:write(d)
	if not self.active then 
		return nil, "close"
	end

	local cur = ski_cur_thread

	if not self.w then
		self.w = cur, cur:register(self) 			-- chan's first writer routine 
	end 

	local r, w = self.r, self.w 	assert(w == cur) -- promise only one writer routine

	local _ = r and wakeup_chan(r, self.seq) 
	if #self.list < self.max then
		table.insert(self.list, d)
		return true 
	end

	assert(w.wait_seq == 0 and self.seq)
	w.wait_seq = self.seq
	-- print("w yield", self.seq)
	w:chan_yield() 
	assert(w.wait_seq == self.seq)
	w.wait_seq = 0

	if not self.active then 
		return nil, "close"
	end

	local r = self.r 	assert(r) 					-- only reader should notify

	local _ = wakeup_chan(r, self.seq), table.insert(self.list, d) 
	return true
end

function chan_method:length()
	return #self.list
end

function chan_method:close()
	if not self.active then 
		return 
	end 
	
	self.active, self.max, self.list = nil, nil, nil
	local r, w = self.r, self.w 
	local _ = r and r:unregister(self)
	local _ = w and w:unregister(self)
	self.r, self.w = nil, nil
	ski_chan_map[self] = nil
end

local chanseq = 0
local function new_chan(n)
	chanseq = chanseq + 1
	local chan = {seq = chanseq, max = n, list = {}, active = true, r = nil, w = nil}
	setmetatable(chan, chan_mt)

	ski_chan_map[chan] = 1 		-- register
	
	return chan
end

---------------------------- ski --------------------------------

function go(f, ...)
	new_thread(f, {...}):wakeup()
end

local function on_debug()
	for chan in pairs(ski_chan_map) do 
		assert(chan.active)
		local r, w = chan.r, chan.w
		local _ = r and assert(r.chan_map[chan])
		local _ = w and assert(w.chan_map[chan])
	end

	for thread in pairs(ski_thread_map) do 
		assert(thread.timer)
		for chan in pairs(thread.chan_map) do 
			assert(chan.r == thread or chan.w == thread)
		end
	end 
end

function run(f, ...)
	new_thread(f, {...}):wakeup()

	local resume = function(cur)
		local co = cur.co 
		local st = coroutine.status(co)
		if st == "dead" then 
			io.stderr:write(cur, " alread dead\n")
			return cur:close()
		end 

		if st == "suspended" or st == "normal" then 
			ski_cur_thread = cur
			
			cur:clear_sig()

			local ret, err 
			if cur.data then 
				ret, err = coroutine.resume(co, unpack(cur.data))
			else 
				ret, err = coroutine.resume(co)
			end 
			
			ski_cur_thread = nil, cur:setdata()

			if not ret then  
				io.stderr:write("error ", err or "", "\n")
				os.exit(-1)
			end
		end

		local _ = coroutine.status(co) == "dead" and cur:close()
	end

	local numb = function() end 
	local empty = function(t)
		for _ in pairs(t) do 
			return false 
		end 
		return true
	end

	local prepare, imme_timer = luv.new_prepare(), luv.new_timer()
	prepare:start(function()
		if empty(ski_thread_map) then 
			local _ = on_debug(), os.exit(0)
		end

		local total = #ski_running_list
		if total == 0 then 
			return 
		end 

		for i = 1, total do
			resume(table.remove(ski_running_list, 1))
		end

		local _ = #ski_running_list > 0 and imme_timer:start(0, 0, numb)
	end)

	local debug_timer = luv.new_timer()
	debug_timer:start(10000, 10000, on_debug)

	luv.run("default")
end

function sleep(n)
	local cur = ski_cur_thread
	cur.timer:start(n * 1000, 0, function() cur:wakeup() end)
	cur:yield()
end

function yield()
	return sleep(0)
end

local function time()
	local now = luv.now()
	return now / 1000
end  


----------------------------------- above is the basic--------------------------

local function cur_thread()
	return ski_cur_thread
end

local ski ={
	go = go,
	run = run,
	time = time,
	yield = yield,
	sleep = sleep, 
	new_chan = new_chan,
	cur_thread = cur_thread,
}

return ski

