--[[
 * @file : BattleSkill.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-13 17:25:33
 * @Last Modified time: 2020-04-13 17:25:33
 * @department : Arabic Studio
 * @brief : 战斗技能相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BattleCommon = require "BattleCommon"
local BattleCacle = require "BattleCacle"
local BattleBuff = require "BattleBuff"
local Random = require "Random"
local BattleDef = require "BattleDef"
local MapObjectLogic = require "MapObjectLogic"
local CommonCacle = require "CommonCacle"

local BattleSkill = {}

---@see 处理战斗技能触发
---@param _battleScene defaultBattleSceneClass 战斗场景
---@param _attackIndex integer 触发攻击方
---@param _defenseIndex integer 触发防御方
---@param _skillTrigger integer 触发时机
function BattleSkill:triggerSkill( _battleScene, _attackIndex, _defenseIndex, _skillTrigger, _useSkillId, _useSkillLevel )
    local isTrigger
    -- 寻找满足触发时机的技能
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    if not attackInfo then
        return
    end
    local sSkillInfo, sSkillBattleInfo, skillBattleID
    for _, skillInfo in pairs(attackInfo.skills) do
        sSkillInfo = CFG.s_HeroSkill:Get( skillInfo.skillId )
        if sSkillInfo then
            -- 是否被觉醒技能强化
            skillBattleID = CommonCacle:checkIsAwakeEnhance( skillInfo.skillId, attackInfo.skills )
            if not skillBattleID then
                skillBattleID = sSkillInfo.skillBattleID
            end
            for _, skillBattleId in pairs(skillBattleID) do
                repeat
                    -- 判断是否有战斗技能数据
                    if (not skillInfo.talent) and ( not sSkillInfo or not skillBattleId or skillBattleId <= 0 ) then
                        break
                    end
                    local useSkillId
                    if skillInfo.talent then
                        useSkillId = skillInfo.skillId
                        sSkillBattleInfo = CFG.s_SkillBattle:Get( skillInfo.skillId * 100 + skillInfo.skillLevel )
                    else
                        useSkillId = skillBattleId
                        sSkillBattleInfo = CFG.s_SkillBattle:Get( skillBattleId * 100 + skillInfo.skillLevel )
                    end

                    -- 觉醒强化技能不能触发
                    if sSkillInfo.type == 4 then
                        break
                    end

                    -- 判断是否为此触发时机
                    if not sSkillBattleInfo or not sSkillBattleInfo.autoActive or sSkillBattleInfo.autoActive ~= _skillTrigger then
                        break
                    end

                    -- 判断部队限制
                    if not self:checkSkillArmyTypeLimit( _battleScene, _attackIndex, sSkillBattleInfo ) then
                        break
                    end

                    -- 判断部队士兵比例限制
                    if not self:checkSkillArmySoldierPercent( _battleScene, _attackIndex, sSkillBattleInfo ) then
                        break
                    end

                    -- 判断部队士兵限制
                    if not self:checkSkillArmySoldierType( _battleScene, _attackIndex, sSkillBattleInfo ) then
                        break
                    end

                    -- 判断技能条件是否满足
                    if not self:checkSkillCondition( _battleScene, _attackIndex, _defenseIndex, _skillTrigger,
                        sSkillBattleInfo, _useSkillId, _useSkillLevel, skillInfo.deputySkill ) then
                        break
                    end

                    -- 判断技能触发限制
                    if not self:checkTriggerCount( _battleScene, _attackIndex, skillInfo.skillId, sSkillBattleInfo.autoActiveRate ) then
                        break
                    end

                    -- 判断技能触发频率
                    if not self:checkTriggerInterval( _battleScene, _attackIndex, skillInfo.skillId, sSkillBattleInfo.autoActiveInterval ) then
                        break
                    end

                    -- 判断触发几率
                    if Random.Get( 1, 1000 ) > sSkillBattleInfo.autoActivePro then
                        break
                    end

                    isTrigger = true
                    -- 如果是怒气技能,扣除怒气(副将技能不扣怒气)
                    if _skillTrigger == Enum.SkillTrigger.ANGER_MORE then
                        if not skillInfo.deputySkill then
                            BattleCacle:useSkillSubAnger( _battleScene, _attackIndex, sSkillBattleInfo.autoActiveParm )
                            -- 记录怒气使用技能回合数
                            attackInfo.useAngleSkillTurn = _battleScene.turn
                        else
                            -- 副将怒气技能
                            attackInfo.useAngleSkillTurn = 0
                        end
                    end
                    -- 生效技能效果
                    self:useSkill( _battleScene, _attackIndex, _defenseIndex, sSkillBattleInfo, useSkillId, skillInfo.skillLevel )
                    -- 释放技能技能后触发被动
                    self:triggerSkill( _battleScene, _attackIndex, _defenseIndex, Enum.SkillTrigger.AFTER_USE_SKILL, useSkillId, skillInfo.skillLevel )
                    -- 如果是怒气技能,判断释放怒气技能后的技能
                    if sSkillBattleInfo.autoActive == Enum.SkillTrigger.ANGER_MORE then
                        self:triggerSkill( _battleScene, _attackIndex, _defenseIndex, Enum.SkillTrigger.ANGER_SKILL, useSkillId, skillInfo.skillLevel )
                        -- 释放怒气技能后增加怒气
                        self:recoverAngerBySkill( _battleScene, _attackIndex, Enum.SkillAngerRecover.AFTER_USE_ANGER_SKILL )
                    end
                until true
            end
        end
    end

    return isTrigger
end

---@see 使用技能
---@param _battleScene defaultBattleSceneClass
function BattleSkill:useSkill( _battleScene, _attackIndex, _defenseIndex, _sSkillBattleInfo, _skillId, _skillLevel )
    local allDamage = {}
    local allHeal = {}
    local targetObjectIndexs = {}
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    if _sSkillBattleInfo.rangeType ==Enum.SkillRange.SECTOR then
        -- 扇形,寻找额外目标
        if _sSkillBattleInfo.targetExMaxNum and _sSkillBattleInfo.targetExMaxNum > 0 then
            -- 这里不包含当前攻击目标
            BattleCommon:getObjectIndexsInRange( _battleScene, _attackIndex, _defenseIndex, _sSkillBattleInfo.skillRadius,
                                                _sSkillBattleInfo.skillAngle, targetObjectIndexs )
        end
    end

    -- 增加主目标
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    targetObjectIndexs[_defenseIndex] = {
                                                        objectIndex = _defenseIndex,
                                                        objectType = defenseInfo.objectType,
                                                        guildId = defenseInfo.guildId,
                                                        objectRid = defenseInfo.objectRid
                                    }

    local targetMaxNum = _sSkillBattleInfo.targetExMaxNum or 0
    targetMaxNum = targetMaxNum + 1 -- 增加一个主目标
    -- 根据技能目标类型,过滤有效的目标
    local skillObjectIndexs
    if not _sSkillBattleInfo.dmgPower or _sSkillBattleInfo.dmgPower <= 0 then
        skillObjectIndexs = self:getTargetIndexs( _battleScene, _attackIndex, _defenseIndex, targetObjectIndexs,
                                                    _sSkillBattleInfo.targetType, targetMaxNum )
    else
        skillObjectIndexs = self:getTargetIndexsEx( _battleScene, _attackIndex, _defenseIndex, targetObjectIndexs, targetMaxNum )
    end

    local allTargetCount = table.size(skillObjectIndexs)
    for _, objectIndex in pairs(skillObjectIndexs) do
        if not _battleScene.objectInfos[objectIndex] and targetObjectIndexs[objectIndex] then
            local targetGuildId = targetObjectIndexs[objectIndex].guildId or 0
            -- 目标不在此战斗中,临时加入战斗中
            local defaultObjectInfo = BattleDef:getDefaultBattleObjectInfo()
            defaultObjectInfo.objectIndex = objectIndex
            defaultObjectInfo.objectRid = targetObjectIndexs[objectIndex].rid
            defaultObjectInfo.objectType = targetObjectIndexs[objectIndex].objectType
            defaultObjectInfo.soldiers = targetObjectIndexs[objectIndex].soldiers
            defaultObjectInfo.attackTargetIndex = _attackIndex
            defaultObjectInfo.pos = targetObjectIndexs[objectIndex].pos
            defaultObjectInfo.armyRadius = targetObjectIndexs[objectIndex].armyRadius
            defaultObjectInfo.isRally = targetObjectIndexs[objectIndex].isRally
            defaultObjectInfo.guildId = targetGuildId
            defaultObjectInfo.armyIndex = targetObjectIndexs[objectIndex].armyIndex or 0
            defaultObjectInfo.tmpObjectFlag = true -- 标记为临时对象
            _battleScene.objectInfos[objectIndex] = defaultObjectInfo

            -- 判断是否在攻击距离内
            local inAttackRange = BattleCommon:checkInAttackRange( _battleScene, objectIndex, _attackIndex )
            if defaultObjectInfo.isRally then
                -- 集结部队不会反击
                inAttackRange = false
            end
            if not _sSkillBattleInfo.dmgPower or _sSkillBattleInfo.dmgPower <= 0 then
                -- 没伤害不会进战斗
                inAttackRange = false
            end
            -- 如果是同联盟,不能进战斗
            if targetGuildId ~= 0 and targetGuildId == attackInfo.guildId then
                inAttackRange = false
            end

            -- 通知游服进战斗
            Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "notifyObjectEnterBattle",
                                    _battleScene.battleIndex ,objectIndex, defaultObjectInfo.objectType, _attackIndex, inAttackRange )
        end

        -- 计算技能伤害、治疗
        local damage, heal
        local addBuffs = {}
        local removeBuffs = {}
        if _sSkillBattleInfo.dmgPower and _sSkillBattleInfo.dmgPower > 0 then
            -- 技能造成伤害
            damage = BattleCacle:cacleSkillDamage( _battleScene, _attackIndex, objectIndex, _sSkillBattleInfo, allTargetCount )
            -- 计算护盾
            damage = BattleBuff:cacleShiled( _battleScene, objectIndex, damage )
            if damage > 0 then
                if not allDamage[objectIndex] then
                    allDamage[objectIndex] = { damage = 0 }
                end
                allDamage[objectIndex].damage = allDamage[objectIndex].damage + damage
                -- 加入伤害统计
                BattleCacle:addObjectHurt( _battleScene, objectIndex, damage, true )
                -- 计算部队损伤
                BattleCacle:cacleObjectHurtDie( _battleScene, _attackIndex, objectIndex )
            end
        end

        if _sSkillBattleInfo.healPower and _sSkillBattleInfo.healPower > 0 then
            -- 技能造成治疗
            heal = BattleCacle:cacleSkillHeal( _battleScene, _attackIndex, objectIndex, _sSkillBattleInfo )
            if heal and heal > 0 then
                if not allHeal[objectIndex] then
                    allHeal[objectIndex] = { heal = 0 }
                end
                allHeal[objectIndex].heal = allHeal[objectIndex].heal + heal
            end
            -- 恢复兵力
            heal = BattleCacle:healArmy( _battleScene, objectIndex, heal )
            -- 加入治疗统计
            BattleCacle:addObjectHeal( _battleScene, objectIndex, heal )
            -- 更新最后战斗回合
            BattleCacle:refreshLastBattleTurn( _battleScene, objectIndex )
        end

        local statusHit
        if _sSkillBattleInfo.statusID then
            -- 技能产生状态
            for _, statusId in pairs(_sSkillBattleInfo.statusID) do
                if statusId and statusId > 0 then
                    if BattleBuff:addBuff( _battleScene, _attackIndex, objectIndex, statusId ) then
                        statusHit = true
                        table.insert( addBuffs, statusId )
                        -- 拥有BUFF时触发的技能
                        BattleSkill:triggerSkill( _battleScene, objectIndex, objectIndex, Enum.SkillTrigger.HAD_BUFF )
                        -- 拥有DEBUFF时触发的技能
                        BattleSkill:triggerSkill( _battleScene, objectIndex, objectIndex, Enum.SkillTrigger.HAD_DEBUFF )
                    end
                end
            end
        end

        if _sSkillBattleInfo.statusDelType and _sSkillBattleInfo.statusDelType > 0 then
            -- 技能产生驱散效果
            removeBuffs = BattleBuff:deleteBuff( _battleScene, objectIndex, _sSkillBattleInfo )
        end

        if damage or heal or statusHit then
            -- 统计回合内受到的技能影响
            local battleObjectInfo = BattleCommon:getObjectInfo( _battleScene, objectIndex )
            table.insert( battleObjectInfo.turnSkillInfo, { skillId = _skillId, skillLevel = _skillLevel, skillDamage = damage, skillHeal = heal, objectIndex = _attackIndex } )
            -- 技能命中目标后增加怒气
            BattleSkill:recoverAngerBySkill( _battleScene, _attackIndex, Enum.SkillAngerRecover.AFTER_SKILL_HIT, _sSkillBattleInfo )
        end

        -- 加入战报
        if damage and damage > 0 then
            -- 造成伤害后触发的技能
            BattleSkill:triggerSkill( _battleScene, _attackIndex, objectIndex, Enum.SkillTrigger.MAKE_DAMAGE )
            -- 受到技能伤害时触发的技能
            BattleSkill:triggerSkill( _battleScene, objectIndex, _attackIndex, Enum.SkillTrigger.BE_SKILL_DAMAGE )
            -- 受到任意伤害时触发的技能
            BattleSkill:triggerSkill( _battleScene, objectIndex, _attackIndex, Enum.SkillTrigger.BE_ANY_DAMAGE )
            -- 伤害加入战报
            BattleCommon:insertBattleReport( _battleScene, _attackIndex, objectIndex, damage , nil, nil, _skillId, addBuffs, removeBuffs )
        end
        if heal and heal > 0 then
            -- 治疗加入战报
            BattleCommon:insertBattleReport( _battleScene, _attackIndex, objectIndex, nil , nil, heal, _skillId, addBuffs, removeBuffs )
        end
    end

    -- 技能释放后增加怒气
    BattleSkill:recoverAngerBySkill( _battleScene, _attackIndex, Enum.SkillAngerRecover.AFTER_USE_SKILL, _sSkillBattleInfo )

    -- 记录技能触发次数
    if not attackInfo.triggerSkillCount[_skillId] then
        attackInfo.triggerSkillCount[_skillId] = 0
    end
    attackInfo.triggerSkillCount[_skillId] = attackInfo.triggerSkillCount[_skillId] + 1

    -- 记录技能触发回合
    attackInfo.triggerSkillInterval[_skillId] = _battleScene.turn

    -- 更新最后战斗回合
    BattleCacle:refreshLastBattleTurn( _battleScene, _attackIndex )

    return allDamage, allHeal
end

---@see 判断技能触发次数限制
function BattleSkill:checkTriggerCount( _battleScene, _objectIndex, _skillId, _maxCount )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if objectInfo.triggerSkillCount[_skillId] then
        return objectInfo.triggerSkillCount[_skillId] < _maxCount
    end

    return true
end

---@see 判断技能触频率限制
---@param _battleScene defaultBattleSceneClass
function BattleSkill:checkTriggerInterval( _battleScene, _objectIndex, _skillId, _interval )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if objectInfo.triggerSkillInterval[_skillId] then
        return ( _battleScene.turn - objectInfo.triggerSkillInterval[_skillId] ) >= _interval
    end

    return true
end

---@see 判断技能条件是否满足
---@param _battleScene defaultBattleSceneClass
function BattleSkill:checkSkillCondition( _battleScene, _attackIndex, _defenseIndex, _skillTrigger,
                                            _skillBattleInfo, _useSkillId, _useSkillLevel, _isDeputySkill )
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    if _skillTrigger == Enum.SkillTrigger.ANGER_MORE then
        if _isDeputySkill then
            local objectInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
            -- 判断上一次使用怒气技能回合
            return objectInfo.useAngleSkillTurn > 0 and objectInfo.useAngleSkillTurn + 2 <= _battleScene.turn
        else
            -- 怒气值大于等于X时
            return attackInfo.sp >= _skillBattleInfo.autoActiveParm
        end
    elseif _skillTrigger == Enum.SkillTrigger.NORMAL_ATTACK then
        -- 普通攻击后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.BEATBACK then
        -- 反击后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.ANGER_SKILL then
        -- 使用怒气技能后
        if _useSkillId then
            local sSkillInfo = CFG.s_HeroSkill:Get( _useSkillId )
            if sSkillInfo and sSkillInfo.skillBattleID then
                for _, skillBattleId in pairs(sSkillInfo.skillBattleID) do
                    local sSkillBattleInfo = CFG.s_SkillBattle:Get( skillBattleId * 100 + _useSkillLevel )
                    if sSkillBattleInfo.autoActive == Enum.SkillTrigger.ANGER_MORE then
                        return true
                    end
                end
            end
        end
        return false
    elseif _skillTrigger == Enum.SkillTrigger.MAKE_DAMAGE then
        -- 造成伤害后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.GET_SHILED then
        -- 获得护盾后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.RESUME_SOLDIER then
        -- 恢复兵力后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.HAD_BUFF then
        -- 拥有BUFF时
        return BattleBuff:checkExistBuff( _battleScene, _attackIndex )
    elseif _skillTrigger == Enum.SkillTrigger.HAD_DEBUFF then
        -- 拥有DEBUFF时
        return BattleBuff:checkExistDeBuff( _battleScene, _attackIndex )
    elseif _skillTrigger == Enum.SkillTrigger.ATTACK_BUILD then
        -- 普通攻击建筑时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.ATTACK_CITY_TURN_MORE then
        -- 普通攻击玩家城市X回合后
        return _battleScene.turn >= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.ATTACK_CITY then
        -- 攻击玩家城市时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.ATTACK_OUT_CITY then
        -- 攻击玩家城市外建筑时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.AFTER_USE_SKILL then
        -- 释放指定技能后
        if _useSkillId then
            local sSkillInfo = CFG.s_HeroSkill:Get( _useSkillId )
            if sSkillInfo then
                for _, skillBattleId in pairs(sSkillInfo.skillBattleID) do
                    if skillBattleId == _skillBattleInfo.autoActiveParm then
                        return true
                    end
                end
            else
                LOG_ERROR("checkSkillCondition not found skillId(%s) in s_HeroSkill", tostring(_useSkillId))
            end
        end
    elseif _skillTrigger == Enum.SkillTrigger.SELF_INFANTRY_MORE then
        -- 自己步兵数量占比大于等于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.INFANTRY ) >= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_INFANTRY_LESS then
        -- 自己步兵数量占比小于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.INFANTRY ) < _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_CAVALRY_MORE then
        -- 自己骑兵数量占比大于等于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.CAVALRY ) >= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_CAVALRY_LESS then
        -- 自己骑兵数量占比小于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.CAVALRY ) < _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_ARCHER_MORE then
        -- 自己弓兵数量占比大于等于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.ARCHER ) >= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_ARCHER_LESS then
        -- 自己弓兵数量占比小于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.ARCHER ) < _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_SIEGE_UNIT_MORE then
        -- 自己攻城单位数量占比大于等于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.SIEGE_UNIT ) >= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_SIEGE_UNIT_LESS then
        -- 自己攻城单位数量占比小于X
        return BattleCacle:getSoldierNumByType( _battleScene, _attackIndex, Enum.ArmyType.SIEGE_UNIT ) < _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_ARMY_COUNT_MORE then
        -- 自己部队兵力百分比大于等于X
        local percent = BattleCommon:getArmySoldierCount( _battleScene.objectInfos[_attackIndex] ) / _battleScene.objectInfos[_attackIndex].armyCountMax
        percent = percent * 100
        return percent > _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_ARMY_COUNT_LESS then
        -- 自己部队兵力百分比小于X
        local percent = BattleCommon:getArmySoldierCount( _battleScene.objectInfos[_attackIndex] ) / _battleScene.objectInfos[_attackIndex].armyCountMax
        percent = percent * 100
        return percent <= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_SOLDIER_COUNT_MORE then
        -- 自己兵种类型数量大于等于X
        return BattleCacle:getSoldierTypeNum( _battleScene, _attackIndex ) >= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.SELF_SOLDIER_COUNT_LESS then
        -- 自己兵种类型数量小于X
        return BattleCacle:getSoldierTypeNum( _battleScene, _attackIndex ) < _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.BE_NORMAL_DAMAGE then
        -- 受到普攻伤害时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.BE_BEAT_BACK_DAMAGE then
        -- 受到反击伤害时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.BE_SKILL_DAMAGE then
        -- 受到技能伤害时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.BE_ANY_DAMAGE then
        -- 受到任意伤害时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.BE_CONVER_ATTACK then
        -- 被夹击时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.ENEMY_HAD_SHILED then
        -- 敌方拥有护盾时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.AFTER_KILL_MONSTER then
        -- 击败野蛮人和守护者后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.ENEMY_HAD_BUFF then
        -- 敌方拥有BUFF类型时
        return BattleBuff:checkExistBuff( _battleScene, _defenseIndex )
    elseif _skillTrigger == Enum.SkillTrigger.ENEMY_HAD_DEBUFF then
        -- 敌方拥有DEBUFF类型时
        return BattleBuff:checkExistDeBuff( _battleScene, _defenseIndex )
    elseif _skillTrigger == Enum.SkillTrigger.ENEMY_SOLDIER_COUNT_MORE then
        -- 敌方部队兵力百分比大于等于X
        local percent = BattleCommon:getArmySoldierCount( _battleScene.objectInfos[_defenseIndex] ) / _battleScene.objectInfos[_defenseIndex].armyCountMax
        percent = percent * 100
        return percent >= _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.ENEMY_SOLDIER_COUNT_LESS then
        -- 敌方部队兵力百分比小于X
        local percent = BattleCommon:getArmySoldierCount( _battleScene.objectInfos[_defenseIndex] ) / _battleScene.objectInfos[_defenseIndex].armyCountMax
        percent = percent * 100
        return percent < _skillBattleInfo.autoActiveParm
    elseif _skillTrigger == Enum.SkillTrigger.ENTER_BATTLE then
        -- 进入战斗时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.LEAVE_BATTLE then
        -- 离开战斗时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.WIN_ANY_ENEMY then
        -- 战胜任意敌方部队后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.WIN_OUT_ARMY then
        -- 战胜野外部队后
        return true
    elseif _skillTrigger == Enum.SkillTrigger.ON_DUTY_HERO_ATTACK then
        -- 担任驻防统帅被普通攻击时
        return true
    elseif _skillTrigger == Enum.SkillTrigger.ON_DUTY_HERO_CONVER then
        -- 担任驻防统帅被夹击时
        return true
    end

    return false
