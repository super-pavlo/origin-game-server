--[[
* @file : OtherEnum.lua
* @type : lualib
* @author : chenlei
* @created : Thu Jan 02 2020 10:40:29 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 其他公共枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see s_ZeroEmpty表索引枚举值
---@class ZeroEmptyTypeEnumClass
local ZeroEmptyType = {
    ---@see 兵种解锁信息
    ARMY_STUDY              =           1,
    ---@see 科技信息
    STUDY                   =           2,
    ---@see 兵种信息表
    ARMY                    =           3,
    ---@see 章节任务
    CHAPTER_TASK            =           4,
    ---@see 野蛮人刷新
    BARBARIAN_REFRESH       =           5,
    ---@see 村庄山洞迷雾区域信息
    VILLAGE_CAVE            =           6,
    ---@see 道具子类型
    SUB_ITEM_TYPE           =           7,
    ---@see 每日任务
    DAILY_TASK              =           8,
    ---@see 英雄技能解锁
    HERO_SKILL_OPEN         =           9,
    ---@see 通用活动目标表
    ACTIVITY_TRAGET_TYPE    =           10,
    ---@see 通用活动掉落表
    ACTIVITY_DROP_TYPE      =           11,
    ---@see 通用兑换活动
    ACTIVITY_EXCHANGE_TYPE  =           12,
    ---@see 开服活动
    ACTIVITY_DAYS_TYPE      =           13,
    ---@see 神秘商人
    MYSTERY_STORE           =           14,
    ---@see 最强执政官
    ACTIVITY_KILL           =           15,
    ---@see 最强执政官阶段信息
    ACTIVITY_KILL_STAGE     =           16,
    ---@see 最强执政官进度
    ACTIVITY_KILL_INT       =           17,
    ---@see 超值礼包
    RECHARGE_SALE           =           18,
    ---@see 远征商店
    EXPEDITION_STORE        =           19,
    ---@see 野蛮人城寨纪念碑事件
    MONSTER_CITY_STONE      =           20,
    ---@see 野蛮人城寨刷新事件
    MONSTER_CITY_REFRESH    =           21,
    ---@see 野蛮人最大独占区域半径
    MONSTER_MAX_RADIUS      =           22,
    ---@see 野蛮人城寨最大独占区域半径
    MONSTER_CITY_MAX_RADIUS =           23,
    ---@see 锻造材料分组
    MATERIAL                =           24,
    ---@see 图纸表
    DRAW                    =           25,
    ---@see 圣地迷雾区域信息
    HOLY_LAND_DENSEFOG      =           26,
    ---@see 圣地纪念碑事件
    HOLY_LAND_STORE         =           27,
    ---@see 守护者分组坐标信息
    GUARD_GROUP_POINT       =           28,
    ---@see 统帅天赋树
    TALENT                  =           29,
    ---@see 统帅等级天赋点
    HERO_LEVEL_TALENT       =           30,
    ---@see 统帅星级天赋点
    HERO_STAR_TALENT        =           31,
    ---@see 远征表
    EXPEDITION              =           32,
    ---@see 商品表
    PRICE                   =           33,
    ---@see 关卡寻路地图坐标
    CHECK_POINT_POS         =           34,
    ---@see 资源信息
    RESOURCE_TYPE           =           35,
    ---@see 最大引导步骤
    MAX_GUIDE_STAGE         =           36,
    ---@see 关卡坐标点映射
    HOLD_POS                =           37,
    ---@see 超值礼包
    SALEPRICE               =           38,
    ---@see 活动天数表
    ACTIVITY_DAYS           =           39,
    ---@see 纪念碑修正
    FIX_TIME                =           40,
}
Enum.ZeroEmptyType = ZeroEmptyType

---@see 货币类型
---@class CurrencyTypeEnumClass
local CurrencyType = {
    ---@see 粮食
    food                =           100,
    ---@see 木材
    wood                =           101,
    ---@see 石料
    stone               =           102,
    ---@see 金币
    gold                =           103,
    ---@see 宝石
    denar               =           104,
    ---@see 行动力
    actionForce         =           105,
    ---@see 联盟个人积分
    individualPoints    =           106,
    ---@see 联盟积分
    leaguePoints        =           107,
    ---@see 联盟食物
    allianceFood        =           108,
    ---@see 联盟木材
    allianceWood        =           109,
    ---@see 联盟石料
    allianceStone       =           110,
    ---@see 联盟金币
    allianceGold        =           111,
    ---@see vip点数
    vip                 =           112,
    ---@see 远征币
    expeditionCoin      =           116,
    ---@see 新手活动活跃度
    activityActivePoint =           118,
}
Enum.CurrencyType = CurrencyType

---@see c_refresh表id值
---@class RefreshTypeEnumClass
local RefreshType = {
    ---@see 资源
    RESOURCE            =           1,
    ---@see 野蛮人
    SAVAGE              =           2,
    ---@see 野蛮人城寨
    MONSTER_CITY        =           3,
}
Enum.RefreshType = RefreshType

---@see 推送分组
---@class PushGroupEnumClass
local PushGroup = {
    ---@see 升级与训练推送
    LEVEL_TRAIN         =           1,
    ---@see 战斗通知
    BATTLE              =           2,
    ---@see 个人邮件
    PERSON              =           3,
    ---@see 联盟邮件
    ALLIANCE            =           4,
    ---@see 活动开启
    ACITVITY            =           5,
}
Enum.PushGroup = PushGroup

---@see 推送状态
---@class PushStatusEnumClass
local PushStatus = {
    ---@see 关闭
    CLOSE               =           0,
    ---@see 开启
    OPEN                =           1,
}
Enum.PushStatus = PushStatus

---@see 推送类型
---@class PushTypeEnumClass
local PushType = {
    ---@see 建筑升级
    BUILD               =           1001,
    ---@see 训练完成
    TARIN               =           1002,
    ---@see 科技完成
    TECH                =           1003,
    ---@see 受到侦查
    SCOUT               =           2001,
    ---@see 城市受到攻击
    CITY_ATTACK         =           2002,
    ---@see 个人邮件
    PERSON_MAIL         =           3001,
    ---@see 联盟聊天
    ALLIANCE_CHAT       =           7001,
    ---@see 玩家部队返回城市中时推送给玩家
    ARMY_RETURN         =           8001,
    ---@see 联盟玩法发起集结时推送给其他联盟成员
    RALLY               =           10001,
}
Enum.PushType = PushType

---@see 推送开关状态
---@class PushOpenEnumClass
local PushOpen = {
    ---@see 开启
    OPEN                =           1,
    ---@see 关闭
    CLOSE               =           0,
}
Enum.PushOpen = PushOpen