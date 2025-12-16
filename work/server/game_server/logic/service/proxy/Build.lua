--[[
* @file : Build.lua
* @type : snax multi service
* @author : chenlei
* @created : Tue Dec 24 2019 11:23:52 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 内城协议服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local BuildingLogic = require "BuildingLogic"
local RoleLogic = require "RoleLogic"
local HeroLogic = require "HeroLogic"
local ItemLogic = require "ItemLogic"
local RoleSync = require "RoleSync"
local Random = require "Random"
local TaskLogic = require "TaskLogic"

---@see 创建建筑
function response.CreateBuilding( msg )
    local type = msg.type
    local rid = msg.rid
    local pos = msg.pos
    local x = pos.x
    local y = pos.y
    -- 判断该类型建筑是否解锁
    local sBuildingLevelData = CFG.s_BuildingLevelData:Get( type * 100 + 1)
    for i=1,3 do
        if sBuildingLevelData["reqType"..i] > 0 then
            if BuildingLogic:getBuildingLv( rid, sBuildingLevelData["reqType"..i] ) < sBuildingLevelData["reqLevel"..i] then
                LOG_ERROR("rid(%d) CreateBuliding error, this type(%d) building level not enough ", rid , sBuildingLevelData["reqType"..i])
                return nil, ErrorCode.BUILDING_LOCK
            end
        end
    end
    -- 判断目标是否有建筑
    if not BuildingLogic:checkBuildingPut( rid, type, x, y ) then
        LOG_ERROR("rid(%d) CreateBuliding error, this area not create", rid)
        return nil, ErrorCode.BUILDING_AREA_ERROR
    end
    -- 判断该类建筑的数量
    local level = BuildingLogic:getBuildingLv( rid, Enum.BuildingType.TOWNHALL )
    local s_BuildingCountLimit = CFG.s_BuildingCountLimit:Get( type * 100 + level )
    local _, count = BuildingLogic:getBuildingLv( rid, type )
    if count >= s_BuildingCountLimit.buildCountLimit then
        LOG_ERROR("rid(%d) CreateBuliding error, this type count enough", rid)
        return nil, ErrorCode.BUILDING_COUNT_MAX
    end
    -- 判断是否有空闲队列
    if sBuildingLevelData.buildingTime > 0 and not BuildingLogic:checkFreeBuildQueue( rid ) then
        LOG_ERROR("rid(%d) CreateBuliding error, not free queue", rid)
        return nil, ErrorCode.BUILDING_NOT_FREE_QUEUE
    end
    -- 判断资源是否充足
    if sBuildingLevelData.food then
        if not RoleLogic:checkFood( rid, sBuildingLevelData.food ) then
            LOG_ERROR("rid(%d) CreateBuliding error, food not enough", rid)
            return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
        end
    end
    if sBuildingLevelData.wood then
        if not RoleLogic:checkWood( rid, sBuildingLevelData.wood ) then
            LOG_ERROR("rid(%d) CreateBuliding error, wood not enough", rid)
            return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
        end
    end
    if sBuildingLevelData.stone then
        if not RoleLogic:checkStone( rid, sBuildingLevelData.stone ) then
            LOG_ERROR("rid(%d) CreateBuliding error, stone not enough", rid)
            return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
        end
    end
    if sBuildingLevelData.coin then
        if not RoleLogic:checkGold( rid, sBuildingLevelData.coin ) then
            LOG_ERROR("rid(%d) CreateBuliding error, coin not enough", rid)
            return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
        end
    end
    if sBuildingLevelData.itemType1 and sBuildingLevelData.itemType1 > 0 then
        if not ItemLogic:checkItemEnough( rid, sBuildingLevelData.itemType1, sBuildingLevelData.itemCnt ) then
            LOG_ERROR("rid(%d) UpGradeBuliding error, item(%d) not enough", rid, sBuildingLevelData.itemType1)
            return nil, ErrorCode.ITEM_NOT_ENOUGH
        end
    end
    return BuildingLogic:createBuliding( rid, type, x, y )
end

---@see 升级建筑
function response.UpGradeBuilding( msg )
    local rid = msg.rid
    local buildingIndex = msg.buildingIndex
    local immediately = msg.immediately
    local buildInfo = BuildingLogic:getBuilding( rid, buildingIndex )
    if not buildInfo or table.empty(buildInfo) then
        LOG_ERROR("rid(%d) UpGradeBuliding error, this building(%d) not exist", rid, buildingIndex)
        return nil, ErrorCode.BUILDING_NOT_EXIST
    end
    local sBuildingLevelData = CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + buildInfo.level + 1 )
    if not sBuildingLevelData then
        LOG_ERROR("rid(%d) UpGradeBuliding error, this building is max level", rid)
        return nil, ErrorCode.BUILDING_LEVEL_MAX
    end
    -- 判断该类型建筑是否解锁
    for i=1,3 do
        if sBuildingLevelData["reqType"..i] > 0 then
            if BuildingLogic:getBuildingLv( rid, sBuildingLevelData["reqType"..i] ) < sBuildingLevelData["reqLevel"..i] then
                LOG_ERROR("rid(%d) UpGradeBuliding error, this type(%d) building level not enough ", rid , sBuildingLevelData["reqType"..i])
                return nil, ErrorCode.BUILDING_LOCK
            end
        end
    end
    if buildInfo.finishTime > 0 and buildInfo.finishTime > os.time() then
        return nil, ErrorCode.BUILDING_LEVEL_UP
    end
    if immediately then
        local args = {}
        args.rid = rid
        args.buildingIndex = buildingIndex
        local buildQueue = RoleLogic:getRole( rid, Enum.Role.buildQueue ) or {}
        for _, queue in pairs( buildQueue ) do
            if queue.buildingIndex == buildingIndex then
                LOG_ERROR("rid(%d) UpGradeBuliding immediately error, this building level up now", rid)
                return nil, ErrorCode.BUILDING_IMMEDIATELY_ERROR
            end
        end
        return MSM.RoleQueueMgr[rid].req.immediatelyComplete( args )
    end
    if sBuildingLevelData.itemType1 and sBuildingLevelData.itemType1 > 0 then
        if not ItemLogic:checkItemEnough( rid, sBuildingLevelData.itemType1, sBuildingLevelData.itemCnt ) then
            LOG_ERROR("rid(%d) UpGradeBuliding error, item(%d) not enough", rid, sBuildingLevelData.itemType1)
            return nil, ErrorCode.ITEM_NOT_ENOUGH
        end
    end
    -- 判断是否有空闲队列
    if not BuildingLogic:checkFreeBuildQueue( rid ) then
        LOG_ERROR("rid(%d) UpGradeBuliding error, not free queue", rid)
        return nil, ErrorCode.BUILDING_NOT_FREE_QUEUE
    end
    -- 判断建筑状态
    if buildInfo.type == Enum.BuildingType.BARRACKS then
        local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue ) or {}
        local type = Enum.ArmyType.INFANTRY
        if armyQueue[type] and armyQueue[type].finishTime and armyQueue[type].finishTime > 0 then
            LOG_ERROR("rid(%d) UpGradeBuliding fail, this UpGradeBuliding(%d) is training", rid,  buildInfo.type )
            return nil, ErrorCode.BUILDING_TRIAN
        end
    elseif buildInfo.type == Enum.BuildingType.STABLE then
        local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue ) or {}
        local type = Enum.ArmyType.CAVALRY
        if armyQueue[type] and armyQueue[type].finishTime and armyQueue[type].finishTime > 0 then
            LOG_ERROR("rid(%d) UpGradeBuliding fail, this UpGradeBuliding(%d) is training", rid,  buildInfo.type )
            return nil, ErrorCode.BUILDING_TRIAN
        end
    elseif buildInfo.type == Enum.BuildingType.ARCHERYRANGE then
        local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue ) or {}
        local type = Enum.ArmyType.ARCHER
        if armyQueue[type] and armyQueue[type].finishTime and armyQueue[type].finishTime > 0 then
            LOG_ERROR("rid(%d) UpGradeBuliding fail, this UpGradeBuliding(%d) is training", rid,  buildInfo.type )
            return nil, ErrorCode.BUILDING_TRIAN
        end
    elseif buildInfo.type == Enum.BuildingType.SIEGE then
        local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue ) or {}
        local type = Enum.ArmyType.SIEGE_UNIT
        if armyQueue[type] and armyQueue[type].finishTime and armyQueue[type].finishTime > 0 then
            LOG_ERROR("rid(%d) UpGradeBuliding fail, this UpGradeBuliding(%d) is training", rid,  buildInfo.type )
            return nil, ErrorCode.BUILDING_TRIAN
        end
    elseif buildInfo.type == Enum.BuildingType.COLLAGE then
        local technologyQueue = RoleLogic:getRole( rid, Enum.Role.technologyQueue ) or {}
        if technologyQueue and technologyQueue.technologyType and technologyQueue.technologyType > 0  then
            LOG_ERROR("rid(%d) UpGradeBuliding fail, technology is researching", rid)
            return nil, ErrorCode.BUILDING_RESREACH
        end
    elseif buildInfo.type == Enum.BuildingType.HOSPITAL then
        local treatmentQueue = RoleLogic:getRole( rid, Enum.Role.treatmentQueue ) or {}
        if treatmentQueue and not table.empty(treatmentQueue) and treatmentQueue.finishTime > 0  then
            LOG_ERROR("rid(%d) Treatment fail, technology is researching", rid)
            return nil, ErrorCode.BUILDING_TREATMENT
        end
    end
    -- 判断资源是否充足
    if sBuildingLevelData.food then
        if not RoleLogic:checkFood( rid, sBuildingLevelData.food ) then
            LOG_ERROR("rid(%d) UpGradeBuliding error, food not enough", rid)
            return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
        end
    end
    if sBuildingLevelData.wood then
        if not RoleLogic:checkWood( rid, sBuildingLevelData.wood ) then
            LOG_ERROR("rid(%d) CreateBuliding error, wood not enough", rid)
            return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
        end
    end
    if sBuildingLevelData.stone then
        if not RoleLogic:checkStone( rid, sBuildingLevelData.stone ) then
            LOG_ERROR("rid(%d) UpGradeBuliding error, stone not enough", rid)
            return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
        end
    end
    if sBuildingLevelData.coin then
        if not RoleLogic:checkGold( rid, sBuildingLevelData.coin ) then
            LOG_ERROR("rid(%d) UpGradeBuliding error, coin not enough", rid)
            return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
        end
    end
    return BuildingLogic:upGradeBuliding( rid, buildingIndex )
