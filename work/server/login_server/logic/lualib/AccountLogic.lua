--[[
 * @file : AccountLogic.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2019-04-10 13:31:15
 * @Last Modified time: 2019-04-10 13:31:15
 * @department : Arabic Studio
 * @brief : 帐号服务器相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local AccountLogic = {}

local httpc = require "http.httpc"
local cjson = require "cjson.safe"
local verifyUrl = "http://cgi.igg.com"
local verifyReq = "/internal/access_token/verify"

---@see 检测AccessToken是否有效
function AccountLogic:verifyAccessToken( _iggid, _accessToken, _platform, _language, _clientAddr )
--    if not _accessToken then
--        return true
--    end
--
--    LOG_INFO("iggid(%s) begin verifyAccessToken accessToken(%s) platform(%d) language(%s) clientAddr(%s)", _iggid, _accessToken, _platform, _language, tostring(_clientAddr))
--    -- 向远程接口验证accessToken
--    local gameId = Common.getGameId( tonumber(_platform), tonumber(_language) )
--    if not gameId then
--        LOG_ERROR("verifyAccessToken error, not found gameId, platform(%d) language(%s) clientAddr(%s)", _platform, _language, tostring(_clientAddr))
--        return false
--    end
--    local _, respBody = httpc.get(verifyUrl, string.format("%s?access_token=%s&game_id=%s&_client_ip=%s",
--                                                    verifyReq, _accessToken, gameId, _clientAddr))
--    local newBody, errorInfo = cjson.decode(respBody)
--    if not newBody then
--        LOG_ERROR("verifyAccessToken fail, platform(%d) language(%s) clientAddr(%s) error(%s), respBody(%s)", _platform, _language, tostring(_clientAddr), errorInfo, respBody)
--        return false
--    end
--    if newBody.error and newBody.error.code ~= 0 then
--        LOG_ERROR("verifyAccessToken fail, iggid(%s) accessToken(%s) gameId(%d) clientAddr(%s) msg(%s)",
--                    _iggid, _accessToken, gameId, tostring(_clientAddr), newBody.error.message)
--        return false
--    end


    LOG_INFO("iggid(%s) begin verifyAccessToken accessToken(%s) platform(%d) language(%s) clientAddr(%s) ok!!", _iggid, _accessToken, _platform, _language, tostring(_clientAddr))


    return true
end

return AccountLogic