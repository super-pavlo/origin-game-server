--[[
* @file : ActivityEnum.lua
* @type : lualib
* @author : chenlei
* @created : Tue Apr 07 2020 14:04:39 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 活动枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 活动统计参数默认值
Enum.ActivityArgDefault = 0

---@see 活动时间类型
---@class ActivityTimeTypeEnumClass
local ActivityTimeType = {
    ---@see 开服时间
    OPEN_SERVER         =           1,
    ---@see 自然天数
    NORMAL              =           2,
    ---@see 周固定时间开启
    WEEK                =           3,
    ---@see 永久存在
    FOREVER             =           4,
    ---@see 单周
    ODD_WEEK            =           6,
    ---@see 双周
    EVEN_WEEK           =           7,
    ---@see 根据前置活动时间来开启
    PRE_ACTIVITY        =           8,
    ---@see 创角时间
    CREATE_TIME         =           9,
}
Enum.ActivityTimeType = ActivityTimeType

---@see 活动类型
local ActivityType = {
    ---@see 开服活动
    SERVER_OPEN         =           100,
    ---@see 领取宝箱
    GET_BOX             =           101,
    ---@see 通用兑换活动
    EXCHANGE            =           200,
    ---@see 最强执政官预告
    MEG_NOTICE          =           300,
    ---@see 最强执政官活动
    MEG_MAIN            =           301,
    ---@see 最强执政官结束展示
    MEG_END_SHOW        =           302,
    ---@see 基础达标活动
    BASIC_TARGER        =           400,
    ---@see 每日重置达标类型
    DAY_RESET           =           401,
    ---@see 达标.排行
    TARGER_RANK         =           402,
    ---@see 达标.排行
    TARGER_RANK_END     =           403,
    ---@see 额外掉落
    DROP                =           500,
    ---@see 额外掉落加排行
    DROP_RANK           =           501,
    ---@see 额外掉落展示
    DROP_RANK_END       =           502,
    ---@see 转盘活动
    TURN_TABLE          =           600,
    ---@see 地狱活动
    HELL                =           800,
    ---@see 洛哈的试炼
    LUOHA               =           700,
    ---@see 战斗的号角
    FIGHT_HORN          =           303,
    ---@see 战斗的号角结束展示
    FIGHT_HORN_SHOW     =           304,
    ---@see 部落之王
    TRIBE_KING          =           305,
    ---@see 部落之王结束展示
    TRIBE_KING_SHOW     =           306,
    ---@see 新手活动
    NEW_ACTIVITY        =           1000,
}
Enum.ActivityType = ActivityType

---@see 活动是否循环
---@class ActivityCirculationEnumClass
local ActivityCirculation = {
    ---@see 不循环
    NO                  =           0,
    ---@see 循环
    YES                 =           1,
}
Enum.ActivityCirculation = ActivityCirculation

---@see 开服是否隐藏
---@class OpenServiceConcealEnumClass
local OpenServiceConceal = {
    ---@see 不隐藏
    NO                  =           0,
    ---@see 隐藏
    YES                 =           1,
}
Enum.OpenServiceConceal = OpenServiceConceal

---@see 达标自动发奖类型
---@class OpenServiceConcealEnumClass
local AutoRewardType = {
    ---@see 个人
    PERSON              =           1,
    ---@see 联盟
    ALLIANCE            =           2,
}
Enum.AutoRewardType = AutoRewardType

---@see 活动行为类型
---@class ActivityActionTypeEnumClass
local ActivityActionType = {
    ---@see 累计登陆天
    LOGIN_DAY                   =           1001,
    ---@see 在地图上探索个迷雾块
    SCOUT_MIST                  =           2001,
    ---@see 领取次部落村庄的奖励
    VILLAGE_REWARD              =           2002,
    ---@see 领取神秘山洞奖励
    CAVE_REWARD                 =           2003,
    ---@see 打开黄金宝箱
    GOLD_BOX                    =           3001,
    ---@see 完成科技研究
    TECHNOLOGY_RESEARCH         =           3002,
    ---@see 驿站购买行为触发.指进行过这个行为
    POST_BUY_ACTION             =           3003,
    ---@see 在驿站购买次道具.具体次数
    POST_BUY_COUNT              =           3004,
    ---@see 部队训练行为触发.指进行过这个行为
    TARIN_ACTION                =           4001,
    ---@see 训练个一级单位.具体数量
    TRAIN_LEVEL1_COUNT          =           4002,
    ---@see 训练个二级单位.具体数量
    TRAIN_LEVEL2_COUNT          =           4003,
    ---@see 训练个三级单位.具体数量
    TRAIN_LEVEL3_COUNT          =           4004,
    ---@see 训练个四级单位.具体数量
    TRAIN_LEVEL4_COUNT          =           4005,
    ---@see 训练个五级单位.具体数量
    TRAIN_LEVEL5_COUNT          =           4006,
    ---@see 训练个任意步兵单位.具体数量
    TRAIN_INFANTRY              =           4007,
    ---@see 训练个任意骑兵单位.具体数量
    TRAIN_CAVALRY               =           4008,
    ---@see 训练个任意弓兵单位.具体数量
    TRAIN_ARCHER                =           4009,
    ---@see 训练个任意攻城单位.具体数量
    TRAIN_SIEGE_UNIT            =           4010,
    ---@see 训练个任意单位.具体数量
    TRAIN_ALL                   =           4011,
    ---@see 训练个等级及以上的步兵单位.具体数量.兵种等级
    TRAIN_LEVEL_INFANTRY        =           4012,
    ---@see 训练个等级及以上的骑兵单位.具体数量.兵种等级
    TRAIN_LEVEL_CAVALRY         =           4013,
    ---@see 训练个等级及以上的弓兵单位.具体数量.兵种等级
    TRAIN_LEVEL_ARCHER          =           4014,
    ---@see 训练个等级及以上的攻城单位.具体数量.兵种等级
    TRAIN_LEVEL_SIEGE_UNIT      =           4015,
    ---@see 训练个等级及以上的任意单位.具体数量.兵种等级
    TRAIN_LEVEL_ALL             =           4016,
    ---@see 建造个数.建筑类型.读取s_BuildingTypeConfig.type
    BUILD_COUNT                 =           5001,
    ---@see 将升至等级.建筑类型.等级
    BUILD_TO_LEVEL              =           5002,
    ---@see 将个升级至等级
    BUILD_TO_LEVEL_COUNT        =           5003,
    ---@see 将任意资源建筑升至等级
    RES_BUILD_LEVEL             =           5004,
    ---@see 将任意部队训练建筑升至等级
    TRAIN_BUILD_LEVEL           =           5005,
    ---@see 升级次
    BUILD_LEVEL_COUNT           =           5006,
    ---@see 升级多少次建筑
    BUILE_LEVEL                 =           5007,
    ---@see 资源采集行为触发
    COLLECTION_RES_ACTION       =           6001,
    ---@see 采集食物采集任意等级的食物资源田都符合要求
    COLLECTION_FOOD_COUNT       =           6002,
    ---@see 采集木材采集任意等级的木材资源田都符合要求
    COLLECTION_WOOD_COUNT       =           6003,
    ---@see 采集石料采集任意等级的石料资源田都符合要求
    COLLECTION_STONE_COUNT      =           6004,
    ---@see 采集金币采集任意等级的金币资源田都符合要求
    COLLECTION_GOLD_COUNT       =           6005,
    ---@see 采集宝石采集任意等级的宝石资源田都符合要求
    COLLECTION_DENAR_COUNT      =           6006,
    ---@see 在地图上总共采集资源.具体数量
    COLLECTION_ALL_NUM          =           6007,
    ---@see 在地图上总共采集食物.具体数量
    COLLECTION_FOOD_NUM         =           6008,
    ---@see 在地图上总共采集石料.具体数量
    COLLECTION_STONE_NUM        =           6009,
    ---@see 在地图上总共采集木材.具体数量
    COLLECTION_WOOD_NUM         =           6010,
    ---@see 在地图上总共采集金币.具体数量
    COLLECTION_GOLD_NUM         =           6011,
    ---@see 在地图上总共采集宝石.具体数量
    COLLECTION_DENAR_NUM        =           6012,
    ---@see 在地图上进行次采集.具体数量
    COLLECTION_RES_COUNT        =           6013,
    ---@see 联盟帮助行为触发
    ALLIANCE_HELP_ACTION        =           7001,
    ---@see 帮助盟友次
    ALLIANCE_HELP_COUNT         =           7002,
    ---@see 在联盟中进行次科技捐献
    ALLIANCE_TECH_DONATE        =           7003,
    ---@see 领取次联盟礼物
    ALLIANCE_GET_GIFT           =           7004,
    ---@see 加入联盟
    JOIN_ALLIANCE               =           7006,
    ---@see 建筑战力提升
    BUILD_POWER_UP              =           8001,
    ---@see 科研战力提升
    TECH_POWER_UP               =           8002,
    ---@see 部队战力提升
    ARMY_POWER_UP               =           8003,
    ---@see 通过建造.科研和训练提升战力
    ALL_POWER_UP                =           8004,
    ---@see 战力提升
    POWER_UP_ACTION             =           8005,
    ---@see 战力提升包括统帅
    POWER_UP                    =           8006,
    ---@see 击败野蛮人行为触发
    KILL_BARB_ACTION            =           9001,
    ---@see 击败野蛮人城寨行为触发
    KILL_BARB_WALL_ACTION       =           9002,
    ---@see 击败次野蛮人
    KILL_BARB_COUNT             =           9003,
    ---@see 进攻等级野蛮人城寨次
    KILL_BARB_WALL_LEVEL_COUNT  =           9004,
    ---@see 摧毁个野蛮人城寨.具体数量
    KILL_BARB_WALL_WIN_COUNT    =           9005,
    ---@see 进攻野蛮人城寨次
    KILL_BARB_WALL_COUNT        =           9006,
    ---@see 战胜支等级的野蛮人部队
    KILL_BARB_LEVEL_COUNT       =           9007,
    ---@see 参与集结战斗次数
    JOIN_RALLY_COUNT            =           9008,
    ---@see 战胜支等级的野蛮人部队
    KILL_BARB_LEVEL2_COUNT      =           9009,
    ---@see 招募名统帅.具体数量
    RECRUIT_HERO_COUNT          =           10001,
    ---@see 提升任意统帅的星级次
    HERO_STAR_LEVEL_COUNT       =           10002,
    ---@see 升级次统帅技能
    HERO_SKILL_LEVEL_COUNT      =           10003,
    ---@see 拥有名等级的统帅.具体数量.具体等级
    HERO_LEVEL_COUNT            =           10004,
    ---@see 消灭敌人行为触发
    KILL_ENEMY_ACTION           =           11001,
    ---@see 重伤.击杀个等级的单位
    KILL_ENEMY_LEVEL_COUNT      =           11002,
    ---@see 击败次守护者
    KILL_GUARDTION_COUNT        =           12001,
    ---@see 收集次符文
    COLLECTION_BUFF_COUNT       =           12002,
    ---@see 城内收获行为触发.指进行过这个行为
    CITY_COLLECTION_ACTION      =           13001,
    ---@see 在城市内总共收集资源.具体数量
    CITY_COLLECTION_NUM         =           13002,
    ---@see 累计使用加速分钟
    USE_SPEED_MIN               =           14001,
    ---@see 在建筑建造中使用分钟的加速道具
    USE_SPEED_MIN_IN_BUIND      =           14002,
    ---@see 在科技研究中使用分钟的加速道具
    USE_SPEED_MIN_IN_TECH       =           14003,
    ---@see 在兵种训练中使用分钟的加速道具
    USE_SPEED_MIN_IN_TARIN      =           14004,
    ---@see 消耗点行动力.具体数量
    COST_ACTION_POINT           =           15001,
    ---@see 累计消耗宝石
    USER_DENAR                  =           16001,
    ---@see 累计治疗次数
    TREATMENT_NUM               =           17002,
    ---@see 参与联盟建筑建造
    BUILD_ALLIANCE_TIME         =           18003,
    ---@see 转盘触发
    TURN_TABLE                  =           20001,
    ---@see 参与抽奖转盘X次
    TURN_TABLE_COUNT            =           20002,
    ---@see 远征通过关卡
    EXPEDITION_LEVEL            =           24001,
    ---@see 任意额度充值
    RECHARGE_ACTION             =           25001,
}
Enum.ActivityActionType = ActivityActionType