--[[
* @file : BattleSceneMgr.lua
* @type : service
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 战斗场景管理服务
* Copyright(C) 2020 IGG, All rights reserved
]]

local skynet = require "skynet"
local BattleLogic = require "BattleLogic"
local BattleCommon = require "BattleCommon"
local BattleCacle = require "BattleCacle"
local AttrDef = require "AttrDef"
local BattleBuff = require "BattleBuff"
local MapObjectLogic = require "MapObjectLogic"

---@type table<integer, defaultBattleSceneClass>
local BattleScenes = {}
---@see 战斗协程
local battleCo

---@see 战斗每回合间隔
local battleTurnTick = 1

---@see 战斗实现
local function BattleWorkImpl()
    if table.empty(BattleScenes) then
        skynet.sleep(100 * 60) -- sleep 1min
    else
        local now = os.time()
        for _, battleScene in pairs(BattleScenes) do
            if not battleScene.isBattleMerged then
                if battleScene.nextTick <= now then
                    battleScene.nextTick = now + battleTurnTick
                    battleScene.isBattleWork = true
                    local ret, err = xpcall(BattleLogic.battleWorkImpl, debug.traceback, BattleLogic, battleScene )
                    if not ret then
                        LOG_ERROR("BattleWorkImpl error:%s", err)
                    end
                    battleScene.isBattleWork = false
                end
            end
        end
        skynet.sleep(1)
    end
end

---@see 战斗协程函数
local function BattleWork()
    local ret, err
    while true do
        -- 避免相关类似 invalid to key 'next' 错误 (发生于destoryBattle后,在循环内又CreateBattle导致)
        ret, err = xpcall( BattleWorkImpl, debug.traceback )
        if not ret then
            LOG_ERROR("BattleWork error:%s", err)
        end
    end
end

function init()
    battleCo = skynet.fork(BattleWork)
end

---@see 增加战斗场景
function response.addBattleScene( _battleIndex, _battleScene )
    if not BattleScenes[_battleIndex] then
        BattleScenes[_battleIndex] = _battleScene
        LOG_INFO("addBattleScene battleIndex(%d)", _battleIndex)
        -- 唤醒
        skynet.wakeup(battleCo)
    end
end

---@see 删除战斗场景
function response.deleteBattleScene( _battleIndex )
    if BattleScenes[_battleIndex] then
        BattleScenes[_battleIndex] = nil
        LOG_INFO("deleteBattleScene battleIndex(%d)", _battleIndex)
    end
end

---@see 对象退出战斗
function response.objectExitBattle( _battleIndex, _objectIndex, _block, _leaderArmyNoEnter )
    if BattleScenes[_battleIndex] then
        if BattleScenes[_battleIndex].objectInfos[_objectIndex] then
            BattleLogic:objectExitBattle( BattleScenes[_battleIndex], _objectIndex, _block, _leaderArmyNoEnter )
        end
    end
end

---@see 对象加入战斗
function response.objectJoinBattle( _battleIndex, _objectIndex, _objectInfo, _targetIndex )
    local battleScene = BattleScenes[_battleIndex]
    if battleScene then
        -- 判断攻击对象是否还存在
        if battleScene.objectInfos[_targetIndex] then
            _objectInfo.lastBattleTurn = battleScene.turn
            -- 添加快照
            _objectInfo.attackObjectSnapShot = BattleCommon:copyObjectInfo( battleScene, _targetIndex )
            battleScene.objectInfos[_objectIndex] = _objectInfo
            battleScene.objectInfos[_targetIndex].allAttackers[_objectIndex] = _objectInfo.objectType
            -- 添加Buff
            BattleBuff:addObjectBuffOnCreate( battleScene, _objectIndex )
            -- 重新计算角色属性
            BattleCacle:cacleObjectAttr( battleScene, _objectIndex )
            local attackCount = table.size( battleScene.objectInfos[_targetIndex].allAttackers )
            if attackCount > battleScene.objectInfos[_targetIndex].historyMaxAttackCount then
                battleScene.objectInfos[_targetIndex].historyMaxAttackCount = attackCount
                -- 同步游服
                Common.rpcMultiSend( battleScene.gameNode, "BattleProxy", "syncObjectBeAttackCount",
                                    _targetIndex, battleScene.objectInfos[_targetIndex].objectType, attackCount )
            end
            return true
        end
    end
