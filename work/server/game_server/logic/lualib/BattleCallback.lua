--[[
 * @file : BattleCallback.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-02-24 10:57:09
 * @Last Modified time: 2020-02-24 10:57:09
 * @department : Arabic Studio
 * @brief : 战斗回调处理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local HospitalLogic = require "HospitalLogic"
local ItemLogic = require "ItemLogic"
local RoleLogic = require "RoleLogic"
local ArmyTrainLogic = require "ArmyTrainLogic"
local BattleReport = require "BattleReport"
local TaskLogic = require "TaskLogic"
local RoleSync = require "RoleSync"
local ArmyLogic = require "ArmyLogic"
local HeroLogic = require "HeroLogic"
local BuildingLogic = require "BuildingLogic"
local EmailLogic = require "EmailLogic"
local MapObjectLogic = require "MapObjectLogic"
local MonsterCityLogic = require "MonsterCityLogic"
local ResourceLogic = require "ResourceLogic"
local Random = require "Random"
local MonumentLogic = require "MonumentLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"
local RallyLogic = require "RallyLogic"
local RepatriationLogic = require "RepatriationLogic"
local MapLogic = require "MapLogic"
local MonsterLogic = require "MonsterLogic"
local BattleAttrLogic = require "BattleAttrLogic"
local GuildLogic = require "GuildLogic"
local RankLogic = require "RankLogic"
local SoldierLogic = require "SoldierLogic"
local ArmyMarchLogic = require "ArmyMarchLogic"

local BattleCallback = {}

---@see 处理对象退出战斗
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchObjectExitBattle( _exitArg )
    LOG_DEBUG("dispatchObjectExitBattle objectIndex(%d) exit battle", _exitArg.objectIndex)

    local ret, err
    -- 移除对象战斗状态
    ret, err = xpcall( self.deleteObjectBattleStatus, debug.traceback, self, _exitArg )
    if not ret then
        LOG_ERROR("deleteObjectBattleStatus err:%s", err)
    end

    if _exitArg.objectType == Enum.RoleType.EXPEDITION then
        self:dispatchExpedition( _exitArg )
    else
        -- 处理轻伤
        ret, err = xpcall(self.dispatchMinorSoldier, debug.traceback, self, _exitArg )
        if not ret then
            LOG_ERROR("dispatchMinorSoldier err:%s", err)
        end
        -- 处理击杀数量
        ret, err = xpcall(self.dispatchKillCount, debug.traceback, self, _exitArg )
        if not ret then
            LOG_ERROR("dispatchKillCount err:%s", err)
        end
        -- 野蛮人掉落计算
        local monsterRet, monsterReward, killExp = xpcall(self.dispatchMonsterDrop, debug.traceback, self, _exitArg )
        if not monsterRet then
            LOG_ERROR("dispatchMonsterDrop err:%s", monsterReward)
            monsterReward = nil
            killExp = 0
        end
        -- 野蛮人城寨掉落计算
        local monsterCityRet, monsterCityErr = xpcall( self.dispatchMonsterCityDrop, debug.traceback, self, _exitArg )
        if not monsterCityRet then
            LOG_ERROR("dispatchMonsterCityDrop err:%s", monsterCityErr)
        end
        -- 圣地守护者掉落计算
        local guardHolyLandRet
        guardHolyLandRet, killExp = xpcall( self.dispatchGuardHolyLandDrop, debug.traceback, self, _exitArg, killExp )
        if not guardHolyLandRet then
            LOG_ERROR("dispatchGuardHolyLandDrop err:%s", killExp)
            killExp = 0
        end
        -- 计算攻城掠夺
        local plunderRet
        plunderRet, monsterReward = xpcall( self.dispatchPlunder, debug.traceback, self, _exitArg, monsterReward )
        if not plunderRet then
            LOG_ERROR("dispatchPlunder err:%s", monsterReward)
            monsterReward = nil
        end
        if monsterRet and monsterCityRet and guardHolyLandRet and plunderRet then
            -- 生成战报
            ret, err = xpcall(self.dispatchBattleReport, debug.traceback, self, _exitArg, monsterReward, killExp )
            if not ret then
                LOG_ERROR("dispatchBattleReport err:%s", err)
            end
        end
        -- 处理角色任务统计信息
        ret, err = xpcall(self.dispatchRoleStatistics, debug.traceback, self, _exitArg )
        if not ret then
            LOG_ERROR("dispatchRoleStatistics err:%s", err)
        end
        -- 处理军队溃败
        ret, err = xpcall(self.dispatchDefeat, debug.traceback, self, _exitArg )
        if not ret then
            LOG_ERROR("dispatchDefeat err:%s", err)
        end
        -- 处理目标方位
        ret, err = xpcall( self.dispatchAroundPos, debug.traceback, self, _exitArg )
        if not ret then
            LOG_ERROR("dispatchAroundPos err:%s", err)
        end
    end

    -- 停止追击
    ArmyWalkLogic:notifyEndFollowUp( _exitArg.objectIndex, _exitArg.objectType )
end

---@see 处理目标退战斗后的方位清理
---@param __exitArg defaultExitBattleArgClass
function BattleCallback:dispatchAroundPos( _exitArg )
    MSM.AttackAroundPosMgr[_exitArg.attackTargetIndex].post.delAttacker( _exitArg.attackTargetIndex, _exitArg.objectIndex )
end

---@see 处理集结部队的重伤.死亡
function BattleCallback:dispatchRallyArmySoldier( _rid, _objectIndex, _rallySoldierHurt )
    if _rallySoldierHurt then
        local hospitalDieInfo = {}
        for rallyRid, rallySoldierHurtInfo in pairs(_rallySoldierHurt) do
            for _, soldierHurt in pairs(rallySoldierHurtInfo) do
                self:dispatchArmySoldier( _rid, _objectIndex, soldierHurt, rallyRid, hospitalDieInfo )
            end
        end
        return hospitalDieInfo
    end
end

---@see 处理部队重伤.死亡
function BattleCallback:dispatchArmySoldier( _rid, _objectIndex, _soldierHurt, _rallyRid, _hospitalDieInfo )
    local hardHurtSum = 0
    local dieSum = 0
    local minorSum = 0
    local tmpSoldierInfo = {}
    local dieSoldierInfo = {}
    local armyIndex
    local armySoldiers, minorSoldiers
    local armyObjectInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
    if not armyObjectInfo then
        return
    end

    local armyInfo
    if not _rallyRid then
        armyInfo = ArmyLogic:getArmy( _rid, armyObjectInfo.armyIndex, { Enum.Army.soldiers, Enum.Army.minorSoldiers } )
        armySoldiers = armyInfo.soldiers
        minorSoldiers = armyInfo.minorSoldiers
        armyIndex = armyObjectInfo.armyIndex
    else
        armyInfo = ArmyLogic:getArmy( _rallyRid, armyObjectInfo.rallyArmy[_rallyRid], { Enum.Army.soldiers, Enum.Army.minorSoldiers } )
        armySoldiers = armyInfo.soldiers
        minorSoldiers = armyInfo.minorSoldiers
        _rid = _rallyRid
        armyIndex = armyObjectInfo.rallyArmy[_rallyRid]
    end

    if not armySoldiers then
        return
    end

    for soldierId, hurtInfo in pairs( _soldierHurt or {} ) do
        -- 重伤
        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
            if armySoldiers[soldierId] and armySoldiers[soldierId].num > 0 then
                if armySoldiers[soldierId].num - hurtInfo.hardHurt < 0 then
                    hurtInfo.hardHurt = armySoldiers[soldierId].num
                end
                armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.hardHurt
                if armySoldiers[soldierId].num < 0 then
                    armySoldiers[soldierId].num = 0
                end
                hardHurtSum = hardHurtSum + hurtInfo.hardHurt
                tmpSoldierInfo[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
            end
        end

        -- 阵亡
        if hurtInfo.die and hurtInfo.die > 0 then
            dieSum = dieSum + hurtInfo.die
            dieSoldierInfo[soldierId] = hurtInfo.die
            hardHurtSum = hardHurtSum + hurtInfo.die
            if armySoldiers[soldierId] and armySoldiers[soldierId].num > 0 then
                if armySoldiers[soldierId].num - hurtInfo.die < 0 then
                    hurtInfo.die = armySoldiers[soldierId].num
                end
                armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.die
                if armySoldiers[soldierId].num < 0 then
                    armySoldiers[soldierId].num = 0
                end
            end
        end

        -- 轻伤
        if hurtInfo.minor and hurtInfo.minor > 0 then
            minorSum = minorSum + hurtInfo.minor
            if armySoldiers[soldierId] then
                if armySoldiers[soldierId].num - hurtInfo.minor < 0 then
                    hurtInfo.minor = armySoldiers[soldierId].num
                end
                armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.minor
                if not minorSoldiers[soldierId] then
                    minorSoldiers[soldierId] = {
                        id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.minor
                    }
                else
                    minorSoldiers[soldierId].num = minorSoldiers[soldierId].num + hurtInfo.minor
                end
            end
        end

        dieSoldierInfo[soldierId] = ( dieSoldierInfo[soldierId] or 0 ) + ( hurtInfo.hardHurt or 0 ) or ( hurtInfo.die or 0 )
    end

    -- 重伤的回医院
    local soldierDieInfo = HospitalLogic:addToHospital( _rid, tmpSoldierInfo )

    local hospitalDieInfo = _hospitalDieInfo or {}
    hospitalDieInfo[_rid] = {}
    hospitalDieInfo[_rid][armyIndex] = soldierDieInfo.dead or {}

    -- 如果有死亡的,加入到死亡中
    if soldierDieInfo.dead then
        for _, info in pairs(soldierDieInfo.dead) do
            dieSum = dieSum + info.num
        end
    end

    if _rid and _rid > 0 then
        if hardHurtSum > 0 or minorSum > 0 then
            -- 更新部队士兵数量
            ArmyLogic:setArmy( _rid, armyIndex, { [Enum.Army.soldiers] = armySoldiers, [Enum.Army.minorSoldiers] = minorSoldiers } )
            -- 通知客户端部队士兵数量
            ArmyLogic:syncArmy( _rid, armyIndex, { [Enum.Army.soldiers] = armySoldiers, [Enum.Army.minorSoldiers] = minorSoldiers }, true )
            -- 计算角色当前战力,轻伤不影响战斗力计算
            if hardHurtSum > 0 then
                RoleLogic:cacleSyncHistoryPower( _rid )
            end
        end

        if dieSum > 0 then
            -- 增加重伤阵亡累计统计
            RoleLogic:addRoleStatistics( _rid, Enum.RoleStatisticsType.DEAD_SOLDIER, dieSum )
        end

        -- 添加战损累计
        MSM.BattleLosePowerMgr[_rid].post.addRoleBattleLosePower( _rid, _soldierHurt )
    end

    if ArmyLogic:checkArmyStatus( armyObjectInfo.status, Enum.ArmyStatus.REINFORCE_MARCH ) then
        -- 增援行军、驻守中
        local guildId = armyObjectInfo.guildId or 0
        if MapObjectLogic:checkIsGuildBuildObject( armyObjectInfo.targetObjectType ) then
            -- 增援联盟建筑,同步
            if guildId > 0 then
                local buildArmy =  {
                    buildArmyIndex = armyObjectInfo.buildArmyIndex,
                    rid = _rid,
                    armyIndex = armyObjectInfo.armyIndex,
                    soldiers = armySoldiers,
                }
                MSM.GuildMgr[guildId].post.syncBuildArmySoldiers( guildId, armyObjectInfo.targetObjectIndex, armyObjectInfo.buildArmyIndex, buildArmy )
            end
        elseif MapObjectLogic:checkIsHolyLandObject( armyObjectInfo.targetObjectType ) then
            -- 增援圣地关卡，同步士兵信息
            if guildId > 0 then
                local buildArmy =  {
                    buildArmyIndex = armyObjectInfo.buildArmyIndex,
                    rid = _rid,
                    armyIndex = armyObjectInfo.armyIndex,
                    soldiers = armySoldiers,
                }
                MSM.GuildMgr[guildId].post.syncBuildArmySoldiers( guildId, armyObjectInfo.targetObjectIndex, armyObjectInfo.buildArmyIndex, buildArmy )
            end
        elseif armyObjectInfo.targetObjectType == Enum.RoleType.ARMY then
            -- 增援集结部队, 更新联盟战争信息
            local targetArmyInfo = MSM.SceneArmyMgr[armyObjectInfo.targetObjectIndex].req.getArmyInfo( armyObjectInfo.targetObjectIndex )
            MSM.RallyMgr[guildId].post.updateReinforceRoleSoldiers( guildId, targetArmyInfo.rid, _rid, armySoldiers )
        end
    elseif ArmyLogic:checkArmyStatus( armyObjectInfo.status, Enum.ArmyStatus.RALLY_JOIN_MARCH ) then
        -- 部队加入集结行军中, 更新联盟战争信息
        local targetInfo = MSM.MapObjectTypeMgr[armyObjectInfo.targetObjectIndex].req.getObjectInfo( armyObjectInfo.targetObjectIndex )
        RallyLogic:syncRallyArmySoldiers( armyObjectInfo.guildId, targetInfo.rid, _rid, armySoldiers )
    end
    return hospitalDieInfo
end

---@see 处理怪物重伤.死亡处理
function BattleCallback:dispatchMonsterSoldier( _rid, _objectIndex, _soldierHurt )
    local allHurtAndDie = {}
    for soldierId, hurtInfo in pairs(_soldierHurt) do
        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.hardHurt
            end
        end
        if hurtInfo.die and hurtInfo.die > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.die }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.die
            end
        end
        if hurtInfo.minor and hurtInfo.minor > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.minor }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.minor
            end
        end
    end

    -- 更新怪物部队数量
    MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterSoldier( _objectIndex, allHurtAndDie )
end

---@see 处理野蛮人城寨重伤.死亡
function BattleCallback:dispatchMonsterCitySoldier( _rid, _objectIndex, _soldierHurt )
    local allHurtAndDie = {}
    for soldierId, hurtInfo in pairs(_soldierHurt) do
        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.hardHurt
            end
        end
        if hurtInfo.die and hurtInfo.die > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.die }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.die
            end
        end
    end

    -- 更新怪物部队数量
    MSM.SceneMonsterCityMgr[_objectIndex].post.updateMonsterCitySoldier( _objectIndex, allHurtAndDie )
