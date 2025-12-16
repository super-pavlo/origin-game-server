--[[
* @file : ChatChannelEntity.lua
* @type : snax multi service
* @author : linfeng
* @created : Mon May 14 2018 10:33:40 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天对象实体服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local ChannelEntitys = {}

---@see 新建channelentity
function response.newChannelEntity( _gameNode, _channelId )
    if not ChannelEntitys[_gameNode] then ChannelEntitys[_gameNode] = {} end
    ChannelEntitys[_gameNode][_channelId] = {}
end

---@see 删除channelentity
function response.delChannelEntity( _gameNode, _channelId )
    if ChannelEntitys[_gameNode] then
        ChannelEntitys[_gameNode][_channelId] = nil
    end
end

---@see rid加入entity
function response.joinChannelEntity( _gameNode, _channelId, _rid, _gameId )
    if ChannelEntitys[_gameNode][_channelId] then
        ChannelEntitys[_gameNode][_channelId][_rid] = _gameId
    end
end

---@see rid离开entity
function response.leaveChannelEntity( _gameNode, _channelId, _rid )
    if ChannelEntitys[_gameNode][_channelId] then
        ChannelEntitys[_gameNode][_channelId][_rid] = nil
    end
end

---@see 获取entity下的rids
function response.getRidsFromEntity( _gameNode, _channelId, _gameId )
    local rids = {}
    if ChannelEntitys[_gameNode] and ChannelEntitys[_gameNode][_channelId] then
        for rid, roleGameId in pairs(ChannelEntitys[_gameNode][_channelId]) do
            -- 过滤平台和语言
            if not _gameId or _gameId <= 0 or _gameId == roleGameId then
                table.insert( rids, rid )
            end
        end
    end
    return rids
end