--[[
 * @file : MapObjectTypeMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-02-10 14:26:49
 * @Last Modified time: 2020-02-10 17:26:49
 * @department : Arabic Studio
 * @brief : 地图对象类型服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local MapObjectLogic = require "MapObjectLogic"

---@class objectTypeClass
local objectTypeTemplate = {
    objectType          =           0,
    rid                 =           0,
    obstracleRef        =           0,
    findObstracleRef    =           0,
    monsterObstracleRef =           0,
}
---@see 对象类型信息
---@type table<int, objectTypeClass>
local objectTypeInfos = {}

function response.empty()
    -- body
end

---@see 注册对象类型
function response.addObjectType( _objectIndex, _objectType, _rid, _obstracleRef, _findObstracleRef, _monsterObstracleRef )
    if not objectTypeInfos[_objectIndex] then
        objectTypeInfos[_objectIndex] = const( table.copy( objectTypeTemplate, true ) )
        objectTypeInfos[_objectIndex].objectType = _objectType
        objectTypeInfos[_objectIndex].rid = _rid or 0
        objectTypeInfos[_objectIndex].obstracleRef = _obstracleRef or 0
        objectTypeInfos[_objectIndex].findObstracleRef = _findObstracleRef or 0
        objectTypeInfos[_objectIndex].monsterObstracleRef = _monsterObstracleRef or 0
    end
end

---@see 更新动态障碍索引
function accept.updateObstracleRef( _objectIndex, _obstracleRef, _findObstracleRef, _monsterObstracleRef )
    if objectTypeInfos[_objectIndex] then
        if _obstracleRef then
            objectTypeInfos[_objectIndex].obstracleRef = _obstracleRef or 0
        end
        if _findObstracleRef then
            objectTypeInfos[_objectIndex].findObstracleRef = _findObstracleRef or 0
        end
        if _monsterObstracleRef then
            objectTypeInfos[_objectIndex].monsterObstracleRef = _monsterObstracleRef or 0
        end
    end
end

---@see 获取对象类型信息
---@return objectTypeClass
function response.getObjectType( _objectIndex )
    return objectTypeInfos[_objectIndex]
end

---@see 移除对象类型
function accept.deleteObjectType( _objectIndex )
    objectTypeInfos[_objectIndex] = nil
end

---@see 获取对象坐标
function response.getObjectPos( _objectIndex )
    if objectTypeInfos[_objectIndex] then
        local objectType = objectTypeInfos[_objectIndex].objectType
        if objectType == Enum.RoleType.ARMY then
            return MSM.SceneArmyMgr[_objectIndex].req.getArmyPos( _objectIndex )
        elseif objectType == Enum.RoleType.MONSTER
            or objectType == Enum.RoleType.GUARD_HOLY_LAND
            or objectType == Enum.RoleType.SUMMON_RALLY_MONSTER
            or objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
            return MSM.SceneMonsterMgr[_objectIndex].req.getMonsterPos( _objectIndex )
        elseif MapObjectLogic:checkIsResourceObject( objectType )
        or objectType == Enum.RoleType.VILLAGE or objectType == Enum.RoleType.CAVE then
            return MSM.SceneResourceMgr[_objectIndex].req.getResourcePos( _objectIndex )
        elseif objectType == Enum.RoleType.CITY then
            return MSM.SceneCityMgr[_objectIndex].req.getCityPos( _objectIndex )
        elseif MapObjectLogic:checkIsGuildBuildObject( objectType ) then
            return MSM.SceneGuildBuildMgr[_objectIndex].req.getGuildBuildPos( _objectIndex )
        elseif MapObjectLogic:checkIsHolyLandObject( objectType ) then
            return MSM.SceneHolyLandMgr[_objectIndex].req.getHolyLandPos( _objectIndex )
        elseif objectType == Enum.RoleType.RUNE then
            return MSM.SceneRuneMgr[_objectIndex].req.getRunePos( _objectIndex )
        elseif objectType == Enum.RoleType.GUARD_HOLY_LAND then
            return MSM.SceneHolyLandMgr[_objectIndex].req.getHolyLandPos( _objectIndex )
        elseif MapObjectLogic:checkIsGuildResourcePointObject( objectType ) then
            return MSM.SceneGuildResourcePointMgr[_objectIndex].req.getGuildResourcePointPos( _objectIndex )
        end
    end
end

---@see 获取对象当前状态
function response.getObjectStatus( _objectIndex )
    if objectTypeInfos[_objectIndex] then
        local objectType = objectTypeInfos[_objectIndex].objectType
        if objectType == Enum.RoleType.ARMY then
            return MSM.SceneArmyMgr[_objectIndex].req.getArmyStatus( _objectIndex )
        elseif objectType == Enum.RoleType.MONSTER
            or objectType == Enum.RoleType.GUARD_HOLY_LAND
            or objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
            or objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            return MSM.SceneMonsterMgr[_objectIndex].req.getMonsterStatus( _objectIndex )
        elseif objectType == Enum.RoleType.MONSTER_CITY then
            return MSM.SceneMonsterCityMgr[_objectIndex].req.getMonsterCityStatus( _objectIndex )
        elseif MapObjectLogic:checkIsResourceObject( objectType )
            or objectType == Enum.RoleType.VILLAGE
            or objectType == Enum.RoleType.CAVE then
            return MSM.SceneResourceMgr[_objectIndex].req.getResourceStatus( _objectIndex )
        elseif objectType == Enum.RoleType.CITY then
            return MSM.SceneCityMgr[_objectIndex].req.getCityStatus( _objectIndex )
        elseif MapObjectLogic:checkIsGuildBuildObject( objectType ) then
            return MSM.SceneGuildBuildMgr[_objectIndex].req.getGuildBuildStatus( _objectIndex )
        elseif objectType == Enum.RoleType.EXPEDITION then
            return MSM.SceneExpeditionMgr[_objectIndex].req.getExpeditionStatus( _objectIndex )
        end
    end

    return Enum.ArmyStatus.ARMY_STANBY
end

---@see 获取对象所属联盟
function response.getObjectGuildId( _objectIndex )
    if objectTypeInfos[_objectIndex] then
        local objectType = objectTypeInfos[_objectIndex].objectType
        local objectInfo, rid
        if objectType == Enum.RoleType.ARMY then
            objectInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
            rid = objectInfo.rid
        elseif MapObjectLogic:checkIsResourceObject( objectType )
        or objectType == Enum.RoleType.VILLAGE or objectType == Enum.RoleType.CAVE then
            objectInfo = MSM.SceneResourceMgr[_objectIndex].req.getResourceInfo( _objectIndex )
            rid = objectInfo.collectRid
        elseif objectType == Enum.RoleType.CITY then
            objectInfo = MSM.SceneCityMgr[_objectIndex].req.getCityInfo( _objectIndex )
            rid = objectInfo.rid
        elseif MapObjectLogic:checkIsGuildBuildObject( objectType ) then
            objectInfo = MSM.SceneGuildBuildMgr[_objectIndex].req.getGuildBuildInfo( _objectIndex )
            return objectInfo.guildId
        elseif MapObjectLogic:checkIsHolyLandObject( objectType ) then
            objectInfo = MSM.SceneHolyLandMgr[_objectIndex].req.getHolyLandInfo( _objectIndex )
            return objectInfo.guildId
        end

        if rid and rid > 0 then
            return RoleLogic:getRole( rid, Enum.Role.guildId )
        end
    end

    return 0
end

---@see 获取对象信息
function response.getObjectInfo( _objectIndex )
    if objectTypeInfos[_objectIndex] then
        local objectType = objectTypeInfos[_objectIndex].objectType
        local objectInfo
        if objectType == Enum.RoleType.ARMY then
            -- 部队
            objectInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
        elseif MapObjectLogic:checkIsResourceObject( objectType )
        or objectType == Enum.RoleType.VILLAGE or objectType == Enum.RoleType.CAVE then
            -- 资源点、山洞、村庄
            objectInfo = MSM.SceneResourceMgr[_objectIndex].req.getResourceInfo( _objectIndex )
        elseif objectType == Enum.RoleType.CITY then
            -- 城市
            objectInfo = MSM.SceneCityMgr[_objectIndex].req.getCityInfo( _objectIndex )
        elseif MapObjectLogic:checkIsGuildBuildObject( objectType ) then
            objectInfo = MSM.SceneGuildBuildMgr[_objectIndex].req.getGuildBuildInfo( _objectIndex )
        elseif objectType == Enum.RoleType.MONSTER or objectType == Enum.RoleType.GUARD_HOLY_LAND
            or objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 野蛮人、圣地守护者、召唤怪物
            objectInfo = MSM.SceneMonsterMgr[_objectIndex].req.getMonsterInfo( _objectIndex )
        elseif objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨
            objectInfo = MSM.SceneMonsterCityMgr[_objectIndex].req.getMonsterCityInfo( _objectIndex )
        elseif objectType == Enum.RoleType.EXPEDITION then
            -- 远征对象
            objectInfo = MSM.SceneExpeditionMgr[_objectIndex].req.getExpeditionInfo( _objectIndex )
        elseif MapObjectLogic:checkIsHolyLandObject( objectType ) then
            -- 圣地建筑
            objectInfo = MSM.SceneHolyLandMgr[_objectIndex].req.getHolyLandInfo( _objectIndex )
        elseif objectType == Enum.RoleType.RUNE then
            -- 符文
            objectInfo = MSM.SceneRuneMgr[_objectIndex].req.getRuneInfo( _objectIndex )
        elseif objectType == Enum.RoleType.SCOUTS then
            -- 斥候
            objectInfo = MSM.SceneScoutsMgr[_objectIndex].req.getScoutsInfo( _objectIndex )
        else
            return
        end

        if objectTypeInfos[_objectIndex] then
            objectInfo.objectType = objectType
            objectInfo.objectIndex = _objectIndex
            objectInfo.obstracleRef = objectTypeInfos[_objectIndex].obstracleRef
            objectInfo.findObstracleRef = objectTypeInfos[_objectIndex].findObstracleRef
            objectInfo.monsterObstracleRef = objectTypeInfos[_objectIndex].monsterObstracleRef

            return objectInfo
        end
    end
end