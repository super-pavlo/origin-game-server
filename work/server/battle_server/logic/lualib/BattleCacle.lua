--[[
 * @file : BattleCacle.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2020-01-20 16:46:22
 * @Last Modified time: 2020-01-20 16:46:22
 * @department : Arabic Studio
 * @brief : 战斗计算逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BattleCommon = require "BattleCommon"
local BattleTypeCacle = require "BattleTypeCacle"
local MapObjectLogic = require "MapObjectLogic"
local Random = require "Random"

local BattleCacle = {}

---@see 获取兵种攻击加成百分比
function BattleCacle:getSoldierAttackAddPercent( _armyType, _attackInfo )
    if _armyType == Enum.ArmyType.INFANTRY then
        -- 步兵
        return _attackInfo.objectAttr.infantryAttackMulti or 0
    elseif _armyType == Enum.ArmyType.CAVALRY then
        -- 骑兵
        return _attackInfo.objectAttr.cavalryAttackMulti or 0
    elseif _armyType == Enum.ArmyType.ARCHER then
        -- 弓兵
        return _attackInfo.objectAttr.bowmenAttackMulti or 0
    elseif _armyType == Enum.ArmyType.SIEGE_UNIT then
        -- 攻城单位
        return _attackInfo.objectAttr.siegeCarAttackMulti or 0
    elseif _armyType == Enum.ArmyType.GUARD_TOWER then
        -- 警戒塔
        return _attackInfo.objectAttr.guardTowerAttackMulti or 0
    else
        return 0
    end
end

---@see 获取兵种防御加成百分比
function BattleCacle:getSoldierDefensePercent( _armyType, _defenseInfo )
    if _armyType == Enum.ArmyType.INFANTRY then
        -- 步兵
        return _defenseInfo.objectAttr.infantryDefenseMulti or 0
    elseif _armyType == Enum.ArmyType.CAVALRY then
        -- 骑兵
        return _defenseInfo.objectAttr.cavalryDefenseMulti or 0
    elseif _armyType == Enum.ArmyType.ARCHER then
        -- 弓兵
        return _defenseInfo.objectAttr.bowmenDefenseMulti or 0
    elseif _armyType == Enum.ArmyType.SIEGE_UNIT then
        -- 攻城单位
        return _defenseInfo.objectAttr.siegeCarDefenseMulti or 0
    elseif _armyType == Enum.ArmyType.GUARD_TOWER then
        -- 警戒塔
        return _defenseInfo.objectAttr.guardTowerDefenseMulti or 0
    else
        return 0
    end
end

---@see 获取兵种生命加成百分比
function BattleCacle:getSoldierHpPercent( _armyType, _objectInfo )
    if _armyType == Enum.ArmyType.INFANTRY then
        -- 步兵
        return _objectInfo.objectAttr.infantryHpMaxMulti or 0
    elseif _armyType == Enum.ArmyType.CAVALRY then
        -- 骑兵
        return _objectInfo.objectAttr.cavalryHpMaxMulti or 0
    elseif _armyType == Enum.ArmyType.ARCHER then
        -- 弓兵
        return _objectInfo.objectAttr.bowmenHpMaxMulti or 0
    elseif _armyType == Enum.ArmyType.SIEGE_UNIT then
        -- 攻城单位
        return _objectInfo.objectAttr.siegeCarHpMaxMulti or 0
    elseif _armyType == Enum.ArmyType.GUARD_TOWER then
        -- 警戒塔
        return _objectInfo.objectAttr.guardTowerHpMaxMulti or 0
    else
        return 0
    end
end

---@see 获取兵种的静态克制百分比
function BattleCacle:getSoldierAttackRestrainPercentFromConfig( _soldierId )
    local restraintPercent = {
        infantryVsCavalryDamageMulti = 0,
        infantryVsSiegeCarDamageMulti = 0,
        infantryVsWarningTowerDamageMulti = 0,
        cavalryVsBowmenDamageMulti = 0,
        cavalryVsSiegeCarDamageMulti = 0,
        cavalryVsWarningTowerDamageMulti = 0,
        bowmenVsInfantryDamageMulti = 0,
        bowmenVsSiegeCarDamageMulti = 0,
        bowmenVsWarningTowerDamageMulti = 0,
        siegeCarVsWarningTowerDamageMulti = 0
    }
    local armsSkillIds = CFG.s_Arms:Get( _soldierId, "armsSkill" ) or {}
    local sArmsSkill = CFG.s_ArmsSkill:Get()
    local armsSkill
    for _, skillId in pairs( armsSkillIds ) do
        armsSkill = sArmsSkill[skillId]
        if armsSkill and not table.empty( armsSkill ) then
            for index, name in pairs( armsSkill.restraintConfig or {} ) do
                if restraintPercent[name] and armsSkill.restraintData[index] then
                    restraintPercent[name] = restraintPercent[name] + armsSkill.restraintData[index]
                end
            end
        end
    end

    return restraintPercent
end

---@see 获取兵种攻击克制百分比
function BattleCacle:getSoldierAttackRestrainPercent( _attackSoldierId, _armyType, _attackInfo, _defenseInfo )
    local attackRestrainPercent = 0
    local defenseRestrainArmyCount = 0
    local defenseArmyType
    local restrainConfigInfo = self:getSoldierAttackRestrainPercentFromConfig( _attackSoldierId )
    if _armyType == Enum.ArmyType.INFANTRY then
        -- 步兵
        for soldierId, soldierInfo in pairs(_defenseInfo.soldiers) do
            defenseArmyType = CFG.s_Arms:Get( soldierId, "armsType" )
            if defenseArmyType == Enum.ArmyType.CAVALRY then -- 骑兵
                if _attackInfo.objectAttr.infantryVsCavalryDamageMulti + restrainConfigInfo.infantryVsCavalryDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.infantryVsCavalryDamageMulti + restrainConfigInfo.infantryVsCavalryDamageMulti
            elseif defenseArmyType == Enum.ArmyType.SIEGE_UNIT then -- 攻城器械
                if _attackInfo.objectAttr.infantryVsSiegeCarDamageMulti + restrainConfigInfo.infantryVsSiegeCarDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.infantryVsSiegeCarDamageMulti + restrainConfigInfo.infantryVsSiegeCarDamageMulti
            elseif defenseArmyType == Enum.ArmyType.GUARD_TOWER then -- 警戒塔
                if _attackInfo.objectAttr.infantryVsWarningTowerDamageMulti + restrainConfigInfo.infantryVsWarningTowerDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.infantryVsWarningTowerDamageMulti + restrainConfigInfo.infantryVsWarningTowerDamageMulti
            end
        end
    elseif _armyType == Enum.ArmyType.CAVALRY then
        -- 骑兵
        for soldierId, soldierInfo in pairs(_defenseInfo.soldiers) do
            defenseArmyType = CFG.s_Arms:Get( soldierId, "armsType" )
            if defenseArmyType == Enum.ArmyType.ARCHER then -- 弓兵
                if _attackInfo.objectAttr.cavalryVsBowmenDamageMulti + restrainConfigInfo.cavalryVsBowmenDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.cavalryVsBowmenDamageMulti + restrainConfigInfo.cavalryVsBowmenDamageMulti
            elseif defenseArmyType == Enum.ArmyType.SIEGE_UNIT then -- 攻城器械
                if _attackInfo.objectAttr.cavalryVsSiegeCarDamageMulti + restrainConfigInfo.cavalryVsSiegeCarDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.cavalryVsSiegeCarDamageMulti + restrainConfigInfo.cavalryVsSiegeCarDamageMulti
            elseif defenseArmyType == Enum.ArmyType.GUARD_TOWER then -- 警戒塔
                if _attackInfo.objectAttr.cavalryVsWarningTowerDamageMulti + restrainConfigInfo.cavalryVsWarningTowerDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.cavalryVsWarningTowerDamageMulti + restrainConfigInfo.cavalryVsWarningTowerDamageMulti
            end
        end
    elseif _armyType == Enum.ArmyType.ARCHER then
        -- 弓兵
        for soldierId, soldierInfo in pairs(_defenseInfo.soldiers) do
            defenseArmyType = CFG.s_Arms:Get( soldierId, "armsType" )
            if defenseArmyType == Enum.ArmyType.INFANTRY then -- 步兵
                if _attackInfo.objectAttr.bowmenVsInfantryDamageMulti + restrainConfigInfo.bowmenVsInfantryDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.bowmenVsInfantryDamageMulti + restrainConfigInfo.bowmenVsInfantryDamageMulti
            elseif defenseArmyType == Enum.ArmyType.SIEGE_UNIT then -- 攻城器械
                if _attackInfo.objectAttr.bowmenVsSiegeCarDamageMulti + restrainConfigInfo.bowmenVsSiegeCarDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.bowmenVsSiegeCarDamageMulti + restrainConfigInfo.bowmenVsSiegeCarDamageMulti
            elseif defenseArmyType == Enum.ArmyType.GUARD_TOWER then -- 警戒塔
                if _attackInfo.objectAttr.bowmenVsWarningTowerDamageMulti + restrainConfigInfo.bowmenVsWarningTowerDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.bowmenVsWarningTowerDamageMulti + restrainConfigInfo.bowmenVsWarningTowerDamageMulti
            end
        end
    elseif _armyType == Enum.ArmyType.SIEGE_UNIT then
        -- 攻城单位
        for soldierId, soldierInfo in pairs(_defenseInfo.soldiers) do
            defenseArmyType = CFG.s_Arms:Get( soldierId, "armsType" )
            if defenseArmyType == Enum.ArmyType.GUARD_TOWER then -- 警戒塔
                if _attackInfo.objectAttr.siegeCarVsWarningTowerDamageMulti + restrainConfigInfo.siegeCarVsWarningTowerDamageMulti > 0 then
                    defenseRestrainArmyCount = defenseRestrainArmyCount + soldierInfo.num
                end
                attackRestrainPercent = attackRestrainPercent + _attackInfo.objectAttr.siegeCarVsWarningTowerDamageMulti + restrainConfigInfo.siegeCarVsWarningTowerDamageMulti
            end
        end
    end

    return attackRestrainPercent, defenseRestrainArmyCount
end

---@see 计算单个兵种攻击
---@param _soldierId integer 兵种ID
---@param _attackInfo battleObjectAttrClass
---@param _defenseInfo battleObjectAttrClass
function BattleCacle:cacleSingleSoldierAttack( _soldierId, _attackInfo, _defenseInfo )
    --[[单个兵种最终攻击力 = 兵种基础攻击力 *
    （max（0.01，1 + Σ兵种攻击力百分比/1000 + Σ兵种克制比例/1000 * 敌方被克制部队兵种类型总数量/敌方部队总数量 + BUFF增减益））]]
    -- 获取基础攻击力
    local soldierBaseInfo = CFG.s_Arms:Get( _soldierId )
    local attackAddPercent = self:getSoldierAttackAddPercent( soldierBaseInfo.armsType, _attackInfo )
    local attackAddRestrainPercent, defenseRestrainArmyCount
         = self:getSoldierAttackRestrainPercent( _soldierId, soldierBaseInfo.armsType, _attackInfo, _defenseInfo )
    local defenseArmyCount = BattleCommon:getArmySoldierCount( _defenseInfo )
    if defenseArmyCount <= 0 then
        return 0
    end
    -- 集结部队攻击增加百分比
    if _attackInfo.isRally then
        attackAddPercent = attackAddPercent + ( _attackInfo.objectAttr.rallyAttackMulti or 0 )
    end
    -- 驻防部队攻击力百分比
    if BattleTypeCacle:checkIsGarrisonArmy( _attackInfo.objectType ) then
        attackAddPercent = attackAddPercent + _attackInfo.objectAttr.garrisonAttackMulti
    end
    -- 获取兵种攻击
    return math.floor( soldierBaseInfo.attack * ( math.max(0.01, 1 + attackAddPercent / 1000 + attackAddRestrainPercent / 1000
                    * defenseRestrainArmyCount / defenseArmyCount )) )
end

---@see 计算单个兵种防御
function BattleCacle:cacleSingleSoldierDefense( _soldierId, _objectInfo )
    --[[单个兵种最终防御力 = 兵种基础防御力 * （max（0.01，1 + Σ兵种防御力百分比/1000  + BUFF增减益））]]
    -- 获取基础防御力
    local soldierBaseInfo = CFG.s_Arms:Get( _soldierId )
    local defenseAddPercent = self:getSoldierDefensePercent( soldierBaseInfo.armsType, _objectInfo )
    -- 集结部队防御增加百分比
    if _objectInfo.isRally then
        defenseAddPercent = defenseAddPercent + ( _objectInfo.objectAttr.rallyDefenseMulti or 0 )
    end
    -- 驻防部队攻击力百分比
    if BattleTypeCacle:checkIsGarrisonArmy( _objectInfo.objectType ) then
        defenseAddPercent = defenseAddPercent + _objectInfo.objectAttr.garrisonDefenseMulti
    end
    -- 兵种防御力
    return math.floor( soldierBaseInfo.defense * math.max( 0.01, 1 + defenseAddPercent / 1000 ))
end

---@see 计算单个兵种生命
function BattleCacle:cacleSingleSoldierHp( _soldierId, _objectInfo )
    --[[单个兵种最终生命值 = 兵种基础生命值 * （max（0.01，1 + Σ兵种生命值百分比/1000  + BUFF增减益））]]
    -- 获取基础生命值
    local soldierBaseInfo = CFG.s_Arms:Get( _soldierId )
    -- 获取加成百分比
    local addHpPercent = self:getSoldierHpPercent( soldierBaseInfo.armsType, _objectInfo )
    -- 集结部队生命增加百分比
    if _objectInfo.isRally then
        addHpPercent = addHpPercent + ( _objectInfo.objectAttr.rallyHpMaxMulti or 0 )
    end
    -- 驻防部队攻击力百分比
    if BattleTypeCacle:checkIsGarrisonArmy( _objectInfo.objectType ) then
        addHpPercent = addHpPercent + _objectInfo.objectAttr.garrisonHpMaxMulti
    end
    -- 兵种生命力
    return math.floor( soldierBaseInfo.hpMax * ( math.max( 0.01, 1 + addHpPercent / 1000 )))
end

---@see 获取指定兵种的数量
function BattleCacle:getSoldierNumByType( _battleScene, _objectIndex, _soldierType )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local soldierNum = 0
    for _, soldierInfo in pairs(objectInfo.soldiers) do
        if soldierInfo.type == _soldierType then
            soldierNum = soldierNum + soldierInfo.num
        end
    end

    return soldierNum
end

---@see 获取指定兵种的比例
function BattleCacle:getSoldierPercentByType( _battleScene, _objectIndex, _soldierType )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local soldierNum = 0
    for _, soldierInfo in pairs(objectInfo.soldiers) do
        if soldierInfo.type == _soldierType then
            soldierNum = soldierNum + soldierInfo.num
        end
    end

    local allSoldierNum = BattleCommon:getArmySoldierCount( objectInfo )

    return ( soldierNum / allSoldierNum ) * 1000
end

---@see 获取目标的兵种类型数量
function BattleCacle:getSoldierTypeNum( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local soldierTypeNum = {}
    for _, soldierInfo in pairs(objectInfo.soldiers) do
        soldierTypeNum[soldierInfo.type] = 1
    end

    return table.size( soldierTypeNum )
end

---@see 计算部队总攻击
---@param _attackInfo battleObjectAttrClass
---@param _defenseInfo battleObjectAttrClass
function BattleCacle:cacleArmyAttack( _attackInfo, _defenseInfo )
    --[[部队总攻击力 = Σ（单个兵种最终攻击力 * 单个兵种总数量/部队总数量）]]
    -- 计算部队总数量
    local allArmyCount = BattleCommon:getArmySoldierCount( _attackInfo )
    if allArmyCount <= 0 then
        return 0
    end
    local armyAttack = 0
    for soldierId, soldierInfo in pairs(_attackInfo.soldiers) do
        armyAttack = armyAttack + ( self:cacleSingleSoldierAttack( soldierId, _attackInfo, _defenseInfo ) * soldierInfo.num / allArmyCount )
    end

    return math.floor(armyAttack)
end

---@see 计算部队总防御
---@param _objectInfo battleObjectAttrClass
function BattleCacle:cacleArmyDefense( _objectInfo )
    --[[部队总防御力 = Σ（单个兵种最终防御力 * 单个兵种总数量/部队总数量）]]
    -- 计算部队总数量
    local allArmyCount = BattleCommon:getArmySoldierCount( _objectInfo )
    if allArmyCount <= 0 then
        return 0
    end
    local armyDefense = 0
    for soldierId, soldierInfo in pairs(_objectInfo.soldiers) do
        armyDefense = armyDefense + ( self:cacleSingleSoldierDefense( soldierId, _objectInfo ) * soldierInfo.num / allArmyCount )
    end

    return math.floor(armyDefense)
end

---@see 计算部队总生命
---@param _objectInfo battleObjectAttrClass
function BattleCacle:cacleArmyHp( _objectInfo )
    --[[部队总生命值 = Σ（单个兵种最终生命值 * 单个兵种总数量/部队总数量）]]
    -- 计算部队总数量
    local allArmyCount = BattleCommon:getArmySoldierCount( _objectInfo )
    if allArmyCount <= 0 then
        return 0
    end
    local armyHp = 0
    for soldierId, soldierInfo in pairs(_objectInfo.soldiers) do
        armyHp = armyHp + ( self:cacleSingleSoldierHp( soldierId, _objectInfo ) * soldierInfo.num / allArmyCount )
    end

    return math.floor(armyHp)
end

---@see 计算攻击伤害
---@param _battleScene defaultBattleSceneClass
function BattleCacle:cacleAttackDamage( _battleScene, _attackIndex, _defenseIndex )
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    -- 攻击方部队总数量
    local attackArmyCount = BattleCommon:getArmySoldierCount( attackInfo )
    -- 进攻方攻击
    local attackArmyAttack = self:cacleArmyAttack( attackInfo, defenseInfo )
    -- 防御方防御
    local defenseArmyDefense = self:cacleArmyDefense( defenseInfo )
    -- 防御方生命
    local defenseArmyHp = self:cacleArmyHp( defenseInfo )
    -- 防御方部队总数
    local defenseArmyCount = BattleCommon:getArmySoldierCount( defenseInfo )

    if attackArmyCount <= 0 or defenseArmyCount <= 0 then
        return 0
    end

    -- 获取攻击方增加百分比
    local attackDamageMulti = attackInfo.objectAttr.attackDamageMulti or 0
    if attackInfo.isRally then
        attackDamageMulti = attackDamageMulti + ( attackInfo.objectAttr.massAttackDamageMulti or 0 )
    end

    -- 防御方伤害减免
    local attackDamageReduceMulti = defenseInfo.objectAttr.attackDamageReduceMulti or 0
    -- 动态参数
    local dynamicArg = self:cacleDynamicSoldierArg( _battleScene, _attackIndex )
    local battleType = BattleTypeCacle:getBattleType( attackInfo.objectType, defenseInfo.objectType, attackInfo.isCheckPointMonster, defenseInfo.isCheckPointMonster )
    if battleType ~= Enum.BattleType.CITY_PVP then
        -- 野蛮人战斗,野外部队战斗
        --[[普通攻击伤害(损兵) = max(1,攻击方部队总数量 * 进攻方部队总攻击 / 防御方部队总防御 / 防御方部队总生命
            * (max(100，1000 + 攻击方普攻伤害百分比 – 防御方普攻伤害减免百分比))/1000 * 普攻系数 / 100 * power(攻击常数 / 攻击方部队总数量, 0.5))]]
        if defenseInfo.objectType == Enum.RoleType.MONSTER then
            -- 野蛮人属性加成
            attackDamageMulti = attackDamageMulti + attackInfo.objectAttr.barbarianAttackDamageMulti
        elseif defenseInfo.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨属性加成
            attackDamageMulti = attackDamageMulti + attackInfo.objectAttr.barbarianVillageAttackDamageMulti
        end
        if attackInfo.objectType == Enum.RoleType.MONSTER then
            -- 野蛮人属性加成
            attackDamageReduceMulti = attackDamageReduceMulti + defenseInfo.objectAttr.barbarianAttackDamageReduceMulti
        elseif attackInfo.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨属性加成
            attackDamageReduceMulti = attackDamageReduceMulti + defenseInfo.objectAttr.barbarianVillageAttackDamageReduceMulti
        end
        -- 计算伤害
        local damage = math.floor( math.max(1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp
            * ( math.max( 100, 1000 + attackDamageMulti - attackDamageReduceMulti)) / 1000
            * CFG.s_Config:Get("ordinaryAttackConstant") / 100 * ( (CFG.s_Config:Get("attackConstant") / attackArmyCount) ^ dynamicArg) ) )
        -- 不能超过防御方部队总数
        if damage > defenseArmyCount then
            damage = defenseArmyCount
        end
        return damage
    else
        -- 城市PVP战斗
        if attackInfo.objectType ~= Enum.RoleType.CITY then -- 攻城部队
            --[[
                普通攻击伤害(损兵) = max(1,攻击方部队总数量 * 进攻方部队总攻击 / 防御方部队总防御 / 防御方部队总生命 *
                (max(100,(1000 + 攻击方普攻伤害百分比 + 攻城部队普攻伤害百分比 – 防御方普攻伤害减免百分比
                – 驻防部队普攻伤害减免百分比))/1000 * 普攻系数 / 100 * power(攻击常数 / 攻击方部队总数量，0.5))
            ]]
            local damage = math.floor( math.max( 1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp
                            * math.max( 100, ( 1000 + attackDamageMulti + attackInfo.objectAttr.cityAttackDamageMulti
                            - attackDamageReduceMulti -  defenseInfo.objectAttr.cityDefenseAttackDamageReduceMulti) ) / 1000
                            * CFG.s_Config:Get("ordinaryAttackConstant") / 100 * ( (CFG.s_Config:Get("attackConstant") / attackArmyCount) ^ dynamicArg ) ) )
            -- 不能超过防御方部队总数
            if damage > defenseArmyCount then
                damage = defenseArmyCount
            end
            return damage
        else -- 防守部队
            --[[
                普通攻击伤害(损兵) = max(1,攻击方部队总数量 * 进攻方部队总攻击 / 防御方部队总防御 / 防御方部队总生命
                * (max(100,(1000 + 攻击方普攻伤害百分比 + 驻防部队普攻伤害百分比– 防御方普攻伤害减免百分比
                – 攻城部队普攻伤害减免百分比))/1000 * 普攻系数 / 100 * power(攻击常数 / 攻击方部队总数量，0.5))
            ]]
            local damage = math.floor( math.max( 1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp
                                * math.max( 100, ( 1000 + attackDamageMulti + attackInfo.objectAttr.cityDefenseAttackDamageMulti
                                - attackDamageReduceMulti - defenseInfo.objectAttr.cityAttackDamageReduceMulti) ) / 1000
                                * CFG.s_Config:Get("ordinaryAttackConstant") / 100 * ( (CFG.s_Config:Get("attackConstant") / attackArmyCount) ^ dynamicArg ) ) )
            -- 不能超过防御方部队总数
            if damage > defenseArmyCount then
                damage = defenseArmyCount
            end
            return damage
        end
    end
end

---@see 计算反击伤害
function BattleCacle:cacleBeatBackDamage( _battleScene, _attackIndex, _defenseIndex )
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    -- 防御方部队总数量
    local defenseArmyCount = BattleCommon:getArmySoldierCount( defenseInfo )
    -- 防御方部队总攻击
    local defenseArmyAttack = self:cacleArmyAttack( defenseInfo, attackInfo )
    -- 进攻方部队总攻击
    local attackArmyDefense = self:cacleArmyDefense( attackInfo )
    -- 进攻方部队总生命
    local attackArmyHp = self:cacleArmyHp( attackInfo )
    -- 进攻方部队总数
    local attackArmyCount = BattleCommon:getArmySoldierCount( attackInfo )
    -- 防御方反击伤害百分比
    local fightBackDamageMulti = defenseInfo.objectAttr.fightBackDamageMulti or 0
    if defenseInfo.isRally then
        fightBackDamageMulti = fightBackDamageMulti + ( defenseInfo.objectAttr.massFightBackDamageMulti or 0 )
    end
    -- 进攻方反击减免
    local fightBackDamageReduceMulti = attackInfo.objectAttr.fightBackDamageReduceMulti or 0

    if attackArmyCount <= 0 or defenseArmyCount <= 0 then
        return 1
    end

    -- 动态参数
    local dynamicArg = self:cacleDynamicSoldierArg( _battleScene, _defenseIndex )
    local battleType = BattleTypeCacle:getBattleType( attackInfo.objectType, defenseInfo.objectType, attackInfo.isCheckPointMonster, defenseInfo.isCheckPointMonster )
    if battleType ~= Enum.BattleType.CITY_PVP then
        -- 野蛮人战斗,野外部队战斗
        --[[反击伤害(损兵) = max(1, 防守方部队总数量 * 防守方部队总攻击 / 进攻方部队总防御 / 进攻方部队总生命
                * (max(100，1000 + 防御方反击伤害百分比 – 进攻方反击伤害百分比))/1000 * 反击系数 / 100 * power(攻击常数 / 防守方部队总数量, 0.5))]]
        if attackInfo.objectType == Enum.RoleType.MONSTER then
            -- 野蛮人属性加成
            fightBackDamageMulti = fightBackDamageMulti + defenseInfo.objectAttr.barbarianFightBackDamageMulti
        elseif attackInfo.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨属性加成
            fightBackDamageMulti = fightBackDamageMulti + attackInfo.objectAttr.barbarianVillageFightBackDamageMulti
        end
        if defenseInfo.objectType == Enum.RoleType.MONSTER then
            -- 野蛮人属性加成
            fightBackDamageReduceMulti = fightBackDamageReduceMulti + attackInfo.objectAttr.barbarianFightBackDamageReduceMulti
        elseif defenseInfo.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨属性加成
            fightBackDamageReduceMulti = fightBackDamageReduceMulti + defenseInfo.objectAttr.barbarianVillageFightBackDamageReduceMulti
        end
        -- 计算伤害
        local damage = math.floor(math.max(1, defenseArmyCount * defenseArmyAttack / attackArmyDefense / attackArmyHp
                * ( math.max( 100, 1000 + fightBackDamageMulti - fightBackDamageReduceMulti )) / 1000
                * CFG.s_Config:Get("counterAttackConstant") / 100 * ((CFG.s_Config:Get("attackConstant") / defenseArmyCount) ^ dynamicArg)))
        -- 不能超过防御方部队总数
        if damage > attackArmyCount then
            damage = attackArmyCount
        end
        return damage
    else
        -- 城市PVP
        if defenseInfo.objectType ~= Enum.RoleType.CITY then -- 攻城部队
            --[[
                反击伤害(损兵) = max(1, 防守方部队总数量 * 防守方部队总攻击 / 攻击方部队总防御 / 攻击方部队总生命
                * (max(100,(1000 + 防守方反击伤害百分比 + 攻城部队反击伤害百分比 – 攻击方反击伤害减免百分比 – 驻防部队反击伤害减免百分比))/1000
                * 反击系数 / 100 * power(攻击常数 / 防御方部队总数量，0.5))
            ]]
            local damage = math.floor(math.max(1, defenseArmyCount * defenseArmyAttack / attackArmyDefense / attackArmyHp
                                * ( math.max(100, (1000 + fightBackDamageMulti + defenseInfo.objectAttr.cityFightBackDamageMulti
                                - fightBackDamageReduceMulti - attackInfo.objectAttr.cityDefenseFightBackDamageReduceMulti)) / 1000
                                * CFG.s_Config:Get("counterAttackConstant") / 100 * ((CFG.s_Config:Get("attackConstant") / defenseArmyCount) ^ dynamicArg))))
            -- 不能超过防御方部队总数
            if damage > attackArmyCount then
                damage = attackArmyCount
            end
            return damage
        else -- 防守部队
            --[[
                反击伤害(损兵) = max(1,防守方部队总数量 * 防守方部队总攻击 / 攻击方部队总防御 / 攻击方部队总生命
                * (max（100, (1000 + 防守方反击伤害百分比 + 驻防部队反击伤害百分比 – 攻击方反击伤害减免百分比 – 攻城部队反击伤害减免百分比))/1000
                * 反击系数 / 100 * power(攻击常数 / 防御方部队总数量,0.5))
            ]]
            local damage = math.floor(math.max(1, defenseArmyCount * defenseArmyAttack / attackArmyDefense / attackArmyHp
                                * ( math.max(100, (1000 + fightBackDamageMulti + defenseInfo.objectAttr.cityDefenseFightBackDamageMulti
                                - fightBackDamageReduceMulti - attackInfo.objectAttr.cityFightBackDamageReduceMulti)) / 1000
                                * CFG.s_Config:Get("counterAttackConstant") / 100 * ((CFG.s_Config:Get("attackConstant") / defenseArmyCount) ^ dynamicArg))))
            -- 不能超过防御方部队总数
            if damage > attackArmyCount then
                damage = attackArmyCount
            end
            return damage
        end
    end
end

---@see 计算技能伤害
function BattleCacle:cacleSkillDamage( _battleScene, _attackIndex, _defenseIndex, _skillBattleInfo, _allTargetCount )
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    local attackArmyCount = BattleCommon:getArmySoldierCount( attackInfo )
    local attackArmyAttack = BattleCacle:cacleArmyAttack( attackInfo, defenseInfo )
    local defenseArmyDefense = BattleCacle:cacleArmyDefense( defenseInfo )
    local defenseArmyHp = BattleCacle:cacleArmyHp( defenseInfo )

    if attackArmyCount <= 0 or defenseArmyDefense <= 0 or defenseArmyHp <= 0 then
        return 0
    end

    -- 动态参数
    local dynamicArg = self:cacleDynamicSoldierArg( _battleScene, _attackIndex )

    -- 攻击方技能伤害百分比
    local skillDamageMulti = attackInfo.objectAttr.skillDamageMulti or 0
    if attackInfo.isRally then
        skillDamageMulti = skillDamageMulti + ( attackInfo.objectAttr.massSkillDamageMulti or 0 )
    end

    local battleType = BattleTypeCacle:getBattleType( attackInfo.objectType, defenseInfo.objectType, attackInfo.isCheckPointMonster, defenseInfo.isCheckPointMonster )
    if battleType ~= Enum.BattleType.CITY_PVP then
        if defenseInfo.objectType == Enum.RoleType.MONSTER then
            -- 野蛮人属性加成
            skillDamageMulti = skillDamageMulti + attackInfo.objectAttr.barbarianSkillDamageMulti
        elseif defenseInfo.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨属性加成
            skillDamageMulti = skillDamageMulti + attackInfo.objectAttr.barbarianVillageSkillDamageMulti
        end

        local skillDamageReduceMulti = defenseInfo.objectAttr.skillDamageReduceMulti or 0
        if attackInfo.objectType == Enum.RoleType.MONSTER then
            -- 野蛮人属性加成
            skillDamageReduceMulti = skillDamageReduceMulti + defenseInfo.objectAttr.barbarianSkillDamageReduceMulti
        elseif attackInfo.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨属性加成
            skillDamageReduceMulti = skillDamageReduceMulti + defenseInfo.objectAttr.barbarianVillageSkillDamageReduceMulti
        end
        if _skillBattleInfo.rangeType == Enum.SkillRange.SINGLE then
            --[[
                技能伤害(损兵) = max(1, 攻击方部队总数量 * 攻击方部队总攻击 / 防御方部队总防御 / 防御方部队总生命 *
                (max(100,1000 + 攻击方部队技能伤害百分比属性 – 受击方技能伤害减免百分比))/1000
                * 技能系数 /  100 * power(攻击常数 / 攻击方部队总数量，0.5）)
            ]]
            return math.floor( math.max( 1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp *
                        math.max( 100, 1000 + (skillDamageMulti or 0) - skillDamageReduceMulti )) / 1000
                        * _skillBattleInfo.dmgPower / 100 * ( CFG.s_Config:Get("attackConstant") / attackArmyCount ) ^ dynamicArg )
        elseif _skillBattleInfo.rangeType == Enum.SkillRange.SECTOR then
            --[[
                技能伤害(损兵) = max(1,攻击方部队总数量 * 攻击方部队总攻击 / 防御方部队总防御 / 防御方部队总生命 *
                (max(100，1000 + 攻击方部队技能伤害百分比属性 – 受击方技能伤害减免百分比))/1000
                * 多目标技能伤害系数 / 100 * power(攻击常数 / 攻击方部队总数量，0.5）)
            ]]
            -- 计算多目标技能伤害系数
            local multiTargetPower = _skillBattleInfo.moreDmgPower[_allTargetCount] or 1000
            return math.floor( math.max( 1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp *
                        math.max( 100, 1000 + (skillDamageMulti or 0) - skillDamageReduceMulti )) / 1000
                        * multiTargetPower / 100 * ( CFG.s_Config:Get("attackConstant") / attackArmyCount ) ^ dynamicArg )
        end
    else
        -- 城市PVP
        if attackInfo.objectType ~= Enum.RoleType.CITY then -- 攻城部队
            if _skillBattleInfo.rangeType == Enum.SkillRange.SINGLE then
                --[[
                    技能伤害(损兵) = max(1, 攻击方部队总数量 * 攻击方部队总攻击 / 防御方部队总防御 / 防御方部队总生命 *
                    (max(100,1000 + 攻击方部队技能伤害百分比属性 + 攻城部队技能伤害百分比 – 受击方技能伤害减免百分比 - 驻防部队技能伤害减免百分比))/1000
                    * 技能系数 /  100 * power(攻击常数 / 攻击方部队总数量，0.5))
                ]]
                return math.floor(math.max(1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp *
                        math.max(100, 1000 + (skillDamageMulti or 0) - (attackInfo.objectAttr.citySkillDamageMulti or 0)
                        - ( defenseInfo.objectAttr.skillDamageReduceMulti or 0) - ( defenseInfo.objectAttr.cityDefenseSkillDamageReduceMulti or 0))) / 1000
                        * _skillBattleInfo.dmgPower / 100 * ( CFG.s_Config:Get("attackConstant") / attackArmyCount ) ^ dynamicArg )
            elseif _skillBattleInfo.rangeType == Enum.SkillRange.SECTOR then
                --[[
                    技能伤害(损兵) = max(1,攻击方部队总数量 * 攻击方部队总攻击 / 防御方部队总防御 / 防御方部队总生命 *
                    (max(100,1000 + 攻击方部队技能伤害百分比属性 + 攻城部队技能伤害百分比 – 受击方技能伤害减免百分比
                    - 驻防部队技能伤害减免百分比))/1000 * 多目标技能伤害系数 / 100 * power(攻击常数 / 攻击方部队总数量，0.5))
                ]]
                -- 计算多目标技能伤害系数
                local multiTargetPower = _skillBattleInfo.moreDmgPower[_allTargetCount] or 1000
                return math.floor( math.max( 1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp *
                        math.max( 100, 1000 + (skillDamageMulti or 0) + (attackInfo.objectAttr.citySkillDamageMulti or 0)
                        - ( defenseInfo.objectAttr.skillDamageReduceMulti or 0) - ( defenseInfo.objectAttr.cityDefenseSkillDamageReduceMulti or 0) )) / 1000
                        * multiTargetPower / 100 * ( CFG.s_Config:Get("attackConstant") / attackArmyCount ) ^ dynamicArg )
            end
        else -- 防守部队
            if _skillBattleInfo.rangeType == Enum.SkillRange.SINGLE then
                --[[
                    技能伤害(损兵) = max(1, 攻击方部队总数量 * 攻击方部队总攻击 / 防御方部队总防御 / 防御方部队总生命 *
                    (max（100,1000 + 攻击方部队技能伤害百分比属性 + 驻防部队技能伤害百分比 – 受击方技能伤害减免百分比
                    - 攻城部队技能伤害减免百分比))/1000 * 技能系数 /  100 * power(攻击常数 / 攻击方部队总数量，0.5))
                ]]
                return math.floor( math.max( 1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp *
                            math.max( 100, 1000 + (skillDamageMulti or 0) + (attackInfo.objectAttr.cityDefenseSkillDamageMulti or 0)
                            - ( defenseInfo.objectAttr.skillDamageReduceMulti or 0) - ( defenseInfo.objectAttr.citySkillDamageReduceMulti or 0) )) / 1000
                            * _skillBattleInfo.dmgPower / 100 * ( CFG.s_Config:Get("attackConstant") / attackArmyCount ) ^ dynamicArg )
            elseif _skillBattleInfo.rangeType == Enum.SkillRange.SECTOR then
                --[[
                    技能伤害(损兵) = max(1,攻击方部队总数量 * 攻击方部队总攻击 / 防御方部队总防御 / 防御方部队总生命 *
                    max(100, 1000 + 攻击方部队技能伤害百分比属性 + 驻防部队技能伤害百分比 – 受击方技能伤害减免百分比 - 攻城部队技能伤害减免百分比))/1000
                    * 多目标技能伤害系数 / 100 * power(攻击常数 / 攻击方部队总数量，0.5))
                ]]
                -- 计算多目标技能伤害系数
                local multiTargetPower = _skillBattleInfo.moreDmgPower[_allTargetCount] or 1000
                return math.floor( math.max( 1, attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp *
                            math.max( 100, 1000 + (skillDamageMulti or 0) + (attackInfo.objectAttr.cityDefenseSkillDamageMulti or 0)
                            - ( defenseInfo.objectAttr.skillDamageReduceMulti or 0) - ( defenseInfo.objectAttr.citySkillDamageReduceMulti or 0) )) / 1000
                            * multiTargetPower / 100 * ( CFG.s_Config:Get("attackConstant") / attackArmyCount ) ^ dynamicArg )
            end
        end
    end
end

---@see 计算技能治疗
function BattleCacle:cacleSkillHeal( _battleScene, _attackIndex, _defenseIndex, _skillBattleInfo )
    --[[
        治疗兵力值 = 部队总数量 * 技能治疗系数/100 * max(0.01,(1 + 部队治疗百分比 / 1000)) * power(参数1 / 部队总数量/1000，参数2）
    ]]
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    local defenseArmyCount = BattleCommon:getArmySoldierCount( defenseInfo )
    if defenseArmyCount <= 0 then
        return 0
    end
    return math.floor( defenseArmyCount * _skillBattleInfo.healPower / 100 *
                        math.max( 0.01, ( 1 + (defenseInfo.objectAttr.troopsToHealthMulti or 0) / 1000))
                        * ( CFG.s_Config:Get("healParameter1") / defenseArmyCount / 1000 ) ^ CFG.s_Config:Get("healParameter2") )
end

---@see 计算部队总属性
function BattleCacle:cacleArmyAttr( _soldiers )
    local soldierBaseInfo
    local allAttr = 0
    for soldierId, soldierInfo in pairs(_soldiers) do
        soldierBaseInfo = CFG.s_Arms:Get( soldierId )
        allAttr = allAttr + ( soldierBaseInfo.attack + soldierBaseInfo.defense + soldierBaseInfo.hpMax ) * soldierInfo.num
    end

    return allAttr
end

---@see 计算各兵种受到的伤害
function BattleCacle:cacleSoldierHurt( _defenseInfo )
    local soldierHurts = {}
    local soldierTypeCount = table.size(_defenseInfo.soldiers)
    if soldierTypeCount <= 1 then
        -- 单兵种
        soldierHurts[table.first(_defenseInfo.soldiers).key] = _defenseInfo.turnHurt
    else
        -- 多兵种
        if _defenseInfo.turnHurt > 1 then
            local armyCount = BattleCommon:getArmySoldierCount( _defenseInfo )
            if armyCount <= 0 then
                return soldierHurts
            end
            local allHurt = 0
            for soldierId, soldierInfo in pairs(_defenseInfo.soldiers) do
                --[[兵种X受到的伤害 = 兵种X剩余数量 / Σ所有兵种数量 * 部队受到总伤害]]
                soldierHurts[soldierId] = math.floor(math.min(soldierInfo.num, soldierInfo.num / armyCount * _defenseInfo.turnHurt))
                allHurt = allHurt + soldierHurts[soldierId]
            end
            if allHurt < _defenseInfo.turnHurt then
                -- 分配剩余伤害
                local leftHurt = _defenseInfo.turnHurt - allHurt
                local loopCount = 0
                while leftHurt > 0 and loopCount < 100 do
                    for soldierId, soldierInfo in pairs(_defenseInfo.soldiers) do
                        if soldierHurts[soldierId] < soldierInfo.num then
                            soldierHurts[soldierId] = soldierHurts[soldierId] + 1
                            leftHurt = leftHurt - 1
                            if leftHurt <= 0 then
                                break
                            end
                        end
                    end
                    loopCount = loopCount + 1
                end
            end
        else
            -- 给最低的兵种
            local lowSoldierId, lowSoldierLevel
            for soldierId, soldierInfo in pairs(_defenseInfo.soldiers) do
                if not lowSoldierLevel or soldierInfo.level < lowSoldierLevel then
                    lowSoldierLevel = soldierInfo.level
                    lowSoldierId = soldierId
                end
            end
            soldierHurts[lowSoldierId] = 1
        end
    end

    return soldierHurts
end

---@see 获取重伤系数
function BattleCacle:getBattleLossArg( _battleScene, _attackIndex, _defenseIndex )
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    local battleType = BattleTypeCacle:getBattleType( attackInfo.objectType, defenseInfo.objectType, attackInfo.isCheckPointMonster, defenseInfo.isCheckPointMonster )
    if not battleType then
        return {
            seriousInjuryProportion = 1000, deathProportion = 1000
        }
    end

    local sBattleLoss = CFG.s_BattleLoss:Get( battleType )
    if defenseInfo.objectType ~= Enum.RoleType.ARMY then
        -- 属于防守方
        return {
                    seriousInjuryProportion = sBattleLoss.seriousInjuryProportionDefence,
                    deathProportion = sBattleLoss.deathProportionDefence
                }
    else
        -- 属于进攻方
        return {
            seriousInjuryProportion = sBattleLoss.seriousInjuryProportion,
            deathProportion = sBattleLoss.deathProportion
        }
    end
end

---@see 根据战斗类型获取战斗系数
---@param _battleScene defaultBattleSceneClass
---@param _attackInfo battleObjectAttrClass
---@param _defenseInfo battleObjectAttrClass
function BattleCacle:getBattleLossInfo( _battleScene, _attackInfo, _defenseInfo, _soldierHurts )
    local sBattleLossInfo = BattleCacle:getBattleLossArg( _battleScene, _attackInfo.objectIndex, _defenseInfo.objectIndex )
    local battleType = BattleTypeCacle:getBattleType( _attackInfo.objectType, _defenseInfo.objectType, _attackInfo.isCheckPointMonster, _defenseInfo.isCheckPointMonster )
    -- 攻城阵亡比例减免百分比
    local attackCityDeathMulti = 0
    if battleType == Enum.BattleType.CITY_PVP then
        attackCityDeathMulti = _defenseInfo.objectAttr.attackCityDeathMulti
    end
    -- 重伤系数
    local severeInjuredMulti = 0
    if _defenseInfo.objectAttr and _defenseInfo.objectAttr.severeInjuredMulti then
        severeInjuredMulti = _defenseInfo.objectAttr.severeInjuredMulti
    end

    local thisAllHurt = 0
    for soldierId in pairs(_defenseInfo.soldiers) do
        if _soldierHurts[soldierId] then
            thisAllHurt = thisAllHurt + math.round( _soldierHurts[soldierId] * ( sBattleLossInfo.seriousInjuryProportion + severeInjuredMulti ) / 1000 )
        end
    end
    local ranHurtIndex
    if thisAllHurt <= 0 then
        ranHurtIndex = Random.Get( 1, table.size(_soldierHurts) )
    end
    severeInjuredMulti = severeInjuredMulti + attackCityDeathMulti

    return sBattleLossInfo, severeInjuredMulti, ranHurtIndex
end

---@see 计算目标伤亡
---@param _battleScene defaultBattleSceneClass
---@param _defenseInfo battleObjectAttrClass
---@param _attackInfo battleObjectAttrClass
function BattleCacle:cacleObjectHurtDie( _battleScene, _attackIndex, _defenseIndex )
    local attackInfo = BattleCommon:getObjectInfo( _battleScene, _attackIndex )
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    if not attackInfo or not defenseInfo or defenseInfo.turnHurt <= 0 then
        return
    end

    -- 标记攻击方造成伤害
    attackInfo.isBeDamageOrHeal = true
    -- 标记目标受到伤害
    defenseInfo.isBeDamageOrHeal = true

    -- 如果是集结部队,分配造成的伤害
    local attackArmyAttrs = {}
    local attackAllArmyAttr = 0
    if attackInfo.isRally or BattleTypeCacle:checkIsGarrisonArmy( attackInfo.objectType ) then
        attackArmyAttrs, attackAllArmyAttr = self:distributeRallyDamage( attackInfo, defenseInfo.turnHurt )
    end

    -- 计算各兵种受到伤害
    local soldierHurts = self:cacleSoldierHurt( defenseInfo )
    -- 获取战斗相关参数
    local sBattleLossInfo, severeInjuredMulti, ranHurtIndex = self:getBattleLossInfo( _battleScene, attackInfo, defenseInfo, soldierHurts )
    -- 计算阵亡、重伤、轻伤
    local thisHurtIndex = 0
    for soldierId, soldierInfo in pairs(defenseInfo.soldiers) do
        if soldierHurts[soldierId] then
            if not defenseInfo.soldierHurt[soldierId] then
                defenseInfo.soldierHurt[soldierId] = {
                                                        type = soldierInfo.type,
                                                        level = soldierInfo.level,
                                                        hardHurt = 0,
                                                        die = 0,
                                                        minor = 0,
                                                        allHardHurt = 0,
                                                        allDie = 0,
                                                        allMinor = 0,
                                                    }
            end
            thisHurtIndex = thisHurtIndex + 1
            -- 重伤
            local hardHurt = math.round( soldierHurts[soldierId] * ( sBattleLossInfo.seriousInjuryProportion + severeInjuredMulti ) / 1000 )
            if thisHurtIndex == ranHurtIndex then
                hardHurt = hardHurt + 1
            end
            -- 避免出现负数的兵量
            if hardHurt > soldierHurts[soldierId] then
                hardHurt = soldierHurts[soldierId]
            end
            -- 轻伤
            local minor = soldierHurts[soldierId] - hardHurt
            if minor < 0 then minor = 0 end
            -- 阵亡
            local die = math.round( hardHurt * ( sBattleLossInfo.deathProportion - severeInjuredMulti ) / 1000 )
            defenseInfo.soldierHurt[soldierId].die = defenseInfo.soldierHurt[soldierId].die + die
            -- 重伤扣除阵亡数量
            hardHurt = hardHurt - die
            defenseInfo.soldierHurt[soldierId].hardHurt = defenseInfo.soldierHurt[soldierId].hardHurt + hardHurt
            -- 剩余数量不能扣除负数
            if soldierInfo.num - hardHurt - die - minor < 0 then
                minor = soldierInfo.num - hardHurt - die
            end
            -- 统计轻伤
            defenseInfo.soldierHurt[soldierId].minor = defenseInfo.soldierHurt[soldierId].minor + minor
            -- 扣除兵种数量
            defenseInfo.soldiers[soldierId].num = math.floor( soldierInfo.num - hardHurt - die - minor )
            if defenseInfo.soldiers[soldierId].num <= 0 then
                defenseInfo.soldiers[soldierId] = nil
            end

            -- 仅计算armysType 1-4
            local armsType = CFG.s_Arms:Get( soldierId, "armsType" )
            if armsType >= 1 and armsType <= 4 then
                -- PVP战斗计算击杀数量
                if defenseInfo.objectType == Enum.RoleType.ARMY or defenseInfo.objectType == Enum.RoleType.CITY
                or MapObjectLogic:checkIsGuildBuildObject( defenseInfo.objectType )
                or MapObjectLogic:checkIsHolyLandObject( defenseInfo.objectType )
                or MapObjectLogic:checkIsResourceObject( defenseInfo.objectType ) then
                    self:addAttackKillCount( attackInfo, soldierInfo, attackArmyAttrs, attackAllArmyAttr, hardHurt + die )
                end
            end

            -- 记录同目标的战斗士兵损伤(用于战报)
            self:recordSoldierHurtWithObjectIndex( _battleScene, _attackIndex, _defenseIndex, soldierId, minor, hardHurt, die )
        end
    end

    -- 如果是集结部队、驻防部队、增援城市部队,分配受到的伤害
    if defenseInfo.isRally or BattleTypeCacle:checkIsGarrisonArmy( defenseInfo.objectType )
    or defenseInfo.objectType == Enum.RoleType.CITY then
        self:distributeRallyHurt( defenseInfo )
    end

    -- 计算当前部队数量
    local armyCount = BattleCommon:getArmySoldierCount( defenseInfo )
    -- 同步给游戏服务器对象当前剩余HP
    local hospitalDieInfo = Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "syncObjectArmyCountAndSp",
                            defenseInfo.objectIndex, defenseInfo.objectType, defenseInfo.objectRid,
                            armyCount, defenseInfo.soldierHurt, defenseInfo.sp, defenseInfo.rallySoldierHurt, defenseInfo.isRally )

    -- 医院死亡统计
    if hospitalDieInfo then
        self:hospitalDieRecord( _battleScene, hospitalDieInfo, _attackIndex )
    end

    -- 重置重伤死亡数据
    self:resetHurtDie( defenseInfo )

    -- 清空本回合伤害
    defenseInfo.turnHurt = 0
end

---@see 记录同目标的伤亡
function BattleCacle:recordSoldierHurtWithObjectIndex( _battleScene, _attackIndex, _defenseIndex, _soldierId, _minor, _hardHurt, _die )
    local defenseInfo = BattleCommon:getObjectInfo( _battleScene, _defenseIndex )
    if _attackIndex == _defenseIndex then
        _attackIndex = defenseInfo.attackTargetIndex
    end
    if not defenseInfo.soldierHurtWithObjectIndex[_attackIndex] then
        defenseInfo.soldierHurtWithObjectIndex[_attackIndex] = {
            targetObjectIndex = _attackIndex,
            battleSoldierHurt = {}
        }
    end

    if _soldierId then
        if not defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId] then
            defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId] = {
                soldierId = _soldierId,
                hardHurt = _hardHurt,
                die = _die,
                minor = _minor,
                heal = 0
            }
        else
            defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId].die =
                defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId].die + _die
            defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId].hardHurt =
                defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId].hardHurt + _hardHurt
            defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId].minor =
                defenseInfo.soldierHurtWithObjectIndex[_attackIndex].battleSoldierHurt[_soldierId].minor + _minor
        end
    end
