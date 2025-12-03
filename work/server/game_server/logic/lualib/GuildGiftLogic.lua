--[[
* @file : GuildGiftLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri May 29 2020 10:37:18 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟礼物相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"
local GuildGiftDef = require "GuildGiftDef"
local ItemLogic = require "ItemLogic"
local RoleSync = require "RoleSync"

local GuildGiftLogic = {}

---@see 获取联盟礼物指定数据
function GuildGiftLogic:getGuildGift( _guildId, _giftIndex, _fields )
    return SM.c_guild_gift.req.Get( _guildId, _giftIndex, _fields )
end

---@see 更新联盟礼物指定数据
function GuildGiftLogic:setGuildGift( _guildId, _giftIndex, _fields, _data )
    return SM.c_guild_gift.req.Set( _guildId, _giftIndex, _fields, _data )
end

---@see 获取联盟礼物最大索引
function GuildGiftLogic:getGiftMaxIndex( _guildId )
    local giftMaxIndex = 0
    local gifts = self:getGuildGift( _guildId ) or {}
    for index in pairs( gifts ) do
        if index > giftMaxIndex then
            giftMaxIndex = index
        end
    end

    return giftMaxIndex
end

---@see 发放联盟礼物
function GuildGiftLogic:sendGuildGift( _guildId, _giftIndex, _giftType, _buyRid, _isHideName, _packageNameId, _sendType, _giftArgs )
    local giftLevel = GuildLogic:getGuild( _guildId, Enum.Guild.giftLevel )
    local sAllianceGiftType = CFG.s_AllianceGiftType:Get( _giftType )
    if not sAllianceGiftType or table.empty( sAllianceGiftType ) then
        LOG_ERROR("guildId(%d) add guild gift failed, no giftType(%d) cfg", _guildId, _giftType)
        return
    end
    -- 检查礼物是否超过上限
    self:checkGuildGiftRecordLimit( _guildId )
    -- 礼物信息
    local giftInfo = GuildGiftDef:getDefaultGuildGiftAttr()
    giftInfo.giftIndex = _giftIndex
    giftInfo.giftType = Enum.GuildGiftType.GIFT
    giftInfo.giftId = _giftType * 1000
    if sAllianceGiftType.levelFlag == Enum.GuildGiftLevel.YES then
        giftInfo.giftId = giftInfo.giftId + giftLevel
    end

    giftInfo.sendTime = os.time()
    if _buyRid and _buyRid > 0 then
        giftInfo.sendType = Enum.GuildGiftSendType.BUY_GIFT
        if not _isHideName then
            giftInfo.buyRoleName = RoleLogic:getRole( _buyRid, Enum.Role.name )
        end
        giftInfo.packageNameId = _packageNameId or 0
    end

    if _sendType then
        giftInfo.sendType = _sendType
    end
    giftInfo.giftArgs = _giftArgs or {}

    -- 添加到联盟礼物表
    SM.c_guild_gift.req.Add( _guildId, _giftIndex, giftInfo )
    giftInfo.status = Enum.GuildGiftStatus.NO_RECEIVE

    -- 通知联盟在线成员
    local memberRids = GuildLogic:getAllOnlineMember( _guildId )
    if #memberRids > 0 then
        giftInfo.status = Enum.GuildGiftStatus.NO_RECEIVE
        self:syncGuildGifts( memberRids, nil, nil, nil, { [_giftIndex] = giftInfo } )
    end
end

---@see 发送联盟珍藏
function GuildGiftLogic:sendGuildTreasure( _guildId, _giftIndex, _treasureId )
    -- 珍藏信息
    local nowTime = os.time()
    local giftInfo = GuildGiftDef:getDefaultGuildGiftAttr()
    giftInfo.giftIndex = _giftIndex
    giftInfo.giftType = Enum.GuildGiftType.TREASURE
    giftInfo.treasureId = _treasureId
    giftInfo.sendTime = nowTime
    -- 添加到联盟礼物表
    SM.c_guild_gift.req.Add( _guildId, _giftIndex, giftInfo )

    return { [_giftIndex] = {
        giftIndex = _giftIndex, treasureId = _treasureId, sendTime = nowTime
    } }
end

---@see 推送联盟礼物信息
function GuildGiftLogic:pushGuildGifts( _rid )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.joinGuildTime } )
    local guildId = roleInfo.guildId or 0
    if guildId <= 0 then return end

    local lastTime
    local giftNum = 0
    local gifts = {}
    local treasures = {}
    local nowTime = os.time()
    local guildGifts = self:getGuildGift( guildId ) or {}
    local guildInfo = GuildLogic:getGuild( guildId, { Enum.Guild.giftPoint, Enum.Guild.keyPoint } )
    for giftIndex, giftInfo in pairs( guildGifts ) do
        if giftInfo.sendTime >= roleInfo.joinGuildTime then
            if giftInfo.giftType == Enum.GuildGiftType.GIFT and not table.exist( giftInfo.cleanRids or {}, _rid ) then
                -- 礼物
                gifts[giftIndex] = {
                    giftIndex = giftIndex,
                    giftId = giftInfo.giftId,
                    sendTime = giftInfo.sendTime,
                    sendType = giftInfo.sendType,
                    buyRoleName = giftInfo.buyRoleName,
                    packageNameId = giftInfo.packageNameId,
                    giftArgs = giftInfo.giftArgs,
                }
                -- 礼物领取状态
                if giftInfo.receives[_rid] then
                    gifts[giftIndex].status = Enum.GuildGiftStatus.RECEIVE
                    gifts[giftIndex].itemId = giftInfo.receives[_rid].itemId
                    gifts[giftIndex].itemNum = giftInfo.receives[_rid].itemNum
                else
                    gifts[giftIndex].status = Enum.GuildGiftStatus.NO_RECEIVE
                end
                giftNum = giftNum + 1
                -- 联盟礼物分批推送
                if giftNum > 100 then
                    self:syncGuildGifts( _rid, nil, nil, nil, gifts, nil, true, true )
                    gifts = {}
                    giftNum = 0
                end
            elseif giftInfo.giftType == Enum.GuildGiftType.TREASURE then
                lastTime = CFG.s_AllianceTreasure:Get( giftInfo.treasureId, "lastTime" )
                if not giftInfo.receives[_rid] and giftInfo.sendTime + lastTime >= nowTime then
                    -- 珍藏
                    treasures[giftIndex] = {
                        giftIndex = giftIndex,
                        treasureId = giftInfo.treasureId,
                        sendTime = giftInfo.sendTime,
                    }
                end
            end
        end
    end

    -- 推送联盟礼物信息
    self:syncGuildGifts( _rid, guildInfo.giftPoint, guildInfo.keyPoint, treasures, gifts )
