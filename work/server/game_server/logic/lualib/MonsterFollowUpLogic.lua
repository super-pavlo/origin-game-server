--[[
 * @file : MonseterFollowUpLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-03 14:42:05
 * @Last Modified time: 2020-04-03 14:42:05
 * @department : Arabic Studio
 * @brief : 怪物追击逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local CommonCacle = require "CommonCacle"
local ArmyWalkLogic = require "ArmyWalkLogic"
local BattleCreate = require "BattleCreate"
local MonseterFollowUpLogic = {}

---@see 怪物追击处理
---@param _mapMonsterInfo table<int, defaultMapMonsterInfoClass>
function MonseterFollowUpLogic:dispatchMonsterFollowUp( _monsterFollowUpInfos, _mapMonsterInfo )
    local removeFollowUp = {}
    for monsterObjectIndex, followInfo in pairs(_monsterFollowUpInfos) do
        local monsterInfo = _mapMonsterInfo[monsterObjectIndex]
        local targetIndex = followInfo.followObjectIndex
        local targetType = followInfo.followObjectType
        repeat
            -- 获取目标信息
            local targetObjectInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
            if not targetObjectInfo then
                break
            end
            if ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.MOVE )
            and not ArmyLogic:checkArmyWalkStatus( targetObjectInfo.status ) then
                break
            end

            local objectFail
            if targetType == Enum.RoleType.ARMY then
                objectFail = ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.FAILED_MARCH )
            end
            -- 判断是否回头攻击自己了
            local isAttackSelf = false
            if targetObjectInfo.targetObjectIndex == monsterObjectIndex
            and ( ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.ATTACK_MARCH )
            or ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.FOLLOWUP ) ) then
                isAttackSelf = true
            end

            if not objectFail and not isAttackSelf then
                -- 判断怪物是否超出了追击范围
                local partolDistance = math.sqrt( (targetObjectInfo.pos.x - monsterInfo.initPos.x ) ^ 2 + ( targetObjectInfo.pos.y - monsterInfo.initPos.y ) ^ 2 )
                if partolDistance < monsterInfo.followUpDistance then
                    local armyRadius = CommonCacle:getArmyRadius( monsterInfo.soldiers )
                    -- 部队实时计算
                    local targetSoldiers = ArmyLogic:getArmySoldiersFromObject( targetObjectInfo )
                    local targetRaidus = CommonCacle:getArmyRadius( targetSoldiers, targetObjectInfo.isRally )
                    local attackRange = armyRadius + targetRaidus + CFG.s_Config:Get("attackRange")
                    local distance = math.sqrt( (monsterInfo.pos.x - targetObjectInfo.pos.x ) ^ 2 + ( monsterInfo.pos.y - targetObjectInfo.pos.y ) ^ 2 )
                    if attackRange < distance then
                        local fPos = monsterInfo.pos
                        local fixPos = MSM.MapMarchMgr[monsterObjectIndex].req.fixObjectPosWithMillisecond( monsterObjectIndex, true )
                        if fixPos then
                            fPos = fixPos
                        end
                        -- 更新路径
                        local path = { fPos, targetObjectInfo.pos }
                        path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.ARMY, path, armyRadius, targetRaidus )
                        MSM.MapMarchMgr[monsterObjectIndex].post.monsterFollowUp( monsterObjectIndex, followInfo.followObjectIndex, path, monsterInfo.speed, monsterInfo.objectType )
                    else
                        -- 结束追击
                        removeFollowUp[monsterObjectIndex] = true
                    end
                else
                    -- 超出追击范围,停止追击
                    removeFollowUp[monsterObjectIndex] = true
                    -- 通知战斗服务器切换目标
                    BattleCreate:changeAttackTarget( monsterObjectIndex, monsterInfo.objectType, 0 )
                end
            else
                -- 目标不存在了,取消追击
                removeFollowUp[monsterObjectIndex] = true
            end
        until true
    end

    for removeIndex in pairs(removeFollowUp) do
        -- 取消追击移动
        MSM.MapMarchMgr[removeIndex].req.stopObjectMove(removeIndex)
        -- 追击信息移除
        _monsterFollowUpInfos[removeIndex] = nil
        -- 移除目标追击状态
        _mapMonsterInfo[removeIndex].status = ArmyLogic:delArmyStatus( _mapMonsterInfo[removeIndex].status, Enum.ArmyStatus.FOLLOWUP )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( removeIndex, { status = _mapMonsterInfo[removeIndex].status, pos = _mapMonsterInfo[removeIndex].pos } )
    end
end

return MonseterFollowUpLogic