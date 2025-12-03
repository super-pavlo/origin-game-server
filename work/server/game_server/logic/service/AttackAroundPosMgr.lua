--[[
 * @file : AttackAroundPosMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-06-08 17:51:21
 * @Last Modified time: 2020-06-08 17:51:21
 * @department : Arabic Studio
 * @brief : 攻击方方位管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local BattleCreate = require "BattleCreate"
local EmailLogic = require "EmailLogic"
local MapObjectLogic = require "MapObjectLogic"
local queue = require "skynet.queue"
local ArmyWalkLogic = require "ArmyWalkLogic"
local AttackAroundPosLogic = require "AttackAroundPosLogic"
local CommonCacle = require "CommonCacle"

---@type table<int, table<int, int>> 站位
local aroundAttackerPos = {}
local lock = {}

---@see 攻击者加入
function accept.addAttacker( _objectIndex, _attackObjectIndex, _attackObjectType )
    if _attackObjectType ~= Enum.RoleType.ARMY and _attackObjectType ~= Enum.RoleType.EXPEDITION
        and _attackObjectType ~= Enum.RoleType.MONSTER and _attackObjectType ~= Enum.RoleType.GUARD_HOLY_LAND
        and _attackObjectType ~= Enum.RoleType.SUMMON_SINGLE_MONSTER then
        return
    end

    if not lock[_objectIndex] then
        lock[_objectIndex] = queue()
    end

    return lock[_objectIndex](
        function ()
            local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
            if not objectInfo then
                -- 不存在目标
                return
            end

            local attackInfo = MSM.MapObjectTypeMgr[_attackObjectIndex].req.getObjectInfo( _attackObjectIndex )
            -- 攻击者处于移动状态
            if not attackInfo or ArmyLogic:checkArmyWalkStatus( attackInfo.status ) then
                return
            end

            -- 攻击者处于溃败状态
            if ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.FAILED_MARCH )
            or ArmyLogic:getArmySoldierCount( attackInfo.soldiers ) <= 0 then
                return
            end

            local maxPos
            if MapObjectLogic:checkIsCheckPoint( objectInfo.objectType ) then
                -- 关卡只有6个方向
                maxPos = 6
            elseif MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType ) then
                -- 圣地12个方向
                maxPos = 12
            else
                maxPos = 8
            end

            -- 计算半径
            local objectArmyRadius, attackArmyRadius
            if objectInfo.objectType == Enum.RoleType.ARMY or objectInfo.objectType == Enum.RoleType.EXPEDITION then
                objectArmyRadius = CommonCacle:getArmyRadius( ArmyLogic:getArmySoldiersFromObject( objectInfo ), objectInfo.isRally )
            else
                objectArmyRadius = objectInfo.armyRadius
            end
            if attackInfo.objectType == Enum.RoleType.ARMY or attackInfo.objectType == Enum.RoleType.EXPEDITION then
                attackArmyRadius = CommonCacle:getArmyRadius( ArmyLogic:getArmySoldiersFromObject( attackInfo ), attackInfo.isRally )
            else
                attackArmyRadius = attackInfo.armyRadius
            end

            -- 计算目标位置处于哪个方位
            local radius = attackArmyRadius + objectArmyRadius
            if not aroundAttackerPos[_objectIndex] then
                aroundAttackerPos[_objectIndex] = {}
            else
                for _, attackers in pairs(aroundAttackerPos[_objectIndex]) do
                    for _, attackIndex in pairs(attackers) do
                        if attackIndex == _attackObjectIndex then
                            -- 已经存在了
                            return
                        end
                    end
                end
            end

            local aroundPos
            local standAroundPos = {}
            if maxPos == 8 then
                aroundPos = ArmyLogic:caclePosAround_8( attackInfo.pos, objectInfo.pos )
            elseif maxPos == 12 then
                aroundPos = ArmyLogic:caclePosAround_12( attackInfo.pos, objectInfo.pos )
            elseif maxPos == 6 then
                aroundPos, standAroundPos = ArmyLogic:caclePosAround_6( attackInfo.pos, objectInfo.pos, objectInfo.strongHoldId )
            end

            -- 寻找空位(非关卡会按挤开队伍机制处理)
            if maxPos == 6 and aroundAttackerPos[_objectIndex][aroundPos] then
                local find
                -- 此方位已经有对象,逆时针寻找
                for i = aroundPos + 1, 8 do
                    if not aroundAttackerPos[_objectIndex][i] and ( table.empty(standAroundPos) or standAroundPos[i] ) then
                        aroundPos = i
                        find = true
                        break
                    end
                end

                if not find then
                    for i = 1, aroundPos do
                        if not aroundAttackerPos[_objectIndex][i] and ( table.empty(standAroundPos) or standAroundPos[i] ) then
                            aroundPos = i
                            break
                        end
                    end
                end
            end

            -- 挤开其他队伍,让出一个空位(关卡不会挤开其他队伍)
            if maxPos ~= 6 and not ArmyLogic:checkArmyWalkStatus( objectInfo.status ) then
                aroundPos = AttackAroundPosLogic:checkAroundPosHadObject( objectInfo, aroundAttackerPos[_objectIndex], _objectIndex, aroundPos, maxPos, radius )
            end
            -- 保存方位对象信息
            if not aroundAttackerPos[_objectIndex][aroundPos] then
                aroundAttackerPos[_objectIndex][aroundPos] = {}
            end
            table.insert( aroundAttackerPos[_objectIndex][aroundPos], _attackObjectIndex )
            -- 目标还在移动,不调整站位
            if ArmyLogic:checkArmyWalkStatus( objectInfo.status ) then
                return
            end

            -- 如果攻击者的主目标不是objectIndex,不调整站位,仅加入站位
            local isMoveAttacker = attackInfo.targetObjectIndex == 0 or attackInfo.targetObjectIndex == _objectIndex
            -- 修正位置
            if isMoveAttacker then
                AttackAroundPosLogic:updateAroundPos( objectInfo, _attackObjectIndex, _objectIndex, maxPos, aroundPos, radius )
            end
        end
    )