end

---@see 根据技能目标类型.过滤目标
---@param _battleScene defaultBattleSceneClass
function BattleSkill:getTargetIndexs( _battleScene, _attackIndex, _defenseIndex, _allTargetIndexs, _skillTargetType, _targetExMaxNum )
    local objectIndexs = {}

    if _skillTargetType == Enum.BattleTargetType.ONLY_SELF then
        -- 仅自己部队
        table.insert( objectIndexs, _attackIndex )
    elseif _skillTargetType == Enum.BattleTargetType.ONLY_FRIEND then
        -- 仅友方部队,过滤盟友
        local attackGuildId = _battleScene.objectInfos[_attackIndex].guildId
        local attackRid = _battleScene.objectInfos[_attackIndex].objectRid
        local objectGuildId
        for _, objectInfo in pairs(_allTargetIndexs) do
            objectGuildId = objectInfo.guildId
            if objectGuildId and objectGuildId > 0 and objectGuildId == attackGuildId then
                -- 盟友
                table.insert( objectIndexs, objectInfo.objectIndex )
            elseif objectGuildId == 0 and attackRid == objectInfo.objectRid then
                -- 无联盟,自己的部队
                table.insert( objectIndexs, objectInfo.objectIndex )
            end
        end
    elseif _skillTargetType == Enum.BattleTargetType.SELF_FRIEND then
        -- 自己和友方部队,过滤盟友
        local attackGuildId = _battleScene.objectInfos[_attackIndex].guildId
        local attackRid = _battleScene.objectInfos[_attackIndex].objectRid
        local objectGuildId
        for _, objectInfo in pairs(_allTargetIndexs) do
            objectGuildId = objectInfo.guildId
            if objectGuildId and objectGuildId > 0 and objectGuildId == attackGuildId then
                -- 盟友
                table.insert( objectIndexs, objectInfo.objectIndex )
            elseif objectGuildId == 0 and attackRid == objectInfo.objectRid then
                -- 无联盟,自己的部队
                table.insert( objectIndexs, objectInfo.objectIndex )
            end
        end
        table.insert( objectIndexs, _attackIndex )
    elseif _skillTargetType == Enum.BattleTargetType.NO_ROLE then
        -- 非玩家部队
        for _, objectInfo in pairs(_allTargetIndexs) do
            if objectInfo.objectType ~= Enum.RoleType.ROLE then
                -- 盟友
                table.insert( objectIndexs, objectInfo.objectIndex )
            end
        end
    elseif _skillTargetType == Enum.BattleTargetType.ONLY_ROLE_ENEMY then
        -- 仅敌方玩家部队
        local attackGuildId = _battleScene.objectInfos[_attackIndex].guildId
        local objectGuildId, objectType
        for _, objectInfo in pairs(_allTargetIndexs) do
            objectGuildId = objectInfo.guildId
            objectType = objectInfo.objectType
            if objectType == Enum.RoleType.ROLE and ( attackGuildId <= 0 or objectGuildId ~= attackGuildId ) then
                table.insert( objectIndexs, objectInfo.objectIndex )
            end
        end
    elseif _skillTargetType == Enum.BattleTargetType.ALL_ENEMY then
        local attackGuildId = _battleScene.objectInfos[_attackIndex].guildId
        -- 全部敌方部队
        for _, objectInfo in pairs(_allTargetIndexs) do
            local objectGuildId = objectInfo.guildId
            if attackGuildId <= 0 or objectGuildId ~= attackGuildId then
                table.insert( objectIndexs, objectInfo.objectIndex )
            end
        end
    end

    -- 随机取N个
    local ranIndex
    local retObjectIndexs = {}
    for _ = 1, _targetExMaxNum do
        if #objectIndexs > 0 then
            ranIndex = Random.Get( 1, #objectIndexs )
            table.insert( retObjectIndexs, objectIndexs[ranIndex] )
            table.remove( objectIndexs, ranIndex )
        else
            break
        end
    end

    return retObjectIndexs
end

---@see 根据技能目标类型.过滤目标
---@param _battleScene defaultBattleSceneClass
function BattleSkill:getTargetIndexsEx( _battleScene, _attackIndex, _defenseIndex, _allTargetIndexs, _targetExMaxNum )
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    local allObjectIndexs = { _defenseIndex }
    if defenseInfo.objectType == Enum.RoleType.MONSTER then
        -- 怪物的额外目标只能是怪物
        for _, objectInfo in pairs(_allTargetIndexs) do
            if _defenseIndex ~= objectInfo.objectIndex then
                if objectInfo.objectType == Enum.RoleType.MONSTER then
                    table.insert( allObjectIndexs, objectInfo.objectIndex )
                end
            end
        end
    elseif defenseInfo.objectType == Enum.RoleType.ARMY then
        -- 目标是部队,而且有联盟
        if defenseInfo.guildId > 0 then
            for _, objectInfo in pairs(_allTargetIndexs) do
                if _defenseIndex ~= objectInfo.objectIndex then
                    if objectInfo.objectType == Enum.RoleType.ARMY and defenseInfo.guildId == objectInfo.guildId then
                        table.insert( allObjectIndexs, objectInfo.objectIndex )
                    end
                end
            end
        else
            -- 没有联盟,取同角色的
            for _, objectInfo in pairs(_allTargetIndexs) do
                if _defenseIndex ~= objectInfo.objectIndex then
                    if objectInfo.objectType == Enum.RoleType.ARMY and defenseInfo.objectRid == objectInfo.rid then
                        table.insert( allObjectIndexs, objectInfo.objectIndex )
                    end
                end
            end
        end
    end

    -- 随机取N个
    local ranIndex
    local retObjectIndexs = {}
    for _ = 1, _targetExMaxNum do
        if #allObjectIndexs > 0 then
            ranIndex = Random.Get( 1, #allObjectIndexs )
            table.insert( retObjectIndexs, allObjectIndexs[ranIndex] )
            table.remove( allObjectIndexs, ranIndex )
        else
            break
        end
    end

    return retObjectIndexs
end

---@see 技能恢复怒气
---@param _battleScene defaultBattleSceneClass
function BattleSkill:recoverAngerBySkill( _battleScene, _objectIndex, _recoverType, _sSkillBattleInfo )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if not _sSkillBattleInfo then
        for _, skillInfo in pairs(objectInfo.skills) do
            local sSkillInfo = CFG.s_HeroSkill:Get( skillInfo.skillId )
            if sSkillInfo and sSkillInfo.skillBattleID then
                for _, skillBattleId in pairs(sSkillInfo.skillBattleID) do
                    local sSkillBattleInfo = CFG.s_SkillBattle:Get( skillBattleId * 100 + skillInfo.skillLevel )
                    if sSkillBattleInfo and sSkillBattleInfo.angerRecoveryType == _recoverType then
                        -- 恢复怒气
                        if objectInfo.objectAttr and objectInfo.mainHeroId > 0 then
                            objectInfo.sp = objectInfo.sp + sSkillBattleInfo.angerParm
                            if objectInfo.sp > objectInfo.maxSp then
                                objectInfo.sp = objectInfo.maxSp
                            end
                        else
                            objectInfo.sp = 0
                        end
                    end
                end
            end
        end
    else
        -- 指定技能
        if _sSkillBattleInfo.angerRecoveryType == _recoverType then
            -- 恢复怒气
            if objectInfo.objectAttr and objectInfo.mainHeroId > 0 then
                objectInfo.sp = objectInfo.sp + _sSkillBattleInfo.angerParm
                if objectInfo.sp > objectInfo.maxSp then
                    objectInfo.sp = objectInfo.maxSp
                end
            else
                objectInfo.sp = 0
            end
        end
    end
end

---@see 判断部队是否满足部队限制规则
---@param _battleScene defaultBattleSceneClass
function BattleSkill:checkSkillArmyTypeLimit( _battleScene, _objectIndex, _skillBattleInfo )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.ALL then
        -- 全部
        return true
    elseif _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.NORMAL then
        -- 普通部队
        return objectInfo.objectType == Enum.RoleType.ARMY
    elseif _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.COLLECT then
        -- 采集部队
        return MapObjectLogic:checkIsResourceObject( objectInfo.objectType )
    elseif _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.CITY then
        -- 城市部队
        return objectInfo.objectType == Enum.RoleType.CITY
    elseif _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.GUILD_BUILD then
        -- 联盟建筑部队
        return MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType )
    elseif _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.HOLY_LAND then
        -- 圣地部队
        return MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
    elseif _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.NO_CITY_GARRISON then
        -- 联盟建筑、圣地部队
        return MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
        or MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType )
    elseif _skillBattleInfo.autoTroopsCondition == Enum.SkillTriggerArmyLimit.GARRISON then
        -- 建筑部队
        return MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
        or MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType )
        or objectInfo.objectType == Enum.RoleType.CITY
    else
        return true
    end
