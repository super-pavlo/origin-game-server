--[[
* @file : Logind.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 11:51:54 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : login_server 的网关管理
* Copyright(C) 2017 IGG, All rights reserved
]]

local login = require "LoginGate"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
local cluster = require "skynet.cluster"

local server = {
    host = "0.0.0.0",
    port = tonumber(skynet.getenv("port")) or 8001,
    multilogin = true, -- multilogin
    name = "Logind",
    instance = 20
}

---@see 验证token
local function authToken(token)
    -- iggid:accessToken:platform:language:clientaddr:selectGameNode
    local tokenInfo = string.split(token, ":")
    local iggid = tokenInfo[1]
    local accessToken = tokenInfo[2]
    local platform = tokenInfo[3]
    local language = tokenInfo[4]
    local clientaddr = tokenInfo[5]
    local selectGameNode = tokenInfo[6]

    local gameNode, uid, isBan, isInvalidToken = SM.AccountMgr.req.AuthIGGID( iggid, accessToken, platform, language, clientaddr, selectGameNode )
--    if not gameNode then
--        LOG_ERROR( "account(%s) GetAccountUid _accessToken invalid, ", iggid )
--        return nil, nil, nil, isBan, isInvalidToken
--    end

    return iggid, gameNode, uid, isBan, isInvalidToken
end

function server.auth_handler(token)
    -- check account
    local iggid, gameNode, uid, isBan, isInvalidToken = authToken(token)
--    if not gameNode then
--        LOG_SKYNET("invalid client token:%s", token)
--        return nil, nil, nil, isBan, isInvalidToken
--    end

    return iggid, gameNode, uid
end

function server.login_handler( iggid, gameNode, secret, uid )
    LOG_INFO(string.format("iggid(%s) gameNode(%s) is login, secret is %s", iggid, gameNode, crypt.hexencode(secret)))

    -- check service exist
    local ret, address = pcall(cluster.query, gameNode, "OnlineMgr")
    assert(ret and address, "target gameNode not exist or boot:" .. gameNode)
    local ok, subid, connectIp, connectPort, connectRealIp = pcall(cluster.call, gameNode, "Gamed", "login", uid, secret, iggid)
    if ok then
        return string.format(
            "%s@%s@%s@%s@%s@%s@%s",
            crypt.base64encode(iggid),
            crypt.base64encode(tostring(subid)),
            crypt.base64encode(connectIp),
            crypt.base64encode(tostring(connectPort)),
            crypt.base64encode(tostring(connectRealIp)),
            crypt.base64encode(tostring(gameNode)),
            crypt.base64encode(tostring(uid))
        )
    else
        LOG_ERROR("notify %s iggid %s login error->%s", gameNode, iggid, subid)
        error("notify game server error")
    end
end

local CMD = {}

function server.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

login(server)
