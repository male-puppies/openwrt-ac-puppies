-- 数组arr中是否包含元素expect
local function contains(arr, expect)
	for _, v in ipairs(arr) do
		if v == expect then
			return true
		end
	end
	return false
end

-- 表t中是否包含表other中任意一个元素
-- @param t : 源表，可以是arr，也可以是map，但是不能混合
-- @param other ：可以是arr，也可以是map
-- @return ：t中是否含表other中任意一个元素
local function contains_any(t, other)
	-- {"a", "b", "c"}, {"a"}			-> {a = 1, b = 1, c = 1}, {"a"}
	-- {"a", "b", "c"}, {a = 1}			-> {a = 1, b = 1, c = 1}, {a = 1}
	-- {a = 1, b = 1, c = 1}, {"a"}
	-- {a = 1, b = 1, c = 1}, {a = 1}
	local c1, c2, ma_tmp = #t, #other, t
	if c1 > 0 then
		ma_tmp = {}
		for _, v in ipairs(t) do
			ma_tmp[v] = v
		end
	end

	if c2 == 0 then
		for k in pairs(other) do
			if ma_tmp[k] then
				return true
			end
		end
		return false
	end

	for _, k in ipairs(other) do
		if ma_tmp[k] then
			return true
		end
	end

	return false
end

-- 把arr转换为map
-- @param arr : 数组，形如{{$k = "key1", ...}, {$k = "key2", ...}}
-- @param k ：如果k为空，则以value为key；如果k不为空，数组元素中的字段，每个元素都必须包含
-- @return ：map
local function tomap(arr, k)
	local m = {}
	if not k then
		for _, v in ipairs(arr) do
			m[v] = 1
		end
		return m
	end

	for _, v in ipairs(arr) do
		m[v[k]] = v
	end

	return m
end

-- 把table根据传入函数f进行转换
-- @param t ：输入table
-- @param f ：转换函数，后接f的参数列表
-- @return ：转换后的table，key和原table一样，值不一样
local function map(t, f, ...)
	local m = {}
	for k, v in pairs(t) do
		m[k] = f(k, v, ...)
	end
	return m
end

-- 每次取table的value部分，使用转换函数f进行运算，总结结果可以存放在state
-- @param t : 可以是arr，也可以是map
-- @param f ：每个k-v对的value部分，会调用f(state, v)
-- @param state ：中间结果，如果是nil，由t的第一个元素填充
-- @return state ：state作为最后结果返回
local function reduce(t, f, state)
	for _, v in pairs(t) do
		state = state and f(state, v) or v
	end
	return state
end

-- 每次取table的key和value部分，使用转换函数f进行运算，总结结果可以存放在state
-- @param t : 可以是arr，也可以是map
-- @param f ：f(k, v, state)
-- @param state ：中间结果，如果是nil，由t的第一个元素填充
-- @return state ：state作为最后结果返回
local function reduce2(t, f, state)
	for k, v in pairs(t) do
		state = state and f(state, k, v) or v
	end
	return state
end

-- 对t中的每个k-v对，调用函数f
-- @param t ：可以是arr，也可以是map
-- @param f ：k-v对的处理函数
local function each(t, f, ...)
	for k, v in pairs(t) do
		f(k, v, ...)
	end
end

-- 对arr中的每个元素，调用函数f
-- @param t ：arr
-- @param f ：处理函数
local function eachi(t, f, ...)
	for k, v in ipairs(t) do
		f(k, v, ...)
	end
end

-- 计算t的元素个数，如果expect不为空，则计算t中值为expect的元素个数
-- @param t ：arr or map
-- @param expect ：可以为空，不为空时，计算t中值为expect的元素个数
-- @return ：符合条件的元素个数
local function count(t, expect)
	local cnt = 0
	if not expect then
		for _ in pairs(t) do
			cnt = cnt + 1
		end
		return cnt
	end

	for _, v in pairs(t) do
		if v == expect then
			cnt = cnt + 1
		end
	end
	return cnt
end

-- 计算t中符合条件的元素个数，其中f为过滤函数
-- @param t ：arr or map
-- @param f ：过滤函数，如果f(k, v, ...)为真，则为符合条件的元素
-- @return ：符合条件的元素个数
local function countf(t, f, ...)
	local cnt = 0
	for k, v in pairs(t) do
		if f(k, v, ...) then
			cnt = cnt + 1
		end
	end
	return cnt
end

-- t是否为空表。如果f不为空，以f(k, v)的结果作为过滤条件
local function empty(t, f)
	if not f then
		for k in pairs(t) do
			return false
		end
		return true
	end

	for k, v in pairs(t) do
		if f(k, v) then
			return false
		end
	end
	return true
end

-- 把表t转换为数组。会丢失map的key部分
local function toarr(t)
	local arr = {}
	for k, v in pairs(t) do
		table.insert(arr, v)
	end
	return arr
end

-- 返回表t的key部分，以数组的方式
local function keys(t)
	local ks = {}
	for k in pairs(t) do
		table.insert(ks, k)
	end
	return ks
end

-- 返回表t的value部分，以数组的方式
local function values(t)
	local vs = {}
	for _, v in pairs(t) do
		table.insert(vs, v)
	end
	return vs
end

-- 过滤表t中的元素，其中f是过滤函数，不做值的转换
local function filter(t, f, ...)
	local m = {}
	for k, v in pairs(t) do
		if f(k, v, ...) then
			m[k] = v
		end
	end
	return m
end

local same_aux
function same_aux(a, b)
	for k, v1 in pairs(a) do
		local v2 = b[k]
		if v1 ~= v2 then
			if not (type(v1) == "table" and type(v2) == "table") then
				return false
			end
			return same_aux(v1, v2)
		end
	end
	return true
end

-- 表t1,t2的内容是否一样。t可以是多层表
local function same(t1, t2)
	return same_aux(t1, t2) and same_aux(t2, t1)
end

return {
	map 			= map,
	filter 			= filter,
	each 			= each,
	eachi 			= eachi,
	count 			= count,
	countf 			= countf,
	empty 			= empty,
	emptyf 			= emptyf,
	reduce			= reduce,
	reduce2 		= reduce2,
	tomap 			= tomap,
	toarr 			= toarr,
	keys 			= keys,
	values 			= values,
	same 			= same,
	contains 		= contains,
	contains_any 	= contains_any,
}





