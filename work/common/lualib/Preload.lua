--[[
* @file : Preload.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 11:01:01 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 预加载文件,所有的服务启动时,均会执行此文件
* Copyright(C) 2017 IGG, All rights reserved
]]

require "skynet.manager"
local snax = require "skynet.snax"

enum = function ( t )
    return setmetatable(t, {
        __index = function ( _, key)
            return error(string.format("read-only table, attempt to a no-exist key! key(%s)", tostring(key)), 2)
        end,

        __newindex = function ( _, key, value )
            error(string.format(" read-only table, invalid to new attempt! key(%s), value(%s)",
                                tostring(key), tostring(value)), 2)
        end
    })
end
const = enum

require "LuaExt"
require "LogDefine"
Common = require "Common"
require "ErrorCode"

--获取保存SM的元表, server 不存在时，会自动 uniqueservice
SM = setmetatable(
    {}, {
        __index = function(self, key)
            local obj = snax.uniqueservice(key)
            rawset( self, key, obj )
            return obj
        end
    }
)

--获取保存MSM的元表,server 不存在时，会自动 new snax service，并保存到 MultiSnax 服务中
MSM = setmetatable(
    {}, {
        __index = function(self, key)
            local multiSnaxs = SM.MultiSnax.req.getOrNew(key)
            assert(multiSnaxs and type(multiSnaxs) == "table" and #multiSnaxs > 0, key .. "->" .. tostring(multiSnaxs))

            --需要重新snax.bind，服务间传输会导致 matatable 丢失
            for k,v in pairs(multiSnaxs) do
                multiSnaxs[k] = snax.bind(v.handle, v.type)
            end

            setmetatable(
                multiSnaxs,
                {
                    __index = function(mself, mkey)
                        if type(mkey) ~= "number" then
                            error(string.format("invalid key type, must be number->%s:%s",
                                        tostring(mkey), type(mkey)), 2)
                        end

                        return mself[mkey % #mself + 1]
                    end
                }
            )
            rawset( self, key, multiSnaxs )
            return multiSnaxs
        end
    }
)

--获取配置表CFG
local function CfGet( self, key, fields )
    if not key then
        return self
    elseif not fields then
        return self[key]
    elseif type(fields) == "table" then
        local ret = {}
        for _,filed in pairs(fields) do
            if self[key] then
                ret[filed] = self[key][filed]
            end
        end
        return ret
    elseif type(fields) == "string" then
        if self[key] then
            return self[key][fields]
        end
    end
end

local function getCfMetaTable()
    return setmetatable({}, {
        __index = function ( self, name )
            local sharedata = require "skynet.sharedata"
            local shareObj = sharedata.query( name )
            assert(shareObj, "not found " .. name .. " Config Table")
            getmetatable(shareObj).__newindex = nil
            shareObj.Get = CfGet
            return shareObj
        end
    })
end
CFG = getCfMetaTable()

local function getEnumMetaTable()
    return setmetatable({}, {
        __index = function ( self, name )
            local sharedata = require "skynet.sharedata"
            local shareObj = sharedata.query( "Enum-"..name )
            assert(shareObj, "not found " .. name .. " Enum Define")
            local copyObj = shareObj.enumValue
            if type(shareObj.enumValue) == "table" then
                copyObj = table.copy(shareObj.enumValue, true)
                copyObj = enum(copyObj)
            end
            self[name] = copyObj
            return copyObj
        end
    })
end
---@type EnumClass
Enum = getEnumMetaTable()

local skynet = require("skynet")
if skynet.self() > 10 then
    if SERVICE_NAME ~= "sharedatad" then
        require "skynet.sharedata"
    end

    if SERVICE_NAME ~= "clusterd" then
        require "skynet.cluster"
    end
end

-- 限制单个VM的内存(1024M)
if skynet.getenv("clusternode") == "game" then
    skynet.memlimit(1024 * 1024 * 1024)
end