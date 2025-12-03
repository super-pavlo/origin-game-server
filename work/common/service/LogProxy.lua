--[[
 * @file : LuaProxy.lua
 * @type : single snax service
 * @author : linfeng
 * @created : 2019-04-01 08:38:59
 * @Last Modified time: 2019-04-01 08:38:59
 * @department : Arabic Studio
 * @brief : 日志代理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

---@see 初始化日志表
function init(index)
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

function response.Init()

end

---@see 记录角色登陆日志
function accept.roleLogin( _rid, _values )
    MSM.LogImpl[_rid].post.roleLogin( _rid, _values )
end

---@see 记录角色登出日志
function accept.roleLogout(  _rid, _values )
    MSM.LogImpl[_rid].post.roleLogout( _rid, _values )
end