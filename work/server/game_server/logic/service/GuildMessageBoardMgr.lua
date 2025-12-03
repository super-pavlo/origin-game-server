--[[
* @file : GuildMessageBoardMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Wed May 27 2020 15:52:57 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟留言板管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local GuildLogic = require "GuildLogic"
local RoleLogic = require "RoleLogic"

---@class defaultGuildMessageAttrClass
local defaultGuildMessageAttr = {
    messageIndex                =               0,                          -- 留言索引
    roleInfo                    =               {},                         -- 留言角色信息
    floorId                     =               0,                          -- 层ID, 0为回复
    replyMessageIndex           =               0,                          -- 回复的留言索引
    sendTime                    =               0,                          -- 发送时间
    content                     =               "",                         -- 留言内容
}

---@see 联盟留言板消息
---@type table<int, table<int, defaultGuildMessageAttrClass>>
local guildMessages = {}

---@see 联盟当前最大消息索引
---@type table<int, int>
local guildMessageIndexs = {}

---@see 支持跨服调用查询
function init(index)
	snax.enablecluster()
	cluster.register(SERVICE_NAME .. index)
end

---@see 初始化
function response.Init()
    local index = 0
    local dbNode = Common.getDbNode()
    local ret
    while true do
        ret = Common.rpcCall( dbNode, "CommonLoadMgr", "loadCommonMysqlImpl", "c_guild_message_board", index )
        if not ret or table.empty( ret ) then
            break
        end

        for guildId, message in pairs( ret ) do
            -- 添加联盟属性
            MSM.GuildMessageBoardMgr[guildId].req.addGuild( guildId, message.messageInfo )
        end

        index = index + table.size( ret )
    end
end

---@see 初始化联盟信息
function response.addGuild( _guildId, _messages )
    local messages = {}
    local replyMessages = {}
    local maxMessageIndex = 0

    for messageIndex, messageInfo in pairs( _messages or {} ) do
        if not messageInfo.floorId or messageInfo.floorId <= 0 then
            -- 回复信息
            if not replyMessages[messageInfo.replyMessageIndex] then
                replyMessages[messageInfo.replyMessageIndex] = {}
            end
            replyMessages[messageInfo.replyMessageIndex][messageIndex] = messageIndex
        end
        -- 计算最大消息索引
        if messageIndex > maxMessageIndex then
            maxMessageIndex = messageIndex
        end

        messages[messageIndex] = messageInfo
    end

    guildMessages[_guildId] = {
        messages = messages,
        replyMessages = replyMessages,
    }
    guildMessageIndexs[_guildId] = maxMessageIndex
end

---@see 获取联盟留言板信息
function response.getMessageBoard( _guildId, _freshType, _messageIndex, _rid )
    local messages = {}

    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.messageBoardRedDotList } )
    local guildMessage = guildMessages[_guildId] or {}
    if not table.empty( guildMessage.messages or {} ) then
        local messageIndex = _messageIndex
        if not messageIndex or messageIndex <= 0 then
            messageIndex = guildMessageIndexs[_guildId] + 1
            _freshType = Enum.GuildMessageFreshType.OLD
        elseif _freshType == Enum.GuildMessageFreshType.EMAIL_FRESH then
            local messageInfo = guildMessages[_guildId] and guildMessages[_guildId].messages[_messageIndex]
            if messageInfo.replyMessageIndex > 0 then
                -- 回复留言
                messageIndex = messageInfo.replyMessageIndex + 1
            else
                -- 发布留言
                messageIndex = messageIndex + 1
            end
        end

        local messageSize = 0
        local messageIndexs = {}
        local replyMessages = guildMessage.replyMessages or {}
        local allianceMessageSyncNum = CFG.s_Config:Get( "allianceMessageSyncNum" )
        while messageSize < allianceMessageSyncNum do
            -- 向上刷新还是向下刷新
            if _freshType == Enum.GuildMessageFreshType.NEW then
                messageIndex = messageIndex + 1
                if messageIndex > guildMessageIndexs[_guildId] then
                    break
                end
            else
                messageIndex = messageIndex - 1
                if messageIndex < 1 then
                    break
                end
            end

            if guildMessage.messages[messageIndex] and guildMessage.messages[messageIndex].floorId > 0 then
                -- 先添加发布信息
                table.insert( messages, guildMessage.messages[messageIndex] )
                messageIndexs[messageIndex] = true
                messageSize = messageSize + 1
                -- 添加回复信息
                for replyMessageIndex in pairs( replyMessages[messageIndex] or {} ) do
                    table.insert( messages, guildMessage.messages[replyMessageIndex] )
                    messageSize = messageSize + 1
                end
            end
        end
        if guildInfo.members[_rid] and not table.exist( guildInfo.messageBoardRedDotList, _rid ) then
            -- 是本联盟角色且当前为有红点标识
            local maxMessageIndex = guildMessageIndexs[_guildId]
            while maxMessageIndex > 0 do
                if guildMessage.messages[maxMessageIndex] and guildMessage.messages[maxMessageIndex].floorId > 0 then
                    break
                end
                maxMessageIndex = maxMessageIndex - 1
            end
            -- 最大的发布消息索引是否获取到
            if messageIndexs[maxMessageIndex] then
                table.insert( guildInfo.messageBoardRedDotList, _rid )
                GuildLogic:setGuild( _guildId, { [Enum.Guild.messageBoardRedDotList] = guildInfo.messageBoardRedDotList } )
                -- 通知角色删除红点
                GuildLogic:syncGuild( _rid, { [Enum.Guild.messageBoardRedDot] = false }, true )
            end
        end
    end

    return { messages = messages, messageBoardStatus = GuildLogic:getGuild( _guildId, Enum.Guild.messageBoardStatus ) }
