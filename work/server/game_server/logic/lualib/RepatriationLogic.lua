--[[
 * @file : RepatriationLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-20 21:28:35
 * @Last Modified time: 2020-05-20 21:28:35
 * @department : Arabic Studio
 * @brief : 遣返相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local ArmyLogic = require "ArmyLogic"
local RoleSync = require "RoleSync"

local RepatriationLogic = {}

---@see 从城市遣返增援的部队
function RepatriationLogic:repatriationFromCityImpl( _rid, _repatriationRid, _force, _set )
    ---@type table<int, defaultReinforceCityClass>
    local objectIndex
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    -- 判断是否有增援的部队
    for reinforceRid, reinforceInfo in pairs(reinforces) do
        if _repatriationRid == reinforceRid then
            -- 判断部队是否已经到达
            if not _force and reinforceInfo.arrivalTime > os.time() then
                -- 未到达,无法遣返
                return nil, ErrorCode.RALLY_REPATRIATION_REINFORCE_FAIL
            end

            -- 遣返部队
            local armyInfo = ArmyLogic:getArmy( reinforceRid, reinforceInfo.armyIndex )
            if not armyInfo or table.empty( armyInfo ) then
                -- 没找到部队,从被增援处移除
                reinforces[reinforceRid] = nil
                RoleLogic:setRole( _rid, Enum.Role.reinforces, reinforces )
                RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
                return nil, ErrorCode.MAP_ARMY_NOT_EXIST
            end
            armyInfo.status = Enum.ArmyStatus.RETREAT_MARCH
            local cityIndex = RoleLogic:getRoleCityIndex( _rid )
            objectIndex = MSM.RoleArmyMgr[reinforceRid].req.getRoleArmyIndex( reinforceRid, reinforceInfo.armyIndex )
            if reinforceInfo.arrivalTime > os.time() and objectIndex then
                -- 未到达
                MSM.MapMarchMgr[objectIndex].req.marchBackCity( reinforceRid, objectIndex, nil, true )
            else
                -- 已到达
                local fpos = RoleLogic:getRole( _rid, Enum.Role.pos )
                local tpos = RoleLogic:getRole( reinforceRid, Enum.Role.pos )
                local tcityIndex = RoleLogic:getRoleCityIndex( reinforceRid )
                local cityRadius = CFG.s_Config:Get("cityRadius") * 100
                local arrivalTime = ArmyLogic:armyEnterMap( reinforceRid, reinforceInfo.armyIndex, armyInfo,
                                                            Enum.RoleType.CITY, Enum.RoleType.CITY, fpos, tpos,
                                                            tcityIndex, Enum.MapMarchTargetType.RETREAT, cityRadius, cityRadius, true )
                if not arrivalTime then
                    return nil, ErrorCode.RALLY_REPATRIATION_REINFORCE_FAIL
                end
            end

            -- 如果城市正在战斗,部队退出战斗
            local cityStatus = MSM.SceneCityMgr[cityIndex].req.getCityStatus( cityIndex )
            if ArmyLogic:checkArmyStatus( cityStatus, Enum.ArmyStatus.BATTLEING ) then
                -- 通知战斗服务器退出战斗
                local BattleAttrLogic = require "BattleAttrLogic"
                BattleAttrLogic:notifyBattleSubSoldier( cityIndex, reinforces[reinforceRid].soldiers, reinforceRid, reinforceRid, reinforceInfo.armyIndex )
                -- 增加退出战斗
                BattleAttrLogic:reinforceLeaveBattle( cityIndex, reinforceRid, reinforceInfo.armyIndex )
                -- 同步当前城市部队数量
                local armyCountMax = ArmyLogic:getCityAllArmyCount( _rid, reinforceRid )
                MSM.SceneCityMgr[cityIndex].post.updateCityArmyCountMax( cityIndex, armyCountMax )
            end
            -- 通知城市
            if not _force or _set then
                reinforces[reinforceRid] = nil
                RoleLogic:setRole( _rid, Enum.Role.reinforces, reinforces )
                RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
            end
            -- 删除集结信息
            local RallyLogic = require "RallyLogic"
            RallyLogic:delRallyedReinforceInfo( cityIndex, reinforceRid, reinforceInfo.armyIndex )

            return { repatriationRid = reinforceRid }
        end
    end

    return nil, ErrorCode.RALLY_REPATRIATION_REINFORCE_FAIL
end

---@see 从城市遣返增援的部队
function RepatriationLogic:repatriationFromCity( _rid, _repatriationRid, _force, _set )
    local key = string.format("reinforceDispath_%d", _rid)
    Common.tryLock(key)
    local _, ret, error = pcall( RepatriationLogic.repatriationFromCityImpl, RepatriationLogic, _rid, _repatriationRid, _force, _set )
    Common.unLock(key)
    return ret, error
end

return RepatriationLogic