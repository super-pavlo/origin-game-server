--[[
* @file : ItemDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Dec 24 2019 10:56:37 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定义道具相关属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local ItemDef = {}

---@class defaultItemAttrClass
local defaultItemAttr = {
    itemIndex               =           0,                  -- 道具(装备)索引
    uniqueIndex             =           0,                  -- 唯一索引
    itemId                  =           0,                  -- 道具ID
    overlay                 =           0,                  -- 叠加数量
    exclusive               =           0,                  -- 专属
    heroId                  =           0,                  -- 英雄id
    ---------------------------------------以下数据不落地-------------------------
}

---@class defaultItemRewardClass
local defaultItemReward = {
    itemId                  =           0,                  -- 道具ID
    itemNum                 =           0,                  -- 道具数量
}

---@see 获取道具默认属性
---@return defaultItemAttrClass
function ItemDef:getDefaultItemAttr()
    return const( table.copy( defaultItemAttr ) )
end

return ItemDef