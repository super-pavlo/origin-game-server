--[[
* @file : HeroEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Dec 26 2019 10:45:18 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 统帅相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 统帅状态
---@class HeroStatusEnumClass
local HeroStatus = {
    ---@see 待命
    WAIT                    =                   0,
    ---@see 出征
    WORK                    =                   1,
    ---@see 守城
    DEFENSE                 =                   2,
}
Enum.HeroStatus = HeroStatus

---@see 士兵状态
---@class SoilderStatusEnumClass
local SoilderStatus = {
    ---@see 待命
    WAIT                    =                   0,
    ---@see 出征
    WORK                    =                   1,
    ---@see 守城
    DEFENSE                 =                   2,
    ---@see 轻伤
    MINOR_INJURY            =                   3,
    ---@see 重伤
    SERIOUS_INJURY          =                   4,
}
Enum.SoilderStatus = SoilderStatus

---@see 统帅稀有度
---@class HeroRareTypeEnumClass
local HeroRareType = {
    ---@see 普通
    NORMAL                  =                   1,
    ---@see 优秀
    EXCELLENT               =                   2,
    ---@see 精英
    ELITE                   =                   3,
    ---@see 史诗
    EPIC                    =                   4,
    ---@see 传说
    LEGEND                  =                   5,
}
Enum.HeroRareType = HeroRareType

---@see 统帅雕像能否兑换
---@class ExchangeEnumClass
local Exchange = {
    ---@see 不可兑换
    NO                      =                   0,
    ---@see 可以兑换
    YES                     =                   1,
}
Enum.Exchange = Exchange