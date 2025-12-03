--[[
* @file : ResourceMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Fri Jan 03 2020 15:15:48 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 资源刷新服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local RoleLogic = require "RoleLogic"
local ResourceLogic = require "ResourceLogic"
local snax = require "skynet.snax"
local MapLogic = require "MapLogic"
local ArmyLogic = require "ArmyLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local BattleCreate = require "BattleCreate"
local GuildLogic = require "GuildLogic"
local CommonCacle = require "CommonCacle"

---@see 资源点信息
-- { [resourceIndex] = {
--    resourceId = id1, zoneIndex = index2, resourceTypeId = id1,
--    refreshTime = time1, pos = pos1, collectRid = rid, collectSpeed = speed,
--    collectTime = time2, armyIndex = 1, timerId = timerId1 }，
--    resourceAmount = num, territoryId = id
-- } }
---@type table<int, defaultResourceAttrClass>
local resources = {}
---@see resourceId与resourceIndex对应
---@type table<int, int>
local resourceDict = {} -- { [resourceId] = resourceIndex }
---@see 瓦片区域资源点信息
---@type table<int, table<int, boolean>>
local zoneResources = {} -- { [zoneIndex] = { [resourceIndex] = {} } }
---@see 领土资源点信息
---@type table<int, table<int, boolean>>
local territoryResources = {} -- { [territoryId] = { [resourceIndex] = {} } }

---@see 资源点定时器信息
local resourceTimers = {} -- { [time] = { resourceIndexs = { resourceIndex1, resourceIndex2 }, timerId = id1 } }
---@see 重启延迟删除列表
local deleteResources = {}

---@see 资源点刷新
function accept.refreshResources( _isInit, _groupZoneIndexs )
    local refreshZones
    if _isInit then
        -- 重启刷新所有的瓦片
        refreshZones = zoneResources
    else
        -- 定时刷新分组内的瓦片
        refreshZones = _groupZoneIndexs
    end

    -- 刷新瓦片资源点
    local ret, err = xpcall( ResourceLogic.refreshZoneResources, debug.traceback, ResourceLogic, resources, zoneResources, resourceDict, resourceTimers, territoryResources, deleteResources, refreshZones )
    if not ret then
        LOG_ERROR("refreshZoneResources err:%s", err)
    end
    SM.MapObjectRefreshMgr.req.addFinishService( _isInit, Enum.MapObjectRefreshType.RESOURCE )
end

---@see 资源点搜索
function response.searchResource( _rid, _zoneIndex, _resourceTypes )
    -- 找到搜索区域半径范围内的所有瓦片索引
    local radius = CFG.s_Config:Get( "resourceGatherFindRadius" ) * Enum.MapPosMultiple
    local pos = RoleLogic:getRole( _rid, Enum.Role.pos )

    -- 所有满足要求的资源类型ID
    local allResources = {}
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    -- 瓦片区域内的资源点
    for resourceIndex in pairs( zoneResources[_zoneIndex] or {} ) do
        if ( not resources[resourceIndex].collectRid or resources[resourceIndex].collectRid <= 0 )
            and _resourceTypes[resources[resourceIndex].resourceTypeId]
            and MapLogic:checkRadius( pos, resources[resourceIndex].pos, radius ) then
            table.insert( allResources, {
                resourceLevel = sResourceGatherType[resources[resourceIndex].resourceTypeId].level,
                pos = resources[resourceIndex].pos,
                objectId = resourceIndex
            } )
        end
    end

    return allResources
end

---@see 获取资源点信息
function response.getResourceInfo( _resourceIndex, _resourceId )
    if not _resourceIndex then
        _resourceIndex = resourceDict[_resourceId]
    end

    return resources[_resourceIndex]
end

---@see 采集结束
local function collectFinish( _rid, _armyIndex, _resourceIndex, _callBackArgs, _disbandArmy, _isReinforce )
    local resourceInfo = resources[_resourceIndex]
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.pos, Enum.Role.guildId } )
    local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex )

    -- 增加到军队负载信息中
    -- collectNum为资源点实际扣除量
    local collectNum = 0
    local curSpeedTime = os.time() - resourceInfo.collectTime
    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    -- 计算不同采集速度下采集的资源量
    local collectSpeeds = armyInfo.collectResource and armyInfo.collectResource.collectSpeeds or {}
    for _, speedInfo in pairs( collectSpeeds ) do
        collectNum = collectNum + speedInfo.collectSpeed / collectSpeedMultiple * speedInfo.collectTime
        curSpeedTime = curSpeedTime - speedInfo.collectTime
    end
    -- 增加以当前速度采集的资源量
    collectNum = math.floor( collectNum + resourceInfo.collectSpeed / collectSpeedMultiple * curSpeedTime )

    if resourceInfo.resourceAmount < collectNum then
        collectNum = resourceInfo.resourceAmount
    end
    local sResourceGatherType = CFG.s_ResourceGatherType:Get( resourceInfo.resourceTypeId )
    -- 计算军队该资源剩余负载量
    local leftLoad = ResourceLogic:getArmyLoad( _rid, _armyIndex, armyInfo ) - ResourceLogic:getArmyUseLoad( _rid, _armyIndex, armyInfo )
    if leftLoad < 0 then
        leftLoad = 0
    end
    local collectAmount = ResourceLogic:loadToResourceCount( sResourceGatherType.type, leftLoad )
    -- collectAmount为军队实际获得资源量
    if collectAmount > collectNum then
        collectAmount = collectNum
    end

    if not armyInfo.resourceLoads then
        armyInfo.resourceLoads = {}
    end

    if collectAmount > 0 then
        local loadIndex
        for index, loadInfo in pairs( armyInfo.resourceLoads or {} ) do
            -- 如果已有该资源点的采集信息，合并处理
            if loadInfo.resourceId == resourceInfo.resourceId then
                loadIndex = index
                loadInfo.load = loadInfo.load + collectAmount
                break
            end
        end

        local isGuildTerritory, guildId
        if roleInfo.guildId > 0 then
            isGuildTerritory = GuildTerritoryLogic:checkGuildTerritory( _rid, roleInfo.guildId, resourceInfo.pos )
            if isGuildTerritory then
                guildId = roleInfo.guildId
            end
        end
        -- 不存在该资源点的采集信息，新增采集信息
        if not loadIndex then
            table.insert( armyInfo.resourceLoads, {
                resourceTypeId = resourceInfo.resourceTypeId, pos = resourceInfo.pos,
                load = collectAmount, resourceId = resourceInfo.resourceId,
                isGuildTerritory = isGuildTerritory, guildId = guildId
            } )
        else
            armyInfo.resourceLoads[loadIndex].isGuildTerritory = isGuildTerritory
            armyInfo.resourceLoads[loadIndex].guildId = guildId
        end
    end

    local targetType
    local targetObjectIndex
    local fromPos = resourceInfo.pos
    local toPos, toType, targetArmyRadius, isDefeat
    if _callBackArgs then
        -- 角色操作
        toPos = _callBackArgs.targetPos
        targetType = _callBackArgs.targetType
        targetObjectIndex = _callBackArgs.targetObjectIndex
        isDefeat = _callBackArgs.isDefeat
        if targetObjectIndex then
            local objectTypeInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectType(targetObjectIndex)
            toType = objectTypeInfo.objectType
            if toType == Enum.RoleType.ARMY then
                -- 对象是军队
                local targetInfo = MSM.SceneArmyMgr[targetObjectIndex].req.getArmyInfo( targetObjectIndex )
                targetArmyRadius = targetInfo.armyRadius
            elseif toType == Enum.RoleType.MONSTER or toType == Enum.RoleType.GUARD_HOLY_LAND or toType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
                -- 对象是野蛮人
                local targetInfo = MSM.SceneMonsterMgr[targetObjectIndex].req.getMonsterInfo( targetObjectIndex )
                targetArmyRadius = targetInfo.armyRadius
            end
        end
    else
        -- 采集结束回城修正回城坐标
        toPos = roleInfo.pos
        toType = Enum.RoleType.CITY
        targetType = Enum.MapMarchTargetType.RETREAT
        targetObjectIndex = RoleLogic:getRoleCityIndex( _rid )
        armyInfo.targetType = targetType
        armyInfo.targetArg = { targetObjectIndex = targetObjectIndex }
    end

    -- 计算部队半径
    local armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
    -- 增加军队行军状态
    armyInfo.status = ArmyLogic:getArmyStatusByTargetType( targetType )
    -- 清除军队正在采集的资源信息
    armyInfo.collectResource = {}
    -- 更新军队负载信息
    ArmyLogic:setArmy( _rid, _armyIndex, armyInfo )
    -- 通知客户端部队信息
    ArmyLogic:syncArmy( _rid, _armyIndex, armyInfo, true )
    -- 删除定时器
    Timer.delete( resourceInfo.timerId )

    if not _disbandArmy then
        if not _isReinforce then
            -- 行军部队加入地图
            local _, objectIndex = ArmyLogic:armyEnterMap( _rid, _armyIndex, armyInfo, Enum.RoleType.FARMLAND, toType, fromPos, toPos, targetObjectIndex,
                                    targetType, armyRadius, targetArmyRadius, nil, nil, isDefeat )
            -- 通知资源点部队离开了
            MSM.SceneResourceMgr[_resourceIndex].post.armyLeaveResource( _resourceIndex, objectIndex, isDefeat )
        end
    else
        BattleCreate:exitBattle( _resourceIndex, true )
    end

    -- 资源点处理
    local deleteTime = resourceInfo.refreshTime + sResourceGatherType.timeLimit
    if resourceInfo.resourceAmount <= collectNum or deleteTime <= os.time() then
        -- 资源点被采集完,或者资源点已超时,移除资源点
        local objectType = ResourceLogic:resourceTypeToObjectType( sResourceGatherType.type )
        if Common.getMapObjectLoadFinish() then
            MSM.MapObjectMgr[_resourceIndex].req.resourceLeave( resourceInfo.resourceId, _resourceIndex, resourceInfo.pos, objectType )
        else
            deleteResources[_resourceIndex] = { objectId = resourceInfo.resourceId, pos = resourceInfo.pos, objectType = objectType }
        end
        -- 删除资源点信息
        if zoneResources[resourceInfo.zoneIndex] then
            zoneResources[resourceInfo.zoneIndex][_resourceIndex] = nil
        end
        local territoryId = resourceInfo.territoryId
        if territoryId and territoryResources[territoryId] and territoryResources[territoryId][_resourceIndex] then
            territoryResources[territoryId][_resourceIndex] = nil
            if table.empty( territoryResources[territoryId] ) then
                territoryResources[territoryId] = nil
            end
        end
        -- 删除资源点超时定时器中的资源点索引信息
        if resourceTimers[deleteTime] and resourceTimers[deleteTime].resourceIndexs and resourceTimers[deleteTime].resourceIndexs[_resourceIndex] then
            resourceTimers[deleteTime].resourceIndexs[_resourceIndex] = nil
            if table.empty( resourceTimers[deleteTime].resourceIndexs ) then
                Timer.delete( resourceTimers[deleteTime].timerId or 0 )
                resourceTimers[deleteTime] = nil
            end
        end
        resources[_resourceIndex] = nil
        resourceDict[resourceInfo.resourceId] = nil
    else
        -- 资源点未采集完, 更新资源点信息
        resources[_resourceIndex].collectRid = nil
        resources[_resourceIndex].collectTime = nil
        resources[_resourceIndex].collectSpeed = nil
        resources[_resourceIndex].armyIndex = nil
        resources[_resourceIndex].resourceAmount = resourceInfo.resourceAmount - collectAmount
        Timer.delete( resources[_resourceIndex].timerId )
        resources[_resourceIndex].timerId = nil
        -- 更新地图资源对象信息
        MSM.MapObjectMgr[_resourceIndex].req.resourceUpdate( resourceInfo.resourceId, _resourceIndex, resourceInfo.resourceAmount, 0, 0, 0, 0, "", {}, "", 0, 0, isDefeat )
    end
