--[[
* @file : ClientTransportLogic.lua
* @type : lualib
* @author : chenlei
* @created : Mon May 11 2020 18:22:26 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端商栈相关
* Copyright(C) 2017 IGG, All rights reserved
]]
local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:transportBack( mode, token, rid, objectIndex )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:TransportBack( ClientCommon._C2S_Request, objectIndex ) ) )
end

function ClientLogic:TransportBack( _C2S_Request, objectIndex )
    return _C2S_Request( "Transport_TransportBack", { objectIndex = objectIndex }, 100 )
end

function ClientLogic:createTransport( mode, token, rid, targetRid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:CreateTransport( ClientCommon._C2S_Request, targetRid ) ) )
end

function ClientLogic:CreateTransport( _C2S_Request, targetRid )
    local transportResourceInfo = {}
    table.insert(transportResourceInfo, { resourceTypeId = 100, load = 3000000 } )
    return _C2S_Request( "Transport_CreateTransport", { targetRid = targetRid, transportResourceInfo = transportResourceInfo }, 100 )
end