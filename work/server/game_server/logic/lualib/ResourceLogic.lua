--[[
* @file : ResourceLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri Jan 03 2020 15:00:24 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 资源相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local ArmyLogic = require "ArmyLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local MapObjectLogic = require "MapObjectLogic"
local HeroLogic = require "HeroLogic"
local MapLogic = require "MapLogic"
local Timer = require "Timer"
local skynet = require "skynet"
local Random = require "Random"

local ResourceLogic = {}

---@see 资源类型转换为地图对象类型
function ResourceLogic:resourceTypeToObjectType( _resourceType )
    if _resourceType == Enum.ResourceType.FARMLAND then
        -- 农田
        return Enum.RoleType.FARMLAND
    elseif _resourceType == Enum.ResourceType.WOOD then
        -- 伐木场
        return Enum.RoleType.WOOD
    elseif _resourceType == Enum.ResourceType.STONE then
        -- 石矿场
        return Enum.RoleType.STONE
    elseif _resourceType == Enum.ResourceType.GOLD then
        -- 金矿场
        return Enum.RoleType.GOLD
    elseif _resourceType == Enum.ResourceType.DENAR then
        -- 宝石矿场
        return Enum.RoleType.DENAR
    elseif _resourceType == Enum.ResourceType.VILLAGE then
        -- 村庄
        return Enum.RoleType.VILLAGE
    elseif _resourceType == Enum.ResourceType.CAVE then
        -- 山洞
        return Enum.RoleType.CAVE
    end
end

---@see 计算军队负载
function ResourceLogic:getArmyLoad( _rid, _armyIndex, _armyInfo )
    -- 计算军队负载
    local load = 0
    -- 统帅负载加成
    local heroSpaceMulti = 0
    local troopsSpaceMulti = RoleLogic:getRole( _rid, Enum.Role.troopsSpaceMulti )
    local armyInfo = _armyInfo or ArmyLogic:getArmy( _rid, _armyIndex ) or {}
    if armyInfo.mainHeroId and armyInfo.mainHeroId > 0 then
        heroSpaceMulti = heroSpaceMulti + HeroLogic:getHeroAttr( _rid, armyInfo.mainHeroId, Enum.Role.troopsSpaceMulti )
    end
    if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
        heroSpaceMulti = heroSpaceMulti + HeroLogic:getHeroAttr( _rid, armyInfo.deputyHeroId, Enum.Role.troopsSpaceMulti, true )
    end
    -- 计算各兵种负载之和
    local sArms
    for _, soldier in pairs( armyInfo.soldiers or {} ) do
        sArms = CFG.s_Arms:Get( soldier.id )
        load = load + ( sArms.capacity or 1 ) * soldier.num
    end
    -- 增加加成系数
    load = math.floor( load * ( 1000 + ( troopsSpaceMulti or 0 ) + heroSpaceMulti ) / 1000 )

    return load
end

---@see 计算军队已经使用的负载空间
function ResourceLogic:getArmyUseLoad( _rid, _armyIndex, _armyInfo )
    local useLoad = 0
    local armyInfo = _armyInfo or ArmyLogic:getArmy( _rid, _armyIndex ) or {}
    if table.empty( armyInfo ) then return useLoad end

    local GuildBuildLogic = require "GuildBuildLogic"

    local resourceType
    local sConfig = CFG.s_Config:Get()
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    for _, loadInfo in pairs( armyInfo.resourceLoads or {} ) do
        if loadInfo.guildBuildType and loadInfo.guildBuildType > 0 then
            resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( loadInfo.guildBuildType )
        else
            resourceType = sResourceGatherType[loadInfo.resourceTypeId] and sResourceGatherType[loadInfo.resourceTypeId].type or 0
        end

        if resourceType == Enum.ResourceType.FARMLAND then
            -- 农田负载量
            useLoad = useLoad + loadInfo.load * sConfig.foodRaito
        elseif resourceType == Enum.ResourceType.WOOD then
            -- 木材负载量
            useLoad = useLoad + loadInfo.load * sConfig.woodRaito
        elseif resourceType == Enum.ResourceType.STONE then
            -- 石料负载量
            useLoad = useLoad + loadInfo.load * sConfig.stoneRaito
        elseif resourceType == Enum.ResourceType.GOLD then
            -- 金矿负载量
            useLoad = useLoad + loadInfo.load * sConfig.goldRaito
        elseif resourceType == Enum.ResourceType.DENAR then
            -- 宝石负载量
            useLoad = useLoad + loadInfo.load * sConfig.diamonRaito
        end
    end

    return useLoad
end

---@see 计算部队剩余负载
function ResourceLogic:getArmyLeftLoad( _rid, _armyIndex, _armyInfo )
    return self:getArmyLoad( _rid, _armyIndex, _armyInfo ) - self:getArmyUseLoad( _rid, _armyIndex, _armyInfo )
end

---@see 负载转换为对应的资源携带量
function ResourceLogic:loadToResourceCount( _resourceType, _load )
    local resourceCount = 0
    local sConfig = CFG.s_Config:Get()
    if _resourceType == Enum.ResourceType.FARMLAND then
        -- 农田负载量
        resourceCount = math.floor( _load / sConfig.foodRaito )
    elseif _resourceType == Enum.ResourceType.WOOD then
        -- 木材负载量
        resourceCount = math.floor( _load / sConfig.woodRaito )
    elseif _resourceType == Enum.ResourceType.STONE then
        -- 石料负载量
        resourceCount = math.floor( _load / sConfig.stoneRaito )
    elseif _resourceType == Enum.ResourceType.GOLD then
        -- 金矿负载量
        resourceCount = math.floor( _load / sConfig.goldRaito )
    elseif _resourceType == Enum.ResourceType.DENAR then
        -- 宝石负载量
        resourceCount = math.floor( _load / sConfig.diamonRaito )
    end

    return resourceCount
end

---@see 计算部队采集的负载
function ResourceLogic:getArmyCollectLoad( _collectResource )
    if not _collectResource or not _collectResource.collectNum then return end
    local GuildBuildLogic = require "GuildBuildLogic"
    local resourceType
    if _collectResource.guildBuildType and _collectResource.guildBuildType > 0 then
        resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( _collectResource.guildBuildType )
    elseif _collectResource.resourceTypeId then
        resourceType = CFG.s_ResourceGatherType:Get( _collectResource.resourceTypeId, "type" ) or 0
    end

    if resourceType then
        local load = 0
        if resourceType == Enum.ResourceType.FARMLAND then
            -- 农田负载量
            load = _collectResource.collectNum * CFG.s_Config:Get( "foodRaito" )
        elseif resourceType == Enum.ResourceType.WOOD then
            -- 木材负载量
            load = _collectResource.collectNum * CFG.s_Config:Get( "woodRaito" )
        elseif resourceType == Enum.ResourceType.STONE then
            -- 石料负载量
            load = _collectResource.collectNum * CFG.s_Config:Get( "stoneRaito" )
        elseif resourceType == Enum.ResourceType.GOLD then
            -- 金矿负载量
            load = _collectResource.collectNum * CFG.s_Config:Get( "goldRaito" )
        elseif resourceType == Enum.ResourceType.DENAR then
            -- 宝石负载量
            load = _collectResource.collectNum * CFG.s_Config:Get( "diamonRaito" )
        end

        return load
    end
end

---@see 资源采集
---@param _armyIndex integer 部队索引
---@param _resourceIndex integer 资源地图对象索引
function ResourceLogic:resourceCollect( _rid, _armyIndex, _resourceIndex )
    -- 资源点是否存在
    local mapResourceInfo = MSM.SceneResourceMgr[_resourceIndex].req.getResourceInfo( _resourceIndex )
    if not mapResourceInfo or table.empty( mapResourceInfo ) then
        LOG_ERROR("rid(%d) resourceCollect, resourceIndex(%d) not exist", _rid, _resourceIndex)
        return false
    end

    local sResourceGatherType = CFG.s_ResourceGatherType:Get( mapResourceInfo.resourceId )
    -- 角色科技研究是否满足
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.technologies } )
    if sResourceGatherType.scienceReq and sResourceGatherType.scienceReq > 0
        and not roleInfo.technologies[sResourceGatherType.scienceReq] then
        LOG_ERROR("rid(%d) resourceCollect, not study technology(%d)", _rid, sResourceGatherType.scienceReq)
        return false
    end

    -- 军队是否还有负载空间, 无则返回城市行军处理
    local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex )
    local leftLoad = self:getArmyLoad( _rid, _armyIndex, armyInfo ) - self:getArmyUseLoad( _rid, _armyIndex, armyInfo )
    if self:loadToResourceCount( sResourceGatherType.type, leftLoad ) < 1 or mapResourceInfo.collectRid and mapResourceInfo.collectRid > 0 then
        LOG_ERROR("rid(%d) resourceCollect, armyIndex(%d) load full or resouce was collected", _rid, _armyIndex)
        -- 返回城市行军处理
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        local armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
        if cityIndex and armyObjectIndex then
            -- 更新部队行军目标
            ArmyLogic:updateArmyInfo( _rid, _armyIndex, {
                targetArg = { targetObjectIndex = cityIndex },
                targetType = Enum.MapMarchTargetType.RETREAT,
            }, true )
            -- 部队移动
            MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, cityIndex, nil, Enum.ArmyStatus.RETREAT_MARCH )
        end

        return false
    end

    -- 开始采集资源
    local serviceIndex = MapLogic:getObjectService( mapResourceInfo.pos )
    return MSM.ResourceMgr[serviceIndex].req.collectResource( _rid, _armyIndex, _resourceIndex )
