--[[
* @file : EnumInit.lua
* @type : snax single service
* @author : linfeng
* @created : Tue Jul 24 2018 09:54:14 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 枚举初始化
* Copyright(C) 2017 IGG, All rights reserved
]]

local sharedata = require "skynet.sharedata"
local Enum = require "Enum"
local RoleDef = require "RoleDef"
local ItemDef = require "ItemDef"
local HeroDef = require "HeroDef"
local ArmyDef = require "ArmyDef"
local GuildDef = require "GuildDef"
local GuildBuildDef = require "GuildBuildDef"
local TransportDef = require "TransportDef"
local HolyLandDef = require "HolyLandDef"
local GuildGiftDef = require "GuildGiftDef"
local AttrDef = require "AttrDef"

require "SystemEnum"
require "WebEnum"
require "RoleEnum"
require "MapEnum"
require "BuildingEnum"
require "ItemEnum"
require "ArmyEnum"
require "OtherEnum"
require "TaskEnum"
require "HeroEnum"
require "ResourceEnum"
require "LogEnum"
require "MonsterEnum"
require "EmailEnum"
require "BattleEnum"
require "GuildEnum"
require "ActivityEnum"
require "ChatEnum"
require "RankEnum"
require "MonumentEnum"
require "RechargeEnum"
require "RallyEnum"
require "HolyLandEnum"
require "ScoutEnum"
require "ExpeditionEnum"

---@see 初始化枚举到sharedata
function response.initAllEnum( ConfigEntityCfg, CommonEntityCfg, UserEntityCfg, RoleEntityCfg )
    for enumName,enumValue in pairs(Enum) do
        sharedata.new( "Enum-"..enumName, { enumValue = enumValue } )
    end

    -- 初始化表结构名字
    local tbNames = {}
    for _, tbInfo in pairs(ConfigEntityCfg) do
        tbNames[tbInfo.name] = tbInfo.name
    end
    for _, tbInfo in pairs(CommonEntityCfg) do
        tbNames[tbInfo.name] = tbInfo.name
    end
    for _, tbInfo in pairs(UserEntityCfg) do
        tbNames[tbInfo.name] = tbInfo.name
    end
    for _, tbInfo in pairs(RoleEntityCfg) do
        tbNames[tbInfo.name] = tbInfo.name
    end
    sharedata.new( "Enum-Table", { enumValue = tbNames } )

    -- 初始化角色数据枚举
    local roleDef = RoleDef:getDefaultRoleAttr()
    local roleEnum = {}
    for name in pairs(roleDef) do
        roleEnum[name] = name
    end
    sharedata.new( "Enum-Role", { enumValue = roleEnum } )

    -- 初始化道具数据枚举
    local itemDef = ItemDef:getDefaultItemAttr()
    local itemEnum = {}
    for name in pairs( itemDef ) do
        itemEnum[name] = name
    end
    sharedata.new( "Enum-Item", { enumValue = itemEnum } )

    -- 初始化统帅数据枚举
    local heroDef = HeroDef:getDefaultHeroAttr()
    local heroEnum = {}
    for name in pairs( heroDef ) do
        heroEnum[name] = name
    end
    sharedata.new( "Enum-Hero", { enumValue = heroEnum } )

    -- 初始化部队数据枚举
    local armyDef = ArmyDef:getDefaultArmyAttr()
    local armyEnum = {}
    for name in pairs( armyDef ) do
        armyEnum[name] = name
    end
    sharedata.new( "Enum-Army", { enumValue = armyEnum } )

    -- 初始化联盟数据枚举
    local attrDef = AttrDef:getDefaultAttr()
    local guildDef = GuildDef:getDefaultGuildAttr()
    local guildEnum = {}
    for name in pairs( guildDef ) do
        guildEnum[name] = name
    end
    for name in pairs( attrDef ) do
        guildEnum[name] = name
    end
    sharedata.new( "Enum-Guild", { enumValue = guildEnum } )

    -- 初始化联盟建筑数据枚举
    local guildBuildDef = GuildBuildDef:getDefaultGuildBuildAttr()
    local guildBuildEnum = {}
    for name in pairs( guildBuildDef ) do
        guildBuildEnum[name] = name
    end
    sharedata.new( "Enum-GuildBuild", { enumValue = guildBuildEnum } )

    -- 初始化运输车数据枚举
    local transportDef = TransportDef:getDefaultTransportAttr()
    local transportEnum = {}
    for name in pairs( transportDef ) do
        transportEnum[name] = name
    end
    sharedata.new( "Enum-Transport", { enumValue = transportEnum } )

    -- 初始化圣地数据枚举
    local hollyLandDef = HolyLandDef:getDefaultHolyLandAttr()
    local holyLandEnum = {}
    for name in pairs( hollyLandDef ) do
        holyLandEnum[name] = name
    end
    sharedata.new( "Enum-HolyLand", { enumValue = holyLandEnum } )

    -- 初始化联盟礼物数据枚举
    local guildGiftDef = GuildGiftDef:getDefaultGuildGiftAttr()
    local guildGiftEnum = {}
    for name in pairs( guildGiftDef ) do
        guildGiftEnum[name] = name
    end
    sharedata.new( "Enum-GuildGift", { enumValue = guildGiftEnum } )
end