end

---@see 角色开始采集
function response.collectResource( _rid, _armyIndex, _resourceIndex )
    local armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
    if resources[_resourceIndex] and ( not resources[_resourceIndex].collectRid or resources[_resourceIndex].collectRid <= 0 ) then
        local nowTime = os.time()
        resources[_resourceIndex].collectRid = _rid
        resources[_resourceIndex].collectTime = nowTime
        resources[_resourceIndex].armyIndex = _armyIndex
        -- 根据军队索引计算采集速度
        local collectSpeed = ResourceLogic:getArmyCollectSpeed( _rid, _armyIndex, _resourceIndex )
        resources[_resourceIndex].collectSpeed = collectSpeed
        -- 删除地图上的对象
        MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, armyObjectIndex, { x = -1, y = -1 } )
        -- 更新地图资源对象信息
        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.name, Enum.Role.level } )
        local guildAbbName
        if roleInfo.guildId > 0 then
            guildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
        end
        MSM.MapObjectMgr[_resourceIndex].req.resourceUpdate( resources[_resourceIndex].resourceId, _resourceIndex,
                    resources[_resourceIndex].resourceAmount, nowTime, _rid, collectSpeed, _armyIndex,
                    roleInfo.name, {}, guildAbbName, roleInfo.guildId, roleInfo.level )
        -- 移除军队索引信息
        MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, _armyIndex )
        local sResourceGatherType = CFG.s_ResourceGatherType:Get( resources[_resourceIndex].resourceTypeId )
        -- 计算军队该资源剩余负载量
        local leftLoad = ResourceLogic:getArmyLoad( _rid, _armyIndex ) - ResourceLogic:getArmyUseLoad( _rid, _armyIndex )
        local collectAmount = ResourceLogic:loadToResourceCount( sResourceGatherType.type, leftLoad )
        -- 取min(资源点剩余量, 可采集携带量)
        if resources[_resourceIndex].resourceAmount < collectAmount then
            collectAmount = resources[_resourceIndex].resourceAmount
        end
        -- 添加采集结束定时器
        local endTime = math.ceil( collectAmount * Enum.ResourceCollectSpeedMultiple / collectSpeed ) + nowTime
        -- 更新角色信息
        local armyResource = {
            resourceTypeId = resources[_resourceIndex].resourceTypeId, pos = resources[_resourceIndex].pos,
            resourceId = resources[_resourceIndex].resourceId, startTime = nowTime, endTime = endTime,
            resourceSum = resources[_resourceIndex].resourceAmount, collectSpeeds = {},
            collectSpeed = collectSpeed
        }
        local armyChanges = {}
        armyChanges.collectResource = armyResource
        armyChanges.status = Enum.ArmyStatus.COLLECTING
        local targetArg = ArmyLogic:getArmy( _rid, _armyIndex, Enum.Army.targetArg ) or {}
        targetArg.pos = resources[_resourceIndex].pos
        targetArg.targetObjectIndex = _resourceIndex
        armyChanges.targetArg = targetArg
        -- 更新军队资源信息
        ArmyLogic:setArmy( _rid, _armyIndex, armyChanges )
        -- 通知客户端
        ArmyLogic:syncArmy( _rid, _armyIndex, armyChanges, true )
        -- 添加定时器
        resources[_resourceIndex].timerId = Timer.runAt( endTime, collectFinish, _rid, _armyIndex, _resourceIndex )
        return true
    else
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        -- 更新部队行军目标
        ArmyLogic:updateArmyInfo( _rid, _armyIndex, {
            targetArg = { targetObjectIndex = cityIndex },
            targetType = Enum.MapMarchTargetType.RETREAT,
        }, true )
        -- 军队移动
        MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, cityIndex, nil, Enum.ArmyStatus.RETREAT_MARCH )
    end
