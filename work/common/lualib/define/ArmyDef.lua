--[[
* @file : ArmyDef.lua
* @type : lua lib
* @author : dingyuchao
* @created : Mon Mar 23 2020 11:28:54 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 部队属性定义
* Copyright(C) 2017 IGG, All rights reserved
]]

local ArmyDef = {}

---@class defaultSoldierAttrClass
local defaultSoldierAttr = {
    id                              =                   0,                          -- type*100+level
    type                            =                   0,                          -- 士兵类型
    level                           =                   0,                          -- 士兵等级
    num                             =                   0,                          -- 士兵数量
    minor                           =                   0,                          -- 轻伤数量
}

---@class defaultArmyAttrClass
local defaultArmyAttr = {
    armyIndex                       =                   0,                          -- 军队索引
    mainHeroId                      =                   0,                          -- 主将ID, 0为解散军队
    deputyHeroId                    =                   0,                          -- 副将ID, 0或空为无副将
    ---@type table<int, defaultSoldierAttrClass>
    soldiers                        =                   {},                         -- 士兵信息
    resourceLoads                   =                   {},                         -- 资源负载信息
    status                          =                   0,                          -- 军队状态
    collectResource                 =                   {},                         -- 军队当前正在采集的资源信息
    preCostActionForce              =                   0,                          -- 预扣除行动力
    arrivalTime                     =                   0,                          -- 到达时间
    path                            =                   {},                         -- 路径
    targetType                      =                   0,                          -- 目的地类型
    targetArg                       =                   {},                         -- 行军目标参数
    minorSoldiers                   =                   {},                         -- 轻伤士兵信息
    mainHeroLevel                   =                   0,                          -- 主将等级
    deputyHeroLevel                 =                   0,                          -- 副将等级
    startTime                       =                   0,                          -- 行军开始时间
    guildBuildPoint                 =                   0,                          -- 联盟建筑获得的个人积分
    guildBuildTime                  =                   0,                          -- 参与联盟建筑建造时间
    armyCountMax                    =                   0,                          -- 部队最大部队数量
    ---------------------------------------以下数据不落地-------------------------
    buildArmyIndex                  =                   0,                          -- 建筑部队索引
    isInRally                       =                   false,                      -- 是否在集结部队中
    battleBuff                      =                   {},                         -- 部队buff
    outBuild                        =                   false,                      -- 部队是否出建筑
    killMonsterReduceVit            =                   0,                          -- 野蛮人扫荡BUFF层数
}

---@class defaultArmyWalkClass
local defaultArmyWalk = {
    path                            =                   {},                         -- 路径
    next                            =                   {},                         -- 下一个坐标
    now                             =                   {},                         -- 当前坐标
    speed                           =                   {},                         -- 速度(向量)
    rawSpeed                        =                   0,                          -- 原始速度(标量)
    angle                           =                   0,                          -- 角度
    marchType                       =                   0,                          -- 行军类型
    rid                             =                   0,                          -- 角色rid
    armyIndex                       =                   0,                          -- 部队索引
    objectIndex                     =                   0,                          -- 对象索引
    targetObjectIndex               =                   0,                          -- 目标索引
    objectType                      =                   0,                          -- 对象类型
    arrivalTime                     =                   0,                          -- 达到时间
    arrivalTimeMillisecond          =                   0,                          -- 达到时间毫秒
    allDesenFog                     =                   {},                         -- 迷雾
    allDesenFogPos                  =                   {},                         -- 迷雾位置
    mapIndex                        =                   0,                          -- 地图索引(远征使用)
    lastTick                        =                   0,                          -- 最后移动(毫秒)
    passPosInfo                     =                   {},                         -- 关卡坐标列表
    isRallyArmy                     =                   false,                      -- 是否是集结部队
    denseFogOpenFlag                =                   false,                      -- 迷雾是否全开
}

---@see 向目标行军部队信息
---@class defaultArmyMarchClass
local defaultArmyMarchInfo = {
    path                            =                   {},                         -- 路径信息
    rid                             =                   0,                          -- 角色rid
    objectIndex                     =                   0,                          -- 对象索引
    guildId                         =                   0,                          -- 联盟ID
}

---@see 获取部队默认属性
---@return defaultArmyAttrClass
function ArmyDef:getDefaultArmyAttr()
    return const( table.copy( defaultArmyAttr ) )
end

---@see 获取向目标行军部队信息
---@return defaultArmyMarchClass
function ArmyDef:getDefaultArmyMarchInfo()
    return const( table.copy( defaultArmyMarchInfo ) )
end

---@see 获取行军参数结构
---@return defaultArmyWalkClass
function ArmyDef:getDefaultArmyWalk()
    return const( table.copy( defaultArmyWalk ) )
end

return ArmyDef