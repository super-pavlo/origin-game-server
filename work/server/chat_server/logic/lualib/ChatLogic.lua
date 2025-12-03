--[[
* @file : ChatLogic.lua
* @type : lua lib
* @author : linfeng
* @created : Fri May 11 2018 17:07:20 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天服务器聊天相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local ChatLogic = {}

---@see 更新角色信息
function ChatLogic:updateRoleInfo( _roleInfo )
    local username, agent = Common.getUserNameAndAgentByRid( _roleInfo.rid )
    if username and agent then
        agent[1].post.updateRoleInfo( username[1], _roleInfo )
    end
end

---@see 生成聊天唯一索引
function ChatLogic:newUniqueIndex()
    return Common.redisExecute( { "incr", "chatUniqueIndexkey" } )
end

---@see 保存聊天信息落地
function ChatLogic:saveStoreChatInfo( _saveChatInfo, _saveStoreIsNew, _saveStoreGuildChatInfo, _saveStoreGuildIsNew )
    -- 保存非联盟聊天信息
    local storeMsg = table.copy(_saveChatInfo, true)
    for gameNode, msgInfo in pairs(storeMsg) do
        for channelType, msgInfoDetail in pairs(msgInfo) do
            if _saveStoreIsNew[gameNode] then
                SM.c_chat.req.Add( gameNode, channelType, { channelType = channelType, chatMsgInfoDetail = msgInfoDetail } )
                _saveStoreIsNew[gameNode] = nil
            else
                SM.c_chat.req.Set( gameNode, channelType, { channelType = channelType, chatMsgInfoDetail = msgInfoDetail } )
            end
        end
    end

    -- 保存联盟聊天信息
    local storeGuildMsg = table.copy(_saveStoreGuildChatInfo, true)
    for gameNode, msgInfo in pairs(storeGuildMsg) do
        for guildId, msgInfoDetail in pairs(msgInfo) do
            if _saveStoreGuildIsNew[guildId] then
                SM.c_chat_guild.req.Add( gameNode, guildId, { guildId = guildId, chatMsgInfoDetail = msgInfoDetail } )
                _saveStoreGuildIsNew[guildId] = nil
            else
                SM.c_chat_guild.req.Set( gameNode, guildId, { guildId = guildId, chatMsgInfoDetail = msgInfoDetail } )
            end
        end
    end
end

---@see 加载聊天信息
function ChatLogic:loadChatInfo( _saveMemChatInfo, _saveStoreChatInfo, _saveMemGuildChatInfo, _saveStoreGuildChatInfo )
    -- 加载非联盟频道
    local allChatInfo = SM.c_chat.req.Get()
    for gameNode, msgInfo in pairs(allChatInfo) do
        if not _saveMemChatInfo[gameNode] then
            _saveMemChatInfo[gameNode] = {}
        end
        if not _saveStoreChatInfo[gameNode] then
            _saveStoreChatInfo[gameNode] = {}
        end
        for channelType, msgInfoDetail in pairs(msgInfo) do
            _saveMemChatInfo[gameNode][channelType] = {}
            _saveStoreChatInfo[gameNode][channelType] = {}
            for _, realMsg in pairs(msgInfoDetail.chatMsgInfoDetail) do
                table.insert( _saveMemChatInfo[gameNode][channelType], realMsg )
                table.insert( _saveStoreChatInfo[gameNode][channelType], realMsg )
            end
        end
    end

    -- 加载联盟频道
    local allGuildChatInfo = SM.c_chat_guild.req.Get()
    for gameNode, msgInfo in pairs(allGuildChatInfo) do
        if not _saveMemGuildChatInfo[gameNode] then
            _saveMemGuildChatInfo[gameNode] = {}
        end
        if not _saveStoreGuildChatInfo[gameNode] then
            _saveStoreGuildChatInfo[gameNode] = {}
        end
        for guildId, msgInfoDetail in pairs(msgInfo) do
            _saveMemGuildChatInfo[gameNode][guildId] = {}
            _saveStoreGuildChatInfo[gameNode][guildId] = {}
            for _, realMsg in pairs(msgInfoDetail.chatMsgInfoDetail) do
                table.insert( _saveMemGuildChatInfo[gameNode][guildId], realMsg )
                table.insert( _saveStoreGuildChatInfo[gameNode][guildId], realMsg )
            end
        end
    end
end

return ChatLogic