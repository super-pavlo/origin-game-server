--[[
* @file : BattleCommon.lua
* @type : lualib
* @author : linfeng
* @created : Wed Nov 22 2017 10:19:32 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 战斗通用逻辑函数实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local MapObjectLogic = require "MapObjectLogic"
local CommonCacle = require "CommonCacle"

local BattleCommon = {}

---@see 获取对象信息
---@param _battleScene defaultBattleSceneClass
---@return battleObjectAttrClass
function BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    return _battleScene.objectInfos[_objectIndex]
end

---@see 复制对象信息
---@param _battleScene defaultBattleSceneClass
---@return battleObjectAttrClass
function BattleCommon:copyObjectInfo( _battleScene, _objectIndex )
    ---@type battleObjectAttrClass
    local obj = table.copy( _battleScene.objectInfos[_objectIndex], true )
    obj.attackObjectSnapShot = {}
    for _, buffInfo in pairs(obj.buffs) do
        buffInfo.addSnapShot = {}
    end

    return obj
end

---@see 根据角色rid和部队armyIndex获取对象信息
---@param _battleScene defaultBattleSceneClass
---@return battleObjectAttrClass
function BattleCommon:getObjectInfoByRidAndArmyIndex( _battleScene, _rid, _armyIndex )
    for _, objectInfo in pairs(_battleScene.objectInfos) do
        if objectInfo.objectRid == _rid and objectInfo.armyIndex == _armyIndex then
            return objectInfo
        end

        -- 如果是集结部队或者驻防的,需要判断队员
        if table.size( objectInfo.rallySoldiers ) > 0 then
            for rallyRid, rallyInfos in pairs(objectInfo.rallySoldiers) do
                for rallyArmyIndex in pairs(rallyInfos) do
                    if rallyRid == _rid and rallyArmyIndex == _armyIndex then
                        return objectInfo
                    end
                end
            end
        end
    end
end

---@see 获取对象部队数量
function BattleCommon:getArmySoldierCount( _objectInfo )
    local allArmyCount = 0
    for _, soldierInfo in pairs(_objectInfo.soldiers) do
        allArmyCount = allArmyCount + soldierInfo.num
    end
    return allArmyCount
end

---@see 判断对象是否已经阵亡
function BattleCommon:isDie( _battleScene, _objectIndex )
    local objectInfo = _battleScene.objectInfos[_objectIndex]
    if not objectInfo or not objectInfo.soldiers or table.empty(objectInfo.soldiers)
    or self:getArmySoldierCount( objectInfo ) <= 0 then
        return true
    end
end

---@see 获取场上未阵亡的对象数量
---@param _battleScene defaultBattleSceneClass
function BattleCommon:getNoDieCount( _battleScene )
    local count = 0
    for _, objectInfo in pairs(_battleScene.objectInfos) do
        if not objectInfo.exitBattleFlag then
            count = count + 1
        end
    end
    return count
end
---@see 获取场上第一个未阵亡的对象
---@return battleObjectAttrClass
function BattleCommon:getFirstNoDieObject( _battleScene )
    for _, objectInfo in pairs(_battleScene.objectInfos) do
        if not objectInfo.exitBattleFlag then
            return objectInfo
        end
    end
end

---@see 判断对象是否有指定状态
function BattleCommon:checkArmyStatus( _armyStatus, _checkStatus )
    return ( _armyStatus & _checkStatus ) ~= 0
end

---@see 判断对象是否处于行军状态
function BattleCommon:checkArmyWalkStatus( _status )
    if self:checkArmyStatus( _status, Enum.ArmyStatus.SPACE_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.ATTACK_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.COLLECT_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.REINFORCE_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.RALLY_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.RETREAT_MARCH ) then
        return true
    end

    return false
end

---@see 获取一个攻击对象
---@param _battleScene defaultBattleSceneClass
function BattleCommon:getAttackTarget( _battleScene, _objectIndex )
    local objectInfo = _battleScene.objectInfos[_objectIndex]
    local attackTargetIndex
    local overAttackRange = false

    local targetInfo = _battleScene.objectInfos[objectInfo.attackTargetIndex]
    if targetInfo then
        -- 判断是否已经退出战斗
        if not targetInfo.exitBattleFlag then
            attackTargetIndex = objectInfo.attackTargetIndex
            targetInfo.allAttackers[_objectIndex] = objectInfo.objectType
            -- 判断攻击范围
            if not self:checkInAttackRange( _battleScene, _objectIndex, attackTargetIndex ) then
                -- 追击中,超过攻击范围
                overAttackRange = true
                repeat
                    -- 怪物不主动追击,除非目标移动了,或者目标不是自己
                    if objectInfo.objectType == Enum.RoleType.MONSTER or objectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
                    or objectInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or objectInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER
                    or ( objectInfo.objectType == Enum.RoleType.EXPEDITION and objectInfo.monsterId > 0 ) then
                        if targetInfo.attackTargetIndex == _objectIndex then
                            -- 目标不在移动,而且不是驻扎
                            if not self:checkArmyWalkStatus( targetInfo.status )
                            and not self:checkArmyStatus( targetInfo.status, Enum.ArmyStatus.STATIONING ) then
                                break
                            end
                            -- 如果目标回头攻击了,也不再追击
                            if self:checkArmyStatus( targetInfo.status, Enum.ArmyStatus.ATTACK_MARCH ) then
                                break
                            end
                        end
                    end

                    -- 建筑不追击
                    if MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType )
                    or MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
                    or objectInfo.objectType == Enum.RoleType.CITY or objectInfo.objectType == Enum.RoleType.MONSTER_CITY then
                        -- 目标在移动,才移除目标
                        if self:checkArmyWalkStatus( targetInfo.status ) then
                            attackTargetIndex = nil
                        end
                        break
                    end

                    -- 同步游服,目标改变(目标移动了)
                    if self:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.STATIONING ) and self:checkArmyWalkStatus( targetInfo.status ) then
                        Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "syncObjectTargetObjectIndex", _objectIndex, objectInfo.objectType, 0 )
                        -- 如果处于驻扎,而且对象处于移动,改变目标
                        attackTargetIndex = nil
                        break
                    end

                    -- 驻扎或者移动不主动追击
                    if self:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.STATIONING )
                    or self:checkArmyWalkStatus( objectInfo.status ) then
                        break
                    end

                    -- 如果目标已经在追击,不再追击(必须是追击自己)
                    if self:checkArmyStatus( targetInfo.status, Enum.ArmyStatus.FOLLOWUP )
                    and targetInfo.attackTargetIndex == _objectIndex then
                        break
                    end

                    -- 追击也算造成伤害,避免脱离战斗
                    if objectInfo.objectType == Enum.RoleType.ARMY and targetInfo.objectType == Enum.RoleType.ARMY then
                        if self:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.FOLLOWUP ) then
                            objectInfo.lastBattleTurn = _battleScene.turn
                        end
                    end

                    -- 调整位置也算造成伤害,避免脱离战斗
                    if self:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.MOVE )
                    or self:checkArmyStatus( targetInfo.status, Enum.ArmyStatus.MOVE ) then
                        objectInfo.lastBattleTurn = _battleScene.turn
                    end

                    -- 如果目标处于围击调整,不进行追击
                    if self:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.MOVE ) then
                        break
                    end

                    -- 通知游服,攻击对象开始追击
                    Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "notifyBeginFollowUp",
                                        objectInfo.attackTargetIndex, targetInfo.objectType, { [_objectIndex] = objectInfo.objectType } )
                until true
            end
        end
    end

    if not attackTargetIndex or self:isDie( _battleScene, attackTargetIndex ) then
        -- 集结部队、攻击集结部队不切换目标(除了建筑,建筑可以切换目标)
        if objectInfo.isRally or ( targetInfo and targetInfo.isRally ) then
            if not MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
            and not MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType ) then
                return
            end
        end
        -- 选择新的目标
        for targetIndex, targetObjectInfo in pairs(_battleScene.objectInfos) do
            repeat
                -- 不能是临时对象
                if targetObjectInfo.tmpObjectFlag then
                    break
                end

                -- 不能是自己
                if targetIndex == _objectIndex then
                    break
                end

                -- 必须是攻击自己的
                if targetObjectInfo.attackTargetIndex ~= _objectIndex then
                    break
                end

                -- 必须没死亡
                if self:isDie( _battleScene, targetIndex ) then
                    break
                end

                -- 判断是否在攻击范围内
                if self:checkInAttackRange( _battleScene, targetIndex, _objectIndex ) then
                    targetObjectInfo.allAttackers[_objectIndex] = objectInfo.objectType
                    return targetIndex, true
                end
            until true
        end
    else
        return attackTargetIndex, nil, overAttackRange
    end