end

---@see 计算角色军队采集速度
function ResourceLogic:getArmyCollectSpeed( _rid, _armyIndex, _resourceIndex )
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.getFoodSpeedMulti, Enum.Role.getWoodSpeedMulti, Enum.Role.getStoneSpeedMulti,
        Enum.Role.getGlodSpeedMulti, Enum.Role.getDiamondSpeedMulti, Enum.Role.guildId
    } )
    local mapResourceInfo = MSM.SceneResourceMgr[_resourceIndex].req.getResourceInfo( _resourceIndex )
    local sResourceGatherType = CFG.s_ResourceGatherType:Get( mapResourceInfo.resourceId )
    -- 采集基础速度
    local speedMuti = 0
    local attrName
    -- 增加该种类资源的采集速度加成
    if sResourceGatherType.type == Enum.ResourceType.FARMLAND then
        -- 农田
        speedMuti = speedMuti + ( roleInfo.getFoodSpeedMulti or 0 )
        attrName = Enum.Role.getFoodSpeedMulti
    elseif sResourceGatherType.type == Enum.ResourceType.WOOD then
        -- 木材
        speedMuti = speedMuti + ( roleInfo.getWoodSpeedMulti or 0 )
        attrName = Enum.Role.getWoodSpeedMulti
    elseif sResourceGatherType.type == Enum.ResourceType.STONE then
        -- 石料
        speedMuti = speedMuti + ( roleInfo.getStoneSpeedMulti or 0 )
        attrName = Enum.Role.getStoneSpeedMulti
    elseif sResourceGatherType.type == Enum.ResourceType.GOLD then
        -- 金币
        speedMuti = speedMuti + ( roleInfo.getGlodSpeedMulti or 0 )
        attrName = Enum.Role.getGlodSpeedMulti
    elseif sResourceGatherType.type == Enum.ResourceType.DENAR then
        -- 宝石
        speedMuti = speedMuti + ( roleInfo.getDiamondSpeedMulti or 0 )
        attrName = Enum.Role.getDiamondSpeedMulti
    end
    -- 增加军队统帅和副统帅采集速度加成
    local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex ) or {}
    if armyInfo.mainHeroId and armyInfo.mainHeroId > 0 then
        speedMuti = speedMuti + HeroLogic:getHeroAttr( _rid, armyInfo.mainHeroId, attrName )
    end
    if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
        speedMuti = speedMuti + HeroLogic:getHeroAttr( _rid, armyInfo.deputyHeroId, attrName, true )
    end
    -- 增加本联盟领土采集速度加成
    if GuildTerritoryLogic:checkGuildTerritory( _rid, roleInfo.guildId, mapResourceInfo.pos ) then
        speedMuti = speedMuti + ( CFG.s_Config:Get( "allianceResourceGatherAdd" ) or 0 )
    end

    -- 采集速度转换为秒级放大10000倍向下取整
    return math.floor( sResourceGatherType.collectSpeed / 3600 * ( 1000 + speedMuti ) / 1000 * Enum.ResourceCollectSpeedMultiple )