end

---@see 处理城市自身的重伤.死亡
function BattleCallback:dispatchCitySelfSoldier( _rid, _objectIndex, _soldierHurt, _hospitalDieInfo )
    local toHospitolSoldierInfo = {}
    local oldGuardTowerHp = RoleLogic:getRole( _rid, Enum.Role.guardTowerHp ) or 1
    local guardTowerHp = oldGuardTowerHp
    local subSoldierInfo = {} -- 减少的士兵信息
    local addSoldierInfo = {} -- 添加的士兵信息

    -- 处理重伤和死亡
    for soldierId, hurtInfo in pairs(_soldierHurt) do
        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
            if hurtInfo.type == Enum.ArmyType.GUARD_TOWER then
                -- 警戒塔,直接扣血
                guardTowerHp = guardTowerHp - hurtInfo.hardHurt
            else
                if not subSoldierInfo[soldierId] then
                    subSoldierInfo[soldierId] = { id = soldierId, num = 0, type = hurtInfo.type, level = hurtInfo.level, minor = 0 }
                end
                -- 非警戒塔
                if hurtInfo.die and hurtInfo.die > 0 then
                    -- 死亡,直接扣士兵
                    subSoldierInfo[soldierId].num = subSoldierInfo[soldierId].num + hurtInfo.die
                end
                if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
                    -- 重伤,直接扣士兵
                    subSoldierInfo[soldierId].num = subSoldierInfo[soldierId].num + hurtInfo.hardHurt
                end

                -- 重伤的士兵回医院
                toHospitolSoldierInfo[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
            end
        end

        if hurtInfo.minor and hurtInfo.minor > 0 then
            if hurtInfo.type == Enum.ArmyType.GUARD_TOWER then
                -- 警戒塔,直接扣血
                guardTowerHp = guardTowerHp - hurtInfo.minor
            end
        end
    end

    -- 同步警戒塔血量
    if oldGuardTowerHp ~= guardTowerHp then
        if guardTowerHp < 0 then
            guardTowerHp = 0
        end
        RoleLogic:setRole( _rid, Enum.Role.guardTowerHp, guardTowerHp )
        RoleSync:syncSelf( _rid, { [Enum.Role.guardTowerHp] = guardTowerHp }, true )
    end

    -- 重伤的回医院
    local soldierDieInfo = HospitalLogic:addToHospital( _rid, toHospitolSoldierInfo )
    local hospitalDieInfo = _hospitalDieInfo or {}
    hospitalDieInfo[_rid] = {}
    hospitalDieInfo[_rid][0] = soldierDieInfo.dead or {}

    -- 如果有死亡的,加入到死亡中
    if soldierDieInfo.dead then
        for soldierId, soldierInfo in pairs(soldierDieInfo.dead) do
            if _soldierHurt[soldierId] then
                _soldierHurt[soldierId].die = _soldierHurt[soldierId].die + soldierInfo.num
            else
                _soldierHurt[soldierId] = { die = soldierInfo.num }
            end
        end
    end

    -- 城市,轻伤回部队
    for soldierId, hurtInfo in pairs(_soldierHurt) do
        if hurtInfo.minor and hurtInfo.minor > 0 then
            -- 非警戒塔
            if hurtInfo.type ~= Enum.ArmyType.GUARD_TOWER then
                if not subSoldierInfo[soldierId] then
                    subSoldierInfo[soldierId] = { id = soldierId, num = 0, minor = 0 }
                end
                if not addSoldierInfo[soldierId] then
                    addSoldierInfo[soldierId] = { id = soldierId, num = 0, minor = 0 }
                end
                -- 士兵,标记为轻伤
                subSoldierInfo[soldierId].num = subSoldierInfo[soldierId].num + hurtInfo.minor
                addSoldierInfo[soldierId].minor = addSoldierInfo[soldierId].minor + hurtInfo.minor
            end
        end
    end

    -- 计算角色当前战力
    RoleLogic:cacleSyncHistoryPower( _rid )
    -- 减少士兵
    SoldierLogic:subSoldier( _rid, subSoldierInfo )
    -- 增加轻伤士兵
    SoldierLogic:addSoldier( _rid, addSoldierInfo )
    -- 添加战损累计
    MSM.BattleLosePowerMgr[_rid].post.addRoleBattleLosePower( _rid, _soldierHurt )

    return hospitalDieInfo
end

---@see 处理远征重伤.死亡
function BattleCallback:dispatchExpeditionArmySoldier( _rid, _objectIndex, _soldierHurt )
    local allHurtAndDie = {}
    for soldierId, hurtInfo in pairs(_soldierHurt) do
        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.hardHurt
            end
        end
        if hurtInfo.die and hurtInfo.die > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.die }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.die
            end
        end
        if hurtInfo.minor and hurtInfo.minor > 0 then
            if not allHurtAndDie[soldierId] then
                allHurtAndDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.minor }
            else
                allHurtAndDie[soldierId].num = allHurtAndDie[soldierId].num + hurtInfo.minor
            end
        end
    end

    -- 更新怪物部队数量
    MSM.SceneExpeditionMgr[_objectIndex].post.updateSoldier( _objectIndex, allHurtAndDie, true )
end