end

---@see 计算对象是否在攻击距离内
function BattleCommon:checkInAttackRange( _battleScene, _defensetIndex, _attackIndex )
    local defenseInfo = _battleScene.objectInfos[_defensetIndex]
    local attackInfo = _battleScene.objectInfos[_attackIndex]
    if not defenseInfo or not attackInfo then
        return false
    end
    local distance = math.sqrt( (defenseInfo.pos.x - attackInfo.pos.x ) ^ 2 + ( defenseInfo.pos.y - attackInfo.pos.y ) ^ 2 )
    -- 计算部队当前攻击半径
    local attackRange = self:cacleArmyRadius( _battleScene, _attackIndex, _defensetIndex )
    return distance <= attackRange
end

---@see 计算部队当前攻击半径
function BattleCommon:cacleArmyRadius( _battleScene, _attackIndex, _defensetIndex )
    local attackInfo = self:getObjectInfo( _battleScene, _attackIndex )
    local defenseInfo = self:getObjectInfo( _battleScene, _defensetIndex )
    local attackArmyRadius = attackInfo.armyRadius
    local defenseArmyRadius = defenseInfo.armyRadius
    if attackInfo.objectType == Enum.RoleType.ARMY or attackInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 部队、远征对象,实时计算
        attackArmyRadius = CommonCacle:getArmyRadius( attackInfo.soldiers, attackInfo.isRally )
    end

    if defenseInfo.objectType == Enum.RoleType.ARMY or defenseInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 部队、远征对象,实时计算
        defenseArmyRadius = CommonCacle:getArmyRadius( defenseInfo.soldiers, defenseInfo.isRally )
    end
    return attackArmyRadius + defenseArmyRadius + CFG.s_Config:Get("attackRange")
