--[[
* @file : BuildingEnum.lua
* @type : lua lib
* @author : chenlei
* @created : Tue Dec 24 2019 10:30:14 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 内城相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 建筑类型
---@class BuildingTypeEnumClass
local BuildingType = {
    ---@see 市政厅
    TOWNHALL                =               1,
    ---@see 农场
    FARM                    =               2,
    ---@see 木材场
    WOOD                    =               3,
    ---@see 采石场
    STONE                   =               4,
    ---@see 金矿
    GOLD                    =           	5,
    ---@see 城墙
    WALL                    =	            6,
    ---@see 工人小屋
    WORKER                  =               7,
    ---@see 警戒塔
    GUARDTOWER              =               8,
    ---@see 兵营
    BARRACKS                =               9,
    ---@see 马厩
    STABLE                  =               10,
    ---@see 靶场
    ARCHERYRANGE            =               11,
    ---@see 攻城器
    SIEGE                   =               12,
    ---@see 学院
    COLLAGE                 =               13,
    ---@see 医院
    HOSPITAL                =               14,
    ---@see 仓库
    WAREHOUSE               =               15,
    ---@see 联盟中心
    ALLIANCE_CENTER         =               16,
    ---@see 城堡
    CASTLE                  =               17,
    ---@see 酒馆
    TAVERN                  =               18,
    ---@see 商栈
    BUSSINESS               =               19,
    ---@see 商店
    STORE                   =               20,
    ---@see 驿站
    STATION                 =               21,
    ---@see 斥候营地
    SCOUT_CAMP              =               28,
    ---@see 公告牌
    BILLBORAD               =               29,
    ---@see 纪念碑
    MONUMENT                =               30,
    ---@see 铁匠铺
    SMITHY                  =               31,
}
Enum.BuildingType = BuildingType

---@see 建筑分组
---@class BuildingGroupEnumClass
local BuildingGroup = {
    ---@see 经济类建筑
    ECONOMIC                =               1,
    ---@see 军事类建筑
    MILITARY                =               2,
    ---@see 装饰类建筑
    DECORATION              =               3,
}
Enum.BuildingGroup = BuildingGroup

---@see 酒馆宝箱类型
---@class BoxTypeEnumClass
local BoxType = {
    ---@see 白银宝箱
    SILVER                  =               1,
    ---@see 黄金宝箱
    GOLD                    =               2,
}
Enum.BoxType = BoxType