--[[
 * @file : BattleTypeCacle.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-06-08 19:55:27
 * @Last Modified time: 2020-06-08 19:55:27
 * @department : Arabic Studio
 * @brief : 战斗类型计算
 * Copyright(C) 2019 IGG, All rights reserved
]]

local MapObjectLogic = require "MapObjectLogic"

local BattleTypeCacle = {}

---@see 计算战斗类型
---@param _attackType integer 攻击方类型
---@param _defenseType integer 防御方类型
function BattleTypeCacle:getBattleType( _attackType, _defenseType, _attackIsCheckPointMonster, _defenseIsCheckPointMonster )
    if _attackType == Enum.RoleType.MONSTER or _defenseType == Enum.RoleType.MONSTER then
        -- 怪物战斗
        return Enum.BattleType.MONSTER
    elseif _attackType == Enum.RoleType.MONSTER_CITY or _defenseType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城寨战斗
        return Enum.BattleType.MONSTER_CITY
    elseif _attackType == Enum.RoleType.ARMY and _defenseType == Enum.RoleType.ARMY then
        -- 部队野外战斗
        return Enum.BattleType.FIELD
    elseif _attackType == Enum.RoleType.CITY or _defenseType == Enum.RoleType.CITY then
        -- 城市战斗
        return Enum.BattleType.CITY_PVP
    elseif MapObjectLogic:checkIsGuildBuildObject( _attackType ) or MapObjectLogic:checkIsGuildBuildObject( _defenseType ) then
        -- 联盟建筑战斗
        return Enum.BattleType.GUILD_BUILD_DEFENSE
    elseif MapObjectLogic:checkIsResourceObject( _attackType ) or MapObjectLogic:checkIsResourceObject( _defenseType ) then
        -- 资源点战斗
        return Enum.BattleType.RESOURCE
    elseif _attackType == Enum.RoleType.GUARD_HOLY_LAND or _defenseType == Enum.RoleType.GUARD_HOLY_LAND then
        -- 圣地守护者
        return Enum.BattleType.GUARD_HOLY_LAND
    elseif _attackType == Enum.RoleType.SANCTUARY or _defenseType == Enum.RoleType.SANCTUARY then
        -- 圣所战斗
        return Enum.BattleType.SANCTUARY
    elseif _attackType == Enum.RoleType.SANCTUARY_PVP or _defenseType == Enum.RoleType.SANCTUARY_PVP then
        -- 圣所战斗.PVP
        return Enum.BattleType.SANCTUARY_PVP
    elseif _attackType == Enum.RoleType.ALTAR or _defenseType == Enum.RoleType.ALTAR then
        -- 圣坛战斗
        return Enum.BattleType.ALTAR
    elseif _attackType == Enum.RoleType.ALTAR_PVP or _defenseType == Enum.RoleType.ALTAR_PVP then
        -- 圣坛战斗.PVP
        return Enum.BattleType.ALTAR_PVP
    elseif _attackType == Enum.RoleType.SHRINE or _defenseType == Enum.RoleType.SHRINE then
        -- 圣祠战斗
        return Enum.BattleType.SHRINE
    elseif _attackType == Enum.RoleType.SHRINE_PVP or _defenseType == Enum.RoleType.SHRINE_PVP then
        -- 圣祠战斗.PVP
        return Enum.BattleType.SHRINE_PVP
    elseif _attackType == Enum.RoleType.LOST_TEMPLE or _defenseType == Enum.RoleType.LOST_TEMPLE then
        -- 失落神庙
        return Enum.BattleType.LOST_TEMPLE
    elseif _attackType == Enum.RoleType.LOST_TEMPLE_PVP or _defenseType == Enum.RoleType.LOST_TEMPLE_PVP then
        -- 失落神庙.PVP
        return Enum.BattleType.LOST_TEMPLE_PVP
    elseif _attackType == Enum.RoleType.CHECKPOINT_1 or _defenseType == Enum.RoleType.CHECKPOINT_1 then
        -- 等级1关卡
        if _attackIsCheckPointMonster or _defenseIsCheckPointMonster then
            return Enum.BattleType.CHECKPOINT_PVE_1
        else
            return Enum.BattleType.CHECKPOINT_1
        end
    elseif _attackType == Enum.RoleType.CHECKPOINT_2 or _defenseType == Enum.RoleType.CHECKPOINT_2 then
        -- 等级2关卡
        if _attackIsCheckPointMonster or _defenseIsCheckPointMonster then
            return Enum.BattleType.CHECKPOINT_PVE_2
        else
            return Enum.BattleType.CHECKPOINT_2
        end
    elseif _attackType == Enum.RoleType.CHECKPOINT_3 or _defenseType == Enum.RoleType.CHECKPOINT_3 then
        -- 等级3关卡
        if _attackIsCheckPointMonster or _defenseIsCheckPointMonster then
            return Enum.BattleType.CHECKPOINT_PVE_3
        else
            return Enum.BattleType.CHECKPOINT_3
        end
    elseif _attackType == Enum.RoleType.EXPEDITION and _defenseType == Enum.RoleType.EXPEDITION then
        -- 部队野外战斗
        return Enum.BattleType.FIELD
    elseif _attackType == Enum.RoleType.SUMMON_SINGLE_MONSTER or _defenseType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        -- 召唤怪物单人挑战战斗
        return Enum.BattleType.SUMMON_SINGLE
    elseif _attackType == Enum.RoleType.SUMMON_RALLY_MONSTER or _defenseType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 召唤怪物集结挑战战斗
        return Enum.BattleType.SUMMON_RALLY
    end
end

---@see 判断是否是驻守部队
function BattleTypeCacle:checkIsGarrisonArmy( _objectType )
    if MapObjectLogic:checkIsGuildBuildObject( _objectType )
    or _objectType == Enum.RoleType.SANCTUARY or _objectType == Enum.RoleType.SANCTUARY_PVP
    or _objectType == Enum.RoleType.ALTAR or _objectType == Enum.RoleType.ALTAR_PVP
    or _objectType == Enum.RoleType.SHRINE or _objectType == Enum.RoleType.SHRINE_PVP
    or _objectType == Enum.RoleType.LOST_TEMPLE or _objectType == Enum.RoleType.LOST_TEMPLE_PVP
    or _objectType == Enum.RoleType.CHECKPOINT_1 or _objectType == Enum.RoleType.CHECKPOINT_2
    or _objectType == Enum.RoleType.CHECKPOINT_3 then
        return true
    end
end

return BattleTypeCacle