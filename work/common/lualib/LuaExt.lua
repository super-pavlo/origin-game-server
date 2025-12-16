--[[
* @file : LuaExt.lua
* @type : lualib
* @author : linfeng
* @created : Wed Nov 22 2017 10:49:55 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : lua 拓展
* Copyright(C) 2017 IGG, All rights reserved
]]

-- table扩展
-- 返回table大小
table.size = function(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- 判断table是否为空
table.empty = function(t)
    if type(t) ~= "table" then return true end
    for _ in pairs(t) do
        return false
    end
    return true
end

-- 返回table索引列表
table.indexs = function(t)
    local result = {}
    for k, _ in pairs(t) do
        table.insert(result, k)
    end
    return result
end

-- 返回table值列表
table.values = function(t)
    local result = {}
    for _, v in pairs(t) do
        table.insert(result, v)
    end
    return result
end

table.valuestring = function( t, delim )
    local result
    for _, v in pairs(t) do
        if not result then
            result = v
        else
            result = result .. delim .. v
        end
    end

    return result
end

table.keystring = function( t, delim )
    local result
    for v in pairs(t) do
        if not result then
            result = v
        else
            result = result .. delim .. v
        end
    end

    return result
end

table.kv = function ( t, delim )
    local result = ""
    for k,v in pairs(t) do
        result = result .. delim .. k .. delim .. v
    end

    return string.trim(result)
end

-- 浅拷贝
table.clone = function(t, nometa)
    local result = {}
    if not nometa then
        setmetatable(result, getmetatable(t))
    end
    for k, v in pairs (t) do
        result[k] = v
    end
    return result
end

-- 深拷贝
table.copy = function(t, nometa)
    if not t then return end
    local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = table.copy(v, nometa)
        else
            result[k] = v
        end
    end

    if not nometa then
        setmetatable(result, getmetatable(t))
    end

    return result
end

table.first = function ( t )
    for k,v in pairs(t) do
        return { key = k, value = v }
    end
end

table.load = function(lua)
    local t = type(lua)
    if t == "nil" or lua == "" then
        return nil
    elseif t == "number" or t == "string" or t == "boolean" then
        lua = tostring(lua)
    else
        error("can not unserialize a " .. t .. " type.")
    end
    lua = "return " .. lua
    local func = load(lua)
    if func == nil then
        return nil
    end
    return func()
end

table.tonumber = function ( tb )
    for k,v in pairs(tb) do
		tb[k] = tonumber(v) or v
	end
end

table.keytostring = function ( tb )
    local retTb = {}
    for k,v in pairs(tb) do
        if type(v) == "table" then
            v = table.keytostring(v)
        end
        retTb[tostring(k) or k] = v
    end
    return retTb
end

table.keytonumber = function ( tb )
    local retTb = {}
    for k,v in pairs(tb) do
        if type(v) == "table" then
            v = table.keytonumber(v)
        end
        retTb[tonumber(k) or k] = v
    end
    return retTb
end

table.value = function ( t, index )
    local i = 1
    for _,v in pairs(t) do
        if i == index then
            return v
        end
        i = i + 1
    end
end

table.valuetostring = function ( tb )
    local retTb = {}
    for k,v in pairs(tb) do
        if type(v) == "table" then
            v = table.valuetostring(v)
        end
        retTb[k] = tostring(v) or v
    end
    return retTb
end

table.topair = function ( t )
    assert(type(t) == "table" and #t % 2 == 0)
	local ret = {}
	for i=1,#t,2 do
		ret[t[i]] = tonumber(t[i+1]) or t[i+1]
	end
	return ret
end

table.toipair = function ( t )
    assert(type(t) == "table" and #t % 2 == 0)
	local ret = {}
	for i=1,#t,2 do
		ret[tonumber(t[i])] = t[i+1]
	end
	return ret
end

table.removevalue = function ( t, value )
    if type(t) ~= "table" then return end
    for k,v in pairs(t) do
        if v == value then table.remove(t, k) return end
    end
end

table.exist = function ( t, value )
    if type(value) ~= "table" then
        for _,v in pairs(t) do
            if v == value then return true end
        end
    else
        for _, subValue in pairs(value) do
            if table.exist( t, subValue ) then
                return true
            end
        end
    end
end

table.merge = function ( t, mt )
    for _,v in pairs(mt) do
        table.insert( t, v )
    end
end

table.mergeEx = function ( t, mt )
    for k,v in pairs(mt) do
        t[k] = v
    end
end

table.exist = function ( t, value )
    for _,v in pairs(t) do
        if v == value then return true end
    end
end

table.tointeger = function ( t )
    for k,v in pairs(t) do
        if type(v) == "table" then
            table.tointeger(v)
        elseif type(v) == "number" then
            t[k] = math.floor(t[k])
        end
    end
end

--print 拓展
do
    local _print = print

    print = function ( ... )
        local info = debug.getinfo(2)

        _print("\x1B[37m".. info.short_src .. ":" ..  info.currentline .. "\x1B[0m")
        local out = { ... }
        if #out > 1 then
            for key, value in pairs(out) do
                if type(value) == "table" then
                    out[key] = tostring(value)
                end
            end
            _print(table.unpack(out))
        else
            if type(...) == "table" then
                _print(tostring(...))
            else
                _print(...)
            end
        end
    end
end

-- string扩展
do
    local mt = getmetatable("")
    -- 下标运算
    local _index = mt.__index
    mt.__index = function (s, ...)
        local k = ...
        if "number" == type(k) then
            return _index.sub(s, k, k)
        else
            return _index[k]
        end
    end

    --和 number 对比拓展
    local _lt = mt.__lt
    mt.__lt = function (a,b)
        assert(type(a) == type(b), "different type __lt")
        return _lt(a,b)
    end

    local _le = mt.__le
    mt.__le = function (a,b)
        assert(type(a) == type(b), "different type __le")
        return _le(a,b)
    end
end


local function Split(s, delim)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
        local nFindLastIndex = string.find(s, delim, nFindStartIndex)
        if not nFindLastIndex then
            nSplitArray[nSplitIndex] = string.sub(s, nFindStartIndex, string.len(s))
            break
        end
        nSplitArray[nSplitIndex] = string.sub(s, nFindStartIndex, nFindLastIndex - 1)
        nFindStartIndex = nFindLastIndex + string.len(delim)
        nSplitIndex = nSplitIndex + 1
    end

    return nSplitArray
end

string.split = function(s, delim, number)
    local split = {}
    if delim:len() == 1 then
        local pattern = "[^" .. delim .. "]*"
        string.gsub(s, pattern, function(v)
                                            if number then
                                                v = tonumber(v) or v
                                            end
                                            table.insert(split, v)
                                end
                )
    else
        split = Split(s, delim)
    end
    return split
end

string.ltrim = function(s, pattern)
    pattern = pattern or "%s"
    return (string.gsub(s, "^" .. pattern .. "+", ""))
end

string.rtrim = function(s, pattern)
    pattern = pattern or "%s"
    return (string.gsub(s, pattern .. "+" .. "$", ""))
end

string.trim = function(s, pattern)
    return string.rtrim(string.ltrim(s, pattern), pattern)
end

string.repeated = function( delim, num, value )
    local ret
    for _=1,num do
        if not ret then
            ret = value
        else
            ret = ret .. delim .. value
        end
    end

    return ret
end

string.startWith = function ( str, substr )
    return str:find(substr) == 1
end

string.endWith = function ( str, substr )
    local strTmp = string.reverse(str)
    local substrTmp = string.reverse(substr)
    return strTmp:find(substrTmp) == 1
end

string.hexByte = function ( str )
    local retHex = ""
    for i = 1, str:len() do
        retHex = retHex .. " " .. string.format("%x", string.byte( str, i ) )
    end
    return retHex
end

local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

do
    local _tostring = tostring
    tostring =function(v)
        if type(v) == 'table' then
            return dump(v)
        else
            return _tostring(v)
        end
    end
end

-- math扩展
do
	local _floor = math.floor
	math.floor = function(n, p)
		if p and p ~= 0 then
			local e = 10 ^ p
			return _floor(n * e) / e
		else
			return _floor(n)
		end
	end
end

math.round = function(n, p)
        local e = 10 ^ (p or 0)
        return math.floor(n * e + 0.5) / e
end

math.getPreciseDecimal = function (nNum, n)
    if type(nNum) ~= "number" then
        return nNum
    end
    n = n or 0
    n = math.floor(n)
    if n < 0 then
        n = 0
    end
    local nDecimal = 10 ^ n
    local nTemp = math.floor(nNum * nDecimal)
    local nRet = nTemp / nDecimal
    return nRet
end

-- lua面向对象扩展
local _class={}

function class(super)
    local class_type={}
    class_type.ctor=false
    class_type.super=super
    class_type.new=function(...)
            local obj={}
            do
                local create
                create = function(c,...)
                    if c.super then
                        create(c.super,...)
                    end
                    if c.ctor then
                        c.ctor(obj,...)
                    end
                end

                create(class_type,...)
            end
            setmetatable(obj,{ __index=_class[class_type] })
            return obj
        end
    local vtbl={}
    _class[class_type]=vtbl

    setmetatable(class_type,{__newindex=
        function(t,k,v)
            vtbl[k]=v
        end
    })

    if super then
        setmetatable(vtbl,{__index=
            function(t,k)
                local ret=_class[super][k]
                vtbl[k]=ret
                return ret
            end
        })
    end

    return class_type
end