end

---@see 更新联盟礼物信息
function GuildGiftLogic:syncGuildGifts( _toRids, _giftPoint, _keyPoint, _treasures, _gifts, _deleteGiftIndexs, _block, _sendNow )
    -- 推送信息
    Common.syncMsg( _toRids, "Guild_GuildGifts",  {
        giftPoint = _giftPoint,
        keyPoint = _keyPoint,
        treasures = _treasures,
        gifts = _gifts,
        deleteGiftIndexs = _deleteGiftIndexs,
    }, _block, _sendNow )
end

---@see 领取珍藏
function GuildGiftLogic:takeTreasure( _guildId, _rid )
    local rewards = {}
    local deleteGiftIndexs = {}
    local nowTime = os.time()
    local rewardInfo, rewardGroupId, lastTime
    local joinGuildTime = RoleLogic:getRole( _rid, Enum.Role.joinGuildTime )
    local gifts = self:getGuildGift( _guildId ) or {}
    for giftIndex, giftInfo in pairs( gifts ) do
        -- 角色可以领取的珍藏
        if giftInfo.giftType == Enum.GuildGiftType.TREASURE and giftInfo.sendTime >= joinGuildTime
            and not giftInfo.receives[_rid] then
            lastTime = CFG.s_AllianceTreasure:Get( giftInfo.treasureId, "lastTime" )
            -- 珍藏是否已超时
            if giftInfo.sendTime + lastTime >= nowTime then
                -- 更新角色领取状态
                giftInfo.receives[_rid] = { rid = _rid, receiveTime = nowTime }
                self:setGuildGift( _guildId, giftIndex, { [Enum.GuildGift.receives] = giftInfo.receives } )
                -- 角色获取奖励
                rewardGroupId = CFG.s_AllianceTreasure:Get( giftInfo.treasureId, "reward" )
                rewardInfo = ItemLogic:getItemPackage( _rid, rewardGroupId ) or {}
                ItemLogic:mergeReward( rewards, rewardInfo )
                table.insert( deleteGiftIndexs, giftIndex )
            end
        end
    end

    -- 通知角色删除珍藏索引
    if #deleteGiftIndexs > 0 then
        self:syncGuildGifts( _rid, nil, nil, nil, nil, deleteGiftIndexs, true )
    end

    return rewards
