--[[
* @file : HeroDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Dec 26 2019 11:54:09 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定义统帅相关属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local HeroDef = {}

---@class defaultHeroAttrClass
local defaultHeroAttr = {
    heroId                          =               0,                          -- 统帅id
    star                            =               0,                          -- 星级
    starExp                         =               0,                          -- 星级进度
    level                           =               0,                          -- 等级
    exp                             =               0,                          -- 经验
    summonTime                      =               0,                          -- 召唤时间
    soldierKillNum                  =               0,                          -- 士兵击杀数量
    savageKillNum                   =               0,                          -- 野蛮人击杀数量
    skills                          =               {},                         -- 技能信息
    talentPoint                     =               0,                          -- 天赋点
    talentTrees                     =               {},                         -- 天赋树列表
    talentIndex                     =               1,                          -- 当前天赋页
    head                            =               0,                          -- 头盔位装备索引
    breastPlate                     =               0,                          -- 胸甲位装备索引
    weapon                          =               0,                          -- 武器位装备索引
    gloves                          =               0,                          -- 手套位装备索引
    pants                           =               0,                          -- 裤子位装备索引
    accessories1                    =               0,                          -- 饰品位装备索引
    accessories2                    =               0,                          -- 饰品位装备索引
    shoes                           =               0,                          -- 鞋子位装备索引
    ---------------------------------------以下数据不落地-------------------------
}

---@see 获取统帅默认属性
---@return defaultHeroAttrClass
function HeroDef:getDefaultHeroAttr()
    return const( table.copy( defaultHeroAttr ) )
end

return HeroDef