end

---@see 建筑建造升级中止
function response.EndBuilding(msg)
    local rid = msg.rid
    local buildingIndex = msg.buildingIndex

    return MSM.RoleBuildQueueMgr[rid].post.endBuilding( rid, buildingIndex )
end

---@see 获取城内资源
function response.GetBuildResources( msg )
    local rid = msg.rid
    local buildingIndexs = msg.buildingIndexs
    if not buildingIndexs then
        LOG_ERROR("rid(%d) GetBuildResources error, buildingIndexs is nil ", rid)
        return nil, ErrorCode.BUILDING_INDEX_ERROR
    end
    local buildInfo
    for _, buildingIndex in pairs(buildingIndexs) do
        buildInfo = BuildingLogic:getBuilding( rid, buildingIndex )
        if buildInfo.level == 0 then
            LOG_ERROR("rid(%d) GetBuildResources error, buildingIndex(%d) is creating ", rid, buildingIndex)
            return nil, ErrorCode.BUILDING_CREATEING
        end
    end
    return MSM.BuildingRoleMgr[rid].req.awardResources(rid, buildingIndexs,Enum.RoleResourcesAction.REWARD)
    -- return BuildingLogic:awardResources( rid, buildingIndexs )
end


---@see 建筑移动
function response.RemoveBuilding( msg )
    local pos = msg.pos
    local rid = msg.rid
    local buildingIndex = msg.buildingIndexs
    local x = pos.x
    local y = pos.y
    local buildInfo = BuildingLogic:getBuilding( rid, buildingIndex )
    if not buildInfo or table.empty(buildInfo) then
        LOG_ERROR("rid(%d) RemoveBuilding error, this building(%d) not exist", rid, buildingIndex)
        return nil, ErrorCode.BUILDING_NOT_EXIST
    end
    -- 判断目标是否有建筑
    if not BuildingLogic:checkBuildingPut( rid, buildInfo.type, x, y, buildingIndex ) then
        LOG_ERROR("rid(%d) RemoveBuilding error, this area not create", rid)
        return nil, ErrorCode.BUILDING_AREA_ERROR
    end
    local version = RoleLogic:addVersion( rid )
    buildInfo.pos = { x = x, y = y }
    buildInfo.version = version
    MSM.d_building[rid].req.Add( rid, buildingIndex, buildInfo )
    BuildingLogic:syncBuilding( rid, buildingIndex, buildInfo, true )
