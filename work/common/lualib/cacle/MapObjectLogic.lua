--[[
 * @file : MapObjectLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-20 14:14:59
 * @Last Modified time: 2020-05-20 14:14:59
 * @department : Arabic Studio
 * @brief : 目标对象管理逻辑库
 * Copyright(C) 2019 IGG, All rights reserved
]]

local MapObjectLogic = {}

---@see 判断目标是否是资源点对象
function MapObjectLogic:checkIsResourceObject( _objectType )
    if not _objectType then
        return false
    end
    return _objectType >= Enum.RoleType.STONE and _objectType <= Enum.RoleType.DENAR
end

---@see 判断目标是否是资源山洞存在
function MapObjectLogic:checkIsResourceCaveObject( _objectType )
    if not _objectType then
        return false
    end
    return ( _objectType >= Enum.RoleType.STONE and _objectType <= Enum.RoleType.DENAR ) or _objectType == Enum.RoleType.VILLAGE or _objectType == Enum.RoleType.CAVE
end

---@see 判断目标是否是联盟建筑
function MapObjectLogic:checkIsGuildBuildObject( _objectType )
    if not _objectType then
        return false
    end
    return ( _objectType >= Enum.RoleType.GUILD_CENTER_FORTRESS and _objectType <= Enum.RoleType.GUILD_FLAG )
    or ( _objectType >= Enum.RoleType.GUILD_FOOD_CENTER and _objectType <= Enum.RoleType.GUILD_GOLD_CENTER )
end

---@see 是否是可进攻的联盟建筑
function MapObjectLogic:checkIsAttackGuildBuildObject( _objectType )
    if not _objectType then
        return false
    end
    return _objectType >= Enum.RoleType.GUILD_CENTER_FORTRESS and _objectType <= Enum.RoleType.GUILD_FLAG
end

---@see 是否是联盟资源中心类型建筑
function MapObjectLogic:checkIsGuildResourceCenterBuild( _objectType )
    return _objectType >= Enum.GuildBuildType.FOOD_CENTER and _objectType <= Enum.GuildBuildType.GOLD_CENTER
end

---@see 是否是联盟资源中心类型建筑
function MapObjectLogic:checkIsGuildResourceCenterObject( _objectType )
    return _objectType >= Enum.RoleType.GUILD_FOOD_CENTER and _objectType <= Enum.RoleType.GUILD_GOLD_CENTER
end

---@see 是否是联盟要塞类型建筑
function MapObjectLogic:checkIsGuildFortressObject( _objectType )
    return _objectType >= Enum.RoleType.GUILD_CENTER_FORTRESS and _objectType <= Enum.RoleType.GUILD_FORTRESS_SECOND
end

---@see 是否是联盟资源点类型建筑
function MapObjectLogic:checkIsGuildResourcePointObject( _objectType )
    return _objectType >= Enum.RoleType.GUILD_FOOD and _objectType <= Enum.RoleType.GUILD_GOLD
end

---@see 是否是圣地建筑
function MapObjectLogic:checkIsHolyLandObject( _objectType )
    if _objectType == Enum.RoleType.CHECKPOINT or _objectType == Enum.RoleType.RELIC
    or _objectType == Enum.RoleType.SANCTUARY or _objectType == Enum.RoleType.ALTAR
    or _objectType == Enum.RoleType.SHRINE or _objectType == Enum.RoleType.LOST_TEMPLE
    or _objectType == Enum.RoleType.CHECKPOINT_1 or _objectType == Enum.RoleType.CHECKPOINT_2
    or _objectType == Enum.RoleType.CHECKPOINT_3 or _objectType == Enum.RoleType.SANCTUARY_PVP
    or _objectType == Enum.RoleType.ALTAR_PVP or _objectType == Enum.RoleType.SHRINE_PVP
    or _objectType == Enum.RoleType.LOST_TEMPLE_PVP then
        return true
    end
end

---@see 是否是关卡
function MapObjectLogic:checkIsCheckPoint( _objectType )
    if _objectType == Enum.RoleType.CHECKPOINT or _objectType == Enum.RoleType.CHECKPOINT_1 or _objectType == Enum.RoleType.CHECKPOINT_2
    or _objectType == Enum.RoleType.CHECKPOINT_3 then
        return true
    end
end