end

---@see 两点计算角度
function BattleCommon:cacleAnagle( _from, _to )
    return math.atan(_to.y - _from.y, _to.x - _from.x) * ( 180 / math.pi )
end

---@see 角度转为正值
function BattleCommon:transAngle( _angle )
    if _angle < 0 then
        _angle = _angle + 360
    end
    return _angle
end

---@see 寻找在对象扇形区域范围内的目标
---@param _battleScene defaultBattleSceneClass
function BattleCommon:getObjectIndexsInRange( _battleScene, _attackIndex, _defenseIndex, _radius, _angle, _targetObjectIndexs )
    local attackObjectInfo = self:getObjectInfo( _battleScene, _attackIndex )
    local defenseObjectInfo = self:getObjectInfo( _battleScene, _defenseIndex )
    -- 计算同目标的角度
    local armyAngle = self:transAngle( self:cacleAnagle( attackObjectInfo.pos, defenseObjectInfo.pos ) )
    -- 计算目标方向扇形的角度访问
    local topAngle = self:transAngle( armyAngle - _angle / 2 )
    local bottomAngle = self:transAngle( armyAngle + _angle / 2 )
    if _angle == 360 then
        topAngle = 0
        bottomAngle = 360
    end
    -- 寻找在半径范围内的
    local distance, angleDiff
    local inRangeTargets = {}
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        repeat
            -- 过滤目标
            if objectIndex == _attackIndex or objectIndex == _defenseIndex --[[or objectInfo.attackTargetIndex ~= _attackIndex]] then
                break
            end

            distance = math.sqrt( (attackObjectInfo.pos.x - objectInfo.pos.x ) ^ 2 + ( attackObjectInfo.pos.y - objectInfo.pos.y ) ^ 2 )

            -- 判断是否超过攻击半径
            if distance > _radius then
                break
            end

            -- 区域圆内,判断与底边夹角
            angleDiff = self:transAngle( self:cacleAnagle( attackObjectInfo.pos, objectInfo.pos ) )
            if angleDiff >= topAngle and angleDiff <= bottomAngle then
                -- 在扇形区域中
                _targetObjectIndexs[objectIndex] = {
                                                        objectIndex = objectIndex,
                                                        objectType = objectInfo.objectType,
                                                        guildId = objectInfo.guildId,
                                                        objectRid = objectInfo.objectRid
                                                }
                table.insert( inRangeTargets, objectIndex )
            end
        until true
    end

    -- 找到战斗中的距离最近的军队对象
    local armyObjectIndex
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectInfo.objectType == Enum.RoleType.ARMY then
            armyObjectIndex = objectIndex
            break
        end
    end

    -- 寻找战斗外的目标
    if armyObjectIndex then
        local allTargetInGame = Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "getObjectIndexsInRange",
                                                        armyObjectIndex, Enum.RoleType.ARMY, _battleScene.objectInfos[_attackIndex].pos,
                                                        _radius, _angle, topAngle, bottomAngle, inRangeTargets )

        if allTargetInGame then
            for _, targetInfo in pairs(allTargetInGame) do
                if targetInfo.rid then
                    targetInfo.objectRid = targetInfo.rid
                end
                _targetObjectIndexs[targetInfo.objectIndex] = targetInfo
            end
        end
    end