end

---@see 判断部队是否满足部队兵种限制规则
---@param _battleScene defaultBattleSceneClass
function BattleSkill:checkSkillArmySoldierPercent( _battleScene, _objectIndex, _skillBattleInfo )
    if _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.NO then
        -- 无限制
        return true
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.INFANTRY_MORE then
        -- 步兵大于等于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.INFANTRY ) >= _skillBattleInfo.autoArmsParm
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.INFANTRY_LESS then
        -- 步兵小于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.INFANTRY ) < _skillBattleInfo.autoArmsParm
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.CAVALRY_MORE then
        -- 骑兵大于等于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.CAVALRY ) >= _skillBattleInfo.autoArmsParm
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.CAVALRY_LESS then
        -- 骑兵小于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.CAVALRY ) < _skillBattleInfo.autoArmsParm
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.ARCHER_MORE then
        -- 弓兵大于等于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.ARCHER ) >= _skillBattleInfo.autoArmsParm
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.ARCHER_LESS then
        -- 弓兵小于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.ARCHER ) < _skillBattleInfo.autoArmsParm
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.SIEGE_UNIT_MORE then
        -- 攻城单位大于等于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.SIEGE_UNIT ) >= _skillBattleInfo.autoArmsParm
    elseif _skillBattleInfo.autoArmsType == Enum.SkillTriggerArmySoldierTypePercent.SIEGE_UNIT_LESS then
        -- 攻城单位小于百分X
        return BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, Enum.ArmyType.SIEGE_UNIT ) >= _skillBattleInfo.autoArmsParm
    else
        return true
    end
