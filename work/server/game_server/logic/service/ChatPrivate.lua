--[[
 * @file : ChatPrivate.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-04-10 15:21:12
 * @Last Modified time: 2020-04-10 15:21:12
 * @department : Arabic Studio
 * @brief : 私聊信息处理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local RoleLogic = require "RoleLogic"
local RoleChatLogic = require "RoleChatLogic"

function init( index )
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

function response.Init()
    -- body
end

---@see 处理私聊信息
function response.dispatchPrivateMsg( _toRid, _fromRid, _msgInfo )
    if not RoleLogic:getRole(_toRid, Enum.Role.level) then
        return
    end
    -- 推送私聊消息
    Common.syncMsg( _toRid, "Chat_PushMsg", { pushMsgInfos = { _msgInfo } } )
    -- 记录聊天消息
    RoleChatLogic:addChatRecord( _toRid, _fromRid, { timeStamp = _msgInfo.timeStamp, msg = _msgInfo.msg, toRid = _toRid } )

    return true
end