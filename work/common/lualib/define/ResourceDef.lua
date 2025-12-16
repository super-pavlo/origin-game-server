--[[
* @file : ResourceDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri Apr 24 2020 14:05:02 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 资源点信息属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local ResourceDef = {}

---@class defaultResourceAttrClass
local defaultResourceAttr = {
    resourceId                  =               0,                          -- c_map_object表ID
    zoneIndex                   =               0,                          -- 瓦片索引
    resourceTypeId              =               0,                          -- 资源类型ID,s_ResourceGatherType表ID
    refreshTime                 =               0,                          -- 资源点刷新时间
    pos                         =               {},                         -- 资源点坐标
    collectRid                  =               0,                          -- 采集角色ID
    collectSpeed                =               0,                          -- 采集速度
    collectTime                 =               0,                          -- 开始采集时间
    armyIndex                   =               0,                          -- 部队索引
    timerId                     =               0,                          -- 定时器ID
    resourceAmount              =               0,                          -- 资源点资源量
    territoryId                 =               0,                          -- 领土ID
}

---@see 获取资源默认属性
---@return defaultResourceAttrClass
function ResourceDef:getDefaultResourceAttr()
    return const( table.copy( defaultResourceAttr ) )
end

return ResourceDef