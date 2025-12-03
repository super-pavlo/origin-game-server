--[[
 * @file : BattleDef.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2020-01-20 15:45:11
 * @Last Modified time: 2020-01-20 15:45:11
 * @department : Arabic Studio
 * @brief : 战斗相关定义
 * Copyright(C) 2019 IGG, All rights reserved
]]

local AttrDef = require "AttrDef"
local BattleDef = {}

---@see 回合战报信息
---@class battleReportClass
local battleReportInfo = {
    damage                      =               0,                                          -- 伤害
    beatBackDamage              =               0,                                          -- 反击伤害
    attackHurt                  =               0,                                          -- 进攻方重伤
    attackDie                   =               0,                                          -- 进攻方死亡
    defenseHurt                 =               0,                                          -- 防御方重伤
    defenseDie                  =               0,                                          -- 防御方死亡
}

---@see 回合战报额外信息
---@class battleReportExClass
local battleReportExInfo = {
    attackIndex                 =               0,                                          -- 进攻方索引
    attackName                  =               "",                                         -- 进攻方名字
    attackObjectType            =               0,                                          -- 进攻方对象类型
    defenseIndex                =               0,                                          -- 防御方索引
    defenseName                 =               "",                                         -- 防御方名字
    defenseObjectType           =               0,                                          -- 防御方对象类型
    damage                      =               0,                                          -- 伤害
    beatBackDamage              =               0,                                          -- 反击伤害
    attackHeadId                =               0,                                          -- 进攻方头像
    defenseHeadId               =               0,                                          -- 防御方头像
    battleBeginTime             =               0,                                          -- 战斗开始时间
    battleEndTime               =               0,                                          -- 战斗结束时间
    battleType                  =               0,                                          -- 战斗类型
    beginArmyCount              =               0,                                          -- 战斗开始部队数量
    endArmyCount                =               0,                                          -- 战斗结束部队数量
    attackPos                   =               {},                                         -- 攻击方坐标
    defensePos                  =               {},                                         -- 防御方坐标
}

---@see 战斗回合伤害信息
---@class battleDamageClass
local battleDamageInfo = {
    attackObjectIndex           =               0,                                          -- 进攻方索引
    defenseObjectIndex          =               0,                                          -- 防御方索引
    damage                      =               0,                                          -- 伤害
    beatBackDamage              =               0,                                          -- 反击伤害
}

---@see 战斗对象buff信息
---@class battleObjectBuffClass
local battleBuffInfo = {
    statusId                    =               0,                                          -- 状态ID
    turn                        =               0,                                          -- 持续回合
    shiled                      =               0,                                          -- 护盾
    overlay                     =               0,                                          -- 叠加层数
    addObjectIndex              =               0,                                          -- 添加对象索引
    overlayType                 =               0,                                          -- 叠加状态
    silentType                  =               0,                                          -- 沉默类型
    addTurn                     =               0,                                          -- 附加的回合
    type                        =               0,                                          -- 状态类型
    ---@type battleObjectAttrClass
    addSnapShot                 =               {},                                         -- 施法者快照
}

