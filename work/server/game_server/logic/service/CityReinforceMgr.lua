--[[
 * @file : CityReinforceMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-05-20 15:46:42
 * @Last Modified time: 2020-05-20 15:46:42
 * @department : Arabic Studio
 * @brief : 城市增援管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local queue = require "skynet.queue"
local CityReinforceLogic = require "CityReinforceLogic"
local RallyDef = require "RallyDef"
local RallyLogic = require "RallyLogic"
local RepatriationLogic = require "RepatriationLogic"
local BattleAttrLogic = require "BattleAttrLogic"
local BattleCreate = require "BattleCreate"
local CommonCacle = require "CommonCacle"

local reinforceLock = {}

---@see 判断城市增援是否已满.是否已经加入增援
function response.isReinforceCityOrFull( _rid, _reinforceRid, _reinforceArmyCount )
    if not reinforceLock[_rid] then
        reinforceLock[_rid] = { lock = queue() }
    end

    return reinforceLock[_rid].lock(function ()
        -- 判断是否超过了容量
        if not CityReinforceLogic:checkIsReinforceFull( _rid, _reinforceArmyCount ) then
            LOG_ERROR("reinforceRid(%d) isReinforceCityOrFull checkIsReinforceFull fail", _reinforceRid)
            return nil
        end

        -- 判断是否已经向此城市增援
        if not CityReinforceLogic:checkIsReinforceIn( _rid, _reinforceRid ) then
            LOG_ERROR("reinforceRid(%d) isReinforceCityOrFull checkIsReinforceIn fail", _reinforceRid)
            return false
        end

        return true
    end)
end

---@see 加入城市增援
function response.addCityReinforce( _rid, _reinforceRid, _armyIndex, _reinforceObjectIndex )
    if not reinforceLock[_rid] then
        reinforceLock[_rid] = { lock = queue() }
    end

    return reinforceLock[_rid].lock(function ()
        -- 获取部队信息
        local armyInfo = ArmyLogic:getArmy( _reinforceRid, _armyIndex )
        if not armyInfo then
            LOG_ERROR("reinforceRid(%d) getArmy fail, armyIndex(%d)", _reinforceRid, _armyIndex)
            return false, ErrorCode.MAP_ARMY_NOT_EXIST
        end
        local reinforceArmyCount = ArmyLogic:getArmySoldierCount( armyInfo.soldiers )

        -- 二次判断容量是否已满
        if not CityReinforceLogic:checkIsReinforceFull( _rid, reinforceArmyCount ) then
            LOG_ERROR("reinforceRid(%d) addCityReinforce checkIsReinforceFull fail", _reinforceRid)
            return false, ErrorCode.RALLY_ALLIANCE_CENTER_ARMY_LIMIT
        end

        -- 判断部队是否在地图中
        local armyInMap, fpos, isOutCity, tpos, ftype
        local objectIndex = MSM.RoleArmyMgr[_reinforceRid].req.getRoleArmyIndex( _reinforceRid, _armyIndex )
        if objectIndex then
            -- 部队在地图上
            armyInMap = true
            fpos = MSM.SceneArmyMgr[objectIndex].req.getArmyPos( objectIndex )
            ArmyLogic:checkArmyOldTarget( _reinforceRid, _armyIndex, armyInfo )
        else
            ftype = Enum.RoleType.CITY
            isOutCity = true
            -- 部队不在地图上
            local oldTargetObjectIndex = armyInfo.targetArg.targetObjectIndex
            if oldTargetObjectIndex == _reinforceObjectIndex then
                -- 无旧的目标
                fpos = RoleLogic:getRole( _reinforceRid, Enum.Role.pos )
                isOutCity = true
            else
                -- 部队旧的目标的处理
                fpos, ftype = ArmyLogic:checkArmyOldTarget( _reinforceRid, _armyIndex, armyInfo )
            end
        end

        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.pos } )
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        tpos = roleInfo.pos

        local arrivalTime
        if armyInMap then
            -- 移动部队,发起集结行军
            arrivalTime = MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, cityIndex, nil, Enum.ArmyStatus.REINFORCE_MARCH, Enum.MapMarchTargetType.REINFORCE )
        else
            local armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
            -- 行军部队加入地图
            arrivalTime, objectIndex = ArmyLogic:armyEnterMap( _reinforceRid, _armyIndex, armyInfo, ftype, Enum.RoleType.CITY, fpos, tpos,
                                                                cityIndex, Enum.MapMarchTargetType.REINFORCE, armyRadius, nil, isOutCity )
        end

        -- 增援目标失败
        if not arrivalTime then
            LOG_ERROR("reinforceRid(%d) addCityReinforce armyEnterMap or armyMove fail", _reinforceRid)
            return false, ErrorCode.RALLY_REINFORCE_CITY_FAIL
        end

        -- 加入城市增援中
        local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
        local defaultReinforceCity = RallyDef:getDefaultReinforceCity()
        defaultReinforceCity.reinforceRid = _reinforceRid
        defaultReinforceCity.armyIndex = _armyIndex
        defaultReinforceCity.arrivalTime = arrivalTime
        defaultReinforceCity.objectIndex = objectIndex
        defaultReinforceCity.mainHeroId = armyInfo.mainHeroId
        defaultReinforceCity.mainHeroLevel = armyInfo.mainHeroLevel
        defaultReinforceCity.deputyHeroId = armyInfo.deputyHeroId
        defaultReinforceCity.deputyHeroLevel = armyInfo.deputyHeroLevel
        defaultReinforceCity.soldiers = armyInfo.soldiers

        local reinforceRoleInfo = RoleLogic:getRole( _reinforceRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
        defaultReinforceCity.name = reinforceRoleInfo.name
        defaultReinforceCity.headId = reinforceRoleInfo.headId
        defaultReinforceCity.headFrameID = reinforceRoleInfo.headFrameID
        reinforces[_reinforceRid] = defaultReinforceCity
        -- 添加到角色中
        RoleLogic:setRole( _rid, Enum.Role.reinforces, reinforces )
        -- 通知客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
        -- 同步集结增援
        RallyLogic:addRallyedReinforceInfo( cityIndex, _rid, reinforces )
        -- 记录部队增援的城市
        ArmyLogic:updateArmyInfo( _reinforceRid, _armyIndex, { reinforceRid = _rid }, true )
        return true
    end)
