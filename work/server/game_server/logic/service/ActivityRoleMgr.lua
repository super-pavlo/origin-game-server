--[[
* @file : ActivityRoleMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Fri Apr 17 2020 13:37:10 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色活动管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local ActivityLogic = require "ActivityLogic"

local activityLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkActivityRoleLock( _rid )
    if not activityLock[_rid] then
        activityLock[_rid] = { lock = queue() }
    end
end

---@see 设置进度
function response.setActivitySchedule( _rid, _actionType, _addNum, _condition, _condition2, _reset, _oldActionType, _isLogin, _time, _free, _discount )
    -- 检查互斥锁
    checkActivityRoleLock( _rid )

    return activityLock[_rid].lock(
        function ()
            ActivityLogic:setActivitySchedule( _rid, _actionType, _addNum, _condition, _condition2, _reset, _oldActionType, _isLogin, _time,
            _free, _discount )
        end
    )
end
