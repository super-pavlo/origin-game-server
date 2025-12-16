--[[
 * @file : WebLogic.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2019-03-29 08:51:58
 * @Last Modified time: 2019-03-29 08:51:58
 * @department : Arabic Studio
 * @brief : 游戏服务器相关接口,暴露给运营调用
 * Copyright(C) 2019 IGG, All rights reserved
]]

local cjson = require "cjson.safe"
local WebCmd = require "WebCmd"

---@see 转化检查
function WebCmd.checkProxy( _data, _funcName )
    local data = cjson.decode(_data)
    if not data then
        return true, cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end
    if data.gameNode and Common.getSelfNodeName() ~= data.gameNode then
        local allGameNodes = Common.getClusterNodeByName( data.gameNode, true )
        if not allGameNodes or table.empty(allGameNodes) then
            return true, cjson.encode( { code = Enum.WebError.SERVER_NODE_NOT_FOUND } )
        end

        return true, Common.rpcCall( allGameNodes[1], "WebProxy", "Do", _funcName, _data )
    end
end

---@see 增加道具
function WebCmd.addItem( _, _data )
    local checkRet, retData = WebCmd.checkProxy( _data, "addItem" )
    if checkRet then return retData end

    if Common.getSelfNodeName():find("game") == nil then
        return cjson.encode( { code = Enum.WebError.ADDITEM_NOT_GAME } )
    end

    _data = cjson.decode(_data)
    if not _data or not _data.rids or not _data.items or table.empty( _data.items ) then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end

    local RoleLogic = require "RoleLogic"
    for _, rid in pairs(_data.rids) do
        if RoleLogic:getRole( rid, Enum.Role.rid ) then
            -- 增加道具
            local ItemLogic = require "ItemLogic"
            for _, itemInfo in pairs( _data.items ) do
                if itemInfo.itemId and itemInfo.itemNum then
                    ItemLogic:addItem( { rid = rid, itemId = itemInfo.itemId, itemNum = itemInfo.itemNum } )
                end
            end
        end
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS } )
end

---@see 扣除道具
function WebCmd.delItem( _, _data )
    local checkRet, retData = WebCmd.checkProxy( _data, "delItem" )
    if checkRet then return retData end

    if Common.getSelfNodeName():find("game") == nil then
        return cjson.encode( { code = Enum.WebError.DELITEM_NOT_GAME } )
    end

    _data = cjson.decode(_data)
    if not _data or not _data.rids or not _data.items or table.empty( _data.items ) then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end

    local RoleLogic = require "RoleLogic"
    for _, rid in pairs(_data.rids) do
        if RoleLogic:getRole( rid, Enum.Role.rid ) then
            -- 扣除道具
            local ItemLogic = require "ItemLogic"
            for _, itemInfo in pairs( _data.items ) do
                if itemInfo.itemId and itemInfo.itemNum then
                    ItemLogic:delItemById( rid, itemInfo.itemId,itemInfo.itemNum, nil, Enum.LogType.DEL_ITEM_FROM_WEB )
                end
            end
        end
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS } )
end

---@see 查询角色信息
function WebCmd.getRoleInfo( _, _data )
    _data = cjson.decode(_data)
    if not _data or not _data.iggid then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end
    -- 向登陆服务器查询iggid下的角色列表
    local allLoginServer = Common.getClusterNodeByName( "login", true )
    local data = Common.rpcMultiCall(allLoginServer[1], "RoleQuery", "getRoleDetailList", 0, _data.iggid, _data.rid )
    return cjson.encode( { code = Enum.WebError.SUCCESS, data = data } )
end

---@see 封号角色
function WebCmd.banRole( _, _data )
    _data = cjson.decode(_data)
    local allLoginServer = Common.getClusterNodeByName( "login", true )
    if Common.rpcMultiCall(allLoginServer[1], "RoleQuery", "banRole", 0, _data.iggid, _data.ban ) then
        return cjson.encode( { code = Enum.WebError.SUCCESS } )
    else
        return cjson.encode( { code = Enum.WebError.ROLE_BAN_NOT_FOUND } )
    end
end

---@see 禁言角色
function WebCmd.silenceRole( _, _data )
    _data = cjson.decode(_data)
    local allLoginServer = Common.getClusterNodeByName( "login", true )
    if Common.rpcMultiCall(allLoginServer[1], "RoleQuery", "silenceRole", 0, _data.iggid, _data.time ) then
        return cjson.encode( { code = Enum.WebError.SUCCESS } )
    else
        return cjson.encode( { code = Enum.WebError.ROLE_SILENCE_NOT_FOUND } )
    end
end