end

---@see 记录同目标的治疗
function BattleCacle:recordSoldierHealWithObjectIndex( _battleScene, _objectIndex, _soldierId, _heal )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    for _, battleSoldierHurtInfo in pairs(objectInfo.soldierHurtWithObjectIndex) do
        if battleSoldierHurtInfo.battleSoldierHurt[_soldierId] then
            battleSoldierHurtInfo.battleSoldierHurt[_soldierId].heal = battleSoldierHurtInfo.battleSoldierHurt[_soldierId].heal + _heal
        end
    end
end

---@see 重置重伤死亡数据
---@param _defenseInfo battleObjectAttrClass
function BattleCacle:resetHurtDie( _defenseInfo )
    -- 重伤死亡清空
    for _, hurtInfo in pairs(_defenseInfo.soldierHurt) do
        hurtInfo.allHardHurt = hurtInfo.allHardHurt + hurtInfo.hardHurt
        hurtInfo.allDie = hurtInfo.allDie + hurtInfo.die
        hurtInfo.allMinor = hurtInfo.allMinor + hurtInfo.minor
        hurtInfo.die = 0
        hurtInfo.hardHurt = 0
        hurtInfo.minor = 0
    end

    if _defenseInfo.rallySoldierHurt then
        -- 集结部队
        for _, roleSoldierHurtInfo in pairs(_defenseInfo.rallySoldierHurt) do
            for _, soldierHurtInfo in pairs(roleSoldierHurtInfo) do
                for _, hurtInfo in pairs(soldierHurtInfo) do
                    hurtInfo.allHardHurt = hurtInfo.allHardHurt + hurtInfo.hardHurt
                    hurtInfo.allDie = hurtInfo.allDie + hurtInfo.die
                    hurtInfo.allMinor = hurtInfo.allMinor + hurtInfo.minor
                    hurtInfo.die = 0
                    hurtInfo.hardHurt = 0
                    hurtInfo.minor = 0
                end
            end
        end
    end
