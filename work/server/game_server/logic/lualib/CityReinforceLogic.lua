--[[
 * @file : CityReinforceLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-20 16:26:54
 * @Last Modified time: 2020-05-20 16:26:54
 * @department : Arabic Studio
 * @brief : 城市增援逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BuildingLogic = require "BuildingLogic"
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local ArmyLogic = require "ArmyLogic"
local BattleAttrLogic = require "BattleAttrLogic"

local CityReinforceLogic = {}

---@see 获取城市最大增援容量
function CityReinforceLogic:getMaxCityReinforce( _rid )
    -- 获取联盟中心等级
    local allianceCenterLevel = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.ALLIANCE_CENTER )
    local sBuildingAllianceCenter = CFG.s_BuildingAllianceCenter:Get( allianceCenterLevel )
    if not sBuildingAllianceCenter then
        return 0
    end

    return sBuildingAllianceCenter.defCapacity
end

---@see 判断城市增援容量是否已满
function CityReinforceLogic:checkIsReinforceFull( _rid, _reinforceArmyCount )
    -- 获取联盟中心容量
    local maxDefCapacity = self:getMaxCityReinforce( _rid )
    -- 获取角色已增援的容量
    local allianceCenterReinforceCount = RoleLogic:getAllianceCenterReinforceCount( _rid )
    -- 要增援的部队容量
    if allianceCenterReinforceCount + _reinforceArmyCount > maxDefCapacity then
        return false
    end

    return true
end

---@see 判断是否已经增援了此城市
function CityReinforceLogic:checkIsReinforceIn( _rid, _reinforceRid )
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    if reinforces[_reinforceRid] then
        return false
    end

    return true
end

---@see 获取联盟中心已增援数量
function CityReinforceLogic:getAllianceCenterReinforceCount( _rid )
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    local count = 0
    for _, reinforce in pairs(reinforces) do
        count = count + ArmyLogic:getArmySoldierCount( reinforce.soldiers )
    end

    return count
end

---@see 取消增援城市实现
function CityReinforceLogic:cancleReinforceCityImpl( _rid, _reinforceRid, _noBackCity, _objectIndex )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.reinforces } )
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    ---@type defaultReinforceCityClass
    local reinforceInfo = roleInfo.reinforces[_reinforceRid]
    if not reinforceInfo then return end
    if not _noBackCity then
        -- 部队回城
        MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _reinforceRid, _objectIndex, nil, true )
    end
    -- 移除角色增援信息
    roleInfo.reinforces[_reinforceRid] = nil
    -- 添加到角色中
    RoleLogic:setRole( _rid, Enum.Role.reinforces, roleInfo.reinforces )
    -- 通知客户端
    RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = roleInfo.reinforces }, true )
    -- 取消增援信息
    local RallyLogic = require "RallyLogic"
    RallyLogic:delRallyedReinforceInfo( cityIndex, _reinforceRid, reinforceInfo.armyIndex )
    -- 删除部队增援城市
    ArmyLogic:updateArmyInfo( _reinforceRid, reinforceInfo.armyIndex or 0, { reinforceRid = 0 }, true )

    -- 如果增援已经到达
    if reinforceInfo.arrivalTime <= os.time() then
        -- 如果城市正在战斗,部队退出战斗
        local cityStatus = MSM.SceneCityMgr[cityIndex].req.getCityStatus( cityIndex )
        if ArmyLogic:checkArmyStatus( cityStatus, Enum.ArmyStatus.BATTLEING ) then
            -- 通知战斗服务器退出战斗
            BattleAttrLogic:notifyBattleSubSoldier( cityIndex, reinforceInfo.soldiers, _reinforceRid, _reinforceRid, reinforceInfo.armyIndex )
            -- 增加退出战斗
            BattleAttrLogic:reinforceLeaveBattle( cityIndex, _reinforceRid, reinforceInfo.armyIndex )
            -- 同步当前城市部队数量
            local armyCountMax = ArmyLogic:getCityAllArmyCount( _rid, _reinforceRid )
            MSM.SceneCityMgr[cityIndex].post.updateCityArmyCountMax( cityIndex, armyCountMax )
        end
    end
end

---@see 取消增援城市
function CityReinforceLogic:cancleReinforceCity( _rid, _reinforceRid, _noBackCity, _objectIndex )
    local key = string.format("reinforceDispath_%d", _rid)
    Common.tryLock(key)
    pcall(CityReinforceLogic.cancleReinforceCityImpl, CityReinforceLogic, _rid, _reinforceRid, _noBackCity, _objectIndex )
    Common.unLock(key)
end

---@see 服务器重启检查角色增援信息
function CityReinforceLogic:checkRoleReinforceOnReboot( _rid, _objectIndex )
    local armyInfo, updateFlag, targetArg
    local newReinforces = {}
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces ) or {}
    for reinforceRid, reinforce in pairs( reinforces ) do
        armyInfo = ArmyLogic:getArmy( reinforceRid, reinforce.armyIndex, { Enum.Army.status, Enum.Army.targetArg } )
        if armyInfo and not table.empty( armyInfo ) and ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
            newReinforces[reinforceRid] = reinforce
            targetArg = armyInfo.targetArg or {}
            targetArg.targetObjectIndex = _objectIndex
            ArmyLogic:setArmy( reinforceRid, reinforce.armyIndex, { [Enum.Army.targetArg] = targetArg } )
        else
            updateFlag = true
        end
    end

    if updateFlag then
        RoleLogic:setRole( _rid, { [Enum.Role.reinforces] = newReinforces } )
    end
end

return CityReinforceLogic