--[[
* @file : BuildingLogic.lua
* @type : lua lib
* @author : chenlei
* @created : Tue Dec 24 2019 10:21:26 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 内城相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local LogLogic = require "LogLogic"
local ItemLogic = require "ItemLogic"
local HeroLogic = require "HeroLogic"
local ScoutsLogic = require "ScoutsLogic"
local RoleChatLogic = require "RoleChatLogic"
local BuildDef = require "BuildDef"
local BuildingLogic = {}

---@see 设置建筑属性
function BuildingLogic:setBuilding( _rid, _buildingIndex, _field, _value )
    return MSM.d_building[_rid].req.Set( _rid, _buildingIndex, _field, _value )
end

---@see 获取建筑属性
---@return defaultBuildAttrClass
function BuildingLogic:getBuilding( _rid, _buildingIndex, _fields )
    return MSM.d_building[_rid].req.Get( _rid, _buildingIndex, _fields )
end

---@see 删除建筑
function BuildingLogic:deleteBuilding( _rid, _buildingIndex )
    return MSM.d_building[_rid].req.Delete( _rid, _buildingIndex )
end

---@see 根据建筑类型查找建筑信息
---@return defaultBuildAttrClass
function BuildingLogic:getBuildingInfoByType( _rid, _type )
    local buildingInfos = {}
    local buildings = self:getBuilding( _rid )
    for _, buildingInfo in pairs(buildings) do
        if buildingInfo.type == _type then
            table.insert( buildingInfos, buildingInfo )
        end
    end
    return buildingInfos
end

---@see 获取建筑信息
function BuildingLogic:getBuildingInfo( _rid, _version )
    local buildings = self:getBuilding( _rid )
    local tBuild = {}
    for _, building in pairs( buildings ) do
        if building.version > _version then
            tBuild[buildings.buildingIndex] = building
        end
    end
    return { buildingInfo = tBuild }
end

---@see 取建筑最高等级
function BuildingLogic:getBuildingLv( _rid, _type )
    local level = 0
    local count = 0
    local buildings = self:getBuilding( _rid )
    for _, building in pairs(buildings) do
        if building.type == _type then
            if building.level > level then
                level = building.level
            end
            count = count + 1
        end
    end
    return level, count
end

---@see 判断某种类型建筑达到等级的个数
function BuildingLogic:getBuildingLvCount( _rid, _type, _level )
    local count = 0
    local buildings = self:getBuilding( _rid )
    for _, building in pairs(buildings) do
        if building.type == _type then
            if building.level >= _level then
                count = count + 1
            end
        end
    end
    return count
end

---@see 判断资源类型建筑的最高等级
function BuildingLogic:getResBuilding( _rid, _types )
    local buildings = self:getBuilding( _rid )
    local level = 0
    for _, building in pairs(buildings) do
        if table.exist( _types, building.type ) then
            if building.level > level then
                level = building.level
            end
        end
    end
    return level
end

---@see 判断属于哪个时代
function BuildingLogic:checkAge( _rid, _level )
    local mainLevel = _level or self:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL )
    local s_CityAgeSize = CFG.s_CityAgeSize:Get()
    local returnConfig
    for _, cityAgeSize in pairs(s_CityAgeSize) do
        if cityAgeSize.townLevel <= mainLevel then
            if returnConfig then
                if cityAgeSize.townLevel > returnConfig.townLevel then
                    returnConfig = cityAgeSize
                end
            else
                returnConfig = cityAgeSize
            end
        end
    end
    return returnConfig
end

---@see 获取一个建筑空索引
function BuildingLogic:getFreeBuildingIndex( _rid )
    local buildings = self:getBuilding( _rid ) or {}
    local newIndex = 0
    for i = 1, table.size(buildings) do
        if not buildings[i] then return i end
        newIndex = i
    end
    return newIndex + 1
end

---@see 创建建筑实现
function BuildingLogic:createBulidingImpl( _rid, _type, _x, _y )
    -- 判断该类型建筑是否解锁
    local sBuildingLevelData = CFG.s_BuildingLevelData:Get( _type * 100 + 1 )

    local newIndex = self:getFreeBuildingIndex( _rid )
    local version = RoleLogic:addVersion( _rid )
    if sBuildingLevelData.buildingTime == 0 then
        -- 扣除相关资源
        if sBuildingLevelData.food then
            RoleLogic:addFood( _rid, -sBuildingLevelData.food, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
        end
        if sBuildingLevelData.wood then
            RoleLogic:addWood( _rid, -sBuildingLevelData.wood, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
        end
        if sBuildingLevelData.stone then
            RoleLogic:addStone( _rid, -sBuildingLevelData.stone, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
        end
        if sBuildingLevelData.coin then
            RoleLogic:addGold( _rid, -sBuildingLevelData.coin, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
        end
        -- 扣除道具
        if sBuildingLevelData.itemType1 and sBuildingLevelData.itemType1 > 0 then
            ItemLogic:delItemById( _rid, sBuildingLevelData.itemType1, sBuildingLevelData.itemCnt, nil, Enum.LogType.BUILDING_LEVEL_COST_ITEM )
        end
        local buildInfo = { buildingIndex = newIndex, type = _type , level = 1, finishTime = -1, pos = { x = _x, y = _y }, version = version,
                            lastRewardTime = 0, buildTime = os.time() }
        if buildInfo.type == Enum.BuildingType.FARM or buildInfo.type == Enum.BuildingType.WOOD
        or buildInfo.type == Enum.BuildingType.STONE or buildInfo.type == Enum.BuildingType.GOLD then
            buildInfo.buildingGainInfo = { num = 0, changeTime = os.time() }
        end

        MSM.d_building[_rid].req.Add( _rid, newIndex, buildInfo )
        self:syncBuilding( _rid, newIndex, buildInfo, true )
        local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
        LogLogic:buildCreate( { logType = Enum.LogType.BUILD_CREATE, buildingId = sBuildingLevelData.ID, costTime = 0, iggid = iggid, rid = _rid } )
        self:sendBuildingMail( _rid, buildInfo.type, buildInfo.level )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILE_LEVEL, 1 )

        return { buildingIndex = newIndex }
    else
        -- 判断工人队列是否开启
        local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
        if table.size(buildQueue) <= 0 then
            return nil, ErrorCode.BUILDING_NOT_FREE_QUEUE
        end
        -- 建筑加成时间
        local buildSpeedMulti = RoleLogic:getRole( _rid, Enum.Role.buildSpeedMulti ) or 0
        local buildTime = sBuildingLevelData.buildingTime * ( 1000 - buildSpeedMulti) / 1000 // 1
        for _, queue in pairs( buildQueue ) do
            if ( not queue.finishTime or queue.finishTime < 0 ) and (queue.expiredTime == -1 or queue.expiredTime >= buildTime) then
                -- 扣除相关资源
                if sBuildingLevelData.food then
                    RoleLogic:addFood( _rid, -sBuildingLevelData.food, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
                end
                if sBuildingLevelData.wood then
                    RoleLogic:addWood( _rid, -sBuildingLevelData.wood, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
                end
                if sBuildingLevelData.stone then
                    RoleLogic:addStone( _rid, -sBuildingLevelData.stone, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
                end
                if sBuildingLevelData.coin then
                    RoleLogic:addGold( _rid, -sBuildingLevelData.coin, nil, Enum.LogType.BUILD_CREATE_COST_DENAR )
                end
                 -- 扣除道具
                if sBuildingLevelData.itemType1 and sBuildingLevelData.itemType1 then
                    ItemLogic:delItemById( _rid, sBuildingLevelData.itemType1, sBuildingLevelData.itemCnt, nil, Enum.LogType.BUILDING_LEVEL_COST_ITEM )
                end
                local finishTime = os.time() + buildTime
                local buildInfo = { buildingIndex = newIndex, type = _type , level = 0, finishTime = finishTime ,
                        pos = { x = _x, y = _y }, version = version }
                if buildInfo.type == Enum.BuildingType.FARM or buildInfo.type == Enum.BuildingType.WOOD
                or buildInfo.type == Enum.BuildingType.STONE or buildInfo.type == Enum.BuildingType.GOLD then
                    buildInfo.buildingGainInfo = { num = 0, changeTime = os.time() }
                end
                queue.finishTime = finishTime
                queue.buildingIndex = newIndex
                queue.beginTime = os.time()
                queue.costTime = buildTime
                queue.firstFinishTime = finishTime
                queue.timerId = MSM.RoleTimer[_rid].req.addBuildTimer( _rid, finishTime, newIndex, queue.queueIndex  )
                RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
                RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [queue.queueIndex] = queue } }, true )
                MSM.d_building[_rid].req.Add( _rid, newIndex, buildInfo )
                self:syncBuilding( _rid, newIndex, buildInfo, true )
                MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILE_LEVEL, 1 )

                return { buildingIndex = newIndex }
            end
        end
    end
end

---@see 创建建筑
function BuildingLogic:createBuliding( _rid, _type, _x, _y )
    return MSM.RoleBuildQueueMgr[_rid].req.createBuliding( _rid, _type, _x, _y )
end

---@see 获取建筑队列空索引
function BuildingLogic:getFreeBuildQueueIndex( _rid )
    local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
    local newIndex = 0
    for i = 1, table.size(buildQueue) do
        if not buildQueue[i] then return i end
        newIndex = i
    end
    return newIndex + 1
end

---@see 创建建筑队列
function BuildingLogic:createBuildQueue( _rid)
    local buildQueue = {}
    local queueIndex = self:getFreeBuildQueueIndex( _rid )
    buildQueue[queueIndex] = {
        queueIndex = queueIndex,
        main = true,
        expiredTime = -1,
        finishTime = -1,
    }
    RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
end

---@see 创建初始建筑
function BuildingLogic:initBuilding( _rid )
    local s_InitBuilding = CFG.s_InitBuilding:Get()
    for _, sInitBuilding in pairs(s_InitBuilding) do
        local version = RoleLogic:addVersion( _rid )
        local buildingIndex = self:getFreeBuildingIndex(_rid)
        local buildInfo = { buildingIndex = buildingIndex, type = sInitBuilding.type , level = 1, finishTime = -1,
                                lastRewardTime = os.time(), pos = { x = sInitBuilding.posX, y = sInitBuilding.posY }, version = version }
        MSM.d_building[_rid].req.Add( _rid, buildingIndex, buildInfo )
        self:initQueue( _rid, sInitBuilding.type, true )
        self:sendBuildingMail( _rid, buildInfo.type, buildInfo.level )

        if sInitBuilding.type == Enum.BuildingType.GUARDTOWER then
            -- 警戒塔
            RoleLogic:guardTowerLevelUpCallback( _rid, 1 )
        end
    end
end

---@see 判断建筑类型初始化相关的队列
function BuildingLogic:initQueue( _rid, _type, _isLogin )
    if _type == Enum.BuildingType.BARRACKS then
        local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue ) or {}
        if not armyQueue[Enum.ArmyType.INFANTRY] then
            armyQueue[Enum.ArmyType.INFANTRY] = {
                queueIndex = Enum.ArmyType.INFANTRY
            }
            RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
            if not _isLogin then
                RoleSync:syncSelf( _rid, { [Enum.Role.armyQueue] = { [Enum.ArmyType.INFANTRY] = armyQueue[Enum.ArmyType.INFANTRY] } }, true )
            end
        end
    elseif _type == Enum.BuildingType.STABLE then
        local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue ) or {}
        if not armyQueue[Enum.ArmyType.CAVALRY] then
            armyQueue[Enum.ArmyType.CAVALRY] = {
                queueIndex = Enum.ArmyType.CAVALRY
            }
            RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
            if not _isLogin then
                RoleSync:syncSelf( _rid, { [Enum.Role.armyQueue] = { [Enum.ArmyType.CAVALRY] = armyQueue[Enum.ArmyType.CAVALRY] } }, true )
            end
        end
    elseif _type == Enum.BuildingType.ARCHERYRANGE then
        local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue ) or {}
        if not armyQueue[Enum.ArmyType.ARCHER] then
            armyQueue[Enum.ArmyType.ARCHER] = {
                queueIndex = Enum.ArmyType.ARCHER
            }
            RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
            if not _isLogin then
                RoleSync:syncSelf( _rid, { [Enum.Role.armyQueue] = { [Enum.ArmyType.ARCHER] = armyQueue[Enum.ArmyType.ARCHER] } }, true )
            end
        end
    elseif _type == Enum.BuildingType.SIEGE then
        local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue ) or {}
        if not armyQueue[Enum.ArmyType.SIEGE_UNIT] then
            armyQueue[Enum.ArmyType.SIEGE_UNIT] = {
                queueIndex = Enum.ArmyType.SIEGE_UNIT
            }
            RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
            if not _isLogin then
                RoleSync:syncSelf( _rid, { [Enum.Role.armyQueue] = { [Enum.ArmyType.SIEGE_UNIT] = armyQueue[Enum.ArmyType.SIEGE_UNIT] } }, true )
            end
        end
    elseif _type == Enum.BuildingType.COLLAGE then
        local technologyQueue = RoleLogic:getRole( _rid, Enum.Role.technologyQueue )
        if not technologyQueue then
            technologyQueue = {
                queueIndex = 1
            }
            RoleLogic:setRole( _rid, { [Enum.Role.technologyQueue] = technologyQueue } )
            if not _isLogin then
                RoleSync:syncSelf( _rid, { [Enum.Role.technologyQueue] = technologyQueue }, true )
            end
        end
    elseif _type == Enum.BuildingType.HOSPITAL then
        local treatmentQueue = RoleLogic:getRole( _rid, Enum.Role.treatmentQueue )
        if not treatmentQueue then
            treatmentQueue = {
                queueIndex = 1
            }
            RoleLogic:setRole( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue } )
            if not _isLogin then
                RoleSync:syncSelf( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue }, true )
            end
        end
    end
