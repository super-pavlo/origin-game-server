--[[
* @file : RoleDef.lua
* @type : lualib
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定义角色相关属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local AttrDef = require "AttrDef"
local RoleDef = {}

---@class defaultRoleAttrClass
local defaultRoleAttr = {
    iggid                       =       "",                         -- 角色iggid
    uid                         =       0,                          -- 角色uid
    rid                         =       0,                          -- 角色rid
    createTime                  =       0,                          -- 创角时间
    level                       =       0,                          -- 角色等级
    name                        =       "",                         -- 角色名字
    map                         =       0,                          -- 当前所在地图
    pos                         =       { x = 0, y = 0 },           -- 当前所在位置
    country                     =       0,                          -- 国家
    headId                      =       0,                          -- 头像ID
    buildQueue                  =       {},                         -- 玩家拥有的建筑队列
    armies                      =       {},                         -- 废置
    actionForce                 =       0,                          -- 行动力
    food                        =       0,                          -- 粮食
    wood                        =       0,                          -- 木材
    stone                       =       0,                          -- 石料
    gold                        =       0,                          -- 金币
    denar                       =       0,                          -- 宝石
    armyQueue                   =       {},                         -- 玩家拥有的训练队列
    cityId                      =       0,                          -- 城堡ID
    technologies                =       {},                         -- 科技信息
    mainLineTaskId              =       0,                          -- 主线任务ID
    buildVersion                =       0,                          -- 建筑版本
    finishSideTasks             =       {},                         -- 已完成并领取奖励的支线任务列表
    taskStatisticsSum           =       {},                         -- 任务累计统计信息
    taskStatisticsDaily         =       {},                         -- 弃用
    technologyQueue             =       {},                         -- 研究队列
    treatmentQueue              =       {},                         -- 治疗队列
    seriousInjured              =       {},                         -- 重伤士兵
    historyPower                =       0,                          -- 角色历史最高战力
    roleStatistics              =       {},                         -- 角色统计信息
    soldierKills                =       {},                         -- 士兵击杀信息
    chapterId                   =       0,                          -- 当前的章节ID，0为无章节任务
    chapterTasks                =       {},                         -- 章节任务信息
    soldiers                    =       {},                         -- 士兵信息
    noviceGuideStep             =       0,                          -- 新手引导步骤
    noviceGuideStepEx           =       0,                          -- 新手引导步骤Ex
    rallies                     =       {},                         -- 集结信息
    denseFog                    =       {},                         -- 迷雾信息
    resourceBuildFirst          =       false,                      -- 资源建筑是否第一次创建
    lastCrossDayTime            =       0,                          -- 上次跨天时间
    situStation                 =       false,                      -- true 原地驻扎
    barbarianLevel              =       0,                          -- 击杀的野蛮人最高等级
    emailVersion                =       0,                          -- 邮件版本号
    lastActionForceTime         =       0,                          -- 上次获得行动力时间
    createVersion               =       "",                         -- 创角版本
    language                    =       0,                          -- 客户端当前语言
    testGroup                   =       0,                          -- 测试分组
    platform                    =       0,                          -- 设备平台
    version                     =       "",                         -- 当前版本
    villageCaves                =       {},                         -- 山洞村庄探索信息
    killCount                   =       {},                         -- 击杀数量
    combatPower                 =       0,                          -- 当前战力
    lastLogoutTime              =       0,                          -- 最后登出时间
    lastLoginTime               =       0,                          -- 最后登陆时间
    allLoginTime                =       0,                          -- 累计在线时长
    todayLoginTime              =       0,                          -- 本日在线时长
    scoutDenseFogFlag           =       {},                         -- 迷雾是否探索标识
    isChangeAge                 =       false,                      -- 时代是否变迁
    buildMailId                 =       {},                         -- 升级建筑发送邮件
    silverFreeCount             =       0,                          -- 白银宝箱免费次数
    openNextSilverTime          =       0,                          -- 下次开启白银宝箱时间
    goldFreeCount               =       0,                          -- 金箱子免费次数
    addGoldFreeAddTime          =       0,                          -- 下次增加金箱子免费次数时间
    activePoint                 =       0,                          -- 活跃度
    activePointRewards          =       {},                         -- 已领取奖励的活跃度值
    dailytaskAge                =       0,                          -- 每日任务时代
    guildId                     =       0,                          -- 联盟ID
    guildJob                    =       0,                          -- 联盟职位
    lastGuildId                 =       0,                          -- 上个联盟ID
    mainHeroId                  =       0,                          -- 当前主将ID
    deputyHeroId                =       0,                          -- 当前副将ID
    userMainHeroId              =       0,                          -- 玩家选择的主将
    userDeputyHeroId            =       0,                          -- 玩家选择的副将
    cityBuff                    =       {},                         -- 城市buff
    guildOfficialId             =       0,                          -- 弃用
    activity                    =       {},                         -- 活动信息
    guildPoint                  =       0,                          -- 联盟个人积分
    guildHelpPoint              =       0,                          -- 今日帮助获得的积分
    headList                    =       {},                         -- 拥有头像列表
    headFrameList               =       {},                         -- 拥有的头像框列表
    headFrameID                 =       0,                          -- 头像框ID
    maxChatUniqueIndex          =       {},                         -- 消息已读信息
    chatNoDisturbFlag           =       false,                      -- 消息免打扰
    guildBuildPoint             =       0,                          -- 角色今日联盟建造获得的个人积分
    chatNoDisturbInfo           =       {},                         -- 消息免打扰
    guardTowerHp                =       0,                          -- 警戒塔生命值
    mysteryStore                =       {},                         -- 神秘商人
    mysteryRefreshTime          =       0,                          -- 神秘商人刷新时间
    vip                         =       0,                          -- vip经验
    continuousLoginDay          =       0,                          -- 连续登陆次数
    vipFreeBox                  =       false,                      -- vip专属礼包当日是否领取过
    vipSpecialBox               =       {},                         -- 特别尊享礼包，购买过的存VIP等级
    vipExpFlag                  =       false,                      -- vip每日点数奖励是否领取
    riseRoad                    =       0,                          -- 崛起之路进度
    recharge                    =       {},                         -- 充值信息
    freeDaily                   =       false,                      -- 每日特惠免费宝箱领取进度
    applyGuildIds               =       {},                         -- 已申请的联盟列表
    monumentInfo                =       {},                         -- 纪念碑相关信息
    rechargeFirst               =       false,                      -- 首充
    denseFogOpenFlag            =       false,                      -- 迷雾是否全开
    denseFogOpenTime            =       0,                          -- 迷雾全开时间
    rechargeInfo                =       {},                         -- 充值信息
    dailyPackage                =       {},                         -- 每日特惠礼包
    riseRoadPackage             =       {},                         -- 崛起之路
    rechargeSale                =       {},                         -- 超值礼包
    growthFund                  =       false,                      -- 是否购买了成长基金
    growthFundReward            =       {},                         -- 成长基金领取列表
    supply                      =       {},                         -- 城市补给站
    limitTimePackage            =       {},                         -- 限时礼包
    battleNum                   =       0,                          -- 战斗数量
    battleLostPower             =       0,                          -- 损失战力
    vipStore                    =       {},                         -- vip商店
    expedition                  =       {},                         -- 远征商店信息
    expeditionCoin              =       0,                          -- 远征币
    buyActionForceCount         =       0,                          -- 今日购买行动力次数
    wallHpNotify                =       false,                      -- 城墙耐久为0迁城通知
    materialQueue               =       {},                         -- 铁匠铺生产队列
    reinforces                  =       {},                         -- 盟友增援信息
    lastGuildDonateTime         =       0,                          -- 上次联盟捐献时间
    guildDonateCostDenar        =       0,                          -- 使用宝石捐献需要的宝石数量
    joinGuildTime               =       0,                          -- 加入联盟时间
    reinforceRecord             =       {},                         -- 增援城市记录
    praiseFlag                  =       false,                      -- 是否点击过好评
    limitPackageCount           =       {},                         -- 限时礼包触发次数(废弃)
    silence                     =       0,                          -- 禁言到期时间
    gameId                      =       0,                          -- 角色gameId
    maxSystemEmailIndex         =       0,                          -- 已发送最大系统邮件ID
    lastCleanGuildGiftTime      =       0,                          -- 上次清除联盟过期和已领取礼物的时间
    historySoldiers             =       {},                         -- 远征历史士兵数据
    expeditionInfo              =       {},                         -- 远征信息
    pushSetting                 =       {},                         -- 推送设置
    eventTrancking              =       0,                          -- 广告埋点
    firstOpenGold               =       false,                      -- 是否首次打开金箱子
    storeNotice                 =       false,                      -- 神秘商店通知
    roleHelpGuildPoint          =       0,                          -- 角色帮助联盟获得的积分
    itemAddTroopsCapacity       =       0,                          -- 预备部队增加容量
    itemAddTroopsCapacityCount  =       0,                          -- 预备部队层数
    markers                     =       {},                         -- 个人标记信息
    activityActivePoint         =       0,                          -- 新手活动活跃度
    newActivityOpenTime         =       0,                          -- 新手活动开启时间
    lastArmyIndex               =       0,                          -- 上次派遣的部队索引
    newLimitPackageCount        =       {},                         -- 限时礼包触发次数
    lastInactiveEmailTime       =       0,                          -- 上次发送不活跃成员邮件时间
    abTestGroup                 =       {},                         -- AB测试分组
    rechargeDollar              =       0,                          -- 玩家累计充值美分
    battleLostPowerCD           =       0,                          -- 战损CD到期时间
    battleLostPowerValue        =       0,                          -- 战损的数值
    lastBattlePvPRoleName       =       "",                         -- 最后PVP战斗的角色名字(用于战损援助)
    usedMoveCityTypes           =       {},                         -- 角色已使用过的迁城道具类型
    ---------------------------------------以下数据不落地-------------------------
    requestEmail                =       false,                      -- 是否请求过邮件信息
    ip                          =       "",                         -- 客户端IP
    phone                       =       "",                         -- 客户端手机机型
    area                        =       "",                         -- 客户端所在地区
    quality                     =       "",                         -- 客户端画质
    memory                      =       "",                         -- 客户端内存
    fps                         =       0,                          -- 客户端fps
    network                     =       "",                         -- 客户端网络
    power                       =       0,                          -- 剩余电量
    chargeStatus                =       0,                          -- 充电状态
    volume                      =       0,                          -- 客户端音量
    online                      =       false,                      -- 角色在线标记(未完全登出)
    fd                          =       0,                          -- 角色fd
    secret                      =       "",                         -- 角色密钥
    isAfk                       =       false,                      -- 判断角色是否在线
    guildInvite                 =       false,                      -- 已邀请加入联盟
    guildIndexs                 =       {},                         -- 联盟信息修改标识
    focusBuildObject            =       {},                         -- 角色关注的地图建筑对象信息
    activityTimeInfo            =       {},                         -- 活动时间信息
    exclusive                   =       false,                      -- 本次锻造是否是专属装备
    mapIndex                    =       0,                          -- 远征地图索引
    expeditionTime              =       0,                          -- 远征开始时间
    expeditionId                =       0,                          -- 远征章节id
    combatPowerType             =       0,                          -- 角色战力变化类型
    inPreview                   =       false,                      -- 角色当前是否在预览层
    ttl                         =       0,                          -- CS延迟(毫秒)
    emailSendCntPerHour         =       0,                          -- 每小时已发送邮件数量
    lastEmailSendTime           =       0,                          -- 上次邮件发送时间
}

---@class defaultRoleTimerClass
local defaultRoleTimerInfo = {
    func                    =           "",                         -- 回调函数
    args                    =           {},                         -- 回调参数
    interval                =           0,                          -- 回调间隔
    isLogoutDelete          =           true,                       -- 是否离线移除
}

---@see 获取角色默认属性
---@return defaultRoleAttrClass
function RoleDef:getDefaultRoleAttr()
    local roleBaseAttr = AttrDef:getDefaultAttr()
    table.mergeEx( defaultRoleAttr, roleBaseAttr )
    return const( table.copy( defaultRoleAttr ) )
end

---@see 获取角色定时器属性
---@return defaultRoleTimerClass
function RoleDef:getDefaultRoleTimerInfo()
    return const( table.copy( defaultRoleTimerInfo ) )
end

return RoleDef