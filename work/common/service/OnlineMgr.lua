--[[
* @file : OnlineMgr.lua
* @type : snax single service
* @author : linfeng九  零 一 起 玩 w w w . 9 0 1 7 5 . co m
* @created : Wed Aug 22 2018 11:06:05 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 在线人数管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local Timer = require "Timer"
local LogLogic = require "LogLogic"

local onlineCount = 0
local onlineRids = {}
local onlineCountGameId = {}

---@see 定时记录日志
local function recordServerOnline()
    LogLogic:serverOnline( onlineCount )
end

function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
    -- 1分钟记录一次在线人数
    Timer.runEvery(6000, recordServerOnline)
    -- 上报给登陆服务器
    local allLoginServer = Common.getClusterNodeByName( "login", true )
    local gameNode = Common.getSelfNodeName()
    local openTime = Common.getSelfNodeOpenTime()
    if allLoginServer then
        for _, loginNode in pairs(allLoginServer) do
            Common.rpcSend( loginNode, "AccountMgr", "regGameServerOpenTime", gameNode, openTime )
        end
    end
end

---@see 增加在线人数
function accept.addOnline( _rid, _gameId )
    if not onlineRids[_rid] then
        onlineRids[_rid] = _gameId
        onlineCount = onlineCount + 1
        if _gameId then
            if not onlineCountGameId[_gameId] then onlineCountGameId[_gameId] = 0 end
            onlineCountGameId[_gameId] = onlineCountGameId[_gameId] + 1
        end
        LOG_INFO("rid(%d) online, curonline(%d)", _rid, onlineCount)
    end
end

---@see 减少在线人数
function accept.delOnline( _rid, _gameId )
    if onlineRids[_rid] then
        onlineRids[_rid] = nil
        onlineCount = onlineCount - 1
        if _gameId then
            onlineCountGameId[_gameId] = onlineCountGameId[_gameId] - 1
        end
        LOG_INFO("rid(%d) offline, curonline(%d)", _rid, onlineCount)
    end
end

---@see 获取当前在线人数
function response.getOnline( _gameId )
    if not _gameId or _gameId == 0 then
        return onlineCount
    else
        return onlineCountGameId[_gameId] or 0
    end
end

---@see 检查是否在线
function response.checkOnline( _rid )
    return onlineRids[_rid] ~= nil
end

---@see 获取在线的rid
function response.getAllOnlineRid()
    return table.indexs( onlineRids )
end

---@see 获取在线的rid.根据gameId区分
function response.getAllOnlineRidWithGameId()
    return onlineRids
end

---@see 获取在线角色
function response.getOnlineRoles( _roles )
    local onlineRoles = {}
    for rid in pairs( _roles or {} ) do
        if onlineRids[rid] then
            table.insert( onlineRoles, rid )
        end
    end

    return onlineRoles
end

---@see 获取不在线角色
function response.getOfflineRoles( _roles )
    local offlineRoles = {}
    for rid in pairs( _roles or {} ) do
        if not onlineRids[rid] then
            table.insert( offlineRoles, rid )
        end
    end

    return offlineRoles
end