end

---@see 玩家召回结束采集
function response.callBackArmy( _rid, _armyIndex, _callBackArgs, _disbandArmy, _isReinforce )
    local resourceId
    local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex ) or {}
    if armyInfo.collectResource then
        resourceId = armyInfo.collectResource.resourceId
    end
    if not resourceId then return end
    -- 结束采集
    collectFinish( _rid, _armyIndex, resourceDict[resourceId], _callBackArgs, _disbandArmy, _isReinforce )

    return true
end

---@see 军队负载变化处理.战斗重伤轻伤或者统帅负载技能天赋变化等
function response.armyLoadChange( _rid, _armyIndex, _objectIndex )
    local armyIndexs
    if _armyIndex then
        armyIndexs = {}
        armyIndexs[_armyIndex] = true
    end
    local nowTime = os.time()
    local resourceIndex, resourceInfo, armyInfo, leftLoad, collectAmount, alreadyCollect, resourceId, useTime
    if _objectIndex then
        resourceInfo = resources[_objectIndex]
        if resourceInfo and resourceInfo.collectRid and resourceInfo.collectRid > 0 then
            _rid = resourceInfo.collectRid
            armyIndexs = {}
            armyIndexs[resourceInfo.armyIndex] = true
        end
    end

    if not _rid then
        -- 说明没有部队在里面采集了,一般发生在被攻击,又召回时
        return
    end

    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    local allArmy = ArmyLogic:getArmy( _rid ) or {}
    for armyIndex in pairs( armyIndexs or {} ) do
        armyInfo = allArmy[armyIndex]
        if armyInfo and ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            if _objectIndex then
                resourceIndex = _objectIndex
                resourceInfo = resources[resourceIndex]
                resourceId = resourceInfo.resourceId
            else
                resourceId = armyInfo.collectResource.resourceId
                resourceIndex = resourceDict[resourceId]
                resourceInfo = resources[resourceIndex]
            end
            -- 部队剩余负载
            leftLoad = ResourceLogic:getArmyLoad( _rid, armyIndex, armyInfo ) - ResourceLogic:getArmyUseLoad( _rid, armyIndex, armyInfo )
            -- 负载转资源携带量
            collectAmount = ResourceLogic:loadToResourceCount( sResourceGatherType[resourceInfo.resourceTypeId].type, leftLoad )
            -- 删除已经采集的量
            useTime = 0
            for _, speedInfo in pairs( armyInfo.collectResource.collectSpeeds or {} ) do
                collectAmount = collectAmount - speedInfo.collectSpeed * speedInfo.collectTime / collectSpeedMultiple
                useTime = useTime + speedInfo.collectTime
            end
            -- 取min(资源点剩余量, 可采集携带量)
            if resourceInfo.resourceAmount < collectAmount then
                collectAmount = resourceInfo.resourceAmount
            end

            alreadyCollect = ( nowTime - resourceInfo.collectTime - useTime ) * resourceInfo.collectSpeed / collectSpeedMultiple
            if alreadyCollect >= collectAmount then
                -- 当前已经采集量超过可携带量，结束采集
                collectFinish( _rid, armyIndex, resourceIndex )
            else
                -- 删除旧定时器
                Timer.delete( resourceInfo.timerId )
                -- 计算还可采集资源量和采集时间，增加定时器
                local needTime = math.ceil( ( collectAmount - alreadyCollect ) * collectSpeedMultiple / resourceInfo.collectSpeed )
                resources[resourceIndex].timerId = Timer.runAfter( needTime * 100, collectFinish, _rid, armyIndex, resourceIndex )
                armyInfo.collectResource.endTime = nowTime + needTime
                -- 更新部队信息
                ArmyLogic:setArmy( _rid, armyIndex, { [Enum.Army.collectResource] = armyInfo.collectResource } )
                -- 通知客户端
                ArmyLogic:syncArmy( _rid, armyIndex, { [Enum.Army.collectResource] = armyInfo.collectResource }, true )
                -- 更新地图资源对象信息
                MSM.MapObjectMgr[resourceId].req.resourceUpdate( resourceId, resourceIndex,
                            resourceInfo.resourceAmount, resourceInfo.collectTime, _rid, resourceInfo.collectSpeed, armyIndex )
            end
        end
    end
