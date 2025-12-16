--[[
 * @file : RallyEnum.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-09 17:56:09
 * @Last Modified time: 2020-05-09 17:56:09
 * @department : Arabic Studio
 * @brief : 集结枚举定义
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 集结类型
---@class RallyTypeEnumClass
local RallyType = {
    ---@see 普通集结
    NORMAL              =           1,
}
Enum.RallyType = RallyType