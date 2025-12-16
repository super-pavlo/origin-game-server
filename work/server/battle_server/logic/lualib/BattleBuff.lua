--[[
 * @file : BattleBuff.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-16 13:40:19
 * @Last Modified time: 2020-04-16 13:40:19
 * @department : Arabic Studio
 * @brief : 战斗技能状态逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BattleCommon = require "BattleCommon"
local Random = require "Random"
local BattleCacle = require "BattleCacle"
local BattleDef = require "BattleDef"
local BattleBuff = {}

---@see 给对象增加BUFF
function BattleBuff:addBuff( _battleScene, _addObjectIndex, _objectIndex, _statusId )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if not objectInfo then
        LOG_ERROR("addBuff error, not found objectIndex(%d)", _objectIndex)
        return
    end

    -- 判断是否免疫此状态
    if self:checkIsImmUnityStatus( _battleScene, _objectIndex, _statusId ) then
        return
    end

    -- 判断状态命中率
    if not self:checkIsStatusHit( _battleScene, _objectIndex, _statusId ) then
        return
    end

    -- 判断状态叠加状态
    local sSkillStatus = CFG.s_SkillStatus:Get( _statusId )
    if not sSkillStatus then
        LOG_ERROR("addBuff error, not found statusId(%d)", _statusId)
        return
    end
    if sSkillStatus.coexistRule and sSkillStatus.coexistRule > 0 then
        -- 存在叠加规则
        if sSkillStatus.coexistRule == Enum.StatusCoExist.ONE_REPLACE then -- 替代
            -- 判断是否存在此buff
            local exist, buffIndex, buffTurn = self:checkBuffExistByOverlay( _battleScene, _objectIndex, _statusId )
            if exist then
                -- 删除buff
                table.remove( objectInfo.buffs, buffIndex )
            end
            -- 添加buff
            self:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId, buffTurn )
        elseif sSkillStatus.coexistRule == Enum.StatusCoExist.ONE_REPLACE_LOW then -- 仅替代低等级
            -- 判断是否存在低等级的状态
            local exist, buffIndex, buffTurn = self:checkBuffExistLowLevelByOverlay( _battleScene, _objectIndex, _statusId, sSkillStatus.level
                                                                                    , nil, sSkillStatus.type )
            if exist then
                -- 删除buff
                table.remove( objectInfo.buffs, buffIndex )
            end
            -- 添加buff
            self:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId, buffTurn )
        elseif sSkillStatus.coexistRule == Enum.StatusCoExist.TWO_REPLACE then -- 同一施法者替代,不同施法者共存
            local exist, buffIndex, buffTurn = self:checkBuffExistByOverlay( _battleScene, _objectIndex, _statusId, _addObjectIndex )
            if exist then
                -- 删除buff
                table.remove( objectInfo.buffs, buffIndex )
            end
            -- 添加buff
            self:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId, buffTurn )
        elseif sSkillStatus.coexistRule == Enum.StatusCoExist.TWO_REPLACE_LOW then -- 同一施法者替代低等级,不同施法者共存
            local exist, buffIndex, buffTurn = self:checkBuffExistLowLevelByOverlay( _battleScene, _objectIndex, _statusId,
                                                                        sSkillStatus.level, _addObjectIndex, sSkillStatus.type )
            if exist then
                -- 删除buff
                table.remove( objectInfo.buffs, buffIndex, buffTurn )
            end
            -- 添加buff
            self:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId, buffTurn )
        elseif sSkillStatus.coexistRule == Enum.StatusCoExist.THREE_OVERLAY then -- 叠加
            local exist, buffIndex, buffTurn = self:checkBuffExistByOverlay( _battleScene, _objectIndex, _statusId )
            if exist then
                if sSkillStatus.overlay > 1 and objectInfo.buffs[buffIndex].overlay < sSkillStatus.overlay then
                    objectInfo.buffs[buffIndex].overlay = objectInfo.buffs[buffIndex].overlay + 1
                end
            else
                -- 添加buff
                self:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId, buffTurn )
            end
        elseif sSkillStatus.coexistRule == Enum.StatusCoExist.THREE_OVERLAY_REPLACE then -- 同一施法者叠加,不同施法者叠加共存
            local exist, buffIndex, buffTurn = self:checkBuffExistByOverlay( _battleScene, _objectIndex, _statusId, _addObjectIndex )
            if exist then
                if sSkillStatus.overlay > 1 then
                    objectInfo.buffs[buffIndex].overlay = objectInfo.buffs[buffIndex].overlay + 1
                end
            else
                -- 添加buff
                self:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId, buffTurn )
            end
        end
    else
        -- 不存在,直接添加
        self:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId )
    end

    return true
