--[[
* @file : TransportLogic.lua
* @type : lua lib
* @author : chenlei
* @created : Fri May 08 2020 14:15:18 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 运输相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local TransportDef = require "TransportDef"
local BuildingLogic = require "BuildingLogic"
local ArmyLogic = require "ArmyLogic"
local EarlyWarningLogic = require "EarlyWarningLogic"

local TransportLogic = {}

---@see 获取运输车信息
---@return defaultArmyAttrClass
function TransportLogic:getTransport( _rid, _transportIndex, _fields )
    return MSM.d_transport[_rid].req.Get( _rid, _transportIndex, _fields )
end

---@see 更新运输车指定数据
function TransportLogic:setTransport( _rid, _transportIndex, _fields, _data )
    return MSM.d_transport[_rid].req.Set( _rid, _transportIndex, _fields, _data )
end

---@see 同步运输车属性
function TransportLogic:syncTransport( _rid, _transportIndex, _field, _haskv, _block )
    local transportInfo
    local syncInfo = {}
    if not _haskv then
        if type( _transportIndex ) == "table" then
            -- 同步多个部队
            for _, transportIndex in pairs( _transportIndex ) do
                transportInfo = self:getTransport( _rid, transportIndex )
                transportInfo.transportIndex = transportIndex
                syncInfo[transportIndex] = transportInfo
            end
        else
            transportInfo = self:getTransport( _rid, _transportIndex )
            transportInfo.transportIndex = _transportIndex
            syncInfo[_transportIndex] = transportInfo
        end
    else
        if _transportIndex then
            _field.transportIndex = _transportIndex
            syncInfo[_transportIndex] = _field
        else
            syncInfo = _field
        end
    end
    -- 同步
    Common.syncMsg( _rid, "Transport_TransportList",  { transportInfo = syncInfo }, _block )
end

---@see 推送所有运输车信息
function TransportLogic:pushAllTransport( _rid )
    local allTransport = self:getTransport( _rid ) or {}
    local syncTransportInfos = {}
    for transportIndex, transportInfo in pairs( allTransport ) do
        syncTransportInfos[transportIndex] = {
            transportIndex = transportIndex,
            transportResourceInfo = transportInfo.transportResourceInfo,
            deductionResourceInfo = transportInfo.deductionResourceInfo,
            arrivalTime = transportInfo.arrivalTime,
            path = transportInfo.path,
            startTime = transportInfo.startTime,
            objectIndex = transportInfo.objectIndex,
            targetPos = transportInfo.targetPos,
            targetObjectIndex = transportInfo.targetObjectIndex,
            targetName = transportInfo.targetName,
            transportStatus = transportInfo.transportStatus
        }
    end

    -- 同步
    Common.syncMsg( _rid, "Transport_TransportList",  { transportInfo = syncTransportInfos } )
end

---@see 获取空闲部队索引
function TransportLogic:getFreeTransportIndex( _rid, _troopsDispatchNumber )
    local transportIndex = 1
    _troopsDispatchNumber = _troopsDispatchNumber - table.size(ArmyLogic:getArmy(_rid) or {})
    local allTransport = self:getTransport( _rid ) or {}
    for i = 1, _troopsDispatchNumber or 0 do
        if not allTransport[i] then
            transportIndex = i
            break
        end
    end

    return transportIndex
end

---@see 更新运输车信息
function TransportLogic:updateTransportInfo( _rid, _transportIndex, _changeTransportInfo, _noSync )
    self:setTransport( _rid, _transportIndex, _changeTransportInfo )
    if not _noSync then
        -- 通知客户端
        self:syncTransport( _rid, _transportIndex, _changeTransportInfo, true )
    end
end

---@see 判断能否创建部队或者运输车
function TransportLogic:checkTroopNum( _rid )
    local troopsDispatchNumber = RoleLogic:getRole( _rid, Enum.Role.troopsDispatchNumber ) or 0
    local allArmy = ArmyLogic:getArmy( _rid ) or {}
    local allTransport = self:getTransport( _rid ) or {}
    if table.size( allArmy ) + table.size( allTransport ) >= troopsDispatchNumber then
        return false
    end
    return true
end

---@see 创建军队
function TransportLogic:createTransport( _rid, _targetRid, _targetPos, _targetName, _targetObjectIndex, _transportIndex, _transportResourceInfo )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.soldiers, Enum.Role.level, Enum.Role.troopsDispatchNumber } )
    local transportIndex = _transportIndex or self:getTransport( _rid, roleInfo.troopsDispatchNumber )
    local buildInfo = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.BUSSINESS )[1]
    local s_BuildingFreight =  CFG.s_BuildingFreight:Get(buildInfo.level)

    local transportResourceInfo = {}

    for _, resourceInfo in pairs (_transportResourceInfo) do
        if resourceInfo.resourceTypeId == Enum.CurrencyType.food then
            RoleLogic:addFood( _rid, -resourceInfo.load, nil, Enum.LogType.TRANSPORT_COST_CURRENCY )
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.wood then
            RoleLogic:addWood( _rid, -resourceInfo.load, nil, Enum.LogType.TRANSPORT_COST_CURRENCY )
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.stone then
            RoleLogic:addStone( _rid, -resourceInfo.load, nil, Enum.LogType.TRANSPORT_COST_CURRENCY )
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.gold then
            RoleLogic:addGold( _rid, -resourceInfo.load, nil, Enum.LogType.TRANSPORT_COST_CURRENCY )
        end
        local reduceNum
        reduceNum = math.floor( resourceInfo.load * s_BuildingFreight.tax / 1000 + 0.5 ) or 0
        table.insert(transportResourceInfo, { resourceTypeId = resourceInfo.resourceTypeId, load = resourceInfo.load - reduceNum })
    end

    -- 设置部队信息
    local transportInfo = TransportDef:getDefaultTransportAttr()
    transportInfo.transportResourceInfo = transportResourceInfo
    transportInfo.allResourceInfo = _transportResourceInfo
    transportInfo.transportIndex = transportIndex
    transportInfo.targetPos = _targetPos
    transportInfo.targetName = _targetName
    transportInfo.targetObjectIndex = _targetObjectIndex
    transportInfo.transportIndex = transportIndex
    transportInfo.targetRid = _targetRid
    transportInfo.transportStatus = Enum.TransportStatus.LEAVE

    -- 添加部队信息
    local ret = MSM.d_transport[_rid].req.Add( _rid, transportIndex, transportInfo )
    if not ret then
        LOG_ERROR("createTransport, add record to d_transport fail, rid(%d) transportIndex(%d)", _rid, transportIndex)
        return
    end
    -- 通知客户端部队信息
    self:syncTransport( _rid, transportIndex, transportInfo, true )

    return transportIndex, transportInfo
