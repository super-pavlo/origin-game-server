--[[
 * @file : AlarmMgr.lua
 * @type : single snax service
 * @author : linfeng
 * @created : 2020-09-27 11:09:44
 * @Last Modified time: 2020-09-27 11:09:44
 * @department : Arabic Studio
 * @brief : 报警信息管理
 * Copyright(C) 2020 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local httpc = require "http.httpc"
local hmacmd5 = require "hmacmd5.core"
local cjson = require "cjson.safe"
local Url = "http://alarm.skyunion.net"
local Req = "/api/send_alarm.php"
local token = "1c21da908f23450199e967dcb612c8e7"
local key = "rt5{jnZ@1"

function init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

function response.Init()

end

---@see 资源超过阈值警告
function accept.alarmResource( _iggid, _rid, _gameId, _resourceId, _resourceNum )
    --[[
    local serverWarningPush = CFG.s_Config:Get("serverWarningPush") or {}
    -- 警告内容
    local content = string.format("iggid(%s) rid(%d) gameId(%d) resourceId(%d) resourceNum(%d) 超过阈值警告, 请联系 @%s 电话:%s",
                                _iggid, _rid, _gameId, _resourceId, _resourceNum, serverWarningPush[1] or "", serverWarningPush[2] or "")
    -- 拼接token
    local querystring = string.format("content=%s&token=%s", content, token)
    -- 生成sign
    local sign = hmacmd5.md5(querystring..key)
    -- 发起post
    local _, respBody = httpc.post(Url, Req, {
        content = content,
        token = token,
        sign = sign
    })
    LOG_INFO("alarmResource:%s", tostring(cjson.decode(respBody)))
    ]]
end

---@see 开服失败警告
function accept.openGameFail( _gameNode, _err )
    --[[
    -- 警告内容
    local content = string.format("节点(%s) 启动异常:%s", _gameNode, _err)
    -- 拼接token
    local querystring = string.format("content=%s&token=%s", content, token)
    -- 生成sign
    local sign = hmacmd5.md5(querystring..key)
    -- 发起post
    httpc.post(Url, Req, {
        content = content,
        token = token,
        sign = sign
    })
    ]]
end

---@see 开服成功提醒
function accept.openGameSuccess( _nodeName )
    --[[
    -- 警告内容
    local content = string.format("节点(%s) 启动成功!", _nodeName)
    -- 拼接token
    local querystring = string.format("content=%s&token=%s", content, token)
    -- 生成sign
    local sign = hmacmd5.md5(querystring..key)
    -- 发起post
    httpc.post(Url, Req, {
        content = content,
        token = token,
        sign = sign
    })
    ]]
end

---@see 关服成功提醒
function accept.closeNodeSuccess( _nodeName)
    --[[
    -- 警告内容
    local content = string.format("节点(%s) 关闭成功!", _nodeName)
    -- 拼接token
    local querystring = string.format("content=%s&token=%s", content, token)
    -- 生成sign
    local sign = hmacmd5.md5(querystring..key)
    -- 发起post
    httpc.post(Url, Req, {
        content = content,
        token = token,
        sign = sign
    })
    ]]
end