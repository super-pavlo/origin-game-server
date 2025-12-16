--[[
* @file : EmailProxy.lua
* @type : snax multi service
* @author : dingyuchao 九  零 一  起 玩 w w w . 9 0  1 7 5 . co m
* @created : Sun Jun 21 2020 06:24:19 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 跨服发送邮件代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local EmailLogic = require "EmailLogic"
local RoleLogic = require "RoleLogic"

function init( index )
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

---@see 跨服发送邮件
function accept.sendEmail( _toRids, _emailId, _otherInfo, _noSync )
    local gameNode

    if not Common.isTable( _toRids ) then
        _toRids = { _toRids }
    end

    for _, rid in pairs( _toRids ) do
        gameNode = RoleLogic:getRoleGameNode( rid )
        if gameNode then
            Common.rpcMultiSend( gameNode, "EmailProxy", "sendRoleEmail", rid, _emailId, _otherInfo, _noSync )
        end
    end
end

---@see 发送邮件到角色
function accept.sendRoleEmail( _rid, _emailId, _otherInfo, _noSync )
    EmailLogic:sendEmail( _rid, _emailId, _otherInfo, _noSync )
end

---@see 初始化
function response.Init()

end