end

---@see 伤害加入战报
---@param _battleScene defaultBattleSceneClass
function BattleCommon:insertBattleReport( _battleScene, _attackIndex, _defenseIndex, _damage,
                                            _beatBackDamage, _heal, _skillId, _addBuffs, _removeBuffs, _force )

    -- 判断是否是记录战报记录的回合
    if not _force and _battleScene.turn ~= _battleScene.nextRecordTurn then
        return
    end
    local attackObjectInfo = self:getObjectInfo( _battleScene, _attackIndex )
    if not attackObjectInfo or not attackObjectInfo.isBeDamageOrHeal then
        return
    end
    local defenseObjectInfo = self:getObjectInfo( _battleScene, _defenseIndex )
    if attackObjectInfo.tmpObjectFlag or defenseObjectInfo.tmpObjectFlag then
        -- 临时对象不加入战报
        return
    end

    local attackArmyCount = BattleCommon:getArmySoldierCount( attackObjectInfo )
    local defenseArmyCount = BattleCommon:getArmySoldierCount( defenseObjectInfo )

    local battleReportInfo = {
        attackArmyCount = attackArmyCount,
        defenseArmyCount = defenseArmyCount,
        attackIndex = _attackIndex,
        defenseIndex = _defenseIndex,
        reportUniqueIndex = _battleScene.reportUniqueIndex,
        turn = _battleScene.turn,
        -- 文字战报使用,先屏蔽
        --[[
        damage = _damage,
        beatBackDamage = _beatBackDamage,
        heal = _heal,
        skillId = _skillId,
        addBuffs = _addBuffs,
        removeBuffs = _removeBuffs,
        ]]
    }

    _battleScene.reportUniqueIndex = _battleScene.reportUniqueIndex + 1

    if not defenseObjectInfo.battleReport[_attackIndex] then
        defenseObjectInfo.battleReport[_attackIndex] = {
            targetObjectIndex = _attackIndex,
            battleBeginTime = os.time(),
            battleEndTime = 0,
            battleDamageHeal = {}
        }
    end
    table.insert( defenseObjectInfo.battleReport[_attackIndex].battleDamageHeal, battleReportInfo )
end

---@see 加入与对象战斗信息.用于战报
function BattleCommon:addBattleWithObjectInfo( _battleScene, _objectIndex, _attackIndex )
    local objectInfo = self:getObjectInfo( _battleScene, _objectIndex )
    local attackInfo = self:getObjectInfo( _battleScene, _attackIndex )
    if not objectInfo or not attackInfo then
        return
    end
    if objectInfo.tmpObjectFlag or attackInfo.tmpObjectFlag then
        -- 临时对象不加入战报
        return
    end

    if not objectInfo.battleWithInfos[_attackIndex] then
        local pos = attackInfo.pos
        if attackInfo.objectType == Enum.RoleType.ARMY then
            pos = attackInfo.objectCityPos
        end
        objectInfo.battleWithInfos[_attackIndex] = {
            objectIndex = _attackIndex,
            guildId = attackInfo.guildId,
            beginArmyCount = attackInfo.beginArmyCount,
            maxArmyCount = attackInfo.armyCountMax,
            mainHeroId = attackInfo.mainHeroId,
            deputyHeroId = attackInfo.deputyHeroId,
            mainHeroLevel = attackInfo.mainHeroLevel,
            deputyHeroLevel = attackInfo.deputyHeroLevel,
            monsterId = attackInfo.monsterId,
            holyLandBuildMonsterId = attackInfo.holyLandBuildMonsterId,
            objectType = attackInfo.objectType,
            pos = pos,
            rid = attackInfo.objectRid,
            rallyLeader = attackInfo.rallyLeader
        }
    end