end


---@see 判断是否有空闲队列
function BuildingLogic:checkFreeBuildQueue( _rid )
    local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue )
    if table.size(buildQueue) <= 0 then
        return false
    end
    for _, queue in pairs(buildQueue) do
        if not queue.finishTime or queue.finishTime <= os.time() then
            return true, queue
        end
    end
end

---@see 升级建筑实现
function BuildingLogic:upGradeBulidingImpl( _rid, _buildingIndex )
    local buildInfo = BuildingLogic:getBuilding( _rid, _buildingIndex )
    local sBuildingLevelData = CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + buildInfo.level + 1 )
    -- 判断工人队列是否开启
    local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
    if table.size(buildQueue) <= 0 then
        return
    end
    -- 建筑加成时间
    local buildSpeedMulti = RoleLogic:getRole( _rid, Enum.Role.buildSpeedMulti ) or 0
    local buildTime = math.tointeger(sBuildingLevelData.buildingTime * ( 1000 - buildSpeedMulti) / 1000 // 1)
    local version = RoleLogic:addVersion( _rid )
    for _, queue in pairs( buildQueue ) do
        if ( not queue.finishTime or queue.finishTime < 0 ) and ( queue.expiredTime == -1 or queue.expiredTime >= os.time() + buildTime ) then
            -- 扣除相关资源
            if sBuildingLevelData.food then
                RoleLogic:addFood( _rid, -sBuildingLevelData.food, nil, Enum.LogType.BUILD_LEVEL_COST_DENAR )
            end
            if sBuildingLevelData.wood then
                RoleLogic:addWood( _rid, -sBuildingLevelData.wood, nil,  Enum.LogType.BUILD_LEVEL_COST_DENAR )
            end
            if sBuildingLevelData.stone then
                RoleLogic:addStone( _rid, -sBuildingLevelData.stone, nil,  Enum.LogType.BUILD_LEVEL_COST_DENAR )
            end
            if sBuildingLevelData.coin then
                RoleLogic:addGold( _rid, -sBuildingLevelData.coin, nil,  Enum.LogType.BUILD_LEVEL_COST_DENAR )
            end
             -- 扣除道具
            if sBuildingLevelData.itemType1 and sBuildingLevelData.itemType1 > 0 then
                ItemLogic:delItemById( _rid, sBuildingLevelData.itemType1, sBuildingLevelData.itemCnt, nil, Enum.LogType.BUILDING_LEVEL_COST_ITEM )
            end
            local finishTime = os.time() + buildTime
            queue.finishTime = finishTime
            queue.beginTime = os.time()
            queue.costTime = buildTime
            queue.firstFinishTime = finishTime
            queue.buildingIndex = _buildingIndex
            queue.timerId = MSM.RoleTimer[_rid].req.addBuildTimer( _rid, finishTime, _buildingIndex, queue.queueIndex  )
            RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
            RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [queue.queueIndex] = queue } }, true )
            buildInfo.version = version
            buildInfo.finishTime = finishTime
            MSM.d_building[_rid].req.Set( _rid, _buildingIndex, buildInfo )
            self:syncBuilding( _rid, _buildingIndex, buildInfo, true, true )
            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILE_LEVEL, 1 )
            return { buildingIndex = _buildingIndex, immediately = false }
        end
    end
    return nil, ErrorCode.BUILDING_NOT_FREE_QUEUE
end

---@see 升级建筑
function BuildingLogic:upGradeBuliding( _rid, _buildingIndex )
    return MSM.RoleBuildQueueMgr[_rid].req.upGradeBuliding( _rid, _buildingIndex )
end

---@see 判断本次升级时代是否变迁
function BuildingLogic:checkAgeChange( _rid, _level )
    -- 如果角色在线，不用处理
    if not Common.offOnline( _rid ) then
        return
    end
    local flag = false
    local s_CityAgeSize = CFG.s_CityAgeSize:Get()
    for _, cityAgeSize in pairs(s_CityAgeSize) do
        if cityAgeSize.townLevel == _level then
            flag = true
        end
    end
    if not flag then
        return
    end
    RoleLogic:setRole( _rid, { [Enum.Role.isChangeAge] = true } )
end

