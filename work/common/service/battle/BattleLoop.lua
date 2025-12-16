--[[
* @file : BattleLoop.lua
* @type : service
* @author : linfeng
* @created : Wed Nov 22 2017 10:18:07 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 战斗循环服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local BattleDef = require "BattleDef"
local AttrDef = require "AttrDef"
local BattleCacle = require "BattleCacle"
local BattleCommon = require "BattleCommon"
local BattleBuff = require "BattleBuff"

function init( index )
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

function response.Init()
    -- body
end

---@see 创建一场战斗
---@param _objectInfos table 战斗组信息
---@return boolean
function response.CreateBattle( _, _gameNode, _objectInfos )
    local battleIndex = SM.BattleIndexMgr.req.newBattleIndex()
    -- 初始化战斗场景
    local battleScene = BattleDef:getDefaultBattleScene()
    -- 战斗索引
    battleScene.battleIndex = battleIndex
    -- 游戏节点
    battleScene.gameNode = _gameNode
    -- 下次战斗时间
    battleScene.nextTick = os.time()
    -- 战斗记录战报回合
    battleScene.nextRecordTurn = 1

    -- 初始化战斗对象信息
    for objectIndex, objectInfo in pairs(_objectInfos) do
        -- 创建默认的战斗对象信息
        local defaultObjectInfo = BattleDef:getDefaultBattleObjectInfo()
        -- 初始化属性
        defaultObjectInfo.objectIndex = objectIndex
        if not objectInfo.objectAttr then
            objectInfo.objectAttr = AttrDef:getDefaultBattleAttr()
        end
        defaultObjectInfo.objectAttr = objectInfo.objectAttr
        defaultObjectInfo.objectAttrRaw = table.copy( objectInfo.objectAttr, true )
        defaultObjectInfo.soldiers = objectInfo.soldiers
        defaultObjectInfo.guildId = objectInfo.guildId or 0
        defaultObjectInfo.mainHeroId = objectInfo.mainHeroId or 0
        defaultObjectInfo.deputyHeroId = objectInfo.deputyHeroId or 0
        defaultObjectInfo.mainHeroLevel = objectInfo.mainHeroLevel or 0
        defaultObjectInfo.deputyHeroLevel = objectInfo.deputyHeroLevel or 0
        defaultObjectInfo.objectRid = objectInfo.rid or 0
        defaultObjectInfo.beginArmyCount = objectInfo.armyCount
        defaultObjectInfo.attackTargetIndex = objectInfo.attackTargetIndex
        defaultObjectInfo.objectType = objectInfo.objectType
        defaultObjectInfo.monsterId = objectInfo.monsterId or 0
        defaultObjectInfo.pos = objectInfo.pos or {}
        defaultObjectInfo.level = objectInfo.level or 0
        defaultObjectInfo.skills = objectInfo.skills or {}
        defaultObjectInfo.rawSkills = objectInfo.skills or {}
        defaultObjectInfo.angle = objectInfo.targetAngle or 0
        defaultObjectInfo.maxSp = objectInfo.maxSp or 0
        defaultObjectInfo.isRally = objectInfo.isRally or false
        defaultObjectInfo.rallySoldiers = objectInfo.rallySoldiers or {}
        defaultObjectInfo.rallyHeros = objectInfo.rallyHeros or {}
        defaultObjectInfo.armyRadius = objectInfo.armyRadius or 0
        defaultObjectInfo.holyLandMonsterId = objectInfo.holyLandMonsterId or 0
        defaultObjectInfo.holyLandBuildMonsterId = objectInfo.holyLandBuildMonsterId or 0
        defaultObjectInfo.rallyLeader = objectInfo.rallyLeader or 0
        defaultObjectInfo.rallyMember = objectInfo.rallyMember or {}
        defaultObjectInfo.staticId = objectInfo.staticId or 0
        defaultObjectInfo.armyCountMax = objectInfo.armyCountMax or BattleCommon:getArmySoldierCount( defaultObjectInfo )
        if defaultObjectInfo.armyCountMax <= 0 then
            defaultObjectInfo.armyCountMax = 1
        end
        defaultObjectInfo.talentAttr = objectInfo.talentAttr or {}
        defaultObjectInfo.equipAttr = objectInfo.equipAttr or {}
        defaultObjectInfo.status = objectInfo.status or 0
        defaultObjectInfo.buffs = objectInfo.battleBuff or {}
        defaultObjectInfo.tmpObjectFlag = false
        defaultObjectInfo.armyIndex = objectInfo.armyIndex or 0
        defaultObjectInfo.objectCityPos = objectInfo.objectCityPos or {}
        defaultObjectInfo.isCheckPointMonster = objectInfo.isCheckPointMonster or false
        -- 战斗开始时间
        defaultObjectInfo.battleBeginTime = os.time()

        -- 加入对象信息
        battleScene.objectInfos[objectIndex] = defaultObjectInfo
    end

    for objectIndex, battleObjectInfo in pairs(battleScene.objectInfos) do
        -- 添加快照
        if battleScene.objectInfos[battleObjectInfo.attackTargetIndex] then
            battleObjectInfo.attackObjectSnapShot = BattleCommon:copyObjectInfo( battleScene, battleObjectInfo.attackTargetIndex )
        end
        -- 添加Buff
        BattleBuff:addObjectBuffOnCreate( battleScene, objectIndex )
        -- 重新计算角色属性
        BattleCacle:cacleObjectAttr( battleScene, objectIndex )
    end

    -- 加入到场景管理
    MSM.BattleSceneMgr[battleIndex].req.addBattleScene( battleIndex, battleScene )
    return battleIndex
end

---@see 对象加入战斗
function response.JoinBattle( _battleIndex, _objectIndex, _objectInfo, _targetIndex )
    -- 创建默认的战斗对象信息
    local defaultObjectInfo = BattleDef:getDefaultBattleObjectInfo()
    -- 初始化属性
    defaultObjectInfo.objectIndex = _objectIndex
    if not _objectInfo.objectAttr then
        _objectInfo.objectAttr = AttrDef:getDefaultBattleAttr()
    end
    defaultObjectInfo.objectAttr = _objectInfo.objectAttr
    defaultObjectInfo.objectAttrRaw = table.copy( _objectInfo.objectAttr, true )
    defaultObjectInfo.soldiers = _objectInfo.soldiers
    defaultObjectInfo.guildId = _objectInfo.guildId or 0
    defaultObjectInfo.mainHeroId = _objectInfo.mainHeroId or 0
    defaultObjectInfo.deputyHeroId = _objectInfo.deputyHeroId or 0
    defaultObjectInfo.mainHeroLevel = _objectInfo.mainHeroLevel or 0
    defaultObjectInfo.deputyHeroLevel = _objectInfo.deputyHeroLevel or 0
    defaultObjectInfo.objectRid = _objectInfo.rid or 0
    defaultObjectInfo.beginArmyCount = _objectInfo.armyCount
    defaultObjectInfo.attackTargetIndex = _targetIndex
    defaultObjectInfo.objectType = _objectInfo.objectType
    defaultObjectInfo.monsterId = _objectInfo.monsterId or 0
    defaultObjectInfo.pos = _objectInfo.pos or {}
    defaultObjectInfo.level = _objectInfo.level or 0
    defaultObjectInfo.skills = _objectInfo.skills or {}
    defaultObjectInfo.rawSkills = _objectInfo.skills or {}
    defaultObjectInfo.angle = _objectInfo.targetAngle or 0
    defaultObjectInfo.maxSp = _objectInfo.maxSp or 0
    defaultObjectInfo.isRally = _objectInfo.isRally or false
    defaultObjectInfo.rallySoldiers = _objectInfo.rallySoldiers or {}
    defaultObjectInfo.rallyHeros = _objectInfo.rallyHeros or {}
    defaultObjectInfo.armyRadius = _objectInfo.armyRadius or 0
    defaultObjectInfo.holyLandMonsterId = _objectInfo.holyLandMonsterId or 0
    defaultObjectInfo.holyLandBuildMonsterId = _objectInfo.holyLandBuildMonsterId or 0
    defaultObjectInfo.rallyLeader = _objectInfo.rallyLeader or 0
    defaultObjectInfo.rallyMember = _objectInfo.rallyMember or {}
    defaultObjectInfo.staticId = _objectInfo.staticId or 0
    defaultObjectInfo.talentAttr = _objectInfo.talentAttr or {}
    defaultObjectInfo.equipAttr = _objectInfo.equipAttr or {}
    defaultObjectInfo.armyCountMax = _objectInfo.armyCountMax or BattleCommon:getArmySoldierCount( defaultObjectInfo )
    if defaultObjectInfo.armyCountMax <= 0 then
        defaultObjectInfo.armyCountMax = 1
    end
    defaultObjectInfo.status = _objectInfo.status or 0
    defaultObjectInfo.buffs = _objectInfo.battleBuff or {}
    defaultObjectInfo.tmpObjectFlag = false
    defaultObjectInfo.armyIndex = _objectInfo.armyIndex or 0
    defaultObjectInfo.objectCityPos = _objectInfo.objectCityPos or {}
    defaultObjectInfo.isCheckPointMonster = _objectInfo.isCheckPointMonster or false

    -- 战斗开始时间
    defaultObjectInfo.battleBeginTime = os.time()

    -- 加入对象信息
    return MSM.BattleSceneMgr[_battleIndex].req.objectJoinBattle( _battleIndex, _objectIndex, defaultObjectInfo, _targetIndex )
end

---@see 合并两个战斗
function response.mergeBattle( _battleIndex, _deleteBattleIndex, _attackIndex, _defenseIndex )
    local mergeObjectInfos, reportUniqueIndex = MSM.BattleSceneMgr[_deleteBattleIndex].req.getObjectInfoAfterTurn( _deleteBattleIndex )
    if mergeObjectInfos then
        return MSM.BattleSceneMgr[_battleIndex].req.multiObjectAddBattle( _battleIndex, mergeObjectInfos, _attackIndex, _defenseIndex, reportUniqueIndex )
    end
end

---@see 对象退出战斗
function accept.objectExitBattle( _battleIndex, _objectIndex )
    MSM.BattleSceneMgr[_battleIndex].req.objectExitBattle( _battleIndex, _objectIndex )
end

---@see 对象退出战斗
function response.objectExitBattle( _battleIndex, _objectIndex, _leaderArmyNoEnter )
    MSM.BattleSceneMgr[_battleIndex].req.objectExitBattle( _battleIndex, _objectIndex, true, _leaderArmyNoEnter )
end

---@see 对象退出战斗.用于关服时
function response.objectExitBattleOnClose( _battleIndex, _objectIndex )
    MSM.BattleSceneMgr[_battleIndex].req.objectExitBattle( _battleIndex, _objectIndex )
end

---@see 更新目标位置
function accept.updateObjectPos( _battleIndex, _objectIndex, _pos, _angle )
    MSM.BattleSceneMgr[_battleIndex].post.updateObjectPos( _battleIndex, _objectIndex, _pos, _angle )
end

---@see 更改攻击目标
function accept.changeAttackTarget( _battleIndex, _objectIndex, _newTargetIndex )
    MSM.BattleSceneMgr[_battleIndex].post.changeAttackTarget( _battleIndex, _objectIndex, _newTargetIndex )
end

---@see 对象开始攻击
function accept.removeObjectStopAttack( _battleIndex, _objectIndex )
    MSM.BattleSceneMgr[_battleIndex].post.removeObjectStopAttack( _battleIndex, _objectIndex )
end

---@see 同步对象属性
function accept.syncObjectAttr( _battleIndex, _objectIndex, _objectAttr )
    MSM.BattleSceneMgr[_battleIndex].post.syncObjectAttr( _battleIndex, _objectIndex,_objectAttr )
end

---@see 更新对象主副将以及技能
function accept.syncObjectHeroAndSkill( _battleIndex, _objectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _skills, _talentAttr )
    MSM.BattleSceneMgr[_battleIndex].post.syncObjectHeroAndSkill( _battleIndex, _objectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _skills, _talentAttr )
end

---@see 战斗中加入士兵
function accept.addSoldierOnBattle( _battleIndex, _objectIndex, _soldiers, _reinforceRid, _reinforceArmyIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    MSM.BattleSceneMgr[_battleIndex].post.addSoldierOnBattle( _battleIndex, _objectIndex, _soldiers, _reinforceRid, _reinforceArmyIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
end

---@see 战斗中减少士兵
function accept.subSoldierOnBattle( _battleIndex, _objectIndex, _soldiers, _sendReportRid, _reinforceRid, _reinforceArmyIndex )
    MSM.BattleSceneMgr[_battleIndex].post.subSoldierOnBattle( _battleIndex, _objectIndex, _soldiers, _sendReportRid, _reinforceRid, _reinforceArmyIndex )
end

---@see 对象删除战斗.用于远征
function accept.objectDeleteBattleOnExpedition( _battleIndex )
    MSM.BattleSceneMgr[_battleIndex].req.deleteBattleScene( _battleIndex)
end

---@see 部队加入增援
function accept.armyReinforceJoinBattle( _battleIndex, _reinforceArmyInfo, _objectIndex, _isCityJoin, _isArmyBack )
    MSM.BattleSceneMgr[_battleIndex].post.armyReinforceJoinBattle( _battleIndex, _reinforceArmyInfo, _objectIndex, _isCityJoin, _isArmyBack )
end

---@see 部队离开增援
function accept.armyReinforceLeaveBattle( _battleIndex, _reinforceArmyInfo, _objectIndex )
    MSM.BattleSceneMgr[_battleIndex].post.armyReinforceLeaveBattle( _battleIndex, _reinforceArmyInfo, _objectIndex )
end

---@see 对象增加buff
function accept.objectAddBuff( _battleIndex, _objectIndex, _buffIds )
    MSM.BattleSceneMgr[_battleIndex].post.objectAddBuff( _battleIndex, _objectIndex, _buffIds )
end

---@see 对象移除buff
function accept.objectRemoveBuff( _battleIndex, _objectIndex, _buffIds )
    MSM.BattleSceneMgr[_battleIndex].post.objectRemoveBuff( _battleIndex, _objectIndex, _buffIds )
end

---@see 同步对象状态
function accept.syncObjectStatus( _battleIndex, _objectIndex, _status )
    MSM.BattleSceneMgr[_battleIndex].post.syncObjectStatus( _battleIndex, _objectIndex, _status )
end

---@see 同步对象攻击者.用于调整位置
function accept.syncAroundAttacker( _battleIndex, _objectIndex )
    MSM.BattleSceneMgr[_battleIndex].post.syncAroundAttacker( _battleIndex, _objectIndex )
end