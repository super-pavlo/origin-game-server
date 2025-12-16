--[[
 * @file : ArmyFollowUpLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-03 14:21:18
 * @Last Modified time: 2020-04-03 14:21:18
 * @department : Arabic Studio
 * @brief : 军队追击逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local MapObjectLogic = require "MapObjectLogic"
local CommonCacle = require "CommonCacle"
local BattleCreate = require "BattleCreate"
local ArmyFollowUpLogic = {}

---@see 处理一个对象的追击
function ArmyFollowUpLogic:dispatchArmyFollowUpOne( _removeFollowUp, _followInfo, _armyFollowUpInfos, _mapArmyInfos, _armyObjectIndex )
    local targetIndex = _followInfo.followObjectIndex
    local targetType = _followInfo.followObjectType
    local objectInfo = _mapArmyInfos[_armyObjectIndex]
    -- 获取目标信息
    local targetObjectInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
    repeat
        if not objectInfo then
            _armyFollowUpInfos[_armyObjectIndex] = nil
            break
        end
        -- 自己在调整位置,目标不在移动
        if ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.MOVE )
        and not ArmyLogic:checkArmyWalkStatus( targetObjectInfo.status ) then
            break
        end

        -- 城市、野蛮人城寨、联盟建筑、圣地
        local isNoMoveTarget = targetType == Enum.RoleType.CITY
                                or targetType == Enum.RoleType.MONSTER_CITY
                                or MapObjectLogic:checkIsGuildBuildObject( targetType)
                                or MapObjectLogic:checkIsHolyLandObject( targetType )

        if targetObjectInfo then
            local objectFail
            if targetType == Enum.RoleType.ARMY then
                objectFail = ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.FAILED_MARCH )
            end

            -- 判断是否回头攻击自己了
            local isAttackSelf = false
            if targetObjectInfo.targetObjectIndex == _armyObjectIndex
            and ( ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.ATTACK_MARCH )
            or ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.FOLLOWUP ) ) then
                -- 只能是部队,怪物会提前停下
                if targetType == Enum.RoleType.ARMY then
                    isAttackSelf = true
                end
            end

            if objectInfo and not objectFail and not isAttackSelf then
                -- 判断是否在攻击距离内
                local soldiers = ArmyLogic:getArmySoldiersFromObject( objectInfo )
                local armyRadius = CommonCacle:getArmyRadius( soldiers, objectInfo.isRally )
                local targetRaidus, targetSoldiers

                if targetType == Enum.RoleType.ARMY then
                    -- 部队实时计算
                    targetSoldiers = ArmyLogic:getArmySoldiersFromObject( targetObjectInfo )
                    targetRaidus = CommonCacle:getArmyRadius( targetSoldiers, targetObjectInfo.isRally )
                else
                    targetRaidus = targetObjectInfo.armyRadius
                end

                local attackRange = armyRadius + targetRaidus + CFG.s_Config:Get("attackRange")
                local distance = math.sqrt( (objectInfo.pos.x - targetObjectInfo.pos.x ) ^ 2 + ( objectInfo.pos.y - targetObjectInfo.pos.y ) ^ 2 )
                if attackRange < distance then
                    -- 更新路径
                    if not MSM.MapMarchMgr[_armyObjectIndex].req.armyMove( _armyObjectIndex, targetIndex, nil, Enum.ArmyStatus.FOLLOWUP, Enum.MapMarchTargetType.FOLLOWUP ) then
                        -- 无法到达,改变目标
                        BattleCreate:changeAttackTarget( _armyObjectIndex, Enum.RoleType.ARMY, 0 )
                        -- 取消追击
                        _removeFollowUp[_armyObjectIndex] = isNoMoveTarget
                    end
                else
                    -- 结束追击
                    _removeFollowUp[_armyObjectIndex] = isNoMoveTarget
                    -- 判断目标是否有攻击目标,没有则把目标的攻击目标设置成追击者
                    if targetObjectInfo.targetObjectIndex and targetObjectInfo.targetObjectIndex <= 0 then
                        MSM.SceneArmyMgr[targetObjectInfo.targetObjectIndex].post.updateArmyTargetObjectIndex( targetObjectInfo.targetObjectIndex, _armyObjectIndex )
                    end
                end
            else
                -- 目标不存在或者溃败了,取消追击
                _removeFollowUp[_armyObjectIndex] = isNoMoveTarget
            end

            if isNoMoveTarget then
                -- 追击不移动的只追击一次
                _removeFollowUp[_armyObjectIndex] = isNoMoveTarget
            end
        end
    until true
end

---@see 处理军队追击
---@param _mapArmyInfos table<int, defaultMapArmyInfoClass>
function ArmyFollowUpLogic:dispatchArmyFollowUp( _armyFollowUpInfos, _mapArmyInfos )
    local removeFollowUp = {}
    local ret, err
    for armyObjectIndex, followInfo in pairs(_armyFollowUpInfos) do
        ret, err = xpcall(self.dispatchArmyFollowUpOne, debug.traceback, self, removeFollowUp, followInfo, _armyFollowUpInfos, _mapArmyInfos, armyObjectIndex )
        if not ret then
            LOG_ERROR("dispatchArmyFollowUp err:%s", err)
        end
    end

    for removeIndex, isNoMoveTarget in pairs(removeFollowUp) do
        -- 取消追击移动(建筑的不能取消,建筑不会移动)
        if not isNoMoveTarget then
            MSM.MapMarchMgr[removeIndex].req.stopObjectMove(removeIndex)
            -- 移除追击信息
            _armyFollowUpInfos[removeIndex] = nil
            -- 移除目标追击状态
            if _mapArmyInfos[removeIndex] then
                _mapArmyInfos[removeIndex].status = ArmyLogic:delArmyStatus( _mapArmyInfos[removeIndex].status, Enum.ArmyStatus.FOLLOWUP )
                -- 通过AOI通知
                local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
                sceneObject.post.syncObjectInfo( removeIndex, { status = _mapArmyInfos[removeIndex].status, pos = _mapArmyInfos[removeIndex].pos } )
            end
        end
    end
end

return ArmyFollowUpLogic