end

---@see 一键领取联盟普通礼物
function GuildGiftLogic:takeNormalGifts( _guildId, _rid, _maxGiftIndex )
    local rewards = {}
    local syncGifts = {}
    local nowTime = os.time()
    local addGiftPoint = 0
    local addKeyPoint = 0
    local allRewards = {}
    local lastTime, rewardInfo, itemId, itemNum, sGiftReward, giftGroup
    local joinGuildTime = RoleLogic:getRole( _rid, Enum.Role.joinGuildTime )
    local gifts = self:getGuildGift( _guildId ) or {}
    local sAllianceGiftType = CFG.s_AllianceGiftType:Get()
    local sAllianceGiftReward = CFG.s_AllianceGiftReward:Get()
    local count = 0

    for giftIndex, giftInfo in pairs( gifts ) do
        -- 角色可以领取的普通礼物
        if giftInfo.giftType == Enum.GuildGiftType.GIFT and giftInfo.sendTime >= joinGuildTime
            and not giftInfo.receives[_rid] then
            sGiftReward = sAllianceGiftReward[giftInfo.giftId]
            if sGiftReward.giftType then
                lastTime = sAllianceGiftType[sGiftReward.giftType] and sAllianceGiftType[sGiftReward.giftType].lastTime
                giftGroup = sAllianceGiftType[sGiftReward.giftType] and sAllianceGiftType[sGiftReward.giftType].group
                -- 是否已超时
                if lastTime and giftInfo.sendTime + lastTime >= nowTime and giftGroup == Enum.GuildGiftGroup.NORMAL then
                    rewardInfo = ItemLogic:getItemPackage( _rid, sGiftReward.reward, true ) or {}
                    if not table.empty( rewardInfo ) then
                        itemId = rewardInfo.items and rewardInfo.items[1].itemId
                        itemNum = rewardInfo.items and rewardInfo.items[1].itemNum
                        giftInfo.receives[_rid] = {
                            rid = _rid, itemId = itemId, itemNum = itemNum, receiveTime = nowTime
                        }
                        -- 更新角色奖励领取信息
                        -- Timer.runAfter( 1, self.setGuildGift, self, _guildId, giftIndex, { [Enum.GuildGift.receives] = giftInfo.receives } )
                        -- self:setGuildGift( _guildId, giftIndex, { [Enum.GuildGift.receives] = giftInfo.receives } )
                        MSM.GuildMgr[_guildId].post.updateGuildGift( _guildId, giftIndex, { [Enum.GuildGift.receives] = giftInfo.receives } )
                        -- 合并奖励
                        ItemLogic:mergeReward( rewards, rewardInfo )
                        syncGifts[giftIndex] = {
                            giftIndex = giftIndex,
                            status = Enum.GuildGiftStatus.RECEIVE,
                            itemId = itemId,
                            itemNum = itemNum,
                        }
                        addGiftPoint = addGiftPoint + sGiftReward.giftPoint
                        addKeyPoint = addKeyPoint + sGiftReward.keyPoint
                        count = count + 1
                        table.insert( allRewards, { groupId = sGiftReward.reward, rewardInfo = rewardInfo } )
                    end
                end
            end
        end
    end

    -- 实际发放礼物
    MSM.GuildMgr[_guildId].post.giveAllRewards( _rid, allRewards )

    -- 增加礼物点数
    local giftPoint, giftLevel
    if addGiftPoint > 0 then
        giftPoint, giftLevel = self:addGiftPoint( _guildId, addGiftPoint )
    end

    -- 增加钥匙点数
    local treasureNum, treasures, keyPoint
    if addKeyPoint > 0 then
        treasureNum, treasures, keyPoint = self:addKeyPoint( _guildId, addKeyPoint, _maxGiftIndex )
    end

    -- 通知角色自己
    if table.size( syncGifts ) > 0 then
        self:syncGuildGifts( _rid, giftPoint, keyPoint, treasures, syncGifts, nil, true )
    end
    -- 通知联盟其他角色
    local memberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 通知客户端联盟礼物等级变化
    if giftLevel then
        GuildLogic:syncGuild( memberRids, { [Enum.Guild.giftLevel] = giftLevel }, true, true, _guildId )
    end
    -- 通知其他联盟成员礼物点数钥匙点数变化
    table.removevalue( memberRids, _rid )
    if #memberRids > 0 and table.size( syncGifts ) > 0 then
        self:syncGuildGifts( memberRids, giftPoint, keyPoint, treasures, nil, nil, true )
    end

    if count > 0 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.ALLIANCE_GET_GIFT, count )
    end

    return rewards, treasureNum