---@see 处理城市增援重伤.死亡处理.实际实现
function BattleCallback:dispatchCityReinforceSoldierImpl( _rid, _reinforceRid, _soldierHurt, _objectIndex, _hospitalDieInfo )
    -- 是否有此增援部队
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces )
    -- 增援未达到无法参战
    if not reinforces[_reinforceRid] or reinforces[_reinforceRid].arrivalTime > os.time() then
        return
    end

    -- 处理伤亡
    local hurtDieSoldierInfo = {}
    local minorSoldiers = ArmyLogic:getArmy( _reinforceRid, reinforces[_reinforceRid].armyIndex, Enum.Army.minorSoldiers ) or {}
    for soldierId, hurtInfo in pairs(_soldierHurt) do
        -- 重伤
        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
            if reinforces[_reinforceRid].soldiers[soldierId] then
                if reinforces[_reinforceRid].soldiers[soldierId].num - hurtInfo.hardHurt < 0 then
                    hurtInfo.hardHurt =reinforces[_reinforceRid].soldiers[soldierId].num
                end
                reinforces[_reinforceRid].soldiers[soldierId].num = reinforces[_reinforceRid].soldiers[soldierId].num - hurtInfo.hardHurt
                if reinforces[_reinforceRid].soldiers[soldierId].num <= 0 then
                    reinforces[_reinforceRid].soldiers[soldierId] = nil
                end
                if not hurtDieSoldierInfo[soldierId] then
                    hurtDieSoldierInfo[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
                else
                    hurtDieSoldierInfo[soldierId].num = hurtDieSoldierInfo[soldierId].num + hurtInfo.hardHurt
                end
            end
        end
        -- 死亡
        if hurtInfo.die and hurtInfo.die > 0 then
            if reinforces[_reinforceRid].soldiers[soldierId] then
                reinforces[_reinforceRid].soldiers[soldierId].num = reinforces[_reinforceRid].soldiers[soldierId].num - hurtInfo.die
                if reinforces[_reinforceRid].soldiers[soldierId].num <= 0 then
                    reinforces[_reinforceRid].soldiers[soldierId] = nil
                end
            end
        end
        -- 轻伤
        if hurtInfo.minor and hurtInfo.minor then
            if reinforces[_reinforceRid].soldiers[soldierId] then
                if reinforces[_reinforceRid].soldiers[soldierId].num - hurtInfo.minor < 0 then
                    hurtInfo.minor = reinforces[_reinforceRid].soldiers[soldierId].num
                end
                reinforces[_reinforceRid].soldiers[soldierId].num = reinforces[_reinforceRid].soldiers[soldierId].num - hurtInfo.minor
                if reinforces[_reinforceRid].soldiers[soldierId].num <= 0 then
                    reinforces[_reinforceRid].soldiers[soldierId] = nil
                end
                -- 更新部队轻伤
                if not minorSoldiers[soldierId] then
                    minorSoldiers[soldierId] = {
                        id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.minor
                    }
                else
                    minorSoldiers[soldierId].num = minorSoldiers[soldierId].num + hurtInfo.minor
                end
            end
        end
    end
    -- 重伤回医院
    local soldierDieInfo = HospitalLogic:addToHospital( _reinforceRid, hurtDieSoldierInfo )

    local hospitalDieInfo = _hospitalDieInfo or {}
    hospitalDieInfo[_reinforceRid] = {}
    hospitalDieInfo[_reinforceRid][reinforces[_reinforceRid].armyIndex] = soldierDieInfo.dead or {}

    -- 更新部队士兵数量
    ArmyLogic:setArmy( _reinforceRid, reinforces[_reinforceRid].armyIndex, { [Enum.Army.soldiers] = reinforces[_reinforceRid].soldiers, [Enum.Army.minorSoldiers] = minorSoldiers } )
    -- 通知客户端部队士兵数量
    ArmyLogic:syncArmy( _reinforceRid, reinforces[_reinforceRid].armyIndex, { [Enum.Army.soldiers] = reinforces[_reinforceRid].soldiers, [Enum.Army.minorSoldiers] = minorSoldiers }, true )
    -- 计算角色当前战力
    RoleLogic:cacleSyncHistoryPower( _reinforceRid )
    -- 添加战损累计
    MSM.BattleLosePowerMgr[_reinforceRid].post.addRoleBattleLosePower( _reinforceRid, _soldierHurt )
    -- 如果增援的溃败了,直接回城
    if table.empty( reinforces[_reinforceRid].soldiers ) then
        local fpos = RoleLogic:getRole( _rid, Enum.Role.pos )
        local tpos = RoleLogic:getRole( _reinforceRid, Enum.Role.pos )
        local targetIndex = RoleLogic:getRoleCityIndex( _reinforceRid )
        ArmyLogic:armyEnterMap( _reinforceRid, reinforces[_reinforceRid].armyIndex, nil, Enum.RoleType.CITY, Enum.RoleType.CITY,
                                fpos, tpos, targetIndex, Enum.MapMarchTargetType.RETREAT, nil, nil, true, nil, true )
        -- 发一封邮件给盟友
        BattleAttrLogic:notifyBattleSubSoldier( _objectIndex, {}, _reinforceRid, _reinforceRid, reinforces[_reinforceRid].armyIndex )
        reinforces[_reinforceRid] = nil
    end

    RoleLogic:setRole( _rid, Enum.Role.reinforces, reinforces )
    RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
    return hospitalDieInfo
end

---@see 处理城市增援重伤.死亡处理
function BattleCallback:dispatchCityReinforceSoldier( _rid, _reinforceRid, _soldierHurt, _objectIndex, _hospitalDieInfo )
    local key = string.format("reinforceDispath_%d", _rid)
    Common.tryLock(key)
    local ret, err = xpcall(BattleCallback.dispatchCityReinforceSoldierImpl, debug.traceback, BattleCallback, _rid, _reinforceRid, _soldierHurt, _objectIndex, _hospitalDieInfo)
    if not ret then
        LOG_ERROR("dispatchCityReinforceSoldierImpl err:%s", err)
    end
    Common.unLock(key)
end

---@see 处理城市重伤.死亡处理
function BattleCallback:dispatchCitySoldier( _rid, _objectIndex, _soldierHurt, _rallySoldierHurt )
    local hospitalDieInfo = {}
    if _rallySoldierHurt and not table.empty(_rallySoldierHurt) then
        if _rallySoldierHurt[_rid] and _rallySoldierHurt[_rid][0] then
            self:dispatchCitySelfSoldier( _rid, _objectIndex, _rallySoldierHurt[_rid][0], hospitalDieInfo )
        end
        for reinforceRid, reinforceSoldierHurtInfo in pairs(_rallySoldierHurt) do
            for _, soldierHurtInfo in pairs(reinforceSoldierHurtInfo) do
                -- 处理增援城市的部队
                if reinforceRid ~= _rid then
                    self:dispatchCityReinforceSoldier( _rid, reinforceRid, soldierHurtInfo, _objectIndex )
                end
            end
        end
    else
        self:dispatchCitySelfSoldier( _rid, _objectIndex, _soldierHurt, hospitalDieInfo )
    end
    return hospitalDieInfo
end

---@see 处理资源重伤.死亡处理
function BattleCallback:dispatchResourceSoldier( _rid, _objectIndex, _soldierHurt )
    local allHurt = {}
    local allDie = {}
    for soldierId, hurtInfo in pairs(_soldierHurt) do
        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
            if not allHurt[soldierId] then
                allHurt[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
            else
                allHurt[soldierId].num = allHurt[soldierId].num + hurtInfo.hardHurt
            end
        end
        if hurtInfo.die and hurtInfo.die > 0 then
            if not allDie[soldierId] then
                allDie[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.die }
            else
                allDie[soldierId].num = allDie[soldierId].num + hurtInfo.die
            end
        end
    end

    -- 添加战损统计
    MSM.BattleLosePowerMgr[_rid].post.addRoleBattleLosePower( _rid, _soldierHurt )

    -- 同步资源内的部队
    return MSM.SceneResourceMgr[_objectIndex].req.updateResourceSoldier( _objectIndex, allHurt, allDie )
end

---@see 处理联盟建筑伤亡
function BattleCallback:dispatchGuildBuildArmySoldier( _, _objectIndex, _soldierHurt )
    local guildBuildInfo = MSM.SceneGuildBuildMgr[_objectIndex].req.getGuildBuildInfo( _objectIndex )
    if guildBuildInfo then
        local hospitalDieInfo = {}
        local syncGuildOrHolyLandArmyInfo = {}
        for garrsionRid, garrsionHurtInfo in pairs(_soldierHurt) do
            for garrisonArmyIndex, garrsionHurt in pairs(garrsionHurtInfo) do
                repeat
                    if not guildBuildInfo.garrison[garrsionRid] or not guildBuildInfo.garrison[garrsionRid][garrisonArmyIndex] then
                        break
                    end
                    local armyInfo = ArmyLogic:getArmy( garrsionRid, garrisonArmyIndex )
                    local armySoldiers = armyInfo.soldiers
                    local minorSoldiers = armyInfo.minorSoldiers
                    if not armySoldiers then
                        break
                    end
                    local tmpSoldierInfo = {}
                    local dieSoldierInfo = {}
                    local hardHurtSum = 0
                    local dieSum = 0
                    local minorSum = 0
                    for soldierId, hurtInfo in pairs(garrsionHurt) do
                        -- 重伤
                        if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
                            if armySoldiers[soldierId] and armySoldiers[soldierId].num > 0 then
                                if armySoldiers[soldierId].num - hurtInfo.hardHurt < 0 then
                                    hurtInfo.hardHurt = armySoldiers[soldierId].num
                                end
                                armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.hardHurt
                                if armySoldiers[soldierId].num < 0 then
                                    armySoldiers[soldierId].num = 0
                                end
                                hardHurtSum = hardHurtSum + hurtInfo.hardHurt
                                tmpSoldierInfo[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
                            end
                        end

                        -- 阵亡
                        if hurtInfo.die and hurtInfo.die > 0 then
                            dieSum = dieSum + hurtInfo.die
                            dieSoldierInfo[soldierId] = hurtInfo.die
                            hardHurtSum = hardHurtSum + hurtInfo.die
                            if armySoldiers[soldierId] and armySoldiers[soldierId].num > 0 then
                                if armySoldiers[soldierId].num - hurtInfo.die < 0 then
                                    hurtInfo.die = armySoldiers[soldierId].num
                                end
                                armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.die
                                if armySoldiers[soldierId].num < 0 then
                                    armySoldiers[soldierId].num = 0
                                end
                            end
                        end

                        -- 轻伤
                        if hurtInfo.minor and hurtInfo.minor > 0 then
                            minorSum = minorSum + hurtInfo.minor
                            if armySoldiers[soldierId] then
                                if armySoldiers[soldierId].num - hurtInfo.minor < 0 then
                                    hurtInfo.minor = armySoldiers[soldierId].num
                                end
                                armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.minor
                                if not minorSoldiers[soldierId] then
                                    minorSoldiers[soldierId] = {
                                        id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.minor
                                    }
                                else
                                    minorSoldiers[soldierId].num = minorSoldiers[soldierId].num + hurtInfo.minor
                                end
                            end
                        end

                        dieSoldierInfo[soldierId] = ( dieSoldierInfo[soldierId] or 0 ) + ( hurtInfo.hardHurt or 0 ) or ( hurtInfo.die or 0 )
                    end

                    -- 重伤的回医院
                    local soldierDieInfo = HospitalLogic:addToHospital( garrsionRid, tmpSoldierInfo )
                    if not hospitalDieInfo[garrsionRid] then
                        hospitalDieInfo[garrsionRid] = {}
                    end
                    hospitalDieInfo[garrsionRid][garrisonArmyIndex] = soldierDieInfo.dead or 0

                    -- 如果有死亡的,加入到死亡中
                    if soldierDieInfo.dead then
                        for _, info in pairs(soldierDieInfo.dead) do
                            dieSum = dieSum + info.num
                        end
                    end

                    if garrsionRid and garrsionRid > 0 then
                        if hardHurtSum > 0 or minorSum > 0 then
                            -- 更新部队士兵数量
                            ArmyLogic:setArmy( garrsionRid, garrisonArmyIndex, { [Enum.Army.soldiers] = armySoldiers, [Enum.Army.minorSoldiers] = minorSoldiers } )
                            -- 通知客户端部队士兵数量
                            ArmyLogic:syncArmy( garrsionRid, garrisonArmyIndex, { [Enum.Army.soldiers] = armySoldiers, [Enum.Army.minorSoldiers] = minorSoldiers }, true )
                            -- 计算角色当前战力,轻伤不影响战斗力计算
                            -- 建筑延迟到战斗结束再计算一次战力
                            --[[
                            if hardHurtSum > 0 then
                                RoleLogic:cacleSyncHistoryPower( garrsionRid, nil, nil, nil, nil, nil, nil, true )
                            end
                            ]]
                        end

                        if dieSum > 0 then
                            -- 增加重伤阵亡累计统计
                            RoleLogic:addRoleStatistics( garrsionRid, Enum.RoleStatisticsType.DEAD_SOLDIER, dieSum )
                        end
                        -- 添加战损统计
                        MSM.BattleLosePowerMgr[garrsionRid].post.addRoleBattleLosePower( garrsionRid, garrsionHurt )
                    end

                    -- 联盟建筑伤兵,同步
                    if guildBuildInfo.guildId and guildBuildInfo.guildId > 0 then
                        local buildArmyIndex = guildBuildInfo.garrison[garrsionRid][garrisonArmyIndex].buildArmyIndex
                        syncGuildOrHolyLandArmyInfo[buildArmyIndex] =  {
                            buildArmyIndex = buildArmyIndex,
                            rid = garrsionRid,
                            armyIndex = garrisonArmyIndex,
                            soldiers = armySoldiers,
                        }
                    end
                until true
            end
        end

        -- 联盟建筑伤兵,同步发送
        if not table.empty(syncGuildOrHolyLandArmyInfo) then
            MSM.GuildMgr[guildBuildInfo.guildId].post.syncBuildArmySoldiers( guildBuildInfo.guildId, _objectIndex, syncGuildOrHolyLandArmyInfo )
        end
        return hospitalDieInfo
    end
end

---@see 处理圣地建筑伤亡
function BattleCallback:dispatchHolyLandArmySoldier( _, _objectIndex, _soldierHurt )
    local holyLandInfo = MSM.SceneHolyLandMgr[_objectIndex].req.getHolyLandInfo( _objectIndex )
    if holyLandInfo then
        local hospitalDieInfo = {}
        local syncGuildOrHolyLandArmyInfo = {}
        for garrsionRid, garrsionHurtInfo in pairs(_soldierHurt) do
            for garrisonArmyIndex, garrsionHurt in pairs(garrsionHurtInfo) do
                repeat
                    if garrsionRid > 0 then
                        if not holyLandInfo.garrison[garrsionRid] or not holyLandInfo.garrison[garrsionRid][garrisonArmyIndex] then
                            break
                        end
                        local armyInfo = ArmyLogic:getArmy( garrsionRid, garrisonArmyIndex )
                        local armySoldiers = armyInfo.soldiers
                        local minorSoldiers = armyInfo.minorSoldiers
                        if not armySoldiers then
                            break
                        end
                        local tmpSoldierInfo = {}
                        local dieSoldierInfo = {}
                        local hardHurtSum = 0
                        local dieSum = 0
                        local minorSum = 0
                        for soldierId, hurtInfo in pairs(garrsionHurt) do
                            -- 重伤
                            if hurtInfo.hardHurt and hurtInfo.hardHurt > 0 then
                                if armySoldiers[soldierId] and armySoldiers[soldierId].num > 0 then
                                    if armySoldiers[soldierId].num - hurtInfo.hardHurt < 0 then
                                        hurtInfo.hardHurt = armySoldiers[soldierId].num
                                    end
                                    armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.hardHurt
                                    if armySoldiers[soldierId].num < 0 then
                                        armySoldiers[soldierId].num = 0
                                    end
                                    hardHurtSum = hardHurtSum + hurtInfo.hardHurt
                                    tmpSoldierInfo[soldierId] = { id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.hardHurt }
                                end
                            end

                            -- 阵亡
                            if hurtInfo.die and hurtInfo.die > 0 then
                                dieSum = dieSum + hurtInfo.die
                                dieSoldierInfo[soldierId] = hurtInfo.die
                                hardHurtSum = hardHurtSum + hurtInfo.die
                                if armySoldiers[soldierId] and armySoldiers[soldierId].num > 0 then
                                    if armySoldiers[soldierId].num - hurtInfo.die < 0 then
                                        hurtInfo.die = armySoldiers[soldierId].num
                                    end
                                    armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.die
                                    if armySoldiers[soldierId].num < 0 then
                                        armySoldiers[soldierId].num = 0
                                    end
                                end
                            end

                            -- 轻伤
                            if hurtInfo.minor and hurtInfo.minor > 0 then
                                minorSum = minorSum + hurtInfo.minor
                                if armySoldiers[soldierId] then
                                    if armySoldiers[soldierId].num - hurtInfo.minor < 0 then
                                        hurtInfo.minor = armySoldiers[soldierId].num
                                    end
                                    armySoldiers[soldierId].num = armySoldiers[soldierId].num - hurtInfo.minor
                                    if not minorSoldiers[soldierId] then
                                        minorSoldiers[soldierId] = {
                                            id = soldierId, type = hurtInfo.type, level = hurtInfo.level, num = hurtInfo.minor
                                        }
                                    else
                                        minorSoldiers[soldierId].num = minorSoldiers[soldierId].num + hurtInfo.minor
                                    end
                                end
                            end

                            dieSoldierInfo[soldierId] = ( dieSoldierInfo[soldierId] or 0 ) + ( hurtInfo.hardHurt or 0 ) or ( hurtInfo.die or 0 )
                        end

                        -- 重伤的回医院
                        local soldierDieInfo = HospitalLogic:addToHospital( garrsionRid, tmpSoldierInfo )
                        if not hospitalDieInfo[garrsionRid] then
                            hospitalDieInfo[garrsionRid] = {}
                        end
                        hospitalDieInfo[garrsionRid][garrisonArmyIndex] = soldierDieInfo.dead or 0
                        -- 如果有死亡的,加入到死亡中
                        if soldierDieInfo.dead then
                            for _, info in pairs(soldierDieInfo.dead) do
                                dieSum = dieSum + info.num
                            end
                        end

                        if hardHurtSum > 0 or minorSum > 0 then
                            -- 更新部队士兵数量
                            ArmyLogic:setArmy( garrsionRid, garrisonArmyIndex, { [Enum.Army.soldiers] = armySoldiers, [Enum.Army.minorSoldiers] = minorSoldiers } )
                            -- 通知客户端部队士兵数量
                            ArmyLogic:syncArmy( garrsionRid, garrisonArmyIndex, { [Enum.Army.soldiers] = armySoldiers, [Enum.Army.minorSoldiers] = minorSoldiers }, true )
                            -- 计算角色当前战力,轻伤不影响战斗力计算
                            -- 建筑延迟到战斗结束再计算一次战力
                            --[[
                            if hardHurtSum > 0 then
                                RoleLogic:cacleSyncHistoryPower( garrsionRid, nil, nil, nil, nil, nil, nil, true )
                            end
                            ]]
                        end

                        if dieSum > 0 then
                            -- 增加重伤阵亡累计统计
                            RoleLogic:addRoleStatistics( garrsionRid, Enum.RoleStatisticsType.DEAD_SOLDIER, dieSum )
                        end

                        -- 添加战损统计
                        MSM.BattleLosePowerMgr[garrsionRid].post.addRoleBattleLosePower( garrsionRid, garrsionHurt )

                        -- 圣地建筑伤兵,同步
                        if holyLandInfo.guildId and holyLandInfo.guildId > 0 then
                            local buildArmyIndex = holyLandInfo.garrison[garrsionRid][garrisonArmyIndex].buildArmyIndex
                            syncGuildOrHolyLandArmyInfo[buildArmyIndex] =  {
                                buildArmyIndex = buildArmyIndex,
                                rid = garrsionRid,
                                armyIndex = garrisonArmyIndex,
                                soldiers = armySoldiers,
                            }
                        end
                    else
                        -- 圣地初始怪物
                        MSM.SceneHolyLandMgr[_objectIndex].post.updateHolyLandMonsterSoldiers( _objectIndex, garrsionHurt )
                    end
                until true
            end
        end

        -- 圣地建筑伤兵,同步发送
        if not table.empty(syncGuildOrHolyLandArmyInfo) then
            MSM.GuildMgr[holyLandInfo.guildId].post.syncBuildArmySoldiers( holyLandInfo.guildId, _objectIndex, syncGuildOrHolyLandArmyInfo )
        end
        return hospitalDieInfo
    end
end

---@see 重伤.死亡处理
function BattleCallback:dispatchSoldier( _rid, _objectType, _objectIndex, _soldierHurt, _rallySoldierHurt, _isRally )
    local hospitalDieInfo
    if _objectType == Enum.RoleType.ARMY then
        if not _isRally then
            -- 非集结部队
            hospitalDieInfo = self:dispatchArmySoldier( _rid, _objectIndex, _soldierHurt )
        else
            -- 集结部队
            hospitalDieInfo = self:dispatchRallyArmySoldier( _rid, _objectIndex, _rallySoldierHurt )
        end
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND
        or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or _objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 野蛮人、圣地守护者、召唤怪
        self:dispatchMonsterSoldier( _rid, _objectIndex, _soldierHurt )
    elseif _objectType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城寨
        self:dispatchMonsterCitySoldier( _rid, _objectIndex, _soldierHurt )
    elseif _objectType == Enum.RoleType.CITY then
        -- 城市
        hospitalDieInfo = self:dispatchCitySoldier( _rid, _objectIndex, _soldierHurt, _rallySoldierHurt )
    elseif MapObjectLogic:checkIsResourceObject( _objectType ) then
        -- 资源点
        hospitalDieInfo = self:dispatchResourceSoldier( _rid, _objectIndex, _soldierHurt )
    elseif MapObjectLogic:checkIsGuildBuildObject( _objectType ) then
        -- 联盟建筑
        hospitalDieInfo = self:dispatchGuildBuildArmySoldier( _rid, _objectIndex, _rallySoldierHurt )
    elseif MapObjectLogic:checkIsHolyLandObject( _objectType ) then
        -- 圣地建筑
        hospitalDieInfo = self:dispatchHolyLandArmySoldier( _rid, _objectIndex, _rallySoldierHurt )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        self:dispatchExpeditionArmySoldier( _rid, _objectIndex, _soldierHurt )
    end
    return hospitalDieInfo
end

---@see 处理城市治疗
function BattleCallback:dispatchCityHealSoldier( _rid, _healSoldiers, _rallySoldierHeal )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.soldiers, Enum.Role.reinforces } )
    if not _rallySoldierHeal and _healSoldiers then
        -- 只有城市自己
        _rallySoldierHeal = { [_rid] = { [0] = _healSoldiers } }
    end

    if not _rallySoldierHeal then
        return
    end

    for rallyRid, healInfo in pairs(_rallySoldierHeal) do
        if rallyRid == _rid then
            -- 城市自身
            local addSoldierInfo = {}
            local subSoldierInfo = {}
            for _, healSoldiers in pairs(healInfo) do
                for soldierId, healCount in pairs(healSoldiers) do
                    if not addSoldierInfo[soldierId] then
                        addSoldierInfo[soldierId] = { id = soldierId, num = 0, minor = 0 }
                    end
                    if not subSoldierInfo[soldierId] then
                        subSoldierInfo[soldierId] = { id = soldierId, num = 0, minor = 0 }
                    end
                    -- 增加士兵
                    addSoldierInfo[soldierId].num = addSoldierInfo[soldierId].num + healCount
                    -- 减少轻伤
                    subSoldierInfo[soldierId].minor = subSoldierInfo[soldierId].minor + healCount

                end
            end

            -- 同步给客户端
            SoldierLogic:addSoldier( _rid, addSoldierInfo )
            SoldierLogic:subSoldier( _rid, subSoldierInfo )
        else
            -- 增援的部队
            local reinforces = roleInfo.reinforces
            if reinforces[rallyRid] and reinforces[rallyRid].arrivalTime <= os.time() then
                -- 已到达的部队
                for armyIndex, healSoldiers in pairs(healInfo) do
                    local armyInfo = ArmyLogic:getArmy( rallyRid, armyIndex, { Enum.Army.soldiers, Enum.Army.minorSoldiers } )
                    for soldierId, healCount in pairs(healSoldiers) do
                        if armyInfo.minorSoldiers[soldierId] then
                            -- 有轻伤兵
                            if armyInfo.minorSoldiers[soldierId].num > 0 then
                                if healCount > armyInfo.minorSoldiers[soldierId].num then
                                    healCount = armyInfo.minorSoldiers[soldierId].num
                                end
                                -- 减少轻伤
                                armyInfo.minorSoldiers[soldierId].num = armyInfo.minorSoldiers[soldierId].num - healCount
                                -- 增加士兵
                                armyInfo.soldiers[soldierId].num = armyInfo.soldiers[soldierId].num + healCount
                                -- 增援部队信息
                                reinforces[rallyRid].soldiers[soldierId].num = reinforces[rallyRid].soldiers[soldierId].num + healCount
                            end
                        end
                    end
                    -- 更新部队士兵数量
                    ArmyLogic:setArmy( rallyRid, armyIndex, { [Enum.Army.soldiers] = armyInfo.soldiers, [Enum.Army.minorSoldiers] = armyInfo.minorSoldiers } )
                    -- 通知客户端部队士兵数量
                    ArmyLogic:syncArmy( rallyRid, armyIndex, { [Enum.Army.soldiers] = armyInfo.soldiers, [Enum.Army.minorSoldiers] = armyInfo.minorSoldiers }, true )
                end
            end

            -- 同步给客户端
            RoleLogic:setRole( _rid, Enum.Role.reinforces, reinforces )
            RoleSync:syncSelf( _rid, { [Enum.Role.reinforces] = reinforces }, true )
        end
    end
end

---@see 处理部队治疗
function BattleCallback:dispatchArmyHealSoldier( _rid, _armyIndex, _healSoldiers )
    local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex, { Enum.Army.soldiers, Enum.Army.minorSoldiers } )
    for soldierId, healCount in pairs(_healSoldiers) do
        if armyInfo.minorSoldiers and armyInfo.minorSoldiers[soldierId] then
            -- 有轻伤兵
            if armyInfo.minorSoldiers[soldierId].num > 0 then
                if healCount > armyInfo.minorSoldiers[soldierId].num then
                    healCount = armyInfo.minorSoldiers[soldierId].num
                end
                -- 减少轻伤
                armyInfo.minorSoldiers[soldierId].num = armyInfo.minorSoldiers[soldierId].num - healCount
                -- 增加士兵
                armyInfo.soldiers[soldierId].num = armyInfo.soldiers[soldierId].num + healCount
            end
        end
    end
    -- 更新部队士兵数量
    ArmyLogic:setArmy( _rid, _armyIndex, { [Enum.Army.soldiers] = armyInfo.soldiers, [Enum.Army.minorSoldiers] = armyInfo.minorSoldiers } )
    -- 通知客户端部队士兵数量
    ArmyLogic:syncArmy( _rid, _armyIndex, { [Enum.Army.soldiers] = armyInfo.soldiers, [Enum.Army.minorSoldiers] = armyInfo.minorSoldiers }, true )