end

---@see 添加buff实现
---@param _battleScene defaultBattleSceneClass
function BattleBuff:addBuffImpl( _battleScene, _addObjectIndex, _objectIndex, _statusId, _buffTurn )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if objectInfo then
        local sSkillStatus = CFG.s_SkillStatus:Get( _statusId )
        -- 计算buff的护盾
        -- 护盾值 = max(1,部队总数量* 技能状态护盾系数/100 * power(参数1 / 部队总数量/1000, 参数2))
        local shiled = 0
        if sSkillStatus.shieldPower and sSkillStatus.shieldPower > 0 then
            local shieldParameter1 = CFG.s_Config:Get("shieldParameter1")
            local shieldParameter2 = CFG.s_Config:Get("shieldParameter2")
            local armyCount = BattleCommon:getArmySoldierCount( objectInfo )
            if armyCount > 0 then
                shiled = math.floor( math.max( 1, armyCount * sSkillStatus.shieldPower / 100
                                    * ( ( shieldParameter1 / armyCount / 1000 ) ^ shieldParameter2 ) ) )
            end
        end
        -- 计算状态持续回合
        local turn = _buffTurn
        if not turn or sSkillStatus.refreshRoundRule == 1 then
            turn = sSkillStatus.boutTimes
            if turn ~= -1 then
                turn = sSkillStatus.boutTimes + Random.Get( 0, sSkillStatus.boutTimesWave )
            end
        end

        -- 计算沉默类型
        local silentType = sSkillStatus.silentType
        if silentType ~= Enum.SilentType.NONE and sSkillStatus.silentRate < Random.Get( 1, 1000 ) then
            silentType = Enum.SilentType.NONE
        end

        local battleBuffInfo = BattleDef:getDefaultBattleBuffInfo()
        battleBuffInfo.statusId = _statusId
        battleBuffInfo.addObjectIndex = _addObjectIndex
        battleBuffInfo.shiled = shiled
        battleBuffInfo.overlay = 1
        battleBuffInfo.turn = turn or 0
        battleBuffInfo.silentType = silentType
        battleBuffInfo.addTurn = _battleScene.turn
        battleBuffInfo.overlayType = sSkillStatus.overlayType
        battleBuffInfo.type = sSkillStatus.type
        battleBuffInfo.addSnapShot = BattleCommon:copyObjectInfo( _battleScene, _addObjectIndex )
        table.insert( objectInfo.buffs, battleBuffInfo )

        -- 重新计算属性
        BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )

        if objectInfo.tmpObjectFlag then
            -- 临时对象,通知到战斗服务器
            Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "addObjectBuff", _objectIndex, objectInfo.objectType, _statusId )
        end
        -- buff变化标记
        objectInfo.buffChangeFlag = true
    end
end