end

---@see 更新对象位置
function accept.updateObjectPos( _battleIndex, _objectIndex, _pos, _angle )
    local battleScene = BattleScenes[_battleIndex]
    if battleScene then
        -- 判断对象是否还存在
        if battleScene.objectInfos[_objectIndex] then
            battleScene.objectInfos[_objectIndex].pos = _pos or {}
            battleScene.objectInfos[_objectIndex].angle = _angle or 0
        end
    end
end

---@see 同步对象属性
function accept.syncObjectAttr( _battleIndex, _objectIndex, _objectAttr )
    local battleScene = BattleScenes[_battleIndex]
    if battleScene then
        -- 判断对象是否还存在
        if battleScene.objectInfos[_objectIndex] then
            battleScene.objectInfos[_objectIndex].objectAttrRaw = _objectAttr or AttrDef:getDefaultBattleAttr()
            -- 重新计算角色属性
            BattleCacle:cacleObjectAttr( battleScene, _objectIndex )
        end
    end
end

---@see 更新对象主副将以及技能
function accept.syncObjectHeroAndSkill( _battleIndex, _objectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _skills, _talentAttr )
    local battleScene = BattleScenes[_battleIndex]
    if battleScene then
        -- 判断对象是否还存在
        if battleScene.objectInfos[_objectIndex] then
            battleScene.objectInfos[_objectIndex].mainHeroId = _mainHeroId or 0
            battleScene.objectInfos[_objectIndex].mainHeroLevel = _mainHeroLevel or 0
            battleScene.objectInfos[_objectIndex].deputyHeroId = _deputyHeroId or 0
            battleScene.objectInfos[_objectIndex].deputyHeroLevel = _deputyHeroLevel or 0
            battleScene.objectInfos[_objectIndex].rawSkills = _skills or {}
            battleScene.objectInfos[_objectIndex].talentAttr = _talentAttr or {}
            -- 重新计算角色属性
            BattleCacle:cacleObjectAttr( battleScene, _objectIndex )
        end
    end
end

---@see 战斗中加入士兵
function accept.addSoldierOnBattle( _battleIndex, _objectIndex, _soldiers, _reinforceRid, _reinforceArmyIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    local battleScene = BattleScenes[_battleIndex]
    if battleScene then
        -- 判断对象是否还存在
        local objectInfo = battleScene.objectInfos[_objectIndex]
        if objectInfo then
            if not objectInfo.exitBattleFlag then
                local addSoldierNum = 0
                for _, soldierInfo in pairs( _soldiers ) do
                    addSoldierNum = addSoldierNum + soldierInfo.num
                    if objectInfo.soldiers[soldierInfo.id] then
                        objectInfo.soldiers[soldierInfo.id].num = objectInfo.soldiers[soldierInfo.id].num + soldierInfo.num
                    else
                        objectInfo.soldiers[soldierInfo.id] = soldierInfo
                    end
                end

                -- 如果对象是联盟建筑、圣地、城市,增加到详细中
                if MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType )
                or MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
                or objectInfo.objectType == Enum.RoleType.CITY or objectInfo.objectType == Enum.RoleType.ARMY then
                    if _reinforceArmyIndex == 0 then
                        -- 城市自身的士兵增加
                        local selfSoldiers = objectInfo.rallySoldiers[_reinforceRid][_reinforceArmyIndex]
                        for _, soldierInfo in pairs( _soldiers ) do
                            if selfSoldiers[soldierInfo.id] then
                                selfSoldiers[soldierInfo.id].num = selfSoldiers[soldierInfo.id].num + soldierInfo.num
                            else
                                selfSoldiers[soldierInfo.id] = soldierInfo
                            end
                        end
                    else
                        if objectInfo.rallySoldiers[_reinforceRid] then
                            objectInfo.rallySoldiers[_reinforceRid][_reinforceArmyIndex] = _soldiers
                        else
                            objectInfo.rallySoldiers[_reinforceRid] = {
                                [_reinforceArmyIndex] = _soldiers
                            }
                        end

                        -- 增加将领信息
                        local heroInfos = {
                            mainHeroId = _mainHeroId,
                            mainHeroLevel = _mainHeroLevel,
                            deputyHeroId = _deputyHeroId,
                            deputyHeroLevel = _deputyHeroLevel
                        }
                        if objectInfo.rallyHeros[_reinforceRid] then
                            objectInfo.rallyHeros[_reinforceRid][_reinforceArmyIndex] = heroInfos
                        else
                            objectInfo.rallyHeros[_reinforceRid] = {
                                [_reinforceArmyIndex] = heroInfos
                            }
                        end
                    end
                end

                -- 如果之前已经加入过,不再重复统计
                if not objectInfo.leavedRallyHeros[_reinforceRid] or not objectInfo.leavedRallyHeros[_reinforceRid][_reinforceArmyIndex] then
                    -- 增加最大部队数量
                    local armyCountMax = objectInfo.armyCountMax + addSoldierNum
                    -- 更新战报中的最大数量
                    for _, battleWithInfo in pairs(battleScene.objectInfos[_objectIndex].battleWithInfos) do
                        if battleWithInfo.maxArmyCount < armyCountMax then
                            battleWithInfo.maxArmyCount = armyCountMax
                        end
                    end
                    battleScene.objectInfos[_objectIndex].armyCountMax = armyCountMax
                end

                -- 如果是集结部队,增加成员
                if objectInfo.isRally then
                    if not objectInfo.rallyMember[_reinforceRid] then
                        objectInfo.rallyMember[_reinforceRid] = _reinforceArmyIndex
                    end
                end
            end
        end
    end