end

---@see 处理部队治疗
function BattleCallback:dispatchExpeditionHealSoldier( _rid, _objectIndex, _healSoldiers )
    local newHealSoldiers = {}
    for soldierId, healCount in pairs(_healSoldiers) do
        newHealSoldiers[soldierId] = { id = soldierId, num = -healCount }
    end
    MSM.SceneExpeditionMgr[_objectIndex].post.updateSoldier( _objectIndex, newHealSoldiers, true )
end

---@see 处理治疗
function BattleCallback:dispatchHealSoldier( _objectIndex, _rid, _objectType, _healSoldiers, _rallySoldierHeal, _armyIndex, _isRally )
    if _objectType == Enum.RoleType.CITY then
        -- 城市
        self:dispatchCityHealSoldier( _rid, _healSoldiers, _rallySoldierHeal )
    elseif _objectType == Enum.RoleType.ARMY then
        -- 部队
        if _isRally then
            -- 集结部队
            for rallyRid, healInfo in pairs(_rallySoldierHeal) do
                for armyIndex, healSoldiers in pairs(healInfo) do
                    self:dispatchArmyHealSoldier( rallyRid, armyIndex, healSoldiers )
                end
            end
        else
            -- 非集结部队
            self:dispatchArmyHealSoldier( _rid, _armyIndex, _healSoldiers )
        end
    elseif MapObjectLogic:checkIsResourceObject( _objectType ) then
        -- 资源点
        self:dispatchArmyHealSoldier( _rid, _armyIndex, _healSoldiers )
    elseif MapObjectLogic:checkIsGuildBuildObject( _objectType ) or MapObjectLogic:checkIsHolyLandObject( _objectType ) then
        -- 联盟建筑、圣地
        for rallyRid, healInfo in pairs(_rallySoldierHeal) do
            for armyIndex, healSoldiers in pairs(healInfo) do
                self:dispatchArmyHealSoldier( rallyRid, armyIndex, healSoldiers )
            end
        end
    elseif _objectType == Enum.RoleType.EXPEDITION then
        self:dispatchExpeditionHealSoldier( _rid, _objectIndex, _healSoldiers )
    end
end

---@see 轻伤处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchMinorSoldier( _exitArg )
    if _exitArg.objectType == Enum.RoleType.CITY then
        -- 城里的轻伤转正常
        local roleSoldiers = RoleLogic:getRole( _exitArg.rid, Enum.Role.soldiers )
        local addSoldierInfo = {}
        local subSoldierInfo = {}
        for soldierId, soldierInfo in pairs(roleSoldiers) do
            if not subSoldierInfo[soldierId] then
                subSoldierInfo[soldierId] = { id = soldierId, num = 0, minor = 0 }
            end
            if not addSoldierInfo[soldierId] then
                addSoldierInfo[soldierId] = { id = soldierId, num = 0, minor = 0 }
            end
            if soldierInfo.minor and soldierInfo.minor > 0 then
                addSoldierInfo[soldierId].num = addSoldierInfo[soldierId].num + soldierInfo.minor
                subSoldierInfo[soldierId].minor = subSoldierInfo[soldierId].minor + soldierInfo.minor
            end
        end
        -- 同步给客户端
        SoldierLogic:addSoldier( _exitArg.rid, addSoldierInfo )
        SoldierLogic:subSoldier( _exitArg.rid, subSoldierInfo )
    elseif MapObjectLogic:checkIsResourceObject( _exitArg.objectType ) then
        -- 资源点
        local minors = {}
        for soldierId, hurtInfo in pairs(_exitArg.soldierHurt) do
            if hurtInfo.allMinor and hurtInfo.allMinor > 0 then
                minors[soldierId] = hurtInfo.allMinor
            end
        end
        -- 同步到资源点内的部队
        MSM.SceneResourceMgr[_exitArg.objectIndex].post.syncSoldierMinor( _exitArg.objectIndex, minors )
    end
end

