--[[
* @file : ClientMapLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Feb 13 2020 15:19:42 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端地图相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:searchresource( mode, token, rid, resourceType, resourceLevel )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:SearchResource( ClientCommon._C2S_Request, resourceType, resourceLevel ) ) )
end

function ClientLogic:SearchResource( _C2S_Request, resourceType, resourceLevel )
    return _C2S_Request( "Map_SearchResource", { resourceType = resourceType, resourceLevel = resourceLevel }, 100 )
end

function ClientLogic:searchbarbarian( mode, token, rid, level )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:SearchBarbarian( ClientCommon._C2S_Request, level ) ) )
end

function ClientLogic:SearchBarbarian( _C2S_Request, level )
    return _C2S_Request( "Map_SearchBarbarian", { level = level }, 100 )
end

function ClientLogic:movecity( mode, token, rid, type, x, y )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:MoveCity( ClientCommon._C2S_Request, type, x, y ) ) )
end

function ClientLogic:MoveCity( _C2S_Request, type, x, y )
    return _C2S_Request( "Map_MoveCity", { type = type, pos = { x = x, y = y } }, 100 )
end

function ClientLogic:addmarker( mode, token, rid, markerId, description, gameNode, x, y )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:AddMarker( ClientCommon._C2S_Request, markerId, description, gameNode, x, y ) ) )
end

function ClientLogic:AddMarker( _C2S_Request, markerId, description, gameNode, x, y )
    return _C2S_Request( "Map_AddMarker", { markerId = markerId, description = description, gameNode = gameNode, pos = { x = x, y = y } }, 100 )
end

function ClientLogic:modifymarker( mode, token, rid, markerIndex, markerId, description )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ModifyMarker( ClientCommon._C2S_Request, markerIndex, markerId, description ) ) )
end

function ClientLogic:ModifyMarker( _C2S_Request, markerIndex, markerId, description )
    return _C2S_Request( "Map_ModifyMarker", { markerIndex = markerIndex, markerId = markerId, description = description }, 100 )
end

function ClientLogic:deletemarker( mode, token, rid, markerIndex, markerId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:DeleteMarker( ClientCommon._C2S_Request, markerIndex, markerId ) ) )
end

function ClientLogic:DeleteMarker( _C2S_Request, markerIndex, markerId )
    return _C2S_Request( "Map_DeleteMarker", { markerIndex = markerIndex, markerId = markerId }, 100 )
end