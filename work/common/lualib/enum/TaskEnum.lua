--[[
* @file : TaskEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Dec 31 2019 14:01:00 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 任务相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 任务统计参数默认值
Enum.TaskArgDefault = -1

---@see 任务类型
---@class TaskTypeEnumClass
local TaskType = {
    ---@see 野蛮人击杀数
    SAVAGE_KILL                     =                   1,
    ---@see 加入或创建一个联盟
    JOIN_GUILD                      =                   2,
    ---@see 占领圣地
    OCCUPY_HOLYlAND                 =                   3,
    ---@see 占领关卡
    OCCUPY_CHECKPOINT               =                   4,
    ---@see 设置昵称
    MODIFY_NAME                     =                   5,
    ---@see 科技提升
    TECHNOLOGY_UPGRADE              =                   6,
    ---@see 士兵数量
    SOLDIER_NUM                     =                   7,
    ---@see 建筑提升
    BUILDING_UPGRADE                =                   8,
    ---@see 城市内收集资源
    CITY_RESOURCE                   =                   9,
    ---@see 士兵训练
    SOLDIER_SUMMON                  =                   10,
    ---@see 地图上采集资源
    MAP_RESOURCE                    =                   11,
    ---@see 建筑数量
    BUILDING_NUM                    =                   13,
    ---@see 迷雾探索
    FOG_EXPLORE                     =                   14,
    ---@see 战力
    SCORE_NUM                       =                   15,
    ---@see 酒馆宝箱
    TAVERN_BOX                      =                   16,
    ---@see 统帅升级
    HERO_LEVEL                      =                   17,
    ---@see 统帅升技能
    HERO_SKILL_NUM                  =                   18,
    ---@see 统帅升星
    HERO_STAR_NUM                   =                   19,
    ---@see 统帅天赋点
    HERO_TALENT_NUM                 =                   20,
    ---@see 野蛮人城寨
    MONSTER_CITY_NUM                =                   21,
    ---@see 侦查次数
    SCOUT_NUM                       =                   22,
    ---@see 设置头像
    MODIFY_HEADID                   =                   23,
    ---@see 村庄奖励
    VILLAGE_REWARD                  =                   24,
    ---@see 探索山洞
    SCOUT_CAVE                      =                   25,
    ---@see 发现关卡
    DISCOVER_CHECKPOINT             =                   26,
    ---@see 发现圣地
    DISCOVER_HOLYLAND               =                   27,
    ---@see 资源产量
    RESOURCE_NUM                    =                   28,
    ---@see 派遣部队次数
    DISPATCH_ARMY                   =                   29,
    ---@see 伤兵治疗数
    HEAL_SOLDIER                    =                   30,
    ---@see 帮助盟友
    HELP_GUILD_MEMBER               =                   31,
    ---@see 使用指定道具
    USE_ITEM                        =                   32,
    ---@see 士兵训练
    SOLDIER_TRAIN                   =                   33,
    ---@see 开始科技研究次数
    TECHNOLOGY_NUM                  =                   34,
    ---@see 商店购买
    SHOP_BUY                        =                   37,
    ---@see 驿站购买
    MYSTERY_BUY                     =                   38,
    ---@see 远征通关
    EXPEDITION                      =                   40,
    ---@see 锻造装备品质
    EQUIP_QUALITY                   =                   42,
    ---@see 合成图纸
    EQUIP_BOOK                      =                   43,
    ---@see 合成装备材料
    MATERIAL_QUALITY                =                   44,
    ---@see 生产装备材料
    PRODUCE_MATERIAL_QUALITY        =                   45,
    ---@see 分解装备
    RESOLVE_EQUIP_QUALITY           =                   46,
    ---@see 分解装备材料
    RESOLVE_MATERIAL_QUALITY        =                   47,
}
Enum.TaskType = TaskType

---@see 章节任务状态
---@class ChapterTaskStatusEnumClass
local ChapterTaskStatus = {
    ---@see 删除
    DELETE                          =                   -1,
    ---@see 未完成
    NOT_FINISH                      =                   0,
    ---@see 已完成
    FINISH                          =                   1,
}
Enum.ChapterTaskStatus = ChapterTaskStatus

---@see 任务分类
---@class TaskGroupTypeEnumClass
local TaskGroupType = {
    ---@see 章节任务
    CHAPTER                         =                   1,
    ---@see 主线任务
    MAIN_LINE                       =                   2,
    ---@see 支线任务
    SIDE_LINE                       =                   3,
    ---@see 每日任务
    DAILY                           =                   4,
}
Enum.TaskGroupType = TaskGroupType

---@see 任务酒馆宝箱类型
---@class TaskTavernBoxTypeEnumClass
local TaskTavernBoxType = {
    ---@see 白银宝箱
    SILVER                          =                   1,
    ---@see 黄金宝箱
    GOLD                            =                   2,
}
Enum.TaskTavernBoxType = TaskTavernBoxType