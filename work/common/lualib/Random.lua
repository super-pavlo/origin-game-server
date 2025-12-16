--[[
* @file : Random.lua
* @type : lualib
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 随机函数库
* Copyright(C) 2017 IGG, All rights reserved
]]


local Random = {}

-- 此函数用法等价于math.random
-- Random.Get(m,n)
do
	-- 避免种子过小
	math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))

	function Random.Get(m, n)
		if m and n then
			return math.random(m, n)
		else
			return math.random()
		end
	end
end

-- 取得[m, n]连续范围内的k个不重复的随机数
function Random.GetRange(m, n, k)

	local t = {}
	for i = m, n do
		t[#t + 1] = i
	end

	local size = #t
	for i = 1, k do
		local x = Random.Get(i, size)
		t[i], t[x] = t[x], t[i]		-- t[i]与t[x]交换
	end

	local result = {}
	for i = 1, k do
		result[#result + 1] = t[i]
	end

	return result
end

-- 问题描述:"有N个物品,每个物品都有对应的被选中的概率,求随机选出k个物品"
-- data是一个数组,每一个元素是这样的table{ id = 0, rate = 0 }, 其中id表示物品的id,
-- rate表示物品被选中的概率.
-- 返回被选中的物品id
function Random.GetIds(t, k)
	assert(k <= #t)

	--调整rate
	local rate_left = 0
	for _,v in pairs(t) do
		rate_left = rate_left + v.rate
	end

	for i = 1, k do
		local x = Random.Get() * rate_left
		local rate = 0
		local n
		for j = i, #t do
			rate = rate + t[j].rate
			if rate >= x then
				n = j
				break
			end
		end

		t[i], t[n] = t[n], t[i]
		rate_left = rate_left - t[i].rate
	end

	local result = {}
	for i = 1, k do
		result[#result + 1] = t[i].id
	end

	return result
end

-- 问题描述:"有N个物品,每个物品都有对应的被选中的概率,求随机选出1个物品"
-- data是一个数组,每一个元素是这样的table{ id = 0, rate = 0 }, 其中id表示物品的id,
-- rate表示物品被选中的概率.所有元素的rate值加起来为1
-- 返回被选中的物品id
function Random.GetId(t)
	assert(t, "Random.GetId t is nil")
	if table.empty(t) then return end
	local ids = Random.GetIds(t, 1)
	return ids[1]
end

return Random