---@see 删除对象BUFF
function BattleBuff:deleteBuff( _battleScene, _objectIndex, _skillBattleInfo )
    local statusDelType = _skillBattleInfo.statusDelType
    local deleteBuffs = {}
    if statusDelType == Enum.StatusDelType.DEL_BUFF then
        -- 清除增益效果
        deleteBuffs = self:deleteObjectBuff( _battleScene, _objectIndex, _skillBattleInfo.delRate, _skillBattleInfo.statusDelMaxNumber )
    elseif statusDelType == Enum.StatusDelType.DEL_DEBUFF then
        -- 清除减益效果
        deleteBuffs = self:deleteObjectDebuff( _battleScene, _objectIndex, _skillBattleInfo.delRate, _skillBattleInfo.statusDelMaxNumber )
    elseif statusDelType == Enum.StatusDelType.DEL_BUFF_DEBUFF then
        -- 清除增益和减益效果
        deleteBuffs = self:deleteObjectAllBuff( _battleScene, _objectIndex, _skillBattleInfo.delRate, _skillBattleInfo.statusDelMaxNumber )
    elseif statusDelType == Enum.StatusDelType.DEL_STATUS then
        -- 清除指定ID的状态
        for _, delStatusId in pairs(_skillBattleInfo.statusDelID) do
            table.merge( deleteBuffs, self:deleteObjectStatusBuff( _battleScene, _objectIndex,
                            _skillBattleInfo.delRate, _skillBattleInfo.statusDelMaxNumber, delStatusId ) )
        end
    elseif statusDelType == Enum.StatusDelType.DEL_OVERLAY then
        -- 清除指定叠加状态
        for _, delOverlayType in pairs(_skillBattleInfo.statusDelID) do
            table.merge( deleteBuffs, self:deleteObjectOverlayBuff( _battleScene, _objectIndex, _skillBattleInfo.delRate,
                _skillBattleInfo.statusDelMaxNumber, delOverlayType ) )
        end
    end

    return deleteBuffs
end

---@see 删除对象增益BUFF
function BattleBuff:deleteObjectBuff( _battleScene, _objectIndex, _delRate, _delCount )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local removeIndexs = {}
    for buffIndex, buffInfo in pairs(objectInfo.buffs) do
        if CFG.s_SkillStatus:Get( buffInfo.statusId, "buffType" ) == Enum.BuffType.BUFF
        and CFG.s_SkillStatus:Get( buffInfo.statusId, "delRule" ) == Enum.StatusCleanType.YES then
            if _delRate >= Random.Get( 1, 1000 ) then
                if _delCount ~= 0 then
                    table.insert( removeIndexs, buffIndex )
                end
                if _delCount ~= -1 then
                    _delCount = _delCount - 1
                end
            end
        end
    end

    -- 删除buff
    local sSkillStatus
    local removeStatusIds = {}
    for _, buffIndex in pairs(removeIndexs) do
        -- 判断是否被清除的时候触发
        sSkillStatus = CFG.s_SkillStatus:Get( objectInfo.buffs[buffIndex].statusId )
        -- 添加删除
        table.insert( removeStatusIds, objectInfo.buffs[buffIndex].statusId )
        -- 处理清除时触发
        if sSkillStatus and sSkillStatus.statusMoment == Enum.StatusTrigger.ON_CLEAN then
            BattleCacle:cacleStatusHeal( _battleScene, _objectIndex, buffIndex )
            BattleCacle:cacleStatusDamage( _battleScene, _objectIndex, buffIndex )
        end
        -- 移除被动技能
        BattleBuff:removeSkillOnStatusDelete( _battleScene, _objectIndex, buffIndex )
        -- 删除buff
        objectInfo.buffs[buffIndex] = nil
    end

    local retBuffs = {}
    table.merge( retBuffs, objectInfo.buffs )
    objectInfo.buffs = retBuffs

    -- 重新计算角色属性
    if not table.empty( removeIndexs ) then
        BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )
        -- buff变化标记
        objectInfo.buffChangeFlag = true
    end

    return removeStatusIds
end