end

---@see 建筑拆除
function response.DismantleBuilding( msg )
    local buildingIndex = msg.buildingIndex
    local rid = msg.rid
    RoleLogic:addVersion( rid )
    local building = BuildingLogic:getBuilding( rid, buildingIndex )
    local synBuildInfo = {}
    local buildingConfig = CFG.s_BuildingTypeConfig:Get( building.type )
    if buildingConfig.group ~= Enum.BuildingGroup.DECORATION then
        LOG_ERROR("rid(%d) DismantleBuilding error, type error", rid)
        return nil, ErrorCode.BUILDING_DISMANTLE_ERROR
    end
    --删除建筑信息
    BuildingLogic:deleteBuilding( rid, buildingIndex )
    synBuildInfo[buildingIndex] = { buildingIndex = buildingIndex, level = -1 }
    BuildingLogic:syncBuilding( rid, buildingIndex, synBuildInfo, true )
    -- 返回资源
    local sBuildingLevelData = CFG.s_BuildingLevelData:Get( building.type * 100 + building.level )
    --返还资源
    local rate = CFG.s_Config:Get("destoryBuildingScale")
    if sBuildingLevelData.food then
        RoleLogic:addFood( rid, sBuildingLevelData.food * (rate / 1000) // 1, nil, Enum.LogType.DESTORY_BUILDING_GAIN_CURRENCY )
    end
    if sBuildingLevelData.wood then
        RoleLogic:addWood( rid, sBuildingLevelData.wood * (rate / 1000) // 1, nil, Enum.LogType.DESTORY_BUILDING_GAIN_CURRENCY )
    end
    if sBuildingLevelData.stone then
        RoleLogic:addStone( rid, sBuildingLevelData.stone * (rate / 1000) // 1, nil, Enum.LogType.DESTORY_BUILDING_GAIN_CURRENCY )
    end
    if sBuildingLevelData.coin then
        RoleLogic:addGold( rid, sBuildingLevelData.coin * (rate / 1000) // 1, nil, Enum.LogType.DESTORY_BUILDING_GAIN_CURRENCY )
    end
end

---@see 酒馆召唤
function response.Tavern( msg )
    local rid = msg.rid
    local type = msg.type
    local free = msg.free
    local count = msg.count
    local useDenar = msg.useDenar
    if type == Enum.BoxType.SILVER then
        local roleInfo = RoleLogic:getRole( rid, { Enum.Role.silverFreeCount, Enum.Role.openNextSilverTime } )
        if free then
            -- 判断今日免费次数几次
            local silverFreeCount = roleInfo.silverFreeCount
            if silverFreeCount <= 0 then
                LOG_ERROR( "rid(%d) Tavern, silverFreeCount not enought", rid )
                return false, ErrorCode.BUILD_SILVER_FREE_NOT_ENOHGH
            end
            -- 判断领取时间间隔超过配置值
            local openNextSilverTime = roleInfo.openNextSilverTime
            if openNextSilverTime > os.time() then
                LOG_ERROR( "rid(%d) Tavern, openTime error", rid )
                return false, ErrorCode.BUILD_SILVER_FREE_TIME_ERROR
            end
        else
            -- 判断背包道具是否充足
            local itemId = CFG.s_Config:Get("silverBoxOpenItem")
            local sItemInfo = CFG.s_Item:Get(itemId)
            if not useDenar then
                if not ItemLogic:checkItemEnough( rid, itemId, CFG.s_Config:Get("silverBoxOpenItemNum") * count ) then
                    LOG_ERROR( "rid(%d) Tavern, item not enough", rid )
                    return false, ErrorCode.ITEM_NOT_ENOUGH
                end
            else
                if not RoleLogic:checkDenar( rid, sItemInfo.shopPrice * count ) then
                    LOG_ERROR( "rid(%d) Tavern, denar not enough", rid )
                    return false, ErrorCode.ROLE_DENAR_NOT_ENOUGH
                end
            end
        end
        return BuildingLogic:openSilver( rid, free, count, useDenar )
    elseif type == Enum.BoxType.GOLD then
        if free then
            local roleInfo = RoleLogic:getRole( rid, { Enum.Role.goldFreeCount } )
            local goldFreeCount = roleInfo.goldFreeCount
            if goldFreeCount <= 0 then
                LOG_ERROR( "rid(%d) Tavern, goldFreeCount not enought", rid )
                return false, ErrorCode.BUILD_GOLD_FREE_NOT_ENOHGH
            end
        else
            -- 判断背包道具是否充足
            local itemId = CFG.s_Config:Get("goldBoxOpenItem")
            local sItemInfo = CFG.s_Item:Get(itemId)
            if not useDenar then
                if not ItemLogic:checkItemEnough( rid, itemId, CFG.s_Config:Get("goldBoxOpenItemNum") * count ) then
                    LOG_ERROR( "rid(%d) Tavern, item not enough", rid )
                    return false, ErrorCode.ITEM_NOT_ENOUGH
                end
            else
                if not RoleLogic:checkDenar( rid, sItemInfo.shopPrice * count ) then
                    LOG_ERROR( "rid(%d) Tavern, denar not enough", rid )
                    return false, ErrorCode.ROLE_DENAR_NOT_ENOUGH
                end
            end
        end
        return BuildingLogic:openGold( rid, free, count, useDenar )
    end
end

---@see 城墙灭火
function response.Extinguishing(msg)
    local rid = msg.rid
    if not BuildingLogic:checkWallBurn( rid ) then
        LOG_ERROR("rid(%d) Extinguishing error, wall not fire", rid)
        return nil, ErrorCode.BUILDING_WALL_NOT_FIRE
    end
    local costDenar = CFG.s_Config:Get("cityWallOutfire")
    if not RoleLogic:checkDenar( rid, costDenar ) then
        LOG_ERROR("rid(%d) Extinguishing error, denar not enough", rid)
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end
    -- 扣除钻石
    RoleLogic:addDenar( rid, -costDenar, nil, Enum.LogType.WALL_FIRE_DOWN_COST_DENAR )
    local buildInfo = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.WALL )[1]
    if MSM.RoleTimer[rid].req.getWallBurnTimer( rid ) then
        MSM.RoleTimer[rid].req.delWallBurnTimer( rid )
    end
    buildInfo.beginBurnTime = 0
    buildInfo.lastBurnTime = 0
    MSM.d_building[rid].req.Set( rid, buildInfo.buildingIndex, buildInfo )
    BuildingLogic:syncBuilding( rid, buildInfo.buildingIndex, buildInfo, true )
    local objectIndex = RoleLogic:getRoleCityIndex( rid )
    MSM.SceneCityMgr[objectIndex].post.updateCityBeginBurnTime( objectIndex, buildInfo.beginBurnTime )

end

---@see 城墙维修
function response.Service(msg)
    local rid = msg.rid
    local buildInfo = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.WALL )[1]
    if buildInfo.lostHp <= 0 then
        LOG_ERROR("rid(%d) Service error, wall hp max", rid)
        return nil, ErrorCode.BUILDING_WALL_HP_FULL
    end
    if buildInfo.serviceTime and buildInfo.serviceTime + CFG.s_Config:Get("cityWallMaintainCoolingTime") > os.time() then
        LOG_ERROR("rid(%d) Service error, service time error", rid)
        return nil, ErrorCode.BUILDING_WALL_SERVICE_TIME_ERROR
    end
    buildInfo.lostHp = buildInfo.lostHp - CFG.s_Config:Get("cityWallMaintainDurability")
    if buildInfo.lostHp <= 0 then
        -- 自动灭火
        buildInfo.lostHp = 0
        buildInfo.beginBurnTime = 0
        buildInfo.lastBurnTime = 0
        buildInfo.serviceTime = 0
        -- 删除定时器
        if MSM.RoleTimer[rid].req.getWallBurnTimer( rid ) then
            MSM.RoleTimer[rid].req.delWallBurnTimer( rid )
        end
    end
    buildInfo.serviceTime = os.time()
    MSM.d_building[rid].req.Set( rid, buildInfo.buildingIndex, buildInfo )
    BuildingLogic:syncBuilding( rid, buildInfo.buildingIndex, buildInfo, true )
    local objectIndex = RoleLogic:getRoleCityIndex( rid )
    MSM.SceneCityMgr[objectIndex].post.updateCityBeginBurnTime( objectIndex, buildInfo.beginBurnTime )
end

---@see 城墙驻防
function response.DefendHero(msg)
    local rid = msg.rid
    local mainHeroId = msg.mainHeroId
    local deputyHeroId = msg.deputyHeroId
    local roleInfo = RoleLogic:getRole( rid )

    if mainHeroId and deputyHeroId and deputyHeroId == mainHeroId then
        LOG_ERROR("rid(%d) DefendHero error, mainHeroId same to deputyHeroId ", rid)
        return nil, ErrorCode.BUILDING_WALL_HERO_SAME
    end

    if mainHeroId then
        roleInfo.mainHeroId = mainHeroId
        roleInfo.userMainHeroId = mainHeroId
    end
    if deputyHeroId then
        roleInfo.deputyHeroId = deputyHeroId
        roleInfo.userDeputyHeroId = deputyHeroId
    end
    RoleLogic:setRole( rid, { [Enum.Role.mainHeroId] = roleInfo.mainHeroId, [Enum.Role.deputyHeroId] = roleInfo.deputyHeroId,
                [Enum.Role.userMainHeroId] = roleInfo.userMainHeroId, [Enum.Role.userDeputyHeroId] = roleInfo.userDeputyHeroId } )
    RoleSync:syncSelf( rid, { [Enum.Role.mainHeroId] = roleInfo.mainHeroId, [Enum.Role.deputyHeroId] = roleInfo.deputyHeroId }, true )
    -- 换防处理
    HeroLogic:changeDefenseHeroCallback( rid, roleInfo.mainHeroId, roleInfo.deputyHeroId )
end

---@see 开启第二队列
function response.UnlockBuildQueue( msg )
    local rid = msg.rid
    local itemId = msg.itemId
    -- 判断建筑队列是否达到上限
    local size = 0
    local buildQueue = RoleLogic:getRole( rid, Enum.Role.buildQueue )
    for _, queueInfo in pairs(buildQueue) do
        if queueInfo.expiredTime == -1 then
            size = size + 1
        end
    end
    if size >= CFG.s_Config:Get("workQueueMax") then
        LOG_ERROR("rid(%d) unlockBuildQueue error, building queue max ", rid)
        return nil, ErrorCode.BUILDING_QUEUE_MAX
    end
    if itemId and itemId > 0 then
        local workQueueItem = CFG.s_Config:Get("workQueueItem")
        if itemId ~= workQueueItem then
            LOG_ERROR("rid(%d) unlockBuildQueue error, item error ", rid)
            return nil, ErrorCode.BUILDING_ITEM_ERROR
        end
        if not ItemLogic:checkItemEnough( rid, itemId, 1) then
            LOG_ERROR("rid(%d) unlockBuildQueue error, itemNum not enough ", rid)
            return nil, ErrorCode.ITEM_NOT_ENOUGH
        end
        ItemLogic:delItemById( rid, itemId, 1, nil, Enum.LogType.UNLOCK_BUILD_QUEUE_COST_ITEM )
    else
        local workQueueDenar = CFG.s_Config:Get("workQueueDenar")
        if not RoleLogic:checkDenar( rid, workQueueDenar ) then
            LOG_ERROR("rid(%d) unlockBuildQueue error, denar not enough ", rid)
            return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
        end
        RoleLogic:addDenar( rid, -workQueueDenar, nil, Enum.LogType.UNLOCK_BUILD_QUEUE_COST_DENAR )
    end
    BuildingLogic:unlockQueue( rid, CFG.s_Config:Get("workQueueTime") )
    return { result = true }
end

---@see 材料生产
function response.ProduceMaterial( msg )
    local rid = msg.rid
    local itemId = msg.itemId
    local buildInfo = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.SMITHY )[1]
    -- 判断铁匠铺是否存在
    if not buildInfo or table.empty(buildInfo) then
        LOG_ERROR("rid(%d) ProduceMaterial error, smithy building not exist ", rid)
        return nil, ErrorCode.BUILDING_SMITHY_NO_EXIST
    end
    -- 判断材料队列是否已满
    local materialQueue = RoleLogic:getRole( rid, Enum.Role.materialQueue ) or {}
    local produceItems = materialQueue.produceItems or {}
    if table.size(produceItems) >= 5 then
        LOG_ERROR("rid(%d) unlockBuildQueue error, material queue max ", rid)
        return nil, ErrorCode.BUILDING_SMITHY_QUEUE_MAX
    end
    -- 判断材料能否生产
    local equipMaterialMake = CFG.s_Config:Get("equipMaterialMake")
    if not table.exist(equipMaterialMake, itemId) then
        LOG_ERROR("rid(%d) unlockBuildQueue error, item can not produce ", rid)
        return nil, ErrorCode.BUILDING_SMITHY_ITEM_ERROR
    end
    table.insert( produceItems, { itemId = itemId, itemNum = CFG.s_Config:Get("equipMaterialMakeNum") })
    materialQueue.produceItems = produceItems
    if table.size(produceItems) == 1 then
        materialQueue.beginTime = os.time()
        materialQueue.finishTime = os.time() + CFG.s_Config:Get("equipMaterialMakeTime")
        -- 增加定时器
        MSM.RoleTimer[rid].req.addProduceTimer( rid, materialQueue.finishTime )
    end
    RoleLogic:setRole( rid, { [Enum.Role.materialQueue] = materialQueue } )
    RoleSync:syncSelf( rid, { [Enum.Role.materialQueue] = materialQueue }, true )
end

---@see 取消材料生产
function response.CancelProduceMaterial( msg )
    local rid = msg.rid
    local index = msg.index
    local materialQueue = RoleLogic:getRole( rid, Enum.Role.materialQueue )
    local produceItems = materialQueue.produceItems or {}
    table.remove(produceItems,index)
    materialQueue.produceItems = produceItems
    if index == 1 then
        materialQueue.beginTime = os.time()
        materialQueue.finishTime = os.time() + CFG.s_Config:Get("equipMaterialMakeTime")
        MSM.RoleTimer[rid].req.deleteProduceTimer( rid )
    end
    if table.size(produceItems) <= 0 then
        materialQueue.beginTime = 0
        materialQueue.finishTime = 0
    end
    RoleLogic:setRole( rid, { [Enum.Role.materialQueue] = materialQueue } )
    RoleSync:syncSelf( rid, { [Enum.Role.materialQueue] = materialQueue }, true )
    if index == 1 and table.size(produceItems) >= 1 then
        -- 重新增加定时器
        MSM.RoleTimer[rid].req.addProduceTimer( rid, materialQueue.finishTime )
    end
end

---@see 领取材料
function response.AwardProduceMaterial( msg )
    local rid = msg.rid
    local materialQueue = RoleLogic:getRole( rid, Enum.Role.materialQueue )
    if table.size( materialQueue.completeItems or {} ) <= 0 then
        LOG_ERROR("rid(%d) AwardProduceMaterial error, can not award material ", rid)
        return nil, ErrorCode.BUILD_SMITHY_CAN_NOT_AWARD
    end
    local quality
    for _, itemInfo in pairs( materialQueue.completeItems or {} ) do
        ItemLogic:addItem( { rid = rid, itemId = itemInfo.itemId, itemNum = itemInfo.itemNum, eventType = Enum.LogType.SMITHY_PRODUCE_GAIN_ITEM } )
        -- 增加合成材料统计计数
        quality = CFG.s_Item:Get( itemInfo.itemId, "quality" )
        TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.PRODUCE_MATERIAL_QUALITY, quality, itemInfo.itemNum )
        TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.PRODUCE_MATERIAL_QUALITY, Enum.TaskArgDefault, itemInfo.itemNum )
    end
    materialQueue.completeItems = {}
    RoleLogic:setRole( rid, { [Enum.Role.materialQueue] = materialQueue } )
    RoleSync:syncSelf( rid, { [Enum.Role.materialQueue] = materialQueue }, true )