end

---@see 战斗中减少士兵
function accept.subSoldierOnBattle( _battleIndex, _objectIndex, _soldiers, _sendReportRid, _reinforceRid, _reinforceArmyIndex )
    local battleScene = BattleScenes[_battleIndex]
    if battleScene then
        -- 判断对象是否还存在
        local objectInfo = battleScene.objectInfos[_objectIndex]
        if objectInfo then
            if not objectInfo.exitBattleFlag then
                -- 给角色发送一封战报
                if _sendReportRid and _sendReportRid > 0 then
                    BattleLogic:sendBattleReportOnExitBuild( battleScene, _objectIndex, _sendReportRid )
                end

                -- 扣除士兵
                for _, soldierInfo in pairs( _soldiers ) do
                    if objectInfo.soldiers[soldierInfo.id] then
                        objectInfo.soldiers[soldierInfo.id].num = objectInfo.soldiers[soldierInfo.id].num - soldierInfo.num
                        if objectInfo.soldiers[soldierInfo.id].num <= 0 then
                            objectInfo.soldiers[soldierInfo.id] = nil
                        end
                    end
                end

                -- 如果对象是联盟建筑、圣地、城市,从详细中减少
                if MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType )
                or MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
                or objectInfo.objectType == Enum.RoleType.CITY then
                    if _reinforceArmyIndex == 0 then
                        -- 城市自身的士兵减少
                        local selfSoldiers = objectInfo.rallySoldiers[_reinforceRid][_reinforceArmyIndex]
                        for _, soldierInfo in pairs( _soldiers ) do
                            if selfSoldiers[soldierInfo.id] then
                                selfSoldiers[soldierInfo.id].num = selfSoldiers[soldierInfo.id].num - soldierInfo.num
                                if selfSoldiers[soldierInfo.id].num <= 0 then
                                    selfSoldiers[soldierInfo.id] = nil
                                end
                            end
                        end
                    else
                        if objectInfo.rallySoldiers[_reinforceRid] and objectInfo.rallySoldiers[_reinforceRid][_reinforceArmyIndex] then
                            objectInfo.rallySoldiers[_reinforceRid][_reinforceArmyIndex] = nil
                            if table.empty( objectInfo.rallySoldiers[_reinforceRid] ) then
                                -- 添加到离开队伍中
                                BattleCommon:addLeaveRallyInfo( battleScene, _objectIndex, _reinforceRid, _reinforceArmyIndex )
                                objectInfo.rallySoldiers[_reinforceRid] = nil
                                objectInfo.rallyHeros[_reinforceRid] = nil
                            end
                            -- 部队全部撤出了
                            if table.empty( objectInfo.rallySoldiers ) then
                                objectInfo.soldiers = {}
                            end
                        end
                    end
                end
            end
        end
    end
end