---@see 升级建筑回调
function BuildingLogic:upGradeBuildCallBackImpl( _rid, _buildingIndex, _queueIndex, _isLogin, _isGuildHelp )
    local version = RoleLogic:addVersion( _rid, _isLogin )
    local costTime = 0
    local buildInfo = self:getBuilding( _rid, _buildingIndex )
    if not buildInfo or table.empty(buildInfo) or ( _queueIndex and ( buildInfo.finishTime or 0 ) <= 0 ) then
        -- 没找到建筑, 或者建筑已经升级过(去除立即升级)
        return
    end
    buildInfo.level = buildInfo.level + 1
    if not CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + buildInfo.level ) then
        return
    end
    buildInfo.finishTime = -1
    buildInfo.version = version
    local resourceBuildFirst = RoleLogic:getRole( _rid, Enum.Role.resourceBuildFirst )
    if buildInfo.level == 1 and ( buildInfo.type == Enum.BuildingType.FARM or buildInfo.type == Enum.BuildingType.WOOD
        or buildInfo.type == Enum.BuildingType.STONE or buildInfo.type == Enum.BuildingType.GOLD ) then
        if not resourceBuildFirst then
            buildInfo.buildingGainInfo.changeTime = 0
            RoleLogic:setRole( _rid, { [Enum.Role.resourceBuildFirst] = true } )
        else
            buildInfo.buildingGainInfo.lastRewardTime = os.time()
        end
    end
    if buildInfo.level == 1 then
        buildInfo.buildTime = os.time()
    end
    MSM.d_building[_rid].req.Set( _rid, _buildingIndex, buildInfo )
    if not _isLogin then
        self:syncBuilding( _rid, _buildingIndex, buildInfo, true, true )
    end
    local roleInfoChange = {}
    local buildQueue
    local requestHelpIndex
    if _queueIndex then
        buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue )
        requestHelpIndex = buildQueue[_queueIndex].requestHelpIndex
        costTime = buildQueue[_queueIndex].costTime
        buildQueue[_queueIndex].finishTime = -1
        buildQueue[_queueIndex].beginTime = 0
        buildQueue[_queueIndex].costTime = 0
        buildQueue[_queueIndex].firstFinishTime = -1
        if MSM.RoleTimer[_rid].req.checkBuildTimer( _rid, buildQueue[_queueIndex].timerId ) then
            MSM.RoleTimer[_rid].req.deleteBuildTimer( _rid, buildQueue[_queueIndex].timerId )
        end
        buildQueue[_queueIndex].timerId = -1
        buildQueue[_queueIndex].requestGuildHelp = nil
        buildQueue[_queueIndex].requestHelpIndex = nil
        RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
        roleInfoChange.buildQueue = { [_queueIndex] = buildQueue[_queueIndex] }
    end

    -- 重新计算角色属性加成
    local RoleCacle = require "RoleCacle"
    local roleInfo = RoleLogic:getRole( _rid )
    local oldRoleInfo = table.copy( roleInfo, true )
    RoleCacle:buildAttrChange( roleInfo, buildInfo )
    RoleLogic:updateRoleChangeInfo( _rid, oldRoleInfo, roleInfo )
    local mysteryStoreCD = CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + buildInfo.level, "mysteryStoreCD" )
    RoleLogic:reduceTime( _rid, mysteryStoreCD )
    -- 相关特殊建筑处理
    if buildInfo.type == Enum.BuildingType.TOWNHALL then
        RoleLogic:setRole( _rid, { [Enum.Role.level] = buildInfo.level } )
        roleInfoChange.level = buildInfo.level
        -- 更新地图上的等级
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        MSM.SceneCityMgr[cityIndex].post.updateCityLevel( cityIndex, buildInfo.level )
        self:checkAgeChange( _rid, buildInfo.level )
        -- 同步等级到聊天服务器
        RoleChatLogic:syncRoleInfoToChatServer( _rid )
        -- 排行版处理
        local RankLogic = require "RankLogic"
        RankLogic:update( _rid, Enum.RankType.MAIN_TOWN_LEVEL, buildInfo.level )
        -- 纪念碑处理
        MSM.MonumentRoleMgr[_rid].post.setSchedule( _rid, { type = Enum.MonumentType.SERVER_CITY_LEVEL, level = buildInfo.level, count = 1 })
        local RechargeLogic = require "RechargeLogic"
        RechargeLogic:triggerLimitPackage( _rid, { type = Enum.LimitTimeType.TOWNHALL, level = buildInfo.level } )
        local s_CityAgeSize = CFG.s_CityAgeSize:Get()
        for _, cityAgeSize in pairs(s_CityAgeSize) do
            if cityAgeSize.townLevel == buildInfo.level then
                RechargeLogic:triggerLimitPackage( _rid, { type = Enum.LimitTimeType.AGE_CHANGE, age = cityAgeSize.age } )
            end
        end

        -- 角色等级升级到指定等级，删除玩家拥有的新手迁城道具
        local destoryCityRemoveLevel = CFG.s_Config:Get( "destoryCityRemoveLevel" ) or 0
        if buildInfo.level == destoryCityRemoveLevel then
            local cityRemoveItem1 = CFG.s_Config:Get( "cityRemoveItem1" ) or 0
            if cityRemoveItem1 > 0 then
                local _, itemNum = ItemLogic:checkItemEnough( _rid, cityRemoveItem1, 1 )
                if itemNum > 0 then
                    ItemLogic:delItemById( _rid, cityRemoveItem1, itemNum, nil, Enum.LogType.ROLE_LEVEL_DELETE_NOVICE_CITY )
                end
            end
        end
        -- 角色升级至指定等级，设置地狱活动信息
        if buildInfo.level == CFG.s_Config:Get("activityInfernalLevelLimit") then
            local ActivityLogic = require "ActivityLogic"
            local activityInfo = SM.ActivityMgr.req.getActivityInfo(80001)
            if activityInfo then
                local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
                ActivityLogic:activityStartReset( _rid, 80001, activity, activityInfo, {} )
                RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
                local synInfo = {}
                synInfo[Enum.Role.activity] = {[80001] = activity[80001]}
                -- 推送活动信息
                synInfo[Enum.Role.activityTimeInfo] = { [80001] = activityInfo }
                if not _isLogin then
                    RoleSync:syncSelf( _rid, synInfo, true )
                end
            end
        end

        -- 更新地图部队市政厅等级
        local ArmyLogic = require "ArmyLogic"
        local objectIndex
        local allArmy = ArmyLogic:getArmy( _rid ) or {}
        for armyIndex, armyInfo in pairs( allArmy ) do
            objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
            if objectIndex then
                MSM.SceneArmyMgr[objectIndex].post.syncArmyCityLevel( objectIndex, buildInfo.level )
            elseif ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                objectIndex = armyInfo.targetArg.targetObjectIndex or 0
                if objectIndex > 0 then
                    MSM.SceneResourceMgr[objectIndex].post.updateResourceInfo( objectIndex, { cityLevel = buildInfo.level } )
                end
            end
        end

    elseif buildInfo.type == Enum.BuildingType.WALL and buildInfo.level == 2 then
        -- 城墙
        -- local country = RoleLogic:getRole( _rid , Enum.Role.country)
        -- local heroId = CFG.s_Civilization:Get(country, "initialHero")
        -- HeroLogic:addHero( _rid, heroId, _isLogin )
    elseif buildInfo.type == Enum.BuildingType.SCOUT_CAMP then
        -- 斥候营地
        ScoutsLogic:addScoutsMax( _rid, _isLogin )
    elseif buildInfo.type == Enum.BuildingType.TAVERN then
        local sBuildingTavern = CFG.s_BuildingTavern:Get(buildInfo.level)
        if buildInfo.level == 1 then
            RoleLogic:setRole( _rid, { [Enum.Role.silverFreeCount] = sBuildingTavern.silverBoxCnt, [Enum.Role.openNextSilverTime] = os.time(),
                                [Enum.Role.goldFreeCount] = 1 } )
            if not _isLogin then
                RoleSync:syncSelf( _rid,  { [Enum.Role.silverFreeCount] = sBuildingTavern.silverBoxCnt, [Enum.Role.openNextSilverTime] = os.time(),
                [Enum.Role.goldFreeCount] = 1 }, true )
            end
        else
            local beforeConfig = CFG.s_BuildingTavern:Get(buildInfo.level - 1)
            local addCount = sBuildingTavern.silverBoxCnt - beforeConfig.silverBoxCnt
            if addCount > 0 then
                local silverFreeCount = RoleLogic:getRole( _rid, Enum.Role.silverFreeCount )
                RoleLogic:setRole( _rid, { [Enum.Role.silverFreeCount] = silverFreeCount + addCount } )
                if not _isLogin then
                    RoleSync:syncSelf( _rid, { [Enum.Role.silverFreeCount] = silverFreeCount + addCount }, true )
                end
            end
        end
    elseif buildInfo.type == Enum.BuildingType.STATION then
        -- 驿站
        RoleLogic:refreshPost( _rid )
    elseif buildInfo.type == Enum.BuildingType.GUARDTOWER then
        -- 警戒塔
        RoleLogic:guardTowerLevelUpCallback( _rid, buildInfo.level )
    end

    -- 同步改变
    if not _isLogin then
        RoleSync:syncSelf( _rid, roleInfoChange, true, true )
    end

    -- 计算角色最高战力
    RoleLogic:cacleSyncHistoryPower( _rid, roleInfo, _isLogin )
    -- 检查角色相关属性信息是否变化
    RoleCacle:checkRoleAttrChange( _rid, oldRoleInfo, roleInfo )

    -- 增加科技完成累计次数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.BUILDING_UPGRADE, Enum.TaskArgDefault, 1, _isLogin )
    -- 更新每日任务进度
    TaskLogic:updateTaskSchedule( _rid, { [Enum.TaskType.BUILDING_UPGRADE] = { arg = 0, addNum = 1 } }, _isLogin )

    if buildQueue then
        buildQueue[_queueIndex].buildingIndex = 0
        RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
        if not _isLogin then
            RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [_queueIndex] = buildQueue[_queueIndex] }}, true )
        end
    end
    local buildingId = buildInfo.type * 100 + buildInfo.level
    if buildInfo.level == 1 then
        LogLogic:buildCreate( { logType = Enum.LogType.BUILD_CREATE, buildingId = buildingId, costTime = costTime, iggid = roleInfo.iggid, rid = _rid } )
        self:initQueue( _rid, buildInfo.type, _isLogin )
    else
        LogLogic:buildCreate( { logType = Enum.LogType.BUILD_LEVEL_UP, buildingId = buildingId, costTime = costTime, iggid = roleInfo.iggid, rid = _rid } )
    end
    self:sendBuildingMail( _rid, buildInfo.type, buildInfo.level )
    -- 设置活动进度
    local count
    if buildInfo.level > 1 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_LEVEL_COUNT, 1, buildInfo.type )
    else
        count = table.size(BuildingLogic:getBuildingInfoByType( _rid, buildInfo.type ))
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_COUNT, count, buildInfo.type )
    end
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_TO_LEVEL )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_TO_LEVEL_COUNT )
    if buildInfo.type == Enum.BuildingType.FARM or buildInfo.type == Enum.BuildingType.WOOD or buildInfo.type == Enum.BuildingType.STONE
        or buildInfo.type == Enum.BuildingType.GOLD then
        count = BuildingLogic:getResBuilding( _rid, { Enum.BuildingType.FARM, Enum.BuildingType.WOOD, Enum.BuildingType.STONE, Enum.BuildingType.GOLD } )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.RES_BUILD_LEVEL, count, nil,nil, true )
    elseif buildInfo.type == Enum.BuildingType.BARRACKS or buildInfo.type == Enum.BuildingType.STABLE or buildInfo.type == Enum.BuildingType.ARCHERYRANGE
            or buildInfo.type == Enum.BuildingType.SIEGE then
        count = BuildingLogic:getResBuilding( _rid, { Enum.BuildingType.BARRACKS, Enum.BuildingType.STABLE, Enum.BuildingType.ARCHERYRANGE, Enum.BuildingType.SIEGE } )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_BUILD_LEVEL, count, nil,nil, true )
    end

    -- 判断战力变化
    local oldPower = 0
    if buildInfo.level > 1 then
        oldPower = CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + buildInfo.level - 1, "power" )
    end
    local newPow = CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + buildInfo.level, "power" )
    if newPow > oldPower then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_POWER_UP, newPow - oldPower )
    end
    -- 非联盟帮助减速完成
    if roleInfo.guildId and roleInfo.guildId > 0 and not _isGuildHelp and requestHelpIndex then
        MSM.GuildMgr[roleInfo.guildId].post.roleQueueFinishCallBack( roleInfo.guildId, requestHelpIndex, _isLogin )
    end

    -- 增加推送
    SM.PushMgr.post.sendPush( { pushRid = _rid, pushType = Enum.PushType.BUILD, args = { arg1 = buildInfo.type } })