end

---@see 医院死亡数据增加到记录中
---@param _battleScene defaultBattleSceneClass
function BattleCacle:hospitalDieRecord( _battleScene, _hospitalDieInfo, _attackIndex )
    for rid, dieInfo in pairs(_hospitalDieInfo) do
        for armyIndex, soldierDieInfo in pairs(dieInfo) do
            local objectInfo = BattleCommon:getObjectInfoByRidAndArmyIndex( _battleScene, rid, armyIndex )
            if objectInfo then
                for soldierId, soldierInfo in pairs(soldierDieInfo) do
                    if objectInfo.soldierHurt[soldierId] then
                        -- 统计重伤
                        objectInfo.allSoldierHardHurt = objectInfo.allSoldierHardHurt + objectInfo.soldierHurt[soldierId].hardHurt
                        -- 减少重伤数量
                        objectInfo.soldierHurt[soldierId].hardHurt = objectInfo.soldierHurt[soldierId].hardHurt - soldierInfo.num
                        if objectInfo.soldierHurt[soldierId].hardHurt < 0 then
                            objectInfo.soldierHurt[soldierId].hardHurt = 0
                        end
                        -- 增加死亡数量
                        objectInfo.soldierHurt[soldierId].die = objectInfo.soldierHurt[soldierId].die + soldierInfo.num
                        -- 增加医院死亡
                        objectInfo.allHospitalDieCount = objectInfo.allHospitalDieCount + soldierInfo.num
                        -- 记录同目标的战斗士兵损伤(用于战报)
                        self:recordSoldierHurtWithObjectIndex( _battleScene, _attackIndex, objectInfo.objectIndex, soldierId, 0, -soldierInfo.num, soldierInfo.num )
                    end
                end
            end
        end
    end
