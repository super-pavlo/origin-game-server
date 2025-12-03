--[[
* @file : RechargeEnum.lua
* @type : lua lib
* @author : chenlei
* @created : Sat May 09 2020 15:56:02 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 充值枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 超值礼包类型
---@class SaleTypeEnumClass
local SaleType = {
    ---@see 终生限购
    LIFE                =           1,
    ---@see 定时开启
    TIME_OPEN           =           2,
    ---@see 天重置
    DAY_RESET           =           3,
    ---@see 周重置
    WEEK_RESET          =           4,
    ---@see 月重置
    MONTH_RESET         =           5,
    ---@see 跟随活动开启
    ACTIVITY            =           6,
}
Enum.SaleType = SaleType

---@see 限时礼包类型
---@class LimitTimeTypeEnumClass
local LimitTimeType = {
    ---@see 市政厅等级达到触发
    TOWNHALL            =           1,
    ---@see 招募统帅触发
    NEW_HERO            =           2,
    ---@see 升级统帅等级触发
    HERO_LEVEL_UP       =           3,
    ---@see 时代变迁触发
    AGE_CHANGE          =           4,
    ---@see 科技解锁触发
    TECH_UNLOCK         =           5,
    ---@see 战力降低
    POWER_LOST          =           6,
}
Enum.LimitTimeType = LimitTimeType

---@see 充值礼包类型
---@class RechargeTypeEnumClass
local RechargeType = {
    ---@see VIP礼包
    VIP                 =           1,
    ---@see 超值礼包
    SALE                =           2,
    ---@see 每日特惠
    DAILY_SALE          =           3,
    ---@see 宝石商城
    DENAR               =           4,
    ---@see 城市补给站
    CITY                =           5,
    ---@see 成长基金
    GROWN               =           6,
    ---@see BATTLEPASS
    BATTLE_PASS         =           7,
    ---@see 限时礼包
    LIMIT               =           8,
    ---@see 首充
    FIRST               =           9,
}
Enum.RechargeType = RechargeType