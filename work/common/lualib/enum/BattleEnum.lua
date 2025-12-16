--[[
* @file : BattleEnum.lua
* @type : lualib
* @author : linfeng
* @created : Thu Dec 26 2019 10:23:27 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 战斗枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 战斗结果
---@class BattleResultEnumClass
local BattleResult = {
    FAIL                =                   0,          -- 失败
    WIN                 =                   1,          -- 胜利
    NORESULT            =                   2,          -- 无结果
}
Enum.BattleResult = BattleResult

---@see 战斗类型
---@class BattleTypeEnumClass
local BattleType = {
    ---@see 野蛮人战斗
    MONSTER                         =               100,
    ---@see 野蛮人城寨
    MONSTER_CITY                    =               101,
    ---@see 圣地守护者
    GUARD_HOLY_LAND                 =               102,
    ---@see 圣所战斗
    SANCTUARY                       =               103,
    ---@see 圣坛战斗
    ALTAR                           =               104,
    ---@see 圣祠战斗
    SHRINE                          =               105,
    ---@see 失落神庙
    LOST_TEMPLE                     =               106,
    ---@see 召唤单人怪
    SUMMON_SINGLE                   =               107,
    ---@see 召唤集结怪
    SUMMON_RALLY                    =               108,
    ---@see 关卡1PVE战斗
    CHECKPOINT_PVE_1                =               109,
    ---@see 关卡2PVE战斗
    CHECKPOINT_PVE_2                =               110,
    ---@see 关卡3PVE战斗
    CHECKPOINT_PVE_3                =               111,
    ---@see 野外战斗
    FIELD                           =               200,
    ---@see 资源点战斗
    RESOURCE                        =               201,
    ---@see 城市战斗
    CITY_PVP                        =               202,
    ---@see 圣所战斗.PVP
    SANCTUARY_PVP                   =               203,
    ---@see 圣坛战斗.PVP
    ALTAR_PVP                       =               204,
    ---@see 圣祠战斗.PVP
    SHRINE_PVP                      =               205,
    ---@see 失落神庙.PVP
    LOST_TEMPLE_PVP                 =               206,
    ---@see 等级1关卡战斗
    CHECKPOINT_1                    =               207,
    ---@see 等级2关卡战斗
    CHECKPOINT_2                    =               208,
    ---@see 等级3关卡战斗
    CHECKPOINT_3                    =               209,
    ---@see 联盟建筑战斗
    GUILD_BUILD_DEFENSE             =               210,
}
Enum.BattleType = BattleType

---@see 技能目标类型
---@class BattleTargetTypeEnumClass
local BattleTargetType = {
    ---@see 仅自己部队
    ONLY_SELF                       =               1,
    ---@see 仅友方部队
    ONLY_FRIEND                     =               2,
    ---@see 自己和友方部队
    SELF_FRIEND                     =               3,
    ---@see 非玩家部队
    NO_ROLE                         =               4,
    ---@see 仅敌方玩家部队
    ONLY_ROLE_ENEMY                 =               5,
    ---@see 全部敌方部队
    ALL_ENEMY                       =               6,
}
Enum.BattleTargetType = BattleTargetType

---@see 技能条件类型
---@class SkillConditionEnumClass
local SkillCondition = {
    ---@see 部队剩余量大于X
    ARMY_COUNT_MORE                 =               1,
    ---@see 部队剩余量小于等于X
    ARMY_COUNT_LESS                 =               2,
}
Enum.SkillCondition = SkillCondition

---@see 技能触发时机
---@class SkillTriggerEnumClass
local SkillTrigger = {
    ---@see 怒气值大于等于X时
    ANGER_MORE                      =               0,
    ---@see 普通攻击后
    NORMAL_ATTACK                   =               1,
    ---@see 反击后
    BEATBACK                        =               2,
    ---@see 释放怒气技能后
    ANGER_SKILL                     =               3,
    ---@see 造成伤害后.包括普攻.反击.技能伤害
    MAKE_DAMAGE                     =               4,
    ---@see 获得护盾后
    GET_SHILED                      =               5,
    ---@see 恢复兵力后
    RESUME_SOLDIER                  =               6,
    ---@see 拥有BUFF时
    HAD_BUFF                        =               7,
    ---@see 拥有DEBUFF时
    HAD_DEBUFF                      =               8,
    ---@see 普通攻击任意建筑时
    ATTACK_BUILD                    =               9,
    ---@see 攻击玩家城市时
    ATTACK_CITY                     =               10,
    ---@see 攻击玩家城市外建筑时
    ATTACK_OUT_CITY                 =               11,
    ---@see 普通攻击玩家城市X回合后
    ATTACK_CITY_TURN_MORE           =               12,
    ---@see 释放指定技能后
    AFTER_USE_SKILL                 =               13,
    ---@see 自己步兵数量占比大于等于X
    SELF_INFANTRY_MORE              =               51,
    ---@see 自己步兵数量占比小于X
    SELF_INFANTRY_LESS              =               52,
    ---@see 自己骑兵数量占比大于等于X
    SELF_CAVALRY_MORE               =               53,
    ---@see 自己骑兵数量占比小于X
    SELF_CAVALRY_LESS               =               54,
    ---@see 自己弓兵数量占比于等于X
    SELF_ARCHER_MORE                =               55,
    ---@see 自己弓兵数量占比小于X
    SELF_ARCHER_LESS                =               56,
    ---@see 自己攻城单位数量占比于等于X
    SELF_SIEGE_UNIT_MORE            =               57,
    ---@see 自己攻城单位数量占比小于X
    SELF_SIEGE_UNIT_LESS            =               58,
    ---@see 自己部队兵力百分比大于X
    SELF_ARMY_COUNT_MORE            =               59,
    ---@see 自己部队兵力百分比小于等于X
    SELF_ARMY_COUNT_LESS            =               60,
    ---@see 自己兵种类型数量大于等于X
    SELF_SOLDIER_COUNT_MORE         =               61,
    ---@see 自己兵种类型数量小于X
    SELF_SOLDIER_COUNT_LESS         =               62,
    ---@see 受到普攻伤害时
    BE_NORMAL_DAMAGE                =               101,
    ---@see 受到反击伤害时
    BE_BEAT_BACK_DAMAGE             =               102,
    ---@see 受到技能伤害时
    BE_SKILL_DAMAGE                 =               103,
    ---@see 受到任意伤害时
    BE_ANY_DAMAGE                   =               104,
    ---@see 被夹击时
    BE_CONVER_ATTACK                =               105,
    ---@see 敌方拥有护盾时
    ENEMY_HAD_SHILED                =               106,
    ---@see 敌方拥有BUFF类型时
    ENEMY_HAD_BUFF                  =               107,
    ---@see 敌方拥有DEBUFF类型时
    ENEMY_HAD_DEBUFF                =               108,
    ---@see 敌方部队兵力百分比大于等于X
    ENEMY_SOLDIER_COUNT_MORE        =               151,
    ---@see 敌方部队兵力百分比小于X
    ENEMY_SOLDIER_COUNT_LESS        =               152,
    ---@see 进入战斗时
    ENTER_BATTLE                    =               201,
    ---@see 离开战斗时
    LEAVE_BATTLE                    =               202,
    ---@see 离开建筑时
    LEAVE_BUILD                     =               203,
    ---@see 战胜任意敌方部队后
    WIN_ANY_ENEMY                   =               204,
    ---@see 战胜野外部队后
    WIN_OUT_ARMY                    =               205,
    ---@see 战胜野蛮人和守护者后
    AFTER_KILL_MONSTER              =               206,
    ---@see 担任驻防统帅被普通攻击时
    ON_DUTY_HERO_ATTACK             =               301,
    ---@see 担任驻防统帅被夹击时
    ON_DUTY_HERO_CONVER             =               302,
}
Enum.SkillTrigger = SkillTrigger

---@see 技能范围类型
---@class SkillRangeEnumClass
local SkillRange = {
    ---@see 单目标
    SINGLE                          =               1,
    ---@see 扇形
    SECTOR                          =               2,
}
Enum.SkillRange = SkillRange

---@see 战斗状态共存规则
---@class StatusCoExistEnumClass
local StatusCoExist = {
    ---@see 替代
    ONE_REPLACE                     =               101,
    ---@see 仅替代低等级
    ONE_REPLACE_LOW                 =               102,
    ---@see 同一施法者替代.不同施法者共存
    TWO_REPLACE                     =               201,
    ---@see 同一施法者替代低等级.不同施法者共存
    TWO_REPLACE_LOW                 =               202,
    ---@see 叠加
    THREE_OVERLAY                   =               301,
    ---@see 同一施法者叠加.不同施法者叠加共存
    THREE_OVERLAY_REPLACE           =               302,
}
Enum.StatusCoExist = StatusCoExist

---@see 沉默类型
---@class SilentTypeEnumClass
local SilentType = {
    ---@see 无沉默
    NONE                            =               0,
    ---@see 技能
    SKILL                           =               1,
    ---@see 攻击
    ATTACK                          =               2,
    ---@see 攻击和技能
    ATTACK_SKILL                    =               3,
}
Enum.SilentType = SilentType

---@see BUFF类型
---@class BuffTypeEnumClass
local BuffType = {
    ---@see 增益效果
    BUFF                            =               1,
    ---@see 减益效果
    DEBUFF                          =               2,
}
Enum.BuffType = BuffType

---@see 状态免疫类型
---@class ImmuneTypeEnumClass
local ImmuneType = {
    ---@see 无免疫效果
    NONE                            =               0,
    ---@see 免疫所有DEBUFF
    ALL_DEBUFF                      =               1,
    ---@see 免疫减速效果
    REDUCE_SPEED                    =               2,
    ---@see 免疫沉默效果
    SILENT                          =               3,
}
Enum.ImmuneType = ImmuneType

---@see 状态删除类型
---@class StatusDelTypeEnumClass
local StatusDelType = {
    ---@see 无清除效果
    NONE                            =               0,
    ---@see 清除增益效果
    DEL_BUFF                        =               1,
    ---@see 清除减益效果
    DEL_DEBUFF                      =               2,
    ---@see 清除增益和减益效果
    DEL_BUFF_DEBUFF                 =               3,
    ---@see 清除指定ID的状态
    DEL_STATUS                      =               4,
    ---@see 清除指定叠加状态
    DEL_OVERLAY                     =               5,
}
Enum.StatusDelType = StatusDelType

---@see 状态触发时机
---@class StatusTriggerEnumClass
local StatusTrigger = {
    ---@see 回合内持续触发
    IN_TURN                         =               1,
    ---@see 状态结束时触发
    ON_END                          =               2,
    ---@see 状态被清除时
    ON_CLEAN                        =               3,
}
Enum.StatusTrigger = StatusTrigger

---@see 状态是否可以被清除
---@class StatusCleanTypeEnumClass
local StatusCleanType = {
    ---@see 可以被清除
    YES                             =               1,
    ---@see 不可被清除
    NO                              =               2,
}
Enum.StatusCleanType = StatusCleanType

---@see 技能怒气恢复规则
---@class SkillAngerRecoverEnumClass
local SkillAngerRecover = {
    ---@see 不恢复
    NO                              =               0,
    ---@see 技能释放后
    AFTER_USE_SKILL                 =               1,
    ---@see 技能命中目标后
    AFTER_SKILL_HIT                 =               2,
    ---@see 释放怒气技能后
    AFTER_USE_ANGER_SKILL           =               3,
    ---@see 部队受到攻击后
    AFTER_BE_ATTACK                 =               4,
}
Enum.SkillAngerRecover = SkillAngerRecover

---@see 被动技能触发部队限制
---@class SkillTriggerArmyLimitEnumClass
local SkillTriggerArmyLimit = {
    ---@see 所有类型
    ALL                             =               0,
    ---@see 普通部队
    NORMAL                          =               1,
    ---@see 采集部队
    COLLECT                         =               2,
    ---@see 城市部队
    CITY                            =               3,
    ---@see 联盟建筑部队
    GUILD_BUILD                     =               4,
    ---@see 圣地部队
    HOLY_LAND                       =               5,
    ---@see 非城市驻防部队
    NO_CITY_GARRISON                =               6,
    ---@see 建筑驻防部队
    GARRISON                        =               7,
}
Enum.SkillTriggerArmyLimit = SkillTriggerArmyLimit

---@see 被动技能触发部队兵种限制
---@class SkillTriggerArmySoldierPercentEnumClass
local SkillTriggerArmySoldierTypePercent = {
    ---@see 无限制
    NO                              =               0,
    ---@see 步兵大于等于百分X
    INFANTRY_MORE                   =               1,
    ---@see 步兵小于百分X
    INFANTRY_LESS                   =               2,
    ---@see 骑兵大于等于百分X
    CAVALRY_MORE                    =               3,
    ---@see 骑兵小于百分X
    CAVALRY_LESS                    =               4,
    ---@see 弓兵大于等于百分X
    ARCHER_MORE                     =               5,
    ---@see 弓兵小于百分X
    ARCHER_LESS                     =               6,
    ---@see 攻城单位大于等于百分X
    SIEGE_UNIT_MORE                 =               7,
    ---@see 攻城单位小于百分X
    SIEGE_UNIT_LESS                 =               8,
}
Enum.SkillTriggerArmySoldierTypePercent = SkillTriggerArmySoldierTypePercent

---@see 被动技能触发部队兵力构成限制
---@class SkillTriggerArmySoldierTypeEnumClass
local SkillTriggerArmySoldierType = {
    ---@see 无限制
    NO                              =               0,
    ---@see 部队兵种类型大于等于X种
    TYPE_MORE                       =               1,
    ---@see 部队兵种类型小于X种
    TYPE_LESS                       =               2,
    ---@see 兵力比例大于等于X
    PERCENT_MORE                    =               3,
    ---@see 兵力比例小于X
    PERCENT_LESS                    =               4,
}
Enum.SkillTriggerArmySoldierType = SkillTriggerArmySoldierType