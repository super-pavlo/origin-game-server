--[[
* @file : MonsterCityDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Wed May 13 2020 09:25:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 野蛮人城寨属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local MonsterCityDef = {}

---@class defaultMonsterCityAttrClass
local defaultMonsterCityAttr = {
    objectId                    =                   0,                          -- c_map_object表ID
    zoneIndex                   =                   0,                          -- 瓦片区域索引
    pos                         =                   {},                         -- 坐标
    monsterId                   =                   0,                          -- s_Monster表ID
    refreshTime                 =                   0,                          -- 野蛮人城寨刷新出来的时间
    attackArmyNum               =                   0,                          -- 正在攻击的集结部队数
}

---@see 获取野蛮人城寨默认属性
---@return defaultMonsterCityAttr
function MonsterCityDef:getDefaultMonsterAttr()
    return const( table.copy( defaultMonsterCityAttr ) )
end

return MonsterCityDef