end

---@see 计算角色军队采集速度
function ResourceLogic:getArmyCollectSpeedOnGuildResource( _rid, _armyIndex, _armyInfo, _buildType, _resourcePos )
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.getFoodSpeedMulti, Enum.Role.getWoodSpeedMulti, Enum.Role.getStoneSpeedMulti,
        Enum.Role.getGlodSpeedMulti, Enum.Role.getDiamondSpeedMulti, Enum.Role.guildId
    } )

    -- 采集基础速度
    local collectSpeed, attrName
    -- 采集加成
    local speedMuti = 0
    local sBuildingType = CFG.s_AllianceBuildingType:Get( _buildType )
    collectSpeed = sBuildingType.collectSpeed

    if _buildType == Enum.GuildBuildType.FOOD_CENTER then
        -- 联盟谷仓
        speedMuti = speedMuti + ( roleInfo.getFoodSpeedMulti or 0 )
        attrName = Enum.Role.getFoodSpeedMulti
    elseif _buildType == Enum.GuildBuildType.WOOD_CENTER then
        -- 联盟木料场
        speedMuti = speedMuti + ( roleInfo.getWoodSpeedMulti or 0 )
        attrName = Enum.Role.getWoodSpeedMulti
    elseif _buildType == Enum.GuildBuildType.STONE_CENTER then
        -- 联盟石材厂
        speedMuti = speedMuti + ( roleInfo.getStoneSpeedMulti or 0 )
        attrName = Enum.Role.getStoneSpeedMulti
    elseif _buildType == Enum.GuildBuildType.GOLD_CENTER then
        -- 联盟铸币场
        speedMuti = speedMuti + ( roleInfo.getGlodSpeedMulti or 0 )
        attrName = Enum.Role.getGlodSpeedMulti
    end

    -- 增加军队统帅和副统帅采集速度加成
    local armyInfo = _armyInfo or ArmyLogic:getArmy( _rid, _armyIndex ) or {}
    if armyInfo.mainHeroId and armyInfo.mainHeroId > 0 then
        speedMuti = speedMuti + HeroLogic:getHeroAttr( _rid, armyInfo.mainHeroId, attrName )
    end
    if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
        speedMuti = speedMuti + HeroLogic:getHeroAttr( _rid, armyInfo.deputyHeroId, attrName, true )
    end

    -- 增加本联盟领土采集速度加成
    if GuildTerritoryLogic:checkGuildTerritory( _rid, roleInfo.guildId, _resourcePos ) then
        speedMuti = speedMuti + ( CFG.s_Config:Get( "allianceResourceGatherAdd" ) or 0 )
    end

    -- 采集速度转换为秒级放大10000倍向下取整
    return math.floor( collectSpeed / 3600 * ( 1000 + speedMuti ) / 1000 * Enum.ResourceCollectSpeedMultiple )
