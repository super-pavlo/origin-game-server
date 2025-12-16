--[[
* @file : MonsterEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Jan 14 2020 11:52:02 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 怪物相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 怪物类型
---@class MonsterTypeEnumClass
local MonsterType = {
    ---@see 野蛮人
    BARBARIAN                   =                   1,
    ---@see 野蛮人城寨
    BARBARIAN_CITY              =                   2,
    ---@see 圣地守护者
    HOLYLAND_GUARDIAN           =                   3,
    ---@see 召唤怪物
    SUMMON_MONSTER              =                   4,
}
Enum.MonsterType = MonsterType

---@see 召唤怪物的挑战类型
---@class MonsterBattleTypeEnumClass
local MonsterBattleType = {
    ---@see 只能单人挑战
    SINGLE                      =                   1,
    ---@see 只能集结挑战
    RALLY                       =                   2,
    ---@see 可单人挑战也可集结挑战
    SINGLE_RALLY                =                   3,
}
Enum.MonsterBattleType = MonsterBattleType