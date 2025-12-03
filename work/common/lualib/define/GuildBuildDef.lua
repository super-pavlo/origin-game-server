--[[
* @file : GuildBuildDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Mon Apr 20 2020 11:20:31 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定义联盟建筑相关属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildBuildDef = {}

---@class defaultGuildBuildAttrClass
local defaultGuildBuildAttr = {
    buildIndex                  =       0,                          -- 建筑索引
    type                        =       0,                          -- 建筑类型
    pos                         =       0,                          -- 坐标
    status                      =       0,                          -- 状态
    durable                     =       0,                          -- 耐久度
    durableLimit                =       0,                          -- 耐久上限
    resourceCenter              =       {},                         -- 联盟资源中心信息
    memberRid                   =       0,                          -- 创建者角色ID
    buildRateInfo               =       {},                         -- 建造进度信息
    reinforces                  =       {},                         -- 建筑部队增援信息
    buildBurnInfo               =       {},                         -- 联盟建筑燃烧信息
    createTime                  =       0,                          -- 联盟建筑创建时间
    consumeCurrencies           =       {},                         -- 建造消耗货币信息
    attackGuild                 =       {},                         -- 攻击角色的联盟信息
}

---@see 获取联盟默认属性
---@return defaultGuildBuildAttrClass
function GuildBuildDef:getDefaultGuildBuildAttr()
    return const( table.copy( defaultGuildBuildAttr ) )
end

return GuildBuildDef