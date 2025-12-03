--[[
 * @file : EarlyWarningDef.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-13 17:30:53
 * @Last Modified time: 2020-05-13 17:30:53
 * @department : Arabic Studio
 * @brief : 角色预警信息定义
 * Copyright(C) 2019 IGG, All rights reserved
]]

local EarlyWarningDef = {}

---@class defaultEarlyWarningInfoClass
local defaultEarlyWarningInfo = {
    earlyWarningIndex           =           0,      -- 预警消息索引
    earlyWarningType            =           0,      -- 预警类型(1为侦察,2为攻击)
    fromObjectIndex             =           0,      -- 发起方索引
    objectIndex                 =           0,      -- 目标索引
    objectType                  =           0,      -- 预警的对象类型
    scoutFromName               =           "",     -- 侦查者名字
    scoutObjectType             =           0,      -- 侦察目标类型
    arrivalTime                 =           0,      -- 侦察、攻击到达时间
    attackSoldiers              =           {},     -- 攻击部队信息
    isShield                    =           false,  -- 是否屏蔽预警
    mainHeroId                  =           0,      -- 主将ID
    mainHeroLevel               =           0,      -- 主将等级
    deputyHeroId                =           0,      -- 副将ID
    deputyHeroLevel             =           0,      -- 副将等级
    armyIndex                   =           0,      -- 被侦察攻击部队索引
    transportResourceInfo       =           {},     -- 运输资源信息
    transportName               =           "",     -- 运输者名称
    guildAbbr                   =           "",     -- 联盟简称
    holyLandId                  =           0,      -- 圣地ID
    isRally                     =           false,  -- 是否被集结部队攻击
}

---@see 获取角色默认属性
---@return defaultEarlyWarningInfoClass
function EarlyWarningDef:getDefaultEarlyWarningInfo()
    return const( table.copy( defaultEarlyWarningInfo ) )
end

return EarlyWarningDef