---@see 圣地守护者掉落处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchGuardHolyLandDrop( _exitArg, _killExp )
    if _exitArg.objectType ~= Enum.RoleType.ARMY then
        return _killExp
    end
    -- 判断对象是否是圣地守护者
    if _exitArg.attackTargetType ~= Enum.RoleType.GUARD_HOLY_LAND then
        -- 不是圣地守护者
        return _killExp
    end

    -- 胜利发送奖励
    local sMonsterInfo = CFG.s_Monster:Get( _exitArg.holyLandMonsterId )
    if _exitArg.win == Enum.BattleResult.WIN then
        -- 获取经验奖励
        local armyInfo = MSM.SceneArmyMgr[_exitArg.objectIndex].req.getArmyInfo(_exitArg.objectIndex)
        if sMonsterInfo.killExp and sMonsterInfo.killExp > 0 then
            local heroExpMulti = RoleLogic:getRole( _exitArg.rid, Enum.Role.heroExpMulti )
            local mainHeroAttr = HeroLogic:getHeroAttr( _exitArg.rid, armyInfo.mainHeroId, Enum.Role.heroExpMulti )
            local deputyHeroAttr = HeroLogic:getHeroAttr( _exitArg.rid, armyInfo.deputyHeroId, Enum.Role.heroExpMulti, true )
            local exp = math.floor( sMonsterInfo.killExp * ( ( 1000 + ( heroExpMulti + mainHeroAttr + deputyHeroAttr ) ) / 1000 ) )

            if armyInfo.mainHeroId and armyInfo.mainHeroId > 0 then
                HeroLogic:addHeroExp( _exitArg.rid, armyInfo.mainHeroId, exp )
                if not _killExp then
                    _killExp = 0
                end
                _killExp = _killExp + exp
            end
            if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
                HeroLogic:addHeroExp( _exitArg.rid, armyInfo.deputyHeroId, exp )
            end
        end
        MSM.ActivityRoleMgr[_exitArg.rid].req.setActivitySchedule( _exitArg.rid, Enum.ActivityActionType.KILL_GUARDTION_COUNT, 1 )
        -- 发放联盟礼物
        if sMonsterInfo.allianceGift and sMonsterInfo.allianceGift > 0
            and Random.GetRange( 1, 1000, 1 )[1] <= ( sMonsterInfo.allianceGiftChance or 0 ) then
            -- 发放联盟礼物
            local roleInfo = RoleLogic:getRole( _exitArg.rid, { Enum.Role.name, Enum.Role.guildId } ) or {}
            if roleInfo.guildId and roleInfo.guildId > 0 then
                local giftArgs = { roleInfo.name, tostring( _exitArg.holyLandMonsterId ) }
                MSM.GuildMgr[roleInfo.guildId].post.sendGuildGift( roleInfo.guildId, sMonsterInfo.allianceGift, nil, nil, nil, Enum.GuildGiftSendType.KILL_MONSTER, giftArgs )
            end
        end
    end

    return _killExp
end