end

---@see 材料图纸合成
function response.MaterialSynthesis( msg )
    local rid = msg.rid
    local itemId = msg.itemId
    local count = msg.count
    local max = msg.max
    local sEquipMaterial = CFG.s_EquipMaterial:Get(itemId)
    if not sEquipMaterial or sEquipMaterial.mix <= 0 then
        LOG_ERROR("rid(%d) MaterialSynthesis error, this item can not synthesis ", rid)
        return nil, ErrorCode.BUILDING_SMITHY_CAN_NOT_SYNTHESIS
    end
    local newItemId = sEquipMaterial.mix
    if not max then
        if not ItemLogic:checkItemEnough( rid, itemId, count * sEquipMaterial.mixCostNum ) then
            LOG_ERROR("rid(%d) MaterialSynthesis error, this item can not synthesis ", rid)
            return nil, ErrorCode.BUILDING_SMITHY_ITEM_NOT_ENOUGH
        end
    else
        local _, num = ItemLogic:checkItemEnough( rid, itemId, 0 )
        count = math.floor(num/sEquipMaterial.mixCostNum)
        if count <= 0 then
            LOG_ERROR("rid(%d) MaterialSynthesis error, this item can not synthesis ", rid)
            return nil, ErrorCode.BUILDING_SMITHY_ITEM_NOT_ENOUGH
        end
    end
    ItemLogic:delItemById( rid, itemId, count * sEquipMaterial.mixCostNum, nil, Enum.LogType.SMITHY_SYNTHESIS_COST_ITEM )
    ItemLogic:addItem( { rid = rid, itemId = newItemId, itemNum = count, eventType = Enum.LogType.SMITHY_SYNTHESIS_GAIN_ITEM } )
    local sItem = CFG.s_Item:Get( newItemId )
    -- 更新合成图纸数量
    if sItem.subType >= Enum.ItemSubType.EQUIP_MATERIAL_FEATHER and sItem.subType <= Enum.ItemSubType.EQUIP_MATERIAL_WOOD then
        -- 合成装备材料
        TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.MATERIAL_QUALITY, Enum.TaskArgDefault, count )
        TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.MATERIAL_QUALITY, sItem.quality, count )
    elseif sItem.subType >= Enum.ItemSubType.EQUIP_BOOK_WEAPON and sItem.subType <= Enum.ItemSubType.EQUIP_BOOK_NECKLACE then
        -- 合成装备图纸
        TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.EQUIP_BOOK, Enum.TaskArgDefault, count )
        TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.EQUIP_BOOK, sItem.quality, count )
    end