end

---@see 攻击者离开
function accept.delAttacker( _objectIndex, _attackObjectIndex )
    if aroundAttackerPos[_objectIndex] then
        local aroundPosInfo = aroundAttackerPos[_objectIndex]
        for aroundPos, attackers in pairs(aroundPosInfo) do
            if table.exist( attackers, _attackObjectIndex ) then
                table.removevalue( attackers, _attackObjectIndex )
            end
            if table.empty(attackers) then
                aroundAttackerPos[_objectIndex][aroundPos] = nil
            end
        end

        if table.empty(aroundPosInfo) then
            aroundAttackerPos[_objectIndex] = nil
        else
            local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
            local maxPos, posTo
            if MapObjectLogic:checkIsCheckPoint( objectInfo.objectType ) then
                -- 关卡只有6个方向
                maxPos = 6
                posTo = CFG.s_StrongHoldData:Get( objectInfo.strongHoldId, "posTo" )
            elseif MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType ) then
                -- 圣地12个方向
                maxPos = 12
            else
                maxPos = 8
            end
            -- 初始化所有方向
            local emptyPos = {}
            for i = 1, maxPos do
                table.insert( emptyPos, i )
            end
            -- 过滤掉已经有人的
            for aroundPos in pairs(aroundPosInfo) do
                emptyPos[aroundPos] = nil
            end
            -- 如果是关卡,过滤无效的站位
            if maxPos == 6 and posTo then
                if posTo == "180" then
                    emptyPos[1] = nil
                    emptyPos[5] = nil
                else
                    emptyPos[2] = nil
                    emptyPos[6] = nil
                end
            end
            emptyPos = table.values(emptyPos)

            local objectArmyRadius
            if objectInfo.objectType == Enum.RoleType.ARMY or objectInfo.objectType == Enum.RoleType.EXPEDITION then
                objectArmyRadius = CommonCacle:getArmyRadius( ArmyLogic:getArmySoldiersFromObject( objectInfo ), objectInfo.isRally )
            else
                objectArmyRadius = objectInfo.armyRadius
            end

            -- 把重叠的目标,分配到空闲的位置上
            if #emptyPos > 0 then
                for attackPos, attackObjectInfos in pairs(aroundPosInfo) do
                    if table.size(attackObjectInfos) > 1 then
                        repeat
                            local newPos
                            if maxPos == 6 then
                                -- 如果是关卡,判断空出来的位置是否在自己这一侧
                                newPos = AttackAroundPosLogic:getCheckPointMovePoint( posTo, attackPos, emptyPos )
                            else
                                newPos = table.remove(emptyPos, 1)
                            end

                            -- 没找到位置
                            if not newPos then
                                break
                            end

                            local attackIndex = table.remove(attackObjectInfos, 1)
                            local attackInfo = MSM.MapObjectTypeMgr[attackIndex].req.getObjectInfo( attackIndex )
                            -- 如果溃败了,不调整
                            if not attackInfo or ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.FAILED_MARCH )
                            or ArmyLogic:getArmySoldierCount( attackInfo.soldiers ) <= 0 then
                                break
                            end
                            aroundAttackerPos[_objectIndex][newPos] = { attackIndex }
                            local attackArmyRadius
                            if attackInfo.objectType == Enum.RoleType.ARMY or attackInfo.objectType == Enum.RoleType.EXPEDITION then
                                attackArmyRadius = CommonCacle:getArmyRadius( ArmyLogic:getArmySoldiersFromObject( attackInfo ), attackInfo.isRally )
                            else
                                attackArmyRadius = attackInfo.armyRadius
                            end
                            local radius = attackArmyRadius + objectArmyRadius
                            AttackAroundPosLogic:updateAroundPos( objectInfo, attackIndex, _objectIndex, maxPos, newPos, radius )
                            if #emptyPos <= 0 then
                                break
                            end
                        until true
                    end
                end
            end
        end
    end