---@see 删除对象减益DEBUFF
function BattleBuff:deleteObjectDebuff( _battleScene, _objectIndex, _delRate, _delCount )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local removeIndexs = {}
    for buffIndex, buffInfo in pairs(objectInfo.buffs) do
        if CFG.s_SkillStatus:Get( buffInfo.statusId, "buffType" ) == Enum.BuffType.DEBUFF
        and CFG.s_SkillStatus:Get( buffInfo.statusId, "delRule" ) == Enum.StatusCleanType.YES then
            if _delRate >= Random.Get( 1, 1000 ) then
                if _delCount ~= 0 then
                    table.insert( removeIndexs, buffIndex )
                end
                if _delCount ~= -1 then
                    _delCount = _delCount - 1
                end
            end
        end
    end

    -- 删除buff
    local sSkillStatus
    local removeStatusIds = {}
    for _, buffIndex in pairs(removeIndexs) do
        -- 判断是否被清除的时候触发
        sSkillStatus = CFG.s_SkillStatus:Get( objectInfo.buffs[buffIndex].statusId )
        table.insert( removeStatusIds, objectInfo.buffs[buffIndex].statusId )
        if sSkillStatus and sSkillStatus.statusMoment == Enum.StatusTrigger.ON_CLEAN then
            BattleCacle:cacleStatusHeal( _battleScene, _objectIndex, buffIndex )
            BattleCacle:cacleStatusDamage( _battleScene, _objectIndex, buffIndex )
        end
        -- 移除被动技能
        BattleBuff:removeSkillOnStatusDelete( _battleScene, _objectIndex, buffIndex )
        -- 删除buff
        objectInfo.buffs[buffIndex] = nil
    end

    local retBuffs = {}
    table.merge( retBuffs, objectInfo.buffs )
    objectInfo.buffs = retBuffs

    -- 重新计算角色属性
    if not table.empty( removeIndexs ) then
        BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )
        -- buff变化标记
        objectInfo.buffChangeFlag = true
    end

    return removeStatusIds
end

---@see 删除对象BUFF
function BattleBuff:deleteObjectAllBuff( _battleScene, _objectIndex, _delRate, _delCount )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local removeIndexs = {}
    for buffIndex, buffInfo in pairs(objectInfo.buffs) do
        if CFG.s_SkillStatus:Get( buffInfo.statusId, "delRule" ) == Enum.StatusCleanType.YES then
            if _delRate >= Random.Get( 1, 1000 ) then
                if _delCount ~= 0 then
                    table.insert( removeIndexs, buffIndex )
                end
                if _delCount ~= -1 then
                    _delCount = _delCount - 1
                end
            end
        end
    end

    -- 删除buff
    local sSkillStatus
    local removeStatusIds = {}
    for _, buffIndex in pairs(removeIndexs) do
        -- 判断是否被清除的时候触发
        sSkillStatus = CFG.s_SkillStatus:Get( objectInfo.buffs[buffIndex].statusId )
        table.insert( removeStatusIds, objectInfo.buffs[buffIndex].statusId )
        if sSkillStatus and sSkillStatus.statusMoment == Enum.StatusTrigger.ON_CLEAN then
            BattleCacle:cacleStatusHeal( _battleScene, _objectIndex, buffIndex )
            BattleCacle:cacleStatusDamage( _battleScene, _objectIndex, buffIndex )
        end
        -- 移除被动技能
        BattleBuff:removeSkillOnStatusDelete( _battleScene, _objectIndex, buffIndex )
        -- 删除buff
        objectInfo.buffs[buffIndex] = nil
    end

    local retBuffs = {}
    table.merge( retBuffs, objectInfo.buffs )
    objectInfo.buffs = retBuffs

    -- 重新计算角色属性
    if not table.empty( removeIndexs ) then
        BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )
        -- buff变化标记
        objectInfo.buffChangeFlag = true
    end

    return removeStatusIds
end

---@see 删除对象指定ID的BUFF
function BattleBuff:deleteObjectStatusBuff( _battleScene, _objectIndex, _delRate, _delCount, _statusId, _force )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local removeIndexs = {}
    for buffIndex, buffInfo in pairs(objectInfo.buffs) do
        if buffInfo.statusId == _statusId then
            if CFG.s_SkillStatus:Get(_statusId, "delRule") == Enum.StatusCleanType.YES or _force then
                if _delRate >= Random.Get( 1, 1000 ) then
                    if _delCount ~= 0 then
                        table.insert( removeIndexs, buffIndex )
                    end
                    if _delCount ~= -1 then
                        _delCount = _delCount - 1
                    end
                end
            end
        end
    end

    -- 删除buff
    local sSkillStatus
    local removeStatusIds = {}
    for _, buffIndex in pairs(removeIndexs) do
        -- 判断是否被清除的时候触发
        sSkillStatus = CFG.s_SkillStatus:Get( objectInfo.buffs[buffIndex].statusId )
        table.insert( removeStatusIds, objectInfo.buffs[buffIndex].statusId )
        if sSkillStatus and sSkillStatus.statusMoment == Enum.StatusTrigger.ON_CLEAN then
            BattleCacle:cacleStatusHeal( _battleScene, _objectIndex, buffIndex )
            BattleCacle:cacleStatusDamage( _battleScene, _objectIndex, buffIndex )
        end
        -- 移除被动技能
        BattleBuff:removeSkillOnStatusDelete( _battleScene, _objectIndex, buffIndex )
        -- 删除buff
        objectInfo.buffs[buffIndex] = nil
    end

    local retBuffs = {}
    table.merge( retBuffs, objectInfo.buffs )
    objectInfo.buffs = retBuffs

    -- 重新计算角色属性
    if not table.empty( removeIndexs ) then
        BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )
        -- buff变化标记
        objectInfo.buffChangeFlag = true
    end

    return removeStatusIds
