--[[
 * @file : BattleAttrLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-20 12:00:44
 * @Last Modified time: 2020-04-20 12:00:44
 * @department : Arabic Studio
 * @brief : 战斗属性变化相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BattleCreate = require "BattleCreate"
local ArmyLogic = require "ArmyLogic"
local RoleCacle = require "RoleCacle"
local RoleLogic = require "RoleLogic"

local BattleAttrLogic = {}

---@see 同步地图部队对象属性到战斗服务器
function BattleAttrLogic:syncObjectAttrToBattleServer( _rid )
    local objectAttr = RoleCacle:getRoleBattleAttr( _rid )
    local armyInfos = ArmyLogic:getArmy( _rid )
    for _, armyInfo in pairs(armyInfos) do
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( armyInfo.objectIndex )
        if battleIndex then
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            if battleNode then
                Common.rpcMultiSend( battleNode, "BattleLoop", "syncObjectAttr", battleIndex, armyInfo.objectIndex, objectAttr )
            end
        end
    end
end

---@see 对象属性变更.同步到战斗服务器
function BattleAttrLogic:syncObjectAttrChange( _objectIndex, _rid )
    local objectAttr = RoleCacle:getRoleBattleAttr( _rid )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            Common.rpcMultiSend( battleNode, "BattleLoop", "syncObjectAttr", battleIndex, _objectIndex, objectAttr )
        end
    end
end

---@see 对象统帅变更.同步到战斗服务器
function BattleAttrLogic:syncObjectHeroChange( _objectIndex, _objectType, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _skills, _talentAttr )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            -- 同步技能和统帅
            Common.rpcMultiSend( battleNode, "BattleLoop", "syncObjectHeroAndSkill",
                                    battleIndex, _objectIndex, _mainHeroId, _mainHeroLevel,
                                    _deputyHeroId, _deputyHeroLevel, _skills,_talentAttr )
        end
    end

    if _objectType == Enum.RoleType.ARMY then
        -- 通知到地图部队
        MSM.SceneArmyMgr[_objectIndex].post.syncHeroSkill( _objectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    end
end

---@see 战斗中减少士兵
function BattleAttrLogic:notifyBattleSubSoldier( _objectIndex, _soldiers, _sendReportRid, _reinforceRid, _reinforceArmyIndex )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            Common.rpcMultiSend( battleNode, "BattleLoop", "subSoldierOnBattle", battleIndex, _objectIndex, _soldiers, _sendReportRid, _reinforceRid, _reinforceArmyIndex )
        end
    end
end

---@see 战斗中加入士兵
function BattleAttrLogic:notifyBattleAddSoldier( _objectIndex, _soldiers, _reinforceRid, _reinforceArmyIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            Common.rpcMultiSend( battleNode, "BattleLoop", "addSoldierOnBattle", battleIndex, _objectIndex, _soldiers, _reinforceRid, _reinforceArmyIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
        end
    end
end

---@see 增援加入战斗
function BattleAttrLogic:reinforceJoinBattle( _objectIndex, _reinforceRid, _armyIndex, _armyCount, _isCityJoin, _isArmyBack )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            local roleInfo = RoleLogic:getRole( _reinforceRid, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
            local armyCount = _armyCount or 0
            if armyCount <= 0 and _armyIndex > 0 then
                armyCount = ArmyLogic:getArmySoldierCount( nil, _reinforceRid, _armyIndex )
            end

            local reinforceArmyInfo = {
                name = roleInfo.name,
                headId = roleInfo.headId,
                headFrameID = roleInfo.headFrameID,
                guildId = roleInfo.guildId,
                armyCount = armyCount
            }
            Common.rpcMultiSend( battleNode, "BattleLoop", "armyReinforceJoinBattle", battleIndex, reinforceArmyInfo, _objectIndex, _isCityJoin, _isArmyBack )
        end
    end
end

---@see 增援离开战斗
function BattleAttrLogic:reinforceLeaveBattle( _objectIndex, _reinforceRid, _armyIndex )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            local roleInfo = RoleLogic:getRole( _reinforceRid, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
            local reinforceArmyInfo = {
                name = roleInfo.name,
                headId = roleInfo.headId,
                headFrameID = roleInfo.headFrameID,
                guildId = roleInfo.guildId,
                armyCount = ArmyLogic:getArmySoldierCount( nil, _reinforceRid, _armyIndex )
            }
            Common.rpcMultiSend( battleNode, "BattleLoop", "armyReinforceLeaveBattle", battleIndex, reinforceArmyInfo, _objectIndex )
        end
    end
end

---@see 同步对象状态
function BattleAttrLogic:syncObjectStatus( _objectIndex, _status )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = BattleCreate:getBattleServerNode( battleIndex )
        if battleNode then
            Common.rpcMultiSend( battleNode, "BattleLoop", "syncObjectStatus", battleIndex, _objectIndex, _status )
        end
    end
end

return BattleAttrLogic