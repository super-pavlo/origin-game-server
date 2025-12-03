--[[
 * @file : WebProxy.lua
 * @type : signle snax service
 * @author : linfeng
 * @created : 2019-05-22 11:09:19
 * @Last Modified time: 2019-05-22 11:09:19
 * @department : Arabic Studio
 * @brief : web代理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local WebCmd = require "WebCmd"

function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
    require "WebLogic"
end

---@see 转发执行相关脚本
function response.Do( _funcName, _data )
    if WebCmd[_funcName] then
        return WebCmd[_funcName]( nil, _data )
    end
end

---@see 转发执行相关web命令
function response.RunWebCmd( _cmd, _q, _body )
    local f = WebCmd[_cmd]
    if f then
        return pcall(f, _q, _body)
    end
end