--[[
* @file : ChatChannel.lua
* @type : snax multi service
* @author : linfeng
* @created : Mon May 14 2018 09:19:06 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天频道服务,保存角色和频道信息的映射
* Copyright(C) 2017 IGG, All rights reserved
]]

local ChatLogic = require "ChatLogic"
local ChatIntervals = {}
local ChannelTypeRids = {}

---@see 聊天服务器角色离线登出
function response.onRoleLogout( _rid )
    ChatIntervals[_rid] = nil
end

---@see 向一个频道发送消息
---@param _roleInfo defaultRoleAttrClass
function accept.publishMsg( _channelType, _roleInfo, _msg, _msgArgs, _gameId, _channelId, _notifyRid )
    local routeRid = _roleInfo.rid
    local channelId
    if routeRid and routeRid > 0 then
        -- 角色发送的消息
        if not ChannelTypeRids[routeRid] then
            LOG_ERROR("rid(%d) publishMsg, but not found info in ChannelTypeRids", routeRid)
            return
        end
        channelId = ChannelTypeRids[routeRid][_channelType]
    else
        -- 系统发送的消息
        channelId = _channelId or _roleInfo.systemChannel[_channelType]
    end

    if not channelId then
        LOG_ERROR("rid(%s) pushMsg channelType(%d) not found channel", tostring(routeRid), _channelType)
        return
    end

    local rids = MSM.ChatChannelEntity[channelId].req.getRidsFromEntity( _roleInfo.gameNode, channelId, _gameId )

    local chatMsg = {}
    local uniqueIndex = ChatLogic:newUniqueIndex()
    if not _msgArgs then -- 一般消息
        table.insert( chatMsg, {
            timeStamp = os.time(),
            channelType = _channelType,
            msg = _msg,
            rid = _roleInfo.rid,
            name = _roleInfo.name,
            guildName = _roleInfo.guildName,
            guildId = _roleInfo.guildId,
            headId = _roleInfo.headId,
            uniqueIndex = uniqueIndex,
            headFrameID = _roleInfo.headFrameID,
            notifyRid = _notifyRid
        } )
    else
        -- 系统消息
        local languageId = tonumber(_msg)
        _msgArgs = table.valuetostring( _msgArgs )
        table.insert( chatMsg, {
            timeStamp = os.time(),
            channelType = _channelType,
            systemMsg = { languageId = languageId, args = _msgArgs },
            uniqueIndex = uniqueIndex,
            msg = _msg,
        } )
    end

    if not table.empty(rids) then
        if _channelType ~= Enum.ChatChannel.GUILD then
            -- 保存聊天消息
            SM.ChatSave.post.saveChatInfo( _roleInfo.gameNode, _channelType, uniqueIndex, _roleInfo.rid, _roleInfo.name, _roleInfo.headId,
                                            _roleInfo.guildName, _roleInfo.guildId, os.time(), _msg, _gameId )
        else
            -- 保存联盟聊天消息
            SM.ChatSave.post.saveGuildChatInfo( _roleInfo.gameNode, _channelType, uniqueIndex, _roleInfo.rid, _roleInfo.name, _roleInfo.headId,
                                            _roleInfo.guildName, _roleInfo.guildId, os.time(), _msg, _gameId )
        end
        Common.syncMsg( rids, "Chat_PushMsg", { pushMsgInfos = chatMsg }, nil, nil, nil, true )
    end

    -- 增加推送
    if _channelType == Enum.ChatChannel.GUILD then
        Common.rpcSend( _roleInfo.gameNode, "PushMgr", "sendAllianceChtPush", routeRid, _roleInfo.name, _msg )
    end
end

---@see 检测发送间隔
function response.checkAndSetInterval( _rid, _channelType, _timeInterval )
    if not ChatIntervals[_rid] then
        ChatIntervals[_rid] = {}
    end

    local lastChatTime = ChatIntervals[_rid][_channelType] or 0
    local now = os.time()
    if lastChatTime + _timeInterval > now then
        return false
    end

    ChatIntervals[_rid][_channelType] = now
    return true
end

---@see 检测发送消耗
function response.checkChatChannelCost( _roleInfo, _costType, _costValue, _costNum, _eventTypes )
    return ChatLogic:checkChatCost( _roleInfo, _costType, _costValue, _costNum, _eventTypes )
end

---@see 加入频道
function response.joinChannel( _rid, _channelType, _channelId )
    if not ChannelTypeRids[_rid] then
        ChannelTypeRids[_rid] = {}
    end
    ChannelTypeRids[_rid][_channelType] = _channelId
end

---@see 离开频道
function response.leaveChannel( _rid, _channelType )
    if ChannelTypeRids[_rid] then
        ChannelTypeRids[_rid][_channelType] = nil
        if table.empty(ChannelTypeRids[_rid]) then
            ChannelTypeRids[_rid] = nil
        end
    end
end

---@see 增加角色系统级频道
function response.addRoleSystemChannel( _rid, _channelInfos )
    if not ChannelTypeRids[_rid] then
        ChannelTypeRids[_rid] = {}
    end

    for channelType,channelId in pairs(_channelInfos) do
        ChannelTypeRids[_rid][channelType] = channelId
    end
end

---@see 删除角色系统级频道
function response.delRoleSystemChannel( _rid, _channelInfos )
    for channelType,_ in pairs(_channelInfos) do
        if ChannelTypeRids[_rid] then
            ChannelTypeRids[_rid][channelType] = nil
        end
    end

    if table.empty(ChannelTypeRids[_rid]) then
        ChannelTypeRids[_rid] = nil
    end
end