--[[
* @file : GuildEnum.lua
* @type : lualib
* @author : dingyuchao
* @created : Wed Apr 08 2020 13:13:10 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟相关枚举
* Copyright(C) 2017 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 联盟名称或检查重复
---@class GuildNameRepeatEnumClass
local GuildNameRepeat = {
    ---@see 不重复
    NO_REPEAT                   =                   0,
    ---@see 名称重复
    NAME                        =                   1,
    ---@see 简称重复
    ABB_NAME                    =                   2,
}
Enum.GuildNameRepeat = GuildNameRepeat

---@see 联盟职位
---@class GuildJobEnumClass
local GuildJob = {
    ---@see R1成员
    R1                          =                   1,
    ---@see R2成员
    R2                          =                   2,
    ---@see R3成员
    R3                          =                   3,
    ---@see R4成员
    R4                          =                   4,
    ---@see 盟主
    LEADER                      =                   5,
}
Enum.GuildJob = GuildJob

---@see 联盟通知
---@class GuildNotifyEnumClass
local GuildNotify = {
    ---@see 成员加入
    MEMBER_JOIN                 =                   1,
    ---@see 移除成员
    KICK_MEMBER                 =                   2,
    ---@see 任命官职
    APPOINT_OFFICER             =                   3,
    ---@see 联盟帮助
    HELP                        =                   4,
    ---@see 联盟解散
    DISBAND                     =                   5,
    ---@see 联盟成员对城市发起集结
    RALLY_CITY                  =                   6,
    ---@see 联盟成员对联盟旗帜发起集结.已废弃
    RALLY_FLAG                  =                   7,
    ---@see 联盟成员对联盟要塞发起集结.已废弃
    RALLY_FORTRESS              =                   8,
    ---@see 联盟成员对部队发起集结
    RALLY_ARMY                  =                   9,
    ---@see 联盟成员取消集结
    CANCLE_RALLY                =                   10,
    ---@see 联盟成员被集结
    CITY_RALLYED                =                   11,
    ---@see 联盟成员对野蛮人城寨发起集结
    RALLY_MONSTER_CITY          =                   12,
    ---@see 联盟旗帜被集结.已废弃
    FLAG_RALLYED                =                   13,
    ---@see 联盟要塞被集结.已废弃
    FORTRESS_RALLYED            =                   14,
    ---@see 人数不足集结取消
    RALLY_MEMBER_NOT_ENOUGH     =                   15,
    ---@see 联盟对无人圣地发起集结
    RALLY_NO_GUILD_HOLY_LAND    =                   16,
    ---@see 联盟对其他联盟圣地发起集结
    RALLY_GUILD_HOLY_LAND       =                   17,
    ---@see 联盟圣地被集结
    HOLY_LAND_RALLYED           =                   18,
    ---@see 联盟成员对联盟建筑发起集结
    RALLY_GUILD_BUILD           =                   19,
    ---@see 联盟建筑被集结
    GUILD_BUILD_RALLYED         =                   20,
    ---@see 添加联盟标记
    ADD_GUILD_MARKER            =                   21,
    ---@see 删除联盟标记
    DELETE_GUILD_MARKER         =                   22,
}
Enum.GuildNotify = GuildNotify

---@see 申请加入联盟返回值
---@class GuildApplyTypeEnumClass
local GuildApplyType = {
    ---@see 申请加入
    APPLY                       =                   1,
    ---@see 加入成功
    JOIN                        =                   2,
}
Enum.GuildApplyType = GuildApplyType

---@see 联盟搜索类型
---@class GuildSearchTypeEnumClass
local GuildSearchType = {
    ---@see 主界面触发的联盟推荐
    MAIN_WIN                    =                   1,
    ---@see 加入联盟界面的联盟推荐
    JOIN_WIN                    =                   2,
    ---@see 搜索联盟
    SEARCH                      =                   3,
}
Enum.GuildSearchType = GuildSearchType

---@see 联盟成员权限类型
---@class GuildJurisdictionTypeEnumClass
local GuildJurisdictionType = {
    ---@see 发送联盟邮件
    SEND_EMAIL                  =                   1,
    ---@see 联盟帮助
    HELP                        =                   2,
    ---@see 退出联盟
    EXIT                        =                   3,
    ---@see 联盟聊天
    CHAT                        =                   4,
    ---@see 发送就绪确认邮件
    CONFIRM_EMAIL               =                   5,
    ---@see 在线状态查看.已有头衔官员专属
    ONLINE_STATUS               =                   6,
    ---@see 建造联盟旗帜
    BUILD_FLAG                  =                   7,
    ---@see 联盟建筑灭火
    BUILDING_EXTINGUISH         =                   8,
    ---@see 提高.降低成员等级
    MEMBER_LEVEL                =                   9,
    ---@see 入盟邀请
    INVITE                      =                   10,
    ---@see 入盟审核
    EXAMINE                     =                   11,
    ---@see 成员移除
    KICK_MEMBER                 =                   12,
    ---@see 建造联盟建筑
    BUILD_BUILDING              =                   13,
    ---@see 联盟标记
    MARK                        =                   14,
    ---@see 编辑联盟资料
    EDIT_GUILD_INFO             =                   15,
    ---@see 官员任命
    APPOINT_OFFICER             =                   16,
    ---@see 拆除联盟建筑
    REMOVE_BUILDING             =                   17,
    ---@see 解散联盟
    DISBAND                     =                   18,
}
Enum.GuildJurisdictionType = GuildJurisdictionType

---@see 联盟成员是否有权限
---@class GuildMemberJurisdictionEnumClass
local GuildMemberJurisdiction = {
    ---@see 无权限
    NO                          =                   0,
    ---@see 有权限
    YES                         =                   1,
}
Enum.GuildMemberJurisdiction = GuildMemberJurisdiction

---@see 联盟成员退出类型
---@class GuildExitTypeEnumClass
local GuildExitType = {
    ---@see 退出
    EXIT                        =                   1,
    ---@see 解散
    DISBAND                     =                   2,
}
Enum.GuildExitType = GuildExitType

---@see 联盟货币消费类型
---@class GuildConsumeTypeEnumClass
local GuildConsumeType = {
    ---@see 修建建筑
    BUILD                       =                   1,
    ---@see 研究科技
    TECHNOLOGY                  =                   2,
}
Enum.GuildConsumeType = GuildConsumeType

---@see 联盟求助类型
---@class GuildRequestHelpTypeEnumClass
local GuildRequestHelpType = {
    ---@see 建筑建造升级
    BUILD                       =                   1,
    ---@see 医院治疗
    HEAL                        =                   2,
    ---@see 科技升级
    TECHNOLOGY                  =                   3,
    ---@see 战损补偿
    BATTLELOSE                  =                   4,
}
Enum.GuildRequestHelpType = GuildRequestHelpType

---@see 联盟建筑状态
---@class GuildBuildStatusEnumClass
local GuildBuildStatus = {
    ---@see 失效
    INVALID                     =                   0,
    ---@see 建造中
    BUILDING                    =                   1,
    ---@see 正常
    NORMAL                      =                   2,
    ---@see 燃烧中
    BURNING                     =                   3,
    ---@see 维修中
    REPAIR                      =                   4,
    ---@see 战斗中
    BATTLE                      =                   5,
}
Enum.GuildBuildStatus = GuildBuildStatus

---@see 联盟建筑类型
---@class GuildBuildTypeEnumClass
local GuildBuildType = {
    ---@see 联盟中心要塞
    CENTER_FORTRESS             =                   1,
    ---@see 联盟要塞1
    FORTRESS_FIRST              =                   2,
    ---@see 联盟旗帜
    FLAG                        =                   3,
    ---@see 联盟农田
    FOOD                        =                   4,
    ---@see 联盟伐木场
    WOOD                        =                   5,
    ---@see 联盟石矿床
    STONE                       =                   6,
    ---@see 联盟金矿床
    GOLD                        =                   7,
    ---@see 联盟谷仓
    FOOD_CENTER                 =                   8,
    ---@see 联盟木料场
    WOOD_CENTER                 =                   9,
    ---@see 联盟石材厂
    STONE_CENTER                =                   10,
    ---@see 联盟铸币场
    GOLD_CENTER                 =                   11,
    ---@see 联盟要塞2
    FORTRESS_SECOND             =                   12,
}
Enum.GuildBuildType = GuildBuildType

---@see 维修联盟类型
---@class GuildRepairTypeEnumClass
local GuildRepairType = {
    ---@see 代币
    DENAR                       =                   1,
    ---@see 联盟积分
    GUILD_POINT                 =                   2,
}
Enum.GuildRepairType = GuildRepairType

---@see 联盟标志类型
---@class GuildSignTypeEnumClass
local GuildSignType = {
    ---@see 旗帜背景
    FLAG_BACKGROUND             =                   1,
    ---@see 领土颜色
    TERRITORY_COLOR             =                   2,
    ---@see 联盟图案
    FLAG_PICTURE                =                   3,
    ---@see 联盟图案颜色
    FLAG_PICTURE_COLOR          =                   4,
}
Enum.GuildSignType = GuildSignType

---@see 联盟属性修改类型
---@class GuildModifyTypeEnumClass
local GuildModifyType = {
    ---@see 简称
    ABB_NAME                    =                   1,
    ---@see 名称
    NAME                        =                   2,
    ---@see 欢迎邮件
    WELCOME_EMAIL               =                   3,
    ---@see 公告.入盟要求和语言
    NOTICE                      =                   4,
    ---@see 联盟标识
    SIGNS                       =                   5,
    ---@see 联盟留言板功能
    MESSAGE_BOARD               =                   6,
}
Enum.GuildModifyType = GuildModifyType

---@see 联盟信息获取类型
---@class GuildGetTypeEnumClass
local GuildGetType = {
    ---@see 联盟信息
    GUILD                       =                   1,
    ---@see 联盟欢迎邮件信息
    WELCOME_EMAIL               =                   2,
}
Enum.GuildGetType = GuildGetType

---@see 联盟建筑燃烧速度放大倍率
Enum.GuildBuildBurnSpeedMulti = 100

---@see 联盟建筑建造速度放大倍率
Enum.GuildBuildBuildSpeedMulti = 100000

---@see 联盟官职类型
---@class GuildOfficerTypeEnumClass
local GuildOfficerType = {
    ---@see 顾问
    ADVISER                     =                   1001,
    ---@see 战神
    BATTLE                      =                   2001,
    ---@see 使节
    LIFE                        =                   3001,
    ---@see 圣女
    COLLECT                     =                   4001,
}
Enum.GuildOfficerType = GuildOfficerType

---@see 重置联盟资源中心定时器类型
---@class GuildResourceCenterResetEnumClass
local GuildResourceCenterReset = {
    ---@see 建造完成
    BUILD_FINISH                =                   1,
    ---@see 联盟成员进入资源中心开始采集
    MEMBER_JOIN                 =                   2,
    ---@see 联盟成员离开资源中心
    MEMBER_LEAVE                =                   3,
    ---@see 联盟成员采集速度变化
    SPEED_CHANGE                =                   4,
}
Enum.GuildResourceCenterReset = GuildResourceCenterReset

---@see 联盟圣地状态
---@class GuildHolyLandStatusEnumClass
local GuildHolyLandStatus = {
    ---@see 正常
    NORMAL                      =                   1,
    ---@see 战斗
    BATTLE                      =                   2,
}
Enum.GuildHolyLandStatus = GuildHolyLandStatus

---@see 联盟捐献类型
---@class GuildDonateTypeEnumClass
local GuildDonateType = {
    ---@see 资源
    RESOURCE                    =                   1,
    ---@see 代币
    DENAR                       =                   2,
}
Enum.GuildDonateType = GuildDonateType

---@see 联盟捐献排行奖励类型
---@class GuildDonateRankTypeEnumClass
local GuildDonateRankType = {
    ---@see 每日排行
    DAILY                       =                   1,
    ---@see 每周排行
    WEEK                        =                   2,
}
Enum.GuildDonateRankType = GuildDonateRankType

---@see 联盟留言板刷新类型
---@class GuildMessageFreshTypeEnumClass
local GuildMessageFreshType = {
    ---@see 向上刷新
    NEW                         =                   1,
    ---@see 向下刷新
    OLD                         =                   2,
    ---@see 邮件跳转请求
    EMAIL_FRESH                 =                   3,
}
Enum.GuildMessageFreshType = GuildMessageFreshType

---@see 联盟礼物类型
---@class GuildGiftTypeEnumClass
local GuildGiftType = {
    ---@see 礼物
    GIFT                        =                   1,
    ---@see 珍藏
    TREASURE                    =                   2,
}
Enum.GuildGiftType = GuildGiftType

---@see 联盟礼物发放类型
---@class GuildGiftSendTypeEnumClass
local GuildGiftSendType = {
    ---@see 购买礼包
    BUY_GIFT                    =                   1,
    ---@see 击败怪物
    KILL_MONSTER                =                   2,
}
Enum.GuildGiftSendType = GuildGiftSendType

---@see 联盟礼物领取状态
---@class GuildGiftStatusEnumClass
local GuildGiftStatus = {
    ---@see 未领取
    NO_RECEIVE                  =                   1,
    ---@see 已领取
    RECEIVE                     =                   2,
}
Enum.GuildGiftStatus = GuildGiftStatus

---@see 联盟礼物领取类型
---@class GuildGiftTakeTypeEnumClass
local GuildGiftTakeType = {
    ---@see 领取珍藏
    TREASURE                    =                   1,
    ---@see 一键领取普通礼物
    ALL_NORMAL_GIFT             =                   2,
    ---@see 领取指定礼物
    GIFT                        =                   3,
}
Enum.GuildGiftTakeType = GuildGiftTakeType

---@see 联盟礼物分组类型
---@class GuildGiftGroupEnumClass
local GuildGiftGroup = {
    ---@see 普通
    NORMAL                      =                   0,
    ---@see 稀有
    RATE                        =                   1,
}
Enum.GuildGiftGroup = GuildGiftGroup

---@see 礼物宝箱是否跟姐姐联盟礼物等级变化
---@class GuildGiftLevelEnumClass
local GuildGiftLevel = {
    ---@see 不随等级变化
    NO                          =                   0,
    ---@see 随等级变化
    YES                         =                   1,
}
Enum.GuildGiftLevel = GuildGiftLevel

---@see 联盟科技属性类型
---@class GuildTechnologyAttrTypeEnumClass
local GuildTechnologyAttrType = {
    ---@see 角色属性
    ROLE                        =                   1,
    ---@see 联盟属性
    GUILD                       =                   2,
    ---@see 联盟领土属性
    TERRITORY                   =                   3,
}
Enum.GuildTechnologyAttrType = GuildTechnologyAttrType