end

---@see 军队采集速度变化处理.科技统帅VIP等级或者文明切换变化
function response.collectSpeedChange( _rid, _armyIndex )
    local nowTime = os.time()
    local resourceIndex, collectSpeed, useTime, resourceInfo, oldCollectSpeed, allArmy
    local alreadyCollect, leftLoad, collectAmount, resourceId
    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    if _armyIndex then
        allArmy = {}
        allArmy[_armyIndex] = ArmyLogic:getArmy( _rid, _armyIndex ) or {}
        if table.empty( allArmy[_armyIndex] ) then
            allArmy[_armyIndex] = nil
        end
    else
        allArmy = ArmyLogic:getArmy( _rid ) or {}
    end
    local armySyncInfo = {}
    for armyIndex, armyInfo in pairs( allArmy ) do
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            resourceId = armyInfo.collectResource.resourceId
            resourceIndex = resourceDict[resourceId]
            resourceInfo = resources[resourceIndex]
            oldCollectSpeed = resourceInfo.collectSpeed
            -- 当前的采集速度
            collectSpeed = ResourceLogic:getArmyCollectSpeed( _rid, armyIndex, resourceIndex )
            if resourceInfo.collectSpeed ~= collectSpeed then
                -- 删除旧定时器
                Timer.delete( resourceInfo.timerId )
                -- 采集速度变化
                resources[resourceIndex].collectSpeed = collectSpeed
                if not armyInfo.collectResource.collectSpeeds then
                    armyInfo.collectResource.collectSpeeds = {}
                end
                -- 已经采集时间
                useTime = 0
                alreadyCollect = 0
                for _, speedInfo in pairs( armyInfo.collectResource.collectSpeeds ) do
                    useTime = useTime + speedInfo.collectTime
                    alreadyCollect = alreadyCollect + speedInfo.collectSpeed * speedInfo.collectTime / collectSpeedMultiple
                end
                -- 上一次的采集速度持续时间多于1秒
                if resourceInfo.collectTime + useTime < nowTime then
                    local olcCollectTime = nowTime - resourceInfo.collectTime - useTime
                    table.insert( armyInfo.collectResource.collectSpeeds, {
                        collectSpeed = oldCollectSpeed,
                        collectTime = olcCollectTime
                    } )
                    alreadyCollect = alreadyCollect + olcCollectTime * oldCollectSpeed / collectSpeedMultiple
                end
                -- 采集速度修改
                armyInfo.collectResource.collectSpeed = collectSpeed
                -- 部队剩余负载
                leftLoad = ResourceLogic:getArmyLoad( _rid, armyIndex, armyInfo ) - ResourceLogic:getArmyUseLoad( _rid, armyIndex, armyInfo )
                -- 剩余负载转化为该资源的携带量
                collectAmount = ResourceLogic:loadToResourceCount( sResourceGatherType[resourceInfo.resourceTypeId].type, leftLoad )
                if collectAmount > resourceInfo.resourceAmount then
                    collectAmount = resourceInfo.resourceAmount
                end
                -- 计算还可采集资源量和采集时间，增加定时器
                local needTime = math.ceil( ( collectAmount - alreadyCollect ) * collectSpeedMultiple / collectSpeed )
                -- 更新地图资源对象信息
                MSM.MapObjectMgr[resourceId].req.resourceUpdate( resourceId, resourceIndex, resourceInfo.resourceAmount,
                            resourceInfo.collectTime, _rid, collectSpeed, armyIndex, nil, armyInfo.collectResource.collectSpeeds )
                armyInfo.collectResource.endTime = nowTime + needTime
                -- 更新部队信息
                ArmyLogic:setArmy( _rid, armyIndex, armyInfo )
                -- 增加新的采集结束定时器
                resources[resourceIndex].timerId = Timer.runAfter( needTime * 100, collectFinish, _rid, armyIndex, resourceIndex )
                armySyncInfo[armyIndex] = {
                    armyIndex = armyIndex, collectResource = armyInfo.collectResource
                }
            end
        end
    end
    -- 通知客户端
    if not table.empty( armySyncInfo ) then
        ArmyLogic:syncArmy( _rid, nil, armySyncInfo, true )
    end
