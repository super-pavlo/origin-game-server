--[[
 * @file : AccountMgr.lua
 * @type : single snax service
 * @author : linfeng
 * @created : 2020-08-12 14:40:06
 * @Last Modified time: 2020-08-12 14:40:06
 * @department : Arabic Studio
 * @brief : 账号注册管理
 * Copyright(C) 2019 IGG, All rights reserved
]]


local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

local gameNodeOpenTimes = {}

function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)

    if not Common.getSelfNodeName():find("game") then
        local allgameNodes = Common.getClusterNodeByName("game", true)
        if allgameNodes then
            for _, gameNode in pairs(allgameNodes) do
                Common.rpcSend( gameNode, "AccountMgr", "notifyRegOpenTimeToLoginServer" )
            end
        end
    end
end

---@see 验证账号
function response.AuthIGGID( _iggid, _accessToken, _platform, _language, _clientaddr, _selectGameNode )
    if ( not _accessToken or _accessToken == "" ) and not Enum.DebugMode then
        -- 非debug禁止无token登陆
        LOG_ERROR("AuthIGGID fail, iggid(%s) not accessToken", _iggid)
        return nil, nil, nil, true
    end
    local accountInfo = SM.c_account.req.Get(_iggid)
    local gameNode, uid
    if not accountInfo then
        if not _selectGameNode or _selectGameNode:len() <= 0 then
            -- 寻找推荐服务器
            if _clientaddr and _clientaddr ~= "" and _clientaddr ~= "127.0.0.1" then
                local iggidIndex = tonumber( _iggid ) or 0
                local clientArea = MSM.AccountRefer[iggidIndex].req.getClientArea( _iggid, _clientaddr )
                gameNode = MSM.AccountRefer[iggidIndex].req.getReferGameNode( clientArea )
            end

            if not gameNode then
                -- 默认最新开服的服务器
                if table.size(gameNodeOpenTimes) > 0 then
                    while table.size(gameNodeOpenTimes) > 0 do
                        gameNode = table.first(gameNodeOpenTimes).value.gameNode
                        -- 判断服务器是否还在线
                        if Common.getClusterNodeByName( gameNode ) then
                            break
                        else
                            table.remove( gameNodeOpenTimes, 1 )
                        end
                    end
                else
                    gameNode = "game1"
                end
            end
        else
            gameNode = _selectGameNode
            -- 判断gameNode是否存在
            if not Common.getClusterNodeByName( gameNode ) then
                return
            end
        end

        uid = MSM.PkIdMgr[0].req.newPkId()
        -- 自动注册
        accountInfo = { iggid = _iggid, accessToken = _accessToken, gameNode = gameNode, uid = uid }
        SM.c_account.req.Add( _iggid, accountInfo )
    else
        if accountInfo.ban then
            -- 已经被封号
            return nil, nil, true
        end

        if _selectGameNode and _selectGameNode ~= "" then
            -- 玩家自行选择服务器
            gameNode = _selectGameNode
        else
            gameNode = accountInfo.gameNode
        end
        uid = accountInfo.uid
    end

    -- 验证 accessToken
    if _clientaddr and _clientaddr ~= "" and _clientaddr ~= "127.0.0.1" then
        -- 30天内只验证一次
        if not accountInfo.accessTokenTime or accountInfo.accessTokenTime < os.time() or _accessToken ~= accountInfo.accessToken then
            local AccountLogic = require "AccountLogic"
            if not AccountLogic:verifyAccessToken( _iggid, _accessToken, _platform, _language, _clientaddr ) then
                LOG_ERROR( "account(%s) GetAccountUid accessToken invalid, ", _iggid )
                return nil, nil, nil, true
            else
                -- 更新 accessToken 验证时间
                SM.c_account.req.Set( _iggid, { accessTokenTime = os.time() + 3600 * 24 * 30 } )
            end
        end
    end

    return gameNode, uid
end

---@see 注册在线的游服.根据时间排序
function accept.regGameServerOpenTime( _gameNode, _openTime )
    table.insert( gameNodeOpenTimes, { gameNode = _gameNode, openTime = _openTime } )
    table.sort( gameNodeOpenTimes, function ( a, b )
        return a.openTime > b.openTime
    end)
end

---@see 反注册在线游服
function accept.unregGameServerOpenTime( _gameNode )
    for index, nodeInfo in pairs( gameNodeOpenTimes ) do
        if nodeInfo.gameNode == _gameNode then
            table.remove( gameNodeOpenTimes, index )
            break
        end
    end
end

---@see 通知游服向登陆服务器注册开服时间
function accept.notifyRegOpenTimeToLoginServer()
    local allLoginNodes = Common.getClusterNodeByName("login", true)
    local selfNode = Common.getSelfNodeName()
    local openTime = Common.getSelfNodeOpenTime()
    for _, loginNode in pairs(allLoginNodes) do
        Common.rpcSend( loginNode, "AccountMgr", "regGameServerOpenTime", selfNode, openTime )
    end
end

---@see 获取游服角色数量
function response.getGameRoleCount( _gameNode )
    local gameRoleCountKey = "gameRoleCount_" .. _gameNode
    local cout = Common.redisExecute( { "get", gameRoleCountKey } )
    return tonumber(cout) or 0
end

---@see 通知token失效
function accept.invalidAccessToken( _, _iggid, _iskick )
    local accountInfo = SM.c_account.req.Get( _iggid )
    if accountInfo then
        accountInfo.accessToken = nil
        accountInfo.accessTokenTime = nil
        SM.c_account.req.Set( _iggid, accountInfo )
        if _iskick then
            local roleInfos = MSM.d_user[accountInfo.uid].req.Get( accountInfo.uid, "roleInfos" )
            -- 通知帐号下所有的角色离线
            for _, roleInfo in pairs(roleInfos) do
                Common.rpcMultiSend( roleInfo.gameNode, "RoleQuery", "invalidTokenKickRole", roleInfo.rid )
            end
        end
    end
end

---@see 踢人
function response.kickRoleFromWeb( _iggid )
    local accountInfo = SM.c_account.req.Get( _iggid )
    if accountInfo then
        local roleInfos = MSM.d_user[accountInfo.uid].req.Get( accountInfo.uid, "roleInfos" )
        -- 通知帐号下所有的角色离线
        for _, roleInfo in pairs(roleInfos) do
            Common.rpcMultiSend( roleInfo.gameNode, "RoleQuery", "kickRoleFromWeb", roleInfo.rid )
        end
        return true
    end
end

---@see 判断指定服务器是否有指定角色
function response.checkGameNodeHadRole( _iggid, _gameNode, _rid )
    local accountInfo = SM.c_account.req.Get( _iggid )
    if accountInfo then
        local roleInfos = MSM.d_user[accountInfo.uid].req.Get( accountInfo.uid, "roleInfos" )
        for _, roleInfo in pairs(roleInfos) do
            if _gameNode == roleInfo.gameNode and roleInfo.rid == _rid then
                return true
            end
        end
    end

    return false
end

---@see 设置最后登录的服务器以及角色
function response.setLastGameNode( _iggid, _gameNode, _rid )
    local accountInfo = SM.c_account.req.Get( _iggid )
    if accountInfo then
        accountInfo.gameNode = _gameNode
        SM.c_account.req.Set( _iggid, { gameNode = _gameNode } )
        if _rid then
            -- 通知游服,修改角色最后登录时间
            if not Common.rpcMultiCall( _gameNode, "RoleQuery", "setRoleLastLoginTime", _rid ) then
                return false
            end
        end
        return true
    end

    return false
end