---@see 野蛮人城寨掉落处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchMonsterCityDrop( _exitArg )
    local monsterCityMonsterId = _exitArg.attackMonsterIds[1]
    if _exitArg.objectType == Enum.RoleType.ARMY and _exitArg.battleType == Enum.BattleType.MONSTER_CITY and _exitArg.attackTargetIndex then
        for rallyRid in pairs(_exitArg.rallyMember) do
            MSM.ActivityRoleMgr[rallyRid].req.setActivitySchedule( rallyRid, Enum.ActivityActionType.KILL_BARB_WALL_LEVEL_COUNT, 1, _exitArg.monsterCityLevel )
            MSM.ActivityRoleMgr[rallyRid].req.setActivitySchedule( rallyRid, Enum.ActivityActionType.KILL_BARB_WALL_COUNT, 1 )
        end
    end

    if _exitArg.objectType ~= Enum.RoleType.ARMY or ( _exitArg.battleType ~= Enum.BattleType.MONSTER_CITY and _exitArg.battleType ~= Enum.BattleType.SUMMON_RALLY )
    or not _exitArg.attackTargetIndex or _exitArg.win ~= Enum.BattleResult.WIN then
        return
    end

    local sMonsterInfo = CFG.s_Monster:Get( monsterCityMonsterId )
    if sMonsterInfo.damageReward and sMonsterInfo.damageReward > 0 then
        -- 计算伤害比例
        local allDamage = 0
        for _, rallyDamage in pairs(_exitArg.rallyDamages) do
            allDamage = allDamage + rallyDamage
        end

        if allDamage > 0 then
            -- 给奖励
            local sMonsterDamageReward, damageStage, emailContents
            local allDamageStage = 0
            local roleList = {}
            for rallyRid, rallyDamage in pairs(_exitArg.rallyDamages) do
                damageStage = math.ceil( rallyDamage / allDamage * 100 )
                if allDamageStage + damageStage > 100 then
                    damageStage = 100 - allDamageStage
                end
                allDamageStage = allDamageStage + damageStage
                sMonsterDamageReward = CFG.s_MonsterDamageReward:Get( sMonsterInfo.damageReward * 100 + math.ceil( damageStage / 10 ) )
                -- 给奖励
                local rewardInfo = ItemLogic:getItemPackage( rallyRid, sMonsterDamageReward.rewardId )
                if _exitArg.battleType == Enum.BattleType.MONSTER_CITY then
                    -- 发奖励邮件
                    local stage = math.floor( damageStage / 10 )
                    if stage == 0 then
                        stage = 1
                    end
                    emailContents = {
                        math.floor( _exitArg.monsterCityPos.x ) .. "," .. math.floor( _exitArg.monsterCityPos.y ),
                        monsterCityMonsterId,
                        damageStage,
                        stage
                    }
                    EmailLogic:sendEmail( rallyRid, sMonsterInfo.emailId, {
                        emailContents = emailContents,
                        rewards = rewardInfo,
                        takeEnclosure = true
                    } )
                    -- 更新击杀野蛮人城寨次数
                    TaskLogic:addTaskStatisticsSum( rallyRid, Enum.TaskType.MONSTER_CITY_NUM, Enum.TaskArgDefault, 1 )
                    TaskLogic:addTaskStatisticsSum( rallyRid, Enum.TaskType.MONSTER_CITY_NUM, sMonsterInfo.level, 1 )
                    MSM.ActivityRoleMgr[rallyRid].req.setActivitySchedule( rallyRid, Enum.ActivityActionType.KILL_BARB_WALL_ACTION, 1 )
                    MSM.ActivityRoleMgr[rallyRid].req.setActivitySchedule( rallyRid, Enum.ActivityActionType.KILL_BARB_WALL_WIN_COUNT, 1 )
                elseif _exitArg.battleType == Enum.BattleType.SUMMON_RALLY then
                    local roleInfo = RoleLogic:getRole( rallyRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
                    table.insert( roleList, { rid = rallyRid, name = roleInfo.name, headId = roleInfo.headId, headFrameID = roleInfo.headFrameID
                                        , rewardInfo = rewardInfo } )
                end
            end
            if _exitArg.battleType == Enum.BattleType.SUMMON_RALLY then
                for rallyRid in pairs(_exitArg.rallyDamages) do
                    emailContents = {
                        math.floor( _exitArg.monsterCityPos.x ) .. "," .. math.floor( _exitArg.monsterCityPos.y ),
                        math.floor( _exitArg.monsterCityPos.x ) .. "," .. math.floor( _exitArg.monsterCityPos.y ),
                        monsterCityMonsterId,
                    }
                    EmailLogic:sendEmail( rallyRid, sMonsterInfo.emailId, {
                        emailContents = emailContents,
                        roleList = roleList,
                        subTitleContents = { monsterCityMonsterId },
                    } )
                end
            end
        end
    end

    local guildId = 0
    if _exitArg.rid and _exitArg.rid > 0 then
        guildId = RoleLogic:getRole( _exitArg.rid, Enum.Role.guildId ) or 0
    end
    if sMonsterInfo.allianceGift and sMonsterInfo.allianceGift > 0
        and Random.GetRange( 1, 1000, 1 )[1] <= ( sMonsterInfo.allianceGiftChance or 0 ) then
        -- 发放联盟礼物
        if guildId > 0 then
            local giftArgs = { RoleLogic:getRole( _exitArg.rid, Enum.Role.name ), tostring( monsterCityMonsterId ) }
            MSM.GuildMgr[guildId].post.sendGuildGift( guildId, sMonsterInfo.allianceGift, nil, nil, nil, Enum.GuildGiftSendType.KILL_MONSTER, giftArgs )
        end
    end

    -- 纪念碑击杀进度
    if guildId > 0 then
        MonumentLogic:setSchedule( nil, { guildId = guildId, count = 1, level = _exitArg.monsterCityLevel, type = Enum.MonumentType.SERVER_ALLICNCE_KILL_WALLED } )
    end

    -- 增加一层野蛮人扫荡效果
    for rallyRid, rallyArmyIndex in pairs(_exitArg.rallyMember) do
        -- 队员
        ArmyLogic:addKillMonsterReduceVit( rallyRid, rallyArmyIndex )
    end
    -- 队长
    ArmyLogic:addKillMonsterReduceVit( _exitArg.rid, _exitArg.armyIndex )
end

---@see 野蛮人掉落处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchMonsterDrop( _exitArg )
    if ( _exitArg.attackTargetType ~= Enum.RoleType.MONSTER and _exitArg.attackTargetType ~= Enum.RoleType.SUMMON_SINGLE_MONSTER )
        or _exitArg.win ~= Enum.BattleResult.WIN then
        return
    end
    local maxMonsterLevel = 0
    local sMonsterInfo
    local killExp = 0
    local allReward = {
        food = 0,
        wood = 0,
        stone = 0,
        gold = 0,
        denar = 0,
        items = {},
        soldiers = {}
    }

    local guildGifts = {}
    local roleInfo = RoleLogic:getRole( _exitArg.rid, { Enum.Role.heroExpMulti, Enum.Role.guildId, Enum.Role.name } ) or {}
    local guildId = roleInfo.guildId or 0
    local heroExpMulti = roleInfo.heroExpMulti or 0
    for _, monsterId in pairs(_exitArg.attackMonsterIds) do
        sMonsterInfo = CFG.s_Monster:Get( monsterId )
        if sMonsterInfo then
            killExp = sMonsterInfo.killExp or 0
            if maxMonsterLevel < sMonsterInfo.level then
                maxMonsterLevel = sMonsterInfo.level
            end

            -- 获取经验奖励
            local armyInfo = MSM.SceneArmyMgr[_exitArg.objectIndex].req.getArmyInfo(_exitArg.objectIndex)
            if killExp > 0 then
                local mainHeroAttr = HeroLogic:getHeroAttr( _exitArg.rid, armyInfo.mainHeroId, Enum.Role.heroExpMulti )
                local deputyHeroAttr = HeroLogic:getHeroAttr( _exitArg.rid, armyInfo.deputyHeroId, Enum.Role.heroExpMulti, true )
                killExp = math.floor( killExp * ( ( 1000 + ( heroExpMulti + mainHeroAttr + deputyHeroAttr ) ) / 1000 ) )
                if armyInfo.mainHeroId and armyInfo.mainHeroId > 0 then
                    HeroLogic:addHeroExp( _exitArg.rid, armyInfo.mainHeroId, killExp )
                end
                if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
                    HeroLogic:addHeroExp( _exitArg.rid, armyInfo.deputyHeroId, killExp )
                end
            end

            -- 获取道具奖励
            local reward = ItemLogic:getGroupPackage( _exitArg.rid, sMonsterInfo.killReward )
            allReward.food = allReward.food + reward.food
            allReward.wood = allReward.wood + reward.wood
            allReward.stone = allReward.stone + reward.stone
            allReward.gold = allReward.gold + reward.gold
            allReward.denar = allReward.denar + reward.denar
            for itemId, itemInfo in pairs(reward.items) do
                if not allReward.items[itemId] then
                    allReward.items[itemId] = 0
                end
                allReward.items[itemId] = allReward.items[itemId] + itemInfo.itemNum
            end

            for armyType, subArmyInfo in pairs(reward.soldiers) do
                if not allReward.soldiers[armyType] then
                    allReward.soldiers[armyType] = {}
                end
                allReward.soldiers[armyType] = subArmyInfo
            end

            -- 是否发放联盟礼物
            if sMonsterInfo.allianceGift and sMonsterInfo.allianceGift > 0 and guildId > 0
                and Random.GetRange( 1, 1000, 1 )[1] <= ( sMonsterInfo.allianceGiftChance or 0 ) then
                table.insert( guildGifts, {
                    giftType = sMonsterInfo.allianceGift,
                    giftArgs = { roleInfo.name, tostring(monsterId) }
                } )
            end
        end
    end

    -- 给粮食
    if allReward.food > 0 then
        RoleLogic:addFood( _exitArg.rid, allReward.food, nil, Enum.LogType.PACKAGE_GAIN_ITEM )
    end
    -- 给木材
    if allReward.wood > 0 then
        RoleLogic:addWood( _exitArg.rid, allReward.wood, nil, Enum.LogType.PACKAGE_GAIN_ITEM )
    end
    -- 给石头
    if allReward.stone > 0 then
        RoleLogic:addStone( _exitArg.rid, allReward.stone, nil, Enum.LogType.PACKAGE_GAIN_ITEM )
    end
    -- 给金币
    if allReward.gold > 0 then
        RoleLogic:addGold( _exitArg.rid, allReward.gold, nil, Enum.LogType.PACKAGE_GAIN_ITEM )
    end
    -- 给代币
    if allReward.denar > 0 then
        RoleLogic:addDenar( _exitArg.rid, allReward.denar, nil, Enum.LogType.PACKAGE_GAIN_ITEM )
    end
    -- 给道具
    local retItems = {}
    if not table.empty( allReward.items ) then
        for itemId, itemNum in pairs(allReward.items) do
            ItemLogic:addItem( { rid = _exitArg.rid, itemId = itemId, itemNum = itemNum,
                                    eventType = Enum.LogType.PACKAGE_GAIN_ITEM, eventArg = sMonsterInfo.killReward or 0 } )
            table.insert( retItems, { itemId = itemId, itemNum = itemNum } )
        end
    end
    -- 给士兵
    if not table.empty( allReward.soldiers ) then
        for armyType, armyInfo in pairs(allReward.soldiers) do
            ArmyTrainLogic:addSoldiers( _exitArg.rid, armyType, armyInfo.level, armyInfo.num, Enum.LogType.PACKAGE_GAIN_ITEM )
        end
    end
    -- 转换道具
    allReward.items = retItems

    -- 击败野蛮人
    if _exitArg.rid > 0 and not table.empty(_exitArg.attackMonsterIds) then
        MSM.ActivityRoleMgr[_exitArg.rid].req.setActivitySchedule( _exitArg.rid, Enum.ActivityActionType.KILL_BARB_ACTION, 1 )
        MSM.ActivityRoleMgr[_exitArg.rid].req.setActivitySchedule( _exitArg.rid, Enum.ActivityActionType.KILL_BARB_COUNT, 1 )
        MSM.ActivityRoleMgr[_exitArg.rid].req.setActivitySchedule( _exitArg.rid, Enum.ActivityActionType.KILL_BARB_LEVEL_COUNT, 1, sMonsterInfo.level )
        MSM.ActivityRoleMgr[_exitArg.rid].req.setActivitySchedule( _exitArg.rid, Enum.ActivityActionType.KILL_BARB_LEVEL2_COUNT, 1, sMonsterInfo.level )
        RoleLogic:reduceTime( _exitArg.rid, sMonsterInfo.mysteryStoreCD )
        MSM.MonumentRoleMgr[_exitArg.rid].post.setSchedule( _exitArg.rid, { type = Enum.MonumentType.SERVER_KILL_MONSTER, level = sMonsterInfo.level, count = 1 })
        -- 增加一层野蛮人扫荡效果
        ArmyLogic:addKillMonsterReduceVit( _exitArg.rid, _exitArg.armyIndex )
    end

    -- 发放联盟礼物
    local sendGiftType = Enum.GuildGiftSendType.KILL_MONSTER
    for _, giftInfo in pairs( guildGifts ) do
        MSM.GuildMgr[guildId].post.sendGuildGift( guildId, giftInfo.giftType, nil, nil, nil, sendGiftType, giftInfo.giftArgs )
    end

    return allReward, killExp
end

---@see 圣地守护者掉落处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchGuardHolyLandDropRune( _exitArg )
    local exitObjectIndex = _exitArg.objectIndex
    local guardHolyLandInfo = MSM.SceneMonsterMgr[exitObjectIndex].req.getMonsterInfo( exitObjectIndex )
    if guardHolyLandInfo then
        local sMonsterInfo = CFG.s_Monster:Get( guardHolyLandInfo.monsterId )
        if sMonsterInfo.lootReward and sMonsterInfo.lootReward > 0 then
            local sMonsterLootRule = CFG.s_MonsterLootRule:Get( sMonsterInfo.lootReward )
            if sMonsterLootRule then
                local allLootRule = {}
                for _, rewardInfo in pairs(sMonsterLootRule) do
                    -- body
                    table.insert( allLootRule, { id = rewardInfo.mapItemId, rate = rewardInfo.rate } )
                end

                -- 随机一个符文
                local dropRune = Random.GetId( allLootRule )
                -- 掉落符文到地图上
                local runeObjectIndex = Common.newMapObjectIndex()
                MSM.RuneMgr[runeObjectIndex].post.addRuneInfo( dropRune, guardHolyLandInfo.pos, guardHolyLandInfo.holyLandId, runeObjectIndex )
            end
        end
        MSM.HolyLandGuardMgr[guardHolyLandInfo.holyLandId].post.deleteGuard( exitObjectIndex )

        -- 增加一层野蛮人扫荡效果
        ArmyLogic:addKillMonsterReduceVit( _exitArg.rid, _exitArg.armyIndex )
    end
end

---@see 攻城掠夺处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchPlunder( _exitArg, _monsterReward )
    if _exitArg.objectType == Enum.RoleType.ARMY then
        local armyInfo = MSM.SceneArmyMgr[_exitArg.objectIndex].req.getArmyInfo( _exitArg.objectIndex )
        if armyInfo then
            -- 处理资源掠夺
            if not _exitArg.disband then
                if _exitArg.battleType == Enum.BattleType.CITY_PVP then
                    -- 如果是攻城战
                    if _exitArg.plunderRid and _exitArg.win == Enum.BattleResult.WIN then
                        if not _monsterReward then
                            _monsterReward = {
                                food = 0,
                                wood = 0,
                                stone = 0,
                                gold = 0
                            }
                        end
                        -- 进行掠夺
                        local notifyRids, plunderReward = MSM.CityPlunderMgr[_exitArg.plunderRid].req.dispatchCityPlunder( _exitArg )
                        if plunderReward then
                            _monsterReward.food = _monsterReward.food + plunderReward.food
                            _monsterReward.wood = _monsterReward.wood + plunderReward.wood
                            _monsterReward.stone = _monsterReward.stone + plunderReward.stone
                            _monsterReward.gold = _monsterReward.gold + plunderReward.gold
                        end
                        -- 通知客户端征服了此城市
                        Common.syncMsg( notifyRids, "Map_CityPundler", { name = RoleLogic:getRole( _exitArg.plunderRid, Enum.Role.name ) } )
                    end
                end
            end
        end
    elseif _exitArg.objectType == Enum.RoleType.CITY and _exitArg.win == Enum.BattleResult.FAIL then
        -- 城市战败,计算被掠夺的资源
        local lostResource = self:cacleCityBePlunderResource( _exitArg )
        if lostResource then
            _monsterReward = {
                food = -lostResource.food,
                wood = -lostResource.wood,
                stone = -lostResource.stone,
                gold = -lostResource.gold
            }
        end
    end

    return _monsterReward
end

---@see 溃败回城处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchDefeat( _exitArg )
    local armyInfo
    if not _exitArg.soldiers or table.size(_exitArg.soldiers) <= 0 then
        -- 溃败了
        if _exitArg.objectType == Enum.RoleType.MONSTER then
            -- 同步野蛮人溃败状态
            MSM.SceneMonsterMgr[_exitArg.objectIndex].req.updateMonsterStatus( _exitArg.objectIndex, Enum.ArmyStatus.MONSTER_FAILED )
            -- 怪物删除
            local serviceIndex = MonsterLogic:getMonsterService( _exitArg.objectIndex )
            MSM.MonsterMgr[serviceIndex].req.deleteMonster( _exitArg.objectIndex )
        elseif _exitArg.objectType == Enum.RoleType.GUARD_HOLY_LAND then
            -- 同步守护者溃败状态
            MSM.SceneMonsterMgr[_exitArg.objectIndex].req.updateMonsterStatus( _exitArg.objectIndex, Enum.ArmyStatus.MONSTER_FAILED )
            -- 掉落符文
            self:dispatchGuardHolyLandDropRune( _exitArg )
        elseif _exitArg.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or _exitArg.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 同步召唤怪物溃败状态
            MSM.SceneMonsterMgr[_exitArg.objectIndex].req.updateMonsterStatus( _exitArg.objectIndex, Enum.ArmyStatus.MONSTER_FAILED )
            -- 删除召唤怪物
            MSM.MonsterSummonMgr[_exitArg.objectIndex].req.deleteSummonMonster( _exitArg.objectIndex )
        elseif _exitArg.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨删除
            MonsterCityLogic:defeatMonsterCityCallBack( _exitArg.objectIndex )
        elseif _exitArg.objectType == Enum.RoleType.ARMY then
            armyInfo = MSM.SceneArmyMgr[_exitArg.objectIndex].req.getArmyInfo( _exitArg.objectIndex )
            if not armyInfo.isRally then
                if not _exitArg.disband then
                    local targetObjectIndex = armyInfo.targetObjectIndex or 0
                    local targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
                    if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH ) then
                        -- 增援行军中
                        if targetInfo.objectType == Enum.RoleType.CITY then
                            -- 增援城市,返回
                            RepatriationLogic:repatriationFromCity( targetInfo.rid, armyInfo.rid, true, true )
                        elseif MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
                            -- 删除向联盟建筑的增援
                            MSM.GuildMgr[targetInfo.guildId].post.guildBuildArmyMarch( targetInfo.guildId, targetInfo.buildIndex, armyInfo.rid, armyInfo.armyIndex, nil, targetObjectIndex, true )
                        elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
                            -- 删除向圣地的增援
                            MSM.GuildMgr[targetInfo.guildId].post.deleteHolyLandArmy( targetInfo.guildId, armyInfo.rid, armyInfo.armyIndex, targetObjectIndex )
                        elseif targetInfo.objectType == Enum.RoleType.ARMY then
                            -- 删除向集结部队的增援
                            MSM.RallyMgr[targetInfo.guildId].req.cacleReinforce( targetInfo.rid, armyInfo.rid )
                        end
                    elseif ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_JOIN_MARCH ) then
                        -- 加入集结点部队中, 取消加入集结
                        MSM.RallyMgr[targetInfo.guildId].req.repatriationRallyArmy( targetInfo.rid, armyInfo.rid )
                    end
                    -- 对象士兵置为0
                    MSM.SceneArmyMgr[_exitArg.objectIndex].post.syncSoldierEmpty( _exitArg.objectIndex )
                    -- 行军回城
                    MSM.MapMarchMgr[_exitArg.objectIndex].req.marchBackCity( _exitArg.rid, _exitArg.objectIndex, true )
                else
                    -- 直接解散
                    ArmyLogic:disbandArmy( _exitArg.rid, armyInfo.armyIndex, true )
                end
            else
                -- 集结部队,解散溃败回城
                if not _exitArg.disband then
                    if _exitArg.guildId > 0 then
                        MSM.RallyMgr[_exitArg.guildId].req.disbandRallyArmy( _exitArg.guildId, _exitArg.rid, true, true )
                    end
                else
                    MSM.SceneArmyMgr[_exitArg.objectIndex].req.disbandRallyArmy( _exitArg.objectIndex )
                end
            end
        elseif MapObjectLogic:checkIsResourceObject( _exitArg.objectType ) then
            -- 资源点的部队被击溃,回城
            local resourceInfo = MSM.SceneResourceMgr[_exitArg.objectIndex].req.getResourceInfo( _exitArg.objectIndex )
            local roleInfo = RoleLogic:getRole( _exitArg.rid, { Enum.Role.pos } )
            local cityIndex = RoleLogic:getRoleCityIndex( _exitArg.rid )
            local serviceIndex = MapLogic:getObjectService( resourceInfo.pos )
            MSM.ResourceMgr[serviceIndex].req.callBackArmy( _exitArg.rid, resourceInfo.armyIndex, {
                targetPos = roleInfo.pos,
                targetType = Enum.MapMarchTargetType.RETREAT,
                targetObjectIndex = cityIndex,
                isDefeat = true
            } )
        elseif MapObjectLogic:checkIsGuildBuildObject( _exitArg.objectType ) then
            -- 联盟建筑中的溃败了,全部部队回城
            MSM.SceneGuildBuildMgr[_exitArg.objectIndex].post.garrisonDefeat( _exitArg.objectIndex, _exitArg.attackerRid )
        elseif MapObjectLogic:checkIsHolyLandObject( _exitArg.objectType ) then
            -- 圣地建筑中的部队溃败，全部回城
            MSM.SceneHolyLandMgr[_exitArg.objectIndex].req.garrisonDefeat( _exitArg.objectIndex, _exitArg.attackerRid )
        end
    else
        -- 没有溃败
        if _exitArg.objectType == Enum.RoleType.MONSTER then
            -- 恢复野蛮人血量
            MSM.SceneMonsterMgr[_exitArg.objectIndex].req.resetMonsterCount( _exitArg.objectIndex )
            -- 野蛮人目标重置
            MSM.SceneMonsterMgr[_exitArg.objectIndex].post.updateMonsterTargetObjectIndex( _exitArg.objectIndex, 0 )
            -- 减少野蛮人攻击数量
            local serviceIndex = MonsterLogic:getMonsterService( _exitArg.objectIndex )
            MSM.MonsterMgr[serviceIndex].post.checkMonsterTimeOut( _exitArg.objectIndex )
        elseif _exitArg.objectType == Enum.RoleType.GUARD_HOLY_LAND then
            -- 恢复守护者血量
            MSM.SceneMonsterMgr[_exitArg.objectIndex].req.resetMonsterCount( _exitArg.objectIndex )
            -- 守护者目标重置
            MSM.SceneMonsterMgr[_exitArg.objectIndex].post.updateMonsterTargetObjectIndex( _exitArg.objectIndex, 0 )
            -- 减少守护者攻击数量
            local guardInfo = MSM.SceneMonsterMgr[_exitArg.objectIndex].req.getMonsterInfo( _exitArg.objectIndex )
            MSM.HolyLandGuardMgr[guardInfo.holyLandId].post.checkMonsterTimeOut( _exitArg.objectIndex )
        elseif _exitArg.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or _exitArg.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 恢复召唤怪物血量
            MSM.SceneMonsterMgr[_exitArg.objectIndex].req.resetMonsterCount( _exitArg.objectIndex )
            -- 召唤怪物目标重置
            MSM.SceneMonsterMgr[_exitArg.objectIndex].post.updateMonsterTargetObjectIndex( _exitArg.objectIndex, 0 )
            -- 减少召唤怪物攻击数量
            MSM.MonsterSummonMgr[_exitArg.objectIndex].post.checkMonsterTimeOut( _exitArg.objectIndex )
        elseif MapObjectLogic:checkIsResourceObject( _exitArg.objectType ) then
            -- 资源点的部队没有被击溃, 更新资源点采集部队定时器
            local resourceInfo = MSM.SceneResourceMgr[_exitArg.objectIndex].req.getResourceInfo( _exitArg.objectIndex )
            local serviceIndex = MapLogic:getObjectService( resourceInfo.pos )
            MSM.ResourceMgr[serviceIndex].req.armyLoadChange( nil, nil, _exitArg.objectIndex )
        elseif _exitArg.objectType == Enum.RoleType.MONSTER_CITY then
            -- 恢复野蛮人城寨血量
            MSM.SceneMonsterCityMgr[_exitArg.objectIndex].req.resetMonsterCityCount( _exitArg.objectIndex )
            -- 减少攻击野蛮人城寨数量
            local service = MonsterCityLogic:getMonsterCityServiceByIndex( _exitArg.objectIndex )
            MSM.MonsterCityMgr[service].post.subAttackArmyNum( _exitArg.objectIndex )
        elseif _exitArg.objectType == Enum.RoleType.ARMY then
            armyInfo = MSM.SceneArmyMgr[_exitArg.objectIndex].req.getArmyInfo( _exitArg.objectIndex )
            if armyInfo then
                if not armyInfo.isRally then
                    -- 非集结部队
                    if not _exitArg.disband then
                        local ret
                        if _exitArg.win == Enum.BattleResult.WIN and MapObjectLogic:checkIsResourceObject( _exitArg.attackTargetType ) then
                            -- 进攻资源点胜利,进入采集
                            ResourceLogic:resourceCollect( _exitArg.rid, armyInfo.armyIndex, _exitArg.attackTargetIndex )
                            ret = true
                        elseif _exitArg.win == Enum.BattleResult.WIN and MapObjectLogic:checkIsHolyLandObject( _exitArg.attackTargetType ) then
                            -- 占领圣地关卡成功, 部队进入关卡圣地驻守
                            if armyInfo.guildId > 0 then
                                local roleArmyInfo = ArmyLogic:getArmy( _exitArg.rid, armyInfo.armyIndex )
                                ret = MSM.GuildMgr[armyInfo.guildId].req.reinforceHolyLand( armyInfo.guildId, _exitArg.rid, armyInfo.armyIndex, roleArmyInfo, _exitArg.attackTargetIndex, _exitArg.attackTargetType )
                            end
                        end

                        -- 如果是无结果战斗,判断是否需要返还体力
                        if _exitArg.win == Enum.BattleResult.NORESULT then
                            local roleArmyInfo = ArmyLogic:getArmy( _exitArg.rid, armyInfo.armyIndex )
                            local roleInfo = RoleLogic:getRole( _exitArg.rid, { Enum.Role.actionForce } )
                            ArmyMarchLogic:checkReturnActionForce( _exitArg.rid, roleInfo, roleArmyInfo )
                        end

                        if not ret then
                            -- 处理回城
                            local situStation = RoleLogic:getRole( _exitArg.rid, Enum.Role.situStation )
                            -- 取军队状态
                            local isArmyStation = ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.STATIONING )
                            if ( situStation and ( _exitArg.battleType and ( _exitArg.battleType == Enum.BattleType.MONSTER
                                or _exitArg.battleType == Enum.BattleType.GUARD_HOLY_LAND or _exitArg.battleType == Enum.BattleType.SUMMON_SINGLE ) ) )
                                or isArmyStation then
                                -- 更新对象状态
                                MSM.SceneArmyMgr[_exitArg.objectIndex].post.addArmyStation( _exitArg.objectIndex )
                            else
                                -- 行军回城(没有行军指令情况下)
                                if not ArmyLogic:checkArmyWalkStatus( armyInfo.status ) then
                                    if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FOLLOWUP ) then
                                        -- 如果正在追击目标,修改为攻击行军
                                        MSM.MapMarchMgr[_exitArg.objectIndex].req.armyMove( _exitArg.objectIndex, _exitArg.attackTargetIndex,
                                                                                            nil, nil, Enum.MapMarchTargetType.ATTACK )
                                    else
                                        MSM.MapMarchMgr[_exitArg.objectIndex].req.marchBackCity( _exitArg.rid, _exitArg.objectIndex )
                                    end
                                end
                            end
                        end
                    else
                        -- 直接解散
                        ArmyLogic:disbandArmy( _exitArg.rid, armyInfo.armyIndex, true )
                    end
                else
                    if not _exitArg.disband then
                        -- 集结部队,解散回城(还在行军中不解散)
                        if not ArmyLogic:checkArmyWalkStatus( armyInfo.status ) then
                            if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FOLLOWUP ) then
                                -- 如果正在追击目标,修改为攻击行军
                                MSM.MapMarchMgr[_exitArg.objectIndex].req.armyMove( _exitArg.objectIndex, _exitArg.attackTargetIndex,
                                                                                    nil, nil, Enum.MapMarchTargetType.RALLY_ATTACK )
                            else
                                if _exitArg.guildId > 0 then
                                    MSM.RallyMgr[_exitArg.guildId].req.disbandRallyArmy( _exitArg.guildId, _exitArg.rid, nil, true, _exitArg.leaderArmyNoEnter )
                                end
                            end
                        end
                    else
                        MSM.SceneArmyMgr[_exitArg.objectIndex].req.disbandRallyArmy( _exitArg.objectIndex )
                    end
                end
            end
        elseif MapObjectLogic:checkIsGuildBuildObject( _exitArg.objectType ) then
            -- 联盟建筑中部队胜利处理, 建造中要重新计算建造速度
            local guildBuild = MSM.SceneGuildBuildMgr[_exitArg.objectIndex].req.getGuildBuildInfo( _exitArg.objectIndex )
            if guildBuild.guildBuildStatus == Enum.GuildBuildStatus.BUILDING then
                MSM.GuildMgr[guildBuild.guildId].post.buildSpeedChange( guildBuild.guildId, nil, guildBuild.buildIndex )
            end
        end
    end

    if _exitArg.objectType == Enum.RoleType.CITY then
        -- 减少部队战斗统计
        RoleLogic:decreaseBattleNum( _exitArg.rid )
        -- 警戒塔开始燃烧
        local guardTowerHp = RoleLogic:getRole( _exitArg.rid, Enum.Role.guardTowerHp )
        if guardTowerHp <= 0 then
            BuildingLogic:startBurnWall( _exitArg.rid )
        end
    elseif _exitArg.objectType  == Enum.RoleType.ARMY then
        -- 减少部队战斗统计
        RoleLogic:decreaseBattleNum( _exitArg.rid )
        -- 部队退出战斗,判断是否攻击资源点
        local targetTypeInfo = MSM.MapObjectTypeMgr[_exitArg.attackTargetIndex].req.getObjectType( _exitArg.attackTargetIndex )
        if targetTypeInfo then
            if MapObjectLogic:checkIsResourceObject( targetTypeInfo.objectType ) then
                -- 移除军队攻击资源点
                MSM.SceneResourceMgr[_exitArg.attackTargetIndex].post.armyNoAttackResource( _exitArg.attackTargetIndex, _exitArg.objectIndex )
            end
        end
    end

    -- 删除战斗索引
    SM.BattleIndexReg.req.removeObjectBattleIndex( _exitArg.objectIndex )
