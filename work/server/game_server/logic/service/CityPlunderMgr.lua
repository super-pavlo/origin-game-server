--[[
* @file : CityPlunderMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Tue Jun 23 2020 18:46:02 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 城市掠夺服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local BattleCallback = require "BattleCallback"
local cityPlunderLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkCityPlunderLockLock( _rid )
    if not cityPlunderLock[_rid] then
        cityPlunderLock[_rid] = { lock = queue() }
    end
end

---@see 掠夺资源处理
---@param _exitArg defaultExitBattleArgClass
function response.dispatchCityPlunder( _exitArg )
    -- 检查互斥锁
    checkCityPlunderLockLock( _exitArg.plunderRid )

    return cityPlunderLock[_exitArg.plunderRid].lock(
        function ()
            return BattleCallback:dispatchCityPlunder( _exitArg )
        end
    )
end