end

---@see 材料分解
function response.MaterialDecomposition( msg )
    local rid = msg.rid
    local itemId = msg.itemId
    local count = msg.count
    local max = msg.max
    local sEquipMaterial = CFG.s_EquipMaterial:Get(itemId)
    if not sEquipMaterial or sEquipMaterial.splitGetNum <= 0 then
        LOG_ERROR("rid(%d) MaterialDecomposition error, this item can not decomposition ", rid)
        return nil, ErrorCode.BUILDING_SMITHY_NOT_DECOMPOSITION
    end
    local newItemId = sEquipMaterial.split
    local price = 0
    if not max then
        if not ItemLogic:checkItemEnough( rid, itemId, count ) then
            LOG_ERROR("rid(%d) MaterialDecomposition error, this item can not synthesis ", rid)
            return nil, ErrorCode.BUILDING_SMITHY_ITEM_NOT_ENOUGH
        end
        -- 判断货币是否充足
        price = sEquipMaterial.splitCostCurNum * count
        if sEquipMaterial.splitCostCur == Enum.CurrencyType.food then
            if not RoleLogic:checkFood( rid, price ) then
                LOG_ERROR("rid(%d) MaterialDecomposition, food not enough", rid )
                return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.wood then
            if not RoleLogic:checkWood( rid, price ) then
                LOG_ERROR("rid(%d) MaterialDecomposition, wood not enough", rid )
                return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.stone then
            if not RoleLogic:checkStone( rid, price ) then
                LOG_ERROR("rid(%d) MaterialDecomposition, stone not enough", rid )
                return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.gold then
            if not RoleLogic:checkGold( rid, price ) then
                LOG_ERROR("rid(%d) MaterialDecomposition, gold not enough", rid )
                return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.denar then
            if not RoleLogic:checkDenar( rid, price ) then
                LOG_ERROR("rid(%d) MaterialDecomposition, denar not enough", rid )
                return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
            end
        end
    else
        local _, num = ItemLogic:checkItemEnough( rid, itemId, 0 )
        count = num
        if count <= 0 then
            LOG_ERROR("rid(%d) MaterialDecomposition error, this item can not synthesis ", rid)
            return nil, ErrorCode.BUILDING_SMITHY_ITEM_NOT_ENOUGH
        end
        -- 判断货币是否充足
        price = sEquipMaterial.splitCostCurNum * count
        if sEquipMaterial.splitCostCur == Enum.CurrencyType.food then
            if not RoleLogic:checkFood( rid, price ) then
                local food = RoleLogic:getRole( rid, Enum.Role.food )
                count = food/sEquipMaterial.splitCostCurNum
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.wood then
            if not RoleLogic:checkWood( rid, price ) then
                local wood = RoleLogic:getRole( rid, Enum.Role.wood )
                count = wood/sEquipMaterial.splitCostCurNum
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.stone then
            if not RoleLogic:checkStone( rid, price ) then
                local stone = RoleLogic:getRole( rid, Enum.Role.stone )
                count = stone/sEquipMaterial.splitCostCurNum
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.gold then
            if not RoleLogic:checkGold( rid, price ) then
                local gold = RoleLogic:getRole( rid, Enum.Role.gold )
                count = gold/sEquipMaterial.splitCostCurNum
            end
        elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.denar then
            if not RoleLogic:checkDenar( rid, price ) then
                local denar = RoleLogic:getRole( rid, Enum.Role.denar )
                count = denar/sEquipMaterial.splitCostCurNum
            end
        end
        price = sEquipMaterial.splitCostCurNum * count
    end

    -- 扣除对应货币
    if sEquipMaterial.splitCostCur == Enum.CurrencyType.food then
        RoleLogic:addFood( rid, -price, nil, Enum.LogType.MAKE_EQUIP_COST_CURRENCY )
    elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.wood then
        RoleLogic:addWood( rid, -price, nil, Enum.LogType.MAKE_EQUIP_COST_CURRENCY )
    elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.stone then
        RoleLogic:addStone( rid, -price, nil, Enum.LogType.MAKE_EQUIP_COST_CURRENCY )
    elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.gold then
        RoleLogic:addGold( rid, -price, nil, Enum.LogType.MAKE_EQUIP_COST_CURRENCY )
    elseif sEquipMaterial.splitCostCur == Enum.CurrencyType.denar then
        RoleLogic:addDenar( rid, -price, nil, Enum.LogType.MAKE_EQUIP_COST_CURRENCY )
    end
    ItemLogic:delItemById( rid, itemId, count, nil, Enum.LogType.SMITHY_DECOMPOSITION_COST_ITEM )
    ItemLogic:addItem( { rid = rid, itemId = newItemId, itemNum = count * sEquipMaterial.splitGetNum , eventType = Enum.LogType.SMITHY_DECOMPOSITION_GAIN_ITEM } )
    -- 增加材料分解统计计数
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.RESOLVE_MATERIAL_QUALITY, Enum.TaskArgDefault, count )
    local quality = CFG.s_Item:Get( itemId, "quality" )
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.RESOLVE_MATERIAL_QUALITY, quality, count )
end

