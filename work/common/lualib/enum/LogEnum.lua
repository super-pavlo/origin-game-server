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

---@see 行为日志类型
---@class LogTypeEnumClass
local LogType = {
    ---@see 通过奖励组功能直接获得货币
    PACKAGE_GAIN_CURRENCY               =               10001,
    ---@see 通过邮件领取对应的货币
    EMAIL_GAIN_CURRENCY                 =               10002,
    ---@see 资源兑换界面.使用或批量使用资源道具获得货币
    RESOURCE_CHANGE_GAIN_CURRENCY       =               10003,
    ---@see 资源补足界面.使用或批量使用资源道具获得货币
    RESOURCE_SUPPLY_GAIN_CURRENCY       =               10004,
    ---@see 背包中直接使用或批量使用资源道具获得货币
    BAG_ITEM_USE_GAIN_CURRENCY          =               10005,
    ---@see 建筑终止获得货币
    BUILD_STOP_GAIN_CURRENCY            =               10006,
    ---@see 训练终止获得货币
    TRAIN_STOP_GAIN_CURRENCY            =               10007,
    ---@see 晋升终止获得货币
    UPGRADE_SOLDIER_STOP_GAIN_DENAR     =               10008,
    ---@see 研究科技终止获得货币
    TECH_RESEARCH_STOP_GAIN_DENAR       =               10009,
    ---@see 城内获得货币
    CITY_GAIN_CURRENCY                  =               10010,
    ---@see 采集资源获得货币
    COLLECT_RESOURCE_GAIN_CURRENCY      =               10011,
    ---@see 取消进攻返还行动力
    CANCEL_ATTACK_GAIN_ACTION           =               10012,
    ---@see 自然恢复获得行动力
    RECOVER_GAIN_ACTION                 =               10013,
    ---@see 探索村庄获得货币
    VILLAGE_GAIN_ACTION                 =               10014,
    ---@see 第一次加入联盟获得宝石
    JOIN_GUILD_GAIN_DENAR               =               10015,
    ---@see 联盟帮助获得联盟积分
    GUILD_HELP_GAIN_POINT               =               10016,
    ---@see 联盟建筑建造获得联盟积分
    GUILD_BUILD_GAIN_POINT              =               10017,
    ---@see PVP掠夺获得货币
    PVP_GET_RESOURCE                    =               10018,
    ---@see 充值获得钻石
    RECHARGE_GAIN_DENAR                 =               10019,
    ---@see 使用道具获得vip点数
    ITEM_GAIN_VIP                       =               10020,
    ---@see 领取每日免费vip点数
    DAY_FREE_GAIN_VIP                   =               10021,
    ---@see 领取联盟领土收益获得资源
    TERRITORY_GAIN_CURRENCY             =               10022,
    ---@see 成长基金获得宝石
    FUND_GAIN_DENAR                     =               10023,
    ---@see 城市补给站获得宝石
    SUPPLY_GAIN_DENAR                   =               10024,
    ---@see 商栈运输获得货币
    TRANSPORT_GAIN_CURRENCY             =               10025,
    ---@see 商栈运输失败返还货币
    TRANSPORT_FAIL_GAIN_CURRENCY        =               10026,
    ---@see 商栈运输返回返还货币
    TRANSPORT_RETURN_GAIN_CURRENCY      =               10027,
    ---@see 使用宝石购买行动力
    BUY_ACTION_FORCE_GAIN_CURRENCY      =               10028,
    ---@see 拆除建筑增加货币
    DESTORY_BUILDING_GAIN_CURRENCY      =               10029,
    ---@see 联盟捐献获得联盟积分
    GUILD_DONATE_GAIN_CURRENCY          =               10030,
    ---@see 通过后台增加钻石
    ADD_DENAR_FROM_WEB                  =               10031,


    ---@see 资源兑换界面.购买消耗宝石
    RESOURCE_CHANGE_COST_DENAR          =               11001,
    ---@see 资源补足界面.购买消耗宝石
    RESOURCE_SUPPLY_COST_DENAR          =               11002,
    ---@see 立即升级建筑消耗宝石
    IM_BUILD_LEVEL_COST_DENAR           =               11003,
    ---@see 立即训练士兵消耗宝石
    IM_TRAIN_SOLDIER_COST_DENAR         =               11004,
    ---@see 立即晋升士兵消耗宝石
    IM_UPGRADE_SOLDIER_COST_DENAR       =               11005,
    ---@see 立即研究科技消耗宝石
    IM_TECH_RESEARCH_COST_DENAR         =               11006,
    ---@see 立即治疗伤兵消耗宝石
    IM_HEAL_SOLDIER_COST_DENAR          =               11007,
    ---@see 创建建筑消耗宝石
    BUILD_CREATE_COST_DENAR             =               11008,
    ---@see 升级建筑消耗宝石
    BUILD_LEVEL_COST_DENAR              =               11009,
    ---@see 训练士兵消耗宝石
    TRAIN_SOLDIER_COST_DENAR            =               11010,
    ---@see 晋升士兵消耗宝石
    UPGRADE_SOLDIER_COST_DENAR          =               11011,
    ---@see 研究科技消耗宝石
    TECH_RESEARCH_COST_DENAR            =               11012,
    ---@see 治疗伤兵消耗宝石
    HEAL_SOLDIER_COST_DENAR             =               11013,
    ---@see 加速界面购买并使用加速道具消耗宝石
    SPEED_UP_COST_DENAR                 =               11014,
    ---@see 野蛮人战斗扣除行动力.预扣除处理时
    ATTACK_COST_ACTION                  =               11015,
    ---@see 普通商店购买消耗货币
    SHOP_COST_DENAR                     =               11016,
    ---@see 创建联盟消耗宝石
    CREATE_GUILD_COST_DENAR             =               11017,
    ---@see 角色改名消耗宝石
    ROLE_MODIFY_NAME_COST_DENAR         =               11018,
    ---@see 酒馆抽卡购买并使用银钥匙道具消耗宝石
    TAVERN_OPEN_SILVER_COST_DENAR       =               11019,
    ---@see 酒馆抽卡购买并使用金钥匙道具消耗宝石
    TAVERN_OPEN_GOLD_COST_DENAR         =               11020,
    ---@see 城墙灭火消耗代币
    WALL_FIRE_DOWN_COST_DENAR           =               11021,
    ---@see 增加城市buff消耗代币
    CITY_BUFF_COST_DENAR                =               11022,
    ---@see 解锁第二建筑队列消耗代币
    UNLOCK_BUILD_QUEUE_COST_DENAR       =               11023,
    ---@see 联盟建筑灭火消耗角色代币
    REPAIR_GUILD_BUILD_COST_DENAR       =               11024,
    ---@see 购买神秘商人道具扣除货币
    BUY_POST_COST_CURRENCY              =               11025,
    ---@see 刷新神秘商人道具扣除货币
    REFRESH_POST_COST_CURRENCY          =               11026,
    ---@see 修改联盟信息消耗代币
    MODIFY_GUILD_COST_CURRENCY          =               11027,
    ---@see 迁城成功消耗代币
    MOVE_CITY_COST_CURRENCY             =               11028,
    ---@see 转换文明消耗货币
    CHANGE_CIVIL_COST_CURRENCY          =               11029,
    ---@see 购买vip商店道具消耗货币
    VIP_STORE_COST_CURRENCY             =               11030,
    ---@see 商栈运输消耗货币
    TRANSPORT_COST_CURRENCY             =               11031,
    ---@see 远征商店购买扣除货币
    EXPEDITION_SHOP_COST_CURRENCY       =               11032,
    ---@see 刷新远征商店扣除货币
    EXPEDITION_REFRESH_COST_CURRENCY    =               11033,
    ---@see 购买行动力消耗货币
    BUY_ACTION_FORCE_COST_CURRENCY      =               11034,
    ---@see 分解材料扣除货币
    MAKE_EQUIP_COST_CURRENCY            =               11035,
    ---@see 联盟捐献消耗货币
    GUILD_DONATE_COST_CURRENCY          =               11036,
    ---@see 侦查消耗货币
    SCOUT_COST_CURRENCY                 =               11037,
    ---@see 切换天赋分页扣除货币
    RESET_TALENT_COST_CURRENCY          =               11038,
    ---@see 切换天赋分页扣除货币
    CHANGE_TALENT_COST_CURRENCY         =               11039,
    ---@see 联盟商店扣除个人联盟积分
    GUILD_SHOP_COST_POINT               =               11040,
    ---@see 通过后台扣除钻石
    SUB_DENAR_FROM_WEB                  =               11041,
    ---@see 转盘消耗钻石
    TURN_TABLE_COST_DENAR               =               11042,

    ---@see 通过奖励组功能直接获得道具
    PACKAGE_GAIN_ITEM                   =               20001,
    ---@see 通过邮件领取对应的道具
    EMAIL_GAIN_ITEM                     =               20002,
    ---@see 探索村庄获得道具
    VILLAGE_GAIN_ITEM                   =               20003,
    ---@see 终止建筑升级获得道具
    STOP_BUILDING_GAIN_ITEM             =               20004,
    ---@see 普通商店购买获得道具
    SHOP_GAIN_ITEM                      =               20005,
    ---@see 统帅转换成对应道具
    HERO_GAIN_ITEM                      =               20006,
    ---@see 通用雕像兑换统帅雕像获得道具
    HERO_EXCHANGE_GAIN_ITEM             =               20007,
    ---@see 神秘商店获得道具
    POST_GAIN_ITEM                      =               20008,
    ---@see VIP商店获得道具
    VIP_STORE_GAIN_ITEM                 =               20009,
    ---@see 远征商店购买增加道具
    EXPEDITION_SHOP_GAIN_ITEM           =               20010,
    ---@see 铁匠铺生产获得道具
    SMITHY_PRODUCE_GAIN_ITEM            =               20011,
    ---@see 铁匠铺合成获得道具.材料.图纸碎片
    SMITHY_SYNTHESIS_GAIN_ITEM          =               20012,
    ---@see 铁匠铺锻造获得装备道具
    MAKE_EQUIP_GAIN_ITEM                =               20013,
    ---@see 铁匠铺分解材料获得道具
    SMITHY_DECOMPOSITION_GAIN_ITEM      =               20014,
    ---@see 铁匠铺分解装备获得道具
    DECOMPOSITION_EQUIP_GAIN_ITEM       =               20015,
    ---@see 联盟商店获得道具
    GUILD_SHOP_GAIN_ITEM                =               20016,
    ---@see 创角初始道具
    GUILD_CREATE_ROLE_GAIN_ITEM         =               20017,
    ---@see 特殊道具补足
    SPECIAL_ITEM_SUPPLY                 =               20018,
    ---@see 战损补偿道具
    BATTLE_LOSE_ITEM                    =               20019,

    ---@see 资源兑换界面.使用或批量使用资源道具
    RESOURCE_CHANGE_COST_ITEM           =               21001,
    ---@see 资源补足界面.使用或批量使用资源道具
    RESOURCE_SUPPLY_COST_ITEM           =               21002,
    ---@see 背包中直接使用或批量使用资源道具
    BAG_ITEM_USE_COST_ITEM              =               21003,
    ---@see 招募统帅消耗道具
    SUMMON_HERO_COST_ITEM               =               21004,
    ---@see 加速消耗道具
    SEPPE_COST_ITEM                     =               21005,
    ---@see 升级建筑消耗道具
    BUILDING_LEVEL_COST_ITEM            =               21006,
    ---@see 开启银箱子消耗道具
    OPEN_SILVER_BOX_COST_ITEM           =               21007,
    ---@see 开启金箱子消耗道具
    OPEN_GOLD_BOX_COST_ITEM             =               21008,
    ---@see 角色改名消耗道具
    ROLE_MODIFY_NAME_COST_ITEM          =               21009,
    ---@see 统帅技能升级消耗道具
    HERO_LEVEL_UP_COST_ITEM             =               21010,
    ---@see 兑换统帅雕像消耗通用雕像道具
    HERO_EXCHANGE_COST_ITEM             =               21011,
    ---@see 增加城市buff消耗道具
    CITY_BUFF_COST_ITEM                 =               21012,
    ---@see 使用道具增加英雄经验
    HERO_ADD_EXP_COST_ITEM              =               21013,
    ---@see 使用道具增加星级经验
    HERO_ADD_STAR_COST_ITEM             =               21014,
    ---@see 使用道具解锁第二建筑队列
    UNLOCK_BUILD_QUEUE_COST_ITEM        =               21015,
    ---@see 兑换活动扣除道具
    ACTIVITY_EXCHANGE_COST_ITEM         =               21016,
    ---@see 迁城成功消耗道具
    MOVE_CITY_COST_ITEM                 =               21017,
    ---@see 转换文明消耗道具
    CHANGE_CIVIL_COST_ITEM              =               21018,
    ---@see 市政厅升级删除新手迁城道具
    ROLE_LEVEL_DELETE_NOVICE_CITY       =               21019,
    ---@see 铁匠铺合成消耗道具
    SMITHY_SYNTHESIS_COST_ITEM          =               21020,
    ---@see 铁匠铺锻造消耗道具
    MAKE_EQUIP_COST_ITEM                =               21021,
    ---@see 铁匠铺分解材料消耗道具
    SMITHY_DECOMPOSITION_COST_ITEM      =               21022,
    ---@see 铁匠铺分解装备消耗道具
    DECOMPOSITION_EQUIP_COST_ITEM       =               21023,
    ---@see 背包直接使用道具扣除道具
    USE_BAG_ITEM_COST_ITEM              =               21024,
    ---@see 切换天赋分页扣除道具
    RESET_TALENT_COST_ITEM              =               21025,
    ---@see 切换天赋分页扣除道具
    CHANGE_TALENT_COST_ITEM             =               21026,
    ---@see 运营后台扣除道具
    DEL_ITEM_FROM_WEB                   =               21027,

    ---@see 训练完成领取士兵.包括立即完成
    TRAIN_ARMY                          =               30001,
    ---@see 晋升完成领取士兵.包括立即完成
    ARMY_LEVEL_UP_ADD                   =               30002,
    ---@see 村庄加入士兵
    ARMY_VILLAGE_ADD                    =               30003,
    ---@see 奖励组获得士兵
    PACKAGE_GAIN_ARMY                   =               30004,
    ---@see 战斗阵亡士兵
    ARMY_FIGHT_DEAD                     =               31001,
    ---@see 晋升完成扣除士兵.包括立即完成
    ARMY_LEVEL_UP_REDUCE                =               31002,
    ---@see 遣散士兵
    ARMY_REDUCE                         =               31003,

    ---@see 登陆
    ROLE_LOGIN                          =               40001,
    ---@see 登出
    ROLE_LOGOUT                         =               40002,
    ---@see 建筑创建
    BUILD_CREATE                        =               40003,
    ---@see 建筑升级
    BUILD_LEVEL_UP                      =               40004,
    ---@see 新手引导
    ROLE_GUIDE                          =               40005,
    ---@see 任务领奖
    TASK_AWARD                          =               40006,
    ---@see 创角
    ROLE_CREATE                         =               40007,
    ---@see 新手剧情日志
    NOVICE_PLOT                         =               40008,
    ---@see 创角操作日志
    CREATE_CLICK                        =               40009,
    ---@see 功能引导日志
    FUNC_GUIDE                          =               40010,
    ---@see 创建部队
    CREATE_ARMY                         =               40011,
    ---@see 解散部队
    DISBAND_ARMY                        =               40012,
    ---@see 地狱活动
    ROLE_ACTIVITYINFERNAL               =               40013,
    ---@see 征服之始日志
    ROLE_ACTIVITYDAYSTYPE               =               40014,
    ---@see 服务器纪念碑日志
    ROLE_EVOLUTION                      =               40015,
    ---@see 创角活动日志
    ROLE_NEWACTIVITYDAYSTYPE            =               40018,
    ---@see 联盟日志
    ROLE_GUILD                          =               40016,
    ---@see 奇观建筑占领
    HOLYLAND_OCCUPY                     =               40017,
    ---@see 充值日志
    ROLE_RECHARGE                       =               40021,

    ---@see 在线人数
    SERVER_ONLINE                       =               50001,

    ---@see 斥候探索迷雾
    SCOUT_DENSEFOG                      =               60001,
    ---@see 斥候侦查城市
    SCOUT_CITY                          =               60002,
    ---@see 斥候侦查部队
    SCOUT_ARMY                          =               60003,
    ---@see 斥候侦查联盟建筑
    SCOUT_GUILD_BUILD                   =               60004,
    ---@see 斥候侦查圣地关卡
    SCOUT_HOLYLAND                      =               60005,
    ---@see 斥候调查山洞
    SCOUT_CAVE                          =               60006,
    ---@see 斥候回城
    SCOUT_MARCHBACK                     =               61001,

    ---@see 创建联盟建筑事件
    GUILD_BUILD_CREATE                  =               62001,
    ---@see 玩家主动拆除联盟建筑事件
    ROLE_REMOVE_GUILD_BUILD             =               62002,
    ---@see 联盟建筑被烧毁事件
    GUILD_BUILD_BURN                    =               62003,
    ---@see 联盟建筑建造完成事件
    GUILD_BUILD_FINISH                  =               62004,
    ---@see 联盟建筑超时自动消失事件
    GUILD_BUILD_TIMEOUT                 =               62005,
    ---@see 联盟解散拆除建筑
    DISBAND_GUILD_REMOVE_BUILD          =               62006,

    ---@see 部队进入联盟建筑建造
    ARMY_JOIN_GUILD_BUILD               =               63001,
    ---@see 部队离开联盟建筑建造
    ARMY_LEAVE_GUILD_BUILD              =               63002,

    ---@see 部队行军
    ROLE_ARMY_MARCH                     =               64001,
}
Enum.LogType = LogType