--[[
 * @file : RoleEnum.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2019-12-06 17:50:35
 * @Last Modified time: 2019-12-06 17:50:35
 * @department : Arabic Studio
 * @brief : 角色相关枚举
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 角色类型
---@class RoleTypeEnumClass
local RoleType = {
    ---@see 角色
    ROLE                    =                   0,
    ---@see 军队
    ARMY                    =                   1,
    ---@see 怪物
    MONSTER                 =                   2,
    ---@see 城市
    CITY                    =                   3,
    ---@see 石料
    STONE                   =                   4,
    ---@see 农田
    FARMLAND                =                   5,
    ---@see 木材
    WOOD                    =                   6,
    ---@see 金矿
    GOLD                    =                   7,
    ---@see 宝石
    DENAR                   =                   8,
    ---@see 斥候
    SCOUTS                  =                   9,
    ---@see 村庄
    VILLAGE                 =                   10,
    ---@see 山洞
    CAVE                    =                   11,
    ---@see 联盟中心要塞
    GUILD_CENTER_FORTRESS   =                   12,
    ---@see 联盟要塞1
    GUILD_FORTRESS_FIRST    =                   13,
    ---@see 联盟要塞2
    GUILD_FORTRESS_SECOND   =                   14,
    ---@see 联盟旗帜
    GUILD_FLAG              =                   15,
    ---@see 联盟农田
    GUILD_FOOD              =                   16,
    ---@see 联盟伐木场
    GUILD_WOOD              =                   17,
    ---@see 联盟石矿床
    GUILD_STONE             =                   18,
    ---@see 联盟金矿床
    GUILD_GOLD              =                   19,
    ---@see 联盟谷仓
    GUILD_FOOD_CENTER       =                   20,
    ---@see 联盟木料场
    GUILD_WOOD_CENTER       =                   21,
    ---@see 联盟石材厂
    GUILD_STONE_CENTER      =                   22,
    ---@see 联盟铸币场
    GUILD_GOLD_CENTER       =                   23,
    ---@see 符文
    RUNE                    =                   24,
    ---@see 关卡
    CHECKPOINT              =                   25,
    ---@see 圣地
    RELIC                   =                   26,
    ---@see 运输车
    TRANSPORT               =                   27,
    ---@see 野蛮人城寨
    MONSTER_CITY            =                   28,
    ---@see 圣地守护者
    GUARD_HOLY_LAND         =                   29,
    ---@see 远征对象
    EXPEDITION              =                   30,
    ---@see 圣所
    SANCTUARY               =                   31,
    ---@see 圣坛
    ALTAR                   =                   32,
    ---@see 圣祠
    SHRINE                  =                   33,
    ---@see 失落神庙
    LOST_TEMPLE             =                   34,
    ---@see 等级1关卡
    CHECKPOINT_1            =                   35,
    ---@see 等级2关卡
    CHECKPOINT_2            =                   36,
    ---@see 等级3关卡
    CHECKPOINT_3            =                   37,
    ---@see 圣所战斗.PVP
    SANCTUARY_PVP           =                   38,
    ---@see 圣坛战斗.PVP
    ALTAR_PVP               =                   39,
    ---@see 圣祠战斗.PVP
    SHRINE_PVP              =                   40,
    ---@see 失落神庙.PVP
    LOST_TEMPLE_PVP         =                   41,
    ---@see 会巡逻的召唤类型单人挑战怪物
    SUMMON_SINGLE_MONSTER   =                   42,
    ---@see 会巡逻的召唤类型集结挑战怪物
    SUMMON_RALLY_MONSTER    =                   43,
}
Enum.RoleType = RoleType

---@see 角色统计信息类型
---@class RoleStatisticsTypeEnumClass
local RoleStatisticsType = {
    ---@see 战斗胜利次数
    BATTLE_SUCCES           =                   1,
    ---@see 战斗失败次数
    BATTLE_FAIL             =                   2,
    ---@see 阵亡士兵数
    DEAD_SOLDIER            =                   3,
    ---@see 侦查次数
    SCOUT                   =                   4,
    ---@see 资源采集总量
    RESOURCE_COLLECT        =                   5,
    ---@see 资源援助总量
    RESOURCE_ASSIST         =                   6,
    ---@see 联盟帮助次数
    GUILD_HELP              =                   7,
}
Enum.RoleStatisticsType = RoleStatisticsType

---@see 城市buff类型
---@class RoleCityBuffEnumClass
local RoleCityBuff = {
    ---@see 增加属性
    ATTR                    =                   0,
    ---@see 战争狂热
    WAR_CARZY               =                   1,
    ---@see 护盾
    SHIELD                  =                   2,
    ---@see 反侦察
    ANTI_SCOUT              =                   3,
    ---@see 疑兵
    SUSPECT                 =                   4,
}
Enum.RoleCityBuff = RoleCityBuff

---@see buff能否共存
---@class RoleCityBuffCoexistEnumClass
local RoleCityBuffCoexist = {
    YES                     =                   0,
    NO                      =                   1,
}
Enum.RoleCityBuffCoexist = RoleCityBuffCoexist

---@see 玩家头像
---@class RoleHeadTypeEnumClass
local RoleHeadType = {
    HEAD                    =                   1,
    HEAD_FRAME              =                   2,
}
Enum.RoleHeadType = RoleHeadType

---@see 玩家头像以及头像框获取途径
---@class RoleHeadGetWayEnumClass
local RoleHeadGetWay = {
    SYSTEM                  =                   1,
    NO_SYSTEM               =                   2,
}
Enum.RoleHeadGetWay = RoleHeadGetWay

---@see 资源获取方式
---@class RoleResourcesActionEnumClass
local RoleResourcesAction = {
    ---@see 正常收取资源
    REWARD                  =                   1,
    ---@see 侦查
    SCOUT                   =                   2,
    ---@see 掠夺
    PLUNDER                 =                   3,
}
Enum.RoleResourcesAction = RoleResourcesAction

---@see 远征商店类型
---@class ExpeditionTypeEnumClass
local ExpeditionType = {
    ---@see 头像
    HEAD                    =                   1,
    ---@see 道具
    ITEM                    =                   2,
}
Enum.ExpeditionType = ExpeditionType

---@see 角色通知类型
---@class RoleNotifyTypeEnumClass
local RoleNotifyType = {
    ---@see 采集符文完成通知
    RUNE_COLLECT_FINISH     =                   1,
    ---@see 耐久为0迁城通知
    WALL_HP_MOVE_CITY       =                   2,
    ---@see 触发战损补偿通知
    BATTLE_LOSE             =                   3,
}
Enum.RoleNotifyType = RoleNotifyType

---@see 战斗预警类型
---@class EarlyWarningTypeEnumClass
local EarlyWarningType = {
    ---@see 侦察
    SCOUT                   =                   1,
    ---@see 攻击
    ATTACK                  =                   2,
    ---@see 增援
    REINFORCE               =                   3,
    ---@see 运输
    TRANSPORT               =                   4,
}
Enum.EarlyWarningType = EarlyWarningType

---@see 时代类型
---@class RoleAgeEnumClass
local RoleAge = {
    ---@see 原始时代
    ORIGINAL                =                   1,
    ---@see 古典时代
    CLASSICAL               =                   2,
    ---@see 黑暗时代
    DARK                    =                   3,
    ---@see 封建时代
    FEUDAL                  =                   4,
    ---@see 工业时代
    INDUSTRY                =                   5,
    ---@see 现代
    MODERN                  =                   6,
}
Enum.RoleAge = RoleAge

---@see 角色战力变化类型
---@class RoleCombatPowerTypeEnumClass
local RoleCombatPowerType = {
    VILLAGE                 =                   1,
}
Enum.RoleCombatPowerType = RoleCombatPowerType

---@see 角色地图建筑关注类型
---@class RoleBuildFocusTypeEnumClass
local RoleBuildFocusType = {
    ---@see 联盟建筑
    GUILD_BUILD             =                   1,
    ---@see 圣地关卡
    HOLY_LAND               =                   2,
}
Enum.RoleBuildFocusType = RoleBuildFocusType

---@see 角色离线未完成引导是否回收城堡
---@class RoleNewCityHideEnumClass
local RoleNewCityHide = {
    ---@see 回收
    YES                     =                   0,
    ---@see 不回收
    NO                      =                   1,
}
Enum.RoleNewCityHide = RoleNewCityHide

---@see 资源阈值类型
---@class ResourceLimitTypeClass
local ResourceLimitType ={
    ---@see 粮食
    FOOD                    =                   100,
    ---@see 木材
    WOOD                    =                   101,
    ---@see 石头
    STONE                   =                   102,
    ---@see 金币
    GOLD                    =                   103,
    ---@see 钻石
    DENAR                   =                   104,
}
Enum.ResourceLimitType = ResourceLimitType