end

---@see 升级联盟建筑回调
function BuildingLogic:upGradeBuildCallBack( _rid, _buildingIndex, _queueIndex, _isLogin, _isGuildHelp )
    MSM.RoleBuildQueueMgr[_rid].req.upGradeBuildCallBack( _rid, _buildingIndex, _queueIndex, _isLogin, _isGuildHelp )
end

---@see 同步建筑信息
function BuildingLogic:syncBuilding( _rid, _buildingIndex, _fields, _haskv, _block, _eventType, _eventArg )
    local syncBuilding = {}
    if _haskv then
        if not _buildingIndex then
            syncBuilding = _fields
        else
            _fields.buildingIndex = _buildingIndex
            syncBuilding[_buildingIndex] = _fields
        end
    elseif _buildingIndex then
        if not Common.isTable( _buildingIndex ) then _buildingIndex = { _buildingIndex } end
        local buildInfo
        for _, buildingIndex in pairs(_buildingIndex) do
            buildInfo = self:getBuilding( _rid, buildingIndex, _fields )
            buildInfo.buildingIndex = buildingIndex
            if _eventType then
                buildInfo.eventType = _eventType
                buildInfo.eventTypeEx = _eventArg
            end
            syncBuilding[buildingIndex] = buildInfo
        end
    else -- 推送全部建筑
        syncBuilding = self:getBuilding( _rid )
    end

    Common.syncMsg( _rid, "Build_BuildingInfo",  { buildingInfo = syncBuilding }, _block, _block )
end

local function Collision(r1, r2)
    -- body
    return not (r1.x1 >= r2.x2
        or r1.y1 >= r2.y2
        or r2.x1 >= r1.x2
        or r2.y1 >= r1.y2)
end

---@see 检查目标区域是否能放置建筑
function BuildingLogic:checkBuildingPut( _rid, _type, _x, _y, _noSelf )
    -- 判断是否超出边界
    local cityAgeSize = self:checkAge( _rid )
    local buildingConfig = CFG.s_BuildingTypeConfig:Get( _type )
    if math.abs(_x) > (cityAgeSize.size - 1)/2 or (_x + buildingConfig.width) > math.ceil(cityAgeSize.size/2) or
        math.abs(_y) > (cityAgeSize.size - 1)/2 or (_y + buildingConfig.length) > math.ceil(cityAgeSize.size/2) then
        return false
    end
    -- 判断是否和别的建筑重叠
    local buildings = self:getBuilding( _rid )
    local r2 = { x1 = _x , x2 = _x + buildingConfig.width, y1 = _y , y2= _y + buildingConfig.length }
    for _, building in pairs(buildings) do
        if building.type ~= Enum.BuildingType.WALL and building.type ~= Enum.BuildingType.GUARDTOWER then
            if not _noSelf or _noSelf ~= building.buildingIndex then
                local x = building.pos.x
                local y = building.pos.y
                buildingConfig = CFG.s_BuildingTypeConfig:Get( building.type )
                local r1 = { x1 = x , x2 = x + buildingConfig.width, y1 = y , y2= y + buildingConfig.length }
                if Collision(r1,r2) then
                    return false
                end
            end
        end
    end
    return true
end

function BuildingLogic:roleLoginCancelResources( _rid )
    BuildingLogic:cancleResourcesMax( _rid, Enum.BuildingType.FARM )
    BuildingLogic:cancleResourcesMax( _rid, Enum.BuildingType.WOOD  )
    BuildingLogic:cancleResourcesMax( _rid, Enum.BuildingType.STONE )
    BuildingLogic:cancleResourcesMax( _rid, Enum.BuildingType.GOLD )
end

---@see 判断某种资源类型的建筑满的时间
function BuildingLogic:cancleResourcesMax( _rid, _buildingType )
    local buildings = self:getBuildingInfoByType( _rid, _buildingType )
    local sBuildingResourcesProduce = CFG.s_BuildingResourcesProduce:Get()
    local addRate = 0
    local maxTime = 0
    local roleInfo =  RoleLogic:getRole( _rid )
    if _buildingType == Enum.BuildingType.FARM then
        addRate = roleInfo.foodCapacityMulti or 0
    elseif _buildingType == Enum.BuildingType.WOOD then
        addRate = roleInfo.woodCapacityMulti or 0
    elseif _buildingType == Enum.BuildingType.STONE then
        addRate = roleInfo.stoneCapacityMulti or 0
    elseif _buildingType == Enum.BuildingType.GOLD then
        addRate = roleInfo.glodCapacityMulti or 0
    end
    for _, buildingInfo in pairs(buildings) do
        local config = sBuildingResourcesProduce[buildingInfo.type][buildingInfo.level]
        local gatherMax = math.floor(config.gatherMax * ( 1000 + addRate ) / 1000)
        local time = math.floor(gatherMax / config.produceSpeed * 3600 / ( 1000 + addRate ) * 1000 + buildingInfo.lastRewardTime)
        if time > maxTime then
            maxTime = time
        end
    end
end

---@see buff导致资源变化
function BuildingLogic:changeBuildingGain( _rid, _name, _num )
    local building = self:getBuilding( _rid )
    local attrName = {}
    attrName[Enum.Role.foodCapacityMulti] = Enum.BuildingType.FARM
    attrName[Enum.Role.woodCapacityMulti] = Enum.BuildingType.WOOD
    attrName[Enum.Role.stoneCapacityMulti] = Enum.BuildingType.STONE
    attrName[Enum.Role.glodCapacityMulti] = Enum.BuildingType.GOLD
    local sBuildingResourcesProduce = CFG.s_BuildingResourcesProduce:Get()
    local synBuildInfo = {}
    for buildIndex, buildingInfo in pairs( building ) do
        if buildingInfo.type == attrName[_name] then
            local addNum
            local config = sBuildingResourcesProduce[buildingInfo.type] and sBuildingResourcesProduce[buildingInfo.type][buildingInfo.level] or {}
            if not table.empty( config ) then
                local gatherMax = math.floor(config.gatherMax * ( 1000 + _num ) / 1000)
                local buildingGainInfo = buildingInfo.buildingGainInfo
                if not buildingGainInfo then buildingGainInfo = { num = 0, changeTime = os.time() } end
                addNum = buildingGainInfo.num
                if addNum < gatherMax then
                    addNum = addNum + math.floor(config.produceSpeed / 3600 * ( os.time() - buildingGainInfo.changeTime ) * ( 1000 + _num ) / 1000)
                    if addNum > gatherMax then
                        addNum = gatherMax
                    end
                end
                buildingGainInfo.num = addNum
                buildingGainInfo.changeTime = os.time()
                buildingInfo.buildingGainInfo = buildingGainInfo
                synBuildInfo[buildIndex] = buildingInfo
                self:setBuilding( _rid, buildIndex, buildingInfo )
            end
        end
    end
    self:syncBuilding( _rid, nil , synBuildInfo, true )
