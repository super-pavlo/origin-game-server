--[[
* @file : EmailEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Jan 07 2020 16:51:05 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 邮件相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 邮件类型
---@class EmailTypeEnumClass
local EmailType = {
    ---@see 系统
    SYSTEM                      =                   1,
    ---@see 报告
    REPORT                      =                   2,
    ---@see 联盟
    GUILD                       =                   3,
    ---@see 个人
    ROLE                        =                   4,
    ---@see 已发送
    SEND                        =                   5,
    ---@see 收藏
    COLLECT                     =                   99,
}
Enum.EmailType = EmailType

---@see 邮件读取状态
---@class EmailStatusEnumClass
local EmailStatus = {
    ---@see 未读
    NO                          =                   0,
    ---@see 已读
    YES                         =                   1,
}
Enum.EmailStatus = EmailStatus

---@see 邮件子类型
---@class EmailSubTypeEnumClass
local EmailSubType = {
    ---@see 资源采集报告
    RESOURCE_COLLECT            =                   1,
    ---@see 战斗报告
    BATTLE_REPORT               =                   2,
    ---@see 探索发现报告
    DISCOVER_REPORT             =                   3,
    ---@see 行动力返还
    ACTIONFORE_RETURN           =                   4,
    ---@see 侦查报告
    SCOUT                       =                   5,
    ---@see 探索山洞报告
    DISCOVER_CAVE               =                   6,
    ---@see 联盟建筑建造邮件
    GUILD_BUILD                 =                   7,
    ---@see 资源援助成功邮件
    RSS_HELP                    =                   8,
    ---@see 被侦查邮件
    SCOUTED                     =                   9,
    ---@see 留言回复邮件
    MESSAGE_REPLY               =                   10,
    ---@see 私人邮件
    PRIVATE                     =                   11,
    ---@see 运营邮件
    OPERATION                   =                   12,
}
Enum.EmailSubType = EmailSubType

---@see 邮件是否自动领取
---@class EmailReceiveAutoEnumClass
local EmailReceiveAuto = {
    ---@see 否
    NO                          =                   0,
    ---@see 是
    YES                         =                   1,
}
Enum.EmailReceiveAuto = EmailReceiveAuto

---@see 联盟邀请邮件回复状态
---@class EmailGuildInviteStatusEnumClass
local EmailGuildInviteStatus = {
    ---@see 未处理
    NO_CLICK                    =                   0,
    ---@see 已同意
    YES                         =                   1,
    ---@see 已拒绝
    NO                          =                   2,
}
Enum.EmailGuildInviteStatus = EmailGuildInviteStatus

---@see 联盟邀请邮件ID
Enum.EmailGuildInviteEmailId = 300007