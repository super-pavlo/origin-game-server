--[[
* @file : MapMarkerLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Sep 10 2020 19:26:38 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图书签相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local GuildLogic = require "GuildLogic"

local MapMarkerLogic = {}

---@see 添加个人书签
function MapMarkerLogic:addRoleMarker( _rid, _markerId, _description, _gameNode, _pos, _markers, _block )
    local markerIndex = 1
    _markers = _markers or RoleLogic:getRole( _rid, Enum.Role.markers ) or {}

    for i = 1, table.size( _markers ) + 1 do
        if not _markers[i] then
            markerIndex = i
        end
    end

    _markers[markerIndex] = {
        markerIndex = markerIndex,
        markerId = _markerId,
        description = _description,
        gameNode = _gameNode,
        pos = _pos,
        markerTime = os.time(),
        status = Enum.MapMarkerStatus.READ
    }

    -- 更新推送角色书签信息
    RoleLogic:setRole( _rid, { [Enum.Role.markers] = _markers } )
    RoleSync:syncSelf( _rid, { [Enum.Role.markers] = { [markerIndex] = _markers[markerIndex] } }, true, _block )
end

---@see 添加联盟书签
function MapMarkerLogic:addGuildMarker( _guildId, _rid, _markerId, _description, _gameNode, _pos, _oldMarkerId )
    local roleName = RoleLogic:getRole( _rid, Enum.Role.name )
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.markers, Enum.Guild.members } ) or {}
    local markers = guildInfo.markers or {}
    if markers[_markerId] then
        -- 已有该联盟书签
        markers[_markerId].description = _description
        markers[_markerId].gameNode = _gameNode
        markers[_markerId].pos = _pos
        markers[_markerId].readRoles = {}
        markers[_markerId].markRid = _rid
        markers[_markerId].markerTime = os.time()
        markers[_markerId].createName = roleName
    else
        -- 无该联盟书签
        markers[_markerId] = {
            markerId = _markerId,
            description = _description,
            gameNode = _gameNode,
            pos = _pos,
            markerTime = os.time(),
            readRoles = {},
            markRid = _rid,
            createName = roleName,
        }
    end

    local syncMarker = {}
    if _oldMarkerId and _oldMarkerId > 0 and _oldMarkerId ~= _markerId then
        markers[_oldMarkerId] = nil
        syncMarker[_oldMarkerId] = { markerId = _oldMarkerId, status = Enum.MapMarkerStatus.DELETE }
    end
    -- 更新推送联盟书签
    GuildLogic:setGuild( _guildId, { [Enum.Guild.markers] = markers } )
    local onlineMembers = GuildLogic:getAllOnlineMember( _guildId, guildInfo.members ) or {}
    -- 设置联盟书签通知
    GuildLogic:guildNotify( onlineMembers, Enum.GuildNotify.ADD_GUILD_MARKER, { { name = roleName } }, { _markerId } )
    -- 推送书签给全联盟
    syncMarker[_markerId] = {
        markerId = _markerId,
        description = _description,
        gameNode = _gameNode,
        pos = _pos,
        markerTime = os.time(),
        status = Enum.MapMarkerStatus.NO_READ,
        createName = roleName,
    }
    self:syncGuildMarker( _guildId, _rid, syncMarker, true )
    -- 通知联盟其他角色
    table.removevalue( onlineMembers, _rid )
    if #onlineMembers > 0 then
        self:syncGuildMarker( _guildId, onlineMembers, syncMarker )
    end
    -- 发送联盟邮件
    local mail = CFG.s_MapMarkerType:Get( _markerId, "mail" )
    if mail and mail > 0 then
        local otherInfo = {
            guildEmail = {
                roleName = roleName,
                markerId = _markerId,
                markerDesc = _description,
                pos = _pos
            }
        }
        MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, guildInfo.members, mail, otherInfo )
    end
end

---@see 推送联盟地图书签
function MapMarkerLogic:syncGuildMarker( _guildId, _toRids, _markers, _block )
    _toRids = _toRids or GuildLogic:getAllOnlineMember( _guildId ) or {}
    if Common.isTable( _toRids ) and table.empty( _toRids ) then
        return
    end

    -- 推送联盟书签信息
    Common.syncMsg( _toRids, "Guild_MapMarkers", { markers = _markers }, _block )