end

---@see 增加攻击方击杀数量
function BattleCacle:addAttackKillCount( _attackInfo, _soldierInfo, _attackArmyAttrs, _attackAllArmyAttr, _killCount )
    if not _attackInfo.killCount[_soldierInfo.level] then
        _attackInfo.killCount[_soldierInfo.level] = { level = _soldierInfo.level, count = 0 }
    end
    -- 增加攻击方的击杀
    _attackInfo.killCount[_soldierInfo.level].count = _attackInfo.killCount[_soldierInfo.level].count + _killCount
    -- 如果是集结部队,分配造成的击杀
    if table.size(_attackInfo.rallySoldiers) > 0 then
        for rid in pairs(_attackInfo.rallySoldiers) do
            if _attackArmyAttrs[rid] then
                if not _attackInfo.rallyKillCounts[rid] then
                    _attackInfo.rallyKillCounts[rid] = {}
                end
                if not _attackInfo.rallyKillCounts[rid][_soldierInfo.level] then
                    _attackInfo.rallyKillCounts[rid][_soldierInfo.level] = { count = 0 }
                end
                local count = _attackInfo.rallyKillCounts[rid][_soldierInfo.level].count
                _attackInfo.rallyKillCounts[rid][_soldierInfo.level].count = math.floor( count +  _attackArmyAttrs[rid] / _attackAllArmyAttr * _killCount )
            end
        end
    end