end

---@see 领取指定礼物
function GuildGiftLogic:takeGift( _guildId, _rid, _giftIndex, _maxGiftIndex )
    local rewards = {}
    local treasureNum = 0
    local nowTime = os.time()
    local giftInfo = self:getGuildGift( _guildId, _giftIndex ) or {}
    local joinGuildTime = RoleLogic:getRole( _rid, Enum.Role.joinGuildTime )
    if giftInfo.giftType == Enum.GuildGiftType.GIFT and giftInfo.sendTime >= joinGuildTime
        and not giftInfo.receives[_rid] then
        local sGiftReward = CFG.s_AllianceGiftReward:Get( giftInfo.giftId )
        if sGiftReward and not table.empty( sGiftReward ) then
            local lastTime = CFG.s_AllianceGiftType:Get( sGiftReward.giftType, "lastTime" )
            -- 礼物未超时
            if giftInfo.sendTime + lastTime >= nowTime then
                rewards = ItemLogic:getItemPackage( _rid, sGiftReward.reward ) or {}
                local itemId = rewards.items and rewards.items[1].itemId
                local itemNum = rewards.items and rewards.items[1].itemNum
                giftInfo.receives[_rid] = {
                    rid = _rid, itemId = itemId, itemNum = itemNum, receiveTime = nowTime
                }
                -- 更新角色奖励领取信息
                self:setGuildGift( _guildId, _giftIndex, { [Enum.GuildGift.receives] = giftInfo.receives } )
                local syncGifts = {
                    [_giftIndex] = {
                        giftIndex = _giftIndex,
                        status = Enum.GuildGiftStatus.RECEIVE,
                        itemId = itemId,
                        itemNum = itemNum,
                    }
                }

                -- 增加礼物点数
                local giftPoint, giftLevel
                if sGiftReward.giftPoint > 0 then
                    giftPoint, giftLevel = self:addGiftPoint( _guildId, sGiftReward.giftPoint )
                end

                -- 增加钥匙点数
                local treasures, keyPoint
                if sGiftReward.keyPoint > 0 then
                    treasureNum, treasures, keyPoint = self:addKeyPoint( _guildId, sGiftReward.keyPoint, _maxGiftIndex )
                end

                -- 通知角色自己
                self:syncGuildGifts( _rid, giftPoint, keyPoint, treasures, syncGifts, nil, true )
                -- 通知联盟其他角色
                local memberRids = GuildLogic:getAllOnlineMember( _guildId )
                -- 通知客户端联盟礼物等级变化
                if giftLevel then
                    GuildLogic:syncGuild( memberRids, { [Enum.Guild.giftLevel] = giftLevel }, true, true, _guildId )
                end
                -- 通知其他联盟成员礼物点数钥匙点数变化
                table.removevalue( memberRids, _rid )
                if #memberRids > 0 then
                    self:syncGuildGifts( memberRids, giftPoint, keyPoint, treasures, nil, nil, true )
                end
                MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.ALLIANCE_GET_GIFT, 1 )
            end
        end
    end

    return rewards, treasureNum
end

---@see 增加礼物点数
function GuildGiftLogic:addGiftPoint( _guildId, _addGiftPoint )
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.giftPoint, Enum.Guild.giftLevel } )
    local sGiftLevel = CFG.s_AllianceGiftLevel:Get()
    local giftPoint = guildInfo.giftPoint + _addGiftPoint
    local giftLevel = guildInfo.giftLevel
    -- 计算当前的礼物等级
    while true do
        if giftPoint < sGiftLevel[giftLevel].exp then
            break
        end
        if not sGiftLevel[giftLevel + 1] then
            giftPoint = sGiftLevel[giftLevel].exp
            break
        end

        giftLevel = giftLevel + 1
    end

    -- 更新联盟信息
    GuildLogic:setGuild( _guildId, { [Enum.Guild.giftPoint] = giftPoint, [Enum.Guild.giftLevel] = giftLevel } )

    if giftLevel == guildInfo.giftLevel then
        giftLevel = nil
    end

    return giftPoint, giftLevel
end