end

---@see 领取资源
function BuildingLogic:awardResources( _rid, _buildingIndexs )
    local buildInfo
    local t = {}
    local totalNum = 0
    local synBuildInfo = {}
    local type
    local activityHarvestLimit = CFG.s_Config:Get("activityHarvestLimit")
    for _, index in pairs(_buildingIndexs) do
        buildInfo = self:getBuilding( _rid, index )
        type = buildInfo.type
        local sBuildingResourcesProduce = CFG.s_BuildingResourcesProduce:Get()
        if not table.empty(buildInfo) and buildInfo.level > 0 then
            local config = sBuildingResourcesProduce[buildInfo.type][buildInfo.level]
            local addRate = 0
            local roleInfo =  RoleLogic:getRole( _rid )
            if buildInfo.type == Enum.BuildingType.FARM then
                addRate = roleInfo.foodCapacityMulti or 0
            elseif buildInfo.type == Enum.BuildingType.WOOD then
                addRate = roleInfo.woodCapacityMulti or 0
            elseif buildInfo.type == Enum.BuildingType.STONE then
                addRate = roleInfo.stoneCapacityMulti or 0
            elseif buildInfo.type == Enum.BuildingType.GOLD then
                addRate = roleInfo.glodCapacityMulti or 0
            end
            local addNum
            local gatherMax = math.floor(config.gatherMax * ( 1000 + addRate ) / 1000)
            local buildingGainInfo = buildInfo.buildingGainInfo
            if not buildingGainInfo then buildingGainInfo = { num = 0, changeTime = os.time() } end
            addNum = buildingGainInfo.num
            if addNum < gatherMax then
                addNum = addNum + math.floor(config.produceSpeed / 3600 * ( os.time() - buildingGainInfo.changeTime ) * ( 1000 + addRate ) / 1000)
                if addNum > gatherMax then
                    addNum = gatherMax
                end
            end
            table.insert( t, { buildingIndex = index, addNum = addNum } )
            buildingGainInfo.changeTime = os.time()
            buildingGainInfo.num = 0
            buildInfo.buildingGainInfo = buildingGainInfo
            MSM.d_building[_rid].req.Set( _rid, index, buildInfo )
            synBuildInfo[index] = buildInfo
            totalNum = totalNum + addNum
            -- 掉落活动修改
            if addNum >= activityHarvestLimit then
                local sActivityReapType = CFG.s_ActivityReapType:Get(buildInfo.level)
                local count = 0
                local Random = require "Random"
                local requireNum = sActivityReapType.times * config.produceSpeed
                while true do
                    if addNum < requireNum then
                        local rate = math.floor(addNum / requireNum * 100 )
                        if rate < 1 then rate = 1 end
                        local randomRate = Random.Get(1, 100)
                        if rate > randomRate then
                            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.CITY_COLLECTION_ACTION, 1 )
                        end
                        break
                    else
                        addNum = addNum - requireNum
                        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.CITY_COLLECTION_ACTION, 1 )
                        count = count + 1
                        if count >= sActivityReapType.timesMax then
                            break
                        end
                    end
                end
            end
        end
    end
    --- 增加对应资源
    local resourceType
    if type == Enum.BuildingType.FARM then
        RoleLogic:addFood( _rid, totalNum, nil, Enum.LogType.CITY_GAIN_CURRENCY )
        resourceType = Enum.ResourceType.FARMLAND
    elseif type == Enum.BuildingType.WOOD then
        RoleLogic:addWood( _rid, totalNum, nil, Enum.LogType.CITY_GAIN_CURRENCY )
        resourceType = Enum.ResourceType.WOOD
    elseif type == Enum.BuildingType.STONE then
        RoleLogic:addStone( _rid, totalNum, nil, Enum.LogType.CITY_GAIN_CURRENCY )
        resourceType = Enum.ResourceType.STONE
    elseif type == Enum.BuildingType.GOLD then
        RoleLogic:addGold( _rid, totalNum, nil, Enum.LogType.CITY_GAIN_CURRENCY )
        resourceType = Enum.ResourceType.GOLD
    end
    self:syncBuilding( _rid, nil , synBuildInfo, true )

    -- 增加任务统计信息
    local TaskLogic = require "TaskLogic"
    local taskType = Enum.TaskType.CITY_RESOURCE
    TaskLogic:addTaskStatisticsSum( _rid, taskType, resourceType, totalNum, true )
    TaskLogic:addTaskStatisticsSum( _rid, taskType, Enum.TaskArgDefault, totalNum )
    -- 更新每日任务进度
    TaskLogic:updateTaskSchedule( _rid, { [taskType] = { arg = resourceType, addNum = totalNum } } )
    -- 设置活动进度
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.CITY_COLLECTION_NUM, totalNum )
    --return { rewardResources = t }
    return { result = 1 }
end

---@see 检测建筑队列状态
function BuildingLogic:checkBuildQueue( _rid )
    local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
    for _, queue in pairs(buildQueue) do
        if queue.finishTime > 0 and queue.finishTime < os.time() then
            self:upGradeBuildCallBack( _rid, queue.buildingIndex, queue.queueIndex, true )
        elseif queue.finishTime > 0 and queue.timerId and queue.timerId > 0 and not MSM.RoleTimer[_rid].req.checkBuildTimer( _rid, queue.timerId ) then
            buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
            buildQueue[queue.queueIndex].timerId = MSM.RoleTimer[_rid].req.addBuildTimer( _rid, queue.finishTime, queue.buildingIndex, queue.queueIndex )
            RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
        end
    end

    local buildIndexs = {}
    for _, queue in pairs(buildQueue) do
        if queue.buildingIndex and queue.buildingIndex > 0 then buildIndexs[queue.buildingIndex] = queue.buildingIndex end
    end
    local buildingInfo = BuildingLogic:getBuilding( _rid )
    for buildIndex, buildInfo in pairs( buildingInfo ) do
        if buildInfo.finishTime > 0 then
            if not buildIndexs[buildIndex] then
                buildInfo.finishTime = -1
                if buildInfo.level == 0 then
                    buildInfo.level = buildInfo.level + 1
                end
                MSM.d_building[_rid].req.Set( _rid, buildIndex, buildInfo )
            end
        end
    end
end

---@see 建筑加速
function BuildingLogic:speedUp( _rid, _queueIndex, _sec, _isGuildHelp )
    local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
    buildQueue[_queueIndex].finishTime = buildQueue[_queueIndex].finishTime - _sec
    MSM.RoleTimer[_rid].req.deleteBuildTimer( _rid, buildQueue[_queueIndex].timerId )
    local finishTime = 0
    if buildQueue[_queueIndex].finishTime > 0 and buildQueue[_queueIndex].finishTime <= os.time() then
        self:upGradeBuildCallBack( _rid, buildQueue[_queueIndex].buildingIndex, _queueIndex, nil, _isGuildHelp )
    elseif buildQueue[_queueIndex].finishTime and buildQueue[_queueIndex].finishTime > os.time() then
        finishTime = MSM.RoleBuildQueueMgr[_rid].req.updateBuildTimer( _rid, _queueIndex, _sec )
    end
    -- 设置活动进度
    if not _isGuildHelp then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USE_SPEED_MIN, _sec/60 )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USE_SPEED_MIN_IN_BUIND, _sec/60 )
    end
    return finishTime
end

---@see 发送建筑升级邮件
function BuildingLogic:sendBuildingMail( _rid, _buildingType, _level )
    local sBuildingMail = CFG.s_BuildingMail:Get()
    if not sBuildingMail[_buildingType] then return end
    local emailId = sBuildingMail[_buildingType][_level]
    if emailId then
        local buildMailId = RoleLogic:getRole( _rid, Enum.Role.buildMailId ) or {}
        if not _rid then _rid = 0 end
        LOG_INFO( "rid(%d)", _rid)
        if table.exist( buildMailId, emailId ) then
            return
        end
        table.insert( buildMailId, emailId )
        RoleLogic:setRole( _rid, { [Enum.Role.buildMailId] = buildMailId } )
        local EmailLogic = require "EmailLogic"
        EmailLogic:sendEmail( _rid, emailId )
    end
end

