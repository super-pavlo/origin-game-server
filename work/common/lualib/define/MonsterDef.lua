--[[
* @file : MonsterDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri Apr 24 2020 14:24:44 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 怪物属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local MonsterDef = {}

---@class defaultMonsterAttrClass
local defaultMonsterAttr = {
    monsterId                   =               0,                          -- c_map_object表ID
    zoneIndex                   =               0,                          -- 瓦片索引
    monsterTypeId               =               0,                          -- 怪物类型ID,s_Monster表ID
    refreshTime                 =               0,                          -- 怪物刷新时间
    pos                         =               {},                         -- 怪物坐标
    attackRoleNum               =               0,                          -- 攻击该目标的角色数量
}

---@see 获取怪物默认属性
---@return defaultMonsterAttrClass
function MonsterDef:getDefaultMonsterAttr()
    return const( table.copy( defaultMonsterAttr ) )
end

return MonsterDef