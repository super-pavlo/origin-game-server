--[[
* @file : RankEnum.lua
* @type : lua lib
* @author : chenlei
* @created : Mon Apr 20 2020 16:34:56 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 排行版枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 排行版偏移值
---@class RankCommonEnumClass
local RankCommon = {
    ---@see 偏移值
    OFFSET          =           1000000000,
    ---@see 最大时间
    MAXTIME         =           2147483647,
}
Enum.RankCommon = RankCommon

---@see 排行版类型
---@class RankTypeEnumClass
local RankType = {
    ---@see 战力至上
    COMBAT_FIRST                =           100,
    ---@see 拔地而起
    RISE_UP                     =           101,
    ---@see 战略储备
    RESERVE                     =           102,
    ---@see 最强执政官.总排名
    MGE_TOTAL                   =           103,
    ---@see 最强执政官.部队训练积分排名
    MGE_TARIN                   =           104,
    ---@see 最强执政官.击败野蛮人积分排名
    MGE_KILL_BARB               =           105,
    ---@see 最强执政官.资源采集积分排名
    MGE_COLLECT_RES             =           106,
    ---@see 最强执政官.战力提升积分排名
    MGE_POWER_UP                =           107,
    ---@see 最强执政官.消灭敌军积分排名
    MGE_KILL                    =           108,
    ---@see 地狱活动原始时代
    HELL_ORIGINAL               =           109,
    ---@see 地狱活动古典时代
    HELL_CLASSICAL              =           110,
    ---@see 地狱活动黑暗时代
    HELL_DARK                   =           111,
    ---@see 地狱活动封建时代
    HELL_FEUDAL                 =           112,
    ---@see 地狱活动工业时代
    HELL_INDUSTRY               =           113,
    ---@see 地狱活动现代
    HELL_MODERN                 =           114,
    ---@see 部落之王联盟排行榜
    TRIBE_KING                  =           115,
    ---@see 战争号角个人排名
    FIGHT_HORN                  =           116,
    ---@see 战争号角联盟排名
    FIGHT_HORN_ALLIANCE         =           117,
    ---@see 联盟战力
    ALLIANCE_POWER              =           201,
    ---@see 联盟击杀
    ALLIANCE_KILL               =           202,
    ---@see 联盟旗帜
    ALLIANCE_FLAG               =           203,
    ---@see 个人战力
    ROLE_POWER                  =           204,
    ---@see 个人击杀
    ROLE_KILL                   =           205,
    ---@see 市政厅等级
    MAIN_TOWN_LEVEL             =           206,
    ---@see 个人资源采集
    ROLE_RES                    =           207,
    ---@see 远征排行版
    EXPEDITION                  =           208,
    ---@see 个人战力排行
    ALLIACEN_ROLE_POWER         =           300,
    ---@see 杀戮机器
    ALLIACEN_ROLE_KILL          =           301,
    ---@see 科技贡献
    ALLIACEN_ROLE_DONATE        =           302,
    ---@see 建造大师
    ALLIACEN_ROLE_BUILD         =           303,
    ---@see 联盟帮助
    ALLIACEN_ROLE_HELP          =           304,
    ---@see 资源援助
    ALLIACEN_ROLE_RES_HELP      =           305,
}
Enum.RankType = RankType

---@see 排行版查询类型
---@class RankQueryTypeEnumClass
local RankQueryType = {
    ---@see 本服
    GAME                        =           1,
    ---@see 本联盟
    GUILD                       =           2,
}
Enum.RankQueryType = RankQueryType