---@see 开启白银宝箱
function BuildingLogic:openSilver( _rid, _free, _count, _useDenar )
    -- 如果是免费则扣除免费次数,并且记录开启时间
    if _free then
         -- 扣除许愿次数
        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.silverFreeCount } )
        local roleChangeInfo = {}
        roleChangeInfo[Enum.Role.silverFreeCount] = roleInfo.silverFreeCount - 1
        roleChangeInfo[Enum.Role.openNextSilverTime] = os.time() + CFG.s_Config:Get("silverBoxCD")
        RoleLogic:setRole( _rid, roleChangeInfo )
        RoleSync:syncSelf( _rid, roleChangeInfo, true )
        _count = 1
    else
        if _count == 1 then
            local itemId = CFG.s_Config:Get("silverBoxOpenItem")
            local sItemInfo = CFG.s_Item:Get(itemId)
            if not _useDenar then
                if ItemLogic:checkItemEnough( _rid, itemId, CFG.s_Config:Get("silverBoxOpenItemNum") * _count ) then
                    local syncItems = ItemLogic:delItemById( _rid, itemId, CFG.s_Config:Get("silverBoxOpenItemNum") * _count, true, Enum.LogType.OPEN_SILVER_BOX_COST_ITEM )
                    -- 通知客户端
                    ItemLogic:syncItem( _rid, nil, syncItems, true, true )
                end
            else
                if RoleLogic:checkDenar( _rid, sItemInfo.shopPrice ) then
                    RoleLogic:addDenar( _rid, -sItemInfo.shopPrice, nil, Enum.LogType.TAVERN_OPEN_SILVER_COST_DENAR )
                end
            end
        else
            local syncItems = ItemLogic:delItemById( _rid, CFG.s_Config:Get("silverBoxOpenItem"), CFG.s_Config:Get("silverBoxOpenItemNum") * _count, true, Enum.LogType.OPEN_SILVER_BOX_COST_ITEM )
            -- 通知客户端
            ItemLogic:syncItem( _rid, nil, syncItems, true, true )
        end
    end
    local rewardInfo
    local groupId = CFG.s_Config:Get("silverBoxItemPackage")
    if _count == 1 then
        rewardInfo = ItemLogic:getItemPackage( _rid, groupId, nil, nil, true, true, true )
    else
        -- for _ = 1 , _count do
        --     ItemLogic:mergeReward(rewardInfo,ItemLogic:getItemPackage( _rid, groupId, nil, nil, true ))
        -- end
        rewardInfo = ItemLogic:getItemPackage( _rid, groupId, nil, nil, true, nil, nil, nil, _count, true )
    end
    -- 更新角色累计打开白银宝箱个数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.TAVERN_BOX, Enum.TaskTavernBoxType.SILVER, _count )
    -- 更新每日任务进度
    TaskLogic:updateTaskSchedule( _rid, { [Enum.TaskType.TAVERN_BOX] = { arg = Enum.TaskTavernBoxType.SILVER, addNum = _count } } )

    return { rewardInfo = rewardInfo, count = _count, type = Enum.BoxType.SILVER }
end

---@see 跨天恢复白银箱子次数
function BuildingLogic:resetSilver( _rid, _isLogin )
    local level = self:getBuildingLv( _rid, Enum.BuildingType.TAVERN )
    if level <= 0 then
        return
    end
    local sBuildingTavern = CFG.s_BuildingTavern:Get(level)
    local roleChangeInfo = {}
    roleChangeInfo[Enum.Role.silverFreeCount] = sBuildingTavern.silverBoxCnt
    roleChangeInfo[Enum.Role.openNextSilverTime] = os.time()
    RoleLogic:setRole( _rid, roleChangeInfo )
    if not _isLogin then
        RoleSync:syncSelf( _rid, roleChangeInfo, true )
    end
end

---@see 开启金宝箱
function BuildingLogic:openGold( _rid, _free, _count, __useDenar )
    if _free then
        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.goldFreeCount } )
        -- 扣除许愿次数
        local roleChangeInfo = {}
        roleChangeInfo[Enum.Role.goldFreeCount] = roleInfo.goldFreeCount - 1
        RoleLogic:setRole( _rid, roleChangeInfo )
        RoleSync:syncSelf( _rid, roleChangeInfo, true )
        -- 判断是否增加定时器
        self:addGoldFreeWishTimer( _rid )
        _count = 1
    else
        if _count == 1 then
            local itemId = CFG.s_Config:Get("goldBoxOpenItem")
            local sItemInfo = CFG.s_Item:Get(itemId)
            if not __useDenar then
                if ItemLogic:checkItemEnough( _rid, itemId, CFG.s_Config:Get("goldBoxOpenItemNum") * _count ) then
                    local syncItems = ItemLogic:delItemById( _rid, itemId, CFG.s_Config:Get("goldBoxOpenItemNum") * _count, true, Enum.LogType.OPEN_SILVER_BOX_COST_ITEM )
                    -- 通知客户端
                    ItemLogic:syncItem( _rid, nil, syncItems, true, true )
                end
            else
                if RoleLogic:checkDenar( _rid, sItemInfo.shopPrice ) then
                    RoleLogic:addDenar( _rid, -sItemInfo.shopPrice, nil, Enum.LogType.TAVERN_OPEN_GOLD_COST_DENAR )
                end
            end
        else
            local syncItems = ItemLogic:delItemById( _rid, CFG.s_Config:Get("goldBoxOpenItem"), CFG.s_Config:Get("goldBoxOpenItemNum") * _count, true, Enum.LogType.OPEN_SILVER_BOX_COST_ITEM )
            -- 通知客户端
            ItemLogic:syncItem( _rid, nil, syncItems, true, true )
        end
    end
    local rewardInfo
    local groupId = CFG.s_Config:Get("goldBoxItemPackage")
    local firstOpenGold = RoleLogic:getRole( _rid, Enum.Role.firstOpenGold )
    if not firstOpenGold then
        groupId = CFG.s_Config:Get("goldBoxFirstReward")
        RoleLogic:setRole( _rid, Enum.Role.firstOpenGold, true )
    end

    if _count == 1 then
        rewardInfo = ItemLogic:getItemPackage( _rid, groupId, nil, nil, true, true, true )
    else
        -- for _ = 1, _count do
        --     ItemLogic:mergeReward(rewardInfo,ItemLogic:getItemPackage( _rid, groupId, nil, nil, true ))
        -- end
        rewardInfo = ItemLogic:getItemPackage( _rid, groupId, nil, nil, true, nil, nil, nil, _count, true )
    end
    -- 更新角色累计打开黄金宝箱个数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.TAVERN_BOX, Enum.TaskTavernBoxType.GOLD, _count )
    -- 更新每日任务进度
    TaskLogic:updateTaskSchedule( _rid, { [Enum.TaskType.TAVERN_BOX] = { arg = Enum.TaskTavernBoxType.GOLD, addNum = _count } } )
    -- 登陆设置活动进度
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.GOLD_BOX, _count )
    return { rewardInfo = rewardInfo, count = _count, type = Enum.BoxType.GOLD }
end

---@see 增加黄金宝箱定时器
function BuildingLogic:addGoldFreeWishTimer( _rid, _isLogin )
    local level = self:getBuildingLv( _rid, Enum.BuildingType.TAVERN )
    if level <= 0 then
        return
    end
    local sBuildingTavern = CFG.s_BuildingTavern:Get(level)
    if not MSM.RoleTimer[_rid].req.getGoldFreeTimer( _rid ) then
        local goldBoxCD = sBuildingTavern.goldBoxCD
        local time = os.time() + goldBoxCD
        MSM.RoleTimer[_rid].req.addGoldFreeTimer( _rid, time )
        local roleChangeInfo = {}
        roleChangeInfo[Enum.Role.addGoldFreeAddTime] = time
        RoleLogic:setRole( _rid, roleChangeInfo )
        if not _isLogin then
            RoleSync:syncSelf( _rid, { [Enum.Role.addGoldFreeAddTime] = time }, true )
        end
    end
end

---@see 增加黄金免费抽奖次数
function BuildingLogic:addGoldFreeCount( _rid, _count, _isLogin )
    local goldFreeCount = RoleLogic:getRole( _rid, Enum.Role.goldFreeCount )
    goldFreeCount = goldFreeCount + _count
    if goldFreeCount >= 1 then
        goldFreeCount = 1
        -- 判断次数是否都满了，如果满了移除定时器
        MSM.RoleTimer[_rid].req.delCommonFreeTimer( _rid )
    end
    local roleChangeInfo = {}
    roleChangeInfo[Enum.Role.goldFreeCount] = goldFreeCount
    roleChangeInfo[Enum.Role.addGoldFreeAddTime] = 0
    RoleLogic:setRole( _rid, roleChangeInfo )
    if not _isLogin then
        RoleSync:syncSelf( _rid, roleChangeInfo, true )
    end
end

---@see 登录增加普通免费抽奖次数
function BuildingLogic:addGoldFreeOnLogin( _rid, _isLogin )
    --- 未解锁不处理
    if not self:getBuildingInfoByType( _rid, Enum.BuildingType.TAVERN ) then
        return
    end
    -- 判断次数是否到达上限
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.goldFreeCount, Enum.Role.addGoldFreeAddTime } )
    if roleInfo.goldFreeCount >= 1 then
        return
    end
    if roleInfo.addGoldFreeAddTime <= os.time() then
        self:addGoldFreeCount( _rid, 1, _isLogin )
    else
        if not MSM.RoleTimer[_rid].req.getGoldFreeTimer( _rid ) then
            MSM.RoleTimer[_rid].req.addGoldFreeTimer( _rid, roleInfo.addGoldFreeAddTime )
        end
    end