---@see 本次锻造是否触发专属
function response.CheckMakeEquip( msg )
    -- 判断材料是否充足
    local rid = msg.rid
    local itemId = msg.itemId
    local sEquip = CFG.s_Equip:Get(itemId)
    local price = sEquip.costGold

    -- 判断货币是否充足
    if not RoleLogic:checkGold( rid, price ) then
        LOG_ERROR("rid(%d) CheckMakeEquip, gold not enough", rid )
        return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
    end

    -- 判断材料是否充足
    if not BuildingLogic:cancleMaterial( rid, itemId ) then
        LOG_ERROR("rid(%d) CheckMakeEquip, item not enough", rid )
        return nil, ErrorCode.BUILDING_EQUIP_ITEM_NO_ENOUGH
    end

    local num = Random.Get(1,100)
    local exclusive = false
    if num > 50 then
        exclusive = true
        RoleLogic:setRole( rid, { [Enum.Role.exclusive] = exclusive })
    end
    return { exclusive = exclusive }
end

---@see 装备锻造
function response.MakeEquipment( msg )
    local rid = msg.rid
    local itemId = msg.itemId
    local exclusive = msg.exclusive or 0

    -- 判断本次锻造是否是专属
    if exclusive > 0 and not RoleLogic:getRole( rid, Enum.Role.exclusive ) then
        LOG_ERROR("rid(%d) MakeEquipment, not exclusive equip", rid )
        return nil, ErrorCode.BUILDING_EQUIP_EXCLUSIVE_ERROR
    end

    local sEquip = CFG.s_Equip:Get(itemId)
    local price = sEquip.costGold
    -- 判断货币是否充足
    if not RoleLogic:checkGold( rid, price ) then
        LOG_ERROR("rid(%d) MakeEquipment, gold not enough", rid )
        return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
    end

    local flag, itemInfo = BuildingLogic:cancleMaterial( rid, itemId )
    -- 判断材料是否充足
    if not flag then
        LOG_ERROR("rid(%d) MakeEquipment, item not enough", rid )
        return nil, ErrorCode.BUILDING_EQUIP_ITEM_NO_ENOUGH
    end

    -- 扣除道具
    for id, itemNum in pairs(itemInfo) do
        if itemNum > 0 and not ItemLogic:checkItemEnough( rid, id, itemNum ) then
            LOG_ERROR("rid(%d) MakeEquipment, item not enough", rid )
            return nil, ErrorCode.BUILDING_EQUIP_ITEM_NO_ENOUGH
        end
    end

    for id, itemNum in pairs(itemInfo) do
        if itemNum > 0 then
            ItemLogic:delItemById( rid, id, itemNum, nil, Enum.LogType.MAKE_EQUIP_COST_ITEM )
        end
    end

    -- 扣除金币
    RoleLogic:addGold( rid, -price, nil, Enum.LogType.MAKE_EQUIP_COST_CURRENCY )
    ItemLogic:addItem({ rid = rid, itemId = itemId, itemNum = 1, eventType = Enum.LogType.MAKE_EQUIP_GAIN_ITEM, exclusive = exclusive })
    -- 更新锻造装备数量
    local quality = CFG.s_Item:Get( itemId, "quality" )
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.EQUIP_QUALITY, Enum.TaskArgDefault, 1 )
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.EQUIP_QUALITY, quality, 1 )
end