---@see 战斗对象信息
---@class battleObjectAttrClass
local battleObjectInfo = {
    objectIndex                 =               0,                                          -- 对象索引
    objectRid                   =               0,                                          -- 对象rid
    pos                         =               {},                                         -- 对象坐标
    level                       =               0,                                          -- 对象等级(用于野蛮人城寨)
    objectType                  =               0,                                          -- 对象类型
    ---@type defaultBattleAttrClass
    objectAttr                  =               AttrDef.getDefaultBattleAttr(),             -- 对象属性
    ---@type defaultBattleAttrClass
    objectAttrRaw               =               AttrDef.getDefaultBattleAttr(),             -- 对象原始属性
    battleBeginTime             =               0,                                          -- 战斗开始时间
    soldiers                    =               {},                                         -- 士兵信息
    attackTargetIndex           =               0,                                          -- 攻击对象索引
    turnHurt                    =               0,                                          -- 单次回合受到伤害
    allTurnHurt                 =               0,                                          -- 全部回合受到伤害
    soldierHurt                 =               {},                                         -- 兵种受到伤害
    soldierHurtWithObjectIndex  =               {},                                         -- 同目标战斗收到伤害(用于战报)
    isInitiativeAttack          =               false,                                      -- 是否主动攻击
    beginArmyCount              =               0,                                          -- 初始军队数量
    monsterId                   =               0,                                          -- 野蛮人ID
    attackMonsterIds            =               {},                                         -- 攻击的野蛮人ID
    mainHeroId                  =               0,                                          -- 主将ID
    deputyHeroId                =               0,                                          -- 副将ID
    mainHeroLevel               =               0,                                          -- 主将等级
    deputyHeroLevel             =               0,                                          -- 副将等级
    allHurt                     =               0,                                          -- 累计受到伤害
    killCount                   =               {},                                         -- 击杀数量
    exitBattleFlag              =               false,                                      -- 退出战斗标记
    exitBattleWin               =               2,                                          -- 退出战斗是否胜利
    exitBattleBlockBlag         =               0,                                          -- 是否已经强退了战斗
    allAttackers                =               {},                                         -- 攻击者索引
    sp                          =               0,                                          -- 对象怒气
    maxSp                       =               0,                                          -- 对象最大怒气
    skills                      =               {},                                         -- 对象技能
    rawSkills                   =               {},                                         -- 对象原技能
    angle                       =               0,                                          -- 对象当前角度
    allHeal                     =               0,                                          -- 目标受到的治疗
    triggerSkillCount           =               {},                                         -- 技能触发次数限制
    triggerSkillInterval        =               {},                                         -- 技能触发回合间隔
    guildId                     =               0,                                          -- 对象联盟ID
    ---@type table<int, battleObjectBuffClass>
    buffs                       =               {},                                         -- 对象buff
    turnSkillInfo               =               {},                                         -- 回合内受到的技能信息
    ---@type table<int,battleReportClass>
    battleReport                =               {},                                         -- 回合战报信息
    isRally                     =               false,                                      -- 是否是集结部队
    rallyLeader                 =               0,                                          -- 集结部队队长
    rallyMember                 =               {},                                         -- 集结部队成员
    rallySoldiers               =               {},                                         -- 集结部队士兵信息
    rallyHeros                  =               {},                                         -- 集结部队主将信息
    rallySoldierHurt            =               {},                                         -- 集结部队士兵受伤信息
    rallyDamages                =               {},                                         -- 集结部队造成的伤害
    rallyKillCounts             =               {},                                         -- 集结部队造成的击杀
    cityAttackCount             =               {},                                         -- 城市攻城战结束时的攻击对象数量
    turnDotDamage               =               0,                                          -- 回合dot伤害
    turnHotHeal                 =               0,                                          -- 回合hot恢复
    useAngleSkillTurn           =               0,                                          -- 使用怒气技能回合
    armyRadius                  =               0,                                          -- 部队半径
    holyLandMonsterId           =               0,                                          -- 圣地守护者怪物ID
    historyBattleObjectType     =               {},                                         -- 历史发生战斗的对象类型
    tmpObjectFlag               =               false,                                      -- 是否为临时对象(被技能AOE加入)
    lastBattleTurn              =               0,                                          -- 最后受伤回合
    staticId                    =               0,                                          -- 攻击目标静态ID
    battleWithInfos             =               {},                                         -- 和目标发生战斗的信息
    battleEndAttackers          =               {},                                         -- 退出战斗时的攻击对象
    plunderResource             =               {},                                         -- 可掠夺的资源量
    talentAttr                  =               {},                                         -- 天赋属性
    equipAttr                   =               {},                                         -- 装备属性
    armyCountMax                =               0,                                          -- 部队最大兵力
    status                      =               0,                                          -- 对象状态
    ---@type battleObjectAttrClass
    attackObjectSnapShot        =               {},                                         -- 攻击对象快照
    isOutAttackRange            =               false,                                      -- 目标是否不在攻击距离内
    outAttackRangeIndex         =               0,                                          -- 超出攻击距离的目标
    holyLandBuildMonsterId      =               0,                                          -- 圣地建筑怪物ID
    historyMaxAttackCount       =               0,                                          -- 历史最大攻击者数量
    armyIndex                   =               0,                                          -- 部队索引
    buffChangeFlag              =               false,                                      -- buff是否发生变化
    objectCityPos               =               {},                                         -- 对象城市坐标(当对象是部队时有效)
    allHospitalDieCount         =               0,                                          -- 总计医院死亡数量
    allSoldierHardHurt          =               0,                                          -- 总计重伤数量
    isBeDamageOrHeal            =               false,                                      -- 是否收到伤害或者治疗(用于判断是否发发送战报)
    isCheckPointMonster         =               false,                                      -- 是否是关卡的PVE怪物
    leavedRallyHeros            =               {},                                         -- 集结部队主将信息(战斗结束前已经退出)
    leavedRallySoldierHurt      =               {},                                         -- 集结部队士兵受伤信息(战斗结束前已经退出)
}

---@see 战斗场景信息
---@class defaultBattleSceneClass
local battleSceneInfo = {
    battleIndex                 =               0,                                          -- 战斗索引
    ---@type table<integer, battleObjectAttrClass>
    objectInfos                 =               {},                                         -- 对象信息
    battleType                  =               0,                                          -- 战斗类型
    gameNode                    =               "",                                         -- 游服节点
    nextTick                    =               0,                                          -- 下次战斗时间
    turn                        =               1,                                          -- 战斗回合
    isBattleWork                =               false,                                      -- 是否正在处理战斗
    isBattleMerged              =               false,                                      -- 战斗是否被合并
    reinforceJoinArmy           =               {},                                         -- 加入增援信息
    reinforceLeaveArmy          =               {},                                         -- 退出增援信息
    nextRecordTurn              =               0,                                          -- 记录战报下一个回合
    reportUniqueIndex           =               0,                                          -- 战报唯一索引
}