end

---@see 分配集结部队造成的伤害
function BattleCacle:distributeRallyDamage( _attackInfo, _turnHurt )
    local attackArmyAttrs = {}
    local attackAllArmyAttr = 0
    -- 计算部队属性占比
    for rid, soldierInfo in pairs(_attackInfo.rallySoldiers) do
        if not attackArmyAttrs[rid] then
            attackArmyAttrs[rid] = 0
        end
        for _, soldiers in pairs(soldierInfo) do
            attackArmyAttrs[rid] = attackArmyAttrs[rid] + self:cacleArmyAttr( soldiers )
        end
        attackAllArmyAttr = attackAllArmyAttr + attackArmyAttrs[rid]
    end

    -- 分配造成的伤害
    if attackAllArmyAttr > 0 then
        for rid in pairs(_attackInfo.rallySoldiers) do
            if not _attackInfo.rallyDamages[rid] then
                _attackInfo.rallyDamages[rid] = 0
            end
            _attackInfo.rallyDamages[rid] = _attackInfo.rallyDamages[rid] + attackArmyAttrs[rid] / attackAllArmyAttr * _turnHurt
        end
    end

    return attackArmyAttrs, attackAllArmyAttr
end

---@see 分配集结部队受到的伤害
---@param _defenseInfo battleObjectAttrClass
function BattleCacle:distributeRallyHurt( _defenseInfo )
    -- 计算兵种数量占比
    local allSoldierTypes = {}
    local armySoldiers = {}
    if table.size(_defenseInfo.rallySoldiers) <= 0 then
        return
    end

    -- 计算混合部队兵量占比
    local allArmyCount = 0
    for rid, roleArmySoldiers in pairs(_defenseInfo.rallySoldiers) do
        for armyIndex, soldiers in pairs(roleArmySoldiers) do
            for soldierId, soldierInfo in pairs(soldiers) do
                if not allSoldierTypes[soldierId] then
                    allSoldierTypes[soldierId] = 0
                end
                allSoldierTypes[soldierId] = allSoldierTypes[soldierId] + soldierInfo.num

                if not armySoldiers[rid] then
                    armySoldiers[rid] = {}
                end
                if not armySoldiers[rid][armyIndex] then
                    armySoldiers[rid][armyIndex] = {}
                end
                if not armySoldiers[rid][armyIndex][soldierId] then
                    armySoldiers[rid][armyIndex][soldierId] = 0
                end
                armySoldiers[rid][armyIndex][soldierId] = armySoldiers[rid][armyIndex][soldierId] + soldierInfo.num
            end
            allArmyCount = allArmyCount + 1
        end
    end

    local soldierHurt = table.copy(_defenseInfo.soldierHurt, true)
    -- 增援城市部队额外死亡比例
    local reinforceDiePercentCfg = CFG.s_Config:Get("cityReinforceDeathProportion")
    for soldierId, hurtInfo in pairs(soldierHurt) do
        if allSoldierTypes[soldierId] and allSoldierTypes[soldierId] > 0 then
            -- 分配到各子部队中
            local hardHurt, die, minor
            local left = { hardHurt = hurtInfo.hardHurt, die = hurtInfo.die, minor = hurtInfo.minor }
            for rallyRid, rallyRoleSoldierInfo in pairs(armySoldiers) do
                for rallyArmyIndex, rallySoldierInfo in pairs(rallyRoleSoldierInfo) do
                    repeat
                        if not rallySoldierInfo[soldierId] then
                            -- 此角色无此兵种,不再计算
                            break
                        end
                        local hurtPercent = rallySoldierInfo[soldierId] / allSoldierTypes[soldierId]
                        -- 如果是增援盟友,增加额外的死亡系数
                        local reinforceDiePercent = 0
                        if _defenseInfo.objectType == Enum.RoleType.CITY and rallyRid ~= _defenseInfo.rallyLeader then
                            reinforceDiePercent = reinforceDiePercentCfg
                        end

                        if _defenseInfo.rallySoldiers[rallyRid] and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]
                        and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] then
                            -- 初始化混和部队受伤结构
                            if not _defenseInfo.rallySoldierHurt[rallyRid] then
                                _defenseInfo.rallySoldierHurt[rallyRid] = { }
                            end
                            if not _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex] then
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex] = { }
                            end
                            if not _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId] then
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId] = {
                                    allHardHurt = 0, allDie = 0, allMinor = 0,
                                    hardHurt = 0, die = 0, minor = 0,
                                    id = soldierId, level = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].level,
                                    type = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].type,
                                    remain = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num
                                }
                            end

                            -- 重伤
                            hardHurt = math.floor( hurtInfo.hardHurt * hurtPercent )
                            left.hardHurt = left.hardHurt - hardHurt
                            -- 死亡
                            die = math.floor( hurtInfo.die * hurtPercent )

                            -- 剩余死亡
                            left.die = left.die - die

                            -- 轻伤
                            minor = math.floor( hurtInfo.minor * hurtPercent )
                            left.minor = left.minor - minor

                            -- 增援重伤转死亡
                            if reinforceDiePercent > 0 then
                                local hardHurtToDie = math.floor( hardHurt * ( reinforceDiePercent / 1000 ) )
                                die = die + hardHurtToDie
                                hardHurt = hardHurt - hardHurtToDie
                            end

                            -- 赋值
                            _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].hardHurt = hardHurt
                            _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].die = die
                            _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].minor = minor

                            -- 剩余数量
                            local curNum = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num
                            curNum = curNum - ( hardHurt + die + minor )
                            if curNum < 0  then
                                curNum = 0
                            end

                            _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num = curNum
                            _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].remain = curNum
                            _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].remain = curNum

                            -- 判断剩余是否已经不足
                            if _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num <= 0 then
                                _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] = nil
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]) then
                                    _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex] = nil
                                end
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid]) then
                                    _defenseInfo.rallySoldiers[rallyRid] = nil
                                end
                            end
                        end
                    until true
                end
            end

            -- 如果还有剩余伤害,按顺序分配(轻伤)
            if left.minor > 0 then
                for rallyRid, rallyRoleSoldierInfo in pairs(armySoldiers) do
                    for rallyArmyIndex in pairs(rallyRoleSoldierInfo) do
                        if _defenseInfo.rallySoldiers[rallyRid] and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]
                        and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] then
                            local num = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num
                            if num >= left.minor then
                                num = num - left.minor
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].minor =
                                    _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].minor + left.minor
                                left.minor = 0
                            else
                                left.minor = left.minor - num
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].minor =
                                    _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].minor + num
                                num = 0
                            end

                            _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num = num
                            _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].remain = num

                            -- 判断剩余是否已经不足
                            if _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num <= 0 then
                                _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] = nil
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]) then
                                    _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex] = nil
                                end
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid]) then
                                    _defenseInfo.rallySoldiers[rallyRid] = nil
                                end
                            end

                            if left.minor <= 0 then
                                break
                            end
                        end
                    end

                    if left.minor <= 0 then
                        break
                    end
                end
            end

            -- 如果还有剩余伤害,按顺序分配(重伤)
            if left.hardHurt > 0 then
                for rallyRid, rallyRoleSoldierInfo in pairs(armySoldiers) do
                    for rallyArmyIndex in pairs(rallyRoleSoldierInfo) do
                        if _defenseInfo.rallySoldiers[rallyRid] and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]
                        and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] then
                            local num = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num
                            if num >= left.hardHurt then
                                num = num - left.hardHurt
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].hardHurt =
                                    _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].hardHurt + left.hardHurt
                                left.hardHurt = 0
                            else
                                left.hardHurt = left.hardHurt - num
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].hardHurt =
                                    _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].hardHurt + num
                                num = 0
                            end

                            _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num = num
                            _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].remain = num

                            -- 判断剩余是否已经不足
                            if _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num <= 0 then
                                _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] = nil
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]) then
                                    _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex] = nil
                                end
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid]) then
                                    _defenseInfo.rallySoldiers[rallyRid] = nil
                                end
                            end

                            if left.hardHurt <= 0 then
                                break
                            end
                        end
                    end

                    if left.hardHurt <= 0 then
                        break
                    end
                end
            end

            -- 如果还有剩余伤害,按顺序分配(死亡)
            if left.die > 0 then
                for rallyRid, rallyRoleSoldierInfo in pairs(armySoldiers) do
                    for rallyArmyIndex in pairs(rallyRoleSoldierInfo) do
                        if _defenseInfo.rallySoldiers[rallyRid] and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]
                        and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] then
                            local num = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num
                            if num >= left.die then
                                num = num - left.die
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].die =
                                    _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].die + left.die
                                left.die = 0
                            else
                                left.die = left.die - num
                                _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].die =
                                    _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].die + num
                                num = 0
                            end

                            _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num = num
                            _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId].remain = num

                            -- 判断剩余是否已经不足
                            if _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num <= 0 then
                                _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] = nil
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]) then
                                    _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex] = nil
                                end
                                if table.empty(_defenseInfo.rallySoldiers[rallyRid]) then
                                    _defenseInfo.rallySoldiers[rallyRid] = nil
                                end
                            end

                            if left.die <= 0 then
                                break
                            end
                        end
                    end

                    if left.die <= 0 then
                        break
                    end
                end
            end
        end
    end
