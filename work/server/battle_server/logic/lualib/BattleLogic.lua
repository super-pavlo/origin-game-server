--[[
 * @file : BattleLogic.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2020-01-20 16:28:10
 * @Last Modified time: 2020-01-20 16:28:10
 * @department : Arabic Studio
 * @brief : 战斗逻辑处理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BattleCacle = require "BattleCacle"
local BattleCommon = require "BattleCommon"
local BattleSkill = require "BattleSkill"
local BattleBuff = require "BattleBuff"
local BattleDef = require "BattleDef"
local BattleTypeCacle = require "BattleTypeCacle"
local MapObjectLogic = require "MapObjectLogic"
local BattleLogic = {}

---@see 战斗结束检测
---@param _allBattleScene table<integer, defaultBattleSceneClass>
function BattleLogic:battleOverWorkImpl( _allBattleScene )
    for battleIndex, battleScene in pairs(_allBattleScene) do
        if table.size(battleScene.objectInfos) <= 1 then
            -- 结束战斗
            _allBattleScene[battleIndex] = nil
        end
    end
end

---@see 战斗定时器处理
---@param _battleScene defaultBattleSceneClass
function BattleLogic:battleWorkImpl( _battleScene )
    local damage, beatBackDamage
    for attackIndex, attackObjectInfo in pairs(_battleScene.objectInfos) do
        repeat
            if attackObjectInfo.tmpObjectFlag then
                -- 临时对象不主动攻击
                break
            end

            -- 追击目标不会对目标造成伤害,移动时也不攻击目标,不主动攻击的只会反击
            if BattleCommon:checkArmyWalkStatus( attackObjectInfo.status ) then
                break
            end
            -- 目标已经死亡
            if BattleCommon:isDie( _battleScene, attackIndex ) then
                break
            end
            -- 攻击目标是否存在
            local defenseIndex, newTarget, overAttackRange = BattleCommon:getAttackTarget( _battleScene, attackIndex )
            if defenseIndex then
                -- 是否追击超过攻击距离
                if not overAttackRange then
                    local defenseObjectInfo = _battleScene.objectInfos[defenseIndex]
                    if defenseObjectInfo then
                        -- 同联盟不能攻击
                        if attackObjectInfo.guildId > 0 and attackObjectInfo.guildId == defenseObjectInfo.guildId then
                            break
                        end

                        -- 增加参与战斗对象
                        BattleCommon:addBattleWithObjectInfo( _battleScene, defenseIndex, attackIndex )
                        BattleCommon:addBattleWithObjectInfo( _battleScene, attackIndex, defenseIndex )
                        -- 新目标,或者可以打到之前的目标
                        if newTarget or ( attackObjectInfo.isOutAttackRange and attackObjectInfo.outAttackRangeIndex == defenseIndex ) then
                            -- 同步游服,目标改变
                            Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "syncObjectTargetObjectIndex",
                                                    attackIndex, attackObjectInfo.objectType, defenseIndex, defenseObjectInfo.objectType )
                        end

                        -- 如果对象处于追击,而目标不再移动,停止追击
                        if BattleCommon:checkArmyStatus( attackObjectInfo.status, Enum.ArmyStatus.FOLLOWUP )
                        and not BattleCommon:checkArmyWalkStatus( defenseObjectInfo.status ) then
                            -- 通知游服,对象停止追击
                            Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "notifyEndFollowUp", attackIndex, attackObjectInfo.objectType )
                        end

                        if newTarget or table.empty( attackObjectInfo.attackObjectSnapShot ) then
                            attackObjectInfo.attackObjectSnapShot = BattleCommon:copyObjectInfo( _battleScene, defenseIndex )
                            attackObjectInfo.attackTargetIndex = defenseIndex
                        end

                        -- 被沉默攻击不进行普攻
                        if not BattleBuff:isSilentAttack( _battleScene, attackIndex ) then
                            -- 攻击伤害
                            damage = BattleCacle:cacleAttackDamage( _battleScene, attackIndex, defenseIndex )
                            -- 计算护盾
                            damage = BattleBuff:cacleShiled( _battleScene, defenseIndex, damage )
                            if damage > 0 then
                                -- 统计受到伤害
                                BattleCacle:addObjectHurt( _battleScene, defenseIndex, damage )
                                -- 计算部队损伤
                                BattleCacle:cacleObjectHurtDie( _battleScene, attackIndex, defenseIndex )
                                -- 加入战报
                                BattleCommon:insertBattleReport( _battleScene, attackIndex, defenseIndex, damage )
                                -- 更新最后战斗回合
                                BattleCacle:refreshLastBattleTurn( _battleScene, attackIndex )
                                -- 造成伤害后触发的技能
                                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.MAKE_DAMAGE )
                                -- 受到普攻伤害时触发的技能
                                BattleSkill:triggerSkill( _battleScene, defenseIndex, attackIndex, Enum.SkillTrigger.BE_NORMAL_DAMAGE )
                                -- 受到任意伤害时触发的技能
                                BattleSkill:triggerSkill( _battleScene, defenseIndex, attackIndex, Enum.SkillTrigger.BE_ANY_DAMAGE )
                                -- 普通攻击建筑时
                                if MapObjectLogic:checkIsGuildBuildObject( defenseObjectInfo.objectType )
                                or MapObjectLogic:checkIsResourceObject( defenseObjectInfo.objectType )
                                or MapObjectLogic:checkIsHolyLandObject( defenseObjectInfo.objectType )
                                or defenseObjectInfo.objectType == Enum.RoleType.CITY then
                                    BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ATTACK_BUILD )
                                end
                            end
                            -- 使用普攻后触发的技能
                            BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.NORMAL_ATTACK )
                            -- 反击伤害
                            beatBackDamage = BattleCacle:cacleBeatBackDamage( _battleScene, attackIndex, defenseIndex )
                            -- 计算护盾
                            beatBackDamage = BattleBuff:cacleShiled( _battleScene, attackIndex, beatBackDamage )
                            if beatBackDamage > 0 then
                                -- 统计受到伤害
                                BattleCacle:addObjectHurt( _battleScene, attackIndex, beatBackDamage )
                                -- 计算部队损伤
                                BattleCacle:cacleObjectHurtDie( _battleScene, defenseIndex, attackIndex )
                                -- 加入战报
                                BattleCommon:insertBattleReport( _battleScene, defenseIndex, attackIndex, nil, beatBackDamage )
                                -- 造成伤害后触发的技能
                                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.MAKE_DAMAGE )
                                -- 受到普攻伤害时触发的技能
                                BattleSkill:triggerSkill( _battleScene, defenseIndex, attackIndex, Enum.SkillTrigger.BE_BEAT_BACK_DAMAGE )
                                -- 受到任意伤害时触发的技能
                                BattleSkill:triggerSkill( _battleScene, defenseIndex, attackIndex, Enum.SkillTrigger.BE_ANY_DAMAGE )
                            end

                            -- 使用反击后触发的技能
                            BattleSkill:triggerSkill( _battleScene, defenseIndex, attackIndex, Enum.SkillTrigger.BEATBACK )
                            -- 普攻怒气获取
                            BattleCacle:normalAttackAddAnger( _battleScene, attackIndex )
                        end

                        -- 被沉默技能无法使用
                        if not BattleBuff:isSilentSkill( _battleScene, attackIndex ) then
                            -- 怒气值大于等于X时触发技能
                            BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ANGER_MORE )
                        end

                        -- 记录攻击者,用于区分战报
                        if not attackObjectInfo.historyBattleObjectType[defenseIndex] then
                            attackObjectInfo.historyBattleObjectType[defenseIndex] = defenseObjectInfo.objectType
                        end
                        if not defenseObjectInfo.historyBattleObjectType[attackIndex] then
                            defenseObjectInfo.historyBattleObjectType[attackIndex] = attackObjectInfo.objectType
                        end

                        if defenseObjectInfo.objectType == Enum.RoleType.CITY then
                            -- 攻击玩家城市时
                            BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ATTACK_CITY )
                            -- 攻击玩家城市X回合时
                            BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ATTACK_CITY_TURN_MORE )
                        end

                        -- 攻击联盟建筑、圣地时触发被动
                        if MapObjectLogic:checkIsGuildBuildObject( defenseObjectInfo.objectType )
                        or MapObjectLogic:checkIsHolyLandObject( defenseObjectInfo.objectType ) then
                            BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ATTACK_OUT_CITY )
                        end
                    end
                end

                attackObjectInfo.isOutAttackRange = overAttackRange
                attackObjectInfo.outAttackRangeIndex = defenseIndex

                -- 如果最后伤害回合为0,触发进入战斗被动
                if attackObjectInfo.lastBattleTurn <= 0 then
                    BattleSkill:triggerSkill( _battleScene, attackIndex, attackIndex, Enum.SkillTrigger.ENTER_BATTLE )
                end
                -- 自己步兵数量占比大于等于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_INFANTRY_MORE )
                -- 自己步兵数量占比小于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_INFANTRY_LESS )
                -- 自己骑兵数量占比大于等于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_CAVALRY_MORE )
                -- 自己骑兵数量占比小于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_CAVALRY_LESS )
                -- 自己弓兵数量占比于等于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_ARCHER_MORE )
                -- 自己弓兵数量占比小于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_ARCHER_LESS )
                -- 自己攻城单位数量占比于等于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_SIEGE_UNIT_MORE )
                -- 自己攻城单位数量占比小于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_SIEGE_UNIT_LESS )
                -- 自己部队兵力百分比大于等于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_ARMY_COUNT_MORE )
                -- 自己部队兵力百分比小于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_ARMY_COUNT_LESS )
                -- 自己兵种类型数量大于等于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_SOLDIER_COUNT_MORE )
                -- 自己兵种类型数量小于X 触发的技能
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.SELF_SOLDIER_COUNT_LESS )

                -- 被夹击时
                if table.size( attackObjectInfo.allAttackers ) > 1 then
                    BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.BE_CONVER_ATTACK )
                end
                -- 敌方拥有护盾时
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ENEMY_HAD_SHILED )
                -- 敌方拥有BUFF类型时
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ENEMY_HAD_BUFF )
                -- 敌方拥有DEBUFF类型时
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ENEMY_HAD_DEBUFF )
                -- 敌方部队兵力百分比大于等于X
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ENEMY_SOLDIER_COUNT_MORE )
                -- 敌方部队兵力百分比小于X
                BattleSkill:triggerSkill( _battleScene, attackIndex, defenseIndex, Enum.SkillTrigger.ENEMY_SOLDIER_COUNT_LESS )
            else
                -- 如果是建筑类的没找到目标,直接退出战斗
                if MapObjectLogic:checkIsGuildBuildObject( attackObjectInfo.objectType )
                or MapObjectLogic:checkIsHolyLandObject( attackObjectInfo.objectType )
                or attackObjectInfo.objectType == Enum.RoleType.CITY or attackObjectInfo.objectType == Enum.RoleType.MONSTER_CITY then
                    -- 没有人在攻击建筑
                    attackObjectInfo.exitBattleFlag = true
                    if BattleCommon:checkTargetFail( _battleScene, attackIndex ) then
                        attackObjectInfo.exitBattleWin = Enum.BattleResult.WIN
                    else
                        attackObjectInfo.exitBattleWin = Enum.BattleResult.NORESULT
                    end
                end
            end
        until true
    end

    -- 处理状态效果
    self:dealDotAndHot( _battleScene )

    -- 发送伤害
    BattleCommon:sendBattleDamageInfo( _battleScene )

    -- 是否溃败
    for _, objectInfo in pairs(_battleScene.objectInfos) do
        if BattleCommon:getArmySoldierCount( objectInfo ) <= 0 then
            -- 通知游戏服务器,这里是溃散了
            objectInfo.exitBattleFlag = true
            objectInfo.exitBattleWin = Enum.BattleResult.FAIL
        end
    end

    -- 是否无目标
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if not objectInfo.exitBattleFlag and not BattleCommon:getAttackTarget( _battleScene, objectIndex ) then
            -- 未找到目标
            objectInfo.exitBattleFlag = true
            if BattleCommon:checkTargetFail( _battleScene, objectIndex ) then
                objectInfo.exitBattleWin = Enum.BattleResult.WIN
            else
                objectInfo.exitBattleWin = Enum.BattleResult.NORESULT
            end
        end
    end

    -- 处理超时回合脱离战斗
    self:turnOutExitBattle( _battleScene )

    -- 统计场上剩余的未死亡数量
    local objectCount = BattleCommon:getNoDieCount( _battleScene )
    -- 如果只剩一个,判断为胜利
    if objectCount == 1 then
        local winObjectInfo = BattleCommon:getFirstNoDieObject( _battleScene )
        if winObjectInfo then
            winObjectInfo.exitBattleFlag = true
            if BattleCommon:checkArmyWalkStatus( winObjectInfo.status ) then
                winObjectInfo.exitBattleWin = Enum.BattleResult.NORESULT
            else
                -- 是否其他目标都是失败的
                if BattleCommon:checkOtherAllFail( _battleScene, winObjectInfo.objectIndex ) then
                    winObjectInfo.exitBattleWin = Enum.BattleResult.WIN
                else
                    winObjectInfo.exitBattleWin = Enum.BattleResult.NORESULT
                end
            end
        end
    end

    local isTriggerSkill
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectInfo.exitBattleFlag and objectInfo.exitBattleWin == Enum.BattleResult.FAIL then
            if objectInfo.objectType == Enum.RoleType.MONSTER or objectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND then
                -- 处理怪物战败
                local isTriggerAttackTarget
                -- 寻找攻击方
                for attackIndex, info in pairs(_battleScene.objectInfos) do
                    if info.attackTargetIndex == objectIndex then
                        -- 触发击败野蛮人和中立单位后的技能
                        if BattleSkill:triggerSkill( _battleScene, attackIndex, objectIndex, Enum.SkillTrigger.AFTER_KILL_MONSTER ) then
                            isTriggerSkill = true
                        end
                        if attackIndex == objectInfo.attackTargetIndex then
                            isTriggerAttackTarget = true
                        end
                    end
                end
                -- 正在攻击的对象也要触发
                if not isTriggerAttackTarget then
                    if BattleSkill:triggerSkill( _battleScene, objectInfo.attackTargetIndex, objectIndex, Enum.SkillTrigger.AFTER_KILL_MONSTER ) then
                        isTriggerSkill = true
                    end
                end
            elseif objectInfo.objectType == Enum.RoleType.ARMY then
                -- 处理部队战败
                local isTriggerAttackTarget
                -- 寻找攻击方
                for attackIndex, info in pairs(_battleScene.objectInfos) do
                    if info.attackTargetIndex == objectIndex then
                        -- 触发击败部队后的技能
                        if BattleSkill:triggerSkill( _battleScene, attackIndex, objectIndex, Enum.SkillTrigger.WIN_OUT_ARMY ) then
                            isTriggerSkill = true
                        end
                        if attackIndex == objectInfo.attackTargetIndex then
                            isTriggerAttackTarget = true
                        end
                    end
                end
                -- 正在攻击的对象也要触发
                if not isTriggerAttackTarget then
                    if BattleSkill:triggerSkill( _battleScene, objectInfo.attackTargetIndex, objectIndex, Enum.SkillTrigger.WIN_OUT_ARMY ) then
                        isTriggerSkill = true
                    end
                end
            end

            -- 处理任意战败
            local isTriggerAttackTarget
            -- 寻找攻击方
            for attackIndex, info in pairs(_battleScene.objectInfos) do
                if info.attackTargetIndex == objectIndex then
                    if objectInfo.monsterId and objectInfo.monsterId > 0 then
                        table.insert( info.attackMonsterIds, objectInfo.monsterId )
                    end
                    -- 触发击败任意敌方部队后的技能
                    if BattleSkill:triggerSkill( _battleScene, attackIndex, objectIndex, Enum.SkillTrigger.WIN_ANY_ENEMY ) then
                        isTriggerSkill = true
                    end
                    if attackIndex == objectInfo.attackTargetIndex then
                        isTriggerAttackTarget = true
                    end
                end
            end
            -- 正在攻击的对象也要触发
            if not isTriggerAttackTarget then
                if BattleSkill:triggerSkill( _battleScene, objectInfo.attackTargetIndex, objectIndex, Enum.SkillTrigger.WIN_ANY_ENEMY ) then
                    isTriggerSkill = true
                end
            end
        end
    end

    if isTriggerSkill then
        -- 发送伤害
        BattleCommon:sendBattleDamageInfo( _battleScene )
    end

    -- 处理回合结束退出战斗的对象,失败先退
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectInfo.exitBattleFlag and objectInfo.exitBattleWin == Enum.BattleResult.FAIL then
            local ret, err = pcall(self.objectEndBattle, self, _battleScene, objectIndex, objectInfo.exitBattleWin )
            if not ret then
                LOG_ERROR("objectEndBattle fail:%s", err)
            end
            -- 从目标的攻击者中退出
            if _battleScene.objectInfos[objectInfo.attackTargetIndex] then
                _battleScene.objectInfos[objectInfo.attackTargetIndex].allAttackers[objectIndex] = nil
            end
        end
    end
    -- 处理非失败退出战斗的
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectInfo.exitBattleFlag and objectInfo.exitBattleWin ~= Enum.BattleResult.FAIL then
            local ret, err = pcall(self.objectEndBattle, self, _battleScene, objectIndex, objectInfo.exitBattleWin )
            if not ret then
                LOG_ERROR("objectEndBattle fail:%s", err)
            end
            -- 从目标的攻击者中退出
            if _battleScene.objectInfos[objectInfo.attackTargetIndex] then
                _battleScene.objectInfos[objectInfo.attackTargetIndex].allAttackers[objectIndex] = nil
            end
        end
    end

    -- 处理对象退出战斗
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectInfo.exitBattleFlag then
            _battleScene.objectInfos[objectIndex] = nil
        end
    end

    -- 判断战斗是否已经结束
    objectCount = table.size(_battleScene.objectInfos)
    if objectCount <= 0 then
        MSM.BattleSceneMgr[_battleScene.battleIndex].req.deleteBattleScene( _battleScene.battleIndex )
    else
        -- 回合结束,清理相关数据
        self:turnOver( _battleScene )
    end
