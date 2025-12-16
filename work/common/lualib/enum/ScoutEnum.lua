--[[
* @file : ScoutEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Mon May 25 2020 15:35:56 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 斥候相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 斥候侦查目标类型
---@class ScoutTargetTypeEnumClass
local ScoutTargetType = {
    ---@see 玩家城市
    CITY                        =                       1,
    ---@see 玩家部队
    ROLE_ARMY                   =                       2,
    ---@see 集结部队
    RALLY_ARMY                  =                       3,
    ---@see 玩家采集点
    RESOURCE                    =                       4,
    ---@see 联盟建筑
    GUILD_BUILD                 =                       5,
    ---@see 关卡
    CHECKPOINT                  =                       6,
    ---@see 圣地
    RELIC                       =                       7,
    ---@see 山洞
    CAVE                        =                       8,
}
Enum.ScoutTargetType = ScoutTargetType

---@see 侦查角色部队数量显示类型
---@class ScoutArmyTypeEnumClass
local ScoutArmyType = {
    ---@see 不详
    NO_DETAIL                   =                       1,
    ---@see 大概数量不显示ICON
    NO_ICON                     =                       2,
    ---@see 大概数量显示ICON
    ICON                        =                       3,
    ---@see 精确数量
    REAL_NUM                    =                       4,
}
Enum.ScoutArmyType = ScoutArmyType

---@see 侦查城援军显示类型
---@class ScoutReinforceTypeEnumClass
local ScoutReinforceType = {
    ---@see 不详
    NO_DETAIL                   =                       1,
    ---@see 大概数量显示ICON
    ICON                        =                       2,
    ---@see 精确数量
    REAL_NUM                    =                       3,
}
Enum.ScoutReinforceType = ScoutReinforceType

---@see 集结士兵显示类型
---@class ScoutCityRallyTypeEnumClass
local ScoutCityRallyType = {
    ---@see 大概数量显示ICON
    ICON                        =                       1,
    ---@see 精确数量
    REAL_NUM                    =                       2,
    ---@see 无正在集结的部队
    NO_RALLY                    =                       3,
}
Enum.ScoutCityRallyType = ScoutCityRallyType
