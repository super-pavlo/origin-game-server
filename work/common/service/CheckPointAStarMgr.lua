--[[
* @file : CheckPointAStarMgr.lua
* @type : multi snax service
* @author : chenlei
* @created : Wed Jul 01 2020 16:55:15 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 关卡A*寻路管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local sharedata = require "skynet.sharedata"
local CheckPointAstarLogic = require "CheckPointAstarLogic"
local MapProvinceLogic = require "MapProvinceLogic"
local RoleLogic = require "RoleLogic"
local MapLogic = require "MapLogic"
local GuildLogic = require "GuildLogic"
---@see AStar寻路指针
local astarSearchPtr

---@see 初始化AStar寻路地图
---@param _blockMap table
--[[
    local _blockMap = {
        0, 1, 0, 0, 0,
        0, 0, 0, 1, 0,
        1, 1, 1, 1, 0,
        0, 0, 0, 1, 0,
        0, 1, 0, 0, 0,
    }
]]

function init( index )
    local holyLands = SM.c_holy_land.req.Get()
    local levelPass = {}
    for holyLandId, info in pairs( holyLands ) do
        local holyLandType = CFG.s_StrongHoldData:Get( holyLandId, "type" )
        if holyLandType == Enum.HolyLandType.CHECKPOINT_LEVEL_1 or holyLandType == Enum.HolyLandType.CHECKPOINT_LEVEL_2
            or holyLandType == Enum.HolyLandType.CHECKPOINT_LEVEL_3 then
            if info.guildId and info.guildId > 0 and not GuildLogic:checkGuild( info.guildId ) then
                info.guildId = 0
            end
            levelPass[holyLandId] = { guildId = info.guildId or 0, id = 0 }
        end
    end
    local sMapBarrierConnect = CFG.s_MapBarrierConnect:Get()
    local blockMap = {}
    for _, mapBarrierConnect in pairs(sMapBarrierConnect) do
        if mapBarrierConnect.checkPointId > 0 then
            if levelPass[mapBarrierConnect.checkPointId] then
                levelPass[mapBarrierConnect.checkPointId].id = mapBarrierConnect.ID
                table.insert( blockMap, mapBarrierConnect.checkPointId )
            else
                LOG_ERROR("CheckPointAStarMgr not found checkPointId(%s) holyLands(%s)", tostring(mapBarrierConnect.checkPointId), tostring(holyLands))
            end
        else
            table.insert( blockMap, mapBarrierConnect.isWalk )
        end
    end
    if index == 1 then
        sharedata.new( Enum.Share.LevelPass, levelPass )
    end
    CheckPointAstarLogic:setMapInfo( blockMap, CFG.s_Config:Get("mapConnectLength"), CFG.s_Config:Get("mapConnectHight") )
    -- 生成寻路地图
    astarSearchPtr = CheckPointAstarLogic:newAStarMap( astarSearchPtr, CFG.s_Config:Get("mapConnectLength"), CFG.s_Config:Get("mapConnectHight") )
    --snax.self().req.InitSearchMap( blockMap, CFG.s_Config:Get("mapConnectLength"), CFG.s_Config:Get("mapConnectHight") )

end

function response.Init()

end

---@param _width integer 地图宽
---@param _height integer 地图高
function response.InitSearchMap( _blockMap, _width, _height )
    -- 设置地图信息
    CheckPointAstarLogic:setMapInfo(  _blockMap, _width, _height )
    -- 生成寻路地图
    CheckPointAstarLogic:newAStarMap( astarSearchPtr, _width, _height )
end

---@see 判断两点是否连接
function response.findPath( _rid, _spos, _epos, _openAll )
    if not astarSearchPtr then
        return false
    end
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    local ids = {}
    local noPass = {}
    local levelPass = sharedata.query( Enum.Share.LevelPass )
    for _, levelPassInfo in pairs(levelPass) do
        if _openAll then
            table.insert( ids, levelPassInfo.id )
        else
            if guildId > 0 and levelPassInfo.guildId and levelPassInfo.guildId > 0 and guildId == levelPassInfo.guildId then
                table.insert( ids, levelPassInfo.id )
            else
                table.insert( noPass, levelPassInfo.id )
            end
        end
    end
    CheckPointAstarLogic:setWalkable( astarSearchPtr, ids, 1 )
    CheckPointAstarLogic:setWalkable( astarSearchPtr, noPass, 0 )

    -- 判断两点的省份
    local sProvince, sMapZoneSF = MapProvinceLogic:getPosInProvince( _spos )
    local eProvince, eMapZoneSF = MapProvinceLogic:getPosInProvince( _epos )
    if eProvince == 0 or sProvince == eProvince then
        return noPass
    end
    -- local provicePosInfo = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.CHECK_POINT_POS)
    -- local sProvinceCenter = provicePosInfo[sProvince]
    -- local eProvinceCenter = provicePosInfo[eProvince]
    local sTopZoneID = sMapZoneSF.topZoneID
    local eTopZoneID = eMapZoneSF.topZoneID
    local mapConnectLength = CFG.s_Config:Get( "mapConnectLength" )

    local sy = math.modf((sTopZoneID - 1) / mapConnectLength) // 1
    local sx = math.fmod((sTopZoneID - 1), mapConnectLength) // 1
    local ey = math.modf((eTopZoneID - 1) / mapConnectLength) // 1
    local ex = math.fmod((eTopZoneID - 1), mapConnectLength) // 1

    local path, pathCount = astarSearchPtr:path( sx, sy, ex, ey )
    if pathCount > 0 then
        local sMapBarrierConnect = CFG.s_MapBarrierConnect:Get()
        local pass = {}
        for _, pathInfo in pairs(path) do
            local id = pathInfo[1] + pathInfo[2] * CFG.s_Config:Get("mapConnectLength") + 1
            if sMapBarrierConnect[id].checkPointId > 0 then
                table.insert( pass, sMapBarrierConnect[id].checkPointId )
            end
        end
        return pass
    end
end

---@see 设置点不可行走
function response.setUnwalkable( _pos )
    CheckPointAstarLogic:setWalkable( astarSearchPtr, _pos, 0 )
end

---@see 设置点可行走
function response.setWalkable( _pos )
    CheckPointAstarLogic:setWalkable( astarSearchPtr, _pos, 1 )
end

---@see 释放AStar寻路地图
function accept.freeSearchMap()
    CheckPointAstarLogic:freeAStarMap( astarSearchPtr )
end