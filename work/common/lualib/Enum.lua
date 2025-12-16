--[[
* @file : Enum.lua
* @type : lualib
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 枚举定义
* Copyright(C) 2017 IGG, All rights reserved
]]

---@class EnumClass
local Enum = {
    ---@type deviceTypeEnumClass
    DeviceType              =                   nil,        -- 设备类型枚举
    ---@type languageTypeEnumClass
    LanguageType            =                   nil,        -- 语言类型枚举
    ---@type tableTypeEnumClass
    TableType               =                   nil,        -- Table类型枚举
    ---@type tableTypeEnumClass
    DbType                  =                   nil,        -- DB类型枚举
    ---@type loginStatusEnumClass
    LoginState              =                   nil,        -- 登陆状态枚举
    ---@type maintainTypeEnumClass
    MaintainType            =                   nil,        -- 维护类型枚举
    ---@type systemKickEnumClass
    SystemKick              =                   nil,        -- 踢人枚举
    ---@type systemCfgEnumClass
    SystemCfg               =                   nil,        -- 系统配置数据枚举
    ---@type ActivityTimeTypeEnumClass
    ActivityTimeType        =                   nil,        -- 活动时间类型
    ---@type ActivityTypeEnumClass
    ActivityType            =                   nil,        -- 活动类型
    ---@type ActivityCirculationEnumClass
    ActivityCirculation     =                   nil,        -- 活动是否循环
    ---@type OpenServiceConcealEnumClass
    OpenServiceConceal      =                   nil,        -- 开服是否隐藏
    ---@type ActivityActionTypeEnumClass
    ActivityActionType      =                   nil,        -- 活动行为类型
    ---@type ArmyTypeEnumClass
    ArmyType                =                   nil,        -- 兵种类型
    ---@type ArmySubTypeEnumClass
    ArmySubType             =                   nil,        -- 兵种子类型
    ---@type ArmyUpdateEnumClass
    ArmyUpdate              =                   nil,        -- 是否晋升
    ---@type ArmyStatusEnumClass
    ArmyStatus              =                   nil,        -- 军队状态
    ---@type ArmyStatusOpEnumClass
    ArmyStatusOp            =                   nil,        -- 部队状态处理操作
    ---@type BattleTypeEnumClass
    BattleType              =                   nil,        -- 战斗类型
    ---@type BattleTargetTypeEnumClass
    BattleTargetType        =                   nil,        -- 技能目标类型
    ---@type SkillConditionEnumClass
    SkillCondition          =                   nil,        -- 技能条件类型
    ---@type SkillTriggerEnumClass
    SkillTrigger            =                   nil,        -- 技能触发时机
    ---@type SkillRangeEnumClass
    SkillRange              =                   nil,        -- 技能范围类型
    ---@type StatusCoExistEnumClass
    StatusCoExist           =                   nil,        -- 战斗状态共存规则
    ---@type SilentTypeEnumClass
    SilentType              =                   nil,        -- 沉默类型
    ---@type BuffTypeEnumClass
    BuffType                =                   nil,        -- BUFF类型
    ---@type ImmuneTypeEnumClass
    ImmuneType              =                   nil,        -- 状态免疫类型
    ---@type StatusDelTypeEnumClass
    StatusDelType           =                   nil,        -- 状态删除类型
    ---@type StatusTriggerEnumClass
    StatusTrigger           =                   nil,        -- 状态触发时机
    ---@type BuildingTypeEnumClass
    BuildingType            =                   nil,        -- 建筑类型
    ---@type BuildingGroupEnumClass
    BuildingGroup           =                   nil,        -- 建筑分组
    ---@type BoxTypeEnumClass
    BoxType                 =                   nil,        -- 酒馆宝箱类型
    ---@type ChatChannelEnumClass
    ChatChannel             =                   nil,        -- 聊天频道类型
    ---@type EmailTypeEnumClass
    EmailType               =                   nil,        -- 邮件类型
    ---@type EmailStatusEnumClass
    EmailStatus             =                   nil,        -- 聊天频道类型
    ---@type EmailSubTypeEnumClass
    EmailSubType            =                   nil,        -- 邮件子类型
    ---@type EmailReceiveAutoEnumClass
    EmailReceiveAuto        =                   nil,        -- 邮件是否自动领取
    ---@type GuildNameRepeatEnumClass
    GuildNameRepeat         =                   nil,        -- 联盟名称或检查重复
    ---@type GuildJobEnumClass
    GuildJob                =                   nil,        -- 联盟职位
    ---@type GuildNotifyEnumClass
    GuildNotify             =                   nil,        -- 联盟通知
    ---@type GuildApplyTypeEnumClass
    GuildApplyType          =                   nil,        -- 申请加入联盟返回值
    ---@type GuildSearchTypeEnumClass
    GuildSearchType         =                   nil,        -- 联盟搜索类型
    ---@type GuildJurisdictionTypeEnumClass
    GuildJurisdictionType   =                   nil,        -- 联盟成员权限类型
    ---@type GuildMemberJurisdictionEnumClass
    GuildMemberJurisdiction =                   nil,        -- 联盟成员是否有权限
    ---@type GuildExitTypeEnumClass
    GuildExitType           =                   nil,        -- 联盟成员退出类型
    ---@type GuildConsumeTypeEnumClass
    GuildConsumeType        =                   nil,        -- 联盟货币消费类型
    ---@type GuildRequestHelpTypeEnumClass
    GuildRequestHelpType    =                   nil,        -- 联盟求助类型
    ---@type GuildBuildStatusEnumClass
    GuildBuildStatus        =                   nil,        -- 联盟建筑状态
    ---@type GuildBuildTypeEnumClass
    GuildBuildType          =                   nil,        -- 联盟建筑类型
    ---@type GuildRepairTypeEnumClass
    GuildRepairType         =                   nil,        -- 维修联盟类型
    ---@type GuildSignTypeEnumClass
    GuildSignType           =                   nil,        -- 联盟标志类型
    ---@type GuildModifyTypeEnumClass
    GuildModifyType         =                   nil,        -- 联盟属性修改类型
    ---@type GuildGetTypeEnumClass
    GuildGetType            =                   nil,        -- 联盟信息获取类型
    ---@type GuildOfficerTypeEnumClass
    GuildOfficerType        =                   nil,        -- 联盟官职类型
    ---@type GuildResourceCenterResetEnumClass
    GuildResourceCenterReset=                   nil,        -- 重置联盟资源中心定时器类型
    ---@type GuildHolyLandStatusEnumClass
    GuildHolyLandStatus     =                   nil,        -- 联盟圣地状态
    ---@type GuildDonateTypeEnumClass
    GuildDonateType         =                   nil,        -- 联盟捐献类型
    ---@type GuildDonateRankTypeEnumClass
    GuildDonateRankType     =                   nil,        -- 联盟捐献排行奖励类型
    ---@type HeroStatusEnumClass
    HeroStatus              =                   nil,        -- 统帅状态
    ---@type SoilderStatusEnumClass
    SoilderStatus           =                   nil,        -- 士兵状态
    ---@type HeroRareTypeEnumClass
    HeroRareType            =                   nil,        -- 统帅稀有度
    ---@type ExchangeEnumClass
    Exchange                =                   nil,        -- 统帅雕像能否兑换
    ---@type HolyLandTypeEnumClass
    HolyLandType            =                   nil,        -- 圣地关卡类型
    ---@type HolyLandStatusEnumClass
    HolyLandStatus          =                   nil,        -- 圣地状态
    ---@type HolyLandGroupTypeEnumClass
    HolyLandGroupType       =                   nil,        -- 圣地分组类型
    ---@type ItemQualityTypeEnumClass
    ItemQualityType         =                   nil,        -- 物品品质类型
    ---@type ItemTypeEnumClass
    ItemType                =                   nil,        -- 物品分组类型
    ---@type ItemSubTypeEnumClass
    ItemSubType             =                   nil,        -- 物品子分组类型
    ---@type ItemBatchUseEnumClass
    ItemBatchUse            =                   nil,        -- 道具是否可以批量使用
    ---@type ItemPackageTypeEnumClass
    ItemPackageType         =                   nil,        -- 奖励类型
    ---@type ItemSpeedTypeEnumClass
    ItemSpeedType           =                   nil,        -- 加速道具类型
    ---@type VillageRewardTypeEnumClass
    VillageRewardType       =                   nil,        -- 村庄奖励类型
    ---@type ItemFunctionTypeEnumClass
    ItemFunctionType        =                   nil,        -- 道具使用类型
    ---@type BatchUseEnumClass
    BatchUse                =                   nil,        -- 能否批量使用
    ---@type LogTypeEnumClass
    LogType                 =                   nil,        -- 行为日志类型
    ---@type MapLevelEnumClass
    MapLevel                =                   nil,        -- 地图层级
    ---@type MapMarchTargetTypeEnumClass
    MapMarchTargetType      =                   nil,        -- 地图行军目标类型
    ---@type MapCityMoveTypeEnumClass
    MapCityMoveType         =                   nil,        -- 迁城类型
    ---@type MapPointFixGroupEnumClass
    MapPointFixGroup        =                   nil,        -- s_MapPointFix表Group类型
    ---@type TransportStatusEnumClass
    TransportStatus         =                   nil,        -- 运输状态
    ---@type MapUnitViewTypeEnumClass
    MapUnitViewType         =                   nil,        -- 地图对象视野类型
    ---@type MonsterTypeEnumClass
    MonsterType             =                   nil,        -- 怪物类型
    ---@type MonumentTypeEnumClass
    MonumentType            =                   nil,        -- 纪念碑类型
    ---@type MonumentRewardTypeEnumClass
    MonumentRewardType      =                   nil,        -- 纪念碑领奖类型
    ---@type MonumentRewardObjectEnumClass
    MonumentRewardObject    =                   nil,        -- 纪念碑领奖对象
    ---@type MonumentCloseTypeEnumClass
    MonumentCloseType       =                   nil,        -- 纪念碑事件关闭方式
    ---@type MonumentnRankRewardEnumClass
    MonumentnRankReward     =                   nil,        -- 纪念碑排行榜奖励类型
    ---@type ZeroEmptyTypeEnumClass
    ZeroEmptyType           =                   nil,        -- s_ZeroEmpty表索引枚举值
    ---@type CurrencyTypeEnumClass
    CurrencyType            =                   nil,        -- 货币类型
    ---@type RefreshTypeEnumClass
    RefreshType             =                   nil,        -- c_refresh表id值
    ---@type PushGroupEnumClass
    PushGroup               =                   nil,        -- 推送分组
    ---@type PushStatusEnumClass
    PushStatus              =                   nil,        -- 推送状态
    ---@type PushTypeEnumClass
    PushType                =                   nil,        -- 推送类型
    ---@type RallyTypeEnumClass
    RallyType               =                   nil,        -- 集结类型
    ---@type RankCommonEnumClass
    RankCommon              =                   nil,        -- 排行版偏移值
    ---@type RankTypeEnumClass
    RankType                =                   nil,        -- 排行版类型
    ---@type SaleTypeEnumClass
    SaleType                =                   nil,        -- 超值礼包类型
    ---@type LimitTimeTypeEnumClass
    LimitTimeType           =                   nil,        -- 限时礼包类型
    ---@type ResourceTypeEnumClass
    ResourceType            =                   nil,        -- 资源类型
    ---@type RoleTypeEnumClass
    RoleType                =                   nil,        -- 角色类型
    ---@type RoleStatisticsTypeEnumClass
    RoleStatisticsType      =                   nil,        -- 角色统计信息类型
    ---@type RoleCityBuffEnumClass
    RoleCityBuff            =                   nil,        -- 城市buff类型
    ---@type RoleCityBuffCoexistEnumClass
    RoleCityBuffCoexist     =                   nil,        -- buff能否共存
    ---@type RoleHeadTypeEnumClass
    RoleHeadType            =                   nil,        -- 玩家头像
    ---@type RoleHeadGetWayEnumClass
    RoleHeadGetWay          =                   nil,        -- 玩家头像以及头像框获取途径
    ---@type RoleResourcesActionEnumClass
    RoleResourcesAction     =                   nil,        -- 资源获取方式
    ---@type ExpeditionTypeEnumClass
    ExpeditionType          =                   nil,        -- 远征商店类型
    ---@type RoleNotifyTypeEnumClass
    RoleNotifyType          =                   nil,        -- 角色通知类型
    ---@type EarlyWarningTypeEnumClass
    EarlyWarningType        =                   nil,        -- 战斗预警类型
    ---@type RoleAgeEnumClass
    RoleAge                 =                   nil,        -- 时代类型
    ---@type ScoutTargetTypeEnumClass
    ScoutTargetType         =                   nil,        -- 斥候侦查目标类型
    ---@type ScoutArmyTypeEnumClass
    ScoutArmyType           =                   nil,        -- 侦查角色部队数量显示类型
    ---@type ScoutReinforceTypeEnumClass
    ScoutReinforceType      =                   nil,        -- 侦查城援军显示类型
    ---@type ScoutCityRallyTypeEnumClass
    ScoutCityRallyType      =                   nil,        -- 集结士兵显示类型
    ---@type TaskTypeEnumClass
    TaskType                =                   nil,        -- 任务类型
    ---@type ChapterTaskStatusEnumClass
    ChapterTaskStatus       =                   nil,        -- 章节任务状态
    ---@type TaskGroupTypeEnumClass
    TaskGroupType           =                   nil,        -- 任务分类
    ---@type WebErrorEnumClass
    WebError                =                   nil,        -- 请求结果错误码定义
    ---@type GuildMessageFreshTypeEnumClass
    GuildMessageFreshType   =                   nil,        -- 联盟留言板刷新类型
    ---@type SystemIdEnumClass
    SystemId                =                   nil,        -- 系统功能ID
    ---@type GuildGiftTypeEnumClass
    GuildGiftType           =                   nil,        -- 联盟礼物类型
    ---@type GuildGiftSendTypeEnumClass
    GuildGiftSendType       =                   nil,        -- 联盟礼物发放类型
    ---@type GuildGiftStatusEnumClass
    GuildGiftStatus         =                   nil,        -- 联盟礼物领取状态
    ---@type GuildGiftTakeTypeEnumClass
    GuildGiftTakeType       =                   nil,        -- 联盟礼物领取类型
    ---@type GuildGiftGroupEnumClass
    GuildGiftGroup          =                   nil,        -- 联盟礼物分组类型
    ---@type RankQueryTypeEnumClass
    RankQueryType           =                   nil,        -- 排行版查询类型
    ---@type ExpeditionTypeEnumClass
    ExpeditionBattleType     =                  nil,        -- 战役类型
    ---@type ExpeditionBattleResultEnumClass
    ExpeditionBattleResult   =                  nil,        -- 战役结果
    ---@type GuildGiftLevelEnumClass
    GuildGiftLevel          =                   nil,        -- 礼物ID是否随联盟礼物等级变化
    ---@type TaskTavernBoxTypeEnumClass
    TaskTavernBoxType       =                   nil,        -- 任务酒馆宝箱类型
    ---@type BattleResultEnumClass
    BattleResult            =                   nil,        -- 战斗结果类型
    ---@type EmailGuildInviteStatusEnumClass
    EmailGuildInviteStatus  =                   nil,        -- 联盟邀请邮件回复状态
    ---@type RoleCombatPowerTypeEnumClass
    RoleCombatPowerType     =                   nil,        -- 角色战力变化类型
    ---@type RoleBuildFocusTypeEnumClass
    RoleBuildFocusType      =                   nil,        -- 角色地图建筑关注类型
    ---@type StatusCleanTypeEnumClass
    StatusCleanType         =                   nil,        -- buff清除类型
    ---@type GuildTechnologyAttrTypeEnumClass
    GuildTechnologyAttrType =                   nil,        -- 联盟科技属性类型
    ---@type ResourceReportTypeEnumClass
    ResourceReportType      =                   nil,        -- 资源采集报告类型
    ---@type SkillAngerRecoverEnumClass
    SkillAngerRecover       =                   nil,        -- 技能怒气恢复规则
    ---@type SkillTriggerArmyLimitEnumClass
    SkillTriggerArmyLimit   =                   nil,        -- 技能部队限制规则
    ---@type SkillTriggerArmySoldierTypePercentEnumClass
    SkillTriggerArmySoldierTypePercent    =     nil,        -- 被动技能触发部队兵种限制
    ---@type SkillTriggerArmySoldierTypeEnumClass
    SkillTriggerArmySoldierType             =   nil,        -- 被动技能触发部队兵力构成限制
    ---@type RoleNewCityHideEnumClass
    RoleNewCityHide         =                   nil,        -- 角色离线未完成引导是否回收城堡
    ---@type MapTerritoryLineDirectionEnumClass
    MapTerritoryLineDirection =                 nil,        -- 地图领地线条方向
    ---@type MonsterBattleTypeEnumClass
    MonsterBattleType       =                   nil,        -- 召唤怪物的挑战类型
    ---@type MapMarkerTypeEnumClass
    MapMarkerType           =                   nil,        -- 地图书签类型
    ---@type MapMarkerStatusEnumClass
    MapMarkerStatus         =                   nil,        -- 地图书签状态
    ---@type MapObjectRefreshTypeEnumClass
    MapObjectRefreshType    =                   nil,        -- 地图对象刷新类型
    ---@type ResourceLimitTypeClass
    ResourceLimitType       =                   nil,        -- 资源阈值类型
    ---@type ServiceBusyTypeEnumClass
    ServiceBusyType         =                   nil,        -- 服务忙碌类型
    ---@type MapObjectSquareGroupEnumClass
    MapObjectSquareGroup    =                   nil,        -- 地图对象半径范围分组类型
}

Enum = setmetatable( {}, {
    __newindex = function ( self, key, value )
        if type(value) == "table" then
            rawset(self, key, enum(value))
        else
            rawset(self, key, value)
        end
    end
} )
return Enum