end

---@see 计算城市被掠夺的资源
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:cacleCityBePlunderResource( _exitArg )
    if not _exitArg.rid then
        return
    end
    -- 计算掠夺量
    local plunderRoleInfo = RoleLogic:getRole( _exitArg.rid, {
            Enum.Role.level, Enum.Role.food, Enum.Role.wood, Enum.Role.stone, Enum.Role.gold
        } )
    -- 获取仓库保护量
    local warEhourseInfo = BuildingLogic:getWarEhouseProtect( _exitArg.rid )
    -- 计算可掠夺量
    local cityFood = plunderRoleInfo.food - warEhourseInfo.foodProtect
    if cityFood < 0 then cityFood = 0 end
    local cityWood = plunderRoleInfo.wood - warEhourseInfo.woodProtect
    if cityWood < 0 then cityWood = 0 end
    local cityStone = plunderRoleInfo.stone - warEhourseInfo.stoneProtect
    if cityStone < 0 then cityStone = 0 end
    local cityGold = plunderRoleInfo.gold - warEhourseInfo.goldProtect
    if cityGold < 0 then cityGold = 0 end

     -- 未收取的资源
     local noRecollectResource = MSM.BuildingRoleMgr[_exitArg.rid].req.awardResources( _exitArg.rid, nil, Enum.RoleResourcesAction.PLUNDER, true )
     cityFood = cityFood + noRecollectResource.food
     cityWood = cityWood + noRecollectResource.wood
     cityStone = cityStone + noRecollectResource.stone
     cityGold = cityGold + noRecollectResource.gold

    local rawAllResource = cityFood + cityWood + cityStone + cityGold
    if rawAllResource <= 0 then
        -- 城市没有可以掠夺的资源
        return
    end

    -- 获取全部攻击部队的负载
    local allArmyLoad = 0
    for attackIndex in pairs(_exitArg.battleEndAttackers) do
        local armyLoad = MSM.SceneArmyMgr[attackIndex].req.getArmyResourceLoad( attackIndex )
        if armyLoad and armyLoad > 0 then
            allArmyLoad = allArmyLoad + armyLoad
        end
    end

    if allArmyLoad <= 0 then
        -- 部队没有负载了
        return
    end

    if rawAllResource > allArmyLoad then
        -- 无法掠夺光,计算比例
        cityFood = math.floor( cityFood * (allArmyLoad / rawAllResource) )
        cityWood = math.floor( cityWood * (allArmyLoad / rawAllResource) )
        cityStone = math.floor( cityStone * (allArmyLoad / rawAllResource) )
        cityGold = math.floor( cityGold * (allArmyLoad / rawAllResource) )
    end

    return {
        food = cityFood,
        wood = cityWood,
        stone = cityStone,
        gold = cityGold
    }
end

