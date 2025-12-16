--[[
* @file : Chat.lua
* @type : snax multi service
* @author : linfeng
* @created : Fri May 11 2018 16:46:43 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天服务器协议处理
* Copyright(C) 2017 IGG, All rights reserved
]]

---@see 客户端发送聊天消息
function response.SendMsg( msg )
    local rid = msg.roleInfo.rid
    local channelType = msg.channelType
    local msgContent = msg.msgContent
    local roleInfo = msg.roleInfo
    local notifyRid = msg.notifyRid

    -- 是否处于禁言
    if roleInfo.silence and roleInfo.silence > os.time() then
        return nil, ErrorCode.CHAT_SILENCE
    end

    -- 检测参数
    if not channelType or not msgContent then
        LOG_ERROR("rid(%d) SendMsg error, not found type or content arg", rid)
        return nil, ErrorCode.CHAT_ARG_ERROR
    end

    -- 检查字符限制
    local channelWordLimit = CFG.s_Config:Get("channelWordLimit")
    if utf8.len(msgContent) > channelWordLimit then
        return nil, ErrorCode.CHAT_WORD_LIMIT
    end

    local sChatChannelInfo = CFG.s_ChatChannel:Get( channelType )
    -- 检测类型是否正常
    if not sChatChannelInfo then
        LOG_ERROR("rid(%d) SendMsg error, invalid channelType(%d)", rid, channelType)
        return nil, ErrorCode.CHAT_INVALID_TYPE
    end

    if sChatChannelInfo.lvLimit and sChatChannelInfo.lvLimit > roleInfo.level then
        LOG_ERROR("rid(%d) SendMsg error, level(%d) less than lvLimit(%d)", rid, roleInfo.level, sChatChannelInfo.lvLimit)
        return nil, ErrorCode.CHAT_LEVEL_LESS
    end

    if channelType == Enum.ChatChannel.GUILD then
        -- 联盟聊天
        if roleInfo.guildId <= 0 then
            -- 不在联盟中,无法送联盟聊天
            LOG_ERROR("rid(%d) SendMsg error, guild msg, but role not in guild", rid)
            return nil, ErrorCode.CHAT_NOT_IN_GUILD
        end
    end

    -- 检测发送间隔
    if not MSM.ChatChannel[rid].req.checkAndSetInterval( rid, channelType, sChatChannelInfo.timeInterval ) then
        LOG_ERROR("rid(%d) SendMsg error, too often", rid)
        return nil, ErrorCode.CHAT_TOO_OFTEN
    end

    -- 发送往频道
    MSM.ChatChannel[rid].post.publishMsg( channelType, roleInfo, msgContent, nil, nil, nil, notifyRid )
end

---@see 获取存储的聊天信息
function response.GetSaveChatMsg( msg )
    local rid = msg.roleInfo.rid
    local page = msg.page
    local channelType = msg.channelType

    SM.ChatSave.post.SendSaveChatMsgByPage( msg.roleInfo.gameNode, msg.roleInfo.guildId, msg.roleInfo.gameId, rid, page, channelType )
end