---@see 等待战斗回合结束后转移对象数据并删除战斗
function response.getObjectInfoAfterTurn( _battleIndex )
    if BattleScenes[_battleIndex] then
        -- 标记为被合并
        BattleScenes[_battleIndex].isBattleMerged = true

        while BattleScenes[_battleIndex] and BattleScenes[_battleIndex].isBattleWork do
            skynet.sleep(100) -- sleep 10ms
        end
        if BattleScenes[_battleIndex] then
            -- 返回角色数据
            local objectInfos = BattleScenes[_battleIndex].objectInfos
            local reportUniqueIndex = BattleScenes[_battleIndex].reportUniqueIndex
            BattleScenes[_battleIndex] = nil
            return objectInfos, reportUniqueIndex
        end
    end
end

---@see 对象批量加入到战斗中
function response.multiObjectAddBattle( _battleIndex, _objectInfos, _attackIndex, _defenseIndex, _reportUniqueIndex )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        local objectIndexs = {}
        for objectIndex, objectInfo in pairs(_objectInfos) do
            if not battleScene.objectInfos[objectIndex] then
                objectInfo.lastBattleTurn = battleScene.turn
                battleScene.objectInfos[objectIndex] = objectInfo
                -- 重新计算角色属性
                BattleCacle:cacleObjectAttr( battleScene, objectIndex )
                table.insert( objectIndexs, objectIndex )
            else
                LOG_WARNING("multiObjectAddBattle objectIndex(%d) had exist", objectIndex)
            end
        end

        -- 通知目标切换战斗索引
        Common.rpcMultiSend( battleScene.gameNode, "BattleProxy", "changeBattleIndex", _battleIndex, objectIndexs )

        if battleScene.objectInfos[_attackIndex] and battleScene.objectInfos[_defenseIndex] then
            -- 修改攻击对象
            battleScene.objectInfos[_attackIndex].attackTargetIndex = _defenseIndex
            -- 增加攻击目标
            battleScene.objectInfos[_defenseIndex].allAttackers[_attackIndex] = battleScene.objectInfos[_attackIndex].objectType
        end

        if _reportUniqueIndex and battleScene.reportUniqueIndex < _reportUniqueIndex then
            battleScene.reportUniqueIndex = _reportUniqueIndex
        end

        return true
    end
end

---@see 改变攻击目标
function accept.changeAttackTarget( _battleIndex, _objectIndex, _newTargetIndex )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if not battleScene.objectInfos[_objectIndex] then
            return
        end
        battleScene.objectInfos[_objectIndex].tmpObjectFlag = false
        battleScene.objectInfos[_objectIndex].attackTargetIndex = _newTargetIndex
        -- 加入目标的攻击者中
        if battleScene.objectInfos[_newTargetIndex] then
            battleScene.objectInfos[_newTargetIndex].allAttackers[_objectIndex] = battleScene.objectInfos[_objectIndex].objectType
        end
        -- 同步游戏服务器
        Common.rpcMultiSend( battleScene.gameNode, "BattleProxy", "syncObjectTargetObjectIndex",
                    _objectIndex, battleScene.objectInfos[_objectIndex].objectType, _newTargetIndex, battleScene.objectInfos[_newTargetIndex].objectType )
        return true
    end
end

---@see 对象开始攻击
function accept.removeObjectStopAttack( _battleIndex, _objectIndex )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if not battleScene.objectInfos[_objectIndex] or battleScene.objectInfos[_objectIndex].tmpObjectFlag then
            return
        end

        local attackTargetIndex = battleScene.objectInfos[_objectIndex].attackTargetIndex
        if not battleScene.objectInfos[attackTargetIndex] then
            -- 任意取一个目标
            for targetIndex in pairs(battleScene.objectInfos) do
                if targetIndex ~= _objectIndex then
                    attackTargetIndex = targetIndex
                    -- 加入目标的攻击者中
                    battleScene.objectInfos[targetIndex].allAttackers[_objectIndex] = battleScene.objectInfos[_objectIndex].objectType
                    battleScene.objectInfos[_objectIndex].allAttackers[targetIndex] = battleScene.objectInfos[targetIndex].objectType
                    break
                end
            end
        end

        battleScene.objectInfos[_objectIndex].attackTargetIndex = attackTargetIndex

        -- 同步游服,目标改变
        local inAttackRange = BattleCommon:checkInAttackRange( battleScene, _objectIndex, attackTargetIndex )
        if inAttackRange then
            -- 在攻击距离内才通知目标改变
            Common.rpcMultiSend( battleScene.gameNode, "BattleProxy", "syncObjectTargetObjectIndex",
                    _objectIndex, battleScene.objectInfos[_objectIndex].objectType, attackTargetIndex, battleScene.objectInfos[attackTargetIndex].objectType )
        else
            battleScene.objectInfos[_objectIndex].isOutAttackRange = true
            battleScene.objectInfos[_objectIndex].outAttackRangeIndex = attackTargetIndex
        end
    end
