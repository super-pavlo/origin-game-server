--[[
* @file : PushMgr.lua
* @type : snax single service
* @author : chenlei
* @created : Tue Dec 4 2018 14:29:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 推送服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"

--  { [ActivityType] = {
--         11 = {rid = 11, level = 11, name = 11, deviceType = 1111, accountId = 11111 },
--         22 = {rid = 22, level = 22, name = 22, deviceType = 2222, accountId = 11111  },... },
--   ...
--  }
local activityRids = {}
local allRids = {}
local languageId = {}


local function formatPushList( _pushList, _pushType, _args )
    local s_PushMessageData = CFG.s_PushMessageData:Get( _pushType )
    local pushList = {}
    local msg
    for _, v in pairs(_pushList) do
        if v.account and v.account ~= "" then
            if not pushList[v.account] then
                if v.language == Enum.LanguageType.ENGLISH then
                    msg = s_PushMessageData.enMessage
                elseif v.language == Enum.LanguageType.ARABIC then
                    msg = s_PushMessageData.arabicMessage
                elseif v.language == Enum.LanguageType.CHINESE then
                    msg = s_PushMessageData.cnMessage
                elseif v.language == Enum.LanguageType.TURKEY then
                    msg = s_PushMessageData.trMessage
                else
                    msg = s_PushMessageData.enMessage
                end
                if _pushType == Enum.PushType.BUILD then
                    local l_nameId = CFG.s_BuildingTypeConfig:Get( _args.arg1, "l_nameId" )
                    local languageServer = CFG.s_LanguageServer:Get( l_nameId )
                    if v.language == Enum.LanguageType.ENGLISH then
                        msg = string.format( msg, languageServer.en )
                    elseif v.language == Enum.LanguageType.ARABIC then
                        msg = string.format( msg, languageServer.arabic )
                    elseif v.language == Enum.LanguageType.CHINESE then
                        msg = string.format( msg, languageServer.cn )
                    elseif v.language == Enum.LanguageType.TURKEY then
                        msg = string.format( msg, languageServer.tr )
                    else
                        msg = string.format( msg, languageServer.en )
                    end
                elseif _pushType == Enum.PushType.TARIN then
                    local l_nameId = CFG.s_Arms:Get( _args.arg1, "l_armsID" )
                    local languageServer = CFG.s_LanguageServer:Get( l_nameId )
                    if v.language == Enum.LanguageType.ENGLISH then
                        msg = string.format( msg, languageServer.en )
                    elseif v.language == Enum.LanguageType.ARABIC then
                        msg = string.format( msg, languageServer.arabic )
                    elseif v.language == Enum.LanguageType.CHINESE then
                        msg = string.format( msg, languageServer.cn )
                    elseif v.language == Enum.LanguageType.TURKEY then
                        msg = string.format( msg, languageServer.tr )
                    else
                        msg = string.format( msg, languageServer.en )
                    end
                elseif _pushType == Enum.PushType.TECH then
                    local l_nameId = CFG.s_Study:Get( _args.arg1, "l_nameID" )
                    local languageServer = CFG.s_LanguageServer:Get( l_nameId )
                    if v.language == Enum.LanguageType.ENGLISH then
                        msg = string.format( msg, languageServer.en )
                    elseif v.language == Enum.LanguageType.ARABIC then
                        msg = string.format( msg, languageServer.arabic )
                    elseif v.language == Enum.LanguageType.CHINESE then
                        msg = string.format( msg, languageServer.cn )
                    elseif v.language == Enum.LanguageType.TURKEY then
                        msg = string.format( msg, languageServer.tr )
                    else
                        msg = string.format( msg, languageServer.en )
                    end
                elseif _pushType == Enum.PushType.SCOUT then
                    msg = string.format( msg, _args.arg1, _args.arg2 )
                elseif _pushType == Enum.PushType.PERSON_MAIL then
                    msg = string.format( msg, _args.arg1, _args.arg2 )
                elseif _pushType == Enum.PushType.ALLIANCE_CHAT then
                    msg = string.format( msg, _args.arg1, _args.arg2 )
                elseif _pushType == Enum.PushType.ARMY_RETURN then
                    msg = string.format( msg, _args.arg1 )
                elseif _pushType == Enum.PushType.RALLY then
                    local languageServer = CFG.s_LanguageServer:Get( languageId[_args.arg2] )
                    if v.language == Enum.LanguageType.ENGLISH then
                        msg = string.format( msg, _args.arg1, languageServer.en )
                    elseif v.language == Enum.LanguageType.ARABIC then
                        msg = string.format( msg, _args.arg1, languageServer.arabic )
                    elseif v.language == Enum.LanguageType.CHINESE then
                        msg = string.format( msg, _args.arg1, languageServer.cn )
                    elseif v.language == Enum.LanguageType.TURKEY then
                        msg = string.format( msg, _args.arg1, languageServer.tr )
                    else
                        msg = string.format( msg, _args.arg1, languageServer.en )
                    end
                elseif _pushType == Enum.PushType.CITY_ATTACK then
                    msg = string.format( msg, _args.arg1, _args.arg2 )
                end
                v.msg = msg
                pushList[v.account] = v
            end
        end
    end
    return pushList
end

---@see 推送通知
function accept.push( _pushList, _pushType, _args )
    local ret, pushList = pcall(formatPushList, _pushList, _pushType, _args )
    if ret and pushList then
        local pushNode = Common.getPushNode()
        if pushNode then
            Common.rpcSend( pushNode, "MessagePush", "pushMessage", pushList )
        end
    else
        LOG_ERROR("PushMgr push error:%s", tostring(pushList))
    end
end

---@see 插入更新推送数据
function accept.updateAllRid( _rid, _arg )
    if Common.isMainLine() then
        if not allRids.pushList then allRids.pushList = {} end
        allRids.pushList[_rid] = _arg
        local info = SM.c_pushInfo.req.Get( Enum.PushDbType.ALL )
        if not info then
            SM.c_pushInfo.req.Add( Enum.PushDbType.ALL, allRids )
        else
            SM.c_pushInfo.req.Set( Enum.PushDbType.ALL, allRids )
        end
        for activityType, v in pairs (activityRids) do
            if not v.pushList then v.pushList = {} end
            if v.pushList[_rid] then
                v.pushList[_rid] = _arg
                info = SM.c_pushInfo.req.Get( activityType )
                if not info then
                    SM.c_pushInfo.req.Add( activityType, v )
                else
                    SM.c_pushInfo.req.Set( activityType, v )
                end
            end
        end
    else
        local mainLine = Common.getMainLine()
        return Common.rpcSend( mainLine, "PushMgr", "updateAllRid", _rid, _arg )
    end
end

---@see 插入更新推送数据
function accept.updateActivityRids( _activityType, _rid, _arg )
    if Common.isMainLine() then
        if not activityRids[_activityType] then activityRids[_activityType] = {} end
        if not activityRids[_activityType].pushList then activityRids[_activityType].pushList = {} end
        activityRids[_activityType].pushList[_rid] = _arg
        local info = SM.c_pushInfo.req.Get( _activityType )
        if not info then
            SM.c_pushInfo.req.Add( _activityType, activityRids[_activityType] )
        else
            SM.c_pushInfo.req.Set( _activityType, activityRids[_activityType] )
        end
    else
        local mainLine = Common.getMainLine()
        return Common.rpcSend( mainLine, "PushMgr", "updateActivityRids", _activityType, _rid, _arg )
    end
end

---@see 返回所有玩家推送信息
function response.getAllRids()
    if Common.isMainLine() then
        return allRids.pushList or {}
    else
        local mainLine = Common.getMainLine()
        return Common.rpcCall( mainLine, "PushMgr", "getAllRids" )
    end
end

---@see 返回指定活动玩家推送信息
function response.getActivityRids( _activityType )
    if Common.isMainLine() then
        if not activityRids[_activityType] then
            return {}
        end
        return activityRids[_activityType].pushList or {}
    else
        local mainLine = Common.getMainLine()
        return Common.rpcCall( mainLine, "PushMgr", "getActivityRids", _activityType )
    end
end

---@see 读取数据
local function load(key)
    allRids = SM.c_pushInfo.req.Get( key ) or {}
    local sActivityOpen = CFG.s_ActivityOpen:Get()
    for _ ,ActivityOpenInfo in pairs(sActivityOpen) do
        if ActivityOpenInfo.pushTime > 0 then
            activityRids[ActivityOpenInfo.ID] = SM.c_pushInfo.req.Get( ActivityOpenInfo.ID )
        end
    end
end

---@see 联盟聊天推送
function accept.sendAllianceChtPush( _rid, _name, _msg )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    local members = GuildLogic:getAllNotOnlineMember( guildId )
    for _, rid in pairs( members ) do
        local args = { pushRid = rid, pushType = Enum.PushType.ALLIANCE_CHAT, args = { arg1 = _name, arg2 = _msg } }
        snax.self().post.sendPush(args)
    end
end

---@see 推送
function accept.sendPush( _args )
    local pushRid = _args.pushRid
    local pushType = _args.pushType
    if RoleLogic:checkPushOpen( _args.pushRid, pushType ) and Common.offOnline( _args.pushRid ) then
        local pushList = {}
        local roleInfo = RoleLogic:getRole( pushRid, { Enum.Role.iggid, Enum.Role.language, Enum.Role.platform, Enum.Role.gameId })
        pushList[roleInfo.iggid] = { account = roleInfo.iggid, language = roleInfo.language, platform = roleInfo.platform, gameId = roleInfo.gameId }
        snax.self().post.push(pushList, pushType, _args.args )
    end
end

---@see 更新推送信息包括活动
function accept.updateAllRids( _rid, _arg )
    if Common.isMainLine() then
        if not allRids.pushList then allRids.pushList = {} end
        allRids.pushList[_rid] = _arg
        local info = SM.c_pushInfo.req.Get( Enum.PushDbType.ALL )
        if not info then
            SM.c_pushInfo.req.Add( Enum.PushDbType.ALL, allRids )
        else
            SM.c_pushInfo.req.Set( Enum.PushDbType.ALL, allRids )
        end
        for activityType, v in pairs (activityRids) do
            if not v.pushList then v.pushList = {} end
            v.pushList[_rid] = _arg
            info = SM.c_pushInfo.req.Get( activityType )
            if not info then
                SM.c_pushInfo.req.Add( activityType, v )
            else
                SM.c_pushInfo.req.Set( activityType, v )
            end
        end
    else
        local mainLine = Common.getMainLine()
        Common.rpcSend( mainLine, "PushMgr", "updateAllRids", _rid, _arg )
    end
end

function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
    languageId[1] = 782050
    languageId[2] = 782051
    languageId[3] = 782052
    languageId[4] = 782053
    -- 主线路才处理
    -- if Common.isMainLine() then
    --     load(Enum.PushDbType.ALL)
    -- end
    -- local pushList = {}
    -- pushList[111] = { account = "123", language = 40 }
    -- snax.self().post.push(pushList, 1001, { arg1 = 1})
end

function accept.empty()
    -- body
end