---@see 增加钥匙点数
function GuildGiftLogic:addKeyPoint( _guildId, _addKeyGiftPoint, _maxGiftIndex )
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.keyPoint, Enum.Guild.giftLevel } )
    local keyPoint = guildInfo.keyPoint + _addKeyGiftPoint
    -- 获取当前的珍藏ID
    local treasureNum = 0
    local treasureId = CFG.s_AllianceGiftLevel:Get( guildInfo.giftLevel, "treasureId" )
    local reqPoints = CFG.s_AllianceTreasure:Get( treasureId, "reqPoints" ) or 0
    local treasures = {}
    if reqPoints > 0 then
        while keyPoint >= reqPoints do
            treasureNum = treasureNum + 1
            table.mergeEx( treasures, self:sendGuildTreasure( _guildId, _maxGiftIndex + treasureNum, treasureId ) )
            keyPoint = keyPoint - reqPoints
        end

        -- 更新钥匙点数
        GuildLogic:setGuild( _guildId, { [Enum.Guild.keyPoint] = keyPoint } )
    end

    if table.size( treasures ) <= 0 then
        treasures = nil
    end

    return treasureNum, treasures, keyPoint
end

---@see 清除联盟过期和已领取的礼物信息
function GuildGiftLogic:cleanGiftRecord( _guildId, _rid )
    local deleteGiftIndexs = {}
    local gifts = self:getGuildGift( _guildId ) or {}
    local sAllianceGiftType = CFG.s_AllianceGiftType:Get()
    local sAllianceGiftReward = CFG.s_AllianceGiftReward:Get()
    local sGiftReward, lastTime, cleanRids
    local nowTime = os.time()
    for giftIndex, giftInfo in pairs( gifts ) do
        if giftInfo.giftType == Enum.GuildGiftType.GIFT and not table.exist( giftInfo.cleanRids or {}, _rid ) then
            sGiftReward = sAllianceGiftReward[giftInfo.giftId]
            lastTime = sAllianceGiftType[sGiftReward.giftType].lastTime
            if giftInfo.receives[_rid] or giftInfo.sendTime + lastTime <= nowTime then
                table.insert( deleteGiftIndexs, giftIndex )
                cleanRids = giftInfo.cleanRids or {}
                table.insert( cleanRids, _rid )
                self:setGuildGift( _guildId, giftIndex, { [Enum.GuildGift.cleanRids] = cleanRids } )
            end
        end
    end

    if #deleteGiftIndexs > 0 then
        -- 通知客户端删除的礼物索引
        self:syncGuildGifts( _rid, nil, nil, nil, nil, deleteGiftIndexs )
    end
end

---@see 检查联盟礼物存储是否已达上限
function GuildGiftLogic:checkGuildGiftRecordLimit( _guildId )
    local guildGifts = self:getGuildGift( _guildId ) or {}
    local allianceGiftRecordLimit = CFG.s_Config:Get( "allianceGiftRecordLimit" ) or 1000

    if allianceGiftRecordLimit <= table.size( guildGifts ) then
        -- 已到上限
        local giftNum = 0
        local timeOutGift = {}
        local noTimeOutGift = {}
        local nowTime = os.time()
        local giftType, allianceGiftType
        local sAllianceGiftType = CFG.s_AllianceGiftType:Get()
        local sAllianceGiftReward = CFG.s_AllianceGiftReward:Get()
        for giftIndex, giftInfo in pairs( guildGifts ) do
            if giftInfo.giftType == Enum.GuildGiftType.GIFT then
                -- 礼物
                giftNum = giftNum + 1
                giftType = sAllianceGiftReward[giftInfo.giftId].giftType or 0
                allianceGiftType = sAllianceGiftType[giftType]
                if allianceGiftType then
                    if giftInfo.sendTime + allianceGiftType.lastTime <= nowTime then
                        -- 已超时
                        table.insert( timeOutGift, {
                            giftIndex = giftIndex,
                            sendTime = giftInfo.sendTime,
                        } )
                    else
                        -- 未超时
                        table.insert( noTimeOutGift, {
                            giftIndex = giftIndex,
                            sendTime = giftInfo.sendTime,
                            group = allianceGiftType.group
                        } )
                    end
                end
            end
        end

        local deleteNum = giftNum - allianceGiftRecordLimit + 1
        if deleteNum > 0 then
            -- 礼物超过上限, 先删除超时礼物
            local deleteGiftIndexs = {}
            table.sort( timeOutGift, function ( a, b ) return a.sendTime < b.sendTime end )
            for _, giftInfo in pairs( timeOutGift ) do
                SM.c_guild_gift.req.Delete( _guildId, giftInfo.giftIndex )
                table.insert( deleteGiftIndexs, giftInfo.giftIndex )
                deleteNum = deleteNum - 1
                if deleteNum <= 0 then
                    break
                end
            end

            if deleteNum > 0 then
                -- 删除未超时礼物
                table.sort( noTimeOutGift, function ( a, b )
                    if a.group == b.group then
                        return a.sendTime < b.sendTime
                    else
                        return a.group < b.group
                    end
                end )
                for _, giftInfo in pairs( noTimeOutGift ) do
                    SM.c_guild_gift.req.Delete( _guildId, giftInfo.giftIndex )
                    table.insert( deleteGiftIndexs, giftInfo.giftIndex )
                    deleteNum = deleteNum - 1
                    if deleteNum <= 0 then
                        break
                    end
                end
            end

            if #deleteGiftIndexs > 0 then
                -- 通知客户端删除的礼物索引
                local members = GuildLogic:getAllOnlineMember( _guildId ) or {}
                if #members > 0 then
                    self:syncGuildGifts( members, nil, nil, nil, nil, deleteGiftIndexs )
                end
            end
        end
    end