end

---@see 更新剩余士兵到参与战斗的目标中.用于战报
---@param _battleScene defaultBattleSceneClass
function BattleCommon:setSoldierHurtOnExitBattle( _battleScene, _exitIndex )
    local exitInfo = self:getObjectInfo( _battleScene, _exitIndex )
    if not exitInfo.isBeDamageOrHeal then
        return
    end
    local exitSoldierHurtRet = exitInfo.soldierHurtWithObjectIndex

    -- 统计剩余部队
    for _, soldierHurtWithObjectInfo in pairs(exitSoldierHurtRet) do
        for soldierId, soldierHurtInfo in pairs(soldierHurtWithObjectInfo.battleSoldierHurt) do
            if exitInfo.soldiers[soldierId] then
                soldierHurtInfo.remain = exitInfo.soldiers[soldierId].num
            else
                soldierHurtInfo.remain = 0
            end
        end
    end

    -- 没有受伤的士兵,也要加入
    for soldierId, soldierInfo in pairs(exitInfo.soldiers) do
        for _, soldierHurtWithObjectInfo in pairs(exitSoldierHurtRet) do
            if not soldierHurtWithObjectInfo.battleSoldierHurt[soldierId] then
                soldierHurtWithObjectInfo.battleSoldierHurt[soldierId] = {
                    soldierId = soldierId,
                    hardHurt = 0,
                    die = 0,
                    minor = 0,
                    heal = 0,
                    remain = soldierInfo.num
                }
            end
        end
    end

    if table.empty( exitSoldierHurtRet ) then
        -- 无交手就结束了战斗
        self:addBattleWithObjectInfo( _battleScene, _exitIndex, exitInfo.attackTargetIndex )
        self:addBattleWithObjectInfo( _battleScene, exitInfo.attackTargetIndex, _exitIndex )

        local exitAttackIndex = exitInfo.attackTargetIndex
        exitSoldierHurtRet[exitAttackIndex] = { battleSoldierHurt = {}, targetObjectIndex = exitAttackIndex }
        for soldierId, soldierInfo in pairs(exitInfo.soldiers) do
            exitSoldierHurtRet[exitAttackIndex].battleSoldierHurt[soldierId] = { remain = soldierInfo.num, soldierId = soldierId }
        end

        self:insertBattleReport( _battleScene, _exitIndex, exitAttackIndex, nil, nil, nil, nil, nil, nil, true )
        self:insertBattleReport( _battleScene, exitAttackIndex, _exitIndex, nil, nil, nil, nil, nil, nil, true )
    end

    -- 集结部队的受伤信息转换
    local rallySoldierHurt = table.copy( exitInfo.rallySoldierHurt, true )
    local finalRallySoldierHurt = {}
    for rallyRid, rallyInfo in pairs(rallySoldierHurt) do
        for rallyArmyIndex, rallyHurtSoldier in pairs(rallyInfo) do
            if exitInfo.rallyHeros[rallyRid] and exitInfo.rallyHeros[rallyRid][rallyArmyIndex] then
                for _, soldierInfo in pairs(rallyHurtSoldier) do
                    soldierInfo.soldierId = soldierInfo.id
                    soldierInfo.die = soldierInfo.allDie
                    soldierInfo.hardHurt = soldierInfo.allHardHurt
                    soldierInfo.minor = soldierInfo.allMinor
                end
                local rallyHurtDetail = {
                    armyIndex = rallyArmyIndex,
                    mainHeroId = exitInfo.rallyHeros[rallyRid][rallyArmyIndex].mainHeroId,
                    mainHeroLevel = exitInfo.rallyHeros[rallyRid][rallyArmyIndex].mainHeroLevel,
                    deputyHeroId = exitInfo.rallyHeros[rallyRid][rallyArmyIndex].deputyHeroId,
                    deputyHeroLevel = exitInfo.rallyHeros[rallyRid][rallyArmyIndex].deputyHeroLevel,
                    rallySoldierDetail = rallyHurtSoldier,
                    joinTime = exitInfo.rallyHeros[rallyRid][rallyArmyIndex].joinTime,
                }
                if not finalRallySoldierHurt[rallyRid] then
                    finalRallySoldierHurt[rallyRid] = {
                        rallyRid = rallyRid,
                        rallyHurt = {
                            [rallyArmyIndex] = rallyHurtDetail
                        }
                    }
                else
                    finalRallySoldierHurt[rallyRid].rallyHurt[rallyArmyIndex] = rallyHurtDetail
                end
                finalRallySoldierHurt[rallyRid].isLeader = ( rallyRid == exitInfo.rallyLeader )
            end
        end
    end

    -- 离开的部队也要加入
    local exitRallySoldierHurt = table.copy( exitInfo.leavedRallySoldierHurt, true )
    for rallyRid, rallyInfo in pairs(exitRallySoldierHurt) do
        for rallyArmyIndex, rallyHurtSoldier in pairs(rallyInfo) do
            if exitInfo.leavedRallyHeros[rallyRid] and exitInfo.leavedRallyHeros[rallyRid][rallyArmyIndex] then
                for _, soldierInfo in pairs(rallyHurtSoldier) do
                    soldierInfo.soldierId = soldierInfo.id
                    soldierInfo.die = soldierInfo.allDie
                    soldierInfo.hardHurt = soldierInfo.allHardHurt
                    soldierInfo.minor = soldierInfo.allMinor
                end
                local rallyHurtDetail = {
                    armyIndex = rallyArmyIndex,
                    mainHeroId = exitInfo.leavedRallyHeros[rallyRid][rallyArmyIndex].mainHeroId,
                    mainHeroLevel = exitInfo.leavedRallyHeros[rallyRid][rallyArmyIndex].mainHeroLevel,
                    deputyHeroId = exitInfo.leavedRallyHeros[rallyRid][rallyArmyIndex].deputyHeroId,
                    deputyHeroLevel = exitInfo.leavedRallyHeros[rallyRid][rallyArmyIndex].deputyHeroLevel,
                    rallySoldierDetail = rallyHurtSoldier,
                    joinTime = exitInfo.leavedRallyHeros[rallyRid][rallyArmyIndex].joinTime,
                }
                if not finalRallySoldierHurt[rallyRid] then
                    finalRallySoldierHurt[rallyRid] = {
                        rallyRid = rallyRid,
                        rallyHurt = {
                            [rallyArmyIndex] = rallyHurtDetail
                        }
                    }
                else
                    finalRallySoldierHurt[rallyRid].rallyHurt[rallyArmyIndex] = rallyHurtDetail
                end
                -- 一定不是队长
                finalRallySoldierHurt[rallyRid].isLeader = false
            end
        end
    end

    -- 更新到其他人的数据中
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectIndex == _exitIndex or objectInfo.battleWithInfos[_exitIndex] then
            if objectIndex == _exitIndex then
                local pos = objectInfo.pos
                if objectInfo.objectType == Enum.RoleType.ARMY then
                    pos = objectInfo.objectCityPos
                end

                -- 自己的也要加
                objectInfo.battleWithInfos[_exitIndex] = {
                    objectIndex = _exitIndex,
                    guildId = objectInfo.guildId,
                    beginArmyCount = objectInfo.beginArmyCount,
                    maxArmyCount = objectInfo.armyCountMax,
                    mainHeroId = objectInfo.mainHeroId,
                    deputyHeroId = objectInfo.deputyHeroId,
                    mainHeroLevel = objectInfo.mainHeroLevel,
                    deputyHeroLevel = objectInfo.deputyHeroLevel,
                    monsterId = objectInfo.monsterId,
                    holyLandBuildMonsterId = objectInfo.holyLandBuildMonsterId,
                    objectType = objectInfo.objectType,
                    pos = pos,
                    rid = objectInfo.objectRid,
                    rallyLeader = objectInfo.rallyLeader
                }
            end
            objectInfo.battleWithInfos[_exitIndex].soldierDetail = exitSoldierHurtRet
            objectInfo.battleWithInfos[_exitIndex].hurt = objectInfo.allHurt
            objectInfo.battleWithInfos[_exitIndex].endArmyCount = self:getArmySoldierCount( exitInfo )
            objectInfo.battleWithInfos[_exitIndex].battleRallySoldierHurt = finalRallySoldierHurt

            -- 更新战报中的战斗结束时间
            if objectInfo.battleReport[_exitIndex] then
                objectInfo.battleReport[_exitIndex].battleEndTime = os.time()
            end
        end
    end

    -- 检查同其他人的伤害,先退出的可能无信息
    for objectIndex, battleWithInfo in pairs(exitInfo.battleWithInfos) do
        if not battleWithInfo.soldierDetail or table.empty( battleWithInfo.soldierDetail ) then
            local otherObjectInfo = _battleScene.objectInfos[objectIndex]
            if otherObjectInfo then
                -- 统计剩余部队
                local otherSoldierHurtRet = otherObjectInfo.soldierHurtWithObjectIndex
                for _, soldierHurtWithObjectInfo in pairs(otherSoldierHurtRet) do
                    for soldierId, soldierHurtInfo in pairs(soldierHurtWithObjectInfo.battleSoldierHurt) do
                        if otherObjectInfo.soldiers[soldierId] then
                            soldierHurtInfo.remain = otherObjectInfo.soldiers[soldierId].num
                        else
                            soldierHurtInfo.remain = 0
                        end
                    end
                end

                -- 没伤害信息,取剩余士兵
                if table.empty( otherSoldierHurtRet ) then
                    local newOtherSoldierHurtRet = {}
                    newOtherSoldierHurtRet[_exitIndex] = { targetObejectIndex = _exitIndex, battleSoldierHurt = {} }
                    battleWithInfo.soldierDetail = newOtherSoldierHurtRet
                else
                    battleWithInfo.soldierDetail = otherSoldierHurtRet
                end
            end
        end
    end

    -- 检查同其他人的战斗结束时间,其他人可能还未退战斗
    for _, battleWithInfo in pairs(exitInfo.battleReport) do
        if battleWithInfo.battleEndTime == 0 then
            battleWithInfo.battleEndTime = os.time()
        end
    end
