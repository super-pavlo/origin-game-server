--[[
* @file : RoleSync.lua
* @type : lualib
* @author : linfeng
* @created : Mon Dec 04 2017 10:30:59 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 玩家角色相关信息同步模块
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleSync = {}

---@see 同步玩家角色属性
function RoleSync:syncRoleAttr( _rid, _fields, _toRid )
    local syncContent = MSM.d_role[_rid].req.Get( _rid, _fields )
    syncContent.rid = _rid
    _toRid = _toRid or _rid
    Common.syncMsg( _toRid, "Role_RoleInfo", { roleInfo = syncContent } )
end

---@see 同步角色相关信息
function RoleSync:syncSelf( _rid, _fields, _haskv, _block, _sendNow, _notLog, _cache )
    local syncContent = _fields
    if not _haskv then
        syncContent = MSM.d_role[_rid].req.Get( _rid, _fields )
    end
    syncContent.rid = _rid
    Common.syncMsg( _rid, "Role_RoleInfo",  { roleInfo = syncContent }, _block, _sendNow, _notLog, _cache )
    syncContent.rid = nil -- 避免污染_fields
end

---@see 同步踢掉信息
function RoleSync:syncKick( _rid, _reason )
    Common.syncMsg( _rid, "System_KickConnect",  { reason = _reason }, true, true )
end

return RoleSync