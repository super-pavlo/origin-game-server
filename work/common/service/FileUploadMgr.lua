--[[
* @file : FileUploadMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Wed Sep 11 2019 09:00:05 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 文件上传服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local httpc = require "http.httpc"
local md5 =	require	"md5"
local timerCore = require "timer.core"
local cjson = require "cjson.safe"
local curl = require "curl.core"
local sprotoloader = require "sprotoloader"
local MergeProtocol = require "MergeProtocol"

local sp

function init(index)
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)

    MergeProtocol:regCSSproto()
    sp = sprotoloader.load( Enum.SPROTO_SLOT.RPC )
end

function response.Init()

end

---@see 删除文件
function accept.DeleteFile( _gameId, _url )
    local oldSignature = string.format( "%d%s%s", _gameId, _url, "Jxjd34#K" )
    local newSignature = md5.sumhexa(oldSignature)
    local form = {}
    form["v"] = 3
    form["g_id"] = _gameId
    form["sign"] = newSignature
    form["file"] = _url
    httpc.post("http://eu-storage.igg.com", "/protracted/delete.php", form )
end

---@see 上传文件到远程存储服务
function response.uploadFileToRemote( _rid, _gameId, _battleReportEx, _day )
    local data = sp:pencode( "BattleReportEx", _battleReportEx )
    LOG_INFO("uploadFileToRemote rid(%d) gameId(%s)", _rid, tostring(_gameId))
    local millisecond = math.modf(timerCore.getmillisecond())
    local prefix = "r"
    if Enum.DebugMode then
        prefix = "d"
    end
    local filename = prefix .. _rid .. millisecond .. ".gz"
    local sign = md5.sumhexa(string.format("%s%sJxjd34#K", _gameId, filename))
    local url = "http://eu-storage.igg.com/protracted/push.php" -- 永久
    if _day then
        url = "http://eu-storage.igg.com/push.php" -- 非永久
    end

    local ret, resp = curl.uploadfile(url, filename, data, tostring(_gameId), sign)
    if ret then
        LOG_INFO(tostring(resp))
        if resp:find("errcode") then
            resp = cjson.decode(resp)
            if resp then
                if resp.errcode ~= 0 then
                    LOG_ERROR("uploadFileToRemote fail:%s", resp.errmsg)
                else
                    return resp.data
                end
            end
        end
    end
end