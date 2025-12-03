--[[
* @file : ClientTechnologyLogic.lua
* @type : lualib
* @author : chenlei
* @created : Wed Jan 15 2020 15:19:39 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端科技相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:researchTechnology( mode, token, rid, technologyType, immediately )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ResearchTechnology( ClientCommon._C2S_Request, technologyType, immediately ) ) )
end

function ClientLogic:rwardTechnology( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:AwardTechnology( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:stopTechnology( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:StopTechnology( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:StopTechnology( _C2S_Request )
    return _C2S_Request( "Technology_StopTechnology", {}, 100 )
end

function ClientLogic:AwardTechnology( _C2S_Request )
    return _C2S_Request( "Technology_AwardTechnology", {}, 100 )
end

function ClientLogic:ResearchTechnology( _C2S_Request, _technologyType, _immediately )
    local flag = false
    if tonumber(_immediately) == 1 then
        flag = true
    end
    return _C2S_Request( "Technology_ResearchTechnology", { technologyType = _technologyType, immediately = flag }, 100 )
end