end

---@see 处理超时回合脱离战斗
---@param _battleScene defaultBattleSceneClass
function BattleLogic:turnOutExitBattle( _battleScene )
    local outOfCombat = CFG.s_Config:Get("outOfCombat")
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        -- 不处于追击,而且不被追击
        if not BattleCommon:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.FOLLOWUP ) then
            local beFollowUped = false
            for subObjectIndex, subObjectInfo in pairs(_battleScene.objectInfos) do
                if subObjectIndex ~= objectIndex and subObjectInfo.attackTargetIndex == objectIndex
                and BattleCommon:checkArmyStatus( subObjectInfo.status, Enum.ArmyStatus.FOLLOWUP ) then
                    beFollowUped = true
                    break
                end
            end

            if not beFollowUped then
                if objectInfo.lastBattleTurn + outOfCombat <= _battleScene.turn then
                    objectInfo.exitBattleFlag = true
                    objectInfo.exitBattleWin = Enum.BattleResult.NORESULT
                end
            end
        end
    end
end

---@see 回合结束.清理相关数据
---@param _battleScene defaultBattleSceneClass
function BattleLogic:turnOver( _battleScene )
    for _, objectInfo in pairs(_battleScene.objectInfos) do
        -- 清空回合技能触发限制
        objectInfo.triggerSkillCount = {}
        --[[
        -- 清理临时对象
        if objectInfo.tmpObjectFlag then
            -- 通知游服退战斗
            Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "notifyObjectLeaveBattle", objectIndex, objectInfo.objectType )
            _battleScene.objectInfos[objectInfo.attackTargetIndex].allAttackers[objectIndex] = nil
            _battleScene.objectInfos[objectIndex] = nil
        end
        ]]
    end

    -- 判断下一个记录的回合
    if _battleScene.nextRecordTurn <= _battleScene.turn then
        local turnInterval = CFG.s_BattleMailRoundDate:Get( _battleScene.turn )
        if turnInterval then
            _battleScene.nextRecordTurn = _battleScene.turn + turnInterval.intervalRound
        else
            _battleScene.nextRecordTurn = 0
        end
    end

    -- 回合+1
    _battleScene.turn = _battleScene.turn + 1