end

---@see 部队加入增援
function accept.armyReinforceJoinBattle( _battleIndex, _reinforceArmyInfo, _objectIndex, _isCityJoin, _isArmyBack )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if battleScene.reinforceJoinArmy[_objectIndex] and battleScene.reinforceLeaveArmy[_objectIndex]
        and table.size( battleScene.reinforceJoinArmy[_objectIndex] ) + table.size( battleScene.reinforceLeaveArmy[_objectIndex] ) >= CFG.s_Config:Get("maxReinforce") then
            return
        end

        if not battleScene.reinforceJoinArmy[_objectIndex] then
            battleScene.reinforceJoinArmy[_objectIndex] = {}
        end

        _reinforceArmyInfo.time = battleScene.turn
        _reinforceArmyInfo.isCityJoin = _isCityJoin
        _reinforceArmyInfo.isArmyBack = _isArmyBack
        table.insert( battleScene.reinforceJoinArmy[_objectIndex], _reinforceArmyInfo )
        -- 加入一条战报记录
        BattleCommon:insertBattleReport( battleScene, _objectIndex, _objectIndex, nil, nil, nil, nil ,nil, true )
    end
end

---@see 部队离开增援
function accept.armyReinforceLeaveBattle( _battleIndex, _reinforceArmyInfo, _objectIndex )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if battleScene.reinforceJoinArmy[_objectIndex] and battleScene.reinforceLeaveArmy[_objectIndex]
        and table.size( battleScene.reinforceJoinArmy[_objectIndex] ) + table.size( battleScene.reinforceLeaveArmy[_objectIndex] ) >= CFG.s_Config:Get("maxReinforce") then
            return
        end

        if not battleScene.reinforceLeaveArmy[_objectIndex] then
            battleScene.reinforceLeaveArmy[_objectIndex] = {}
        end

        _reinforceArmyInfo.time = battleScene.turn
        table.insert( battleScene.reinforceLeaveArmy[_objectIndex], _reinforceArmyInfo )
        -- 加入一条战报记录
        BattleCommon:insertBattleReport( battleScene, _objectIndex, _objectIndex, nil, nil, nil, nil ,nil, true )
    end
end

---@see 对象增加buff
function accept.objectAddBuff( _battleIndex, _objectIndex, _buffIds )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if battleScene.objectInfos[_objectIndex] then
            for _, buffId in pairs(_buffIds) do
                BattleBuff:addBuff( battleScene, _objectIndex, _objectIndex, buffId )
            end
        end
    end
end

---@see 对象移除buff
function accept.objectRemoveBuff( _battleIndex, _objectIndex, _buffIds )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if battleScene.objectInfos[_objectIndex] then
            for _, buffId in pairs(_buffIds) do
                BattleBuff:deleteObjectStatusBuff( battleScene, _objectIndex, 1000, 1, buffId, true )
            end
        end
    end
end

---@see 同步对象状态
function accept.syncObjectStatus( _battleIndex, _objectIndex, _status )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if battleScene.objectInfos[_objectIndex] then
            battleScene.objectInfos[_objectIndex].status = _status
        end
    end
end

---@see 同步对象攻击者.用于站位
function accept.syncAroundAttacker( _battleIndex, _objectIndex )
    if BattleScenes[_battleIndex] then
        local battleScene = BattleScenes[_battleIndex]
        if battleScene.objectInfos[_objectIndex] then
            Common.rpcMultiSend( battleScene.gameNode, "BattleProxy", "syncAroundAttacker", _objectIndex, battleScene.objectInfos[_objectIndex].allAttackers )
        end
    end
end