end

---@see 分配集结部队受到的治疗
---@param _defenseInfo battleObjectAttrClass
function BattleCacle:distributeRallyHeal( _defenseInfo, _soldierHeal )
    -- 计算兵种数量占比
    local allSoldierTypes = {}
    local armySoldiers = {}
    if table.size(_defenseInfo.rallySoldiers) <= 0 then
        return
    end

    -- 计算混合部队伤兵占比
    for rid, roleArmySoldiers in pairs(_defenseInfo.rallySoldierHurt) do
        for armyIndex, soldiers in pairs(roleArmySoldiers) do
            for soldierId, soldierInfo in pairs(soldiers) do
                if soldierInfo.allMinor and soldierInfo.allMinor > 0 then
                    if not allSoldierTypes[soldierId] then
                        allSoldierTypes[soldierId] = 0
                    end
                    allSoldierTypes[soldierId] = allSoldierTypes[soldierId] + soldierInfo.allMinor

                    if not armySoldiers[rid] then
                        armySoldiers[rid] = {}
                    end
                    if not armySoldiers[rid][armyIndex] then
                        armySoldiers[rid][armyIndex] = {}
                    end
                    if not armySoldiers[rid][armyIndex][soldierId] then
                        armySoldiers[rid][armyIndex][soldierId] = 0
                    end
                    armySoldiers[rid][armyIndex][soldierId] = armySoldiers[rid][armyIndex][soldierId] + soldierInfo.allMinor
                end
            end
        end
    end

    local rallySoldierHeal = {}
    for soldierId, heal in pairs(_soldierHeal) do
        if allSoldierTypes[soldierId] and allSoldierTypes[soldierId] > 0 then
            -- 分配到各子部队中
            for rallyRid, rallyRoleSoldierInfo in pairs(armySoldiers) do
                for rallyArmyIndex, rallySoldierInfo in pairs(rallyRoleSoldierInfo) do
                    repeat
                        if not rallySoldierInfo[soldierId] then
                            -- 此角色无此兵种,不再计算
                            break
                        end
                        local healPercent = rallySoldierInfo[soldierId] / allSoldierTypes[soldierId]
                        if _defenseInfo.rallySoldiers[rallyRid] and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex]
                        and _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId] then
                            if _defenseInfo.rallySoldierHurt[rallyRid] and _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex]
                            and _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId] then
                                local rallySoldierSubInfo = _defenseInfo.rallySoldierHurt[rallyRid][rallyArmyIndex][soldierId]
                                if rallySoldierSubInfo.allMinor > 0 then
                                    -- 计算分配到的治疗
                                    local thisHeal = math.floor( heal * healPercent )
                                    local allMinor = rallySoldierSubInfo.allMinor
                                    if allMinor - thisHeal < 0 then
                                        thisHeal = allMinor
                                    end

                                    rallySoldierSubInfo.allMinor = allMinor - thisHeal
                                    _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num
                                        = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num + thisHeal
                                    -- 更新剩余士兵,用于战报
                                    _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].remain = _defenseInfo.rallySoldiers[rallyRid][rallyArmyIndex][soldierId].num
                                    -- 记录治疗
                                    if not rallySoldierHeal[rallyRid] then
                                        rallySoldierHeal[rallyRid] = {}
                                    end
                                    if not rallySoldierHeal[rallyRid][rallyArmyIndex] then
                                        rallySoldierHeal[rallyRid][rallyArmyIndex] = {}
                                    end
                                    rallySoldierHeal[rallyRid][rallyArmyIndex][soldierId] = thisHeal
                                end
                            end
                        end
                    until true
                end
            end
        end
    end

    return rallySoldierHeal