end

---@see 警戒塔hp为0的时候城墙开始燃烧
function BuildingLogic:startBurnWall( _rid )
    local buildInfo = self:getBuildingInfoByType( _rid, Enum.BuildingType.WALL )[1]
    if not buildInfo then
        return false
    end
    if not self:checkWallBurn( _rid ) and MSM.RoleTimer[_rid].req.getWallBurnTimer( _rid ) then
        MSM.RoleTimer[_rid].req.delWallBurnTimer( _rid )
    end
    if not self:checkWallBurn( _rid ) then
        buildInfo.beginBurnTime = os.time()
        MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
        MSM.RoleTimer[_rid].req.addWallBurnTimer( _rid, os.time())
    end
    buildInfo.beginBurnTime = os.time()
    MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
    self:syncBuilding( _rid, buildInfo.buildingIndex, buildInfo, true, true )
    local objectIndex = RoleLogic:getRoleCityIndex( _rid )
    MSM.SceneCityMgr[objectIndex].post.updateCityBeginBurnTime( objectIndex, buildInfo.beginBurnTime )
end

---@see 扣除城墙耐久
function BuildingLogic:cancelWallHp( _rid, _isLogin )
    local buildInfo = self:getBuildingInfoByType( _rid, Enum.BuildingType.WALL )[1]
    if not buildInfo then
        return false
    end
    local beginBurnTime = buildInfo.beginBurnTime
    if not self:checkWallBurn( _rid ) then
        buildInfo.beginBurnTime = os.time()
    end
    buildInfo.lostHp = ( buildInfo.lostHp or 0 ) + CFG.s_Config:Get("cityWallBurnDurability")
    buildInfo.lastBurnTime = os.time()
    -- 判断如果耐久值为0，则进行迁城处理
    local s_BuildingCityWall = CFG.s_BuildingCityWall:Get(buildInfo.level)
    local objectIndex = RoleLogic:getRoleCityIndex( _rid )
    if s_BuildingCityWall.wallDurableMax <= buildInfo.lostHp then
        if MSM.RoleTimer[_rid].req.getWallBurnTimer( _rid ) then
            MSM.RoleTimer[_rid].req.delWallBurnTimer( _rid )
        end
        buildInfo.lostHp = 0
        buildInfo.beginBurnTime = 0
        buildInfo.lastBurnTime = 0
        beginBurnTime = 0
        MSM.SceneCityMgr[objectIndex].post.updateCityBeginBurnTime( objectIndex, buildInfo.beginBurnTime )
        RoleLogic:forceMoveCity( _rid )
    end
    if beginBurnTime and beginBurnTime > 0 and os.time() - beginBurnTime >= CFG.s_Config:Get("cityWallBurnTime") then
        if MSM.RoleTimer[_rid].req.getWallBurnTimer( _rid ) then
            MSM.RoleTimer[_rid].req.delWallBurnTimer( _rid )
        end
        buildInfo.beginBurnTime = 0
        buildInfo.lastBurnTime = 0
        MSM.SceneCityMgr[objectIndex].post.updateCityBeginBurnTime( objectIndex, buildInfo.beginBurnTime )
    elseif beginBurnTime and beginBurnTime > 0 then
        MSM.RoleTimer[_rid].req.addWallBurnTimer( _rid, os.time() + 60 )
    end
    MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
    if not _isLogin then
        self:syncBuilding( _rid, buildInfo.buildingIndex, buildInfo, true, true )
    end
    -- 角色城市燃烧时间更新
    MSM.SceneCityMgr[objectIndex].post.updateCityBeginBurnTime( objectIndex, buildInfo.beginBurnTime )
end

---@see 判断城墙是否处于燃烧状态
function BuildingLogic:checkWallBurn( _rid )
    local buildInfo = self:getBuildingInfoByType( _rid, Enum.BuildingType.WALL )[1]
    if not buildInfo or not buildInfo.beginBurnTime then
        return false
    end
    if buildInfo.beginBurnTime > 0 and buildInfo.beginBurnTime + CFG.s_Config:Get("cityWallBurnTime") >= os.time() then
        return true
    end
    return false
end

---@see 驻防修改
function BuildingLogic:changeDefendHero( _rid, _noSync )
    local ArmyLogic = require "ArmyLogic"
    local roleInfo = RoleLogic:getRole( _rid )
    local heros = HeroLogic:getHero( _rid )
    local heroKeyList = {}
    local heroKey

    local userHeroIds = {}
    if roleInfo.userMainHeroId > 0 then
        table.insert( userHeroIds, roleInfo.userMainHeroId )
    end
    if roleInfo.userDeputyHeroId > 0 then
        table.insert( userHeroIds, roleInfo.userDeputyHeroId )
    end

    roleInfo.mainHeroId = 0
    roleInfo.deputyHeroId = 0

    for _, heroInfo in pairs(heros) do
        if not table.exist(userHeroIds, heroInfo.heroId ) and ArmyLogic:checkHeroStatue( _rid, heroInfo.heroId ) then
            local sHero = CFG.s_Hero:Get(heroInfo.heroId)
            heroKey = ( heroInfo.level or 0 ) * 1000000 + ( sHero.rare or 0 ) * 10000
            table.insert( heroKeyList, { key = heroKey, id = heroInfo.heroId } )
        end
    end
    local count = 1
    table.sort( heroKeyList, function ( a, b )
        -- 按照觉醒等级>进阶等级>等级>品质排序
        return a.key > b.key
    end )

    local sortHeroList = {}
    for i=1,table.size(userHeroIds) do
        if ArmyLogic:checkHeroStatue( _rid, userHeroIds[i] ) then
            table.insert( sortHeroList, userHeroIds[i] )
        end
    end

    for i=1,table.size(heroKeyList) do
        if ArmyLogic:checkHeroStatue( _rid, heroKeyList[i].id ) then
            table.insert( sortHeroList, heroKeyList[i].id )
        end
    end

    if sortHeroList[count] then
        roleInfo.mainHeroId = sortHeroList[count]
        count = count + 1
    end
    if sortHeroList[count] then
        roleInfo.deputyHeroId = sortHeroList[count]
    end

    RoleLogic:setRole( _rid, { [Enum.Role.mainHeroId] = roleInfo.mainHeroId, [Enum.Role.deputyHeroId] = roleInfo.deputyHeroId } )
    if not _noSync then
        RoleSync:syncSelf( _rid, { [Enum.Role.mainHeroId] = roleInfo.mainHeroId, [Enum.Role.deputyHeroId] = roleInfo.deputyHeroId }, true )
    end
    -- 换防处理
    HeroLogic:changeDefenseHeroCallback( _rid, roleInfo.mainHeroId, roleInfo.deputyHeroId )
end

---@see 服务器重启处理
function BuildingLogic:serverResetWall( _rid, objectIndex )
    local buildInfo = self:getBuildingInfoByType( _rid, Enum.BuildingType.WALL )[1]
    if not buildInfo or not buildInfo.beginBurnTime or buildInfo.beginBurnTime <= 0 then
        return
    end
    if MSM.RoleTimer[_rid].req.getWallBurnTimer( _rid ) then
        return
    end
    if not buildInfo.lastBurnTime then buildInfo.lastBurnTime = buildInfo.beginBurnTime end
    -- 如果燃烧时间已经超过30分钟
    if os.time() >= buildInfo.lastBurnTime + CFG.s_Config:Get("cityWallBurnTime") then
        local time = os.time() - buildInfo.lastBurnTime
        if time > CFG.s_Config:Get("cityWallBurnTime") then time = CFG.s_Config:Get("cityWallBurnTime") end
        local lostHp = time / 60 // 1 * CFG.s_Config:Get("cityWallBurnDurability")
        buildInfo.lostHp = (buildInfo.lostHp or 0) + lostHp
        buildInfo.beginBurnTime = 0
        buildInfo.lastBurnTime = 0
        local s_BuildingCityWall = CFG.s_BuildingCityWall:Get(buildInfo.level)
        if s_BuildingCityWall.wallDurableMax <= buildInfo.lostHp then
            if MSM.RoleTimer[_rid].req.getWallBurnTimer( _rid ) then
                MSM.RoleTimer[_rid].req.delWallBurnTimer( _rid )
            end
            buildInfo.lostHp = 0
            MSM.SceneCityMgr[objectIndex].post.updateCityBeginBurnTime( objectIndex, buildInfo.beginBurnTime )
            RoleLogic:forceMoveCity( _rid )
        end
    else
        local time = (os.time() - buildInfo.lastBurnTime) / 60 // 1
        local timel = os.time() - buildInfo.lastBurnTime - 60 * time
        local lostHp = time * CFG.s_Config:Get("cityWallBurnDurability")
        buildInfo.lostHp = (buildInfo.lostHp or 0)+ lostHp
        buildInfo.lastBurnTime = os.time()
        MSM.RoleTimer[_rid].req.addWallBurnTimer( _rid, os.time() + 60 - timel )
    end
    MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
end