end

---@see 发送伤害信息
---@param _battleScene defaultBattleSceneClass
function BattleCommon:sendBattleDamageInfo( _battleScene )
    -- 生成伤害信息
    local battleDamageInfos = {}
    local notifyObjectType, notifyObjectIndex
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        local battleRemainSoldiers = {}
        if objectInfo.isRally then
            -- 集结部队(一个角色只能加入一支部队到集结部队中)
            for rid, rallySoldierInfo in pairs(objectInfo.rallySoldiers) do
                for _, soldiers in pairs(rallySoldierInfo) do
                    battleRemainSoldiers[rid] = { rid = rid, remainSoldier = soldiers }
                end
            end
        else
            -- 非集结部队
            battleRemainSoldiers = { [objectInfo.objectRid] = { rid = objectInfo.objectRid, remainSoldier = objectInfo.soldiers } }
        end

        local armyRadius
        if objectInfo.objectType == Enum.RoleType.ARMY or objectInfo.objectType == Enum.RoleType.MONSTER
        or objectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND or objectInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
            armyRadius = CommonCacle:getArmyRadius( objectInfo.soldiers, objectInfo.isRally )
        end
        local damageInfo = {
            objectIndex = objectIndex,
            objectType = objectInfo.objectType,
            damage = objectInfo.allTurnHurt,
            battleRemainSoldiers = battleRemainSoldiers,
            skillInfo = objectInfo.turnSkillInfo,
            dotDamage = objectInfo.turnDotDamage,
            hotHeal = objectInfo.turnHotHeal,
            armyRadius = armyRadius
        }

        if table.empty( damageInfo.skillInfo ) then
            damageInfo.skillInfo = nil
        end

        -- 造成伤害或者治疗才同步
        if damageInfo.damage > 0 or not table.empty(objectInfo.turnSkillInfo) or damageInfo.dotDamage > 0
        or damageInfo.hotHeal > 0 then
            if damageInfo.dotDamage == 0 then
                damageInfo.dotDamage = nil
            end
            if damageInfo.hotHeal == 0 then
                damageInfo.hotHeal = nil
            end
            if damageInfo.damage == 0 then
                damageInfo.damage = nil
            end
            -- 加入序列
            battleDamageInfos[objectIndex] = damageInfo
        end

        objectInfo.allTurnHurt = 0
        objectInfo.turnDotDamage = 0
        objectInfo.turnHotHeal = 0
        objectInfo.turnSkillInfo = {}
        if not notifyObjectType and ( objectInfo.objectType == Enum.RoleType.ARMY
        or ( objectInfo.objectRid and objectInfo.objectRid > 0 and objectInfo.objectType == Enum.RoleType.EXPEDITION )) then
            notifyObjectType = objectInfo.objectType
            notifyObjectIndex = objectIndex
        end
    end

    -- 伤害发送给游服
    if not table.empty(battleDamageInfos) then
        Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "brocastBattleDamage", _battleScene.battleIndex,
                            battleDamageInfos, notifyObjectType, notifyObjectIndex )
    end
