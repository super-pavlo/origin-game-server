--[[
 * @file : EarlyWarningLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-13 16:55:09
 * @Last Modified time: 2020-05-13 16:55:09
 * @department : Arabic Studio
 * @brief : 战斗预警逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local MapObjectLogic = require "MapObjectLogic"
local RoleLogic = require "RoleLogic"

local EarlyWarningLogic = {}

---@see 检查预警是否到期
---@param _allEarlyWarningInfo table<int, defaultEarlyWarningInfoClass>
function EarlyWarningLogic:checkEarlyWarningTimeout( _allEarlyWarningInfo )
    local now = os.time()
    for rid, earlyWarningInfos in pairs(_allEarlyWarningInfo) do
        for earlyWarningIndex, earlyWarningInfo in pairs(earlyWarningInfos) do
            if earlyWarningInfo.arrivalTime <= now then
                earlyWarningInfos[earlyWarningIndex] = nil
                -- 预警到期,移除
                local syncContent = {
                    [earlyWarningIndex] = {
                            earlyWarningIndex = earlyWarningIndex,
                            isDelete = true
                        }
                }
                Common.syncMsg( rid, "Role_EarlyWarningInfo", { earlyWarningInfo = syncContent } )
            end
        end

        if table.empty(earlyWarningInfos) then
            _allEarlyWarningInfo[rid] = nil
        end
    end
end

---@see 通知目标被侦察
function EarlyWarningLogic:notifyScout( _scoutRid, _scoutTargetRid, _scoutArrivalTime, _scoutObjectIndex, _fromObjectIndex,
                                        _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    MSM.EarlyWarningMgr[_scoutTargetRid].post.addScoutEarlyWarning( _scoutRid, _scoutTargetRid, _scoutArrivalTime,
                                        _scoutObjectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _fromObjectIndex )
end

---@see 通知目标被攻击
function EarlyWarningLogic:notfiyAttack( _attackRid, _attackTargetRid, _attackArrivalTime, _attackSoldiers, _attackObjectIndex,
                                        _fromObjectIndex,_mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    MSM.EarlyWarningMgr[_attackTargetRid].post.addAttackEarlyWarning( _attackRid, _attackTargetRid, _attackArrivalTime, _attackSoldiers,
                                        _attackObjectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _fromObjectIndex )
end

---@see 通知目标被增援
function EarlyWarningLogic:notifyReinforce( _reinforceRid, _reinforceTargetRid, _reinforceArrivalTime, _reinforceSoldiers,
                                        _reinforceObjectIndex, _fromObjectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    MSM.EarlyWarningMgr[_reinforceTargetRid].post.addReinforceEarlyWarning( _reinforceRid, _reinforceTargetRid, _reinforceArrivalTime, _reinforceSoldiers,
                                        _reinforceObjectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _fromObjectIndex )
end

---@see 通知目标被运输
function EarlyWarningLogic:notifyTransport( _transportRid, _transportTargetRid, _transportArrivalTime, _transportInfo,
                                            _transportObjectIndex, _fromObjectIndex )
    MSM.EarlyWarningMgr[_transportTargetRid].post.addTransportEarlyWarning( _transportRid, _transportTargetRid, _transportArrivalTime,
                                         _transportInfo, _transportObjectIndex, _fromObjectIndex )
end

---@see 通知被攻击目标.攻击部队数量变化
function EarlyWarningLogic:syncAttackerSoldiers( _attackTargetRid, _objectIndex, _fromObjectIndex, _attackSoldiers )
    MSM.EarlyWarningMgr[_attackTargetRid].post.updateAttackerSoldiers( _attackTargetRid, _objectIndex, _fromObjectIndex, _attackSoldiers  )
end

---@see 删除预警信息.攻击方取消攻击或者取消侦察或取消增援
function EarlyWarningLogic:deleteEarlyWarning( _attackTargetRid, _fromObjectIndex, _attackObjectIndex )
    MSM.EarlyWarningMgr[_attackTargetRid].post.cancleEarlyWarning( _attackTargetRid, _fromObjectIndex, _attackObjectIndex )
end

---@see 推送角色预警信息
function EarlyWarningLogic:pushEarlyWarning( _rid )
    MSM.EarlyWarningMgr[_rid].post.pushEarlyWarning( _rid )
end

---@see 进入建筑.增加推送预警
function EarlyWarningLogic:enterBuildAddWarning( _rid, _objectIndex, _moveToObjects )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    for moveObjectIndex, marchInfo in pairs(_moveToObjects) do
        -- 攻击、增援、加入集结、侦查才有预警
        if marchInfo.marchType == Enum.MapMarchTargetType.ATTACK or marchInfo.marchType == Enum.MapMarchTargetType.REINFORCE
        or marchInfo.marchType == Enum.MapMarchTargetType.RALLY or marchInfo.marchType == Enum.MapMarchTargetType.RALLY_ATTACK
        or marchInfo.marchType == Enum.MapMarchTargetType.COLLECT or marchInfo.marchType == Enum.MapMarchTargetType.SCOUTS then
            local armyInfo = MSM.MapObjectTypeMgr[moveObjectIndex].req.getObjectInfo(moveObjectIndex)
            if armyInfo then
                local armyGuildId = RoleLogic:getRole( armyInfo.rid, Enum.Role.guildId )
                -- 不能向自己发送攻击和侦查预警
                if armyInfo.rid ~= _rid and ( guildId == 0 or guildId ~= armyGuildId ) then
                    if marchInfo.marchType == Enum.MapMarchTargetType.ATTACK or marchInfo.marchType == Enum.MapMarchTargetType.RALLY_ATTACK
                    or marchInfo.marchType == Enum.MapMarchTargetType.COLLECT then
                        self:notfiyAttack( armyInfo.rid, _rid, marchInfo.arrivalTime, armyInfo.soldiers, _objectIndex, moveObjectIndex,
                                                        armyInfo.mainHeroId, armyInfo.mainHeroLevel, armyInfo.deputyHeroId, armyInfo.deputyHeroLevel )
                    elseif marchInfo.marchType == Enum.MapMarchTargetType.REINFORCE or marchInfo.marchType == Enum.MapMarchTargetType.RALLY then
                        self:notifyReinforce( armyInfo.rid, _rid, marchInfo.arrivalTime, armyInfo.soldiers, _objectIndex, moveObjectIndex,
                                                        armyInfo.mainHeroId, armyInfo.mainHeroLevel, armyInfo.deputyHeroId, armyInfo.deputyHeroLevel )
                    elseif marchInfo.marchType == Enum.MapMarchTargetType.SCOUTS then
                        self:notifyScout( armyInfo.rid, _rid, marchInfo.arrivalTime, _objectIndex, moveObjectIndex )
                    end
                end
            end
        end
    end
end

---@see 出建筑.删除预警
function EarlyWarningLogic:leaveBuildDelWarning( _rid, _objectIndex, _moveToObjects )
    for moveObjectIndex in pairs( _moveToObjects or {} ) do
        self:deleteEarlyWarning( _rid, moveObjectIndex, _objectIndex )
    end
end

---@see 斥候侦查发送侦查预警
function EarlyWarningLogic:addScoutEarlyWarning( _rid, _objectIndex, _arrivalTime, _targetObjectIndex, _taregetObjectInfo )
    if not _targetObjectIndex then return end
    _taregetObjectInfo = _taregetObjectInfo or MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
    if not _taregetObjectInfo then return end

    local toType = _taregetObjectInfo.objectType
    if toType == Enum.RoleType.CITY or toType == Enum.RoleType.ARMY
        or MapObjectLogic:checkIsResourceObject( toType ) or MapObjectLogic:checkIsGuildBuildObject( toType )
        or MapObjectLogic:checkIsHolyLandObject( toType ) then
        local rids = { _taregetObjectInfo.rid }
        if MapObjectLogic:checkIsResourceObject( toType ) then
            -- 资源点,获取采集内的角色
            rids = { _taregetObjectInfo.collectRid }
        elseif MapObjectLogic:checkIsGuildBuildObject( toType ) then
            -- 联盟建筑,获取建筑内的所有人
            rids = table.indexs( _taregetObjectInfo.garrison )
        elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
            -- 圣地建筑,获取建筑内的所有人
            rids = table.indexs( _taregetObjectInfo.garrison )
        elseif toType == Enum.RoleType.ARMY and _taregetObjectInfo.isRally then
            -- 集结部队
            rids = table.indexs( _taregetObjectInfo.rallyArmy )
        end
        -- 发送侦察预警
        for _, targetRid in pairs(rids) do
            self:notifyScout( _rid, targetRid, _arrivalTime, _targetObjectIndex, _objectIndex )
        end
    end
end

---@see 删除斥候对旧的侦查目标的侦查预警
function EarlyWarningLogic:deleteScoutEarlyWarning( _objectIndex, _oldTargetIndex, _oldTaregetObjectInfo, _toRids )
    if not _oldTargetIndex then return end
    local oldTaregetObjectInfo = _oldTaregetObjectInfo or MSM.MapObjectTypeMgr[_oldTargetIndex].req.getObjectInfo( _oldTargetIndex )
    if not oldTaregetObjectInfo then return end

    local toType = oldTaregetObjectInfo.objectType
    if toType then
        if toType == Enum.RoleType.CITY or toType == Enum.RoleType.ARMY
            or MapObjectLogic:checkIsResourceObject( toType ) or MapObjectLogic:checkIsGuildBuildObject( toType )
            or MapObjectLogic:checkIsHolyLandObject( toType ) then
            local rids
            if _toRids then
                rids = _toRids
            else
                rids = { oldTaregetObjectInfo.rid }
                if MapObjectLogic:checkIsResourceObject( toType ) then
                    -- 资源点,获取采集内的角色
                    rids = { oldTaregetObjectInfo.collectRid }
                elseif MapObjectLogic:checkIsGuildBuildObject( toType ) then
                    -- 联盟建筑,获取建筑内的所有人
                    rids = table.indexs( oldTaregetObjectInfo.garrison )
                elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
                    -- 圣地关卡
                    rids = table.indexs( oldTaregetObjectInfo.garrison )
                elseif toType == Enum.RoleType.ARMY and oldTaregetObjectInfo.isRally then
                    -- 集结部队
                    rids = table.indexs( oldTaregetObjectInfo.rallyArmy )
                end
            end
            for _, targetRid in pairs( rids or {} ) do
                self:deleteEarlyWarning( targetRid, _objectIndex, _oldTargetIndex )
            end
        end
    end
end

---@see 更新预警结束时间
function EarlyWarningLogic:updateEarlyWarningTime( _objectIndex, _fromObjectIndex, _arrivalTime )
    local targetInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    if not targetInfo or table.empty( targetInfo ) then
        return
    end
    -- 获取目标内的rid
    local targetRids = { targetInfo.rid }
    if MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
        local resourceInfo = MSM.SceneResourceMgr[_objectIndex].req.getResourceInfo( _objectIndex )
        targetRids = { resourceInfo.collectRid }
    elseif MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
        -- 联盟建筑,通知建筑内的所有成员
        targetRids = MSM.SceneGuildBuildMgr[_objectIndex].req.getMemberRidsInBuild( _objectIndex )
    elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
        -- 圣地建筑,通知建筑内的所有成员
        targetRids = MSM.SceneHolyLandMgr[_objectIndex].req.getMemberRidsInBuild( _objectIndex )
    elseif targetInfo.objectType == Enum.RoleType.ARMY and targetInfo.isRally then
        -- 集结部队
        targetRids = table.indexs( targetInfo.rallyArmy )
    end
    for _, targetRid in pairs(targetRids) do
        MSM.EarlyWarningMgr[targetRid].post.updateEarlyWarningTime( targetRid, _objectIndex, _fromObjectIndex, _arrivalTime )
    end
end

return EarlyWarningLogic