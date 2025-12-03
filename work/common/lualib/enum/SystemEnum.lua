--[[
 * @file : SystemEnum.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2019-12-03 15:14:36
 * @Last Modified time: 2019-12-03 15:14:36
 * @department : Arabic Studio
 * @brief : 系统相关枚举
 * Copyright(C) 2019 IGG, All rights reserved
]]

local skynet = require "skynet"
local Enum = require "Enum"

---@see 协议枚举
Enum.PROTOCOL_PATH                      =           skynet.getenv("protocolpath")
---@see 数据库落地数据枚举
Enum.DB_SPROTO_PATH                     =           skynet.getenv("dbsprotopath")
---@see 数据库落地数据枚举
Enum.COMMON_SPROTO_PATH                 =           skynet.getenv("commonsprotopath")
---@see 是否处于守护模式
Enum.G_DAEMON                           =           skynet.getenv("daemon") ~= nil
---@see 所在时区.小时
Enum.TIME_ZONE                          =           tonumber(skynet.getenv("timezone")) or 0
---@see 最大分包大小
Enum.MaxPackageSize                     =           2048
---@see 默认子服务数量
Enum.DEFUALT_SNAX_SERVICE_NUM           =           10
---@see 玩家从AFK到LOGOUT的间隔.秒
Enum.AFK_INTERVAL                       =           60
---@see 调试模式
Enum.DebugMode = tonumber(skynet.getenv("debug")) == 1
---@see 压缩最小数据大小
Enum.CompressMinSize                    =           512

---@see 注册的sproto.slot
Enum.SPROTO_SLOT = {
    RPC         =           0,
    DB          =           1,
}

---@see AOI_ACITON定义
Enum.AOI_ACTION = {
    MOVE                       =           "m",
    DROP                       =           "d"
}

---@see Agent状态定义
Enum.AgentMode = {
    OPEN                      =           1,
    CLOSE                     =           2,
}

---@see DataSheet标识定义
Enum.Share = {
    ENTITY_CFG				=			"ShareEntityCfg",
    NODENAME                =           "ShareNodeName",
    NODELINENAME            =           "ShareNodeLineName",
    DBNODE                  =           "ShareDbNode",
    CENTERNODE              =           "ShareCenterNode",
    CHATNODE                =           "ShareChatNode",
    PUSHNODE                =           "SharePushNode",
    OPENTIME                =           "ShareOpenTime",
    MAPINFO                 =           "ShareMapInfo",
    MAPIDS                  =           "ShareMapIds",
    REDISPORT               =           "ShareRedisPort",
    RoleShare               =           "RoleShare",
    DelGoodsSha1            =           "DelGoodsSha1",
    MultiSnaxNum            =           "MultiSnaxNum",
    MaxRealMapId            =           "MaxRealMapId",
    RecommendConfig         =           "RecommendConfig",
    FriendRecommend         =           "FriendRecommend",
    LevelPass               =           "LevelPass",
    MapObjectLoad           =           "MapObjectLoad",
    ServerStart             =           "ServerStart",
    FullProvice             =           "FullProvice",
}

---@see 设备类型定义
---@class deviceTypeEnumClass
local DeviceType = {
    IOS                     =           1,
    ANDROID                 =           2,
    PC                      =           3,
}
Enum.DeviceType = DeviceType

---@see 语言类型
---@class languageTypeEnumClass
local LanguageType = {
    ---@see 全部语言
    ALL                     =               0,
    ---@see 中文
    CHINESE                 =               40,
    ---@see 英语
    ENGLISH                 =               10,
    ---@see 阿拉伯语
    ARABIC                  =               1,
    ---@see 土耳其语
    TURKEY                  =               37,
}
Enum.LanguageType = LanguageType

---@see Table类型定义
---@class tableTypeEnumClass
local TableType = {
    CONFIG 						= 			"config",
    USER						=			"user",
    COMMON						=			"common",
    ROLE                        =           "role",
}
Enum.TableType = TableType

