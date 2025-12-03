--[[
 * @file : RolePowerMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-11-17 11:33:14
 * @Last Modified time: 2020-11-17 11:33:14
 * @department : Arabic Studio
 * @brief : 角色战斗力计算管理服务
 * Copyright(C) 2020 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"

---@see 计算角色战斗力
function accept.cacleSyncHistoryPower( _rids )
    for _, rid in pairs(_rids) do
        RoleLogic:cacleSyncHistoryPower( rid )
    end
end