---@see 退出战斗通知信息
---@class defaultExitBattleArgClass
local battleExitArg = {
    objectIndex                 =               0,                                          -- 对象索引
    rid                         =               0,                                          -- 对象角色rid
    guildId                     =               0,                                          -- 对象公会id
    objectType                  =               0,                                          -- 对象类型
    soldiers                    =               {},                                         -- 士兵信息
    soldierHurt                 =               {},                                         -- 士兵损伤信息
    battleReportEx              =               {},                                         -- 战报额外信息
    win                         =               false,                                      -- 是否战斗胜利
    battleType                  =               0,                                          -- 战斗类型
    isInitiativeAttack          =               false,                                      -- 是否是主动攻击
    attackMonsterIds            =               {},                                         -- 攻击的怪物id
    killCount                   =               0,                                          -- 击杀数
    plunderRid                  =               0,                                          -- 被掠夺角色rid
    attackTargetIndex           =               0,                                          -- 攻击目标索引
    attackTargetType            =               0,                                          -- 攻击目标类型
    disband                     =               false,                                      -- 是否解散
    isRally                     =               false,                                      -- 是否是集结部队
    rallySoldiers               =               {},                                         -- 集结部队士兵信息
    rallySoldierHurt            =               {},                                         -- 集结部队士兵受伤信息
    rallyDamages                =               {},                                         -- 集结部队各子部队造成伤害
    rallyKillCounts             =               {},                                         -- 集结部队各子部队造成的击杀
    cityAttackCount             =               0,                                          -- 攻城结束时的攻击者数量
    battleEndAttackers          =               0,                                          -- 攻城结束时,正在攻击自己的对象
    targetRid                   =               0,                                          -- 攻击对象rid
    attackerRid                 =               0,                                          -- 攻击者rid
    holyLandMonsterId           =               0,                                          -- 圣地守护者怪物ID
    historyBattleObjectType     =               {},                                         -- 历史发生战斗的对象类型
    rallyLeader                 =               0,                                          -- 集结部队队长
    rallyMember                 =               {},                                         -- 集结部队成员
    targetStaticId              =               0,                                          -- 目标对象ID(用于战报)
    selfStaticId                =               0,                                          -- 自己对象ID(用于战报)
    plunderResource             =               {},                                         -- 可掠夺的资源量
    leaderArmyNoEnter           =               false,                                      -- 集结队长是否进入地图
    sendReportRid               =               0,                                          -- 发送战报角色rid
    targetGuildId               =               0,                                          -- 目标联盟ID
    monsterCityLevel            =               0,                                          -- 野蛮人城寨等级
    monsterCityPos              =               0,                                          -- 野蛮人城寨位置
    mainHeroId                  =               0,                                          -- 部队主将ID
    armyIndex                   =               0,                                          -- 部队索引
    allHospitalDieCount         =               0,                                          -- 总计医院死亡数量
    allSoldierHardHurt          =               0,                                          -- 总计重伤数量
    isBeDamageOrHeal            =               false,                                      -- 是否收到伤害或者治疗(用于判断是否发发送战报)
    tmpObjectFlag               =               false,                                      -- 是否是临时对象
    selfIsCheckPointMonster     =               false,                                      -- 自己是否是关卡怪物
    targetIsCheckPointMonster   =               false,                                      -- 目标是否是关卡怪物
}

---@see 获取战斗对象基础信息
---@return battleObjectAttrClass
function BattleDef:getDefaultBattleObjectInfo()
    return const( table.copy(battleObjectInfo) )
end

---@see 获取战斗场景信息
---@return defaultBattleSceneClass
function BattleDef:getDefaultBattleScene()
    return const( table.copy(battleSceneInfo) )
end

---@see 获取退出战斗通知信息
---@return defaultExitBattleArgClass
function BattleDef:getDefaultBattleExitArg()
    return const( table.copy(battleExitArg) )
end

---@see 获取战斗buff信息
---@return battleObjectBuffClass
function BattleDef:getDefaultBattleBuffInfo()
    return const( table.copy(battleBuffInfo) )
end

---@see 获取战斗回合伤害信息
---@return battleDamageClass
function BattleDef:getBattleDamageInfo()
    return const( table.copy(battleDamageInfo) )
end

---@see 获取战报信息
---@return battleReportClass
function BattleDef:getBattleReportInfo()
    return const( table.copy(battleReportInfo) )
end

---@see 获取战报额外信息
---@return battleReportExClass
function BattleDef:getBattleReportExInfo()
    return const( table.copy(battleReportExInfo) )
end

return BattleDef