end

---@see 角色部队采集速度变化
function ResourceLogic:roleArmyCollectSpeedChange( _rid, _armyIndex )
    local allArmy
    if not _armyIndex then
        allArmy = ArmyLogic:getArmy( _rid, _armyIndex )
    else
        allArmy = {}
        allArmy[_armyIndex] = ArmyLogic:getArmy( _rid, _armyIndex )
    end

    local targetObjectIndex, targetInfo, serviceIndex
    for armyIndex, armyInfo in pairs( allArmy ) do
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            -- 部队在采集中
            targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex
            if targetObjectIndex then
                -- 目标对象类型
                targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
                if MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
                    -- 野外资源点
                    serviceIndex = MapLogic:getObjectService( targetInfo.pos )
                    MSM.ResourceMgr[serviceIndex].req.collectSpeedChange( _rid, armyIndex )
                else
                    -- 联盟资源中心
                    if targetInfo.guildId then
                        MSM.GuildMgr[targetInfo.guildId].post.roleArmyCollectSpeedChange( targetInfo.guildId, targetInfo.buildIndex, _rid )
                    end
                end
            end
        end
    end
end

---@see 角色负载变化更新部队信息
function ResourceLogic:checkResourceArmyOnLoadChange( _rid )
    local targetObjectIndex, targetInfo, serviceIndex
    local allArmys = ArmyLogic:getArmy( _rid )
    for armyIndex, armyInfo in pairs( allArmys ) do
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex
            if targetObjectIndex then
                -- 目标对象类型
                targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
                if MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
                    -- 野外资源点
                    serviceIndex = MapLogic:getObjectService( targetInfo.pos )
                    MSM.ResourceMgr[serviceIndex].req.collectSpeedChange( _rid, armyIndex )
                elseif MapObjectLogic:checkIsGuildResourceCenterObject( targetInfo.objectType ) then
                    -- 联盟资源中心
                    MSM.GuildMgr[targetInfo.guildId].post.roleArmyCollectSpeedChange( targetInfo.guildId, targetInfo.buildIndex, _rid )
                end
            end
        end
    end
