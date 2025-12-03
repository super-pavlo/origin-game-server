--[[
 * @file : ChatSave.lua
 * @type : signle snax service
 * @author : linfeng
 * @created : 2020-04-07 16:37:44
 * @Last Modified time: 2020-04-07 16:37:44
 * @department : Arabic Studio
 * @brief : 聊天保存逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Timer = require "Timer"
local ChatLogic = require "ChatLogic"

---@type table<int, ChatMsgInfo>
local saveMemChatInfo = {}
---@type table<int, ChatMsgInfo>
local saveMemGuildChatInfo = {}
---@type table<int, ChatMsgInfo>
local saveStoreChatInfo = {}
---@type table<int, ChatMsgInfo>
local saveStoreGuildChatInfo = {}
---@type table<int, boolean>
local saveStoreIsNew = {}
---@type table<int, boolean>
local saveStoreGuildIsNew = {}

---@see 初始化
function response.Init()
    -- 加载到内存中
    ChatLogic:loadChatInfo( saveMemChatInfo, saveStoreChatInfo, saveMemGuildChatInfo, saveStoreGuildChatInfo )
    -- 30s 保存一次落地
    Timer.runEvery( 3000, ChatLogic.saveStoreChatInfo, ChatLogic, saveStoreChatInfo, saveStoreIsNew, saveStoreGuildChatInfo, saveStoreGuildIsNew )
end

---@see 保存聊天数据
function accept.saveChatInfo( _gameNode, _channelType, _uniqueIndex, _rid, _name, _headId, _guildName,
                            _guildId, _timeStamp, _msg, _gameId )
    local sChatChannelInfo = CFG.s_ChatChannel:Get( _channelType )
    local saveMsg = {
        uniqueIndex = _uniqueIndex,
        rid = _rid,
        name = _name,
        timeStamp = _timeStamp,
        msg = _msg,
        headId = _headId,
        channelType = _channelType,
        gameId = _gameId
    }
    -- 内存保存判断
    if sChatChannelInfo.saveNum and sChatChannelInfo.saveNum > 0 then
        if not saveMemChatInfo[_gameNode] then
            saveMemChatInfo[_gameNode] = {}
            saveStoreIsNew[_gameNode] = true
        end
        if not saveMemChatInfo[_gameNode][_channelType] then
            saveMemChatInfo[_gameNode][_channelType] = {}
        end
        if table.size(saveMemChatInfo[_gameNode][_channelType]) >= sChatChannelInfo.saveNum then
            -- 移除最后一个
            table.remove( saveMemChatInfo[_gameNode][_channelType] )
        end

        -- 保存
        table.insert( saveMemChatInfo[_gameNode][_channelType], 1, saveMsg )
    end

    -- 落地保存判断
    if sChatChannelInfo.saveStorageNum and sChatChannelInfo.saveStorageNum > 0 then
        if not saveStoreChatInfo[_gameNode] then
            saveStoreChatInfo[_gameNode] = {}
        end
        if not saveStoreChatInfo[_gameNode][_channelType] then
            saveStoreChatInfo[_gameNode][_channelType] = {}
        end
        local count = table.size(saveStoreChatInfo[_gameNode][_channelType])
        if count > sChatChannelInfo.saveStorageNum then
            for _ = 1, count - sChatChannelInfo.saveStorageNum do
                -- 移除最后一个
                table.remove( saveStoreChatInfo[_gameNode][_channelType] )
            end
        end

        -- 保存
        table.insert( saveStoreChatInfo[_gameNode][_channelType], 1, saveMsg )
    end
end

---@see 保存联盟聊天数据
function accept.saveGuildChatInfo( _gameNode, _channelType, _uniqueIndex, _rid, _name, _headId, _guildName,
                            _guildId, _timeStamp, _msg, _gameId )
    local sChatChannelInfo = CFG.s_ChatChannel:Get( _channelType )
    local saveMsg = {
        uniqueIndex = _uniqueIndex,
        rid = _rid,
        name = _name,
        guildName = _guildName,
        guildId = _guildId,
        timeStamp = _timeStamp,
        msg = _msg,
        headId = _headId,
        channelType = _channelType,
        gameId = _gameId
    }
    -- 内存保存判断
    if sChatChannelInfo.saveNum and sChatChannelInfo.saveNum > 0 then
        if not saveMemGuildChatInfo[_gameNode] then
            saveMemGuildChatInfo[_gameNode] = {}
            saveStoreGuildIsNew[_guildId] = true
        end
        if not saveMemGuildChatInfo[_gameNode][_guildId] then
            saveMemGuildChatInfo[_gameNode][_guildId] = {}
            saveStoreGuildIsNew[_guildId] = true
        end
        if table.size(saveMemGuildChatInfo[_gameNode][_guildId]) >= sChatChannelInfo.saveNum then
            -- 移除最后一个
            table.remove( saveMemGuildChatInfo[_gameNode][_guildId] )
        end

        -- 保存
        table.insert( saveMemGuildChatInfo[_gameNode][_guildId], 1, saveMsg )
    end

    -- 落地保存判断
    if sChatChannelInfo.saveStorageNum and sChatChannelInfo.saveStorageNum > 0 then
        if not saveStoreGuildChatInfo[_gameNode] then
            saveStoreGuildChatInfo[_gameNode] = {}
        end
        if not saveStoreGuildChatInfo[_gameNode][_guildId] then
            saveStoreGuildChatInfo[_gameNode][_guildId] = {}
        end
        local count = table.size(saveStoreGuildChatInfo[_gameNode][_guildId])
        if count > sChatChannelInfo.saveStorageNum then
            for _ = 1, count - sChatChannelInfo.saveStorageNum do
                -- 移除最后一个
                table.remove( saveStoreGuildChatInfo[_gameNode][_guildId] )
            end
        end

        -- 保存
        table.insert( saveStoreGuildChatInfo[_gameNode][_guildId], 1, saveMsg )
    end
end

---@see 同步聊天数据
function accept.syncChatInfo( _roleInfo )
    local channelPageLimit = CFG.s_Config:Get("channelPageLimit")
    -- 发送非联盟信息
    for gameNode, chatMsgInfo in pairs(saveMemChatInfo) do
        if gameNode == _roleInfo.gameNode then
            for _, chatMsg in pairs(chatMsgInfo) do
                local pushMsgInfos = {}
                -- 只发送最新的一页
                for i = 1, channelPageLimit do
                    if chatMsg[i] then
                        repeat
                            if chatMsg.gameId and chatMsg.gameId ~= _roleInfo.gameId then
                                break
                            end
                            table.insert( pushMsgInfos, chatMsg[i] )
                        until true
                    end
                end
                Common.syncMsg( _roleInfo.rid, "Chat_PushMsg", { pushMsgInfos = pushMsgInfos } )
            end
        end
    end

    -- 发送联盟信息
    for gameNode, chatMsgInfo in pairs(saveMemGuildChatInfo) do
        if gameNode == _roleInfo.gameNode and chatMsgInfo[_roleInfo.guildId] then
            local pushMsgInfos = {}
            -- 只发送最新的一页
            for i = 1, channelPageLimit do
                if chatMsgInfo[_roleInfo.guildId][i] then
                    repeat
                        if chatMsgInfo[_roleInfo.guildId].gameId and chatMsgInfo[_roleInfo.guildId].gameId ~= _roleInfo.gameId then
                            break
                        end
                        table.insert( pushMsgInfos, chatMsgInfo[_roleInfo.guildId][i] )
                    until true
                end
            end
            Common.syncMsg( _roleInfo.rid, "Chat_PushMsg", { pushMsgInfos = pushMsgInfos } )
        end
    end
end

---@see 按分页发送聊天信息
function accept.SendSaveChatMsgByPage( _gameNode, _guildId, _gameId, _rid, _page, _channelType )
    local channelPageLimit = CFG.s_Config:Get("channelPageLimit")
    if _channelType ~= Enum.ChatChannel.GUILD then
        if saveMemChatInfo[_gameNode] and saveMemChatInfo[_gameNode][_channelType] then
            local from = ( _page - 1 ) * channelPageLimit + 1
            local to = _page * channelPageLimit
            local pushMsgInfos = {}
            for i = from, to do
                if saveMemChatInfo[_gameNode][_channelType][i] then
                    repeat
                        if saveMemChatInfo[_gameNode][_channelType][i].gameId and saveMemChatInfo[_gameNode][_channelType][i].gameId ~= _gameId then
                            break
                        end
                        table.insert( pushMsgInfos, saveMemChatInfo[_gameNode][_channelType][i] )
                    until true
                end
            end
            Common.syncMsg( _rid, "Chat_PushMsg", { pushMsgInfos = pushMsgInfos } )
        end
    else
        if saveMemGuildChatInfo[_gameNode] and saveMemGuildChatInfo[_gameNode][_guildId] then
            local from = ( _page - 1 ) * channelPageLimit + 1
            local to = _page * channelPageLimit
            local pushMsgInfos = {}
            for i = from, to do
                if saveMemGuildChatInfo[_gameNode][_guildId][i] then
                    repeat
                        if saveMemGuildChatInfo[_gameNode][_guildId][i].gameId and saveMemGuildChatInfo[_gameNode][_guildId][i].gameId ~= _gameId then
                            break
                        end
                        table.insert( pushMsgInfos, saveMemGuildChatInfo[_gameNode][_guildId][i] )
                    until true
                end
            end
            Common.syncMsg( _rid, "Chat_PushMsg", { pushMsgInfos = pushMsgInfos } )
        end
    end
end