--[[
 * @file : PushMsgProxy.lua
 * @type : single snax service
 * @author : linfeng
 * @created : 2019-05-27 16:00:46
 * @Last Modified time: 2019-05-27 16:00:46
 * @department : Arabic Studio
 * @brief : 推送消息服务代理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

---@see 初始化
function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

---@see 非阻塞推送
function accept.syncMsg( _toRid, _protoName, _protoData, _notLog, _cache )
    Common.syncMsg( _toRid, _protoName, _protoData, nil, nil, _notLog, nil, nil, _cache )
end

---@see 阻塞推送
function response.syncMsg( _toRid, _protoName, _protoData, _sendNow, _notLog, _cache )
    Common.syncMsg( _toRid, _protoName, _protoData, true, _sendNow, _notLog, nil, nil, _cache )
end