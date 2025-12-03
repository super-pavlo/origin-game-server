--[[
* @file : Transport.lua
* @type : snax multi service
* @author : chenlei
* @created : Mon May 11 2020 18:00:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 商栈相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local TransportLogic = require "TransportLogic"
local RoleLogic = require "RoleLogic"
local BuildingLogic = require "BuildingLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"
local ArmyLogic = require "ArmyLogic"
local EarlyWarningLogic = require "EarlyWarningLogic"

---@see 创建运输车
function response.CreateTransport( msg )
    local rid = msg.rid
    local transportResourceInfo = msg.transportResourceInfo
    local targetRid = msg.targetRid

    -- 参数检查
    if not transportResourceInfo or table.empty(transportResourceInfo) then
        LOG_ERROR("rid(%d) CreateTransport, no transportResourceInfo arg", rid)
        return nil, ErrorCode.ROLE_ARG_ERROR
    end
    local buildInfo = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.BUSSINESS )[1]
    if not buildInfo then
        LOG_ERROR("rid(%d) CreateTransport, not build bussiness", rid)
        return nil, ErrorCode.TRANSPORT_NOT_BUILDING
    end
    local s_BuildingFreight =  CFG.s_BuildingFreight:Get(buildInfo.level)
    local roleInfo = RoleLogic:getRole( rid, {
        Enum.Role.troopsDispatchNumber,Enum.Role.troopsCapacity, Enum.Role.transportSpeedMulti, Enum.Role.guildId,
        Enum.Role.pos
    } )
    -- 行军队列是否已满(根据市政厅获取队列数)
    if not TransportLogic:checkTroopNum( rid ) then
        LOG_ERROR("rid(%d) CreateTransport, troop full", rid)
        return nil, ErrorCode.TRANSPORT_TROOP_FULL
    end
    local targetRoleInfo = RoleLogic:getRole( targetRid, {Enum.Role.guildId})
    -- 判断联盟是否相同
    if roleInfo.guildId <= 0 or roleInfo.guildId ~= targetRoleInfo.guildId then
        LOG_ERROR("rid(%d) CreateTransport, guild not same", rid)
        return nil, ErrorCode.TRANSPORT_TROOP_FULL
    end
    buildInfo = BuildingLogic:getBuildingInfoByType( targetRid, Enum.BuildingType.BUSSINESS )[1]
    if not buildInfo then
        LOG_ERROR("rid(%d) CreateTransport, not build bussiness", targetRid)
        return nil, ErrorCode.TRANSPORT_TARGET_NOT_BUILDING
    end
    local totalNum = 0
    for _, resourceInfo in pairs (transportResourceInfo) do
        if resourceInfo.resourceTypeId == Enum.CurrencyType.food then
            if not RoleLogic:checkFood( rid, resourceInfo.load ) then
                LOG_ERROR("rid(%d) CreateTransport, food not enough", targetRid)
                return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
            end
            totalNum = totalNum + resourceInfo.load
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.wood then
            if not RoleLogic:checkWood( rid, resourceInfo.load ) then
                LOG_ERROR("rid(%d) CreateTransport, wood not enough", targetRid)
                return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
            end
            totalNum = totalNum + resourceInfo.load
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.stone then
            if not RoleLogic:checkStone( rid, resourceInfo.load ) then
                LOG_ERROR("rid(%d) CreateTransport, wood not enough", targetRid)
                return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
            end
            totalNum = totalNum + resourceInfo.load
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.gold then
            if not RoleLogic:checkGold( rid, resourceInfo.load ) then
                LOG_ERROR("rid(%d) CreateTransport, gold not enough", targetRid)
                return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
            end
            totalNum = totalNum + resourceInfo.load
        end
    end
    local reduceNum = math.floor( totalNum * s_BuildingFreight.tax / 1000 + 0.5 ) or 0
    if totalNum <= 0 or totalNum - reduceNum  > s_BuildingFreight.capacity then
        LOG_ERROR("rid(%d) CreateTransport, max than capacity", rid)
        return nil, ErrorCode.TRANSPORT_MAX_NUM
    end

    local targetObjectIndex = RoleLogic:getRoleCityIndex( targetRid )
    local cityInfo = MSM.SceneCityMgr[targetObjectIndex].req.getCityInfo( targetObjectIndex )

    local targetPos = cityInfo.pos
    local targetName = cityInfo.name
    local troopsDispatchNumber = roleInfo.troopsDispatchNumber or 0
    local transportIndex = TransportLogic:getFreeTransportIndex( rid, troopsDispatchNumber )

    -- 创建军队
    local transportInfo
    transportIndex, transportInfo = TransportLogic:createTransport( rid, targetRid, targetPos, targetName, targetObjectIndex, transportIndex, transportResourceInfo )

    -- NavMesh寻路
    local navPath = { roleInfo.pos, targetPos }
    -- 生成一个新的对象ID
    local objectIndex = Common.newMapObjectIndex()
    -- 计算行军速度
    local speed = math.floor( CFG.s_Config:Get("transportSpeed") * ( 1000 + roleInfo.transportSpeedMulti ) / 1000 )
    -- 行军部队加入地图
    local arrivalTime = MSM.MapMarchMgr[objectIndex].req.transportEnterMap( rid, objectIndex, transportIndex, navPath, targetObjectIndex, speed )
    -- 发送预警信息
    local fromObjectIndex = RoleLogic:getRoleCityIndex( rid )
    EarlyWarningLogic:notifyTransport( rid, targetRid, arrivalTime, transportInfo, objectIndex, fromObjectIndex )

    return { transportIndex = transportIndex }
end

---@see 遣返运输车
function response.TransportBack( msg )
    local rid = msg.rid
    local objectIndex = msg.objectIndex
    local transportInfo = MSM.SceneTransportMgr[objectIndex].req.getTransportInfo( objectIndex )
    -- 运输车是否存在
    if not transportInfo or table.empty( transportInfo ) then
        LOG_ERROR("rid(%d) TransportBack error, objectIndex(%d) not exist", rid, objectIndex)
        return nil, ErrorCode.TRANSPORT_NOT_EXIST
    end
    local transport = TransportLogic:getTransport( rid, transportInfo.transportIndex )
    if transport.targetRid == rid then
        LOG_ERROR("rid(%d) TransportBack error, march same target", rid)
        return nil, ErrorCode.MAP_MARCH_SAME_TARGET
    end
    transport.transportStatus = Enum.TransportStatus.LEAVE
    transport.targetRid = rid
    TransportLogic:setTransport( rid, transportInfo.transportIndex, transport )
    TransportLogic:syncTransport( rid, transportInfo.transportIndex, transport, true )

    MSM.MapMarchMgr[objectIndex].req.transportBackCity( rid, objectIndex, transportInfo.transportIndex, transportInfo.pos )

    -- 删除预警信息
    local fromObjectIndex = RoleLogic:getRoleCityIndex( rid )
    EarlyWarningLogic:deleteEarlyWarning( transport.targetRid, fromObjectIndex, objectIndex )

    return { objectIndex = objectIndex }
end

---@see 运输前置检测
function response.GetTransport( msg )
    local rid = msg.rid
    local targetRid = msg.targetRid

    local roleInfo = RoleLogic:getRole( rid, {
        Enum.Role.troopsDispatchNumber,Enum.Role.troopsCapacity, Enum.Role.transportSpeedMulti, Enum.Role.guildId,
        Enum.Role.pos
    } )
    -- local targetObjectIndex = RoleLogic:getRoleCityIndex( targetRid )
    -- local cityInfo = MSM.SceneCityMgr[targetObjectIndex].req.getCityInfo( targetObjectIndex )
    -- local targetPos = cityInfo.pos
    -- local toType

    -- -- 获取目标类型
    -- if targetObjectIndex then
    --     local taregetObjectInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectType( targetObjectIndex )
    --     toType = taregetObjectInfo.objectType
    -- end
    -- NavMesh寻路
    local targetPos = RoleLogic:getRole( targetRid, Enum.Role.pos )
    local navPath = { roleInfo.pos, targetPos }
    -- 修正坐标
    local transportRadius = CFG.s_Config:Get( "transportRadius" )
    navPath = ArmyWalkLogic:fixPathPoint( Enum.RoleType.CITY, Enum.RoleType.CITY, navPath, transportRadius, nil, nil, rid )
    -- 计算到达时间
    local speed = math.floor( CFG.s_Config:Get("transportSpeed") * ( 1000 + roleInfo.transportSpeedMulti ) / 1000 )
    local arrivalTime = ArmyLogic:cacleArrivalTime( navPath, speed )
    local status = true
    return { time = arrivalTime - os.time() , status = status, targetRid = targetRid }
end