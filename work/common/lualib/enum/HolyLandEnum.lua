--[[
* @file : HolyLandEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu May 14 2020 09:56:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 圣地相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 圣地关卡类型
---@class HolyLandTypeEnumClass
local HolyLandType = {
    ---@see 勇气圣所
    COURAGE                         =                   1001,
    ---@see 鲜血圣所
    BLOOD                           =                   1002,
    ---@see 狂风圣所
    GALE                            =                   1003,
    ---@see 希望圣所
    HOPE                            =                   1004,
    ---@see 烈焰圣坛
    BLAZE                           =                   2001,
    ---@see 怒涛圣坛
    RAGE                            =                   2002,
    ---@see 暴风圣坛
    STORM                           =                   2003,
    ---@see 大地圣坛
    EARTH                           =                   2004,
    ---@see 丰收圣坛
    HARVEST                         =                   2005,
    ---@see 智慧圣坛
    WISDOM                          =                   2006,
    ---@see 光辉圣祠
    GLORIOUS                        =                   3001,
    ---@see 战争圣祠
    WAR                             =                   3002,
    ---@see 荣耀圣祠
    GLORY                           =                   3003,
    ---@see 秩序圣祠
    ORDER                           =                   3004,
    ---@see 失落的神庙
    LOST_TEMPLE                     =                   4001,
    ---@see 等级1关卡
    CHECKPOINT_LEVEL_1              =                   10001,
    ---@see 等级2关卡
    CHECKPOINT_LEVEL_2              =                   10002,
    ---@see 等级3关卡
    CHECKPOINT_LEVEL_3              =                   10003,
}
Enum.HolyLandType = HolyLandType

---@see 圣地状态
---@class HolyLandStatusEnumClass
local HolyLandStatus = {
    ---@see 未开放
    LOCK                            =                   0,
    ---@see 初始保护中
    INIT_PROTECT                    =                   1,
    ---@see 初始争夺中
    INIT_SCRAMBLE                   =                   2,
    ---@see 常规争夺中
    SCRAMBLE                        =                   3,
    ---@see 常规保护中
    PROTECT                         =                   4,
}
Enum.HolyLandStatus = HolyLandStatus

---@see 圣地分组类型
---@class HolyLandGroupTypeEnumClass
local HolyLandGroupType = {
    ---@see 圣所
    SANCTUARY                       =                   1,
    ---@see 圣坛
    ALTAR                           =                   2,
    ---@see 圣祠
    HOLY_SHRINE                     =                   3,
    ---@see 神庙
    TEMPLE                          =                   4,
    ---@see 等级1关卡
    CHECKPOINT_LEVEL_1              =                   10,
    ---@see 等级2关卡
    CHECKPOINT_LEVEL_2              =                   11,
    ---@see 等级3关卡
    CHECKPOINT_LEVEL_3              =                   12,
}
Enum.HolyLandGroupType = HolyLandGroupType
