--[[
 * @file : SoldierLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-07-14 09:14:44
 * @Last Modified time: 2020-07-14 09:14:44
 * @department : Arabic Studio
 * @brief : 士兵逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local SoldierLogic = {}

---@see 增加士兵.对同角色互斥处理
function SoldierLogic:addSoldier( _rid, _addSoldiers, _notCaclePower )
    local ret ,err = xpcall(MSM.SoldierLockMgr[_rid].req.addSoldiersInLock, debug.traceback, _rid, _addSoldiers, _notCaclePower)
    if not ret then
        LOG_ERROR("addSoldiersInLock err:%s", err)
    end
end

---@see 减少士兵.对同角色互斥处理
function SoldierLogic:subSoldier( _rid, _subSoldiers )
    local ret ,err = xpcall(MSM.SoldierLockMgr[_rid].req.subSoldiersInLock, debug.traceback, _rid, _subSoldiers)
    if not ret then
        LOG_ERROR("subSoldiersInLock err:%s", err)
    end
end

---@see 治疗伤兵.对同角色互斥处理
function SoldierLogic:subSeriousInLock( _rid, _soldiers )
    local ret ,err, addSoldierInfo = xpcall(MSM.SeriousInjureMgr[_rid].req.subSeriousInLock, debug.traceback, _rid, _soldiers )
    if not ret then
        LOG_ERROR("subSoldiersInLock err:%s", err)
    else
        return err, addSoldierInfo
    end
end

---@see 医院增加伤兵.对同角色互斥处理
function SoldierLogic:addSeriousInLock( _rid, _soldiers )
    local ret ,err = xpcall(MSM.SeriousInjureMgr[_rid].post.addSeriousInLock, debug.traceback, _rid, _soldiers )
    if not ret then
        LOG_ERROR("subSoldiersInLock err:%s", err)
    else
        return err
    end
end

return SoldierLogic