---@see 获取在线人数
function WebCmd.getOnline( _, _data )
    _data = cjson.decode(_data)
    local allGameServer
    if not _data.gameNode then
        -- 获取全服务器的在线
        allGameServer = Common.getClusterNodeByName( "game", true )
    else
        -- 获取指定服务器的在线
        allGameServer = Common.getClusterNodeByName( _data.gameNode )
        allGameServer = { allGameServer }
    end

    local data = {}
    local online
    for _, gameNodeName in pairs(allGameServer) do
        online = Common.rpcCall( gameNodeName, "OnlineMgr", "getOnline", _data.gameId )
        table.insert( data, {
            gameNode = gameNodeName, online = online, gameId = _data.gameId
        })
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS, data = data } )
end

---@see 发送邮件
function WebCmd.sendEmail( _, _data )
    _data = cjson.decode(_data)
    local allGameServer
    if not _data.gameNode then
        -- 发全服
        allGameServer = Common.getClusterNodeByName( "game", true )
    else
        -- 发指定服务器
        allGameServer = _data.gameNode
    end

    for _, gameNode in pairs(allGameServer) do
        if _data.rids then
            Common.rpcMultiSend( gameNode, "SystemEmailMgr", "addSystemMailToRole", _data.rids[1], _data.rids, _data.title, _data.subTitle, _data.content, _data.items )
        else
            Common.rpcMultiSend( gameNode, "SystemEmailMgr", "addSystemMail", 0, _data.title, _data.subTitle, _data.content, _data.items )
        end
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS } )
end

---@see 发送公告
function WebCmd.sendAnnouncement( _, _data )
    _data = cjson.decode(_data)
    if _data.channel == Enum.ChatChannel.SYSTEM then
        -- 跑马灯,发往游戏服务器
        local allGameNodes = _data.gameNode
        if not allGameNodes then
            -- 全部游戏服务器发送
            allGameNodes = Common.getClusterNodeByName( "game", true )
        end
        for _, gameNode in pairs(allGameNodes) do
            Common.rpcSend( gameNode, "MarqueeMgr", "notifyMarquee", _data.content, _data.gameId, _data.beginTime, _data.endTime, _data.sendInterval )
        end
    elseif _data.channel == Enum.ChatChannel.WORLD then
        -- 世界频道,发往聊天服务器
        local allChatNodes = Common.getClusterNodeByName( "chat", true )
        for _, chatNode in pairs(allChatNodes) do
            Common.rpcSend( chatNode, "ChatMgr", "sendAnnouncement", _data.gameNode, _data.channel, _data.gameId, _data.guildId, _data.content )
        end
    else
        return cjson.encode( { code = Enum.WebError.CHAT_INVALIDE_CHANNEL } )
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS } )
end

---@see 充值
function WebCmd.recharge( _, _data )
    local checkRet, retData = WebCmd.checkProxy( _data, "recharge" )
    if checkRet then return retData end

    if Common.getSelfNodeName():find("game") == nil then
        return cjson.encode( { code = Enum.WebError.RECHARGE_NOT_GAME } )
    end

    _data = cjson.decode(_data)
    if not _data then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end
    return SM.RechargeMgr.req.recharge(_data)
end


---@see 关闭服务器
function WebCmd.closeServer( _, _data )
    -- 仅monitorServer可以分发
    if Common.getSelfNodeName():find("monitor") then
        local checkRet, retData = WebCmd.checkProxy( _data, "closeServer", true )
        if checkRet then return retData end
    end

    if Common.getSelfNodeName():find("game") ~= nil then
		SM.System.post.Maintain()
	elseif Common.getSelfNodeName():find("monitor") == nil then
		SM.MonitorSubscribe.req.restartCluster()
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS } )
end

---@see 执行热更
function WebCmd.hotfixServer( _, _data )
    -- 仅monitorServer可以分发
    if Common.getSelfNodeName():find("monitor") then
        local clusterInfo = SM.Rpc.req.getClusterCfg()
        local data = ""
        local ret, isTimeout
        if clusterInfo then
            for nodeName, _ in pairs(clusterInfo) do
                isTimeout, ret = Common.timeoutRun( 3, Common.rpcCall, nodeName, "WebProxy", "Do", "hotfix" )
                if not isTimeout then
                    if ret and ret ~= "" then
                        data = data .. string.format("[%s] hotfixRet:%s<br>", nodeName, tostring(ret))
                    end
                else
                    data = data .. string.format("[%s] hotfixRet:timeout 3s<br>", nodeName)
                end
            end
        end

        if not _data or _data == "" then
            return "jsonpCallback(" .. cjson.encode( { result = data } )  .. ")"
        else
            return cjson.encode( { code = Enum.WebError.SUCCESS, data = data } )
        end
    else
        if not _data or _data == "" then
            return "jsonpCallback(" .. cjson.encode( { result = "hotfix not at monitor server" } )  .. ")"
        else
            return cjson.encode( { code = Enum.WebError.FAILED } )
        end
    end
end