end

---@see 通知攻击者退出战斗
function response.notifyAttackerExitBattle( _objectIndex, _isSendMail, _mailArg, _isCityShield )
    if aroundAttackerPos[_objectIndex] then
        local attackGuildId
        local guildId = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectGuildId( _objectIndex )
        for _, attackers in pairs(aroundAttackerPos[_objectIndex]) do
            for _, attackIndex in pairs(attackers) do
                -- 攻击城市的一定是部队
                attackGuildId = MSM.SceneArmyMgr[attackIndex].req.getArmyGuild( attackIndex )
                if _isCityShield or attackGuildId == guildId then
                    -- 此部队退出战斗
                    BattleCreate:exitBattle( attackIndex )
                    if _isSendMail then
                        -- 发送邮件
                        local armyInfo = MSM.SceneArmyMgr[attackIndex].req.getArmyInfo( attackIndex )
                        EmailLogic:sendEmail( armyInfo.rid, 110000, { subTitleContents = _mailArg, emailContents = _mailArg } )
                    end
                end
            end
        end
    end
end

---@see 重调所有站位
function accept.recacleAroundPos( _objectIndex )
    if aroundAttackerPos[_objectIndex] then
        if table.empty(aroundAttackerPos[_objectIndex]) then
            return
        end

        -- 如果只有一个目标,不调整
        local allCount = 0
        for _, attackers in pairs(aroundAttackerPos[_objectIndex]) do
            allCount = allCount + table.size( attackers )
        end
        if allCount <= 1 then
            return
        end

        local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
        if not objectInfo then
            -- 不存在目标
            return
        end

        -- 建筑不调整
        if MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType )
        or MapObjectLogic:checkIsResourceObject( objectInfo.objectType )
        or MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType ) then
            return
        end

        local objectArmyRadius
        if objectInfo.objectType == Enum.RoleType.ARMY or objectInfo.objectType == Enum.RoleType.EXPEDITION then
            objectArmyRadius = CommonCacle:getArmyRadius( ArmyLogic:getArmySoldiersFromObject( objectInfo ), objectInfo.isRally )
        else
            objectArmyRadius = objectInfo.armyRadius
        end

        local maxPos = 8
        for aroundPos, attackers in pairs(aroundAttackerPos[_objectIndex]) do
            for index, attackIndex in pairs(attackers) do
                repeat
                    local attackInfo = MSM.MapObjectTypeMgr[attackIndex].req.getObjectInfo( attackIndex )
                    if attackInfo then
                        -- 如果溃败了,不调整
                        if ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.FAILED_MARCH )
                        or ArmyLogic:getArmySoldierCount( attackInfo.soldiers ) <= 0 then
                            attackers[index] = nil
                            break
                        end
                        local attackArmyRadius
                        if attackInfo.objectType == Enum.RoleType.ARMY or attackInfo.objectType == Enum.RoleType.EXPEDITION then
                            attackArmyRadius = CommonCacle:getArmyRadius( ArmyLogic:getArmySoldiersFromObject( attackInfo ), attackInfo.isRally )
                        else
                            attackArmyRadius = attackInfo.armyRadius
                        end
                        local radius = attackArmyRadius + objectArmyRadius
                        -- 停止追击
                        ArmyWalkLogic:notifyEndFollowUp( attackIndex, attackInfo.objectType )
                        -- 更新部队路径
                        AttackAroundPosLogic:updateAroundPos( objectInfo, attackIndex, _objectIndex, maxPos, aroundPos, radius )
                    end
                until true
            end
        end

        -- 让战斗服务器发送在攻击目标的对象,避免攻击的对象未加入站位(对象移动了,但是目标没移动)
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
        if battleIndex then
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            if battleNode then
                Common.rpcMultiSend( battleNode, "BattleLoop", "syncAroundAttacker", battleIndex, _objectIndex )
            end
        end
    end
end

---@see 清空环绕攻击位置信息
function accept.deleteAllRoundPos( _objectIndex )
    aroundAttackerPos[_objectIndex] = nil
    lock[_objectIndex] = nil
end

---@see 获取攻击者信息
function response.getAttackers( _objectIndex )
    return aroundAttackerPos[_objectIndex]
end

---@see 获取攻击者对象索引
function response.getAttackerIndexs( _objectIndex )
    local attackIndexs = {}
    if aroundAttackerPos[_objectIndex] then
        for _, attackers in pairs(aroundAttackerPos[_objectIndex]) do
            for _, attackIndex in pairs(attackers) do
                table.insert( attackIndexs, attackIndex )
            end
        end
    end
    return attackIndexs
end