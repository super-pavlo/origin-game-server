--[[
* @file : ResourcePointMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Thu Jul 02 2020 18:44:29 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟资源点管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildLogic = require "GuildLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"

---@see 领土所占资源点信息
---@type table<int, table<int, table<string, int>>>
local territoryResourcePoints = {} -- { [territoryId] = { [objectIndex] = { buildType = type1 } } }

---@see 地块联盟资源点信息
function accept.addTerritoryResourcePoint( _pos, _objectIndex, _buildType )
    local territoryId = GuildTerritoryLogic:getPosTerritoryId( _pos )
    if not territoryResourcePoints[territoryId] then
        territoryResourcePoints[territoryId] = {}
    end

    territoryResourcePoints[territoryId][_objectIndex] = { buildType = _buildType }
end

---@see 联盟占用领土资源点
function response.addGuildTerritoryResourcePoint( _guildId, _territoryIds, _lock )
    local resourcePoints = {}
    local updateInfo = {
        guildId = _guildId, guildAbbName = GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName ),
    }
    for _, territoryId in pairs( _territoryIds ) do
        for objectIndex, resourceInfo in pairs( territoryResourcePoints[territoryId] or {} ) do
            if not resourcePoints[resourceInfo.buildType] then
                resourcePoints[resourceInfo.buildType] = 1
            else
                resourcePoints[resourceInfo.buildType] = resourcePoints[resourceInfo.buildType] + 1
            end
            -- 联盟资源点改名
            MSM.SceneGuildResourcePointMgr[objectIndex].post.updateGuildResourcePointInfo( objectIndex, updateInfo )
        end
    end

    -- 增加联盟资源点
    for type, num in pairs( resourcePoints ) do
        if _lock then
            GuildLogic:guildResourcePointChange( _guildId, type, num )
        else
            MSM.GuildMgr[_guildId].post.guildResourcePointChange( _guildId, type, num )
        end
    end
end

---@see 联盟释放领土资源点
function response.delGuildTerritoryResourcePoint( _guildId, _territoryIds, _lock, _disbandGuild )
    local resourcePoints = {}
    local updateInfo = { guildId = 0, guildAbbName = "" }
    for _, territoryId in pairs( _territoryIds ) do
        for objectIndex, resourceInfo in pairs( territoryResourcePoints[territoryId] or {} ) do
            if not resourcePoints[resourceInfo.buildType] then
                resourcePoints[resourceInfo.buildType] = 1
            else
                resourcePoints[resourceInfo.buildType] = resourcePoints[resourceInfo.buildType] + 1
            end
            -- 联盟资源点改名
            MSM.SceneGuildResourcePointMgr[objectIndex].post.updateGuildResourcePointInfo( objectIndex, updateInfo )
        end
    end
    -- 旧的联盟失去资源点
    if not _disbandGuild then
        for type, num in pairs( resourcePoints ) do
            -- 删除联盟资源点
            if _lock then
                GuildLogic:guildResourcePointChange( _guildId, type, - num )
            else
                MSM.GuildMgr[_guildId].post.guildResourcePointChange( _guildId, type, - num )
            end
        end
    end
end