end

---@see 删除对象指定叠加BUFF
function BattleBuff:deleteObjectOverlayBuff( _battleScene, _objectIndex, _delRate, _delCount, _overlayType )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local removeIndexs = {}
    for buffIndex, buffInfo in pairs(objectInfo.buffs) do
        if CFG.s_SkillStatus:Get( buffInfo.statusId, "delRule" ) == Enum.StatusCleanType.YES then
            if buffInfo.overlayType == _overlayType then
                if _delRate >= Random.Get( 1, 1000 ) then
                    if _delCount ~= 0 then
                        table.insert( removeIndexs, buffIndex )
                    end
                    if _delCount ~= -1 then
                        _delCount = _delCount - 1
                    end
                end
            end
        end
    end

    -- 删除buff
    local sSkillStatus
    local removeStatusIds = {}
    for _, buffIndex in pairs(removeIndexs) do
        -- 判断是否被清除的时候触发
        sSkillStatus = CFG.s_SkillStatus:Get( objectInfo.buffs[buffIndex].statusId )
        table.insert( removeStatusIds, objectInfo.buffs[buffIndex].statusId )
        if sSkillStatus and sSkillStatus.statusMoment == Enum.StatusTrigger.ON_CLEAN then
            BattleCacle:cacleStatusHeal( _battleScene, _objectIndex, buffIndex )
            BattleCacle:cacleStatusDamage( _battleScene, _objectIndex, buffIndex )
        end
        -- 移除被动技能
        BattleBuff:removeSkillOnStatusDelete( _battleScene, _objectIndex, buffIndex )
        -- 删除buff
        objectInfo.buffs[buffIndex] = nil
    end

    local retBuffs = {}
    table.merge( retBuffs, objectInfo.buffs )
    objectInfo.buffs = retBuffs

    -- 重新计算角色属性
    if not table.empty( removeIndexs ) then
        BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )
        -- buff变化标记
        objectInfo.buffChangeFlag = true
    end

    return removeStatusIds
end

---@see 判断是否有指定的状态
function BattleBuff:checkExistBuff( _battleScene, _objectIndex, _statusId )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    for _, buffInfo in pairs(objectInfo.buffs) do
        local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
        if sSkillStatus and sSkillStatus.ID == _statusId then
            return true
        end
    end
end

