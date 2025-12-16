--[[
* @file : GuildTechnologyLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue May 19 2020 20:35:07 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟科技相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"
local ItemLogic = require "ItemLogic"

local GuildTechnologyLogic = {}

---@see 推送联盟科技信息
function GuildTechnologyLogic:pushGuildTechnology( _rid, _guildId )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0

    if _guildId > 0 then
        local guildInfo = GuildLogic:getGuild( _guildId, {
            Enum.Guild.technologies, Enum.Guild.recommendTechnologyType,
            Enum.Guild.researchTechnologyType, Enum.Guild.researchTime,
            Enum.Guild.dailyDonates
        } )

        Common.syncMsg( _rid, "Guild_GuildTechnologies", {
            technologies = guildInfo.technologies,
            recommendTechnologyType = guildInfo.recommendTechnologyType,
            researchTechnologyType = guildInfo.researchTechnologyType,
            researchTime = guildInfo.researchTime,
            donateNum = guildInfo.dailyDonates and guildInfo.dailyDonates[_rid] and guildInfo.dailyDonates[_rid].donateNum or 0
        } )
    end
end

---@see 通知联盟科技信息
function GuildTechnologyLogic:syncGuildTechnology( _toRids, _technologies, _recommendTechnologyType, _researchTechnologyType, _researchTime, _donateNum )
    Common.syncMsg( _toRids, "Guild_GuildTechnologies", {
        technologies = _technologies,
        recommendTechnologyType = _recommendTechnologyType,
        researchTechnologyType = _researchTechnologyType,
        researchTime = _researchTime,
        donateNum = _donateNum,
    } )
end

---@see 联盟科技捐献跨天发放奖励
function GuildTechnologyLogic:resetMemberDailyDonates( _guildId )
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.dailyDonates, Enum.Guild.members } ) or {}
    local dailyDonates = guildInfo.dailyDonates or {}
    local newDailyDonates = {}
    local sConfig = CFG.s_Config:Get()
    -- 获取贡献值达到设定值的角色
    for _, donateInfo in pairs( dailyDonates ) do
        if donateInfo.donateNum >= sConfig.AllianceDailyUpperLimit then
            table.insert( newDailyDonates, donateInfo )
        end
    end

    -- 按照贡献值和捐献时间排序
    table.sort( newDailyDonates, function ( a, b )
        if a.donateNum == b.donateNum then
            return a.donateTime < b.donateTime
        else
            return a.donateNum > b.donateNum
        end
    end )

    -- 整理排行榜前30
    local donateRanks = {}
    local sAllianceDonateRanking = CFG.s_AllianceDonateRanking:Get( Enum.GuildDonateRankType.DAILY ) or {}
    for index, donateInfo in pairs( newDailyDonates ) do
        if index > sConfig.AllianceDailyRankNum then
            break
        end
        -- 发放奖励
        for _, donateRank in pairs( sAllianceDonateRanking ) do
            if donateRank.targetMin <= index and index <= donateRank.targetMax then
                ItemLogic:getItemPackage( donateInfo.rid, donateRank.itemPackage )
                break
            end
        end
        table.insert( donateRanks, {
            name = RoleLogic:getRole( donateInfo.rid, Enum.Role.name ),
            donateNum = donateInfo.donateNum
        } )
    end

    if #donateRanks > 0 then
        -- 发放奖励邮件
        local emailOtherInfo = {
            emailContents = { CFG.s_Config:Get( "AllianceDailyUpperLimit" ) },
            guildEmail = {
                roleDonates = donateRanks,
            }
        }
        MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, guildInfo.members or {}, 300015, emailOtherInfo )
    end

    -- 更新每日捐献信息
    GuildLogic:setGuild( _guildId, { [Enum.Guild.dailyDonates] = {} } )
end

---@see 联盟科技捐献每周奖励发放
function GuildTechnologyLogic:resetMemberWeekDonates( _guildId )
    local RankLogic = require "RankLogic"

    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.weekDonates } )
    local weekDonates = guildInfo.weekDonates or {}
    local members = guildInfo.members or {}
    local newWeekDonates = {}
    local sConfig = CFG.s_Config:Get()
    -- 获取贡献值达到设定值的角色
    for memberRid, donateInfo in pairs( weekDonates ) do
        if donateInfo.donateNum >= sConfig.AllianceWeeklyUpperLimit then
            table.insert( newWeekDonates, donateInfo )
        end
        if members[memberRid] then
            -- 角色还在联盟中
            RankLogic:update( memberRid, Enum.RankType.ALLIACEN_ROLE_DONATE, 0, _guildId )
        else
            -- 角色不在联盟中，删除角色排行榜信息
            RankLogic:delete( memberRid, Enum.RankType.ALLIACEN_ROLE_DONATE, _guildId )
        end
    end

    -- 按照贡献值和捐献时间排序
    table.sort( newWeekDonates, function ( a, b )
        if a.donateNum == b.donateNum then
            return a.donateTime < b.donateTime
        else
            return a.donateNum > b.donateNum
        end
    end )

    -- 整理排行榜前30
    local donateRanks = {}
    local sAllianceDonateRanking = CFG.s_AllianceDonateRanking:Get( Enum.GuildDonateRankType.WEEK ) or {}
    for index, donateInfo in pairs( newWeekDonates ) do
        if index > sConfig.AllianceWeeklyRankNum then
            break
        end
        -- 发放奖励
        for _, donateRank in pairs( sAllianceDonateRanking ) do
            if donateRank.targetMin <= index and index <= donateRank.targetMax then
                ItemLogic:getItemPackage( donateInfo.rid, donateRank.itemPackage )
                break
            end
        end
        table.insert( donateRanks, {
            name = RoleLogic:getRole( donateInfo.rid, Enum.Role.name ),
            donateNum = donateInfo.donateNum
        } )
    end

    if #donateRanks > 0 then
        -- 发放奖励邮件
        local emailOtherInfo = {
            emailContents = { CFG.s_Config:Get( "AllianceWeeklyUpperLimit" ) },
            guildEmail = {
                roleDonates = donateRanks,
            }
        }
        MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, guildInfo.members or {}, 300016, emailOtherInfo )
    end

    -- 更新每周捐献信息
    GuildLogic:setGuild( _guildId, { [Enum.Guild.weekDonates] = {} } )
end

---@see 跨天处理全部联盟的捐献奖励
function GuildTechnologyLogic:resetGuildDailyDonate()
    local centerNode = Common.getCenterNode()
    -- 本服所有联盟ID
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
    for guildId in pairs( guildIds ) do
        MSM.GuildMgr[guildId].post.resetGuildDailyDonate( guildId )
    end
end

---@see 跨周处理全部联盟的捐献奖励
function GuildTechnologyLogic:resetGuildWeekDonate()
    local centerNode = Common.getCenterNode()
    -- 本服所有联盟ID
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
    for guildId in pairs( guildIds ) do
        MSM.GuildMgr[guildId].post.resetGuildWeekDonate( guildId )
    end
end

return GuildTechnologyLogic