---@see 让指定的IGGID的AccessToken失效
function WebCmd.invalidAccessToken( _, _data )
    if Common.getSelfNodeName():find("monitor") then
        -- 从monitor分发,通知所有登陆服务器
        _data = cjson.decode(_data)
        local iggid = _data.iggid
        local allLoginNodes = Common.getClusterNodeByName( "login", true )
        for index, loginNode in pairs(allLoginNodes) do
            Common.rpcSend( loginNode, "AccountMgr", "invalidAccessToken", index, iggid, index == 1 )
        end

        return cjson.encode( { code = Enum.WebError.SUCCESS } )
    end
end

---@see 获取指定服务器的角色数量
function WebCmd.getServerRoleCount( _, _data )
    _data = cjson.decode(_data)
    local gameNodes = _data.gameNode
    if not gameNodes then
        gameNodes = Common.getClusterNodeByName("game", true)
    end

    -- 向游服查询
    local gameRoleCount = {}
    for _, gameNode in pairs(gameNodes) do
        gameRoleCount[gameNode] = Common.rpcCall( gameNode, "AccountMgr", "getGameRoleCount", gameNode )
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS, gameRoleCount = gameRoleCount } )
end

---@see 增加钻石
function WebCmd.addDenar( _, _data )
    local checkRet, retData = WebCmd.checkProxy( _data, "addDenar" )
    if checkRet then return retData end

    if Common.getSelfNodeName():find("game") == nil then
        return cjson.encode( { code = Enum.WebError.RECHARGE_NOT_GAME } )
    end

    _data = cjson.decode(_data)
    if not _data then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end
    local rids = _data.rids
    local addDenar = _data.denar
    if not rids or not addDenar or addDenar <= 0 then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end

    -- 游服增加钻石
    local RoleLogic = require "RoleLogic"
    for _, rid in pairs(rids) do
        RoleLogic:addDenar( rid, addDenar, nil, Enum.LogType.ADD_DENAR_FROM_WEB )
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS } )
end

---@see 扣除钻石
function WebCmd.subDenar( _, _data )
    local checkRet, retData = WebCmd.checkProxy( _data, "subDenar" )
    if checkRet then return retData end

    if Common.getSelfNodeName():find("game") == nil then
        return cjson.encode( { code = Enum.WebError.RECHARGE_NOT_GAME } )
    end

    _data = cjson.decode(_data)
    if not _data then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end
    local rids = _data.rids
    local subDenar = _data.denar
    if not rids or not subDenar or subDenar <= 0 then
        return cjson.encode( { code = Enum.WebError.ARG_NOT_FOUND } )
    end

    -- 游服增加钻石
    local RoleLogic = require "RoleLogic"
    for _, rid in pairs(rids) do
        RoleLogic:addDenar( rid, -subDenar, nil, Enum.LogType.SUB_DENAR_FROM_WEB )
    end

    return cjson.encode( { code = Enum.WebError.SUCCESS } )
end

---@see 更新推荐服务器配置
function WebCmd.updateRecommendConfig( _, _data )
    if Common.getSelfNodeName():find("login") == nil then
        -- 更新给所有的登陆服务器
        local accountNodes = Common.getClusterNodeByName( "login", true )
        for _, accountNode in pairs(accountNodes) do
            Common.rpcCall( accountNode, "WebProxy", "Do", "updateRecommendConfig", _data )
        end

        return cjson.encode( { code = Enum.WebError.SUCCESS } )
    else
        _data = cjson.decode(_data)
        -- 更新推荐服务器配置
        MSM.AccountRefer[0].req.updateRecommendConfig( _data.config )
    end
end

---@see 获取推荐服务器配置
function WebCmd.getRecommendConfig( _, _data )
    if Common.getSelfNodeName():find("login") == nil then
        -- 通过第一个登陆服务器获取配置
        local accountNodes = Common.getClusterNodeByName( "login", true )
        local ret = Common.rpcCall( accountNodes[1], "WebProxy", "Do", "getRecommendConfig", _data )
        if ret then
            return cjson.encode( { code = Enum.WebError.SUCCESS, data = { serverNode = ret.serverNode, recommendArea = ret.recommendArea } } )
        else
            return cjson.encode( { code = Enum.WebError.SERVER_NODE_NOT_FOUND } )
        end
    else
        _data = cjson.decode(_data)
        -- 获取推荐服务器配置
        return MSM.AccountRefer[0].req.getRecommendConfig( _data.serverNode )
    end
end

---@see 踢人
function WebCmd.kickRole( _, _data )
    if Common.getSelfNodeName():find("monitor") then
        -- 从monitor分发,通知所有登陆服务器
        _data = cjson.decode(_data)
        local iggid = _data.iggid
        local allLoginNodes = Common.getClusterNodeByName( "login", true )
        if allLoginNodes and not table.empty( allLoginNodes ) then
            local ret = Common.rpcCall( allLoginNodes[1], "AccountMgr", "kickRoleFromWeb", iggid )
            if not ret then
                return cjson.encode( { code = Enum.WebError.KICK_ERROR } )
            end
        end

        return cjson.encode( { code = Enum.WebError.SUCCESS } )
    end
end