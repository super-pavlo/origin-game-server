--[[
* @file : SceneRuneMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon May 18 2020 09:31:42 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图符文管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local ArmyDef = require "ArmyDef"

---@see 地图符文信息
---@class defaultMapRuneInfoClass
local defaultMapRuneInfo = {
    pos                         =                   {},             -- 符文坐标
    runeId                      =                   0,              -- 符文图纸ID
    runeRefreshTime             =                   0,              -- 符文图纸刷新出来的时间
    holyLandId                  =                   0,              -- 圣地ID
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    armyRadius                  =                   0,              -- 对象半径
}

---@type table<int, defaultMapRuneInfoClass>
local mapRuneInfos = {}
---@type table<int, table>
local armyWalkToInfo = {}

---@see 增加地图符文对象
function response.addRuneObject( _objectIndex, _runeInfo, _pos )
    local mapRuneInfo = const( table.copy( defaultMapRuneInfo, true ) )
    mapRuneInfo.pos = _pos
    mapRuneInfo.runeId = _runeInfo.runeId
    mapRuneInfo.runeRefreshTime = _runeInfo.runeRefreshTime
    mapRuneInfo.holyLandId = _runeInfo.holyLandId
    mapRuneInfo.armyRadius = CFG.s_MapItemType:Get( _runeInfo.runeId, "radius" ) * 100
    mapRuneInfos[_objectIndex] = mapRuneInfo
end

---@see 删除地图符文对象
function accept.deleteRuneObject( _objectIndex )
    if mapRuneInfos[_objectIndex] and armyWalkToInfo[_objectIndex] then
        local mapArmyInfo, armyStatus
        -- 向该目标行军的部队直接回城
        for armyObjectIndex in pairs( armyWalkToInfo[_objectIndex] ) do
            mapArmyInfo = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyInfo( armyObjectIndex )
            if mapArmyInfo then
                armyStatus = ArmyLogic:getArmy( mapArmyInfo.rid, mapArmyInfo.armyIndex, Enum.Army.status )
                if armyStatus and ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.COLLECT_MARCH ) then
                    MSM.MapMarchMgr[armyObjectIndex].req.marchBackCity( mapArmyInfo.rid, armyObjectIndex )
                end
            end
        end
    end

    mapRuneInfos[_objectIndex] = nil
end

---@see 获取地图符文信息
function response.getRuneInfo( _objectIndex )
    if mapRuneInfos[_objectIndex] then
        return mapRuneInfos[_objectIndex]
    end
end

---@see 获取地图符文坐标
function response.getRunePos( _objectIndex )
    if mapRuneInfos[_objectIndex] then
        return mapRuneInfos[_objectIndex].pos
    end
end

---@see 增加军队向符文行军
function accept.addArmyWalkToRune( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapRuneInfos[_objectIndex] then
        if not armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex] = {}
        end
        armyWalkToInfo[_objectIndex][_armyObjectIndex] = { marchType = _marchType, arrivalTime = _arrivalTime }

        local armyInfo = MSM.SceneArmyMgr[_armyObjectIndex].req.getArmyInfo( _armyObjectIndex )
        local armyMarchInfo = ArmyDef:getDefaultArmyMarchInfo()
        armyMarchInfo.objectIndex = _armyObjectIndex
        armyMarchInfo.rid = armyInfo.rid
        armyMarchInfo.path = _path
        armyMarchInfo.guildId = armyInfo.guildId
        mapRuneInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除军队向符文行军
function accept.delArmyWalkToRune( _objectIndex, _armyObjectIndex )
    if mapRuneInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapRuneInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
        end
    end
end

---@see 更新向目标行军的目标联盟
function accept.updateArmyWalkObjectGuildId( _objectIndex, _armyObjectIndex, _guildId )
    if mapRuneInfos[_objectIndex] and mapRuneInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapRuneInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapRuneInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end