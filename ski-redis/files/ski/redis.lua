-- yjs

local ski = require("ski")
local tcp = require("ski.tcp")

local buf_method = {}
local buf_mt = {__index = buf_method}

-- 按size把data分成两段，如果data长度不够，返回nil
function take(data, size)
	if #data < size then
		return
	end

	return data:sub(1, size), data:sub(size + 1)
end

-- 读取size个字符
function buf_method:read(size)
	local data, left = take(self.data, size)
	if data then
		self.data = left
		return data
	end

	while true do
		local s, e = self.cli:read2()
		if not s then
			return nil, e
		end

		self.data = self.data .. s

		data, left = take(self.data, size)
		if data then
			self.data = left
			return data
		end
	end
end

-- 读取直到遇到sub
function buf_method:read_until(sub)
	local data
	while true do
		data = self.data
		if #data >= #sub then
			local sp, ep = data:find(sub)
			if sp then
				local s, left = take(data, ep)
				self.data = left
				return s
			end
		end

		local s, e = self.cli:read2()
		if not s then
			return nil, e
		end

		self.data = self.data .. s
	end
end

local function buf_new(cli)
	return setmetatable({cli = cli, data = ""}, buf_mt)
end

-----------------------------------------------------

local method = {}
local mt = {__index = method}
local read_obj

-- 读取一个数字
local function read_number(reader)
	local s, e = reader:read_until('\r\n')
	if not s then
		return nil, e
	end

	local number = tonumber(s:sub(1, -3))
	if not number then
		return nil, 'redis error, bad number: ' .. s
	end

	return number
end

-- 连接redis服务器
function method:connect(host, port)
	local cli, e = tcp.connect(host, port)
	if not cli then
		return nil, e
	end

	self.cli, self.reader = cli, buf_new(cli)

	return true
end

function method:close()
	if not self.cli then
		return
	end

	self.cli:close()
	self.cli, self.data = nil
end

local reply_map = {}

-- (+) 表示一个正确的状态信息，具体信息是当前行+后面的字符。
reply_map["+"] = function(reader)
	local s, e = reader:read_until("\r\n")
	if not s then
		return nil, e
	end

	return {ok = s:sub(1, -3)}
end

-- (-)  表示一个错误信息，具体信息是当前行－后面的字符。
reply_map["-"] = function(reader)
	local s, e = reader:read_until('\r\n')
	if not s then
		return nil, e
	end

	return {err = s:sub(1, -3)}
end

-- (:) 表示返回一个数值，：后面是相应的数字节符。
reply_map[":"] = function(reader)
	return read_number(reader)
end

-- ($) 表示下一行数据长度，不包括换行符长度\r\n,$后面则是对应的长度的数据。
reply_map["$"] = function(reader)
	local len, e = read_number(reader)
	if not len then
		return nil, e
	end

	if len < 0 then
		return false
	end

	local s, e = reader:read(len + 2)
	if not s then
		return nil, e
	end

	if s:sub(-2) ~= "\r\n" then
		return nil, 'redis error, bad string: ' .. s
	end

	return s:sub(1, -3)
end

-- (*) 表示消息体总共有多少行，不包括当前行,*后面是具体的行数。
reply_map["*"] = function(reader)
	local len, e = read_number(reader)
	if not len then
		return nil, e
	end

	if len < 0 then
		return false
	end

	local arr = {}
	for i = 1, len do
		local obj, e = read_obj(reader)
		if not obj then
			return nil, e
		end
		table.insert(arr, obj)
	end

	return arr
end

function read_obj(reader)
	local c, e = reader:read(1)
	if not c then
		return nil, e
	end

	local f = reply_map[c]
	if not f then
		return nil, "invalid reply type " .. c
	end

	return f(reader)
end

-- 编码
local function format_command(args)
	local arr = {}
	table.insert(arr, string.format('*%d\r\n', #args))
	for _, arg in ipairs(args) do
		arg = tostring(arg)
		table.insert(arr, string.format('$%d\r\n%s\r\n', #arg, arg))
	end
	return table.concat(arr)
end

function method:call(...)
	local s = format_command({...})

	local cli = self.cli
	local r, e = cli:write(s)
	if not r then
		self:close()
		return nil, e
	end

	local r, e = read_obj(self.reader)
	if not r then
		self:close()
		return nil, e
	end

	return r
end

local function new()
	return setmetatable({cli = nil, reader = nil}, mt)
end

return {new = new}