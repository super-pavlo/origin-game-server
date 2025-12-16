--[[
* @file : ExpeditionEnum.lua
* @type : lua lib
* @author : chenlei
* @created : Wed Dec 16 2020 22:13:07 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 远征相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]
local Enum = require "Enum"

---@see 战役类型
---@class ExpeditionBattleTypeEnumClass
local ExpeditionBattleType = {
    ---@see 普通关卡
    COMMON                          =               1,
    ---@see BOSS关卡
    BOSS                            =               2,
    ---@see 集结关卡
    RALLY                           =               3,
    ---@see 驻防关卡
    DEFEND                          =               4,
}
Enum.ExpeditionBattleType = ExpeditionBattleType

---@see 战役结果
---@class ExpeditionBattleResultEnumClass
local ExpeditionBattleResult = {
    ---@see 时间到失败
    TIME_FAIL                       =               0,
    ---@see 战斗失败
    FAIL                            =               1,
    ---@see 胜利
    WIN                             =               2,
}
Enum.ExpeditionBattleResult = ExpeditionBattleResult

---@see 星级结果结算类型
---@class ExpeditionStarTypeEnumClass
local ExpeditionStarType = {
    ---@see 时间
    TIME                            =               1,
    ---@see 伤亡比例
    DEAD_RATE                       =               2,
    ---@see 英雄阵亡数目
    HERO_DEAD                       =               3,
}
Enum.ExpeditionStarType = ExpeditionStarType
