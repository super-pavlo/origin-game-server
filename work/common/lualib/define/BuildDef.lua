--[[
 * @file : BuildDef.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-23 14:19:51
 * @Last Modified time: 2020-04-23 14:19:51
 * @department : Arabic Studio
 * @brief : 建筑相关定义
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BuildDef = {}

---@class defaultBuildAttrClass
local defaultBuildAttr = {
    buildingIndex                                   =           0,  -- 建筑索引
    type                                            =           0,  -- 建筑类型
    level                                           =           0,  -- 建筑等级
    pos                                             =           {}, -- 建筑坐标
    finishTime                                      =           0,  -- 建造/升级结束时间 0为已完成
    version                                         =           0,  -- 对应建筑版本
    lastRewardTime                                  =           0,  -- 上次获取资源时间
    lostHp                                          =           0,  -- 扣除血量
    beginBurnTime                                   =           0,  -- 开始燃烧的时间
    serviceTime                                     =           0,  -- 上次维修的时间
    lastBurnTime                                    =           0,  -- 上次燃烧时间，服务器重启使用
    BuildingGainInfo                                =           {}, -- 资源时间
    ---------------------------------------以下数据不落地-------------------------
}

---@class defaultWarEhourseAttrClass
local defaultWarEhourseAttr = {
    foodProtect                                     =           0,  -- 仓库食物保护
    woodProtect                                     =           0,  -- 木材食物保护
    stoneProtect                                    =           0,  -- 石头食物保护
    goldProtect                                     =           0,  -- 金币食物保护
}

---@see 获取仓库保护默认属性
---@return defaultWarEhourseAttrClass
function BuildDef:getDefaultWarEhourseAttr()
    return const( table.copy( defaultWarEhourseAttr ) )
end

return BuildDef