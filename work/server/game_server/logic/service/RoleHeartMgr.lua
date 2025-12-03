--[[
 * @file : RoleHeartMgr.lua
 * @type : multi snax service
 * @author : linfeng
 * @created : 2020-01-21 14:36:48
 * @Last Modified time: 2020-01-21 14:36:48
 * @department : Arabic Studio
 * @brief : 角色心跳管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleSync = require "RoleSync"
local timeCore = require "timer.core"
local RoleLogic = require "RoleLogic"
local Timer = require "Timer"
local roleHeart = {}
local roleLastHeart = {}
local interval = 60
local heartInterval = 50

local function checkHeartTimeOut()
    for rid, time in pairs(roleHeart) do
        if time + interval < os.time() then
            -- 没收到心跳,或者心跳超时,踢出角色
            local userNames, agents = Common.getUserNameAndAgentByRid( rid )
            if not table.empty(agents) then
                RoleSync:syncKick( rid, Enum.SystemKick.HEART_TIMEOUT )
                agents[1].req.kickAgent( userNames[1] )
                LOG_INFO("rid(%d) username(%s) checkHeartOverTime, kickAgent", rid, userNames[1])
            end
            -- 删除定时器
            roleHeart[rid] = nil
            roleLastHeart[rid] = nil
        end
    end
end

---@see 初始化
function init()
    Timer.runEvery( 100, checkHeartTimeOut )
end

---@see 占位
function response.Init()
    -- body
end

---@see 添加角色心跳
function accept.addRoleHeart( _rid )
    roleHeart[_rid] = os.time()
    roleLastHeart[_rid] = timeCore.getmillisecond()
end

---@see 更新角色心跳
function accept.updateRoleHeart( _rid, _serverTime )
    roleHeart[_rid] = os.time()
    -- 计算CS延迟(毫秒)
    local now = timeCore.getmillisecond()
    if not roleLastHeart[_rid] then
        roleLastHeart[_rid] = timeCore.getmillisecond()
    end
    local ttl = now - roleLastHeart[_rid] - heartInterval * 1000
    if ttl < 0 then
        ttl = 0
    end

    roleLastHeart[_rid] = now
    -- 更新delay
    RoleLogic:setRole( _rid, Enum.Role.ttl, ttl)
end

---@see 移除角色心跳
function accept.removeRoleHeart( _rid )
    roleHeart[_rid] = nil
    roleLastHeart[_rid] = nil
end