end

---@see 资源所属联盟简称变化
function ResourceLogic:resourceGuildAbbNameChange( _territoryIds, _guildAbbName )
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        -- 刷新该服务的资源点
        MSM.ResourceMgr[i].post.guildAbbNameChange( _territoryIds, _guildAbbName )
    end
end

---@see 资源所属联盟简称变化
function ResourceLogic:resourceTerritoryStatusChange( _territoryIds )
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        -- 刷新该服务的资源点
        MSM.ResourceMgr[i].post.territoryStatusChange( _territoryIds )
    end
end

---@see 资源点刷新
function ResourceLogic:resourceRefresh( _isInit, _group )
    LOG_INFO("ResourceLogic resourceRefresh group(%s) start", tostring(_group))
    -- 本服分组刷新地图资源
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    if _isInit then
        -- 服务器重启，全部服务的瓦片都要刷新
        for i = 1, multiSnaxNum do
            -- 刷新该服务的资源点
            MSM.ResourceMgr[i].post.refreshResources( _isInit )
        end
    else
        -- 刷新分组内的瓦片
        local groupZones = MapLogic:getGroupZoneIndexs( Enum.MapObjectRefreshType.RESOURCE, _group, multiSnaxNum ) or {}
        for serviceIndex, zoneIndexs in pairs( groupZones ) do
            MSM.ResourceMgr[serviceIndex].post.refreshResources( _isInit, zoneIndexs )
        end
    end
end

---@see 资源点初始化处理
function ResourceLogic:resourceInit( _serviceZones )
    -- 资源点服务瓦片索引初始化
    for index, zoneIndexs in pairs( _serviceZones ) do
        MSM.ResourceMgr[index].req.InitZoneIndex( zoneIndexs )
    end

    -- 资源点刷新处理
    local nowTime = os.time()
    local refreshInfo = SM.c_refresh.req.Get( Enum.RefreshType.RESOURCE ) or {}
    if not refreshInfo.nextRefreshTime then
        refreshInfo.nextRefreshTime = 0
    end

    if refreshInfo.nextRefreshTime <= nowTime then
        -- 到刷新时间，直接刷新
        self:resourceRefresh( true )

        return true
    end
end

---@see 资源点存在重置
function ResourceLogic:resourceTimeOut( _resources, _resourceDict, _zoneResources, _resourceTimers, _territoryResources, _time, _deleteResources )
    local resourceInfo, zoneIndex, objectType, territoryId
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    -- 处理该定时器下的所有资源点信息
    for resourceIndex in pairs( _resourceTimers[_time] and _resourceTimers[_time].resourceIndexs or {} ) do
        -- 该资源点信息
        resourceInfo = _resources[resourceIndex] or {}
        -- 该资源点未被采集
        if not table.empty( resourceInfo ) and ( not resourceInfo.collectRid or resourceInfo.collectRid <= 0 ) then
            -- 地图移除该对象
            objectType = ResourceLogic:resourceTypeToObjectType( sResourceGatherType[resourceInfo.resourceTypeId].type )
            if Common.getMapObjectLoadFinish() then
                MSM.MapObjectMgr[resourceIndex].req.resourceLeave( resourceInfo.resourceId, resourceIndex, resourceInfo.pos, objectType )
            else
                _deleteResources[resourceIndex] = { objectId = resourceInfo.resourceId, pos = resourceInfo.pos, objectType = objectType }
            end
            -- 移除瓦片区域的资源点信息
            zoneIndex = resourceInfo.zoneIndex or nil
            if zoneIndex and _zoneResources[zoneIndex] and _zoneResources[zoneIndex][resourceIndex] then
                _zoneResources[zoneIndex][resourceIndex] = nil
            end
            -- 移除资源点信息
            _resourceDict[_resources[resourceIndex].resourceId] = nil
            territoryId = _resources[resourceIndex].territoryId
            if territoryId and _territoryResources[territoryId] and _territoryResources[territoryId][resourceIndex] then
                _territoryResources[territoryId][resourceIndex] = nil
                if table.empty( _territoryResources[territoryId] ) then
                    _territoryResources[territoryId] = nil
                end
            end
            _resources[resourceIndex] = nil
        end
    end
    -- 移除定时器信息
    _resourceTimers[_time] = nil