end

---@see 服务器重启增加资源点信息
function response.addResourceInfo( _resourceId, _resouceIndex, _resourceInfo )
    local zoneIndex = MapLogic:getZoneIndexByPos( _resourceInfo.objectPos )
    local territoryId = GuildTerritoryLogic:getPosTerritoryId( _resourceInfo.objectPos )
    -- 更新资源点信息
    resources[_resouceIndex] = {
        resourceId = _resourceId, zoneIndex = zoneIndex, resourceTypeId = _resourceInfo.resourceId,
        refreshTime = _resourceInfo.refreshTime, pos = _resourceInfo.objectPos, collectRid = _resourceInfo.collectRid,
        collectSpeed = _resourceInfo.collectSpeed, collectTime = _resourceInfo.collectTime,
        resourceAmount = _resourceInfo.resourceAmount, armyIndex = _resourceInfo.armyIndex,
        territoryId = territoryId
    }
    resourceDict[_resourceId] = _resouceIndex
    -- 更新区域资源点信息
    if not zoneResources[zoneIndex] then
        zoneResources[zoneIndex] = {}
    end
    zoneResources[zoneIndex][_resouceIndex] = true
    -- 增加领地ID包含的资源对象ID
    if not territoryResources[territoryId] then
        territoryResources[territoryId] = {}
        territoryResources[territoryId][_resouceIndex] = true
    else
        territoryResources[territoryId][_resouceIndex] = true
    end
    -- 更新定时器信息
    local sResourceGatherType = CFG.s_ResourceGatherType:Get( _resourceInfo.resourceId )
    -- 添加资源点过期定时器
    local endTime = _resourceInfo.refreshTime + sResourceGatherType.timeLimit
    if resourceTimers[endTime] then
        -- 定时器已存在
        resourceTimers[endTime].resourceIndexs[_resouceIndex] = true
    else
        -- 定时器不存在
        resourceTimers[endTime] = {}
        resourceTimers[endTime].resourceIndexs = {}
        resourceTimers[endTime].resourceIndexs[_resouceIndex] = true
        resourceTimers[endTime].timerId = Timer.runAt( endTime, ResourceLogic.resourceTimeOut, ResourceLogic, resources,
                                            resourceDict, zoneResources, resourceTimers, territoryResources, endTime, deleteResources )
    end
    if _resourceInfo.collectRid and _resourceInfo.collectRid > 0 then
        -- 更新部队采集对象索引
        ArmyLogic:setArmy( _resourceInfo.collectRid, _resourceInfo.armyIndex, {
            [Enum.Army.targetArg] = { targetObjectIndex = _resouceIndex, pos = _resourceInfo.objectPos }
        } )
        -- 资源点正在被采集, 重置定时器
        snax.self().req.armyLoadChange( _resourceInfo.collectRid, _resourceInfo.armyIndex, _resouceIndex, true )
    end