end

---@see 处理状态效果
---@param _battleScene defaultBattleSceneClass
function BattleLogic:dealDotAndHot( _battleScene )
    -- HOT效果
    BattleBuff:turnOverHot( _battleScene )
    -- DOT效果
    BattleBuff:turnOverDot( _battleScene )
    -- 增加怒气
    BattleBuff:turnOverAnger( _battleScene )
    -- 状态减少一回合
    BattleBuff:turnOverSubStatusTurn( _battleScene )
    -- 同步对象状态到游服
    local allBuffs
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        if objectInfo.buffChangeFlag then
            -- buff发生变化才同步
            allBuffs = BattleBuff:getAllStatusId( _battleScene, objectIndex )
            Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "syncObjectBattleBuff", objectIndex, objectInfo.objectType, allBuffs )
        end
        objectInfo.buffChangeFlag = false
    end
end

---@see 对象退出战斗
---@param _battleScene defaultBattleSceneClass
---@param _battleObject battleObjectAttrClass
---@param _win integer
function BattleLogic:objectEndBattle( _battleScene, _objectIndex, _win, _leaderArmyNoEnter )
    local attackInfo = _battleScene.objectInfos[_objectIndex]
    if attackInfo.exitBattleBlockBlag >= 2 then
        -- 已经强退了,不再第二次退出战斗
        return
    elseif attackInfo.exitBattleBlockBlag == 1 then
        attackInfo.exitBattleBlockBlag = 2
    end

    local defenseInfo = attackInfo.attackObjectSnapShot
    if _battleScene.objectInfos[attackInfo.attackTargetIndex] then
        defenseInfo = _battleScene.objectInfos[attackInfo.attackTargetIndex]
    end

    -- 插入一个战报记录
    BattleCommon:insertBattleReport( _battleScene, _objectIndex, _objectIndex, nil, nil, nil, nil, nil, nil, true )

    if _win ~= Enum.BattleResult.FAIL then
        -- 退出战斗,触发被动
        if BattleSkill:triggerSkill( _battleScene, _objectIndex, _objectIndex, Enum.SkillTrigger.LEAVE_BATTLE ) then
            -- 同步buff
            local allBuffs = BattleBuff:getAllStatusId( _battleScene, _objectIndex )
            Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "syncObjectBattleBuff", _objectIndex, attackInfo.objectType, allBuffs )
            -- 同步治疗
            local damageInfo = {
                objectIndex = _objectIndex,
                objectType = attackInfo.objectType,
                skillInfo = attackInfo.turnSkillInfo
            }
            Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "brocastBattleDamage", _battleScene.battleIndex,
                { [_objectIndex] = damageInfo }, attackInfo.objectType, _objectIndex )
        end
    end

    -- 退出战斗,将自身的信息报告给参与战斗的各对象
    BattleCommon:setSoldierHurtOnExitBattle( _battleScene, _objectIndex )
    -- 额外战报信息
    local battleType = BattleTypeCacle:getBattleType( attackInfo.objectType, defenseInfo.objectType, attackInfo.isCheckPointMonster, defenseInfo.isCheckPointMonster )
    local battleReportEx = {
        objectInfos = attackInfo.battleWithInfos,
        battleBeginTime = attackInfo.battleBeginTime,
        battleEndTime = os.time(),
        battleType = battleType,
        winObjectIndex = ( _win == Enum.BattleResult.WIN ) and _objectIndex or attackInfo.attackTargetIndex,
        reinforceJoinArmy = _battleScene.reinforceJoinArmy[_objectIndex],
        reinforceLeaveArmy = _battleScene.reinforceLeaveArmy[_objectIndex],
        battleReport = attackInfo.battleReport
    }

    -- 是否是征服攻城战防守方
    local plunderRid
    if battleType == Enum.BattleType.CITY_PVP then
        if defenseInfo.objectType == Enum.RoleType.CITY then
            if _win == Enum.BattleResult.WIN and defenseInfo.exitBattleWin == Enum.BattleResult.FAIL then
                -- 守城方被击溃
                plunderRid = defenseInfo.objectRid
            end
        end

        if attackInfo.objectType == Enum.RoleType.CITY then
            -- 城市退出战斗
            local cityAttackCount = {}
            for attackerIndex in pairs(attackInfo.allAttackers) do
                if _battleScene.objectInfos[attackerIndex] then
                    cityAttackCount[attackerIndex] = BattleCommon:getArmySoldierCount( _battleScene.objectInfos[attackerIndex] )
                end
            end
            attackInfo.battleEndAttackers = cityAttackCount
        end
    end

    if attackInfo.objectType == Enum.RoleType.CITY and _win == Enum.BattleResult.FAIL then
        -- 城市退出战斗,获取可掠夺资源
        attackInfo.plunderResource = Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "getCitPlunderResource", attackInfo.objectRid )
    end

    -- 发送给游服
    local exitArg = BattleDef:getDefaultBattleExitArg()
    exitArg.objectIndex = _objectIndex
    exitArg.rid = attackInfo.objectRid or 0
    exitArg.targetRid = defenseInfo.objectRid or 0
    exitArg.objectType = attackInfo.objectType
    exitArg.soldiers = attackInfo.soldiers
    exitArg.soldierHurt = attackInfo.soldierHurt
    exitArg.battleReportEx = battleReportEx
    exitArg.win = _win
    exitArg.battleType = battleType
    exitArg.isInitiativeAttack = attackInfo.isInitiativeAttack
    exitArg.attackMonsterIds = attackInfo.attackMonsterIds
    exitArg.killCount = attackInfo.killCount
    exitArg.plunderRid = plunderRid
    exitArg.attackTargetIndex = attackInfo.attackTargetIndex
    exitArg.attackTargetType = defenseInfo.objectType
    exitArg.isRally = attackInfo.isRally
    exitArg.rallySoldiers = attackInfo.rallySoldiers
    exitArg.rallyDamages = attackInfo.rallyDamages
    exitArg.rallyKillCounts = attackInfo.rallyKillCounts
    exitArg.cityAttackCount = defenseInfo.battleEndAttackers
    exitArg.battleEndAttackers = attackInfo.battleEndAttackers
    exitArg.rallyLeader = attackInfo.rallyLeader
    exitArg.rallyMember = attackInfo.rallyMember
    exitArg.attackerRid = defenseInfo.objectRid
    exitArg.holyLandMonsterId = defenseInfo.holyLandMonsterId
    exitArg.historyBattleObjectType = attackInfo.historyBattleObjectType
    exitArg.targetStaticId = defenseInfo.staticId
    exitArg.selfStaticId = attackInfo.staticId
    exitArg.plunderResource = defenseInfo.plunderResource
    exitArg.leaderArmyNoEnter = _leaderArmyNoEnter or false
    exitArg.targetGuildId = defenseInfo.guildId
    exitArg.monsterCityLevel = defenseInfo.level
    exitArg.monsterCityPos = defenseInfo.pos
    exitArg.mainHeroId = attackInfo.mainHeroId
    exitArg.armyIndex = attackInfo.armyIndex
    exitArg.allHospitalDieCount = attackInfo.allHospitalDieCount
    exitArg.allSoldierHardHurt = attackInfo.allSoldierHardHurt
    exitArg.isBeDamageOrHeal = attackInfo.isBeDamageOrHeal
    exitArg.tmpObjectFlag = attackInfo.tmpObjectFlag
    exitArg.selfIsCheckPointMonster = attackInfo.isCheckPointMonster
    exitArg.targetIsCheckPointMonster = defenseInfo.isCheckPointMonster
    exitArg.guildId = attackInfo.guildId

    Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "notifyObjectExitBattle", _objectIndex, exitArg )