end

---@see 判断其他人是否都是失败
---@param _battleScene defaultBattleSceneClass 战斗场景
function BattleCommon:checkOtherAllFail( _battleScene, _objectIndex )
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectIndex ~= _objectIndex then
            if not objectInfo.exitBattleFlag or objectInfo.exitBattleFlag ~= Enum.BattleResult.FAIL then
                return false
            end
        end
    end
    return true
end

---@see 判断攻击目标是否溃败
---@param _battleScene defaultBattleSceneClass 战斗场景
function BattleCommon:checkTargetFail( _battleScene, _objectIndex )
    local objectInfo = self:getObjectInfo( _battleScene, _objectIndex )
    local targetInfo = self:getObjectInfo( _battleScene, objectInfo.attackTargetIndex )
    if not targetInfo or ( targetInfo.exitBattleFlag and targetInfo.exitBattleFlag == Enum.BattleResult.FAIL )
    or self:isDie( _battleScene, objectInfo.attackTargetIndex ) then
        return true
    end
end

---@see 从集结.驻防部队中退出.增加到离开信息中
function BattleCommon:addLeaveRallyInfo( _battleScene, _objectIndex, _leaveRallyRid, _leaveRallyArmyIndex )
    local objectInfo = self:getObjectInfo( _battleScene, _objectIndex )
    if not objectInfo.leavedRallyHeros[_leaveRallyRid] then
        objectInfo.leavedRallyHeros[_leaveRallyRid] = {}
        objectInfo.leavedRallyHeros[_leaveRallyRid][_leaveRallyArmyIndex] = {}
    elseif not objectInfo.leavedRallyHeros[_leaveRallyRid][_leaveRallyArmyIndex] then
        objectInfo.leavedRallyHeros[_leaveRallyRid][_leaveRallyArmyIndex] = {}
    end

    if not objectInfo.leavedRallySoldierHurt[_leaveRallyRid] then
        objectInfo.leavedRallySoldierHurt[_leaveRallyRid] = {}
        objectInfo.leavedRallySoldierHurt[_leaveRallyRid][_leaveRallyArmyIndex] = {}
    elseif not objectInfo.leavedRallySoldierHurt[_leaveRallyRid][_leaveRallyArmyIndex] then
        objectInfo.leavedRallySoldierHurt[_leaveRallyRid][_leaveRallyArmyIndex] = {}
    end

    objectInfo.leavedRallyHeros[_leaveRallyRid][_leaveRallyArmyIndex] = objectInfo.rallyHeros[_leaveRallyRid][_leaveRallyArmyIndex]
    objectInfo.leavedRallySoldierHurt[_leaveRallyRid][_leaveRallyArmyIndex] = objectInfo.rallySoldierHurt[_leaveRallyRid][_leaveRallyArmyIndex]
end

return BattleCommon