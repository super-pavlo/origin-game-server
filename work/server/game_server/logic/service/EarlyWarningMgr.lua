--[[
 * @file : EarlyWarningMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-05-13 17:02:26
 * @Last Modified time: 2020-05-13 17:02:26
 * @department : Arabic Studio
 * @brief : 角色预警管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local Timer = require "Timer"
local EarlyWarningLogic = require "EarlyWarningLogic"
local EarlyWarningDef = require "EarlyWarningDef"
local MapObjectLogic = require "MapObjectLogic"
local GuildLogic = require "GuildLogic"

---@type table<int, table<int, defaultEarlyWarningInfoClass>>
local allEarlyWarningInfo = {}

function init()
    Timer.runEvery( 100, EarlyWarningLogic.checkEarlyWarningTimeout, EarlyWarningLogic, allEarlyWarningInfo )
end

function response.Init()
    -- body
end

---@see 增加侦察预警信息
function accept.addScoutEarlyWarning( _scoutRid, _scoutTargetRid, _scoutArrivalTime, _scoutObjectIndex,
                                        _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _fromObjectIndex )
    local earlyWarningIndex = Common.redisExecute( { "incr", string.format("earlyWarningIndex_%d", _scoutTargetRid) } )
    local defaultEarlyWarning = EarlyWarningDef:getDefaultEarlyWarningInfo()
    defaultEarlyWarning.earlyWarningIndex = earlyWarningIndex
    defaultEarlyWarning.earlyWarningType = Enum.EarlyWarningType.SCOUT
    defaultEarlyWarning.scoutFromName = RoleLogic:getRole( _scoutRid, Enum.Role.name )
    defaultEarlyWarning.arrivalTime = _scoutArrivalTime
    defaultEarlyWarning.objectIndex = _scoutObjectIndex
    defaultEarlyWarning.fromObjectIndex = _fromObjectIndex
    defaultEarlyWarning.mainHeroId = _mainHeroId
    defaultEarlyWarning.mainHeroLevel = _mainHeroLevel
    defaultEarlyWarning.deputyHeroId = _deputyHeroId
    defaultEarlyWarning.deputyHeroLevel = _deputyHeroLevel

    local guildId = RoleLogic:getRole( _scoutRid, Enum.Role.guildId )
    if guildId and guildId > 0 then
        local guildInfo = GuildLogic:getGuildInfo( guildId )
        defaultEarlyWarning.guildAbbr = guildInfo.abbreviationName
    end

    local scountObjectInfo = MSM.MapObjectTypeMgr[_scoutObjectIndex].req.getObjectType( _scoutObjectIndex )
    defaultEarlyWarning.scoutObjectType = scountObjectInfo.objectType
    if scountObjectInfo.objectType == Enum.RoleType.ARMY then
        -- 获取部队索引
        local armyInfo = MSM.SceneArmyMgr[_scoutObjectIndex].req.getArmyInfo( _scoutObjectIndex )
        defaultEarlyWarning.armyIndex = armyInfo.armyIndex
    elseif MapObjectLogic:checkIsResourceObject( scountObjectInfo.objectType ) then
        -- 获取资源内的部队
        local resourceInfo = MSM.SceneResourceMgr[_scoutObjectIndex].req.getResourceInfo( _scoutObjectIndex )
        defaultEarlyWarning.armyIndex = resourceInfo.armyIndex
    elseif MapObjectLogic:checkIsHolyLandObject( scountObjectInfo.objectType ) then
        -- 圣地,取具体的圣地类型
        ---@type defaultMapHolyLandInfoClass
        local holyLandInfo = MSM.SceneHolyLandMgr[_scoutObjectIndex].req.getHolyLandInfo( _scoutObjectIndex )
        defaultEarlyWarning.holyLandId = holyLandInfo.strongHoldId
        defaultEarlyWarning.scoutObjectType = MapObjectLogic:getRealHolyLandType( holyLandInfo.strongHoldId, holyLandInfo.holyLandStatus, true )
        -- 获取圣地内的部队
        if holyLandInfo.garrison[_scoutTargetRid] then
            defaultEarlyWarning.armyIndex = table.first( holyLandInfo.garrison[_scoutTargetRid] ).key
        end
    elseif MapObjectLogic:checkIsGuildBuildObject( scountObjectInfo.objectType ) then
        -- 取联盟建筑内的部队
        ---@type defaultMapGuildBuildInfoClass
        local guildBuildInfo = MSM.SceneGuildBuildMgr[_scoutObjectIndex].req.getGuildBuildInfo( _scoutObjectIndex )
        if guildBuildInfo.garrison[_scoutTargetRid] and not table.empty( guildBuildInfo.garrison[_scoutTargetRid] ) then
            defaultEarlyWarning.armyIndex = table.first( guildBuildInfo.garrison[_scoutTargetRid] ).key
        end
    end

    -- 加入到预警管理中
    if not allEarlyWarningInfo[_scoutTargetRid] then
        allEarlyWarningInfo[_scoutTargetRid] = {}
    end
    allEarlyWarningInfo[_scoutTargetRid][earlyWarningIndex] = defaultEarlyWarning

    -- 同步给客户端
    Common.syncMsg( _scoutTargetRid, "Role_EarlyWarningInfo", { earlyWarningInfo = { defaultEarlyWarning } } )
end

---@see 增加攻击预警信息
function accept.addAttackEarlyWarning( _attackRid, _attackTargetRid, _attackArrivalTime, _attackSoldiers, _attackObjectIndex,
                                        _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _fromObjectIndex )
    local earlyWarningIndex = Common.redisExecute({ "incr", string.format("earlyWarningIndex_%d", _attackTargetRid) })
    local defaultEarlyWarning = EarlyWarningDef:getDefaultEarlyWarningInfo()
    defaultEarlyWarning.earlyWarningIndex = earlyWarningIndex
    defaultEarlyWarning.earlyWarningType = Enum.EarlyWarningType.ATTACK
    defaultEarlyWarning.scoutFromName = RoleLogic:getRole( _attackRid, Enum.Role.name )
    defaultEarlyWarning.attackSoldiers = _attackSoldiers
    defaultEarlyWarning.arrivalTime = _attackArrivalTime
    defaultEarlyWarning.objectIndex = _attackObjectIndex
    defaultEarlyWarning.fromObjectIndex = _fromObjectIndex
    defaultEarlyWarning.mainHeroId = _mainHeroId
    defaultEarlyWarning.mainHeroLevel = _mainHeroLevel
    defaultEarlyWarning.deputyHeroId = _deputyHeroId
    defaultEarlyWarning.deputyHeroLevel = _deputyHeroLevel

    local guildId = RoleLogic:getRole( _attackRid, Enum.Role.guildId )
    if guildId and guildId > 0 then
        local guildInfo = GuildLogic:getGuildInfo( guildId )
        defaultEarlyWarning.guildAbbr = guildInfo.abbreviationName
    end

    local fromObjectInfo = MSM.MapObjectTypeMgr[_fromObjectIndex].req.getObjectInfo( _fromObjectIndex )
    if fromObjectInfo.objectType == Enum.RoleType.ARMY and fromObjectInfo.isRally then
        -- 被集结部队攻击
        defaultEarlyWarning.isRally = true
    end

    local attackObjectInfo = MSM.MapObjectTypeMgr[_attackObjectIndex].req.getObjectType( _attackObjectIndex )
    if not attackObjectInfo then
        return
    end
    defaultEarlyWarning.scoutObjectType = attackObjectInfo.objectType
    if attackObjectInfo.objectType == Enum.RoleType.ARMY then
        -- 获取部队索引
        local armyInfo = MSM.SceneArmyMgr[_attackObjectIndex].req.getArmyInfo( _attackObjectIndex )
        defaultEarlyWarning.armyIndex = armyInfo.armyIndex
    elseif MapObjectLogic:checkIsResourceObject( attackObjectInfo.objectType ) then
        -- 获取资源内的部队
        local resourceInfo = MSM.SceneResourceMgr[_attackObjectIndex].req.getResourceInfo( _attackObjectIndex )
        defaultEarlyWarning.armyIndex = resourceInfo.armyIndex
    elseif MapObjectLogic:checkIsHolyLandObject( attackObjectInfo.objectType ) then
        -- 圣地,取具体的圣地类型
        local holyLandInfo = MSM.SceneHolyLandMgr[_attackObjectIndex].req.getHolyLandInfo( _attackObjectIndex )
        defaultEarlyWarning.holyLandId = holyLandInfo.strongHoldId
        defaultEarlyWarning.scoutObjectType = MapObjectLogic:getRealHolyLandType( holyLandInfo.strongHoldId, holyLandInfo.holyLandStatus, true )
        -- 获取圣地内的部队
        if holyLandInfo.garrison[_attackTargetRid] then
            defaultEarlyWarning.armyIndex = table.first( holyLandInfo.garrison[_attackTargetRid] ).key
        end
    elseif MapObjectLogic:checkIsGuildBuildObject( attackObjectInfo.objectType ) then
        -- 取联盟建筑内的部队
        ---@type defaultMapGuildBuildInfoClass
        local guildBuildInfo = MSM.SceneGuildBuildMgr[_attackObjectIndex].req.getGuildBuildInfo( _attackObjectIndex )
        if guildBuildInfo.garrison[_attackTargetRid] then
            defaultEarlyWarning.armyIndex = table.first( guildBuildInfo.garrison[_attackTargetRid] ).key
        end
    end

    -- 加入到预警管理中
    if not allEarlyWarningInfo[_attackTargetRid] then
        allEarlyWarningInfo[_attackTargetRid] = {}
    end
    allEarlyWarningInfo[_attackTargetRid][earlyWarningIndex] = defaultEarlyWarning

    -- 同步给客户端
    Common.syncMsg( _attackTargetRid, "Role_EarlyWarningInfo", { earlyWarningInfo = { defaultEarlyWarning } } )
end

---@see 增加增援预警信息
function accept.addReinforceEarlyWarning( _reinforceRid, _reinforceTargetRid, _reinforceArrivalTime, _reinforceSoldiers, _reinforceObjectIndex,
                                            _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel, _fromObjectIndex )
    local earlyWarningIndex = Common.redisExecute({ "incr", string.format("earlyWarningIndex_%d", _reinforceTargetRid) })
    local defaultEarlyWarning = EarlyWarningDef:getDefaultEarlyWarningInfo()
    defaultEarlyWarning.earlyWarningIndex = earlyWarningIndex
    defaultEarlyWarning.earlyWarningType = Enum.EarlyWarningType.REINFORCE
    defaultEarlyWarning.scoutFromName = RoleLogic:getRole( _reinforceRid, Enum.Role.name )
    defaultEarlyWarning.attackSoldiers = _reinforceSoldiers
    defaultEarlyWarning.arrivalTime = _reinforceArrivalTime
    defaultEarlyWarning.objectIndex = _reinforceObjectIndex
    defaultEarlyWarning.fromObjectIndex = _fromObjectIndex
    defaultEarlyWarning.mainHeroId = _mainHeroId
    defaultEarlyWarning.mainHeroLevel = _mainHeroLevel
    defaultEarlyWarning.deputyHeroId = _deputyHeroId
    defaultEarlyWarning.deputyHeroLevel = _deputyHeroLevel

    local guildId = RoleLogic:getRole( _reinforceRid, Enum.Role.guildId )
    if guildId and guildId > 0 then
        local guildInfo = GuildLogic:getGuildInfo( guildId )
        defaultEarlyWarning.guildAbbr = guildInfo.abbreviationName
    end

    local reinforceObjectInfo = MSM.MapObjectTypeMgr[_reinforceObjectIndex].req.getObjectType( _reinforceObjectIndex )
    defaultEarlyWarning.scoutObjectType = reinforceObjectInfo.objectType
    if reinforceObjectInfo.objectType == Enum.RoleType.ARMY then
        -- 获取部队索引
        local armyInfo = MSM.SceneArmyMgr[_reinforceObjectIndex].req.getArmyInfo( _reinforceObjectIndex )
        defaultEarlyWarning.armyIndex = armyInfo.armyIndex
    elseif MapObjectLogic:checkIsResourceObject( reinforceObjectInfo.objectType ) then
        -- 获取资源内的部队
        local resourceInfo = MSM.SceneResourceMgr[_reinforceObjectIndex].req.getResourceInfo( _reinforceObjectIndex )
        defaultEarlyWarning.armyIndex = resourceInfo.armyIndex
    elseif MapObjectLogic:checkIsHolyLandObject( reinforceObjectInfo.objectType ) then
        -- 圣地,取具体的圣地类型
        local holyLandInfo = MSM.SceneHolyLandMgr[_reinforceObjectIndex].req.getHolyLandInfo( _reinforceObjectIndex )
        defaultEarlyWarning.holyLandId = holyLandInfo.strongHoldId
        defaultEarlyWarning.scoutObjectType = MapObjectLogic:getRealHolyLandType( holyLandInfo.strongHoldId, holyLandInfo.holyLandStatus, true )
        -- 获取圣地内的部队
        if holyLandInfo.garrison[_reinforceTargetRid] then
            defaultEarlyWarning.armyIndex = table.first( holyLandInfo.garrison[_reinforceTargetRid] ).key
        end
    elseif MapObjectLogic:checkIsGuildBuildObject( reinforceObjectInfo.objectType ) then
        -- 取联盟建筑内的部队
        ---@type defaultMapGuildBuildInfoClass
        local guildBuildInfo = MSM.SceneGuildBuildMgr[_reinforceObjectIndex].req.getGuildBuildInfo( _reinforceObjectIndex )
        if guildBuildInfo.garrison[_reinforceTargetRid] then
            defaultEarlyWarning.armyIndex = table.first( guildBuildInfo.garrison[_reinforceTargetRid] ).key
        end
    end

    -- 加入到预警管理中
    if not allEarlyWarningInfo[_reinforceTargetRid] then
        allEarlyWarningInfo[_reinforceTargetRid] = {}
    end
    allEarlyWarningInfo[_reinforceTargetRid][earlyWarningIndex] = defaultEarlyWarning

    -- 同步给客户端
    Common.syncMsg( _reinforceTargetRid, "Role_EarlyWarningInfo", {  earlyWarningInfo = { defaultEarlyWarning } } )
end


---@see 增加运输预警信息
function accept.addTransportEarlyWarning( _transportRid, _transportTargetRid, _transportArrivalTime,
                                        _transportInfo, _transportObjectIndex, _fromObjectIndex )
    local earlyWarningIndex = Common.redisExecute({ "incr", string.format("earlyWarningIndex_%d", _transportTargetRid) })
    local defaultEarlyWarning = EarlyWarningDef:getDefaultEarlyWarningInfo()
    defaultEarlyWarning.earlyWarningIndex = earlyWarningIndex
    defaultEarlyWarning.earlyWarningType = Enum.EarlyWarningType.TRANSPORT
    local roleInfo = RoleLogic:getRole( _transportRid, { Enum.Role.name, Enum.Role.guildId } )

    if roleInfo.guildId and roleInfo.guildId > 0 then
        local guildInfo = GuildLogic:getGuildInfo( roleInfo.guildId )
        defaultEarlyWarning.guildAbbr = guildInfo.abbreviationName
    end

    defaultEarlyWarning.transportName = roleInfo.name
    defaultEarlyWarning.arrivalTime = _transportArrivalTime
    defaultEarlyWarning.objectIndex = _transportObjectIndex
    defaultEarlyWarning.fromObjectIndex = _fromObjectIndex
    defaultEarlyWarning.transportResourceInfo = _transportInfo.transportResourceInfo

    -- 获取运输车索引
    local armyInfo = MSM.SceneTransportMgr[_transportObjectIndex].req.getTransportInfo( _transportObjectIndex )
    defaultEarlyWarning.armyIndex = armyInfo.transportIndex

    -- 加入到预警管理中
    if not allEarlyWarningInfo[_transportTargetRid] then
    allEarlyWarningInfo[_transportTargetRid] = {}
    end
    allEarlyWarningInfo[_transportTargetRid][earlyWarningIndex] = defaultEarlyWarning

    -- 同步给客户端
    Common.syncMsg( _transportTargetRid, "Role_EarlyWarningInfo", { earlyWarningInfo = { defaultEarlyWarning } } )
end


---@see 取消预警信息
function accept.cancleEarlyWarning( _attackTargetRid, _fromObjectIndex, _objectIndex )
    if allEarlyWarningInfo[_attackTargetRid] then
        for earlyWarningIndex, earlyWarningInfo in pairs(allEarlyWarningInfo[_attackTargetRid]) do
            if earlyWarningInfo.objectIndex == _objectIndex and earlyWarningInfo.fromObjectIndex == _fromObjectIndex then
                -- 同步客户端
                local syncContent = {
                    [earlyWarningIndex] = {
                        earlyWarningIndex = earlyWarningIndex,
                        isDelete = true
                    }
                }

                Common.syncMsg( _attackTargetRid, "Role_EarlyWarningInfo", { earlyWarningInfo = syncContent } )
                allEarlyWarningInfo[_attackTargetRid][earlyWarningIndex] = nil
                break
            end
        end
    end
end

---@see 更新攻击方部队信息
function accept.updateAttackerSoldiers( _attackTargetRid, _objectIndex, _fromObjectIndex, _attackSoldiers )
    if allEarlyWarningInfo[_attackTargetRid] then
        for earlyWarningIndex, earlyWarningInfo in pairs(allEarlyWarningInfo[_attackTargetRid]) do
            if earlyWarningInfo.objectIndex == _objectIndex and earlyWarningInfo.fromObjectIndex == _fromObjectIndex then
                -- 同步客户端
                local syncContent = {
                    [earlyWarningIndex] = {
                        earlyWarningIndex = earlyWarningIndex,
                        attackSoldiers = _attackSoldiers
                    }
                }
                Common.syncMsg( _attackTargetRid, "Role_EarlyWarningInfo", { earlyWarningInfo = syncContent } )
                allEarlyWarningInfo[_attackTargetRid][earlyWarningIndex].attackSoldiers = _attackSoldiers
                break
            end
        end
    end
end

---@see 推送预警信息
function accept.pushEarlyWarning( _rid )
    if allEarlyWarningInfo[_rid] then
        local syncContent = { earlyWarningInfo = allEarlyWarningInfo[_rid] }
        Common.syncMsg( _rid, "Role_EarlyWarningInfo", syncContent )
    end
end

---@see 屏蔽预警信息
function accept.shiledEarlyWarning( _rid, _earlyWarningIndexs )
    if allEarlyWarningInfo[_rid] then
        local syncContent = {}
        for _, earlyWarningIndex in pairs(_earlyWarningIndexs) do
            if allEarlyWarningInfo[_rid][earlyWarningIndex] then
                allEarlyWarningInfo[_rid][earlyWarningIndex].isShield = true
                table.insert( syncContent, {
                    earlyWarningIndex = earlyWarningIndex,
                    isShield = true
                })
            end
        end

        -- 同步给客户端
        Common.syncMsg( _rid, "Role_EarlyWarningInfo", { earlyWarningInfo = syncContent } )
    end
end

---@see 更新预警结束时间
function accept.updateEarlyWarningTime( _targetRid, _objectIndex, _fromObjectIndex, _arrivalTime )
    -- 更新到达时间
    if allEarlyWarningInfo[_targetRid] then
        for earlyWarningIndex, earlyWarningInfo in pairs(allEarlyWarningInfo[_targetRid]) do
            if earlyWarningInfo.objectIndex == _objectIndex and earlyWarningInfo.fromObjectIndex == _fromObjectIndex then
                -- 同步客户端
                local syncContent = {
                    [earlyWarningIndex] = {
                        earlyWarningIndex = earlyWarningIndex,
                        arrivalTime = _arrivalTime
                    }
                }
                Common.syncMsg( _targetRid, "Role_EarlyWarningInfo", { earlyWarningInfo = syncContent } )
                allEarlyWarningInfo[_targetRid][earlyWarningIndex].arrivalTime = _arrivalTime
                break
            end
        end
    end
end