end

---@see 添加资源点
function ResourceLogic:addResource( _resources, _resourceDict, _zoneResources, _resourceTimers,
        _territoryResources, _sResourceGatherType, _resourcePos, _refreshTime, _zoneIndex, _deleteResources )
    -- 资源点所在领地ID
    local territoryId = GuildTerritoryLogic:getPosTerritoryId( _resourcePos )
    local resourceGuildAbbName = GuildTerritoryLogic:getTerritoryGuildAbbName( territoryId ) or ""
    -- 资源点类型
    local objectType = ResourceLogic:resourceTypeToObjectType( _sResourceGatherType.type )
    -- 资源点进入地图
    local resourceId, resourceIndex = MSM.MapObjectMgr[_sResourceGatherType.ID].req.resourceAddMap( _sResourceGatherType.ID,
                _resourcePos, _refreshTime, objectType, _sResourceGatherType.resAmount, resourceGuildAbbName )
    -- 更新资源点信息
    _resources[resourceIndex] = {
        resourceId = resourceId,
        zoneIndex = _zoneIndex,
        resourceTypeId = _sResourceGatherType.ID,
        refreshTime = _refreshTime,
        pos = _resourcePos,
        resourceAmount = _sResourceGatherType.resAmount,
        territoryId = territoryId,
    }

    _resourceDict[resourceId] = resourceIndex
    -- 更新区域资源点信息
    if not _zoneResources[_zoneIndex] then _zoneResources[_zoneIndex] = {} end
    _zoneResources[_zoneIndex][resourceIndex] = true
    -- 更新定时器信息
    local endTime = _refreshTime + _sResourceGatherType.timeLimit
    if _resourceTimers[endTime] then
        -- 定时器已存在
        _resourceTimers[endTime].resourceIndexs[resourceIndex] = true
    else
        -- 定时器不存在
        _resourceTimers[endTime] = {}
        _resourceTimers[endTime].resourceIndexs = {}
        _resourceTimers[endTime].resourceIndexs[resourceIndex] = true
        _resourceTimers[endTime].timerId = Timer.runAt( endTime, self.resourceTimeOut, self, _resources,
                        _resourceDict, _zoneResources, _resourceTimers, _territoryResources, endTime, _deleteResources )
    end

    -- 增加领地ID包含的资源对象ID
    if not _territoryResources[territoryId] then
        _territoryResources[territoryId] = {}
        _territoryResources[territoryId][resourceIndex] = true
    else
        _territoryResources[territoryId][resourceIndex] = true
    end
end

---@see 添加资源点刷新定时器
function ResourceLogic:addResourceRefreshTimer( _group )
    -- 增加下次刷新定时器
    local nextRefreshTime
    local nowTime = os.time()
    local refreshInfo = SM.c_refresh.req.Get( Enum.RefreshType.RESOURCE )
    if refreshInfo and refreshInfo.nextRefreshTime then
        if refreshInfo.nextRefreshTime > nowTime then
            nextRefreshTime = refreshInfo.nextRefreshTime
        else
            nextRefreshTime = nowTime + ( CFG.s_Config:Get( "resourceFreshTimeGap" ) or 120 )
            SM.c_refresh.req.Set( Enum.RefreshType.RESOURCE, { nextRefreshTime = nextRefreshTime } )
        end
    else
        nextRefreshTime = nowTime + ( CFG.s_Config:Get( "resourceFreshTimeGap" ) or 120 )
        SM.c_refresh.req.Add( Enum.RefreshType.RESOURCE, { nextRefreshTime = nextRefreshTime } )
    end

    -- 增加下次刷新定时器
    return Timer.runAt( nextRefreshTime, self.resourceRefresh, self, nil, _group )
end

---@see 获取瓦片区域资源点数量信息
function ResourceLogic:getZoneResourceNum( _zoneIndex, _zoneLevels, _sResourceGatherRule )
    local resourceCount = {}
    local zoneLevel = _zoneLevels[_zoneIndex] and _zoneLevels[_zoneIndex].zoneLevel or nil
    if zoneLevel then
        local sResourceGatherRule = _sResourceGatherRule[zoneLevel] or {}
        for resourceId, ruleInfo in pairs( sResourceGatherRule ) do
            resourceCount[resourceId] = ruleInfo.resourceGatherCnt
        end
    end

    return resourceCount
