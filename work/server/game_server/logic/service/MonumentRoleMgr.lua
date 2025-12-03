--[[
* @file : MonumentRoleMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Mon May 04 2020 07:30:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : TODO
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local MonumentLogic = require "MonumentLogic"

local monumentLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkMonumentRoleLock( _rid )
    if not monumentLock[_rid] then
        monumentLock[_rid] = { lock = queue() }
    end
end

---@see 设置进度
function accept.setSchedule( _rid, _args )
    -- 检查互斥锁
    checkMonumentRoleLock( 0 )

    return monumentLock[0].lock(
        function ()
            MonumentLogic:setSchedule( _rid, _args )
        end
    )
end