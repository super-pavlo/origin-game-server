--[[
* @file : RoleQueueMgr.lua
* @type : multi snax service
* @author : chenlei
* @created : Fri Apr 17 2020 10:52:37 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色队列服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local TechnologyLogic = require "TechnologyLogic"
local BuildingLogic = require "BuildingLogic"
local HospitalLogic = require "HospitalLogic"
local RoleLogic = require "RoleLogic"

local roleLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkRoleLock( _rid )
    if not roleLock[_rid] then
        roleLock[_rid] = { lock = queue() }
    end
end


---@see 建筑加速
function response.buildSpeedUp( _rid, _queueIndex, _sec, _isGuildHelp )
    -- 检查互斥锁
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            return BuildingLogic:speedUp( _rid, _queueIndex, _sec, _isGuildHelp )
        end
    )
end

---@see 科研加速
function response.technologySpeedUp( _rid, _sec, _isGuildHelp )
    -- 检查互斥锁
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            return TechnologyLogic:speedUp( _rid, _sec, _isGuildHelp )
        end
    )
end

---@see 治疗加速
function response.hospitalSpeedUp( _rid, _sec, _isGuildHelp )
    -- 检查互斥锁
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            return HospitalLogic:speedUp( _rid, _sec, _isGuildHelp )
        end
    )
end

---@see 立即完成
function response.immediatelyComplete( _args )
    -- 检查互斥锁
    checkRoleLock( _args.rid )

    return roleLock[_args.rid].lock(
        function ()
            return RoleLogic:immediatelyComplete( _args )
        end
    )
end