---@see 判断是否存在buff
function BattleBuff:checkExistBuff( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    for _, buffInfo in pairs(objectInfo.buffs) do
        local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
        if sSkillStatus and sSkillStatus.buffType == Enum.BuffType.BUFF then
            return true
        end
    end
end

---@see 判断是否存在debuff
function BattleBuff:checkExistDeBuff( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    for _, buffInfo in pairs(objectInfo.buffs) do
        local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
        if sSkillStatus and sSkillStatus.buffType == Enum.BuffType.DEBUFF then
            return true
        end
    end
end

---@see 判断状态是否是沉默效果
function BattleBuff:checkIsSilentBuff( _statusId )
    local sSkillStatus = CFG.s_SkillStatus:Get( _statusId )
    if sSkillStatus then
        return sSkillStatus.silentType ~= Enum.SilentType.NONE
    end
end

---@see 判断状态是否是减速效果
function BattleBuff:checkBuffReduceSpeed( _statusId )
    local sSkillStatus = CFG.s_SkillStatus:Get( _statusId )
    if not sSkillStatus then
        return false
    end
    for index, attrTypeName in pairs(sSkillStatus.attrType) do
        if attrTypeName == "infantryMoveSpeed"
        or attrTypeName == "cavalryMoveSpeed"
        or attrTypeName == "bowmenMoveSpeed"
        or attrTypeName == "siegeCarMoveSpeed"
        or attrTypeName == "infantryMoveSpeedMulti"
        or attrTypeName == "cavalryMoveSpeedMulti"
        or attrTypeName == "bowmenMoveSpeedMulti"
        or attrTypeName == "siegeCarMoveSpeedMulti" then
            if sSkillStatus.attrNumber and sSkillStatus.attrNumber[index] and sSkillStatus.attrNumber[index] < 0 then
                return true
            end
        end
    end
    return false
end

---@see 判断是否存在指定叠加状态
function BattleBuff:checkBuffExistByOverlay( _battleScene, _objectIndex, _statusId, _addObjectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if objectInfo.buffs then
        local checkOverlayType = CFG.s_SkillStatus:Get( _statusId, "overlayType" )
        for buffIndex, buffInfo in pairs(objectInfo.buffs) do
            if checkOverlayType > 0 and checkOverlayType == buffInfo.overlayType then
                if not _addObjectIndex or _addObjectIndex == buffInfo.addObjectIndex then
                    return true, buffIndex, buffInfo.turn
                end
            end
        end
    end

    return false
end

---@see 判断是否存在指定低等级叠加状态
function BattleBuff:checkBuffExistLowLevelByOverlay( _battleScene, _objectIndex, _statusId, _level, _addObjectIndex, _type )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if objectInfo.buffs then
        for buffIndex, buffInfo in pairs(objectInfo.buffs) do
            if buffInfo.type == _type then
                local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
                if sSkillStatus.level <= _level then
                    if not _addObjectIndex or _addObjectIndex == buffInfo.addObjectIndex then
                        return true, buffIndex, buffInfo.turn
                    end
                end
            end
        end
    end

    return false
end

---@see 判断对象是否被沉默攻击
function BattleBuff:isSilentAttack( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    for _, buffInfo in pairs(objectInfo.buffs) do
        if buffInfo.silentType == Enum.SilentType.ATTACK or buffInfo.silentType == Enum.SilentType.ATTACK_SKILL then
            return true
        end
    end
    return false
end

---@see 判断对象是否被沉默技能
function BattleBuff:isSilentSkill( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    for _, buffInfo in pairs(objectInfo.buffs) do
        if buffInfo.silentType == Enum.SilentType.SKILL or buffInfo.silentType == Enum.SilentType.ATTACK_SKILL then
            return true
        end
    end
    return false
end

---@see 计算护盾抵消伤害
function BattleBuff:cacleShiled( _battleScene, _objectIndex, _damage )
    if not _damage or _damage <= 0 then
        return _damage
    end
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local removeBuffIndexs = {}
    for buffIndex, buffInfo in pairs(objectInfo.buffs) do
        if buffInfo.shiled > 0 and _damage > 0 then
            if _damage < buffInfo.shiled then
                buffInfo.shiled = buffInfo.shiled - _damage
                _damage = 0
            else
                _damage = _damage - buffInfo.shiled
                -- 移除buff
                table.insert( removeBuffIndexs, buffIndex )
            end
        end
    end

    for _, removeBuffIndex in pairs(removeBuffIndexs) do
        -- 判断是否结束时触发效果
        local sSkillStatus = CFG.s_SkillStatus:Get( objectInfo.buffs[removeBuffIndex].statusId )
        if sSkillStatus and sSkillStatus.statusMoment == Enum.StatusTrigger.ON_END then
            BattleCacle:cacleStatusHeal( _battleScene, _objectIndex, removeBuffIndex )
            BattleCacle:cacleStatusDamage( _battleScene, _objectIndex, removeBuffIndex )
        end
        -- 移除被动技能
        BattleBuff:removeSkillOnStatusDelete( _battleScene, _objectIndex, removeBuffIndex )
        -- 删除buff
        objectInfo.buffs[removeBuffIndex] = nil
    end

    if not table.empty( removeBuffIndexs ) then
        -- buff移除,重新计算属性
        BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )
    end

    -- 重新整合
    local retBuffs = {}
    table.merge( retBuffs, objectInfo.buffs )
    objectInfo.buffs = retBuffs

    return _damage
end

---@see 判断对象是否免疫指定效果
function BattleBuff:checkIsImmUnityStatus( _battleScene, _objectIndex, _statusId )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local isSilent = self:checkIsSilentBuff( _statusId )
    local isReduceSpeed = self:checkBuffReduceSpeed( _statusId )
    local isDebuff = self:checkIsDebuff( _statusId )
    local sSkillStatus
    for _, buffInfo in pairs(objectInfo.buffs) do
        sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
        if sSkillStatus then
            if sSkillStatus.immuneType == Enum.ImmuneType.ALL_DEBUFF then
                -- 免疫所有DEBUFF
                if isDebuff and sSkillStatus.immuneRate >= Random.Get( 1, 1000 ) then
                    return true
                end
            elseif sSkillStatus.immuneType == Enum.ImmuneType.REDUCE_SPEED then
                -- 免疫减速效果
                if isReduceSpeed and sSkillStatus.immuneRate >= Random.Get( 1, 1000 ) then
                    return true
                end
            elseif sSkillStatus.immuneType == Enum.ImmuneType.SILENT then
                -- 免疫沉默效果
                if isSilent and sSkillStatus.immuneRate >= Random.Get( 1, 1000 ) then
                    return true
                end
            end
        end
    end

    return false
end

---@see 判断是否是减益效果
function BattleBuff:checkIsDebuff( _statusId )
    local sSkillStatus = CFG.s_SkillStatus:Get( _statusId )
    if sSkillStatus then
        return sSkillStatus.buffType == Enum.BuffType.DEBUFF
    end
end

---@see 判断状态是否命中
function BattleBuff:checkIsStatusHit( _battleScene, _objectIndex, _statusId )
    local sSkillStatus = CFG.s_SkillStatus:Get( _statusId )
    if sSkillStatus then
        return sSkillStatus.hitRate >= Random.Get( 1, 1000 )
    end
end

---@see 回合结束恢复兵力和怒气
---@param _battleScene defaultBattleSceneClass
function BattleBuff:turnOverHot( _battleScene )
    -- 治疗兵力值 = 部队总数量 * 状态治疗系数/100 * max(0.01,（1 + 部队治疗百分比）) * power(参数1 / 部队总数量/1000，参数2)
    local sSkillStatus
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        for buffIndex, buffInfo in pairs(objectInfo.buffs) do
            sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
            if sSkillStatus.statusMoment == Enum.StatusTrigger.IN_TURN then
                -- 回合内触发的BUFF
                if sSkillStatus and sSkillStatus.statusHealPower and sSkillStatus.statusHealPower > 0 then
                    BattleCacle:cacleStatusHeal( _battleScene, objectIndex, buffIndex )
                end
            end
        end
    end
end

---@see 回合结束损失兵力和怒气
---@param _battleScene defaultBattleSceneClass
function BattleBuff:turnOverDot( _battleScene )
    local sSkillStatus
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        for buffIndex, buffInfo in pairs(objectInfo.buffs) do
            sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
            if sSkillStatus.statusMoment == Enum.StatusTrigger.IN_TURN then
                -- 回合内触发的BUFF
                if sSkillStatus and sSkillStatus.statusDamagePower and sSkillStatus.statusDamagePower > 0 then
                    BattleCacle:cacleStatusDamage(  _battleScene, objectIndex, buffIndex )
                end
            end
        end
    end
end

---@see 回合结束恢复怒气
---@param _battleScene defaultBattleSceneClass
function BattleBuff:turnOverAnger( _battleScene )
    for _, objectInfo in pairs(_battleScene.objectInfos) do
        objectInfo.sp = objectInfo.sp + objectInfo.objectAttr.troopsAnger
        if objectInfo.sp < 0 then
            objectInfo.sp = 0
        elseif objectInfo.sp > objectInfo.maxSp then
            objectInfo.sp = objectInfo.maxSp
        end
    end
end

---@see 回合结束.状态持续回合减少
---@param _battleScene defaultBattleSceneClass
function BattleBuff:turnOverSubStatusTurn( _battleScene )
    local sSkillStatus
    for objectIndex, objectInfo in pairs(_battleScene.objectInfos) do
        local removeBuffIndexs = {}
        for buffIndex, buffInfo in pairs(objectInfo.buffs) do
            if buffInfo.turn >= 0 then
                buffInfo.turn = buffInfo.turn - 1
                if buffInfo.turn <= 0 then
                    -- 移除buff
                    table.insert( removeBuffIndexs, buffIndex )
                end
            end
        end

        for _, removeBuffIndex in pairs(removeBuffIndexs) do
            if objectInfo.buffs[removeBuffIndex] then
                -- 判断是否结束时触发效果
                sSkillStatus = CFG.s_SkillStatus:Get( objectInfo.buffs[removeBuffIndex].statusId )
                if sSkillStatus and sSkillStatus.statusMoment == Enum.StatusTrigger.ON_END then
                    BattleCacle:cacleStatusHeal( _battleScene, objectIndex, removeBuffIndex )
                    BattleCacle:cacleStatusDamage( _battleScene, objectIndex, removeBuffIndex )
                end
                -- 移除被动技能
                BattleBuff:removeSkillOnStatusDelete( _battleScene, objectIndex, removeBuffIndex )
                -- 删除buff
                objectInfo.buffs[removeBuffIndex] = nil
            end
        end

        if not table.empty( removeBuffIndexs ) then
            -- buff移除,重新计算属性
            BattleCacle:cacleObjectAttr( _battleScene, objectIndex )
        end

        -- 重新整合
        local retBuffs = {}
        table.merge( retBuffs, objectInfo.buffs )
        objectInfo.buffs = retBuffs
    end
end

---@see 状态结束.清除移动加入的技能
function BattleBuff:removeSkillOnStatusDelete( _battleScene, _objectIndex, _buffIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local buffInfo = objectInfo.buffs[_buffIndex]
    if buffInfo then
        local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
        if sSkillStatus.autoSkillID and sSkillStatus.autoSkillID > 0 then
            for skillIndex, skillInfo in pairs(objectInfo.skills) do
                if skillInfo.skillId == sSkillStatus.autoSkillID and skillInfo.statusSkill then
                    table.remove( objectInfo.skills, skillIndex )
                    return
                end
            end
        end
    end
end

---@see 获取对象所有状态ID
function BattleBuff:getAllStatusId( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local allStatusId = {}
    for _, buffInfo in pairs(objectInfo.buffs) do
        table.insert( allStatusId, { buffId = buffInfo.statusId, isNew = buffInfo.addTurn == _battleScene.turn, turn = buffInfo.turn } )
    end
    return allStatusId
end

---@see 添加初始战斗Buff
---@param _battleScene defaultBattleSceneClass
function BattleBuff:addObjectBuffOnCreate( _battleScene, _objectIndex )
    local objectInfo = _battleScene.objectInfos[_objectIndex]
    if objectInfo then
        if objectInfo.buffs and not table.empty( objectInfo.buffs ) then
            local roleBuffs = {}
            for _, buffInfo in pairs(objectInfo.buffs) do
                local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.buffId )
                local battleBuffInfo = BattleDef:getDefaultBattleBuffInfo()
                battleBuffInfo.statusId = buffInfo.buffId
                battleBuffInfo.addObjectIndex = _objectIndex
                battleBuffInfo.shiled = 0
                battleBuffInfo.overlay = 1
                battleBuffInfo.turn = buffInfo.turn or 0
                battleBuffInfo.addTurn = 1
                battleBuffInfo.overlayType = sSkillStatus.overlayType
                battleBuffInfo.type = sSkillStatus.type
                battleBuffInfo.addSnapShot = BattleCommon:copyObjectInfo( _battleScene, _objectIndex )
                table.insert( roleBuffs, battleBuffInfo )
            end
            objectInfo.buffs = roleBuffs
        end
    end
end

return BattleBuff