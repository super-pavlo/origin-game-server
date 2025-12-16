--[[
* @file : MultiSnax.lua
* @type : service
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 多snax服务管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]
local skynet = require "skynet"
local snax = require "skynet.snax"
local sharedata = require "skynet.sharedata"
local multiSnax = {}
local queue = require "skynet.queue"
local multiSnaxNum
local lock

function init()
    multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM --默认DEFUALT_SNAX_SERVICE_NUM个子服务
    sharedata.new( Enum.Share.MultiSnaxNum, { num = multiSnaxNum } )
    lock = queue()
end

local function getOrNewMultiSnaxService( name )
    if not multiSnax[name] or table.empty(multiSnax[name]) then
        multiSnax[name] = {}
        for i = 1, multiSnaxNum do
            table.insert(multiSnax[name], assert(snax.newservice(name, i)))
        end
    end
    return multiSnax[name]
end

function response.getOrNew(name)
    if name == "RedisAgent" then
        return lock(getOrNewMultiSnaxService, name)
    end

    local cmd = { "SETNX", string.format("multisnax_%s", name), 1 }
    while Common.redisExecute(cmd) == 0 do
        skynet.sleep(1)
    end

    -- 30s time out
    Common.redisExecute( { "EXPIRE", string.format("multisnax_%s", name), 30 } )
    local ret, err = xpcall(getOrNewMultiSnaxService, debug.traceback, name)
    if not ret then
        LOG_ERROR("MultiSnax getOrNew error:%s", err)
    end
    Common.redisExecute( { "DEL", string.format("multisnax_%s", name) } )
    return err
end