end

---@see 解散运输车
function TransportLogic:marchBackCity( _rid, _transportIndex, _noSync )
    local transport = self:getTransport( _rid, _transportIndex )
    if transport.transportStatus == Enum.TransportStatus.FAIL then
        for _, resourceInfo in pairs (transport.allResourceInfo) do
            if resourceInfo.resourceTypeId == Enum.CurrencyType.food then
                RoleLogic:addFood( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_FAIL_GAIN_CURRENCY )
            elseif resourceInfo.resourceTypeId == Enum.CurrencyType.wood then
                RoleLogic:addWood( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_FAIL_GAIN_CURRENCY )
            elseif resourceInfo.resourceTypeId == Enum.CurrencyType.stone then
                RoleLogic:addStone( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_FAIL_GAIN_CURRENCY )
            elseif resourceInfo.resourceTypeId == Enum.CurrencyType.gold then
                RoleLogic:addGold( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_FAIL_GAIN_CURRENCY )
            end
        end
    elseif transport.transportStatus == Enum.TransportStatus.RETURN or transport.transportStatus == Enum.TransportStatus.LEAVE then
        for _, resourceInfo in pairs (transport.allResourceInfo) do
            if resourceInfo.resourceTypeId == Enum.CurrencyType.food then
                RoleLogic:addFood( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_RETURN_GAIN_CURRENCY )
            elseif resourceInfo.resourceTypeId == Enum.CurrencyType.wood then
                RoleLogic:addWood( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_RETURN_GAIN_CURRENCY )
            elseif resourceInfo.resourceTypeId == Enum.CurrencyType.stone then
                RoleLogic:addStone( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_RETURN_GAIN_CURRENCY )
            elseif resourceInfo.resourceTypeId == Enum.CurrencyType.gold then
                RoleLogic:addGold( _rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_RETURN_GAIN_CURRENCY )
            end
        end
    end
    MSM.d_transport[_rid].req.Delete( _rid, _transportIndex )
    if not _noSync then
        -- 通知客户端部队解散
        self:syncTransport( _rid, _transportIndex, { targetObjectIndex = -1,  objectIndex = transport.objectIndex }, true )
    end
end

---@see 角色登录处理部队信息
function TransportLogic:checkTransportOnRoleLogin( _rid, _noSync )
    local allTransport = self:getTransport( _rid ) or {}
    local transportInfo
    for _, armyInfo in pairs( allTransport ) do
        transportInfo = MSM.SceneTransportMgr[armyInfo.objectIndex].req.getTransportInfo( armyInfo.objectIndex )
        if not transportInfo or ( transportInfo.rid ~= _rid and transportInfo.objectIndex ~= armyInfo.objectIndex ) then
            -- 地图无此对象
            self:marchBackCity( _rid, armyInfo.transportIndex, _noSync )
        end
    end
end

---@see 强制迁城处理
function TransportLogic:forceMoveTransport( _rid )
    local allTransport = self:getTransport( _rid ) or {}
    for _, armyInfo in pairs( allTransport ) do
        -- 删除地图对象
        MSM.AoiMgr[Enum.MapLevel.ARMY].req.transportLeave( Enum.MapLevel.ARMY, armyInfo.objectIndex, { x = -1, y = -1 } )
        -- 删除模拟行走信息
        MSM.MapMarchMgr[armyInfo.objectIndex].req.stopObjectMove(armyInfo.objectIndex)
        -- 删除预警信息
        EarlyWarningLogic:deleteEarlyWarning( armyInfo.targetRid, armyInfo.objectIndex, armyInfo.targetObjectIndex )
        -- 运输车回城处理
        self:marchBackCity( _rid, armyInfo.transportIndex )
    end
end

return TransportLogic