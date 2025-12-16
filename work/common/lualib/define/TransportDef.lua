--[[
* @file : TransportDef.lua
* @type : lua lib
* @author : chenlei
* @created : Fri May 08 2020 14:41:18 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 运输车属性定义
* Copyright(C) 2017 IGG, All rights reserved
]]

local TransportDef = {}

---@class defaultTransportAttrClass
local defaultTransportAttr = {
    transportIndex              =           0,                      -- 部队索引
    transportResourceInfo       =           {},                     -- 运输资源信息
    allResourceInfo             =           {},                     -- 军队当前正在采集的资源信息
    arrivalTime                 =           0,                      -- 到达时间
    path                        =           {},                     -- 路径
    startTime                   =           0,                      -- 出发时间
    objectIndex                 =           0,                      -- 地图对象索引
    targetPos                   =           {},                     -- 坐标
    targetObjectIndex           =           0,                      -- 目标索引ID
    targetName                  =           "",                     -- 目标名称
    TransportStatus             =           0,                      -- 状态
    targetRid                   =           0,                      -- 目标rid
    transportStatus             =           0,
    ---------------------------------------以下数据不落地-------------------------
}

---@see 获取部队默认属性
---@return defaultArmyAttrClass
function TransportDef:getDefaultTransportAttr()
    return const( table.copy( defaultTransportAttr ) )
end

return TransportDef