end

---@see 角色登录或加入联盟推送联盟书签消息
function MapMarkerLogic:pushGuildMarkers( _rid, _guildId )
    _guildId = _guildId or RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if _guildId <= 0 then
        return
    end

    local syncMarkers = {}
    local markers = GuildLogic:getGuild( _guildId, Enum.Guild.markers ) or {}
    for markerId, markerInfo in pairs( markers ) do
        syncMarkers[markerId] = {
            markerId = markerId,
            description = markerInfo.description,
            gameNode = markerInfo.gameNode,
            pos = markerInfo.pos,
            markerTime = markerInfo.markerTime,
            createName = markerInfo.createName,
        }
        if table.exist( markerInfo.readRoles, _rid ) then
            syncMarkers[markerId].status = Enum.MapMarkerStatus.READ
        else
            syncMarkers[markerId].status = Enum.MapMarkerStatus.NO_READ
        end
    end

    -- 推送联盟书签信息
    Common.syncMsg( _rid, "Guild_MapMarkers", { markers = syncMarkers } )
end

---@see 删除联盟书签
function MapMarkerLogic:deleteGuildMarker( _guildId, _rid, _markerId )
    local markers = GuildLogic:getGuild( _guildId, Enum.Guild.markers ) or {}
    if not markers[_markerId] then return end

    markers[_markerId] = nil
    GuildLogic:setGuild( _guildId, Enum.Guild.markers, markers )
    -- 推送联盟书签信息
    local onlineMembers = GuildLogic:getAllOnlineMember( _guildId ) or {}
    -- 发送联盟通知
    GuildLogic:guildNotify( onlineMembers, Enum.GuildNotify.DELETE_GUILD_MARKER, { RoleLogic:getRole( _rid, { Enum.Role.name } ) }, { _markerId } )
    -- 推送联盟书签信息
    local syncMarker = { [_markerId] = { markerId = _markerId, status = Enum.MapMarkerStatus.DELETE } }
    self:syncGuildMarker( _guildId, onlineMembers, syncMarker, true )
    -- 通知联盟其他成员
    table.removevalue( onlineMembers, _rid )
    if #onlineMembers > 0 then
        self:syncGuildMarker( _guildId, onlineMembers, syncMarker )
    end
end

---@see 更新联盟书签读取状态
function MapMarkerLogic:updateGuildMarkerStatus( _guildId, _rid )
    local syncMarkers = {}
    local markers = GuildLogic:getGuild( _guildId, Enum.Guild.markers ) or {}
    for markerId, markerInfo in pairs( markers ) do
        if not table.exist( markerInfo.readRoles, _rid ) then
            table.insert( markerInfo.readRoles, _rid )
            syncMarkers[markerId] = {
                markerId = markerId,
                status = Enum.MapMarkerStatus.READ
            }
        end
    end

    if not table.empty( syncMarkers ) then
        -- 更新联盟书签读取状态
        GuildLogic:setGuild( _guildId, { [Enum.Guild.markers] = markers } )
        -- 推送联盟书签读取状态
        self:syncGuildMarker( _guildId, _rid, syncMarkers )
    end
end

---@see 角色改名更新联盟书签创建者名称
function MapMarkerLogic:updateGuildMarkerName( _guildId, _rid, _name )
    local syncMarkers = {}
    local markers = GuildLogic:getGuild( _guildId, Enum.Guild.markers ) or {}
    _name = _name or RoleLogic:getRole( _rid, Enum.Role.name )
    for markerId, markerInfo in pairs( markers ) do
        if markerInfo.markRid == _rid and markerInfo.createName ~= _name then
            markerInfo.createName = _name
            syncMarkers[markerId] = {
                markerId = markerId,
                createName = _name
            }
        end
    end

    if not table.empty( syncMarkers ) then
        -- 更新联盟书签读取状态
        GuildLogic:setGuild( _guildId, { [Enum.Guild.markers] = markers } )
        -- 推送联盟书签读取状态
        self:syncGuildMarker( _guildId, nil, syncMarkers )
    end
end

return MapMarkerLogic