end

---@see 增援城市达到
function response.cityReinforceArrivalCallback( _rid, _reinforceRid, _armyIndex, _reinforceObjectIndex )
    -- 判断是否还属于同一联盟
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.reinforceRecord, Enum.Role.guildId, Enum.Role.reinforces, Enum.Role.pos } )
    if not roleInfo.reinforces[_reinforceRid] then
        return true
    end
    local reinforceGuildId = RoleLogic:getRole( _reinforceRid, Enum.Role.guildId )
    if roleInfo.guildId > 0 and roleInfo.guildId ~= reinforceGuildId then
        -- 取消增援城市
        CityReinforceLogic:cancleReinforceCity( _rid, _reinforceRid, nil, _reinforceObjectIndex )
        return false
    end

    -- 添加增援记录,最多50条
    local recordCount = table.size(roleInfo.reinforceRecord)
    -- 移除多余的记录
    for _ = 50, recordCount do
        table.remove( roleInfo.reinforceRecord, 1 )
    end

    -- 添加增援记录
    local reinforceRoleInfo = RoleLogic:getRole( _reinforceRid, { Enum.Role.headId, Enum.Role.name } )
    local armyCount = ArmyLogic:getArmySoldierCount( roleInfo.reinforces[_reinforceRid].soldiers )
    local record = {
        headId = reinforceRoleInfo.headId,
        name = reinforceRoleInfo.name,
        armyCount = armyCount,
        arrivalTime = os.time()
    }
    table.insert( roleInfo.reinforceRecord, record )

    -- 设置
    RoleLogic:setRole( _rid, { [Enum.Role.reinforceRecord] = roleInfo.reinforceRecord } )
    -- 更新部队状态为增援驻扎中
    local armyInfo = ArmyLogic:getArmy( _reinforceRid, _armyIndex )
    -- 增援部队退出战斗
    if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
        BattleCreate:exitBattle( _reinforceObjectIndex, true )
    end
    armyInfo.targetArg.pos = roleInfo.pos
    ArmyLogic:setArmy( _reinforceRid, _armyIndex, { [Enum.Army.targetArg] = armyInfo.targetArg, [Enum.Army.status] = Enum.ArmyStatus.GARRISONING } )
    ArmyLogic:syncArmy( _reinforceRid, _armyIndex, { [Enum.Army.targetArg] = armyInfo.targetArg, [Enum.Army.status] = Enum.ArmyStatus.GARRISONING }, true )

    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local cityInfo = MSM.MapObjectTypeMgr[cityIndex].req.getObjectInfo( cityIndex )
    if ArmyLogic:checkArmyStatus( cityInfo.status, Enum.ArmyStatus.BATTLEING ) then
        -- 士兵加入
        BattleAttrLogic:notifyBattleAddSoldier( cityIndex, armyInfo.soldiers, _reinforceRid, _armyIndex, armyInfo.mainHeroId, armyInfo.mainHeroLevel, armyInfo.deputyHeroId, armyInfo.deputyHeroLevel )
        -- 增援加入战斗
        BattleAttrLogic:reinforceJoinBattle( cityIndex, _reinforceRid, _armyIndex )
        local armyCountMax = ArmyLogic:getCityAllArmyCount( _rid )
        -- 同步当前城市部队数量
        MSM.SceneCityMgr[cityIndex].post.updateCityArmyCountMax( cityIndex, armyCountMax )
    end

    return true
