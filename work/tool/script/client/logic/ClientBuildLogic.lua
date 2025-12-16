--[[
* @file : ClientBuildLogic.lua
* @type : lualib
* @author : chenlei
* @created : Mon Jan 06 2020 15:31:39 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端建筑相关
* Copyright(C) 2017 IGG, All rights reserved
]]


local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:createBuilding( mode, token, rid, type, x, y )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:CreateBuilding( ClientCommon._C2S_Request, type, x, y ) ) )
end

function ClientLogic:upGradeBuilding( mode, token, rid, buildingIndex, immediately )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:UpGradeBuilding( ClientCommon._C2S_Request, buildingIndex, immediately ) ) )
end

function ClientLogic:endBuilding( mode, token, rid, buildingIndex )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:EndBuilding( ClientCommon._C2S_Request, buildingIndex ) ) )
end

function ClientLogic:removeBuilding( mode, token, rid, buildingIndex, x, y )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RemoveBuilding( ClientCommon._C2S_Request, buildingIndex, x, y ) ) )
end

function ClientLogic:tavern( mode, token, rid, type, free, count )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Tavern( ClientCommon._C2S_Request, type, free, count  ) ) )
end

function ClientLogic:Tavern( _C2S_Request, _type, _free, _count  )
    if tonumber(_free) == 1 then
        _free = true
    else
        _free = false
    end
    return _C2S_Request( "Build_Tavern", { type = _type, free = _free, count = _count }, 100 )
end

function ClientLogic:RemoveBuilding( _C2S_Request, _buildingIndex, _x, _y )
    return _C2S_Request( "Build_RemoveBuilding", { buildingIndexs = _buildingIndex, pos = { x = _x, y = _y } }, 100 )
end

function ClientLogic:EndBuilding( _C2S_Request, _buildingIndex )
    return _C2S_Request( "Build_EndBuilding", { buildingIndex = _buildingIndex }, 100 )
end

function ClientLogic:UpGradeBuilding( _C2S_Request, _buildingIndex, _immediately )
    return _C2S_Request( "Build_UpGradeBuilding", { buildingIndex = _buildingIndex, immediately = _immediately == 1}, 100 )
end

function ClientLogic:CreateBuilding( _C2S_Request, _type, _x, _y )
    return _C2S_Request( "Build_CreateBuilding", { type = _type, pos = { x = _x, y = _y } }, 100 )
end

function ClientLogic:extinguishing( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Extinguishing( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:Extinguishing( _C2S_Request  )
    return _C2S_Request( "Build_Extinguishing", {}, 100 )
end

function ClientLogic:service( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Service( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:Service( _C2S_Request  )
    return _C2S_Request( "Build_Service", {}, 100 )
end

function ClientLogic:defendHero( mode, token, rid, mainHeroId, deputyHeroId )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:DefendHero( ClientCommon._C2S_Request, mainHeroId, deputyHeroId ) ) )
end

function ClientLogic:DefendHero( _C2S_Request, mainHeroId, deputyHeroId )
    return _C2S_Request( "Build_DefendHero", { mainHeroId = mainHeroId, deputyHeroId = deputyHeroId }, 100 )
end