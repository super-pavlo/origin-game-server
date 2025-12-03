--[[
* @file : ArmyEnum.lua
* @type : lualib
* @author : chenlei
* @created : Thu Dec 26 2019 10:23:27 GMT+0800 .中国标准时间)
* @department : Arabic Studio
* @brief : 部队枚举
* Copyright.C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 兵种类型
---@class ArmyTypeEnumClass
local ArmyType = {
    ---@see 步兵
    INFANTRY                =               1,
    ---@see 骑兵
    CAVALRY                 =               2,
    ---@see 弓兵
    ARCHER                  =               3,
    ---@see 攻城单位
    SIEGE_UNIT              =               4,
    ---@see 野蛮人
    BARBARIAN               =               5,
    ---@see 野蛮人城寨
    BARBARIAN_CITY          =               6,
    ---@see 警戒塔
    GUARD_TOWER             =               7,
}
Enum.ArmyType = ArmyType

---@see 兵种子类型
---@class ArmySubTypeEnumClass
local ArmySubType = {
    ---@see 普通
    COMMON                  =               1,
    ---@see 特殊
    SPECIAL                 =               2,
}
Enum.ArmySubType = ArmySubType

---@see 是否晋升
---@class ArmyUpdateEnumClass
local ArmyUpdate = {
    ---@see 非晋升
    NOT                     =               0,
    ---@see 晋升
    YES                     =               1,
}
Enum.ArmyUpdate = ArmyUpdate

---@see 军队状态
---@class ArmyStatusEnumClass
local ArmyStatus = {
    ---@see 向空地行军中.军队
    SPACE_MARCH             =               1 << 0,
    ---@see 进攻行军中.军队
    ATTACK_MARCH            =               1 << 1,
    ---@see 采集行军中.军队
    COLLECT_MARCH           =               1 << 2,
    ---@see 增援行军中.军队
    REINFORCE_MARCH         =               1 << 3,
    ---@see 集结行军中.军队
    RALLY_MARCH             =               1 << 4,
    ---@see 撤退行军中.军队
    RETREAT_MARCH           =               1 << 5,
    ---@see 溃败行军中.军队
    FAILED_MARCH            =               1 << 6,
    ---@see 采集中.军队
    COLLECTING              =               1 << 7,
    ---@see 战斗中.军队.城市
    BATTLEING               =               1 << 8,
    ---@see 驻扎中.军队
    STATIONING              =               1 << 9,
    ---@see 驻守中.军队
    GARRISONING	            =               1 << 10,
    ---@see 巡逻.野蛮人
    PATROL                  =               1 << 11,
    ---@see 探索中.斥候
    DISCOVER                =               1 << 12,
    ---@see 探索返回中.斥候
    RETURN                  =               1 << 13,
    ---@see 待命中.斥候
    STANBY                  =               1 << 14,
    ---@see 返回城市中.斥候
    BACK_CITY               =               1 << 15,
    ---@see 野蛮人溃败
    MONSTER_FAILED          =               1 << 16,
    ---@see 军队待机
    ARMY_STANBY             =               1 << 17,
    ---@see 追击
    FOLLOWUP                =               1 << 19,
    ---@see 移动.战斗时调整位置
    MOVE                    =               1 << 20,
    ---@see 集结等待
    RALLY_WAIT              =               1 << 22,
    ---@see 加入集结行军
    RALLY_JOIN_MARCH        =               1 << 23,
    ---@see 采集地图上的其他资源.客户端部队不消失状态
    COLLECTING_NO_DELETE    =               1 << 24,
    ---@see 斥候侦查中
    SCOUTING                =               1 << 25,
    ---@see 斥候调查中
    SURVEYING               =               1 << 26,
    ---@see 集结部队战斗中
    RALLY_BATTLE            =               1 << 27,
    ---@see 斥候侦查中删除地图斥候
    SCOUTING_DELETE         =               1 << 28,
}
Enum.ArmyStatus = ArmyStatus

---@see 部队状态处理操作
---@class ArmyStatusOpEnumClass
local ArmyStatusOp = {
    ---@see 增加
    ADD                     =               1,
    ---@see 删除
    DEL                     =               2,
    ---@see 设置
    SET                     =               3,
}
Enum.ArmyStatusOp = ArmyStatusOp