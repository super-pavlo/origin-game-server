--[[
* @file : RoleArmyMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Fri Feb 14 2020 15:38:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色部队索引服务
* Copyright(C) 2017 IGG, All rights reserved
]]

---@see 部队索引信息
local roleArmyIndexs = {} -- { [rid] = { [armyIndex] = objectIndex } }

---@see 增加部队索引信息
function accept.addRoleArmyIndex( _rid, _armyIndex, _objectIndex )
    if not roleArmyIndexs[_rid] then roleArmyIndexs[_rid] = {} end
    roleArmyIndexs[_rid][_armyIndex] = _objectIndex
end

---@see 删除部队索引信息
function accept.deleteRoleArmyIndex( _rid, _armyIndex )
    if roleArmyIndexs[_rid] then
        roleArmyIndexs[_rid][_armyIndex] = nil
        if table.empty( roleArmyIndexs[_rid] ) then
            roleArmyIndexs[_rid] = nil
        end
    end
end

---@see 获取部队索引信息
function response.getRoleArmyIndex( _rid, _armyIndex )
    if roleArmyIndexs[_rid] then
        if _armyIndex then
            return roleArmyIndexs[_rid][_armyIndex]
        else
            return roleArmyIndexs[_rid]
        end
    end
end