---@see 解锁第二队列实现
function BuildingLogic:unlockQueueImpl( _rid, _addSec, _roleInfo, _isLogin )
    local buildQueue
    local status
    if not _roleInfo then
        buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
    else
        buildQueue = _roleInfo.buildQueue
    end
    if table.size(buildQueue) == 1 then
        local queueIndex = self:getFreeBuildQueueIndex( _rid )
        buildQueue[queueIndex] = {
            queueIndex = queueIndex,
            main = false,
            expiredTime = os.time(),
            finishTime = -1,
        }
    end
    for _, queueInfo in pairs(buildQueue) do
        if queueInfo.expiredTime > 0 then
            if _addSec < 0 then
                queueInfo.expiredTime = -1
            elseif queueInfo.expiredTime > os.time() then
                queueInfo.expiredTime = queueInfo.expiredTime + _addSec
                status = 2
            elseif queueInfo.expiredTime <= os.time() then
                queueInfo.expiredTime = os.time() + _addSec
                status = 1
            end
        end
        RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
        if not _isLogin then
            RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [queueInfo.queueIndex] = queueInfo } }, true )
        end
    end
    return status
end

---@see 解锁第二队列
function BuildingLogic:unlockQueue( _rid, _addSec, _roleInfo, _isLogin )
    return MSM.RoleBuildQueueMgr[_rid].req.unlockQueue( _rid, _addSec, _roleInfo, _isLogin )
end

---@see 获取仓库保护量
---@return defaultWarEhourseAttrClass
function BuildingLogic:getWarEhouseProtect( _rid )
    local buildInfo = self:getBuildingInfoByType( _rid, Enum.BuildingType.WAREHOUSE )
    if buildInfo then
        local sBuildingStorage = CFG.s_BuildingStorage:Get( buildInfo[1].level )
        if sBuildingStorage then
            local roleInfo = RoleLogic:getRole( _rid )
            return {
                foodProtect = sBuildingStorage.foodCnt + math.floor( sBuildingStorage.foodCnt * roleInfo.resourcesProtectSpaceMulti / 1000 ),
                woodProtect = sBuildingStorage.woodCnt + math.floor( sBuildingStorage.woodCnt * roleInfo.resourcesProtectSpaceMulti / 1000 ),
                stoneProtect = sBuildingStorage.stoneCnt + math.floor( sBuildingStorage.stoneCnt * roleInfo.resourcesProtectSpaceMulti / 1000 ),
                goldProtect = sBuildingStorage.goldCnt + math.floor( sBuildingStorage.goldCnt * roleInfo.resourcesProtectSpaceMulti / 1000 ),
            }
        end
    else
        return BuildDef:getDefaultWarEhourseAttr()
    end
end

---@see 定时恢复警戒塔血量
function BuildingLogic:addGuardTowerHpOnTimer( _rid )
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    if not cityIndex then
        return
    end
    -- 如果城市正在被攻击,不处理
    local cityInfo = MSM.SceneCityMgr[cityIndex].req.getCityInfo( cityIndex )
    local ArmyLogic = require "ArmyLogic"
    if cityInfo and not ArmyLogic:checkArmyStatus( cityInfo.status, Enum.ArmyStatus.BATTLEING ) then
        -- 恢复1%
        local guardTowerHp = RoleLogic:getRole( _rid, Enum.Role.guardTowerHp )
        local buildInfo = self:getBuildingInfoByType( _rid, Enum.BuildingType.GUARDTOWER )
        if buildInfo then
            local sBuildingGuardTower = CFG.s_BuildingGuardTower:Get( buildInfo[1].level )
            if guardTowerHp < sBuildingGuardTower.warningTowerHpMax then
                guardTowerHp = math.floor( guardTowerHp + ( sBuildingGuardTower.warningTowerHpMax * 0.01 ) )
                if guardTowerHp > sBuildingGuardTower.warningTowerHpMax then
                    guardTowerHp = sBuildingGuardTower.warningTowerHpMax
                end
                -- 设置警戒塔血量
                RoleLogic:setRole( _rid, Enum.Role.guardTowerHp, guardTowerHp )
                -- 通知客户端
                RoleSync:syncSelf( _rid, { [Enum.Role.guardTowerHp] = guardTowerHp }, true )
            end
        end
    end
end

---@see 材料定时器结束回调
function BuildingLogic:produceMaterialCallBack( _rid, _isLogin )
    local materialQueue = RoleLogic:getRole( _rid, Enum.Role.materialQueue )
    local produceItems = materialQueue.produceItems or {}
    local completeItems = materialQueue.completeItems or {}
    table.insert(completeItems, produceItems[1])
    table.remove(produceItems,1)
    materialQueue.produceItems = produceItems
    if table.size(produceItems) > 0 then
        materialQueue.beginTime = materialQueue.finishTime
        materialQueue.finishTime = materialQueue.finishTime + CFG.s_Config:Get("equipMaterialMakeTime")
    else
        materialQueue.beginTime = 0
        materialQueue.finishTime = 0
    end
    materialQueue.completeItems = completeItems
    RoleLogic:setRole( _rid, { [Enum.Role.materialQueue] = materialQueue } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.materialQueue] = materialQueue }, true )
    end
    --重新增加定时器
    if table.size(produceItems) > 0 then
        if _isLogin and materialQueue.finishTime > os.time() then _isLogin = false end
        MSM.RoleTimer[_rid].req.addProduceTimer( _rid, materialQueue.finishTime, _isLogin )
    end
end

---@see 检测材料队列状态
function BuildingLogic:checkMaterialQueue( _rid )
    local materialQueue = RoleLogic:getRole( _rid, Enum.Role.materialQueue ) or {}
    if materialQueue.finishTime and materialQueue.finishTime > 0 then
        MSM.RoleTimer[_rid].req.addProduceTimer( _rid, materialQueue.finishTime )
    end
end

---@see 返回本次锻造装备需要的道具列表
function BuildingLogic:cancleMaterial( _rid, _itemId )
    local sEquip = CFG.s_Equip:Get( _itemId )
    local makeMaterial = sEquip.makeMaterial or {}
    local makeMaterialNum = sEquip.makeMaterialNum or {}
    local itemInfo = {}
    local draw = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.DRAW ) or {}
    local material = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.MATERIAL ) or {}

    for i=1,table.size(makeMaterial) do
        local itemId = makeMaterial[i]
        if draw[itemId] then
            -- 图纸
            local _, num = ItemLogic:checkItemEnough( _rid, itemId, 0 )
            if num >= makeMaterialNum[i] then
                itemInfo[itemId] = makeMaterialNum[i]
            else
                if not ItemLogic:checkItemEnough( _rid, draw[itemId].itemID, draw[itemId].mixCostNum * makeMaterialNum[i] ) then
                    return false
                end
                itemInfo[draw[itemId].itemID] = draw[itemId].mixCostNum * makeMaterialNum[i]
            end
        else
            --材料
            local _, num = ItemLogic:checkItemEnough( _rid, itemId, 0 )
            if num >= makeMaterialNum[i] then
                itemInfo[itemId] = makeMaterialNum[i]
            else
                local sEquipMaterial = CFG.s_EquipMaterial:Get(itemId)
                if sEquipMaterial.rare == 1 then
                    return false
                else
                    local materialGroup = material[sEquipMaterial.group]
                    itemInfo[itemId] = num
                    local count = makeMaterialNum[i] - num
                    local orderRare = sEquipMaterial.rare
                    for rare = sEquipMaterial.rare - 1, 1, -1 do
                        itemId = materialGroup[rare].itemID
                        local needCount = count * materialGroup[orderRare].add/materialGroup[rare].add
                        _, num = ItemLogic:checkItemEnough( _rid, itemId, 0 )
                        if num >= needCount then
                            itemInfo[itemId] = needCount
                            break
                        elseif rare == 1 then
                            return false
                        else
                            orderRare = rare
                            count = needCount - num
                            itemInfo[itemId] = num
                        end
                    end
                end
            end
        end
    end
    return true, itemInfo
end

---@see 获取城墙耐久和上限
function BuildingLogic:getCityWallHp( _rid )
    local buildInfo = self:getBuildingInfoByType( _rid, Enum.BuildingType.WALL )[1]
    local sBuildingCityWall = CFG.s_BuildingCityWall:Get(buildInfo.level)

    return sBuildingCityWall.wallDurableMax - ( buildInfo.lostHp or 0 ), sBuildingCityWall.wallDurableMax
end

---@see 获取可掠夺资源
function BuildingLogic:getRoleRobResource( _rid )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.food, Enum.Role.wood, Enum.Role.stone, Enum.Role.gold } )
    local buildRewards = MSM.BuildingRoleMgr[_rid].req.awardResources( _rid, nil, Enum.RoleResourcesAction.SCOUT )
    local resourceProtect = self:getWarEhouseProtect( _rid )
    local robFood = roleInfo.food - resourceProtect.foodProtect + buildRewards.food
    if robFood < 0 then
        robFood = nil
    end
    local robWood = roleInfo.wood - resourceProtect.woodProtect + buildRewards.wood
    if robWood < 0 then
        robWood = nil
    end
    local robStone = roleInfo.stone - resourceProtect.stoneProtect + buildRewards.stone
    if robStone < 0 then
        robStone = nil
    end
    local robGold = roleInfo.gold - resourceProtect.goldProtect + buildRewards.gold
    if robGold < 0 then
        robGold = nil
    end
    return {
        robFood = robFood,
        robWood = robWood,
        robStone = robStone,
        robGold = robGold,
    }
end

return BuildingLogic