--[[
 * @file : RallyDef.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-07 18:44:13
 * @Last Modified time: 2020-05-07 18:44:13
 * @department : Arabic Studio
 * @brief : 集结结构定义
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RallyDef = {}

---@class defaultReinforceCityClass
local defaultReinforceCityInfo = {
    reinforceRid            =               0,              -- 增援角色rid
    mainHeroId              =               0,              -- 增援主将ID
    mainHeroLevel           =               0,              -- 增援主将等级
    deputyHeroId            =               0,              -- 增援副将ID
    deputyHeroLevel         =               0,              -- 增援副将等级
    name                    =               "",             -- 角色名称
    headId                  =               0,              -- 角色头像
    headFrameID             =               0,              -- 玩家头像框
    ---@type table<int, defaultSoldierAttrClass>
    soldiers                =               {},             -- 增援士兵信息
    arrivalTime             =               0,              -- 增援到达时间
    armyIndex               =               0,              -- 增援部队索引
    objectIndex             =               0,              -- 增援的对象索引
}

---@class defaultRallyReinforceClass
local defaultRallyReinforce = {
    reinforceRid            =               0,              -- 增援角色rid
    mainHeroId              =               0,              -- 增援主将ID
    mainHeroLevel           =               0,              -- 增援主将等级
    deputyHeroId            =               0,              -- 增援副将ID
    deputyHeroLevel         =               0,              -- 增援副将等级
    ---@type table<int, defaultSoldierAttrClass>
    soldiers                =               {},             -- 增援士兵信息
    arrivalTime             =               0,              -- 增援到达时间
    reinforceTime           =               0,              -- 增援加入时间
    reinforceObjectIndex    =               0,              -- 增援军队地图对象索引
    reinforceArmyIndex      =               0,              -- 增援的部队索引
    reinforceName           =               "",             -- 增援角色名称
    reinforceHeadId         =               0,              -- 增援角色头像ID
    reinforceHeadFrameId    =               0,              -- 增援角色头像框ID
}

---@class defaultJoinRallyClass
local defaultJoinRally = {
    arrivalTime             =               0,              -- 加入集结到达时间
    objectIndex             =               0,              -- 加入集结队伍地图对象索引
    joinTime                =               0,              -- 加入集结时间
}

---@class defaultRallyTargetClass
local defaultRallyTarget = {
    rallyTargetPos          =               {},             -- 被集结目标坐标
    rallyTargetName         =               "",             -- 被集结目标名字
    rallyTargetGuildName    =               "",             -- 被集结目标公会名字
    rallyTargetHeadId       =               0,              -- 被集结目标头像ID
    rallyTargetType         =               0,              -- 被集结目标类型
    rallyTargetMonsterId    =               0,              -- 被集结野蛮人城市ID
    rallyTargetHeadFrameId  =               0,              -- 被集结目标头像框
    rallyTargetHolyLandId   =               0,              -- 被集结的圣地ID
    rallyTargetObjectIndex  =               0,              -- 被集结目标地图对象索引
}

---@class defaultRallyTeamClass
local defaultRallyTeam = {
    rallyRid                =               0,              -- 发起集结角色
    rallyObjectIndex        =               0,              -- 集结队伍地图对象索引
    rallyPath               =               {},             -- 集结部队路径
    rallyMainHeroId         =               0,              -- 主将ID
    rallyDeputyHeroId       =               0,              -- 副将ID
    ---@type table<int, defaultSoldierAttrClass>
    rallySoldiers           =               {},             -- 集结士兵
    rallyStartTime          =               0,              -- 集结发起时间
    rallyReadyTime          =               0,              -- 集结准备结束时间
    rallyWaitTime           =               0,              -- 集结等待结束时间
    rallyMarchTime          =               0,              -- 集结行军结束时间
    rallyTargetIndex        =               0,              -- 集结目标对象
    rallyTargetType         =               0,              -- 集结目标类型
    rallyTargetGuildId      =               0,              -- 集结目标公会
    rallyTargetMonsterId    =               0,              -- 集结目标怪物ID
    ---@type table<int, int>
    rallyArmy               =               {},             -- 集结部队信息
    ---@type table<int, defaultJoinRallyClass>
    rallyWaitArmyInfo       =               {},             -- 等待加入集结队伍信息
    rallyArrivalTarget      =               false,          -- 集结队伍是否达到目标
    ---@type table<int, defaultRallyReinforceClass>
    rallyReinforce          =               {},             -- 集结增援信息
    rallyArmyCountMax       =               0,              -- 集结部队数量上限
    rallyArmyCount          =               0,              -- 集结部队当前数量
    rallyGuildName          =               0,              -- 集结部队公会名字
}

---@class defaultGuildRallyedClass
local defaultGuildRallyed = {
    ---@type table<int, int>
    rally                   =               {},             -- 集结者信息
    ---@type table<int, int>
    reinforce               =               {},             -- 增援者信息
}

---@see 获取集结队伍属性
---@return defaultRallyTeamClass
function RallyDef:getDefaultRallyTeam()
    return const( table.copy( defaultRallyTeam ) )
end

---@see 获取加入集结队伍属性
---@return defaultJoinRallyClass
function RallyDef:getDefaultJoinRally()
    return const( table.copy( defaultJoinRally ) )
end

---@see 获取增援属性
---@return defaultRallyReinforceClass
function RallyDef:getDefaultRallyReinforce()
    return const( table.copy( defaultRallyReinforce ) )
end

---@see 获取目标被集结增援属性
---@return defaultGuildRallyedClass
function RallyDef:getDefaultGuildRallyed()
    return const( table.copy( defaultGuildRallyed ) )
end

---@see 获取被集结目标信息
---@return defaultRallyTargetClass
function RallyDef:getDefaultRallyTarget()
    return const( table.copy( defaultRallyTarget ) )
end

---@see 获取城市增援队伍信息
---@return defaultReinforceCityClass
function RallyDef:getDefaultReinforceCity()
    return const( table.copy( defaultReinforceCityInfo ) )
end

return RallyDef