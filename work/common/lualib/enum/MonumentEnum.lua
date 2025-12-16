--[[
* @file : MonumentEnum.lua
* @type : lualib
* @author : chenlei
* @created : Tue Apr 28 2020 16:17:21 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 纪念碑相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 纪念碑类型
---@class MonumentTypeEnumClass
local MonumentType = {
    ---@see 全服累计探索一定数量的迷雾块
    SERVER_SCOUT                    =       1,
    ---@see 全服累计击败一定数量特定类型怪物
    SERVER_KILL_MONSTER             =       2,
    ---@see 全服成员数量达到X人的联盟数量达到Y个
    SERVER_ALLICNCE_MEMBER_COUNT    =       4,
    ---@see 全服总共建造了X面联盟旗帜
    SERVER_ALLICNCE_FLAG_COUNT      =       5,
    ---@see X座圣所被首次占领
    SERVER_SANCTUARY                =       6,
    ---@see 个人探索完成了王国内所有迷雾
    PERSON_SCOUT                    =       7,
    ---@see 玩家所在联盟击败了X个等级Y或以上的野蛮人城寨
    SERVER_ALLICNCE_KILL_WALLED     =       8,
    ---@see X名执政官进入特定时代.市政厅等待达到指定值
    SERVER_CITY_LEVEL               =       9,
    ---@see 全服成员数量达到X人的联盟数量达到Y个
    SERVER_ALLICNCE_POWER           =       10,
    ---@see 玩家所在联盟正占领着X座特定奇观建筑
    SERVER_ALLICNCE_BUILD_COUNT     =       11,
}
Enum.MonumentType = MonumentType

---@see 纪念碑领奖类型
---@class MonumentRewardTypeEnumClass
local MonumentRewardType = {
    ---@see 不是全服可领
    NOT_SERVER                      =       0,
    ---@see 全服可领
    SERVER                          =       1,
}
Enum.MonumentRewardType = MonumentRewardType

---@see 纪念碑领奖对象
---@class MonumentRewardObjectEnumClass
local MonumentRewardObject = {
    ---@see 本服全部玩家可领
    SERVER                          =       1,
    ---@see 达成条件时的特定联盟成员可领
    ALLIANCE                        =       2,
    ---@see 满足条件的联盟的成员可领取排行奖励
    ALLIANCE_RANK                   =       3,
    ---@see 达成条件的个人玩家可领
    PERSON                          =       4,
}
Enum.MonumentRewardObject = MonumentRewardObject

---@see 纪念碑事件关闭方式
---@class MonumentCloseTypeEnumClass
local MonumentCloseType = {
    ---@see 条件达成或时间到达时关闭
    CONDITION_AND_TIME              =       0,
    ---@see 只能持续时间到达时关闭
    TIME                            =       1,
}
Enum.MonumentCloseType = MonumentCloseType

---@see 纪念碑排行榜奖励类型
---@class MonumentnRankRewardEnumClass
local MonumentnRankReward = {
    ---@see 个人奖励
    PERSON                          =       0,
}
Enum.MonumentnRankReward = MonumentnRankReward

---@see 纪念碑是否记录排行
---@class MonumentnShowRankEnumClass
local MonumentnShowRank = {
    ---@see 不显示
    NO                          =       0,
    ---@see 显示
    YES                         =       1,
}
Enum.MonumentnShowRank = MonumentnShowRank