end

---@see 删除多余消息
local function deleteGuildMessage( _guildId, _messageIndex, _deleteFlag )
    local messageInfo = guildMessages[_guildId] and guildMessages[_guildId].messages[_messageIndex]
    if messageInfo then
        if messageInfo.replyMessageIndex > 0 then
            -- 该信息为回复信息
            if _deleteFlag then
                -- 删除发布信息
                guildMessages[_guildId].messages[messageInfo.replyMessageIndex] = nil
                SM.c_guild_message_board.req.Delete( _guildId, messageInfo.replyMessageIndex )
                -- 删除全部回复信息
                for index in pairs( guildMessages[_guildId].replyMessages[messageInfo.replyMessageIndex] ) do
                    guildMessages[_guildId].messages[index] = nil
                    SM.c_guild_message_board.req.Delete( _guildId, index )
                end
            else
                -- 只删除该回复信息
                guildMessages[_guildId].replyMessages[messageInfo.replyMessageIndex][_messageIndex] = nil
                guildMessages[_guildId].messages[_messageIndex] = nil
                SM.c_guild_message_board.req.Delete( _guildId, _messageIndex )
            end
        else
            -- 删除该发布信息
            guildMessages[_guildId].messages[_messageIndex] = nil
            SM.c_guild_message_board.req.Delete( _guildId, _messageIndex )
            -- 删除该信息的所有回复信息
            for index in pairs( guildMessages[_guildId].replyMessages[_messageIndex] or {} ) do
                guildMessages[_guildId].messages[index] = nil
                SM.c_guild_message_board.req.Delete( _guildId, index )
            end
            guildMessages[_guildId].replyMessages[_messageIndex] = nil
        end
    end
end

