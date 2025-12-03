--[[
 * @file : RoleChatLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-01-21 16:00:38
 * @Last Modified time: 2020-01-21 16:00:38
 * @department : Arabic Studio
 * @brief : 游服聊天逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleChatLogic = {}

---@see 获取聊天服务器角色所需的信息
function RoleChatLogic:getRoleInfoWithChatServer( _rid, _field )
    if _field and not Common.isTable( _field ) then _field = { _field } end
    local syncFileds = _field or {
        Enum.Role.rid, Enum.Role.name, Enum.Role.level, Enum.Role.country, Enum.Role.iggid, Enum.Role.secret,
        Enum.Role.guildId, Enum.Role.headFrameID, Enum.Role.headId, Enum.Role.silence, Enum.Role.gameId
    }

    local RoleLogic = require "RoleLogic"
    local roleInfo = RoleLogic:getRole( _rid, syncFileds )
    if not roleInfo then
        return
    end
    roleInfo.guildName = ""
    if roleInfo.guildId > 0 then
        local GuildLogic = require "GuildLogic"
        roleInfo.guildName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end
    roleInfo.gameNode = Common.getSelfNodeName()
    roleInfo.rid = _rid

    return roleInfo
end

---@see 通知聊天服务器角色登陆
function RoleChatLogic:notifyChatServerLogin( _rid, _secret, _subId )
    local chatNode = Common.getChatNode()
    local roleInfo = self:getRoleInfoWithChatServer( _rid )
    if not roleInfo then
        return
    end
    if not _secret then
        _secret = roleInfo.secret
    end
    local cluster = require "skynet.cluster"
    local ok, chatSubId, chatServerIp, chatServerRealIp, chatServerPort, chatServerName = pcall(cluster.call, chatNode,
                                "Chatd", "login", _secret, roleInfo, _subId)
    if ok then
        return chatSubId, chatServerIp, chatServerRealIp, chatServerPort, chatServerName
    else
        LOG_ERROR("rid(%d) notifyChatServerLogin error(%s)", _rid, chatSubId )
    end
end

---@see 更新聊天服务器角色信息
function RoleChatLogic:syncRoleInfoToChatServer( _rid )
    local chatNode = Common.getChatNode()
    local roleInfo = self:getRoleInfoWithChatServer( _rid )
    Common.rpcSend( chatNode, "ChatMgr", "updateRoleInfo", roleInfo )
end

---@see 新增联盟频道
function RoleChatLogic:newGuildChannel( _guildId )
    local gameNode = Common.getSelfNodeName()
    local chatNode = Common.getChatNode()
    local channel = Common.rpcCall( chatNode, "ChatMgr", "addGuildChannel", gameNode, _guildId )
    return channel ~= nil
end

---@see 删除联盟频道
function RoleChatLogic:delGuildChannel( _guildId )
    local gameNode = Common.getSelfNodeName()
    local chatNode = Common.getChatNode()
    Common.rpcCall( chatNode, "ChatMgr", "delGuildChannel", gameNode, _guildId )
end

---@see 联盟频道加入角色
function RoleChatLogic:memberJoinGuildChannel( _guildId, _memberRid, _gameId )
    local gameNode = Common.getSelfNodeName()
    local chatNode = Common.getChatNode()
    Common.rpcCall( chatNode, "ChatMgr", "guildChannelAddRole", gameNode, _guildId, _memberRid, _gameId )
end

---@see 联盟频道移除角色
function RoleChatLogic:memberLeaveGuildChannel( _guildId, _memberRid )
    local gameNode = Common.getSelfNodeName()
    local chatNode = Common.getChatNode()
    Common.rpcCall( chatNode, "ChatMgr", "guildChannelDelRole", gameNode, _guildId, _memberRid )
end

---@see 获取角色私聊信息
function RoleChatLogic:getChat( _rid, _toRid )
    return MSM.d_chat[_rid].req.Get( _rid, _toRid )
end

---@see 更新角色私聊信息
function RoleChatLogic:setChat( _rid, _toRid, _msg )
    LOG_DEBUG("%d CHAT msg:%s timeStamp:%d with %d", _rid, _msg, os.time(), _toRid)
    return MSM.d_chat[_rid].req.Set( _rid, _toRid, _msg )
end

---@see 增加角色私聊信息
function RoleChatLogic:addChat( _rid, _toRid, _msg )
    return MSM.d_chat[_rid].req.Add( _rid, _toRid, _msg )
end

---@see 发送跑马灯信息
---@param _languageId integer 语言包ID
---@param _args table<int, string> 参数
---@param _msg string 消息,和前2个参数互斥
function RoleChatLogic:sendMarquee( _languageId, _args, _msg, _rids )
    -- 获取全服在线的玩家
    local onlineRids = _rids or SM.OnlineMgr.req.getAllOnlineRid()
    Common.syncMsg( onlineRids, "Chat_MarqueeNotify", {
        languageId = _languageId,
        args = _args,
        msg = _msg
    })
end

---@see 记录私聊信息
function RoleChatLogic:addChatRecord( _leftRid, _rightRid, _messageInfo )
    local saveStorageNum = CFG.s_ChatChannel:Get( Enum.ChatChannel.PRIVATE, "saveStorageNum" ) or 50
    local messages = self:getChat( _leftRid, _rightRid )
    if messages and not table.empty( messages ) then
        -- 聊天记录数量上限控制
        if ( table.size( messages.lstChat ) >= saveStorageNum ) then
            table.remove( messages.lstChat, 1 )
        end

        table.insert( messages.lstChat, _messageInfo )
        self:setChat( _leftRid, _rightRid, messages )
    else
        -- 新增聊天
        messages = { rid = _rightRid, lstChat = {} }
        table.insert( messages.lstChat, _messageInfo )
        self:addChat( _leftRid, _rightRid, messages )
    end
end

return RoleChatLogic