--[[
* @file : AuthToken.lua
* @type : service
* @author : linfeng
* @created : Wed Nov 22 2017 14:26:00 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 验证 token 有效性的服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local httpc = require "http.httpc"
local cjson = require "cjson.safe"
local Url = "http://push.igg.com/api/get_user.php"

function init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

---@see 发起验证
local function AuthImpl( _token, _gameId )
    local req = string.format("%s?g_id=%d&iggid=%d",Url, _gameId, _token)
    local resp = httpc.get(req)
    resp = cjson.decode(resp)
    return resp.success == 1 and resp.g_id == _gameId and resp.iggid == _token
end

---@see 向web验证token的有效性
-- params@token : iggid
-- parms@deviceType : 设备类型(IOS,ANDROID,PC)
-- params@language : 语言版本(EN,CN,ARB)
function response.WebAuth( _token, _deviceType )
    if _deviceType == Enum.DeviceType.PC then
        return true -- PC端不需要验证 亲测 源 码网www.q cym w.c  om
    else
        return AuthImpl( _token, Enum.GameID[_deviceType])
    end
end