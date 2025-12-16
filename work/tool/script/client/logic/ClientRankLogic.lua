--[[
* @file : ClientRankLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Jun 02 2020 19:11:42 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端排行榜相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:queryrank( mode, token, rid, type, num )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:QueryRank( ClientCommon._C2S_Request, type, num ) ) )
end

function ClientLogic:QueryRank( _C2S_Request, type, num )
    return _C2S_Request( "Rank_QueryRank", { type = type, num = num }, 100 )
end

function ClientLogic:showrankfirst( mode, token, rid, type )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ShowRankFirst( ClientCommon._C2S_Request, type ) ) )
end

function ClientLogic:ShowRankFirst( _C2S_Request, type )
    return _C2S_Request( "Rank_ShowRankFirst", { type = type }, 100 )
end