end

---@see 判断部队是否满足部队兵种限制规则
---@param _battleScene defaultBattleSceneClass
function BattleSkill:checkSkillArmySoldierType( _battleScene, _objectIndex, _skillBattleInfo )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if _skillBattleInfo.autoArmsNumType == Enum.SkillTriggerArmySoldierType.NO then
        -- 无限制
        return true
    elseif _skillBattleInfo.autoArmsNumType == Enum.SkillTriggerArmySoldierType.TYPE_MORE then
        -- 部队兵种类型大于等于X种
        return BattleCacle:getSoldierTypeNum( _battleScene, _objectIndex ) >= _skillBattleInfo.autoArmsNumParm
    elseif _skillBattleInfo.autoArmsNumType == Enum.SkillTriggerArmySoldierType.TYPE_LESS then
        -- 部队兵种类型小于X种
        return BattleCacle:getSoldierTypeNum( _battleScene, _objectIndex ) < _skillBattleInfo.autoArmsNumParm
    elseif _skillBattleInfo.autoArmsNumType == Enum.SkillTriggerArmySoldierType.PERCENT_MORE then
        -- 兵力比例大于等于X
        return ( BattleCommon:getArmySoldierCount( objectInfo ) / objectInfo.armyCountMax * 1000 ) > _skillBattleInfo.autoArmsNumParm
    elseif _skillBattleInfo.autoArmsNumType == Enum.SkillTriggerArmySoldierType.PERCENT_LESS then
        -- 兵力比例小于X
        return ( BattleCommon:getArmySoldierCount( objectInfo ) / objectInfo.armyCountMax * 1000 ) <= _skillBattleInfo.autoArmsNumParm
    else
        return true
    end
end

return BattleSkill
