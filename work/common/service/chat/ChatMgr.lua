--[[
* @file : ChatMgr.lua
* @type : snax single service
* @author : linfeng
* @created : Fri Feb 23 2018 16:43:18 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天相关管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local ChatLogic = require "ChatLogic"

-- 频道组播id信息
local Channels = {}

function response.Init()
    -- body
end

function init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

local function cleanAllChannels( _gameNode )
    if Channels[_gameNode] then
        local channelId = Channels[_gameNode][Enum.ChatChannel.WORLD]
        MSM.ChatChannelEntity[channelId].req.delChannelEntity( _gameNode, channelId )

        for _,ch in pairs(Channels[_gameNode][Enum.ChatChannel.GUILD]) do
            MSM.ChatChannelEntity[ch].req.delChannelEntity( _gameNode, ch )
        end

        for _,ch in pairs(Channels[_gameNode][Enum.ChatChannel.GROUP]) do
            MSM.ChatChannelEntity[ch].req.delChannelEntity( _gameNode, ch )
        end
    end
end

---@see 新建一个channelId
local function newChannelId()
    return Common.redisExecute( { "incr", "chatchannelId" } )
end

---@see 初始化全部的组播频道
function response.initChannelWithNode( _gameNode )
    if Channels[_gameNode] then
        cleanAllChannels( _gameNode )
    end

    Channels[_gameNode] = {}

    -- 初始化世界频道
    local worldChannel = newChannelId()
    Channels[_gameNode][Enum.ChatChannel.WORLD] = worldChannel
    MSM.ChatChannelEntity[worldChannel].req.newChannelEntity( _gameNode, worldChannel )
    -- 联盟频道
    Channels[_gameNode][Enum.ChatChannel.GUILD] = {}
    -- 组队频道
    Channels[_gameNode][Enum.ChatChannel.GROUP] = {}
end

---@see 获取gameNode对应的系统级频道信息
function response.getAllChannelsByNode( _gameNode, _job, _mapId, _guildId, _groupIndex )
    if  not Channels[_gameNode] then
        -- 聊天服务器重启了,自己初始化
        snax.self().req.initChannelWithNode( _gameNode )
    end

    if _guildId and _guildId > 0 and not Channels[_gameNode][Enum.ChatChannel.GUILD][_guildId] then
        -- 增加联盟频道
        snax.self().req.addGuildChannel( _gameNode, _guildId )
    end

    if _groupIndex and _groupIndex > 0 and not Channels[_gameNode][Enum.ChatChannel.GROUP][_groupIndex] then
        -- 增加群组频道
        snax.self().req.addTeamChannel( _gameNode, _groupIndex )
    end

    return {
                [Enum.ChatChannel.WORLD] = Channels[_gameNode][Enum.ChatChannel.WORLD],
                [Enum.ChatChannel.GUILD] = ( _guildId and _guildId > 0 ) and Channels[_gameNode][Enum.ChatChannel.GUILD][_guildId] or nil,
        }
end

---@see 更新角色信息
function accept.updateRoleInfo( _roleInfo )
    ChatLogic:updateRoleInfo( _roleInfo )
end

---@see 新增联盟频道
function response.addGuildChannel( _gameNode, _guildId )
    if Channels[_gameNode] then
        local channel = newChannelId()
        Channels[_gameNode][Enum.ChatChannel.GUILD][_guildId] = channel
        MSM.ChatChannelEntity[channel].req.newChannelEntity( _gameNode, channel )
        return channel
    end
end

---@see 删除联盟频道
function response.delGuildChannel( _gameNode, _guildId )
    if Channels[_gameNode] then
        local channel = Channels[_gameNode][Enum.ChatChannel.GUILD][_guildId]
        if channel then
            MSM.ChatChannelEntity[channel].req.delChannelEntity( _gameNode, channel )
        end
        Channels[_gameNode][Enum.ChatChannel.GUILD][_guildId] = nil
    end
end

---@see 联盟频道加入角色
function response.guildChannelAddRole( _gameNode, _guildId, _rid, _gameId )
    if Channels[_gameNode] then
        local channel = Channels[_gameNode][Enum.ChatChannel.GUILD][_guildId]
        if not channel then
            -- 增加联盟频道
            channel = snax.self().req.addGuildChannel( _gameNode, _guildId )
        end

        if channel then
            ChatLogic:updateRoleInfo( { rid = _rid, guildId = _guildId } )
            MSM.ChatChannel[_rid].req.joinChannel( _rid, Enum.ChatChannel.GUILD, channel )
            MSM.ChatChannelEntity[channel].req.joinChannelEntity( _gameNode, channel, _rid, _gameId )
        end
    end
end

---@see 联盟频道删除角色
function response.guildChannelDelRole( _gameNode, _guildId, _rid )
    if Channels[_gameNode] then
        local channel = Channels[_gameNode][Enum.ChatChannel.GUILD][_guildId]
        if channel then
            ChatLogic:updateRoleInfo( { rid = _rid, guildId = 0 } )
            MSM.ChatChannel[_rid].req.leaveChannel( _rid, Enum.ChatChannel.GUILD )
            MSM.ChatChannelEntity[channel].req.leaveChannelEntity( _gameNode, channel, _rid )
        end
    end
end

---@see 新增群组频道
function response.addGroupChannel( _gameNode, _groupIndex )
    if Channels[_gameNode] then
        local channel = newChannelId()
        Channels[_gameNode][Enum.ChatChannel.GROUP][_groupIndex] = channel
        MSM.ChatChannelEntity[channel].req.newChannelEntity( _gameNode, channel )
        return channel
    end
end

---@see 删除群组频道
function response.delGroupChannel( _gameNode, _groupIndex )
    if Channels[_gameNode] then
        local channel = Channels[_gameNode][Enum.ChatChannel.GROUP][_groupIndex]
        if channel then
            MSM.ChatChannelEntity[channel].req.delChannelEntity( _gameNode, channel )
        end
        Channels[_gameNode][Enum.ChatChannel.GROUP][_groupIndex] = nil
    end
end

---@see 群组频道加入角色
function response.groupChannelAddRole( _gameNode, _groupIndex, _rid, _gameId )
    if Channels[_gameNode] then
        local channel = Channels[_gameNode][Enum.ChatChannel.GROUP][_groupIndex]
        if not channel then
            -- 增加群组频道
            channel = snax.self().req.addGroupChannel( _gameNode, _groupIndex )
        end

        if channel then
            ChatLogic:updateRoleInfo( { rid = _rid, groupIndex = _groupIndex } )
            MSM.ChatChannel[_rid].req.joinChannel( _rid, Enum.ChatChannel.GROUP, channel )
            MSM.ChatChannelEntity[channel].req.joinChannelEntity( _gameNode, channel, _rid, _gameId )
        end
    end
end

---@see 群组频道删除角色
function response.groupChannelDelRole( _gameNode, _groupIndex, _rid )
    if Channels[_gameNode] then
        local channel = Channels[_gameNode][Enum.ChatChannel.GROUP][_groupIndex]
        if channel then
            ChatLogic:updateRoleInfo( { rid = _rid, groupIndex = 0 } )
            MSM.ChatChannel[_rid].req.leaveChannel( _rid, Enum.ChatChannel.GROUP )
            MSM.ChatChannelEntity[channel].req.leaveChannelEntity( _gameNode, channel, _rid )
        end
    end
end

---@see 检测聊天频道间隔
function accept.checkAndSetInterval( _rid, _channelType )
    local sChatChannelInfo = CFG.s_ChatChannel:Get(_channelType)
    if not sChatChannelInfo then
        -- 没找到相关频道信息
        return false
    end
    return MSM.ChatChannel[_rid].req.checkAndSetInterval(_rid, _channelType, sChatChannelInfo.timeInterval)
end

---@see 接收处理其他服务器发送的消息
function accept.recvMessageFromServer( _roleInfo, _channelType, _msgContent, _msgArgs,
                                _noSelf, _noRoleAttr, _hyperLinkData, _uniqeIndex, _reSendRid, _gameId )
    local routeRid = _reSendRid or _roleInfo.rid
    if  not Channels[_roleInfo.gameNode] then
        -- 聊天服务器重启了,自己初始化
        snax.self().req.initChannelWithNode( _roleInfo.gameNode )
        if routeRid then
            -- 加入频道
            snax.self().req.joinAllChannel(_roleInfo.gameNode, routeRid, _roleInfo)
        end
    end

    if not routeRid then -- 系统消息
        _roleInfo.rid = 0
        _roleInfo.systemChannel = Channels[_roleInfo.gameNode]
    end

    if not routeRid then
        routeRid = 0
    end -- 系统消息
    MSM.ChatChannel[routeRid].post.publishMsg( _channelType, _roleInfo, _msgContent, _msgArgs, _gameId )
end

---@see 加入所有系统级频道
function response.joinAllChannel( _gameNode, _rid, _roleInfo )
    if not Channels[_gameNode] then
        -- 聊天服务器重启了,自己初始化
        snax.self().req.initChannelWithNode( _gameNode )
    end

    local channel
    -- 加入世界频道
    channel = Channels[_gameNode][Enum.ChatChannel.WORLD]
    if channel then
        MSM.ChatChannel[_rid].req.joinChannel( _rid, Enum.ChatChannel.WORLD, channel )
        MSM.ChatChannelEntity[channel].req.joinChannelEntity( _gameNode, channel, _rid, _roleInfo.gameId )
    end

    -- 加入联盟频道
    if _roleInfo.guildId and _roleInfo.guildId > 0 then
        channel = Channels[_gameNode][Enum.ChatChannel.GUILD][_roleInfo.guildId]
        if channel then
            MSM.ChatChannel[_rid].req.joinChannel( _rid, Enum.ChatChannel.GUILD, channel )
            MSM.ChatChannelEntity[channel].req.joinChannelEntity( _gameNode, channel, _rid, _roleInfo.gameId )
        end
    end
end

---@see 离开所有系统级频道
function response.leaveAllChannel( _gameNode, _rid, _roleInfo )
    if not Channels[_gameNode] then return end
    local channel
    -- 离开世界频道
    channel = Channels[_gameNode][Enum.ChatChannel.WORLD]
    if channel then
        MSM.ChatChannel[_rid].req.leaveChannel( _rid, Enum.ChatChannel.WORLD, channel )
        MSM.ChatChannelEntity[channel].req.leaveChannelEntity( _gameNode, channel, _rid )
    end

    -- 离开联盟频道
    if _roleInfo.guildId and _roleInfo.guildId > 0 then
        channel = Channels[_gameNode][Enum.ChatChannel.GUILD][_roleInfo.guildId]
        if channel then
            ChatLogic:updateRoleInfo( { rid = _rid, guildId = 0 } )
            MSM.ChatChannel[_rid].req.leaveChannel( _rid, Enum.ChatChannel.GUILD, channel )
            MSM.ChatChannelEntity[channel].req.leaveChannelEntity( _gameNode, channel, _rid )
        end
    end
end

---@see 根据频道类型获取频道ChannelId
function response.getChannelIdByChannelType( _channelType )
    local channelIds = {}

    for gameNode, channelInfo in pairs(Channels) do
        channelIds[gameNode] = channelInfo[_channelType]
    end

    return channelIds
end

---@see 后台发送公告
function accept.sendAnnouncement( _gameNode, _channelType, _gameId, _guildId, _content )
    if _channelType == Enum.ChatChannel.WORLD then
        -- 世界频道
        local notifyGameNode
        if not _gameNode then
            notifyGameNode = table.indexs( Channels )
        else
            notifyGameNode = _gameNode
        end

        local sendContent = _content.cn
        local channelId, roleInfo
        for _, gameNode in pairs(notifyGameNode) do
            roleInfo = { rid = 0, gameNode = gameNode }
            channelId = Channels[gameNode][Enum.ChatChannel.WORLD]
            if _gameId and _gameId > 0 then
                if _gameId == Enum.GameID.ANDROID_EN or _gameId == Enum.GameID.IOS_EN then
                    sendContent = _content.en
                elseif _gameId == Enum.GameID.ANDROID_ARB or _gameId == Enum.GameID.IOS_ARB then
                    sendContent = _content.arb
                elseif _gameId == Enum.GameID.ANDROID_TUR or _gameId == Enum.GameID.IOS_TUR then
                    sendContent = _content.tr
                elseif _gameId == Enum.GameID.ANDROID_CN or _gameId == Enum.GameID.IOS_CN then
                    sendContent = _content.cn
                end
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, sendContent, {}, _gameId, channelId )
            else
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.en, {}, Enum.GameID.ANDROID_EN, channelId )
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.arb, {}, Enum.GameID.ANDROID_ARB, channelId )
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.tr, {}, Enum.GameID.ANDROID_TUR, channelId )
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.cn, {}, Enum.GameID.ANDROID_CN, channelId )
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.en, {}, Enum.GameID.IOS_EN, channelId )
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.arb, {}, Enum.GameID.IOS_ARB, channelId )
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.tr, {}, Enum.GameID.IOS_TUR, channelId )
                MSM.ChatChannel[0].post.publishMsg( _channelType, roleInfo, _content.cn, {}, Enum.GameID.IOS_CN, channelId )
            end
        end
    end
end