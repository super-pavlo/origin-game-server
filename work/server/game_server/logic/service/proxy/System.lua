--[[
* @file : System.lua
* @type : snax multi service
* @author : linfeng
* @created : Mon Jul 02 2018 10:29:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 系统心跳管理
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local Timer = require "Timer"
local RoleSync = require "RoleSync"

local roleHeart = {}
local roleHeartTimerId = {}
local interval = 30 -- 超时时间,秒

---@see 判断心跳是否超时
local function checkHeartOverTime( _rid, _agentHandle, _agentName, _userName )
    if not roleHeart[_rid] or roleHeart[_rid] + interval < os.time() then
        -- 没收到心跳,或者心跳超时
        -- 踢出角色
        local agent = snax.bind(_agentHandle, _agentName)
        if agent then
            RoleSync:syncKick( _rid, Enum.SystemKick.HEART_TIMEOUT )
            agent.req.kickAgent( _userName )
            LOG_INFO("rid(%d) username(%s) checkHeartOverTime, kickAgent", _rid, _userName)
        end

        -- 删除定时器
        Timer.delete( roleHeartTimerId[_rid] )
    end
end

---@see 移除心跳检测
function response.removeHeartCheckTimer( _rid )
    if roleHeartTimerId[_rid] then
        Timer.delete( roleHeartTimerId[_rid] )
    end
end

---@see 添加心跳检测
function response.addHeartCheckTimer( _rid, _agentHandle, _agentName, _username )
    if roleHeartTimerId[_rid] then
        Timer.delete( roleHeartTimerId[_rid] )
    end

    -- 启动定时器
    roleHeartTimerId[_rid] = Timer.runEvery( interval * 100, checkHeartOverTime,
                                                _rid, _agentHandle, _agentName, _username )
end

---@see 启动维护通知
---@param _type integer 维护类型
function accept.Maintain()
    -- 立即维护(立即关闭服务器)
    SM.MonitorSubscribe.req.restartCluster()
end