--[[
* @file : GuildDef.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Apr 07 2020 17:41:34 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定义联盟相关属性结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildDef = {}

---@class defaultGuildAttrClass
local defaultGuildAttr = {
    guildId                     =       0,                          -- 联盟ID
    name                        =       "",                         -- 联盟名称
    abbreviationName            =       "",                         -- 联盟简称
    notice                      =       "",                         -- 联盟公告
    needExamine                 =       true,                       -- 加入联盟是否需要审批
    languageId                  =       0,                          -- 语言id
    signs                       =       {},                         -- 联盟标志
    leaderRid                   =       0,                          -- 盟主角色id
    leaderName                  =       "",                         -- 盟主名称
    power                       =       0,                          -- 联盟战力
    giftLevel                   =       1,                          -- 联盟礼物等级
    members                     =       {},                         -- 联盟成员列表
    createTime                  =       0,                          -- 创建时间
    memberLimit                 =       0,                          -- 成员上限
    gameNode                    =       "",                         -- 联盟所属game服
    applys                      =       {},                         -- 联盟申请信息
    invites                     =       {},                         -- 联盟邀请的角色ID信息
    guildOfficers               =       {},                         -- 联盟官员信息
    currencies                  =       {},                         -- 联盟货币信息
    consumeRecords              =       {},                         -- 联盟货币消耗记录
    requestHelps                =       {},                         -- 联盟求助信息
    foodPoint                   =       0,                          -- 联盟农田数量
    woodPoint                   =       0,                          -- 联盟木材数量
    stonePoint                  =       0,                          -- 联盟石矿数量
    goldPoint                   =       0,                          -- 联盟金币数量
    welcomeEmail                =       "",                         -- 欢迎邮件内容
    monumentInfo                =       {},                         -- 纪念碑内容
    territory                   =       0,                          -- 联盟领土数量
    resourcePoints              =       {},                         -- 联盟资源点数量
    territoryLimit              =       0,                          -- 领土上限
    technologies                =       {},                         -- 联盟科技信息
    recommendTechnologyType     =       0,                          -- 推荐的联盟科技类型
    researchTechnologyType      =       0,                          -- 研究中的科技子类型
    researchTime                =       0,                          -- 研究开始时间
    dailyDonates                =       {},                         -- 角色每天的科技捐献值
    weekDonates                 =       {},                         -- 角色每周的科技捐献值
    messageBoardStatus          =       true,                       -- 联盟留言板状态
    messageFloorId              =       0,                          -- 联盟留言板当前最大ID
    giftPoint                   =       0,                          -- 礼物点数
    keyPoint                    =       0,                          -- 钥匙点数
    guildRanks                  =       {},                         -- 联盟角色排行榜数据
    welcomeEmailFlag            =       false,                      -- 是否修改过联盟欢迎邮件
    messageBoardRedDotList      =       {},                         -- 无留言板红点提示的角色列表
    territoryBuildFlag          =       false,                      -- 领土建造标识
    createIggId                 =       0,                          -- 创建联盟角色的iggId
    markers                     =       {},                         -- 联盟地图书签信息
    disbandFlag                 =       false,                      -- 联盟解散标识

    ---------------------------------------以下数据不落地-------------------------
    memberNum                   =       0,                          -- 成员数量
    guildIndex                  =       0,                          -- 联盟修改标识
    isApply                     =       false,                      -- 是否已申请加入此联盟
    isSameGame                  =       false,                      -- 是否同一个服
    leaderHeadFrameID           =       0,                          -- 盟主头像框
    messageBoardRedDot          =       false,                      -- 留言板红点提示
}

---@see 获取联盟默认属性
---@return defaultGuildAttrClass
function GuildDef:getDefaultGuildAttr()
    return const( table.copy( defaultGuildAttr ) )
end

return GuildDef