end

---@see 角色退出联盟.增援全部返回
function accept.roleExitGuildDisbanReinforce( _rid )
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    -- 增援的全部遣返
    for reinforceRid in pairs(reinforces) do
        RepatriationLogic:repatriationFromCity( _rid, reinforceRid, true )
    end
    RoleLogic:setRole( _rid, { [Enum.Role.reinforces] = {} } )
    RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = {} }, true )
    -- 自己的部队增援盟友的,也要返回
    local armyInfos = ArmyLogic:getArmy( _rid )
    for _, armyInfo in pairs(armyInfos) do
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING )
        or ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH ) then
            -- 增援行军、驻扎中,回城
            RepatriationLogic:repatriationFromCity( armyInfo.reinforceRid, _rid, true, true )
        end
    end
end

---@see 联盟解散.增援全部返回
function accept.disGuildDisbanReinforce( _allMembers )
    for _, memberInfo in pairs(_allMembers) do
        ---@type table<int, defaultReinforceCityClass>
        local reinforces = RoleLogic:getRole( memberInfo.rid, Enum.Role.reinforces )
        -- 增援的全部遣返
        for reinforceRid in pairs(reinforces) do
            RepatriationLogic:repatriationFromCity( memberInfo.rid, reinforceRid, true )
        end
        RoleLogic:setRole( memberInfo.rid, { [Enum.Role.reinforces] = {} } )
        RoleSync:syncSelf( memberInfo.rid, { [Enum.Role.reinforces] = {} }, true )
        -- 自己的部队增援盟友的,也要返回
        local armyInfos = ArmyLogic:getArmy( memberInfo.rid )
        for _, armyInfo in pairs(armyInfos) do
            if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING )
            or ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH ) then
                -- 增援行军、驻扎中,回城
                RepatriationLogic:repatriationFromCity( armyInfo.reinforceRid, memberInfo.rid, true, true )
            end
        end
    end
end

---@see 清理未到达的增援部队
function accept.backReinforceNoArrival( _rid, _pos )
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    -- 增援的全部遣返
    for reinforceRid, reinforceInfo in pairs(reinforces) do
        if reinforceInfo.arrivalTime > os.time() then
            reinforces[reinforceRid] = nil
        else
            -- 已达到的,更新pos
            local targetArg = ArmyLogic:getArmy( reinforceRid, reinforceInfo.armyIndex, Enum.Army.targetArg )
            targetArg.pos = _pos
            ArmyLogic:updateArmyInfo(reinforceRid, reinforceInfo.armyIndex, { [Enum.Army.targetArg] = targetArg } )
        end
    end
    RoleLogic:setRole( _rid, { [Enum.Role.reinforces] = reinforces } )
    RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
end

---@see 角色强制迁城.清除增援的部队
function accept.disbanArmyOnForceMoveCity( _rid, _reinforceRid )
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    -- 增援的全部遣返,只处理到达的
    for reinforceRid in pairs(reinforces) do
        if _reinforceRid == reinforceRid then
            reinforces[reinforceRid] = nil
        end
    end
    RoleLogic:setRole( _rid, { [Enum.Role.reinforces] = reinforces } )
    RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
end

---@see 角色强制迁城.增援自己的全部遣返
function response.returnArmyOnForceMoveCity( _rid )
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    for reinforceRid in pairs(reinforces) do
        RepatriationLogic:repatriationFromCity( _rid, reinforceRid, true, true )
    end
end