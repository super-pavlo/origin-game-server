--[[
 * @file : EmailDef.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-28 15:05:39
 * @Last Modified time: 2020-05-28 15:05:39
 * @department : Arabic Studio
 * @brief : 邮件结构枚举
 * Copyright(C) 2019 IGG, All rights reserved
]]

---@class systemEmailInfoClass
local defaultSystemEmailInfo = {
    cn                      =           "",
    en                      =           "",
    arb                     =           "",
    tr                      =           "",
}

---@class systemEmailClass
local defaultSystemEmail = {
    ---@type systemEmailInfoClass
    title                   =           {},             -- 邮件标题
    ---@type systemEmailInfoClass
    subTitle                =           {},             -- 邮件副标题
    ---@type systemEmailInfoClass
    content                 =           {},             -- 邮件内容
    ---@type table<int, defaultItemRewardClass>
    items                   =           {},             -- 附件
    sendTime                =           0,              -- 发送时间
    expriedTime             =           0,              -- 失效时间
}