end

---@see 定时检查联盟礼物超时删除
function GuildGiftLogic:cleanTimeOutGuildGifts( _guildId )
    local nowTime = os.time()
    local giftType
    local deleteGiftIndexs = {}
    local sAllianceTreasure = CFG.s_AllianceTreasure:Get()
    local sAllianceGiftType = CFG.s_AllianceGiftType:Get()
    local sAllianceGiftReward = CFG.s_AllianceGiftReward:Get()
    local allianceGiftClean = ( CFG.s_Config:Get( "allianceGiftClean" ) or 24 ) * 3600
    for giftIndex, giftInfo in pairs( self:getGuildGift( _guildId ) or {} ) do
        if giftInfo.giftType == Enum.GuildGiftType.TREASURE then
            -- 珍藏
            if nowTime >= giftInfo.sendTime + sAllianceTreasure[giftInfo.treasureId].lastTime then
                -- 珍藏超时
                SM.c_guild_gift.req.Delete( _guildId, giftIndex )
                table.insert( deleteGiftIndexs, giftIndex )
            end
        elseif giftInfo.giftType == Enum.GuildGiftType.GIFT then
            -- 礼物
            giftType = sAllianceGiftReward[giftInfo.giftId].giftType
            if nowTime >= giftInfo.sendTime + sAllianceGiftType[giftType].lastTime + allianceGiftClean then
                -- 礼物超时
                SM.c_guild_gift.req.Delete( _guildId, giftIndex )
                table.insert( deleteGiftIndexs, giftIndex )
            end
        end
    end

    if #deleteGiftIndexs > 0 then
        -- 通知客户端删除的礼物索引
        local members = GuildLogic:getAllOnlineMember( _guildId ) or {}
        if #members > 0 then
            self:syncGuildGifts( members, nil, nil, nil, nil, deleteGiftIndexs )
        end
    end
end

---@see 联盟联盟礼物是否超时
function GuildGiftLogic:checkGuildGiftTimeOut()
    local centerNode = Common.getCenterNode()
    -- 本服所有联盟ID
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
    for guildId in pairs( guildIds ) do
        MSM.GuildMgr[guildId].post.cleanTimeOutGuildGifts( guildId )
    end
end

---@see 一键领取普通礼物发放奖励信息
function GuildGiftLogic:giveAllRewards( _rid, _rewards )
    local roleChange, itemChange
    local roleChangeInfo = {}
    local itemChangeInfo = {}
    for _, reward in pairs( _rewards or {} ) do
        roleChange, itemChange = ItemLogic:giveReward( _rid, reward.rewardInfo, reward.groupId, true )
        table.mergeEx( roleChangeInfo, roleChange or {} )
        if not table.empty( itemChange or {} ) then
            for itemIndex, item in pairs(itemChange) do
                if itemChangeInfo[itemIndex] then
                    itemChangeInfo[itemIndex].overlay = item.overlay
                else
                    itemChangeInfo[itemIndex] = item
                end
            end
        end
    end

    -- 角色变化信息合并推送
    if not table.empty( roleChangeInfo ) then
        RoleSync:syncSelf( _rid, roleChangeInfo, true )
    end
    -- 道具变化信息合并推送
    if not table.empty( itemChangeInfo ) then
        ItemLogic:syncItem( _rid, nil, itemChangeInfo, true )
    end
end

return GuildGiftLogic