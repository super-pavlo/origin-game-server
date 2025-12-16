--[[
* @file : HolyLandDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri May 15 2020 13:23:36 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定义圣地相关属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local HolyLandDef = {}

---@class defaultHolyLandAttrClass
local defaultHolyLandAttr = {
    holyLandId                  =               0,                          -- 圣地ID
    pos                         =               {},                         -- 坐标
    status                      =               0,                          -- 圣地状态
    finishTime                  =               0,                          -- 状态结束时间
    guildId                     =               0,                          -- 占领圣地的联盟ID
    valid                       =               false,                      -- 是否为有效地块
    reinforces                  =               {},                         -- 圣地关卡增援信息
    ---------------------------------------以下数据不落地-------------------------

}

---@see 获取圣地默认属性
---@return defaultHolyLandAttrClass
function HolyLandDef:getDefaultHolyLandAttr()
    return const( table.copy( defaultHolyLandAttr ) )
end

return HolyLandDef