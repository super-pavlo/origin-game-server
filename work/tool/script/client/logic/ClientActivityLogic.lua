--[[
* @file : ClientActivityLogic.lua
* @type : lualib
* @author : chenlei
* @created : Fri Apr 17 2020 17:14:57 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 活动客户端
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"


function ClientLogic:receiveReward( mode, token, rid, activityId, id )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ReceiveReward( ClientCommon._C2S_Request, activityId, id ) ) )
end

function ClientLogic:ReceiveReward( _C2S_Request, activityId, id )
    return _C2S_Request( "Activity_ReceiveReward", {
        activityId = activityId, id = id
    }, 100 )
end

function ClientLogic:getRank( mode, token, rid, type, activityId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetRank( ClientCommon._C2S_Request, type, activityId ) ) )
end

function ClientLogic:GetRank( _C2S_Request, type, activityId )
    return _C2S_Request( "Activity_GetRank", { type = type, activityId = activityId }, 100 )
end

function ClientLogic:expeditionChallenge( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ExpeditionChallenge( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:ExpeditionChallenge( _C2S_Request )
    local id = 1
    local troops = {}
    local soldiers = {}
    soldiers[10101] = { num = 1000, type = 1, id = 10101, level = 1}
    troops[1] = { mainHeroId = 1001, soldiers = soldiers }
    return _C2S_Request( "Expedition_ExpeditionChallenge", { id = id, troops = troops }, 100 )
end

function ClientLogic:getSelfRank( mode, token, rid, activityId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetSelfRank( ClientCommon._C2S_Request, activityId ) ) )
end

function ClientLogic:GetSelfRank( _C2S_Request, activityId )
    return _C2S_Request( "Activity_GetSelfRank", { activityId = activityId }, 100 )
end