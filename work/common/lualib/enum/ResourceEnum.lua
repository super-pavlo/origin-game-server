--[[
* @file : ResourceEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Mon Jan 06 2020 10:14:41 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 资源相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 资源采集速度放大倍数
Enum.ResourceCollectSpeedMultiple = 10000

---@see 资源类型
---@class ResourceTypeEnumClass
local ResourceType = {
    ---@see 农田
    FARMLAND                =                   1,
    ---@see 木材
    WOOD                    =                   2,
    ---@see 石料
    STONE                   =                   3,
    ---@see 金矿
    GOLD                    =                   4,
    ---@see 宝石
    DENAR                   =                   5,
    ---@see 山洞
    CAVE                    =                   6,
    ---@see 村庄
    VILLAGE                 =                   7,
}
Enum.ResourceType = ResourceType

---@see 资源采集报告类型
---@class ResourceReportTypeEnumClass
local ResourceReportType = {
    ---@see 资源田
    RESOURCE                =                   1,
    ---@see 联盟资源中心
    RESOURCE_CENTER         =                   2,
}
Enum.ResourceReportType = ResourceReportType