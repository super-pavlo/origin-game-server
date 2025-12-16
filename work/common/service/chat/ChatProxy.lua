--[[
* @file : ChatProxy.lua
* @type : snax single service
* @author : linfeng
* @created : Mon May 14 2018 09:38:26 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local RoleChatLogic = require "RoleChatLogic"

function init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

---@see 注册到聊天服务节点中
function response.Init()
    local selfNodeName = Common.getSelfNodeName()
    local chatNode = Common.getChatNode()
    Common.rpcCall( chatNode, "ChatMgr", "initChannelWithNode", selfNodeName )
end

---@see 让某个玩家的信息注册到ChatServer中
function response.forceLoginChatServer( _rid, _subId )
    RoleChatLogic:notifyChatServerLogin( _rid, nil, _subId )
end