end

---@see 检查坐标范围内是否有资源点
function response.checkPosResource( _pos, _redius, _zoneIndexs )
    local resourceTypeId
    local sResources = CFG.s_ResourceGatherType:Get()
    local posMultiple = Enum.MapPosMultiple

    for _, zoneIndex in pairs( _zoneIndexs or {} ) do
        for resourceIndex in pairs( zoneResources[zoneIndex] or {} ) do
            resourceTypeId = resources[resourceIndex] and resources[resourceIndex].resourceTypeId or nil
            if resourceTypeId and sResources[resourceTypeId] then
                if MapLogic:checkRadius( _pos, resources[resourceIndex].pos, _redius + sResources[resourceTypeId].radius * posMultiple ) then
                    return true
                end
            end
        end
    end

    return false
end

---@see 获取资源点的坐标
function response.getAllResourcePos()
    local pos = {}
    for _, resourceInfo in pairs(resources) do
        table.insert( pos, resourceInfo.pos )
    end
    return pos
end

---@see 联盟建筑拆除和建造成功影响角色采集速度
function accept.territoryStatusChange( _territories )
    local resourceInfo
    -- 建筑变化影响的领地
    for _, territoryId in pairs( _territories or {} ) do
        -- 在该领地范围内的资源点信息
        for resourceIndex in pairs( territoryResources[territoryId] or {} ) do
            resourceInfo = resources[resourceIndex] or {}
            -- 采集中的部队
            if resourceInfo.collectRid then
                -- 部队采集速度发生变化
                snax.self().req.collectSpeedChange( resourceInfo.collectRid, resourceInfo.armyIndex )
            end
        end
    end