---@see 发布联盟留言板消息
function response.sendBoardMessage( _guildId, _replyMessageIndex, _content, _roleInfo )
    -- 留言板功能是否打开
    if not GuildLogic:getGuild( _guildId, Enum.Guild.messageBoardStatus ) then
        return { error = ErrorCode.GUILD_NO_OPEN_MESSAGE_BOARD }
    end

    if not guildMessages[_guildId] then
        guildMessages[_guildId] = {
            messages = {},
            replyMessages = {},
        }
        guildMessageIndexs[_guildId] = 0
    end
    local messageInfo = const( table.copy( defaultGuildMessageAttr ) )
    messageInfo.roleInfo = _roleInfo
    messageInfo.sendTime = os.time()
    messageInfo.content = _content

    local guildMessage = guildMessages[_guildId]
    local allMessages = guildMessage.messages
    local replyMessages = guildMessage.replyMessages
    local replyMessageFlag = _replyMessageIndex and _replyMessageIndex > 0 or false
    local sendMessageIndex = _replyMessageIndex
    if replyMessageFlag then
        -- 回复消息
        local oldMessageInfo = allMessages[_replyMessageIndex]
        if not oldMessageInfo then
            -- 回复消息已经被删除
            return { error = ErrorCode.GUILD_REPLY_MESSAGE_INVALID }
        end

        if oldMessageInfo.replyMessageIndex > 0 then
            sendMessageIndex = oldMessageInfo.replyMessageIndex
        end

        -- 该条消息回复总数是否已达上限
        if table.size( replyMessages[sendMessageIndex] or {} ) >= CFG.s_Config:Get( "allianceMessageTierLimit" ) then
            return { error = ErrorCode.GUILD_REPLY_SUM_LIMIT }
        end

        -- 回复信息
        local rid = _roleInfo.rid
        if allMessages[sendMessageIndex].roleInfo.rid ~= rid then
            local size = 0
            -- 自已回复条数是否已达上限
            for _, index in pairs( replyMessages[sendMessageIndex] or {} ) do
                if allMessages[index].roleInfo.rid == rid then
                    size = size + 1
                end
            end
            if size >= CFG.s_Config:Get( "allianceMessageReplyLimit" ) then
                return { error = ErrorCode.GUILD_SELF_REPLY_SUM_LIMIT }
            end
        end
        messageInfo.replyMessageIndex = sendMessageIndex
    else
        -- 发布消息
        local _, floorId = GuildLogic:lockSetGuild( _guildId, Enum.Guild.messageFloorId, 1 )
        messageInfo.floorId = floorId
    end

    if table.size( guildMessage.messages or {} ) >= CFG.s_Config:Get( "allianceMessageNum" ) then
        -- 超过上限，取出索引最小(时间最早的)的消息
        local minMessageIndex = guildMessageIndexs[_guildId] or 0
        for index in pairs( allMessages ) do
            if minMessageIndex > index then
                minMessageIndex = index
            end
        end

        -- 本次回复信息且回复的是最旧的数据，则不删除
        if not replyMessageFlag or minMessageIndex ~= sendMessageIndex then
            deleteGuildMessage( _guildId, minMessageIndex, true )
        end
    end

    -- 添加本次消息
    guildMessageIndexs[_guildId] = guildMessageIndexs[_guildId] + 1
    messageInfo.messageIndex = guildMessageIndexs[_guildId]

    -- 插入新消息
    SM.c_guild_message_board.req.Add( _guildId, messageInfo.messageIndex, messageInfo )

    guildMessages[_guildId].messages[messageInfo.messageIndex] = messageInfo
    if replyMessageFlag then
        if not guildMessages[_guildId].replyMessages[sendMessageIndex] then
            guildMessages[_guildId].replyMessages[sendMessageIndex] = {}
        end
        guildMessages[_guildId].replyMessages[sendMessageIndex][messageInfo.messageIndex] = messageInfo.messageIndex
        -- 发送回复邮件
        local toRid = allMessages[_replyMessageIndex].roleInfo.rid
        local emailArg = string.format( "%s,%s", _roleInfo.guildAbbName or "", _roleInfo.name )
        local emailOtherInfo = {
            subTitleContents = { emailArg },
            emailContents = { emailArg, _content },
            guildEmail = {
                guildId = _guildId,
                roleHeadId = _roleInfo.headId,
                roleHeadFrameId = _roleInfo.headFrameID,
                boardMessageIndex = _replyMessageIndex,
            },
            subType = Enum.EmailSubType.MESSAGE_REPLY
        }
        MSM.EmailProxy[toRid].post.sendEmail( toRid, 100057, emailOtherInfo )
    else
        -- 所有角色都有留言板红点提示
        local messageBoardRedDotList = {}
        local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
        if members[_roleInfo.rid] then
            -- 发布角色不需要有红点提示
            table.insert( messageBoardRedDotList, _roleInfo.rid )
        end
        GuildLogic:setGuild( _guildId, { [Enum.Guild.messageBoardRedDotList] = messageBoardRedDotList } )
        -- 增加联盟修改标识
        MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
    end

    return { messageInfo = messageInfo }
end

---@see 删除联盟留言板消息
function response.deleteBoardMessage( _guildId, _messageIndex, _rid )
    local guildMessage = guildMessages[_guildId] or {}
    local allMessages = guildMessage.messages or {}

    if allMessages[_messageIndex] then
        if allMessages[_messageIndex].roleInfo.rid == _rid then
            -- 自己发布的消息直接删除
            deleteGuildMessage( _guildId, _messageIndex )
        else
            -- 不是自己发布消息，检查是否是自己的联盟
            local roleGuildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
            if _guildId ~= roleGuildId then
                return { error = ErrorCode.GUILD_NO_JURISDICTION }
            end

            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.guildOfficers } )
            local guildJob = guildInfo.members[_rid] and guildInfo.members[_rid].guildJob or 0
            if guildJob ~= Enum.GuildJob.LEADER then
                local officerFlag
                for _, officerInfo in pairs( guildInfo.guildOfficers or {} ) do
                    if officerInfo.rid == _rid then
                        officerFlag = true
                        break
                    end
                end
                if not officerFlag then
                    return { error = ErrorCode.GUILD_NO_JURISDICTION }
                end
            end
            -- 删除留言板消息
            deleteGuildMessage( _guildId, _messageIndex )
        end
    end

    return {}
end

---@see 检查留言板信息是否存在
function response.checkBoardMessage( _guildId, _messageIndex )
    if guildMessages[_guildId] and guildMessages[_guildId].messages[_messageIndex] then
        return true
    end
end