---@see 装备分解
function response.DecompositionEquipment( msg )
    local rid = msg.rid
    local itemIndex = msg.itemIndex
    local itemInfo = ItemLogic:getItem( rid, itemIndex )
    if not itemInfo then
        LOG_ERROR("rid(%d) DecompositionEquipment, item not exist", rid )
        return nil, ErrorCode.BUILDING_EQUIP_NO_EXIST
    end
    -- 判断是否被统帅穿着
    if itemInfo.heroId and itemInfo.heroId > 0 then
        -- 判断统帅是否在城内
        if not HeroLogic:checkHeroIdle( rid, itemInfo.heroId ) then
            LOG_ERROR("rid(%d) HeroWearEquip, hero not in city ", rid)
            return nil, ErrorCode.HERO_EQUIP_NOT_IN_CITY
        end
    end

    local sEquip = CFG.s_Equip:Get(itemInfo.itemId)

    ItemLogic:delItem( rid, itemIndex, 1, nil, Enum.LogType.DECOMPOSITION_EQUIP_COST_ITEM )

    for i=1, table.size(sEquip.decomposeMaterial) do
        local itemId = sEquip.decomposeMaterial[i]
        local itemNum = sEquip.decomposeMaterialNum[i]
        ItemLogic:addItem( { rid = rid, itemId = itemId, itemNum = itemNum, eventType = Enum.LogType.DECOMPOSITION_EQUIP_GAIN_ITEM } )
    end

    local equips = {}
    equips[1] = { subType = Enum.ItemSubType.HELMET, attr = Enum.Hero.head }
    equips[2] = { subType = Enum.ItemSubType.BREASTPLATE, attr = Enum.Hero.breastPlate }
    equips[3] = { subType = Enum.ItemSubType.ARMS, attr = Enum.Hero.weapon }
    equips[4] = { subType = Enum.ItemSubType.GLOVES, attr = Enum.Hero.gloves }
    equips[5] = { subType = Enum.ItemSubType.PANTS, attr = Enum.Hero.pants }
    equips[6] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories1 }
    equips[7] = { subType = Enum.ItemSubType.ACCESSORIES, attr = Enum.Hero.accessories2 }
    equips[8] = { subType = Enum.ItemSubType.SHOES, attr = Enum.Hero.shoes }

    if itemInfo.heroId and itemInfo.heroId > 0 then
        local heroInfo = HeroLogic:getHero( rid, itemInfo.heroId )
        for _, equipInfo in pairs(equips) do
            local attr = equipInfo.attr
            if heroInfo[attr] and heroInfo[attr] == itemIndex then
                heroInfo[attr] = 0
                HeroLogic:setHero( rid, itemInfo.heroId, heroInfo )
                HeroLogic:syncHero( rid, itemInfo.heroId, heroInfo, true, true)
                break
            end
        end
    end

    -- 增加分解装备统计计数
    local quality = CFG.s_Item:Get( itemInfo.itemId, "quality" )
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.RESOLVE_EQUIP_QUALITY, Enum.TaskArgDefault, 1 )
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.RESOLVE_EQUIP_QUALITY, quality, 1 )
end