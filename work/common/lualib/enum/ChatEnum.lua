--[[
 * @file : ChatEnum.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-10 15:39:54
 * @Last Modified time: 2020-04-10 15:39:54
 * @department : Arabic Studio
 * @brief : 聊天枚举
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 聊天频道类型
---@class ChatChannelEnumClass
local ChatChannel = {
    ---@see 世界频道
    WORLD               =               1,
    ---@see 联盟频道
    GUILD               =               2,
    ---@see 好友私聊
    PRIVATE             =               100,
    ---@see 群聊
    GROUP               =               101,
    ---@see 跑马灯
    SYSTEM              =               102,
}
Enum.ChatChannel = ChatChannel