end

---@see 增加目标受到的伤害
---@param _battleScene defaultBattleSceneClass
function BattleCacle:addObjectHurt( _battleScene, _objectIndex, _damage, _isSkill, _isDot )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    -- 统计受到伤害
    objectInfo.turnHurt = objectInfo.turnHurt + _damage
    objectInfo.allHurt = objectInfo.allHurt + _damage
    if not _isSkill and not _isDot then
        -- 技能通过另外的协议字段通知
        objectInfo.allTurnHurt = objectInfo.allTurnHurt + _damage
    end
    -- 最后战斗回合刷新
    self:refreshLastBattleTurn( _battleScene, _objectIndex )
    -- 部队受到攻击后增加怒气
    local BattleSkill =  require "BattleSkill"
    BattleSkill:recoverAngerBySkill( _battleScene, _objectIndex, Enum.SkillAngerRecover.AFTER_BE_ATTACK )
end

---@see 更新对象最后战斗回合
function BattleCacle:refreshLastBattleTurn( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    -- 记录最后一次受伤回合
    objectInfo.lastBattleTurn = _battleScene.turn
end

---@see 增加目标受到的治疗
function BattleCacle:addObjectHeal( _battleScene, _objectIndex, _heal )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    -- 统计受到治疗
    objectInfo.allHeal = objectInfo.allHeal + _heal
end

---@see 普攻怒气获取
---@param _battleScene defaultBattleSceneClass
function BattleCacle:normalAttackAddAnger( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if objectInfo.objectAttr and objectInfo.mainHeroId > 0 then
        objectInfo.sp = objectInfo.sp + math.floor( ( objectInfo.objectAttr.attackAnger + 100 ) * ( 1 + objectInfo.objectAttr.attackAngerMulti / 1000 ) )
        if objectInfo.sp > objectInfo.maxSp then
            objectInfo.sp = objectInfo.maxSp
        end
    else
        objectInfo.sp = 0
    end
end

---@see 使用技能扣除怒气
function BattleCacle:useSkillSubAnger( _battleScene, _objectIndex, _sp )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    if objectInfo then
        objectInfo.sp = objectInfo.sp - _sp
        if objectInfo.sp <= 0 then
            objectInfo.sp = 0
        end
    end
end

---@see 治疗恢复部队兵力
---@param _battleScene defaultBattleSceneClass
function BattleCacle:healArmy( _battleScene, _objectIndex, _heal )
    -- 计算各兵种轻伤数量
    local allMinorInfo = {}
    local allMinorCount = 0
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local armsType
    for soldierId, soldierHurtInfo in pairs(objectInfo.soldierHurt) do
        if soldierHurtInfo.allMinor and soldierHurtInfo.allMinor > 0 then
            -- 仅治疗armsType1~4的士兵
            armsType = CFG.s_Arms:Get(soldierId, "armsType")
            if armsType and armsType >= 1 and armsType <= 4 then
                table.insert( allMinorInfo, {
                    soldierId = soldierId,
                    allMinor = soldierHurtInfo.allMinor
                })
                allMinorCount = allMinorCount + soldierHurtInfo.allMinor
            end
        end
    end

    -- 排序
    table.sort( allMinorInfo, function ( a, b )
        return a.allMinor > b.allMinor
    end)

    local hadHeal = 0
    local realHeal = 0
    local allHealInfo = {}
    for i = 1, #allMinorInfo do
        -- 按比例恢复兵力
        local healMinor
        if i ~= #allMinorInfo then
            healMinor = math.floor( allMinorInfo[i].allMinor / allMinorCount * _heal )
        else
            -- 最后一个兵种
            healMinor = _heal - hadHeal
        end

        local soldierId = allMinorInfo[i].soldierId
        -- 扣除轻伤
        if objectInfo.soldierHurt[soldierId].allMinor - healMinor < 0 then
            healMinor = objectInfo.soldierHurt[soldierId].allMinor
        end
        objectInfo.soldierHurt[soldierId].allMinor = objectInfo.soldierHurt[soldierId].allMinor - healMinor

        -- 增加当前士兵数量
        if objectInfo.soldiers[soldierId] then
            objectInfo.soldiers[soldierId].num = objectInfo.soldiers[soldierId].num + healMinor
            hadHeal = hadHeal + healMinor
            realHeal = realHeal + healMinor

            if not allHealInfo[soldierId] then
                allHealInfo[soldierId] = healMinor
            else
                allHealInfo[soldierId] = allHealInfo[soldierId] + healMinor
            end
        end

        -- 增加同目标的治疗
        self:recordSoldierHealWithObjectIndex( _battleScene, _objectIndex, soldierId, healMinor )
    end

    -- 分配到混合部队
    local rallySoldierHeal = BattleCacle:distributeRallyHeal( objectInfo, allHealInfo )
    -- 通知游戏服务器,治疗恢复
    Common.rpcMultiSend( _battleScene.gameNode, "BattleProxy", "syncBattleHeal", _objectIndex, objectInfo.objectRid,
                        objectInfo.objectType, allHealInfo, rallySoldierHeal, objectInfo.armyIndex, objectInfo.isRally )

    -- 计算当前部队数量
    local armyCount = BattleCommon:getArmySoldierCount( objectInfo )
    -- 同步给游戏服务器对象当前剩余HP
    Common.rpcMultiCall( _battleScene.gameNode, "BattleProxy", "syncObjectArmyCountAndSp",
                            objectInfo.objectIndex, objectInfo.objectType, objectInfo.objectRid,
                            armyCount, nil, objectInfo.sp )

    -- 恢复兵力后触发的技能
    local BattleSkill = require "BattleSkill"
    BattleSkill:triggerSkill( _battleScene, _objectIndex, _objectIndex, Enum.SkillTrigger.RESUME_SOLDIER )

    -- 标记目标受到治疗
    objectInfo.isBeDamageOrHeal = true

    return realHeal
end

---@see 计算对象属性加成
---@param _battleScene defaultBattleSceneClass
---@param _objectIndex integer 对象索引
function BattleCacle:cacleObjectAttr( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    -- 还原成原始的
    objectInfo.objectAttr = table.copy( objectInfo.objectAttrRaw, true )
    objectInfo.skills = table.copy( objectInfo.rawSkills, true )
    local sSkillStatus
    for _, buffInfo in pairs(objectInfo.buffs) do
        sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
        -- 计算buff增加的属性
        if sSkillStatus.attrType then
            for index, attrName in pairs(sSkillStatus.attrType) do
                objectInfo.objectAttr[attrName] = ( objectInfo.objectAttr[attrName] or 0 ) + ( ( sSkillStatus.attrNumber[index] or 0 ) * buffInfo.overlay )
            end
        end

        -- 计算buff增加的技能
        if sSkillStatus.autoSkillID and sSkillStatus.autoSkillID > 0 then
            table.insert( objectInfo.skills, {
                skillId = math.floor( sSkillStatus.autoSkillID / 100 ),
                skillLevel = sSkillStatus.autoSkillID % 100,
                statusSkill = true
            })
        end
    end

    -- 计算技能增加的属性
    for _, skillInfo in pairs(objectInfo.skills) do
        local sHeroSkillEffect = CFG.s_HeroSkillEffect:Get( skillInfo.skillId * 1000 + skillInfo.skillLevel )
        if sHeroSkillEffect then
            for index, name in pairs(sHeroSkillEffect.attrType) do
                if objectInfo.objectAttr[name] then
                    objectInfo.objectAttr[name] = objectInfo.objectAttr[name] + ( sHeroSkillEffect.attrNumber[index] or 0 )
                end
            end
        end
    end

    -- 计算天赋增加的属性
    for name, value in pairs(objectInfo.talentAttr) do
        if objectInfo.objectAttr[name] then
            objectInfo.objectAttr[name] = objectInfo.objectAttr[name] + value
        end
    end

    -- 计算装备增加的属性
    for name, value in pairs(objectInfo.equipAttr) do
        if objectInfo.objectAttr[name] then
            objectInfo.objectAttr[name] = objectInfo.objectAttr[name] + value
        end
    end
end

---@see 计算状态造成的治疗
function BattleCacle:cacleStatusHeal( _battleScene, _objectIndex, _buffIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local armyCount = BattleCommon:getArmySoldierCount( objectInfo )
    if armyCount <= 0 then
        return
    end
    local buffInfo = objectInfo.buffs[_buffIndex]
    local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
    local heal = math.floor( armyCount * ( sSkillStatus.statusHealPower * buffInfo.overlay ) / 100
            * math.max( 0.01, ( 1 + objectInfo.objectAttr.troopsToHealthMulti + 1000 )
            * ( CFG.s_Config:Get("healParameter1") / armyCount / 1000) ^ CFG.s_Config:Get("healParameter2") ) )

    if heal > 0 then
        -- 恢复兵力
        heal = self:healArmy( _battleScene, _objectIndex, heal )
        -- 加入治疗统计
        self:addObjectHeal( _battleScene, _objectIndex, heal )
        -- 统计hot治疗
        objectInfo.turnHotHeal = objectInfo.turnHotHeal + heal
        -- 加入战报
        BattleCommon:insertBattleReport( _battleScene, _objectIndex, _objectIndex, nil , nil, heal )
    end
end

---@see 计算状态造成的伤害
function BattleCacle:cacleStatusDamage(  _battleScene, _objectIndex, _buffIndex )
    --[[
        状态伤害(损兵) = 攻击方部队总数量 * 攻击方部队总攻击 / 防御方部队总防御 / 防御方部队总生命
        * (max(100，1000 + 攻击方技能伤害百分比属性 – 受击方技能伤害减免百分比))/1000 * 状态伤害系数 / 100
        * power(攻击常数 / 攻击方部队总数量，0.5)
    ]]
    local defenseInfo =  BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local buffInfo = defenseInfo.buffs[_buffIndex]
    local attackArmyCount = BattleCommon:getArmySoldierCount( defenseInfo )
    local attackInfo = buffInfo.addSnapShot
    local attackArmyAttack = BattleCacle:cacleArmyAttack( attackInfo, defenseInfo )
    local defenseArmyDefense = BattleCacle:cacleArmyDefense( defenseInfo )
    local defenseArmyHp = BattleCacle:cacleArmyHp( defenseInfo )
    local sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.statusId )
    if defenseArmyDefense <= 0 or defenseArmyHp <= 0 or attackArmyCount <= 0 then
        return
    end

    -- 动态参数
    local dynamicArg = self:cacleDynamicSoldierArg( _battleScene, _objectIndex )
    local damage = math.floor( attackArmyCount * attackArmyAttack / defenseArmyDefense / defenseArmyHp
            * math.max( 100, ( 1000 + attackInfo.objectAttr.skillDamageMulti - defenseInfo.objectAttr.skillDamageReduceMulti )) / 1000
            * ( sSkillStatus.statusDamagePower * buffInfo.overlay ) / 100
            * ( CFG.s_Config:Get("attackConstant") / attackArmyCount) ^ dynamicArg )
    -- 计算护盾
    local BattleBuff = require "BattleBuff"
    damage = BattleBuff:cacleShiled( _battleScene, _objectIndex, damage )
    if damage > 0 then
        -- 加入伤害统计
        self:addObjectHurt( _battleScene, _objectIndex, damage, nil, true )
        -- 计算部队损伤
        self:cacleObjectHurtDie( _battleScene, defenseInfo.attackTargetIndex, _objectIndex )
        -- 加入战报
        BattleCommon:insertBattleReport( _battleScene, _objectIndex, _objectIndex, damage )
        -- 统计dot伤害
        defenseInfo.turnDotDamage = defenseInfo.turnDotDamage + damage
        -- 受到任意伤害时触发的技能
        local BattleSkill = require "BattleSkill"
        BattleSkill:triggerSkill( _battleScene, _objectIndex, _objectIndex, Enum.SkillTrigger.BE_ANY_DAMAGE )
    end
end

---@see 计算动态兵力参数
---@param _battleScene defaultBattleSceneClass
function BattleCacle:cacleDynamicSoldierArg( _battleScene, _objectIndex )
    local objectInfo = BattleCommon:getObjectInfo( _battleScene, _objectIndex )
    local soldierCount = BattleCommon:getArmySoldierCount( objectInfo )
    local troopsParameter1 = CFG.s_Config:Get("troopsParameter1")
    local troopsParameter2 = CFG.s_Config:Get("troopsParameter2")
    local troopsParameter3 = CFG.s_Config:Get("troopsParameter3")
    local troopsParameter4 = CFG.s_Config:Get("troopsParameter4")
    local troopsParameter5 = CFG.s_Config:Get("troopsParameter5")
    local troopsParameter6 = CFG.s_Config:Get("troopsParameter6")
    local minSoldierCounmt = math.min( troopsParameter2, soldierCount )
    return math.max( troopsParameter1, minSoldierCounmt )
            / ( math.max( troopsParameter3, ( minSoldierCounmt / troopsParameter4 ) ^ troopsParameter5 ) * troopsParameter6 )
end

return BattleCacle