---@see 攻城战掠夺处理
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchCityPlunder( _exitArg )
    -- 计算掠夺量
    local plunderRoleInfo
    local isMultiArmyAttack = ( table.size(_exitArg.cityAttackCount) > 1 )
    if not isMultiArmyAttack then
        plunderRoleInfo = RoleLogic:getRole( _exitArg.plunderRid, {
            Enum.Role.level, Enum.Role.food, Enum.Role.wood, Enum.Role.stone, Enum.Role.gold
        } )
    else
        -- 多部队,取战斗服务器传过来的
        plunderRoleInfo = _exitArg.plunderResource
    end
    -- 获取仓库保护量
    local warEhourseInfo = BuildingLogic:getWarEhouseProtect( _exitArg.plunderRid )
    -- 未收取的资源
    local noRecollectResource = MSM.BuildingRoleMgr[_exitArg.plunderRid].req.awardResources( _exitArg.plunderRid, nil, Enum.RoleResourcesAction.PLUNDER )
    local allRecollect = math.floor( noRecollectResource.food + noRecollectResource.wood
                                        + noRecollectResource.stone + noRecollectResource.gold )

    -- 计算可掠夺量
    local cityFood = plunderRoleInfo.food - warEhourseInfo.foodProtect
    if cityFood < 0 then cityFood = 0 end
    local cityWood = plunderRoleInfo.wood - warEhourseInfo.woodProtect
    if cityWood < 0 then cityWood = 0 end
    local cityStone = plunderRoleInfo.stone - warEhourseInfo.stoneProtect
    if cityStone < 0 then cityStone = 0 end
    local cityGold = plunderRoleInfo.gold - warEhourseInfo.goldProtect
    if cityGold < 0 then cityGold = 0 end
    -- 多部队掠夺处理
    if isMultiArmyAttack then
        local allArmyCount = 0
        local thisArmyCount = 0
        for attackerIndex, armyCount in pairs(_exitArg.cityAttackCount) do
            allArmyCount = allArmyCount + armyCount
            if attackerIndex == _exitArg.objectIndex then
                thisArmyCount = armyCount
            end
        end

        local percent = thisArmyCount / allArmyCount
        cityFood = math.floor( cityFood * percent )
        cityWood = math.floor( cityWood * percent )
        cityStone = math.floor( cityStone * percent )
        cityGold = math.floor( cityGold * percent )
    end
    -- 计算部队所属角色
    local notifyRids
    local armyInfo = MSM.SceneArmyMgr[_exitArg.objectIndex].req.getArmyInfo( _exitArg.objectIndex )
    if armyInfo and armyInfo.isRally then
        notifyRids = table.indexs(armyInfo.rallyArmy)
    else
        notifyRids = { _exitArg.rid }
    end

    local rawAllResource = cityFood + cityWood + cityStone + cityGold
    if rawAllResource <= 0 and allRecollect <= 0 then
        -- 城市没有可以掠夺的资源
        return notifyRids
    end

    -- 部队负载
    local allResource = rawAllResource
    local armyLoad = MSM.SceneArmyMgr[_exitArg.objectIndex].req.getArmyResourceLoad( _exitArg.objectIndex )
    if armyLoad <= 0 then
        -- 部队负载已满,无法掠夺
        return notifyRids
    end
    if allResource > armyLoad then
        allResource = armyLoad
    end
    -- 扣除未收取的部分
    local leftArmyLoad = armyLoad - allRecollect
    if leftArmyLoad < 0 then
        -- 未收取部分已满,无法掠夺身上的
        allResource = 0
        -- 重新分配未收取的部分
        noRecollectResource.food = math.floor( armyLoad * ( noRecollectResource.food / allRecollect ) )
        noRecollectResource.wood = math.floor( armyLoad * ( noRecollectResource.wood / allRecollect ) )
        noRecollectResource.stone = math.floor( armyLoad * ( noRecollectResource.stone / allRecollect ) )
        noRecollectResource.gold = math.floor( armyLoad * ( noRecollectResource.gold / allRecollect ) )
    end

    -- 计算最终可被掠夺量
    if rawAllResource > 0 then
        cityFood = math.floor( allResource * ( cityFood / rawAllResource ) )
        cityWood = math.floor( allResource * ( cityWood / rawAllResource ) )
        cityStone = math.floor( allResource * ( cityStone / rawAllResource ) )
        cityGold = math.floor( allResource * ( cityGold / rawAllResource ) )
    end
    plunderRoleInfo = RoleLogic:getRole( _exitArg.plunderRid, {
        Enum.Role.level, Enum.Role.food, Enum.Role.wood, Enum.Role.stone, Enum.Role.gold
    } )
    local syncResource = {
        [Enum.Role.food] = math.floor( plunderRoleInfo.food - cityFood ),
        [Enum.Role.wood] = math.floor( plunderRoleInfo.wood - cityWood ),
        [Enum.Role.stone] = math.floor( plunderRoleInfo.stone - cityStone ),
        [Enum.Role.gold] = math.floor( plunderRoleInfo.gold - cityGold ),
    }
    if syncResource.food < 0 then syncResource.food = 0 end
    if syncResource.wood < 0 then syncResource.wood = 0 end
    if syncResource.stone < 0 then syncResource.stone = 0 end
    if syncResource.gold < 0 then syncResource.gold = 0 end
    -- 扣除被掠夺城市的资源
    RoleLogic:setRole( _exitArg.plunderRid, syncResource )
    -- 同步给客户端
    RoleSync:syncSelf( _exitArg.plunderRid, syncResource, true )

    -- 计算部队最终可掠夺资源,扣除被系统吃的部分
    local sResourcesPlunderLoss = CFG.s_ResourcesPlunderLoss:Get( plunderRoleInfo.level )
    local plunderResource = allResource * ( 1 - sResourcesPlunderLoss.lossConstant / 1000 )

    -- 分摊各种类资源
    local plunderFood = 0
    local plunderWood = 0
    local plunderStone = 0
    local plunderGold = 0
    if allResource > 0 then
        plunderFood = math.floor( plunderResource * ( cityFood / allResource ) )
        plunderWood = math.floor( plunderResource * ( cityWood / allResource ) )
        plunderStone = math.floor( plunderResource * ( cityStone / allResource ) )
        plunderGold = math.floor( plunderResource * ( cityGold / allResource ) )
    end

    -- 补足多扣的部分
    local leftResource = plunderResource - plunderFood - plunderWood - plunderStone - plunderGold
    if leftResource > 0 then
        plunderGold = plunderGold + 1
        leftResource = leftResource - 1
        if leftResource > 0 then
            plunderStone = plunderStone + 1
            leftResource = leftResource - 1
            if leftResource > 0 then
                plunderWood = plunderWood + 1
                leftResource = leftResource - 1
                if leftResource > 0 then
                    plunderFood = plunderFood + 1
                end
            end
        end
    end

    -- 增加未收取的部分
    plunderFood = plunderFood + math.floor( noRecollectResource.food )
    plunderWood = plunderWood + math.floor( noRecollectResource.wood )
    plunderStone = plunderStone + math.floor( noRecollectResource.stone )
    plunderGold = plunderGold + math.floor( noRecollectResource.gold )
    -- 更新部队掠夺资源
    MSM.SceneArmyMgr[_exitArg.objectIndex].post.syncArmyResourceLoad( _exitArg.objectIndex, plunderFood, plunderWood, plunderStone, plunderGold )

    return notifyRids, {
        food = plunderFood,
        wood = plunderWood,
        stone = plunderStone,
        gold = plunderGold
    }
end

---@see 处理战报
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchBattleReport( _exitArg, _monsterReward, _killExp )
    if ( not _exitArg.isBeDamageOrHeal or _exitArg.tmpObjectFlag ) and _exitArg.objectType ~= Enum.RoleType.CITY then
        -- 没有受到伤害或者治疗,不发送邮件
        return
    end

    if _exitArg.objectType == Enum.RoleType.CITY
    or _exitArg.objectType == Enum.RoleType.ARMY
    or MapObjectLogic:checkIsGuildBuildObject( _exitArg.objectType )
    or MapObjectLogic:checkIsHolyLandObject( _exitArg.objectType )
    or MapObjectLogic:checkIsResourceObject( _exitArg.objectType ) then
        -- 加入掉落信息
        _exitArg.battleReportEx.rewardInfo = _monsterReward
        _exitArg.battleReportEx.mainHeroExp = _killExp
        _exitArg.battleReportEx.deputyHeroExp = _killExp
        BattleReport:makeBattleReport( _exitArg )
    end

    -- 医院容量上限邮件
    if _exitArg.allHospitalDieCount > 0 then
        local data1 = math.modf( _exitArg.allSoldierHardHurt - _exitArg.allHospitalDieCount )
        local data2 = math.modf( _exitArg.allHospitalDieCount )
        EmailLogic:sendEmail( _exitArg.rid, CFG.s_Config:Get("cureOverstepMailID"),
        { emailContents = { data1, data2 } } )
    end
end

---@see 处理击杀数量
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchKillCount( _exitArg )
    if _exitArg.killCount then
        if _exitArg.rallyKillCounts and table.size(_exitArg.rallyKillCounts) > 0 then
            -- 集结、驻守部队
            for rallyRid, rallyKillCount in pairs(_exitArg.rallyKillCounts) do
                if rallyRid > 0 then
                    self:addRoleKillCount( rallyRid, rallyKillCount )
                end
            end
        else
            if  _exitArg.rid > 0 then
                self:addRoleKillCount( _exitArg.rid, _exitArg.killCount )
            end
        end
    end
end

---@see 增加角色击杀数量
function BattleCallback:addRoleKillCount( _rid, _addKillCount )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.killCount, Enum.Role.guildId } )
    if not roleInfo then
        LOG_ERROR("addRoleKillCount not found roleInfo, rid(%s)", tostring(_rid))
        return
    end
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local newKillCount = roleInfo.killCount or {}
    for level, killInfo in pairs( _addKillCount ) do
        if not newKillCount[level] then
            newKillCount[level] = { level = level, count = killInfo.count }
        else
            newKillCount[level].count = newKillCount[level].count + killInfo.count
        end
    end
    -- 更新累计数量
    RoleLogic:setRole( _rid, { [Enum.Role.killCount] = newKillCount } )
    -- 通知角色
    RoleSync:syncSelf( _rid, { [Enum.Role.killCount] = newKillCount }, true )
    -- 活动击杀处理
    local allKillCount = 0
    for level, killInfo in pairs( _addKillCount ) do
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.KILL_ENEMY_LEVEL_COUNT, killInfo.count, level )
        allKillCount = allKillCount + killInfo.count
    end
    if roleInfo.guildId > 0 then
        RankLogic:update( roleInfo.guildId, Enum.RankType.ALLIANCE_KILL, allKillCount )
    end
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.KILL_ENEMY_ACTION, 1 )
    -- 通知到军队场景处理
    MSM.SceneCityMgr[cityIndex].post.updateCityKillCount( _rid, cityIndex, newKillCount )
    RankLogic:update( _rid, Enum.RankType.ROLE_KILL )
    if roleInfo.guildId and roleInfo.guildId > 0 then
        -- 更新联盟角色击杀数量排行榜
        RankLogic:update( _rid, Enum.RankType.ALLIACEN_ROLE_KILL, nil, roleInfo.guildId )
        local guildJob = GuildLogic:getRoleGuildJob( roleInfo.guildId, _rid )
        if guildJob == Enum.GuildJob.LEADER then
            -- 更新联盟盟主的成员标识
            MSM.GuildIndexMgr[roleInfo.guildId].post.addMemberIndex( roleInfo.guildId, _rid )
        end
    end
end

---@see 处理角色相关统计信息
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:dispatchRoleStatistics( _exitArg )
    if _exitArg.rid and _exitArg.rid > 0 then
        if _exitArg.attackMonsterIds and not table.empty( _exitArg.attackMonsterIds ) then
            -- 击杀野蛮人任务相关统计
            local sMonster
            local taskType = Enum.TaskType.SAVAGE_KILL
            local monsterLevels = {}
            for _, monsterId in pairs( _exitArg.attackMonsterIds ) do
                sMonster = CFG.s_Monster:Get( monsterId )
                if sMonster and not table.empty( sMonster ) then
                    monsterLevels[sMonster.level] = true
                    -- 增加累计统计
                    TaskLogic:addTaskStatisticsSum( _exitArg.rid, taskType, sMonster.level, 1, true )
                    TaskLogic:addTaskStatisticsSum( _exitArg.rid, taskType, Enum.TaskArgDefault, 1 )
                    -- 更新每日任务进度
                    TaskLogic:updateTaskSchedule( _exitArg.rid, { [taskType] = { arg = sMonster.level, addNum = 1 } } )
                end
            end

            -- 依次递增找到击杀的最高等级的野蛮人
            local barbarianLevel = RoleLogic:getRole( _exitArg.rid, Enum.Role.barbarianLevel ) or 0
            local maxLevel = barbarianLevel
            while true do
                if not monsterLevels[maxLevel + 1] then
                    break
                end
                maxLevel = maxLevel + 1
            end

            if maxLevel > barbarianLevel then
                -- 更新击杀野蛮人最高等级
                RoleLogic:setRole( _exitArg.rid, { [Enum.Role.barbarianLevel] = maxLevel } )
                -- 通知客户端
                RoleSync:syncSelf( _exitArg.rid, { [Enum.Role.barbarianLevel] = maxLevel }, true )
            end
        end
        -- 战斗胜利和失败次数统计
        if _exitArg.win == Enum.BattleResult.WIN then
            -- 增加战斗胜利次数
            RoleLogic:addRoleStatistics( _exitArg.rid, Enum.RoleStatisticsType.BATTLE_SUCCES, 1 )
        elseif _exitArg.win == Enum.BattleResult.FAIL then
            -- 增加战斗失败次数
            RoleLogic:addRoleStatistics( _exitArg.rid, Enum.RoleStatisticsType.BATTLE_FAIL, 1 )
        end
        -- 刷新角色在联盟中的战力
        GuildLogic:refreshGuildRolePower( _exitArg.rid )
    end
end

---@see 删除对象战斗状态
---@param _exitArg defaultExitBattleArgClass
function BattleCallback:deleteObjectBattleStatus( _exitArg )
    local objectIndex = _exitArg.objectIndex
    local objectType = _exitArg.objectType

    if objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.SceneArmyMgr[objectIndex].req.updateArmyStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif objectType == Enum.RoleType.CITY then
        -- 城市
        MSM.SceneCityMgr[objectIndex].req.updateCityStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif objectType == Enum.RoleType.MONSTER or objectType == Enum.RoleType.GUARD_HOLY_LAND or objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 野蛮人、圣地守护者
        MSM.SceneMonsterMgr[objectIndex].req.updateMonsterStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif objectType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城市
        MSM.SceneMonsterCityMgr[objectIndex].req.updateMonsterCityStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif MapObjectLogic:checkIsResourceObject( objectType )  then
        -- 资源点
        MSM.SceneResourceMgr[objectIndex].req.updateResourceStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif MapObjectLogic:checkIsGuildBuildObject( objectType ) then
        -- 联盟建筑
        MSM.SceneGuildBuildMgr[objectIndex].req.updateGuildBuildStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif MapObjectLogic:checkIsHolyLandObject( objectType ) then
        -- 圣地建筑
        MSM.SceneHolyLandMgr[objectIndex].req.updateHolyLandStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.SceneExpeditionMgr[objectIndex].req.updateArmyStatus( objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    else
        LOG_WARNING("deleteObjectBattleStatus invalid objectType(%d)", objectType)
    end

    -- 移除对象的roundpos信息
    MSM.AttackAroundPosMgr[objectIndex].post.deleteAllRoundPos( objectIndex )
end

---@see 远征战斗结束回调
function BattleCallback:dispatchExpedition( _exitArg )
    SM.ExpeditionMgr.req.dispatchExpedition( _exitArg )
end

return BattleCallback