end

---@see 瓦片资源点刷新
function ResourceLogic:refreshZoneResources( _resources, _zoneResources, _resourceDict, _resourceTimers, _territoryResources, _deleteResources, _refreshZones )
    -- 该区域内应该有资源数量
    local resourceCount
    -- 当前该区域内的资源信息统计
    local resourceNum
    -- 应该刷新出的资源信息
    local refreshNum
    local refreshSum
    local sortRefresh
    -- 该区域内的资源点坐标信息
    local resourcePoints, resourcePos
    local nowTime = os.time()
    local newRefreshNum = 0
    local sConfig = CFG.s_Config:Get()
    local resourceGatherRadius = sConfig.resourceGatherRadiusCollide
    local sResourceGatherPoint = CFG.s_ResourceGatherPoint:Get()
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    local sResourceZoneLevel = CFG.s_ResourceZoneLevel:Get()
    local sResourceGatherRule = CFG.s_ResourceGatherRule:Get() or {}

    -- 循环处理每个区域的资源点信息
    for zoneIndex in pairs( _refreshZones or {} ) do
        if _zoneResources[zoneIndex] then
            -- 获取该区域的资源点数量信息
            resourceCount = self:getZoneResourceNum( zoneIndex, sResourceZoneLevel, sResourceGatherRule )
            -- 统计该区域内的资源点信息
            resourceNum = {}
            for resourceIndex in pairs( _zoneResources[zoneIndex] or {} ) do
                if not resourceNum[_resources[resourceIndex].resourceTypeId] then
                    resourceNum[_resources[resourceIndex].resourceTypeId] = 1
                else
                    resourceNum[_resources[resourceIndex].resourceTypeId] = resourceNum[_resources[resourceIndex].resourceTypeId] + 1
                end
            end

            refreshNum = {}
            refreshSum = 0
            sortRefresh = {}
            -- 统计该区域内不足的资源点信息
            for resourceTypeId, num in pairs( resourceCount ) do
                if ( resourceNum[resourceTypeId] or 0 ) < num then
                    refreshNum[resourceTypeId] = num - ( resourceNum[resourceTypeId] or 0 )
                    refreshSum = refreshSum + refreshNum[resourceTypeId]
                    table.insert( sortRefresh, { resourceTypeId = resourceTypeId, num = refreshNum[resourceTypeId] } )
                end
            end

            if refreshSum > 0 then
                -- 获取所有的该区域内的有效坐标点信息
                resourcePoints = table.copy( sResourceGatherPoint[zoneIndex] or {}, true )
                -- 按照资源点缺少多少来补刷
                table.sort( sortRefresh, function ( a, b ) return a.num > b.num end )
                local exitFlag, posIndex, posNum, isIdel, setObstracleRef
                for _, refreshInfo in pairs( sortRefresh ) do
                    local index = 1
                    while index <= refreshInfo.num do
                        if newRefreshNum >= 100 then
                            nowTime = os.time()
                            newRefreshNum = 0
                        end
                        posNum = #resourcePoints
                        if posNum >= 1 then
                            posIndex = Random.GetRange( 1, posNum, 1)[1]
                        else
                            exitFlag = true
                            break
                        end

                        resourcePos = { x = resourcePoints[posIndex].x, y = resourcePoints[posIndex].y }
                        table.remove( resourcePoints, posIndex )
                        -- 占用地块成功
                        isIdel, setObstracleRef = MapLogic:checkPosIdle( resourcePos, resourceGatherRadius, nil, nil, true )
                        if isIdel then
                            self:addResource( _resources, _resourceDict, _zoneResources, _resourceTimers, _territoryResources,
                                sResourceGatherType[refreshInfo.resourceTypeId], resourcePos, nowTime, zoneIndex, _deleteResources )
                            newRefreshNum = newRefreshNum + 1
                            index = index + 1
                            -- 移除旧的阻挡
                            if setObstracleRef then
                                SM.NavMeshObstracleMgr.post.delObstracleByRef( setObstracleRef )
                            end
                        end
                    end

                    if exitFlag then
                        break
                    end
                end
            end
        else
            LOG_ERROR("ResourceMgr refreshResources error, zoneIndex(%d) not in this service", zoneIndex)
        end
    end
end

return ResourceLogic