---@see DB类型定义
---@class dbTypeEnumClass
local DbType = {
    MYSQL				=			"mysql",
    MONGO				=			"mongo",
}
Enum.DbType = DbType

---@see 使用的数据库
Enum.G_DBTYPE           =           skynet.getenv("dbtype") or Enum.DbType.MYSQL

---@see 登陆状态
---@class loginStatusEnumClass
local LoginState = {
    ---@see 预登陆阶段
    PRELOGIN		=			0,
    ---@see 登陆完成
    OK				=			1,
    ---@see 离线状态
    AFK				=			2,
}
Enum.LoginState = LoginState

---@see 维护类型
---@class maintainTypeEnumClass
local MaintainType = {
    ---@see 正常维护
    NORMAL                  =           1,
    ---@see 紧急维护
    URGENT                  =           2,
    ---@see 立刻维护
    RIGHTNOW                =           3,
}
Enum.MaintainType = MaintainType

---@see 踢人枚举
---@class systemKickEnumClass
local SystemKick = {
    ---@see 心跳超时
    HEART_TIMEOUT           =           1,
    ---@see 服务器关闭
    SERVER_CLOSE            =           2,
    ---@see 重复登陆
    REPLACE                 =           3,
    ---@see 封号被踢出
    BAN                     =           4,
    ---@see accesstoken失效
    TOKEN_INVALID           =           5,
    ---@see 移民踢出
    IMMIGRATE_KICK          =           6,
    ---@see 运营后台踢出
    KICK_WEB                =           7,
}
Enum.SystemKick = SystemKick

---@see 系统配置数据枚举
---@class systemCfgEnumClass
local SystemCfg = {
    ---@see 系统最后跨天时间
    LAST_CROSS_DAY          =           1,
}
Enum.SystemCfg = SystemCfg

---@see 游戏gameId
---@class gameIdEnumClass
local GameID = {
    ---@see 安卓英文
    ANDROID_EN              =           10970102021,
    ---@see 安卓阿语
    ANDROID_ARB             =           10971802021,
    ---@see 安卓中文
    ANDROID_CN              =           10971902021,
    ---@see 安卓土耳其
    ANDROID_TUR             =           10971602021,
    ---@see IOS英文
    IOS_EN                  =           10970103031,
    ---@see IOS阿语
    IOS_ARB                 =           10971803031,
    ---@see IOS中文
    IOS_CN                  =           10971903031,
    ---@see IOS土耳其
    IOS_TUR                 =           10971603031,
}
Enum.GameID = GameID

---@see 系统功能ID
---@class SystemIdEnumClass
local SystemId = {
    ---@see 安卓英文
    MENU_HERO               =           10000,
    ---@see 菜单.联盟
    MENU_GUILD              =           10001,
    ---@see 菜单.道具
    MENU_ITEM               =           10002,
    ---@see 菜单.战役
    MENU_BATTLE             =           10003,
    ---@see 菜单.邮件
    MENU_EMAIL              =           10004,
    ---@see 战役.远征
    EXPEDITION              =           10005,
    ---@see 战役.埃及之战
    EGYPT_BATTLE            =           10006,
    ---@see 战役.日落峡谷
    SUNSET_GORGE            =           10007,
    ---@see 战役.失落峡谷
    LOSE_GORGE              =           10008,
    ---@see 战役.奥西里斯联赛
    OSIRIS                  =           10009,
    ---@see 基础排行榜
    BASE_RANK               =           20001,
    ---@see 充值.充值活动入口
    RECHARGE                =           30001,
    ---@see 联盟.留言板
    GUILD_MESSAGE_BOARD     =           40001,
}
Enum.SystemId = SystemId

---@see 服务忙碌类型
------@class ServiceBusyTypeEnumClass
local ServiceBusyType = {
    ---@see 联盟服务
    GUILD                   =           1,
}
Enum.ServiceBusyType = ServiceBusyType