end

---@see 角色退出战斗
---@param _battleScene defaultBattleSceneClass
function BattleLogic:objectExitBattle( _battleScene, _objectIndex, _block, _leaderArmyNoEnter )
    if _battleScene.objectInfos[_objectIndex] then
        _battleScene.objectInfos[_objectIndex].exitBattleWin = Enum.BattleResult.NORESULT
        _battleScene.objectInfos[_objectIndex].exitBattleFlag = true
        _battleScene.objectInfos[_objectIndex].exitBattleBlockBlag = 1
        if _block then
            self:objectEndBattle( _battleScene, _objectIndex, Enum.BattleResult.NORESULT, _leaderArmyNoEnter )
        end
    end
end

---@see 给角色发送战报.用于战斗中退出建筑
function BattleLogic:sendBattleReportOnExitBuild( _battleScene, _objectIndex, _sendReportRid )
    -- 退出战斗,将自身的信息报告给参与战斗的各对象
    BattleCommon:setSoldierHurtOnExitBattle( _battleScene, _objectIndex )

    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local defenseInfo = attackInfo.attackObjectSnapShot
    -- 额外战报信息
    local battleType = BattleTypeCacle:getBattleType( attackInfo.objectType, defenseInfo.objectType, attackInfo.isCheckPointMonster, defenseInfo.isCheckPointMonster )
    local battleReportEx = {
        objectInfos = attackInfo.battleWithInfos,
        battleBeginTime = attackInfo.battleBeginTime,
        battleEndTime = os.time(),
        battleType = battleType,
        winObjectIndex = attackInfo.attackTargetIndex,
        reinforceJoinArmy = _battleScene.reinforceJoinArmy[_objectIndex],
        reinforceLeaveArmy = _battleScene.reinforceLeaveArmy[_objectIndex],
        battleReport = attackInfo.battleReport
    }

    -- 发送给游服
    local exitArg = BattleDef:getDefaultBattleExitArg()
    exitArg.objectIndex = _objectIndex
    exitArg.rid = attackInfo.objectRid or 0
    exitArg.targetRid = defenseInfo.objectRid or 0
    exitArg.objectType = attackInfo.objectType
    exitArg.soldiers = attackInfo.soldiers
    exitArg.soldierHurt = attackInfo.soldierHurt
    exitArg.battleReportEx = battleReportEx
    exitArg.win = Enum.BattleResult.NORESULT
    exitArg.battleType = battleType
    exitArg.isInitiativeAttack = attackInfo.isInitiativeAttack
    exitArg.attackMonsterIds = attackInfo.attackMonsterIds
    exitArg.monsterCityLevel = defenseInfo.level
    exitArg.killCount = attackInfo.killCount
    exitArg.attackTargetIndex = attackInfo.attackTargetIndex
    exitArg.attackTargetType = defenseInfo.objectType
    exitArg.isRally = attackInfo.isRally
    exitArg.rallySoldiers = attackInfo.rallySoldiers
    exitArg.rallyDamages = attackInfo.rallyDamages
    exitArg.rallyKillCounts = attackInfo.rallyKillCounts
    exitArg.cityAttackCount = defenseInfo.battleEndAttackers
    exitArg.rallyLeader = attackInfo.rallyLeader
    exitArg.rallyMember = attackInfo.rallyMember
    exitArg.attackerRid = defenseInfo.objectRid
    exitArg.holyLandMonsterId = defenseInfo.holyLandMonsterId
    exitArg.historyBattleObjectType = attackInfo.historyBattleObjectType
    exitArg.targetStaticId = defenseInfo.staticId
    exitArg.selfStaticId = attackInfo.staticId
    exitArg.plunderResource = defenseInfo.plunderResource
    exitArg.targetGuildId = defenseInfo.guildId
    exitArg.monsterCityLevel = defenseInfo.level
    exitArg.monsterCityPos = defenseInfo.pos
    exitArg.sendReportRid = _sendReportRid
    exitArg.armyIndex = attackInfo.armyIndex
    exitArg.allHospitalDieCount = attackInfo.allHospitalDieCount
    exitArg.allSoldierHardHurt = attackInfo.allSoldierHardHurt
    exitArg.isBeDamageOrHeal = attackInfo.isBeDamageOrHeal
    exitArg.tmpObjectFlag = attackInfo.tmpObjectFlag
    exitArg.guildId = attackInfo.guildId

    Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "sendBattleReport", _objectIndex, exitArg )
end

return BattleLogic