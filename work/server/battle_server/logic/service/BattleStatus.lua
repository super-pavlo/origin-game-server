--[[
* @file : BattleStatus.lua
* @type : snax multi service
* @author : linfeng
* @created : Fri Feb 02 2018 09:14:03 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色战斗状态管理
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleStatus = {}

---@see 增加角色战斗状态
function accept.addRoleStatus( _rid, _battleIndex )
    RoleStatus[_rid] = _battleIndex
end

---@see 移除角色战斗状态
function accept.delRoleStatus( _rid )
    RoleStatus[_rid] = nil
end

---@see 获取角色战斗状态
-- return: true(战斗),false、nil(非战斗)
function response.getRoleStatus( _rid )
    return RoleStatus[_rid]
end