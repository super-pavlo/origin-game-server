--[[
* @file : MessagePush.lua
* @type : service
* @author : linfeng 九  零  一 起 玩 w w w . 9 0  1 7 5 . co m
* @created : Wed Nov 22 2017 14:33:07 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 消息推送服务(APNS,GMS)
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local httpc = require "http.httpc"
local cjson = require "cjson.safe"
local cluster = require "skynet.cluster"
local Url = "push.igg.com"
local Method = "/api/send_msg.php"
local hmacmd5 = require "hmacmd5.core"
local key = "EkALpd1s008YyHwp3W"

function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
    cjson.encode_sparse_array(true)
end

---@see urlEncode
local function urlEncode(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

---@see 根据ascii排序生成需要加密的字符串
local function formatSign( _g_id, _m_time_to_send, _m_display, _m_push_type, _m_by_timezone, _m_msg,
                    _mt_id, _m_iggid_file, _m_data, _m_expire_time, _m_voice, _m_title, _m_regid_file,
                    _m_mass_id, _m_ios_badge, _m_category, _timestamp)
    local str = ""
    if _timestamp then
        str = string.format( "%s%d", str, _timestamp )
    end
    if _g_id then
        str = string.format( "%s%d", str, _g_id )
    end
    if _m_by_timezone then
        str = string.format( "%s%d", str, _m_by_timezone )
    end
    if _m_category then
        str = string.format( "%s%d", str, _m_category )
    end
    if _m_data then
        str = string.format( "%s%s", str, _m_data )
    end
    if _m_display then
        str = string.format( "%s%d", str, _m_display )
    end
    if _m_expire_time then
        str = string.format( "%s%d", str, _m_expire_time )
    end
    if _m_iggid_file then
        str = string.format( "%s%s", str, _m_iggid_file )
    end
    if _m_ios_badge then
        str = string.format( "%s%d", str, _m_ios_badge )
    end
    if _m_mass_id then
        str = string.format( "%s%s", str, _m_mass_id )
    end
    if _m_msg then
        str = string.format( "%s%s", str, _m_msg )
    end
    if _m_push_type then
        str = string.format( "%s%d", str, _m_push_type )
    end
    if _m_regid_file then
        str = string.format( "%s%s", str, _m_regid_file )
    end
    if _m_time_to_send then
        str = string.format( "%s%d", str, _m_time_to_send )
    end
    if _m_title then
        str = string.format( "%s%s", str, _m_title )
    end
    if _m_voice then
        str = string.format( "%s%s", str, _m_voice )
    end
    if _mt_id then
        str = string.format( "%s%d", str, _mt_id )
    end
    return str
end

-- local function GetKey( _gameId )
--     if _gameId == Enum.GameID.ANDROID_EN then
--         return Enum.GameKey.ANDROID_EN_KEY
--     elseif _gameId == Enum.GameID.ANDROID_ARB then
--         return Enum.GameKey.ANDROID_ARB_KEY
--     elseif _gameId == Enum.GameID.ANDROID_CN then
--         return Enum.GameKey.ANDROID_CN_KEY
--     elseif _gameId == Enum.GameID.IOS_EN then
--         return Enum.GameKey.IOS_EN_KEY
--     elseif _gameId == Enum.GameID.IOS_ARB then
--         return Enum.GameKey.IOS_ARB_KEY
--     elseif _gameId == Enum.GameID.IOS_CN then
--         return Enum.GameKey.IOS_CN_KEY
--     end
-- end

function accept.pushImpl( _token, _gameId, _msg )
    local time = os.time()
    local oldSignature = formatSign( _gameId, time, 0, 2, 0, _msg,
                    0, _token, nil, nil, nil, nil, nil,
                    nil, nil, nil, time)
    local newSignature = hmacmd5.hmac_md5(key, oldSignature)
    local req = string.format("%s?g_id=%d&m_time_to_send=%d&m_display=0&m_push_type=2&m_by_timezone=0&m_msg=%s&mt_id=0&m_iggid_file=%s&_signature=%s&_timestamp=%d",
                            Method, _gameId, time, urlEncode(_msg), _token, newSignature, time);
    local _, respBody = httpc.get(Url, req)
    respBody = string.reverse(respBody)
    local pos = string.find(respBody, "}")
    respBody = string.sub(respBody, pos)
    respBody = string.reverse(respBody)
    local newBody, _ = cjson.decode(respBody)
    if not newBody or newBody.errCode ~= 0 then
        LOG_ERROR("PushImpl fail, token(%s) gameId(%d), msg(%s), respBody(%s)", tostring(_token), _gameId, _msg, respBody)
    end
end

---@see 向客户端推送通知消息
---@param _token string iggid
---@param _deviceType integer 设备类型
---@param _msg string 消息内容
function accept.pushMessage( _pushList)
    for _, pushInfo in pairs( _pushList) do
        snax.self().post.pushImpl( pushInfo.account, pushInfo.gameId, pushInfo.msg )
    end
end