end

---@see 联盟建筑建造完成拆除和修改联盟简称
function accept.guildAbbNameChange( _territories, _newGuildAbbName )
    -- 建筑变化影响的领地
    for _, territoryId in pairs( _territories or {} ) do
        -- 在该领地范围内的资源点信息
        for resourceIndex in pairs( territoryResources[territoryId] or {} ) do
            -- 更新资源点所属联盟简称
            MSM.SceneResourceMgr[resourceIndex].post.updateResourceInfo( resourceIndex, { resourceGuildAbbName = _newGuildAbbName } )
        end
    end
end

---@see 初始化服务瓦片信息
function response.InitZoneIndex( _zoneIndexs )
    -- 服务瓦片索引初始化
    for _, zoneIndex in pairs( _zoneIndexs ) do
        if not zoneResources[zoneIndex] then
            zoneResources[zoneIndex] = {}
        end
    end
end

---@see 添加资源点
function response.addResource( _resourceId, _pos )
    local zoneIndex = MapLogic:getZoneIndexByPos( _pos )
    local sResourceGatherType = CFG.s_ResourceGatherType:Get( _resourceId )
    if sResourceGatherType and not table.empty( sResourceGatherType ) then
        ResourceLogic:addResource( resources, resourceDict, zoneResources, resourceTimers,
                    territoryResources, sResourceGatherType, _pos, os.time(), zoneIndex, deleteResources )
    end
end

---@see 重启延迟删除
function accept.deleteObjectOnReboot()
    for objectIndex, resourceInfo in pairs( deleteResources ) do
        MSM.MapObjectMgr[objectIndex].req.resourceLeave( resourceInfo.objectId, objectIndex, resourceInfo.pos, resourceInfo.objectType )
    end
    deleteResources = {}
end

---@see PMLogic获取瓦片对象数量
function response.getZoneObjectNum( _zoneIndex )
    if _zoneIndex then
        return { [_zoneIndex] = table.size( zoneResources[_zoneIndex] or {} ) }
    else
        local zoneObjectNum = {}
        for zoneIndex, objects in pairs( zoneResources ) do
            zoneObjectNum[zoneIndex] = table.size( objects )
        end

        return zoneObjectNum
    end
end