---@see 获取具体的圣地建筑类型
function MapObjectLogic:getRealHolyLandType( _strongHoldId, _status, _noPvP )
    local type = CFG.s_StrongHoldData:Get( _strongHoldId, "type" )
    local sStrongHoldType = CFG.s_StrongHoldType:Get( type )

    -- 判断是否是PVP
    if not _noPvP then
        if _status == Enum.HolyLandStatus.PROTECT or _status == Enum.HolyLandStatus.SCRAMBLE then
            if sStrongHoldType.group == Enum.HolyLandGroupType.ALTAR then
                return Enum.RoleType.ALTAR_PVP
            elseif sStrongHoldType.group == Enum.HolyLandGroupType.HOLY_SHRINE then
                return Enum.RoleType.SHRINE_PVP
            elseif sStrongHoldType.group == Enum.HolyLandGroupType.SANCTUARY then
                return Enum.RoleType.SANCTUARY_PVP
            elseif sStrongHoldType.group == Enum.HolyLandGroupType.TEMPLE then
                return Enum.RoleType.LOST_TEMPLE_PVP
            end
        end
    end

    if sStrongHoldType.group == Enum.HolyLandGroupType.ALTAR then
        return Enum.RoleType.ALTAR
    elseif sStrongHoldType.group == Enum.HolyLandGroupType.HOLY_SHRINE then
        return Enum.RoleType.SHRINE
    elseif sStrongHoldType.group == Enum.HolyLandGroupType.SANCTUARY then
        return Enum.RoleType.SANCTUARY
    elseif sStrongHoldType.group == Enum.HolyLandGroupType.TEMPLE then
        return Enum.RoleType.LOST_TEMPLE
    elseif sStrongHoldType.group == Enum.HolyLandGroupType.CHECKPOINT_LEVEL_1 then
        return Enum.RoleType.CHECKPOINT_1
    elseif sStrongHoldType.group == Enum.HolyLandGroupType.CHECKPOINT_LEVEL_2 then
        return Enum.RoleType.CHECKPOINT_2
    elseif sStrongHoldType.group == Enum.HolyLandGroupType.CHECKPOINT_LEVEL_3 then
        return Enum.RoleType.CHECKPOINT_3
    end

    assert(false, string.format("invalid holyland type(%d)", sStrongHoldType))
end

---@see 根据建筑类型.获取建筑ID
function MapObjectLogic:getBuildObjectId( _objectInfo )
    if self:checkIsGuildBuildObject( _objectInfo.objectType ) then
        -- 联盟建筑
        local GuildBuildLogic = require "GuildBuildLogic"
        return GuildBuildLogic:objectTypeToBuildType( _objectInfo.objectType )
    elseif self:checkIsHolyLandObject( _objectInfo.objectType ) then
        -- 圣地建筑
        return _objectInfo.holyLandType
    end
end

---@see 根据建筑类型.获取建筑范围半径
function MapObjectLogic:getBuildRadiusCollide( _objectType, _objectId )
    if _objectType == Enum.RoleType.CITY then
        -- 城市
        return CFG.s_Config:Get("cityRadiusCollide")
    elseif _objectType == Enum.RoleType.MONSTER_CITY or self:checkIsResourceObject( _objectType )
    or _objectType == Enum.RoleType.CAVE or _objectType == Enum.RoleType.VILLAGE then
        -- 野蛮人城寨,资源点,山洞村庄
        return CFG.s_Config:Get("resourceGatherRadiusCollide")
    elseif self:checkIsGuildBuildObject( _objectType ) or self:checkIsGuildResourcePointObject( _objectType ) then
        -- 联盟建筑
        local GuildBuildLogic = require "GuildBuildLogic"
        local guildBuildType = GuildBuildLogic:objectTypeToBuildType( _objectType )
        return CFG.s_AllianceBuildingType:Get( guildBuildType, "radiusCollide" )
    elseif self:checkIsHolyLandObject( _objectType ) then
        -- 圣地建筑
        local holyLandType = CFG.s_StrongHoldData:Get( _objectId, "type" )
        return CFG.s_StrongHoldType:Get( holyLandType, "radiusCollide" )
    elseif _objectType == Enum.RoleType.RUNE then
        -- 符文
        return CFG.s_Config:Get("cityRadiusCollide")
    end
    LOG_WARNING("getBuildRadiusCollide invalid _objectType(%d)", _objectType)
    return CFG.s_Config:Get("cityRadiusCollide")
end

---@see 根据建筑类型.获取建筑占地半径
function MapObjectLogic:getBuildRadius( _objectType, _objectId )
    if _objectType == Enum.RoleType.CITY then
        -- 城市
        return CFG.s_Config:Get("cityRadius")
    elseif _objectType == Enum.RoleType.MONSTER_CITY or self:checkIsResourceObject( _objectType )
    or _objectType == Enum.RoleType.CAVE or _objectType == Enum.RoleType.VILLAGE then
        -- 野蛮人城寨,资源点,山洞村庄
        return CFG.s_Config:Get("resourceGatherRadius")
    elseif self:checkIsGuildBuildObject( _objectType ) or self:checkIsGuildResourcePointObject( _objectType ) then
        -- 联盟建筑
        local GuildBuildLogic = require "GuildBuildLogic"
        local guildBuildType = GuildBuildLogic:objectTypeToBuildType( _objectType )
        return CFG.s_AllianceBuildingType:Get( guildBuildType, "radius" )
    elseif self:checkIsHolyLandObject( _objectType ) then
        -- 圣地建筑
        local holyLandType = CFG.s_StrongHoldData:Get( _objectId, "type" )
        return CFG.s_StrongHoldType:Get( holyLandType, "radius" )
    end
    LOG_WARNING("getBuildRadius invalid _objectType(%d)", _objectType)
    return CFG.s_Config:Get("cityRadius")
end

return MapObjectLogic