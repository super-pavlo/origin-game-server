--[[
* @file : GuildBuildLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Mon Apr 20 2020 10:39:33 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟建筑相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildBuildDef = require "GuildBuildDef"
local GuildLogic = require "GuildLogic"
local ArmyLogic = require "ArmyLogic"
local RoleLogic = require "RoleLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local DenseFogLogic = require "DenseFogLogic"
local MapObjectLogic = require "MapObjectLogic"
local MapLogic = require "MapLogic"
local CommonCacle = require "CommonCacle"
local LogLogic = require "LogLogic"

local GuildBuildLogic = {}

local buildObjectTypes, buildRoleTypes
local resourceRoleCurrencys, resourceGuildCurrency
local resourceRoleCurrencyToBuildTypes, resourceGuildCurrencyToBuildTypes

local function checkBuildObjectTypes()
    if buildObjectTypes and buildRoleTypes then return end

    buildObjectTypes = {}
    buildObjectTypes[Enum.GuildBuildType.CENTER_FORTRESS] = Enum.RoleType.GUILD_CENTER_FORTRESS
    buildObjectTypes[Enum.GuildBuildType.FORTRESS_FIRST] = Enum.RoleType.GUILD_FORTRESS_FIRST
    buildObjectTypes[Enum.GuildBuildType.FLAG] = Enum.RoleType.GUILD_FLAG
    buildObjectTypes[Enum.GuildBuildType.FOOD] = Enum.RoleType.GUILD_FOOD
    buildObjectTypes[Enum.GuildBuildType.WOOD] = Enum.RoleType.GUILD_WOOD
    buildObjectTypes[Enum.GuildBuildType.STONE] = Enum.RoleType.GUILD_STONE
    buildObjectTypes[Enum.GuildBuildType.GOLD] = Enum.RoleType.GUILD_GOLD
    buildObjectTypes[Enum.GuildBuildType.FOOD_CENTER] = Enum.RoleType.GUILD_FOOD_CENTER
    buildObjectTypes[Enum.GuildBuildType.WOOD_CENTER] = Enum.RoleType.GUILD_WOOD_CENTER
    buildObjectTypes[Enum.GuildBuildType.STONE_CENTER] = Enum.RoleType.GUILD_STONE_CENTER
    buildObjectTypes[Enum.GuildBuildType.GOLD_CENTER] = Enum.RoleType.GUILD_GOLD_CENTER
    buildObjectTypes[Enum.GuildBuildType.FORTRESS_SECOND] = Enum.RoleType.GUILD_FORTRESS_SECOND

    buildRoleTypes = {}
    buildRoleTypes[Enum.RoleType.GUILD_CENTER_FORTRESS] = Enum.GuildBuildType.CENTER_FORTRESS
    buildRoleTypes[Enum.RoleType.GUILD_FORTRESS_FIRST] = Enum.GuildBuildType.FORTRESS_FIRST
    buildRoleTypes[Enum.RoleType.GUILD_FLAG] = Enum.GuildBuildType.FLAG
    buildRoleTypes[Enum.RoleType.GUILD_FOOD] = Enum.GuildBuildType.FOOD
    buildRoleTypes[Enum.RoleType.GUILD_WOOD] = Enum.GuildBuildType.WOOD
    buildRoleTypes[Enum.RoleType.GUILD_STONE] = Enum.GuildBuildType.STONE
    buildRoleTypes[Enum.RoleType.GUILD_GOLD] = Enum.GuildBuildType.GOLD
    buildRoleTypes[Enum.RoleType.GUILD_FOOD_CENTER] = Enum.GuildBuildType.FOOD_CENTER
    buildRoleTypes[Enum.RoleType.GUILD_WOOD_CENTER] = Enum.GuildBuildType.WOOD_CENTER
    buildRoleTypes[Enum.RoleType.GUILD_STONE_CENTER] = Enum.GuildBuildType.STONE_CENTER
    buildRoleTypes[Enum.RoleType.GUILD_GOLD_CENTER] = Enum.GuildBuildType.GOLD_CENTER
    buildRoleTypes[Enum.RoleType.GUILD_FORTRESS_SECOND] = Enum.GuildBuildType.FORTRESS_SECOND
end

local function checkResourceCurrencys()
    if resourceRoleCurrencys and resourceGuildCurrency and resourceRoleCurrencyToBuildTypes and resourceGuildCurrencyToBuildTypes then return end

    resourceRoleCurrencys = {}
    resourceRoleCurrencys[Enum.GuildBuildType.FOOD] = Enum.CurrencyType.food
    resourceRoleCurrencys[Enum.GuildBuildType.WOOD] = Enum.CurrencyType.wood
    resourceRoleCurrencys[Enum.GuildBuildType.STONE] = Enum.CurrencyType.stone
    resourceRoleCurrencys[Enum.GuildBuildType.GOLD] = Enum.CurrencyType.gold

    resourceGuildCurrency = {}
    resourceGuildCurrency[Enum.GuildBuildType.FOOD] = Enum.CurrencyType.allianceFood
    resourceGuildCurrency[Enum.GuildBuildType.WOOD] = Enum.CurrencyType.allianceWood
    resourceGuildCurrency[Enum.GuildBuildType.STONE] =Enum.CurrencyType.allianceStone
    resourceGuildCurrency[Enum.GuildBuildType.GOLD] = Enum.CurrencyType.allianceGold

    resourceRoleCurrencyToBuildTypes = {}
    resourceRoleCurrencyToBuildTypes[Enum.CurrencyType.food] = Enum.GuildBuildType.FOOD
    resourceRoleCurrencyToBuildTypes[Enum.CurrencyType.wood] = Enum.GuildBuildType.WOOD
    resourceRoleCurrencyToBuildTypes[Enum.CurrencyType.stone] = Enum.GuildBuildType.STONE
    resourceRoleCurrencyToBuildTypes[Enum.CurrencyType.gold] = Enum.GuildBuildType.GOLD

    resourceGuildCurrencyToBuildTypes = {}
    resourceGuildCurrencyToBuildTypes[Enum.CurrencyType.allianceFood] = Enum.GuildBuildType.FOOD
    resourceGuildCurrencyToBuildTypes[Enum.CurrencyType.allianceWood] = Enum.GuildBuildType.WOOD
    resourceGuildCurrencyToBuildTypes[Enum.CurrencyType.allianceStone] = Enum.GuildBuildType.STONE
    resourceGuildCurrencyToBuildTypes[Enum.CurrencyType.allianceGold] = Enum.GuildBuildType.GOLD
end

---@see 获取联盟建筑指定数据
function GuildBuildLogic:getGuildBuild( _guildId, _buildIndex, _fields )
    return SM.c_guild_building.req.Get( _guildId, _buildIndex, _fields )
end

---@see 更新联盟建筑指定数据
function GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, _fields, _data )
    return SM.c_guild_building.req.Set( _guildId, _buildIndex, _fields, _data )
end

---@see 联盟建筑类型转换为地图对象类型
function GuildBuildLogic:buildTypeToObjectType( _buildType )
    checkBuildObjectTypes()

    return buildObjectTypes[_buildType]
end

---@see 地图对象类型转换为联盟建筑类型
function GuildBuildLogic:objectTypeToBuildType( _roleType )
    checkBuildObjectTypes()

    return buildRoleTypes[_roleType]
end

---@see 获取联盟建筑耐久度上限
function GuildBuildLogic:getBuildDurableLimit( _guildId, _type, _durableMulti )
    -- 联盟科技加成百分比
    local allianceBuildingDurableMulti = _durableMulti or GuildLogic:getGuildAttr( _guildId, Enum.Guild.allianceBuildingDurableMulti ) or 0
    local durableLimit = CFG.s_AllianceBuildingType:Get( _type, "durable" )
    return math.floor( durableLimit * ( 1000 + allianceBuildingDurableMulti ) / 1000 )
end

---@see 获取同类型建筑个数
function GuildBuildLogic:getBuildNum( _guildId, _type, _guildBuilds )
    if not Common.isTable( _type ) then
        _type = { _type }
    end
    local buildCount = 0
    local guildBuilds = _guildBuilds or self:getGuildBuild( _guildId ) or {}
    for _, buildInfo in pairs( guildBuilds ) do
        if table.exist( _type, buildInfo.type ) then
            buildCount = buildCount + 1
        end
    end

    return buildCount
end

---@see 创建联盟建筑
function GuildBuildLogic:createGuildBuild( _guildId, _rid, _buildIndex, _type, _pos )
    local nowTime = os.time()
    -- 预占用地块
    if _type == Enum.GuildBuildType.CENTER_FORTRESS or _type == Enum.GuildBuildType.FORTRESS_FIRST
        or _type == Enum.GuildBuildType.FORTRESS_SECOND or _type == Enum.GuildBuildType.FLAG then
        local territoryId = GuildTerritoryLogic:getPosTerritoryId( _pos )
        local territorySize = CFG.s_AllianceBuildingType:Get( _type, "territorySize" )
        local territoryIds = GuildTerritoryLogic:getPosTerritoryIds( _pos, territorySize )
        -- 移除圣地关卡地块
        territoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( territoryIds )
        if not SM.TerritoryMgr.req.preOccupyTerritory( _guildId, _buildIndex, nowTime, territoryIds, territoryId ) then
            LOG_ERROR("rid(%d) createGuildBuild, can't create guild build in other guild", _rid)
            return nil, ErrorCode.GUILD_BUILD_CANT_OTHER_GUILD
        end
    end

    -- 扣除联盟资源
    local currencies
    local consumeCurrencies = {}
    local buildNum = self:getBuildNum( _guildId, _type ) + 1
    local buildDataId = _type * 10000 + buildNum
    local currencyCost = CFG.s_AllianceBuildingData:Get( buildDataId, "currencyCost" )
    local allianceBuildingCostMulti = GuildLogic:getGuildAttr( _guildId, Enum.Guild.allianceBuildingCostMulti ) or 0
    for currencyType, currencyNum in pairs( currencyCost ) do
        currencyNum = math.ceil( currencyNum * ( 1000 + allianceBuildingCostMulti ) / 1000 )
        currencies = GuildLogic:addGuildCurrency( _guildId, currencyType, - currencyNum, nil, true )
        consumeCurrencies[currencyType] = { type = currencyType, num = - currencyNum }
    end
    local allMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    if #allMemberRids > 0 then
        GuildLogic:syncGuildDepot( allMemberRids, currencies )
    end

    local sBuildingType = CFG.s_AllianceBuildingType:Get( _type )
    local buildInfo = GuildBuildDef:getDefaultGuildBuildAttr()
    buildInfo.buildIndex = _buildIndex
    buildInfo.type = _type
    buildInfo.pos = _pos
    buildInfo.status = Enum.GuildBuildStatus.BUILDING
    buildInfo.memberRid = _rid
    buildInfo.createTime = nowTime
    buildInfo.consumeCurrencies = consumeCurrencies

    -- 添加建筑信息到表中
    SM.c_guild_building.req.Add( _guildId, _buildIndex, buildInfo )

    -- 添加联盟资源消费记录
    GuildLogic:addConsumeRecord( _guildId, _rid, Enum.GuildConsumeType.BUILD, { _type }, consumeCurrencies )

    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.name, Enum.Guild.abbreviationName, Enum.Guild.signs } )
    local buildSpeed = self:getGuildBuildSpeed( _guildId, _buildIndex, buildInfo )
    local mapBuildInfo = {
        objectType = self:buildTypeToObjectType( _type ),
        guildFullName = guildInfo.name,
        guildAbbName = guildInfo.abbreviationName,
        guildBuildStatus = Enum.GuildBuildStatus.BUILDING,
        guildId = _guildId,
        buildProgress = 0,
        buildProgressTime = 0,
        needBuildTime = math.ceil( sBuildingType.S * Enum.GuildBuildBuildSpeedMulti / buildSpeed ),
        buildIndex = _buildIndex,
        pos = _pos
    }

    -- 增加领土数量
    if _type == Enum.GuildBuildType.FLAG then
        GuildLogic:addGuildTerritory( _guildId, 1 )
        mapBuildInfo.guildFlagSigns = guildInfo.signs
        GuildLogic:updateGuildMemberLimit( _guildId )
    elseif MapObjectLogic:checkIsGuildResourceCenterBuild( _type ) then
        -- 联盟资源中心
        mapBuildInfo.guildFlagSigns = guildInfo.signs
        mapBuildInfo.resourceCenterDeleteTime = buildInfo.createTime + sBuildingType.stillTime
    elseif buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
        or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
        or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
        mapBuildInfo.guildFlagSigns = guildInfo.signs
        GuildLogic:updateGuildMemberLimit( _guildId )
    end

    -- 增加联盟建筑建造超时定时器
    MSM.GuildTimerMgr[_guildId].post.addGuildBuildStatusTimer( _guildId, _buildIndex, buildInfo )

    -- 更新联盟建筑修改标识
    MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )

    -- 更新联盟主界面领土建筑图标
    self:updateGuildBuildFlag( _guildId, true )

    -- 创建联盟建筑事件
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    LogLogic:guildBuild( {
        logType = Enum.LogType.GUILD_BUILD_CREATE, iggid = iggid, guildId = _guildId,
        buildIndex = _buildIndex, buildType = _type, buildNum = buildNum,
    } )

    -- 联盟建筑进入Aoi
    local objectIndex = MSM.MapObjectMgr[_buildIndex].req.guildBuildAddMap( mapBuildInfo )
    return objectIndex
end

---@see 获取联盟建筑最大索引
function GuildBuildLogic:getGuildBuildIndex( _guildId )
    local maxIndex = 0
    local guildBuilds = self:getGuildBuild( _guildId ) or {}
    for index in pairs( guildBuilds ) do
        if maxIndex < index then
            maxIndex = index
        end
    end

    return maxIndex
end

---@see 建造速度计算
function GuildBuildLogic:getGuildBuildSpeed( _guildId, _buildIndex, _buildInfo )
    _buildInfo = _buildInfo or self:getGuildBuild( _guildId, _buildIndex )
    local reinforces = _buildInfo.reinforces or {}
    local armyNum = 0
    local soldierNum = 0
    local armyInfo
    -- 有派遣士兵
    for _, reinforce in pairs( reinforces ) do
        armyInfo = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex )
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
            armyNum = armyNum + 1
            soldierNum = soldierNum + ArmyLogic:getArmySoldierCount( armyInfo.soldiers )
        end
    end

    local buildSpeed = 1
    if armyNum > 0 then
        -- 联盟科技加成
        local guildAttr = GuildLogic:getGuildAttr( _guildId, { Enum.Guild.allianceBuildingSpeedMulti, Enum.Guild.allianceFlagSpeedMulti } ) or {}
        local guildTechMulti = guildAttr.allianceBuildingSpeedMulti or 0
        if _buildInfo.type == Enum.GuildBuildType.FLAG then
            guildTechMulti = guildTechMulti + ( guildAttr.allianceFlagSpeedMulti or 0 )
        end
        local sBuildingType = CFG.s_AllianceBuildingType:Get( _buildInfo.type )
        -- 建造速度计算公式
        armyNum = math.min( armyNum, 11 )
        buildSpeed = ( 1 + soldierNum * sBuildingType.X1 ) / ( 1 + ( armyNum - 1 ) * sBuildingType.Y1 ) * ( 1000 + guildTechMulti ) / 1000
    end

    return math.floor( buildSpeed * Enum.GuildBuildBuildSpeedMulti ), armyNum == 0
end

---@see 移除联盟建筑
function GuildBuildLogic:removeGuildBuild( _guildId, _buildIndex, _buildInfo, _isInit, _disbandGuild, _lock )
    local buildInfo = _buildInfo or self:getGuildBuild( _guildId, _buildIndex )
    if not buildInfo or table.empty( buildInfo ) then return end

    local nowTime = os.time()
    local armyInfo, targetObjectIndex, objectIndex, addGuildBuildPoint, toPos, armyChangeInfo
    local targetType = Enum.MapMarchTargetType.RETREAT
    local sBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )
    local allianceCoinReward = sBuildingType.allianceCoinReward / 3600
    local objectType = self:buildTypeToObjectType( buildInfo.type )
    local toType = Enum.RoleType.CITY
    local indexs = {}
    for index, reinforce in pairs( buildInfo.reinforces or {} ) do
        armyInfo = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex )
        if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
            -- 建造中
            if armyInfo.status and ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
                -- 获得联盟个人积分
                armyChangeInfo = {}
                if allianceCoinReward > 0 then
                    addGuildBuildPoint = math.floor( allianceCoinReward * ( nowTime - reinforce.startTime ) )
                    if addGuildBuildPoint > 0 then
                        armyChangeInfo.guildBuildPoint = ( armyInfo.guildBuildPoint or 0 ) + addGuildBuildPoint
                    end
                end
                -- 参与建造时间
                armyChangeInfo.guildBuildTime = ( armyInfo.guildBuildTime or 0 ) + ( nowTime - reinforce.startTime )
                MSM.ActivityRoleMgr[reinforce.rid].req.setActivitySchedule(
                    reinforce.rid, Enum.ActivityActionType.BUILD_ALLIANCE_TIME, nil, nil, nil, nil, nil, nil, nowTime - reinforce.startTime )
                ArmyLogic:setArmy( reinforce.rid, reinforce.armyIndex, armyChangeInfo )
            end
        end

        if not _isInit then
            -- 通知客户端部队信息
            targetObjectIndex = RoleLogic:getRoleCityIndex( reinforce.rid )
            if armyInfo.status and ( ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING )
                or ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) ) then
                -- 驻守中的部队取建筑坐标
                toPos = RoleLogic:getRole( reinforce.rid, Enum.Role.pos )
                ArmyLogic:armyEnterMap( reinforce.rid, reinforce.armyIndex, armyInfo, objectType, toType, buildInfo.pos, toPos, targetObjectIndex, targetType )
            else
                -- 未在驻守中的部队,取部队当前坐标
                objectIndex = MSM.RoleArmyMgr[reinforce.rid].req.getRoleArmyIndex( reinforce.rid, reinforce.armyIndex )
                if objectIndex then
                    -- 部队移动
                    MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, targetObjectIndex, nil, Enum.ArmyStatus.RETREAT_MARCH )
                end
            end
        else
            -- 直接解散部队
            ArmyLogic:disbandArmy( reinforce.rid, reinforce.armyIndex )
        end
        table.insert( indexs, index )
    end

    -- 删除建筑信息
    SM.c_guild_building.req.Delete( _guildId, _buildIndex )

    if not _isInit then
        -- 联盟建筑离开aoi
        objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
        self:syncGuildBuildArmy( objectIndex, nil, nil, indexs )
        MSM.MapObjectMgr[objectIndex].post.guildBuildLeave( objectIndex, self:buildTypeToObjectType( buildInfo.type ) )
        if not _disbandGuild then
            -- 更新联盟主界面领土建筑图标
            self:updateGuildBuildFlag( _guildId )
        end
    end

    local delOccupyTerritories, addGuildTerritories, delGuildTerritories
    if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
        or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
        or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND
        or buildInfo.type == Enum.GuildBuildType.FLAG then
        -- 移除地块占用
        local delTerritoryIds = GuildTerritoryLogic:getPosTerritoryIds( buildInfo.pos, sBuildingType.territorySize )
        -- 删除圣地占用地块
        delTerritoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( delTerritoryIds )
        delOccupyTerritories, addGuildTerritories, delGuildTerritories = SM.TerritoryMgr.req.delTerritories( _guildId, _buildIndex, delTerritoryIds, _lock, _disbandGuild )
        -- 领土数量变化
        if not _disbandGuild and buildInfo.type == Enum.GuildBuildType.FLAG then
            GuildLogic:addGuildTerritory( _guildId, - 1 )
        end
        -- 检查其他的正常状态的旗帜
        self:checkGuildValidFlags( _guildId, nil, _disbandGuild )
        -- 更新联盟成员上限
        if not _disbandGuild then
            GuildLogic:updateGuildMemberLimit( _guildId )
        end
    end

    -- 删除联盟建筑修改索引
    MSM.GuildIndexMgr[_guildId].post.delBuildIndex( _guildId, _buildIndex )

    -- 通知角色删除该建筑信息
    if not _disbandGuild then
        local guildFlags
        if buildInfo.type == Enum.GuildBuildType.FLAG then
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.territory, Enum.Guild.territoryLimit } )
            guildFlags = { flagNum = guildInfo.territory, flagLimit = guildInfo.territoryLimit }
        end
        if buildInfo.type == Enum.GuildBuildType.FLAG and buildInfo.status == Enum.GuildBuildStatus.NORMAL then
            self:syncMemberDeleteBuild( _guildId, nil, guildFlags )
        else
            self:syncMemberDeleteBuild( _guildId, _buildIndex, guildFlags )
        end
    end

    return true, addGuildTerritories, delGuildTerritories, delOccupyTerritories
end

---@see 解散联盟拆除联盟所有建筑
function GuildBuildLogic:removeAllGuildBuilds( _guildId )
    -- 移除联盟建筑定时器
    MSM.GuildTimerMgr[_guildId].req.delGuildTimers( _guildId )

    local builds = self:getGuildBuild( _guildId )
    local guildTerritoryIds = MSM.GuildTerritoryMgr[_guildId].req.getGuildTerritories( _guildId )
    local addGuildTerritories = {}
    local delGuildTerritories = {}
    for buildIndex, buildInfo in pairs( builds or {} ) do
        local _, addGuildTerritory, delGuildTerritory = self:removeGuildBuild( _guildId, buildIndex, buildInfo, nil, true, true )
        table.merge( addGuildTerritories, addGuildTerritory or {} )
        table.merge( delGuildTerritories, delGuildTerritory or {} )
        -- 联盟被解散建筑移除事件
        LogLogic:guildBuild( {
            logType = Enum.LogType.DISBAND_GUILD_REMOVE_BUILD, guildId = _guildId,
            buildIndex = buildIndex, buildType = buildInfo.type,
            buildNum = GuildBuildLogic:getBuildNum( _guildId, buildInfo.type ),
        } )
    end
    if guildTerritoryIds and not table.empty( guildTerritoryIds ) then
        local newGuildTerritoryIds = {
            guildId = _guildId,
            colorId = guildTerritoryIds.colorId,
            validTerritoryIds = table.indexs( guildTerritoryIds.validTerritoryIds ),
            invalidTerritoryIds = table.indexs( guildTerritoryIds.invalidTerritoryIds ),
            preOccupyTerritoryIds = table.indexs( guildTerritoryIds.preOccupyTerritoryIds ),
        }
        if table.empty( addGuildTerritories ) then
            addGuildTerritories = nil
        end
        table.insert( delGuildTerritories, newGuildTerritoryIds )
        GuildTerritoryLogic:syncGuildTerritories( nil, nil, addGuildTerritories, delGuildTerritories )
    end
    -- 删除联盟建筑表
    if builds then
        SM.c_guild_building.req.Delete( _guildId )
    end
end

---@see 建筑开始燃烧
function GuildBuildLogic:burnGuildBuild( _guildId, _buildIndex, _buildInfo, _armyRid )
    _buildInfo = _buildInfo or self:getGuildBuild( _guildId, _buildIndex )
    -- 驻守中的部队溃败回城
    local armyInfo, armyChangeInfo, addGuildBuildPoint, toPos, cityIndex, radius
    local nowTime = os.time()
    local sBuildingType = CFG.s_AllianceBuildingType:Get( _buildInfo.type )
    local allianceCoinReward = sBuildingType.allianceCoinReward / 3600
    local objectType = self:buildTypeToObjectType( _buildInfo.type )
    local toType = Enum.RoleType.CITY
    local deleteArmyIndexs = {}
    local newReinforces = {}
    for index, reinforce in pairs( _buildInfo.reinforces or {} ) do
        armyInfo = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex )
        if armyInfo and not table.empty( armyInfo ) then
            if _buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                -- 建造中
                if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
                    -- 获得联盟个人积分
                    armyChangeInfo = {}
                    if allianceCoinReward > 0 then
                        addGuildBuildPoint = math.floor( allianceCoinReward * ( nowTime - reinforce.startTime ) )
                        if addGuildBuildPoint > 0 then
                            armyChangeInfo.guildBuildPoint = ( armyInfo.guildBuildPoint or 0 ) + addGuildBuildPoint
                        end
                    end
                    -- 参与建造时间
                    armyChangeInfo.guildBuildTime = ( armyInfo.guildBuildTime or 0 ) + ( nowTime - reinforce.startTime )
                    MSM.ActivityRoleMgr[reinforce.rid].req.setActivitySchedule(
                    reinforce.rid, Enum.ActivityActionType.BUILD_ALLIANCE_TIME, nil, nil, nil, nil, nil, nil, nowTime - reinforce.startTime )
                    ArmyLogic:setArmy( reinforce.rid, reinforce.armyIndex, armyChangeInfo )
                end
            end

            -- 通知客户端部队信息
            cityIndex = RoleLogic:getRoleCityIndex( reinforce.rid )
            if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING )
                and ArmyLogic:getArmySoldierCount( armyInfo.soldiers or {} ) <= 0 then
                -- 驻守中的部队取建筑坐标
                toPos = RoleLogic:getRole( reinforce.rid, Enum.Role.pos )
                radius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                ArmyLogic:armyEnterMap( reinforce.rid, reinforce.armyIndex, armyInfo, objectType, toType, _buildInfo.pos, toPos, cityIndex,
                                    Enum.MapMarchTargetType.RETREAT, radius, nil, nil, nil, true )
                table.insert( deleteArmyIndexs, index )
            else
                newReinforces[index] = reinforce
            end
        end
    end
    self:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.reinforces] = newReinforces } )

    if #deleteArmyIndexs > 0 then
        local objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex ) or 0
        self:syncGuildBuildArmy( objectIndex, nil, nil, deleteArmyIndexs )
    end

    if _buildInfo.status == Enum.GuildBuildStatus.NORMAL or _buildInfo.status == Enum.GuildBuildStatus.REPAIR
        or _buildInfo.status == Enum.GuildBuildStatus.INVALID or _buildInfo.status == Enum.GuildBuildStatus.BURNING then
        -- 正常状态 或者维修状态的建筑，变为燃烧状态
        _buildInfo.buildBurnInfo = _buildInfo.buildBurnInfo or {}
        -- 维修状态的联盟建筑重置建筑当前的耐久度
        if _buildInfo.status == Enum.GuildBuildStatus.REPAIR then
            -- 计算当前耐久
            local durableUp = CFG.s_AllianceBuildingType:Get( _buildInfo.type, "durableUp" ) / 3600
            _buildInfo.durable = _buildInfo.durable + math.floor( ( nowTime - _buildInfo.buildBurnInfo.lastDurableTime ) * durableUp )
        elseif _buildInfo.status == Enum.GuildBuildStatus.BURNING then
            -- 燃烧状态
            _buildInfo.durable = math.floor( _buildInfo.durable - ( nowTime - _buildInfo.buildBurnInfo.burnTime ) * _buildInfo.buildBurnInfo.burnSpeed / Enum.GuildBuildBurnSpeedMulti )
        end
        _buildInfo.status = Enum.GuildBuildStatus.BURNING
        _buildInfo.buildBurnInfo.burnTime = nowTime
        _buildInfo.buildBurnInfo.burnSpeed = self:getGuildBuildBurnSpeed( _armyRid, _buildInfo.type )
        -- 更新建筑信息
        self:setGuildBuild( _guildId, _buildIndex, {
            [Enum.GuildBuild.status] = _buildInfo.status,
            [Enum.GuildBuild.buildBurnInfo] = _buildInfo.buildBurnInfo,
            [Enum.GuildBuild.durable] = _buildInfo.durable,
        } )
        -- 增加建筑燃烧定时器
        MSM.GuildTimerMgr[_guildId].post.addGuildBuildBurnTimer( _guildId, _buildIndex, _buildInfo )
        -- 记录攻击的角色联盟信息
        local attackGuildId = RoleLogic:getRole( _armyRid, Enum.Role.guildId )
        if attackGuildId > 0 then
            local guildInfo = GuildLogic:getGuild( attackGuildId, { Enum.Guild.name, Enum.Guild.abbreviationName } )
            self:setGuildBuild( _guildId, _buildIndex, {
                [Enum.GuildBuild.attackGuild] = {
                    guildId = attackGuildId,
                    guildName = guildInfo.name,
                    guildAbbName = guildInfo.abbreviationName
                }
            } )
        end
    elseif _buildInfo.status == Enum.GuildBuildStatus.BUILDING then
        -- 建造中建筑，直接删除
        MSM.GuildTimerMgr[_guildId].post.deleteGuildBuildTimer( _guildId, _buildIndex )
        -- 移除建筑
        self:removeGuildBuild( _guildId, _buildIndex, nil, nil, nil, true )
        -- 联盟建筑被烧毁事件
        LogLogic:guildBuild( {
            logType = Enum.LogType.GUILD_BUILD_BURN, guildId = _guildId,
            buildIndex = _buildIndex, buildType = _buildInfo.type,
            buildNum = self:getBuildNum( _guildId, _buildInfo.type ),
        } )
    end
end

---@see 计算燃烧速度
function GuildBuildLogic:getGuildBuildBurnSpeed( _rid, _buildType )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    local guildTechBurnMulti = GuildLogic:getGuildAttr( guildId, Enum.Guild.allTerrBurnSpeedMulti ) or 0
    return math.ceil( CFG.s_AllianceBuildingType:Get( _buildType, "durableDown" ) * ( 1000 + guildTechBurnMulti ) / 1000 / 3600 * Enum.GuildBuildBurnSpeedMulti )
end

---@see 角色执行联盟建筑灭火
function GuildBuildLogic:repairGuildBuild( _guildId, _buildIndex, _buildInfo )
    _buildInfo = _buildInfo or self:getGuildBuild( _guildId, _buildIndex )

    if _buildInfo.status == Enum.GuildBuildStatus.BURNING then
        -- 更新联盟建筑状态，联盟耐久度和维修状态开始时间
        local nowTime = os.time()
        local buildBurnInfo = _buildInfo.buildBurnInfo or {}
        buildBurnInfo.lastDurableTime = nowTime
        buildBurnInfo.lastRepairTime = nowTime
        self:setGuildBuild( _guildId, _buildIndex, {
            [Enum.GuildBuild.status] = Enum.GuildBuildStatus.REPAIR,
            [Enum.GuildBuild.durable] = math.floor( _buildInfo.durable - ( nowTime - buildBurnInfo.burnTime ) * buildBurnInfo.burnSpeed / Enum.GuildBuildBurnSpeedMulti ),
            [Enum.GuildBuild.buildBurnInfo] = buildBurnInfo,
        } )
        -- 增加回复耐久定时器
        MSM.GuildTimerMgr[_guildId].post.addGuildBuildDurableTimer( _guildId, _buildIndex )
    end
end

---@see 推送联盟建筑信息
function GuildBuildLogic:pushGuildBuilds( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if guildId <= 0 then return end

    local buildRateInfo, buildBurnInfo, guildBuildStatus, buildObjectIndex, isBattle
    local battleStatus = Enum.ArmyStatus.BATTLEING
    local guildFortresses = {}
    local guildResourceCenter = {}
    local guildFlags = { flags = {}, flagNum = 0, flagLimit = 0 }
    local guildInfo = GuildLogic:getGuild( guildId, {
        Enum.Guild.resourcePoints, Enum.Guild.members, Enum.Guild.territory, Enum.Guild.territoryLimit
    } )
    local objectIndexs = MSM.GuildBuildIndexMgr[guildId].req.getGuildBuildIndexs( guildId ) or {}
    local guildBuilds = self:getGuildBuild( guildId ) or {}
    for index, buildInfo in pairs( guildBuilds ) do
        buildBurnInfo = buildInfo.buildBurnInfo
        buildRateInfo = buildInfo.buildRateInfo
        buildObjectIndex = objectIndexs[index] or 0
        if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
            or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
            or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
            -- 联盟要塞信息
            guildFortresses[index] = {
                buildIndex = index,
                type = buildInfo.type,
                pos = buildInfo.pos,
                status = buildInfo.status,
                objectIndex = buildObjectIndex,
            }
            if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                -- 建造中显示建造进度
                guildFortresses[index].buildProgress = buildRateInfo.buildRate
                guildFortresses[index].buildProgressTime = buildRateInfo.lastRateTime
                guildFortresses[index].buildFinishTime = buildRateInfo.finishTime
                guildFortresses[index].isReinforce = self:checkIsReinforce( nil, nil, buildInfo.reinforces, _rid )
            else
                -- 其他状态显示耐久度
                guildFortresses[index].durable = buildInfo.durable
                guildFortresses[index].durableLimit = buildInfo.durableLimit
                guildFortresses[index].isReinforce = true
                if buildInfo.status == Enum.GuildBuildStatus.BURNING then
                    guildFortresses[index].burnSpeed = buildBurnInfo.burnSpeed
                    guildFortresses[index].burnTime = buildBurnInfo.burnTime
                elseif buildInfo.status == Enum.GuildBuildStatus.REPAIR then
                    guildFortresses[index].durableRecoverTime = buildBurnInfo.lastDurableTime
                end
            end
            guildBuildStatus = MSM.SceneGuildBuildMgr[buildObjectIndex].req.getGuildBuildStatus( buildObjectIndex )
            guildFortresses[index].isBattle = ArmyLogic:checkArmyStatus( guildBuildStatus, battleStatus )
        elseif buildInfo.type >= Enum.GuildBuildType.FOOD_CENTER and buildInfo.type <= Enum.GuildBuildType.GOLD_CENTER then
            -- 联盟资源中心信息
            guildResourceCenter = {
                resourceCenter = {
                    buildIndex = index,
                    type = buildInfo.type,
                    pos = buildInfo.pos,
                    status = buildInfo.status,
                    objectIndex = buildObjectIndex,
                }
            }
            if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                -- 建造中显示建造进度
                guildResourceCenter.resourceCenter.buildProgress = buildRateInfo.buildRate
                guildResourceCenter.resourceCenter.buildProgressTime = buildRateInfo.lastRateTime
                guildResourceCenter.resourceCenter.buildFinishTime = buildRateInfo.finishTime
                guildResourceCenter.resourceCenter.isReinforce = self:checkIsReinforce( nil, nil, buildInfo.reinforces, _rid )
            else
                guildResourceCenter.resource = buildInfo.resourceCenter.resourceNum
                guildResourceCenter.collectTime = buildInfo.resourceCenter.lastCollectTime
                guildResourceCenter.collectSpeed = buildInfo.resourceCenter.collectSpeed
                guildResourceCenter.resourceCenter.isReinforce = true
            end
        elseif buildInfo.type == Enum.GuildBuildType.FLAG then
            -- 联盟旗帜信息
            guildBuildStatus = MSM.SceneGuildBuildMgr[buildObjectIndex].req.getGuildBuildStatus( buildObjectIndex )
            isBattle = ArmyLogic:checkArmyStatus( guildBuildStatus, battleStatus )
            if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                -- 建造中
                guildFlags.flags[index] = {
                    buildIndex = index,
                    type = buildInfo.type,
                    pos = buildInfo.pos,
                    status = buildInfo.status,
                    objectIndex = buildObjectIndex,
                    isBattle = isBattle,
                }
                -- 建造中显示建造进度
                guildFlags.flags[index].buildProgress = buildRateInfo.buildRate
                guildFlags.flags[index].buildProgressTime = buildRateInfo.lastRateTime
                guildFlags.flags[index].buildFinishTime = buildRateInfo.finishTime
                guildFlags.flags[index].isReinforce = self:checkIsReinforce( nil, nil, buildInfo.reinforces, _rid )
            elseif buildInfo.status ~= Enum.GuildBuildStatus.NORMAL or isBattle then
                -- 非正常状态的旗帜
                guildFlags.flags[index] = {
                    buildIndex = index,
                    type = buildInfo.type,
                    pos = buildInfo.pos,
                    status = buildInfo.status,
                    isReinforce = true,
                    objectIndex = buildObjectIndex,
                    durable = buildInfo.durable,
                    durableLimit = buildInfo.durableLimit,
                    isBattle = isBattle,
                }
                if buildInfo.status == Enum.GuildBuildStatus.BURNING then
                    guildFlags.flags[index].burnSpeed = buildBurnInfo.burnSpeed
                    guildFlags.flags[index].burnTime = buildBurnInfo.burnTime
                elseif buildInfo.status == Enum.GuildBuildStatus.REPAIR then
                    guildFlags.flags[index].durableRecoverTime = buildBurnInfo.lastDurableTime
                end
            end
        end
    end
    guildFlags.flagNum = guildInfo.territory
    guildFlags.flagLimit = guildInfo.territoryLimit

    -- 联盟资源田数量
    local resourcePoints = guildInfo.resourcePoints or {}
    local guildResourcePoint = {
        foodPoint = resourcePoints[Enum.GuildBuildType.FOOD] and resourcePoints[Enum.GuildBuildType.FOOD].num or 0,
        woodPoint = resourcePoints[Enum.GuildBuildType.WOOD] and resourcePoints[Enum.GuildBuildType.WOOD].num or 0,
        stonePoint = resourcePoints[Enum.GuildBuildType.STONE] and resourcePoints[Enum.GuildBuildType.STONE].num or 0,
        goldPoint = resourcePoints[Enum.GuildBuildType.GOLD] and resourcePoints[Enum.GuildBuildType.GOLD].num or 0,
    }

    local roleTerritoryGains
    local lastTakeGainTime
    if guildInfo.members[_rid] then
        roleTerritoryGains = guildInfo.members[_rid].roleTerritoryGains
        lastTakeGainTime = guildInfo.members[_rid].lastTakeGainTime
    end
    -- 推送信息
    Common.syncMsg( _rid, "Guild_GuildBuilds",  {
        guildFortresses = guildFortresses,
        guildResourceCenter = guildResourceCenter,
        guildFlags = guildFlags,
        guildResourcePoint = guildResourcePoint,
        roleTerritoryGains = roleTerritoryGains,
        lastTakeGainTime = lastTakeGainTime,
    }, true, true )

    RoleLogic:updateRoleGuildIndexs( _rid, {
        guildBuildIndex = MSM.GuildIndexMgr[guildId].req.getBuildGlobalIndex( guildId ),
        guildResourcePointIndex = MSM.GuildIndexMgr[guildId].req.getResourcePointIndex( guildId ),
    } )
end

---@see 拆除建筑通知角色删除
function GuildBuildLogic:syncMemberDeleteBuild( _guildId, _buildIndex, _guildFlags )
    local members = GuildLogic:getAllOnlineMember( _guildId )
    if #members > 0 then
        self:synGuildBuild( members, nil, nil, _guildFlags, nil, nil, nil, _buildIndex )
    end
end

---@see 联盟建筑信息通知客户端
function GuildBuildLogic:synGuildBuild( _toRids, _guildFortresses, _guildResourceCenter, _guildFlags, _guildResourcePoint, _roleTerritoryGains, _lastTakeGainTime, _deleteBuildIndex, _reqType )
    Common.syncMsg( _toRids, "Guild_GuildBuilds",  {
        guildFortresses = _guildFortresses,
        guildResourceCenter = _guildResourceCenter,
        guildFlags = _guildFlags,
        guildResourcePoint = _guildResourcePoint,
        roleTerritoryGains = _roleTerritoryGains,
        lastTakeGainTime = _lastTakeGainTime,
        deleteBuildIndex = _deleteBuildIndex,
        reqType = _reqType
    } )
end

---@see 检查创建旗帜是否与有效的联盟领土相连
function GuildBuildLogic:checkFlagCreateByPos( _guildId, _pos )
    -- 联盟建筑所占领地宽度
    local buildType = Enum.GuildBuildType.FLAG
    -- 联盟建筑所占领地宽度
    local territorySize = CFG.s_AllianceBuildingType:Get( buildType, "territorySize" )
    -- 联盟建筑占用地块
    local territoryIds = GuildTerritoryLogic:getPosTerritoryIds( _pos, territorySize )
    territoryIds = SM.TerritoryMgr.req.deleteOtherGuildTerritory( territoryIds, _guildId, true )
    local centerTerritoryId = GuildTerritoryLogic:getPosTerritoryId( _pos )
    -- 该建筑占用的地块附近是否为指定联盟地块
    return MSM.GuildTerritoryMgr[_guildId].req.checkGuildValidTerritory( _guildId, territoryIds, centerTerritoryId )
end

---@see 检查联盟建筑是否可以创建到指定目标中
function GuildBuildLogic:checkGuildBuildCreate( _rid, _guildId, _type, _pos )
    -- 角色是否在联盟中
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.pos } )
    _guildId = _guildId or roleInfo.guildId
    if not _guildId or _guildId <= 0 then
        LOG_ERROR("rid(%d) checkGuildBuildCreate, role not in guild", _rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local guildBuilds = self:getGuildBuild( _guildId ) or {}
    local buildNum = self:getBuildNum( _guildId, _type, guildBuilds )
    local sBuildingType = CFG.s_AllianceBuildingType:Get( _type )

    -- 角色是否有创建联盟建筑的权限
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.members, Enum.Guild.power, Enum.Guild.currencies, Enum.Guild.territoryLimit } )
    local guildJob = GuildLogic:getRoleGuildJob( _guildId, _rid )
    if _type == Enum.GuildBuildType.FLAG then
        -- 创建旗帜权限
        if not GuildLogic:checkRoleJurisdiction( _rid, Enum.GuildJurisdictionType.BUILD_FLAG, guildJob ) then
            LOG_ERROR("rid(%d) checkGuildBuildCreate, role guildJob(%d) no create flag jurisdiction", _rid, guildJob)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end

        if buildNum >= guildInfo.territoryLimit then
            LOG_ERROR("rid(%d) checkGuildBuildCreate, guild type(%d) buildNum(%d) max limit", _rid, _type, buildNum)
            return nil, ErrorCode.GUILD_BUILD_NUM_LIMIT
        end
    else
        -- 创建建筑权限
        if not GuildLogic:checkRoleJurisdiction( _rid, Enum.GuildJurisdictionType.BUILD_BUILDING, guildJob ) then
            LOG_ERROR("rid(%d) checkGuildBuildCreate, role guildJob(%d) no create build jurisdiction", _rid, guildJob)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end

        -- 建造的是联盟资源中心判断角色市政厅等级
        if _type >= Enum.GuildBuildType.FOOD_CENTER and _type <= Enum.GuildBuildType.GOLD_CENTER then
            if RoleLogic:getRole( _rid, Enum.Role.level ) < CFG.s_Config:Get( "allianceResourcePointReqLevel" ) then
                LOG_ERROR("rid(%d) checkGuildBuildCreate, role level not enough", _rid)
                return nil, ErrorCode.GUILD_CREATE_BUILD_LEVEL_ERROR
            end

            -- 是否已有联盟资源中心
            local resourceCenterTypes = {
                Enum.GuildBuildType.FOOD_CENTER, Enum.GuildBuildType.WOOD_CENTER,
                Enum.GuildBuildType.STONE_CENTER, Enum.GuildBuildType.GOLD_CENTER
            }
            if self:getBuildNum( _guildId, resourceCenterTypes, guildBuilds ) >= 1 then
                LOG_ERROR("rid(%d) checkGuildBuildCreate, guildId(%d) already have resource center", _rid, _guildId)
                return nil, ErrorCode.GUILD_ALREADY_HAVE_RESOURCE_CENTER
            end
        else
            -- 联盟建造数量是否已到上限
            if buildNum >= sBuildingType.countDefault then
                LOG_ERROR("rid(%d) checkGuildBuildCreate, guild type(%d) buildNum(%d) max limit", _rid, _type, buildNum)
                return nil, ErrorCode.GUILD_BUILD_NUM_LIMIT
            end
        end
    end

    -- 判断联盟前置
    if sBuildingType.preBuilding1 > 0 and sBuildingType.preNum1 > 0
        and self:getBuildNum( _guildId, sBuildingType.preBuilding1, guildBuilds ) < sBuildingType.preNum1 then
        LOG_ERROR("rid(%d) checkGuildBuildCreate, guild type(%d) buildNum not enough", _rid, _type)
        return nil, ErrorCode.GUILD_PRE_BUILD_NOT_ENOUGH
    end

    -- 联盟人数和战力是否满足
    if table.size( guildInfo.members ) < sBuildingType.playerNum
        or guildInfo.power < sBuildingType.alliancePower then
        LOG_ERROR("rid(%d) checkGuildBuildCreate, guild buildType(%d) need power or player not enough", _rid, _type)
        return nil, ErrorCode.GUILD_POWER_PLAY_NOT_ENOUGH
    end

    -- 坐标点是否在迷雾中
    if DenseFogLogic:checkPosInDenseFog( _rid, _pos ) then
        LOG_ERROR("rid(%d) checkGuildBuildCreate, pos(%s) in densefog", _rid, tostring(_pos))
        return nil, ErrorCode.GUILD_BUILD_CREATE_IN_DENSEFOG
    end

    -- 检测目标位置建筑的独占区域是否与其他地图物件的独占区域相交叠
    if sBuildingType.radiusCollide > 0 and not MapLogic:checkPosIdle( _pos, sBuildingType.radiusCollide ) then
        LOG_ERROR("rid(%d) checkGuildBuildCreate, pos(%s) around already occupy", _rid, tostring(_pos))
        return nil, ErrorCode.GUILD_BUILD_NOT_OPEN_SPACE
    end

    -- 检测目标位置是否在关卡/圣地所属特殊领土内
    local HolyLandLogic = require "HolyLandLogic"
    if HolyLandLogic:checkInHolyLand( _pos ) then
        LOG_ERROR("rid(%d) checkGuildBuildCreate, can't move holyLand territory pos(%s)", _rid, tostring(_pos))
        return nil, ErrorCode.GUILD_BUILD_CREATE_IN_HOLYLAND
    end

    -- 坐标是否在其他联盟领土上
    local territoryId = GuildTerritoryLogic:getPosTerritoryId( _pos )
    local territoryGuildId = SM.TerritoryMgr.req.getTerritoryGuildId( territoryId, true )
    if territoryGuildId then
        if territoryGuildId ~= _guildId then
            -- 联盟建筑不能放到其他联盟的领土上
            LOG_ERROR("rid(%d) checkGuildBuildCreate, can't create guild build in other guild", _rid)
            return nil, ErrorCode.GUILD_BUILD_CANT_OTHER_GUILD
        end

        -- 该位置是否与有效的联盟领土相连
        if _type == Enum.GuildBuildType.FLAG and not self:checkFlagCreateByPos( _guildId, _pos ) then
            LOG_ERROR("rid(%d) checkGuildBuildCreate, around pos(%s) far away guild territory", _rid, tostring(_pos))
            return nil, ErrorCode.GUILD_CREATE_FLAG_NOT_LINK
        end

        if SM.TerritoryMgr.req.checkTerritoryBuild( territoryId ) then
            -- 在同一个地块上创建联盟另一个建筑
            LOG_ERROR("rid(%d) checkGuildBuildCreate, territoryId(%d) already have build", _rid, territoryId)
            return nil, ErrorCode.GUILD_TERRITORY_ALREADY_BUILD
        end
    else
        -- 该地块不属于任何联盟
        if _type >= Enum.GuildBuildType.FOOD_CENTER and _type <= Enum.GuildBuildType.GOLD_CENTER then
            -- 联盟资源中心需要建造在联盟领土中
            LOG_ERROR("rid(%d) checkGuildBuildCreate, resource center type(%d) must be build guild territory", _rid, _type)
            return nil, ErrorCode.GUILD_RESOURCE_NOT_TERRITORY
        end

        -- 该位置是否与有效的联盟领土相连
        if _type == Enum.GuildBuildType.FLAG and not self:checkFlagCreateByPos( _guildId, _pos ) then
            LOG_ERROR("rid(%d) checkGuildBuildCreate, around pos(%s) far away guild territory", _rid, tostring(_pos))
            return nil, ErrorCode.GUILD_CREATE_FLAG_NOT_LINK
        end
    end

    -- 联盟货币是否足够
    local buildDataId = _type * 10000 + buildNum + 1
    local currencyCost = CFG.s_AllianceBuildingData:Get( buildDataId, "currencyCost" )
    -- 在基础数量基础上会按照联盟科技减少一定比例的资源消耗
    local allianceBuildingCostMulti = GuildLogic:getGuildAttr( _guildId, Enum.Guild.allianceBuildingCostMulti ) or 0
    for currencyType, currencyNum in pairs( currencyCost ) do
        currencyNum = math.ceil( currencyNum * ( 1000 + allianceBuildingCostMulti ) / 1000 )
        if not GuildLogic:checkGuildCurrency( _guildId, currencyType, currencyNum, guildInfo.currencies ) then
            LOG_ERROR("rid(%d) checkGuildBuildCreate, guild buildDataId(%d) currency(%d) currencyNum(%s) allianceBuildingCostMulti(%s) not enough",
                    _rid, buildDataId, currencyType, tostring(currencyNum), tostring(allianceBuildingCostMulti))
            if currencyType == Enum.CurrencyType.leaguePoints then
                -- 联盟积分是否足够
                return nil, ErrorCode.GUILD_POINT_NOT_ENOUGH
            else
                -- 其他联盟货币不足
                return nil, ErrorCode.GUILD_CURRENCY_NOT_ENOUGH
            end
        end
    end

    return true
end

---@see 获取联盟建筑部队最大索引
function GuildBuildLogic:getBuildArmyMaxIndex( _guildId, _buildIndex, _buildInfo )
    _buildInfo = _buildInfo or self:getGuildBuild( _guildId, _buildIndex )

    local reinforceIndex = 0
    for index in pairs( _buildInfo.reinforces or {} ) do
        if index > 0 then
            reinforceIndex = index
        end
    end

    return reinforceIndex
end

---@see 获取联盟建筑增援信息.用于联盟战争
function GuildBuildLogic:getGuildBuildReinforceInfo( _guildId, _objectIndex )
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    local reinforces = self:getGuildBuild( _guildId, objectInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
    local roleInfo, armyInfo
    local reinforceDetail = {}
    for _, reinforce in pairs( reinforces ) do
        roleInfo = RoleLogic:getRole( reinforce.rid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
        armyInfo = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex )
        table.insert( reinforceDetail, {
            reinforceRid = reinforce.rid,
            mainHeroId = armyInfo.mainHeroId,
            deputyHeroId = armyInfo.deputyHeroId,
            soldiers = armyInfo.soldiers,
            reinforceTime = armyInfo.startTime,
            arrivalTime = armyInfo.arrivalTime,
            mainHeroLevel = armyInfo.mainHeroLevel,
            deputyHeroLevel = armyInfo.deputyHeroLevel,
            reinforceName = roleInfo.name,
            reinforceHeadId = roleInfo.headId,
            reinforceHeadFrameId = roleInfo.headFrameID,
            armyIndex = reinforce.armyIndex,
        } )
    end

    return reinforceDetail
end

---@see 推送联盟建筑部队信息
function GuildBuildLogic:pushGuildBuildArmys( _rid, _guildId, _buildIndex, _objectIndex )
    local armyList = {}
    local leaderBuildArmyIndex, armyInfo, roleInfo
    local reinforces = self:getGuildBuild( _guildId, _buildIndex, Enum.GuildBuild.reinforces ) or {}
    local leaderRid, leaderArmyIndex = MSM.SceneGuildBuildMgr[_objectIndex].req.getGarrisonLeader( _objectIndex )
    for index, reinforce in pairs( reinforces ) do
        roleInfo = RoleLogic:getRole( reinforce.rid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
        armyInfo = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex )
        armyList[index] = {
            buildArmyIndex = index,
            rid = reinforce.rid,
            armyIndex = reinforce.armyIndex,
            mainHeroId = armyInfo.mainHeroId,
            deputyHeroId = armyInfo.deputyHeroId,
            soldiers = armyInfo.soldiers,
            status = armyInfo.status,
            startTime = armyInfo.startTime,
            arrivalTime = armyInfo.arrivalTime,
            mainHeroLevel = armyInfo.mainHeroLevel,
            deputyHeroLevel = armyInfo.deputyHeroLevel,
            roleName = roleInfo.name,
            roleHeadId = roleInfo.headId,
            roleHeadFrameId = roleInfo.headFrameID,
        }
        if leaderRid and leaderRid == reinforce.rid and leaderArmyIndex == reinforce.armyIndex then
            leaderBuildArmyIndex = index
        end
    end

    Common.syncMsg( _rid, "Map_GuildBuildArmys", { armyList = armyList, leaderBuildArmyIndex = leaderBuildArmyIndex, objectIndex = _objectIndex } )
end

---@see 推送联盟建筑部队信息
function GuildBuildLogic:syncGuildBuildArmy( _objectIndex, _armyList, _leaderBuildArmyIndex, _deleteBuildArmyIndexs, _focusRids )
    local focusRids = _focusRids or MSM.SceneGuildBuildMgr[_objectIndex].req.getFocusRids( _objectIndex ) or {}
    if table.size( focusRids ) > 0 then
        Common.syncMsg( table.indexs( focusRids ), "Map_GuildBuildArmys", {
            armyList = _armyList,
            leaderBuildArmyIndex = _leaderBuildArmyIndex,
            objectIndex = _objectIndex,
            deleteBuildArmyIndexs = _deleteBuildArmyIndexs,
        } )
    end
end

---@see 更新部队到达时间到联盟建筑中
function GuildBuildLogic:updateBuildArmyArrivalTime( _objectIndex, _rid, _armyIndex, _arrivalTime )
    local targetInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectType( _objectIndex )
    if targetInfo and MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
        -- 联盟建筑
        local mapBuildInfo = MSM.SceneGuildBuildMgr[_objectIndex].req.getGuildBuildInfo( _objectIndex ) or {}
        if mapBuildInfo and table.size( mapBuildInfo.focusRids or {} ) > 0 then
            local reinforces = self:getGuildBuild( mapBuildInfo.guildId, mapBuildInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
            local reinforceIndex
            for index, reinforce in pairs( reinforces ) do
                if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
                    reinforceIndex = index
                    break
                end
            end

            if reinforceIndex then
                Common.syncMsg( table.indexs( mapBuildInfo.focusRids ), "Map_GuildBuildArmys", {
                    armyList = {
                        [reinforceIndex] = {
                            buildArmyIndex = reinforceIndex,
                            arrivalTime = _arrivalTime
                        }
                    },
                    objectIndex = _objectIndex,
                } )
            end
        end
    end
end

---@see 资源点建筑类型转为角色货币
function GuildBuildLogic:resourceBuildTypeToRoleCurrency( _resourceBuildType )
    checkResourceCurrencys()

    return resourceRoleCurrencys[_resourceBuildType]
end

---@see 资源点建筑类型转为联盟货币
function GuildBuildLogic:resourceBuildTypeToGuildCurrency( _resourceBuildType )
    checkResourceCurrencys()

    return resourceGuildCurrency[_resourceBuildType]
end

---@see 角色货币转为资源点建筑类型
function GuildBuildLogic:resourceRoleCurrencyToBuildType( _currencyType )
    checkResourceCurrencys()

    return resourceRoleCurrencyToBuildTypes[_currencyType]
end

---@see 联盟货币转为资源点建筑类型
function GuildBuildLogic:resourceGuildCurrencyToBuildType( _currencyType )
    checkResourceCurrencys()

    return resourceGuildCurrencyToBuildTypes[_currencyType]
end

---@see 联盟资源中心建筑类型转换为资源类型
function GuildBuildLogic:resourceBuildTypeToResourceType( _buildType )
    if _buildType == Enum.GuildBuildType.FOOD_CENTER then
        return Enum.ResourceType.FARMLAND
    elseif _buildType == Enum.GuildBuildType.WOOD_CENTER then
        return Enum.ResourceType.WOOD
    elseif _buildType == Enum.GuildBuildType.STONE_CENTER then
        return Enum.ResourceType.STONE
    elseif _buildType == Enum.GuildBuildType.GOLD_CENTER then
        return Enum.ResourceType.GOLD
    end
end

---@see 检查失效状态的联盟建筑
function GuildBuildLogic:checkGuildInvalidFlags( _guildId, _guildBuilds )
    local guildBuilds = _guildBuilds or self:getGuildBuild( _guildId ) or {}
    local sBuildingType = CFG.s_AllianceBuildingType:Get()
    local territorySize = sBuildingType[Enum.GuildBuildType.FLAG].territorySize
    -- 联盟搜索地图中已有该联盟信息
    local invalidFlags = {}
    local flagTerritoryIds
    local fortressTypes = {
        Enum.GuildBuildType.CENTER_FORTRESS, Enum.GuildBuildType.FORTRESS_FIRST,
        Enum.GuildBuildType.FORTRESS_SECOND
    }

    local fromPos = {}
    local occupyTerritoryIds = {}
    for index, build in pairs( guildBuilds ) do
        if build.type == Enum.GuildBuildType.FLAG and build.status == Enum.GuildBuildStatus.INVALID then
            if build.status == Enum.GuildBuildStatus.INVALID then
                -- 失效状态的旗帜
                flagTerritoryIds = GuildTerritoryLogic:getPosTerritoryIds( build.pos, territorySize )
                -- 删除圣地占用地块
                flagTerritoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( flagTerritoryIds )
                flagTerritoryIds = SM.TerritoryMgr.req.deleteOtherGuildTerritory( flagTerritoryIds, _guildId )
                invalidFlags[index] = {
                    buildPos = build.pos,
                    flagTerritoryIds = flagTerritoryIds,
                    searchMapPos = GuildTerritoryLogic:mapPosToSearchMapPos( build.pos ),
                }
            elseif build.status == Enum.GuildBuildStatus.BURNING or build.status == Enum.GuildBuildStatus.REPAIR then
                -- 燃烧或者维修状态的旗帜
                flagTerritoryIds = GuildTerritoryLogic:getPosTerritoryIds( build.pos, territorySize )
                -- 删除圣地占用地块
                flagTerritoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( flagTerritoryIds )
                flagTerritoryIds = SM.TerritoryMgr.req.deleteOtherGuildTerritory( flagTerritoryIds, _guildId )
                table.merge( occupyTerritoryIds, flagTerritoryIds )
            end
        elseif table.exist( fortressTypes, build.type ) and build.status ~= Enum.GuildBuildStatus.BUILDING then
            -- 有效的要塞
            table.insert( fromPos, GuildTerritoryLogic:mapPosToSearchMapPos( build.pos )[1] )
            table.merge( occupyTerritoryIds, GuildTerritoryLogic:getPosTerritoryIds( build.pos, sBuildingType[build.type].territorySize ) )
        end
    end
    -- 失效的联盟圣地信息
    local sHoldType
    local invalidHolyLands = {}
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()
    local guildHolyLands = MSM.GuildHolyLandMgr[_guildId].req.getGuildHolyLand( _guildId ) or {}
    for holyLandId, holyLandInfo in pairs( guildHolyLands ) do
        if not holyLandInfo.valid then
            sHoldType = sStrongHoldType[sStrongHoldData[holyLandId].type]
            invalidHolyLands[holyLandId] = {
                pos = holyLandInfo.pos,
                territoryIds = GuildTerritoryLogic:getPosTerritoryIds( holyLandInfo.pos, sHoldType.territorySize ),
                searchMapPos = GuildTerritoryLogic:mapPosToSearchMapPos( holyLandInfo.pos ),
            }
        end
    end

    local objectIndex
    local objectIndexs = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndexs( _guildId )
    for index, flagInfo in pairs( invalidFlags ) do
        -- fromPos为要塞的地图寻路坐标
        if MSM.AStarMgr[_guildId].req.findPath( _guildId, fromPos, flagInfo.searchMapPos ) then
            -- 旗帜变为有效状态
            self:setGuildBuild( _guildId, index, { [Enum.GuildBuild.status] = Enum.GuildBuildStatus.NORMAL } )
            -- 更新联盟建筑修改标识
            MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, index )
            -- 更新地图旗帜状态
            objectIndex = objectIndexs[index]
            if objectIndex then
                MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, { guildBuildStatus = Enum.GuildBuildStatus.NORMAL } )
            end
            -- 获取该旗帜中属于该联盟领土的地块
            table.merge( occupyTerritoryIds, flagInfo.flagTerritoryIds )
        end
    end

    local updateHolyLandStatus = {}
    for holyLandId, holyLandInfo in pairs( invalidHolyLands ) do
        -- fromPos为要塞的地图寻路坐标
        if MSM.AStarMgr[_guildId].req.findPath( _guildId, fromPos, holyLandInfo.searchMapPos ) then
            -- 获取圣地地块
            table.merge( occupyTerritoryIds, holyLandInfo.territoryIds )
            -- 更新联盟圣地状态
            table.insert( updateHolyLandStatus, holyLandId )
        end
    end

    -- 地块状态检查
    if #occupyTerritoryIds > 0 then
        MSM.GuildTerritoryMgr[_guildId].post.guildTerritoryStatusChange( _guildId, occupyTerritoryIds )
    end

    -- 更新圣地状态
    if #updateHolyLandStatus > 0 then
        MSM.GuildHolyLandMgr[_guildId].post.updateGuildHolyLandValid( _guildId, updateHolyLandStatus, true )
    end
end

---@see 获取联盟要塞地图寻路坐标
function GuildBuildLogic:getGuildSearchMapPos( _guildId, _guildBuilds )
    local fromPos = {}

    local fortressTypes = {
        Enum.GuildBuildType.CENTER_FORTRESS, Enum.GuildBuildType.FORTRESS_FIRST,
        Enum.GuildBuildType.FORTRESS_SECOND
    }
    local guildBuilds = _guildBuilds or self:getGuildBuild( _guildId ) or {}
    for _, buildInfo in pairs( guildBuilds ) do
        if table.exist( fortressTypes, buildInfo.type ) and buildInfo.status ~= Enum.GuildBuildStatus.BUILDING then
            -- 有效的要塞
            table.insert( fromPos, GuildTerritoryLogic:mapPosToSearchMapPos( buildInfo.pos )[1] )
        end
    end

    return fromPos
end

---@see 联盟建筑建造完成回调
function GuildBuildLogic:buildFinishCallBack( _guildId, _buildIndex )
    local guildBuilds = self:getGuildBuild( _guildId )
    local buildInfo = guildBuilds[_buildIndex] or {}
    -- 建造完成是否为要塞、旗帜
    local territoryBuildTypes = {
        Enum.GuildBuildType.CENTER_FORTRESS, Enum.GuildBuildType.FORTRESS_FIRST,
        Enum.GuildBuildType.FORTRESS_SECOND, Enum.GuildBuildType.FLAG
    }

    local sConfig = CFG.s_Config:Get()
    local width = math.ceil( sConfig.kingdomMapLength / sConfig.territorySizeMin )
    local height = math.ceil( sConfig.kingdomMapWidth / sConfig.territorySizeMin )
    local buildNum = self:getBuildNum( _guildId, territoryBuildTypes, guildBuilds )
    -- 第一个建筑
    if buildNum <= 1 then
        local blockMap = {}
        for _ = 1, width * height do
            table.insert( blockMap, 1 )
        end
        -- 添加联盟领土寻路图
        MSM.AStarMgr[_guildId].req.InitSearchMap( _guildId, blockMap, width, height )
    end

    -- 默认建筑为正常状态
    local buildStatus = Enum.GuildBuildStatus.NORMAL
    if table.exist( territoryBuildTypes, buildInfo.type ) then
        if buildInfo.type ~= Enum.GuildBuildType.FLAG then
            -- 更新状态
            self:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.status] = buildStatus } )
        end
        -- 地块占用
        local territorySize = CFG.s_AllianceBuildingType:Get( buildInfo.type, "territorySize" )
        -- 占用地块
        local territoryIds = GuildTerritoryLogic:getPosTerritoryIds( buildInfo.pos, territorySize )
        -- 删除圣地占用地块
        territoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( territoryIds )
        local centerTerritoryId = GuildTerritoryLogic:getPosTerritoryId( buildInfo.pos )
        -- 联盟占用地块
        SM.TerritoryMgr.req.occupyTerritory( _guildId, _buildIndex, buildInfo.createTime, territoryIds, nil, centerTerritoryId )
        if buildInfo.type == Enum.GuildBuildType.FLAG then
            local fromPos = self:getGuildSearchMapPos( _guildId, guildBuilds )
            local toPos = GuildTerritoryLogic:mapPosToSearchMapPos( buildInfo.pos )
            if not MSM.AStarMgr[_guildId].req.findPath( _guildId, fromPos, toPos ) then
                -- 旗帜所在点到达不了要塞所在点
                buildStatus = Enum.GuildBuildStatus.INVALID
            end
        end

        if buildStatus == Enum.GuildBuildStatus.NORMAL then
            if buildInfo.type == Enum.GuildBuildType.FLAG  then
                self:syncMemberDeleteBuild( _guildId, _buildIndex )
            end
            -- 检查其他失效旗帜
            self:checkGuildInvalidFlags( _guildId )
        end
    end

    return buildStatus
end

---@see 检查正常状态的联盟建筑
function GuildBuildLogic:checkGuildValidFlags( _guildId, _guildBuilds, _disbandGuild )
    local guildBuilds = _guildBuilds or self:getGuildBuild( _guildId ) or {}
    -- 找到当前所有的有效状态的联盟要塞和正常状态的旗帜
    local fortresses = {}
    local validFlags = {}
    local flagTerritoryIds
    local invalidTerritoryIds = {}
    local territorySize = CFG.s_AllianceBuildingType:Get( Enum.GuildBuildType.FLAG, "territorySize" )
    for index, buildInfo in pairs( guildBuilds ) do
        if ( buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
            or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND ) and buildInfo.status ~= Enum.GuildBuildStatus.BUILDING then
            -- 非建造中的要塞
            table.insert( fortresses, GuildTerritoryLogic:mapPosToSearchMapPos( buildInfo.pos )[1] )
        elseif buildInfo.type == Enum.GuildBuildType.FLAG then
            if buildInfo.status == Enum.GuildBuildStatus.NORMAL then
                -- 正常状态的旗帜
                validFlags[index] = {
                    buildPos = buildInfo.pos,
                    searchMapPos = GuildTerritoryLogic:mapPosToSearchMapPos( buildInfo.pos )
                }
            elseif buildInfo.status == Enum.GuildBuildStatus.BURNING or buildInfo.status == Enum.GuildBuildStatus.REPAIR then
                -- 燃烧或者维修状态的旗帜
                flagTerritoryIds = GuildTerritoryLogic:getPosTerritoryIds( buildInfo.pos, territorySize )
                -- 删除圣地占用地块
                flagTerritoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( flagTerritoryIds )
                flagTerritoryIds = SM.TerritoryMgr.req.deleteOtherGuildTerritory( flagTerritoryIds, _guildId )
                table.merge( invalidTerritoryIds, flagTerritoryIds )
            end
        end
    end

    if table.size( validFlags ) > 0 then
        local flagStatus, objectIndex
        local objectIndexs = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndexs( _guildId )
        for index, flag in pairs( validFlags ) do
            -- 正常状态的旗帜，是否可以到达联盟要塞
            flagStatus = false
            if MSM.AStarMgr[_guildId].req.findPath( _guildId, fortresses, flag.searchMapPos ) then
                -- 旗帜还是正常状态
                flagStatus = true
            end

            if not flagStatus then
                if not _disbandGuild then
                    -- 更新旗帜状态为失效
                    self:setGuildBuild( _guildId, index, { [Enum.GuildBuild.status] = Enum.GuildBuildStatus.INVALID } )
                    -- 更新联盟建筑修改标识
                    MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, index )
                    -- 更新地图旗帜状态
                    objectIndex = objectIndexs[index]
                    if objectIndex then
                        MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, { guildBuildStatus = Enum.GuildBuildStatus.INVALID } )
                    end
                end
                -- 获取旗帜所占地块
                flagTerritoryIds = GuildTerritoryLogic:getPosTerritoryIds( flag.buildPos, territorySize )
                -- 删除圣地占用地块
                flagTerritoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( flagTerritoryIds )
                flagTerritoryIds = SM.TerritoryMgr.req.deleteOtherGuildTerritory( flagTerritoryIds, _guildId )
                table.merge( invalidTerritoryIds, flagTerritoryIds )
            end
        end
    end

    if not _disbandGuild then
        -- 有效的联盟圣地信息
        local sHoldType
        local validHolyLands = {}
        local sStrongHoldData = CFG.s_StrongHoldData:Get()
        local sStrongHoldType = CFG.s_StrongHoldType:Get()
        local guildHolyLands = MSM.GuildHolyLandMgr[_guildId].req.getGuildHolyLand( _guildId ) or {}
        for holyLandId, holyLandInfo in pairs( guildHolyLands ) do
            if holyLandInfo.valid then
                sHoldType = sStrongHoldType[sStrongHoldData[holyLandId].type]
                validHolyLands[holyLandId] = {
                    pos = holyLandInfo.pos,
                    territoryIds = GuildTerritoryLogic:getPosTerritoryIds( holyLandInfo.pos, sHoldType.territorySize ),
                    searchMapPos = GuildTerritoryLogic:mapPosToSearchMapPos( holyLandInfo.pos ),
                }
            end
        end

        local updateHolyLandStatus = {}
        for holyLandId, holyLandInfo in pairs( validHolyLands ) do
            if not MSM.AStarMgr[_guildId].req.findPath( _guildId, fortresses, holyLandInfo.searchMapPos ) then
                -- 获取圣地地块
                table.merge( invalidTerritoryIds, holyLandInfo.territoryIds )
                -- 更新联盟圣地状态
                table.insert( updateHolyLandStatus, holyLandId )
            end
        end

        -- 地块状态检查
        if #invalidTerritoryIds > 0 then
            MSM.GuildTerritoryMgr[_guildId].post.guildTerritoryStatusChange( _guildId, invalidTerritoryIds )
        end

        -- 更新联盟领地状态
        if #updateHolyLandStatus > 0 then
            MSM.GuildHolyLandMgr[_guildId].post.updateGuildHolyLandValid( _guildId, updateHolyLandStatus, false )
        end
    end
end

---@see 检查联盟建筑状态是否为失效状态
function GuildBuildLogic:checkGuildBuildInvalidStatus( _guildId, _buildIndex, _buildInfo )
    _buildInfo = _buildInfo or self:getGuildBuild( _guildId, _buildIndex )
    if _buildInfo then
        return _buildInfo.status == Enum.GuildBuildStatus.INVALID
    end
end

---@see 检查联盟建筑是否已增援
function GuildBuildLogic:checkIsReinforce( _guildId, _buildIndex, _reinforces, _memberRid )
    _reinforces = _reinforces or self:getGuildBuild( _guildId, _buildIndex, Enum.GuildBuild.reinforces ) or {}
    for _, reinforce in pairs( _reinforces ) do
        if reinforce.rid == _memberRid then
            return true
        end
    end

    return false
end

---@see 选择驻守的队长
---@param _garrison table<int, table<int, defaultGuildBuildGarrisonInfo> >
function GuildBuildLogic:selectGarrisonLeader( _garrison )
    local leaderRid, leaderArmyIndex, heroInfo
    local heroPower = 0
    local heroLevel = 0
    local HeroCacle = require "HeroCacle"
    local HeroLogic = require "HeroLogic"
    local mainHeroId
    for rid, armyInfo in pairs(_garrison) do
        for armyIndex in pairs(armyInfo) do
            -- 计算统帅战斗力
            mainHeroId = ArmyLogic:getArmy( rid, armyIndex, Enum.Army.mainHeroId )
            heroInfo = HeroLogic:getHero( rid, mainHeroId )
            local power = HeroCacle:caclePower( heroInfo )
            if ( heroLevel < heroInfo.level ) or ( heroLevel == heroInfo.level and heroPower < power ) then
                heroLevel = heroInfo.level
                leaderRid = rid
                leaderArmyIndex = armyIndex
                heroPower = power
            end
        end
    end

    return leaderRid, leaderArmyIndex
end

---@see 队长变更.同步信息
---@param _mapGuildBuildInfos defaultMapGuildBuildInfoClass
function GuildBuildLogic:syncInfoOnChangeLeader( _mapGuildBuildInfo, _objectIndex, _leaderRid, _garrisonArmyIndex, _isGuildBuild )
    local HeroLogic = require "HeroLogic"
    _mapGuildBuildInfo.garrisonLeader = _leaderRid
    _mapGuildBuildInfo.garrisonArmyIndex = _garrisonArmyIndex

    local armyInfo = ArmyLogic:getArmy( _leaderRid, _garrisonArmyIndex, {
        Enum.Army.mainHeroId, Enum.Army.deputyHeroId, Enum.Army.mainHeroLevel, Enum.Army.deputyHeroLevel
    } )
    local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( _leaderRid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
    _mapGuildBuildInfo.skills = skills or {}
    _mapGuildBuildInfo.mainHeroSkills = mainHeroSkills or {}
    _mapGuildBuildInfo.deputyHeroSkills = deputyHeroSkills or {}
    _mapGuildBuildInfo.mainHeroId = armyInfo.mainHeroId or 0
    _mapGuildBuildInfo.deputyHeroId = armyInfo.deputyHeroId or 0
    local maxSp = ArmyLogic:cacleArmyMaxSp( skills )
    _mapGuildBuildInfo.maxSp = maxSp
    -- 通过AOI通知
    local sceneObject
    if not _isGuildBuild or ( MapObjectLogic:checkIsGuildFortressObject( _mapGuildBuildInfo.objectType )
        or MapObjectLogic:checkIsGuildResourceCenterObject( _mapGuildBuildInfo.objectType ) ) then
        sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
    else
        sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
    end
    sceneObject.post.syncObjectInfo( _objectIndex, {
                                                        maxSp = maxSp,
                                                        mainHeroId = armyInfo.mainHeroId,
                                                        mainHeroSkills = _mapGuildBuildInfo.mainHeroSkills,
                                                        deputyHeroSkills = _mapGuildBuildInfo.deputyHeroSkills
                                                    }
                                )
    -- 如果处于战斗,通知战斗服务器更新
    if ArmyLogic:checkArmyStatus( _mapGuildBuildInfo.status, Enum.ArmyStatus.BATTLEING ) then
        local BattleAttrLogic = require "BattleAttrLogic"
        -- 更新角色属性
        BattleAttrLogic:syncObjectAttrChange( _objectIndex, _leaderRid )
        -- 更新将领技能
        BattleAttrLogic:syncObjectHeroChange( _objectIndex, nil, armyInfo.mainHeroId, armyInfo.mainHeroLevel,
                                                armyInfo.deputyHeroId, armyInfo.deputyHeroLevel, skills )
    end
    if _isGuildBuild then
        -- 更新客户端联盟建筑驻守队长信息
        self:updateGuildBuildLeader( _mapGuildBuildInfo, _objectIndex, _leaderRid, _garrisonArmyIndex )
    else
        -- 更新客户端圣地驻守队长信息
        local HolyLandLogic = require "HolyLandLogic"
        HolyLandLogic:updateHolyLandLeader( _mapGuildBuildInfo, _objectIndex, _leaderRid, _garrisonArmyIndex )
    end
end

---@see 更新联盟建筑驻守队长信息
function GuildBuildLogic:updateGuildBuildLeader( _mapGuildBuildInfo, _objectIndex, _leaderRid, _garrisonArmyIndex )
    local reinforces = self:getGuildBuild( _mapGuildBuildInfo.guildId, _mapGuildBuildInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
    for index, reinforce in pairs( reinforces ) do
        if reinforce.rid == _leaderRid and reinforce.armyIndex == _garrisonArmyIndex then
            self:syncGuildBuildArmy( _objectIndex, nil, index )
            break
        end
    end
end

---@see 地块变更更新联盟资源中心采集速度
function GuildBuildLogic:updateResourceCenterArmyCollectSpeed( _guildId, _territoryIds )
    local guildBuild
    local guildBuilds = self:getGuildBuild( _guildId ) or {}
    for _, buildInfo in pairs( guildBuilds ) do
        if MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
            guildBuild = buildInfo
            break
        end
    end

    if not guildBuild or table.empty( guildBuild.reinforces ) then
        return
    end

    -- 更新资源中心中部队的采集速度
    local territoryId = GuildTerritoryLogic:getPosTerritoryId( guildBuild.pos )
    if table.exist( _territoryIds, territoryId ) then
        MSM.GuildMgr[_guildId].post.roleArmyCollectSpeedChange( _guildId, guildBuild.buildIndex )
    end
end

---@see 创建联盟建筑测试
function GuildBuildLogic:createGuildBuildTest( _guildId, _rid, _buildIndex, _type, _pos )
    local buildInfo = GuildBuildDef:getDefaultGuildBuildAttr()
    buildInfo.buildIndex = _buildIndex
    buildInfo.type = _type
    buildInfo.pos = _pos
    buildInfo.status = Enum.GuildBuildStatus.NORMAL
    buildInfo.memberRid = _rid
    buildInfo.createTime = os.time()
    buildInfo.consumeCurrencies = {}

    -- 添加建筑信息到表中
    SM.c_guild_building.req.Add( _guildId, _buildIndex, buildInfo )
end

---@see 获取联盟建筑下一个测试坐标
function GuildBuildLogic:getBuildNextTestPos( _pos )
    local pos = { x = _pos.x + 5400, y = _pos.y }
    if pos.x >= 720000 then
        pos = { x = 3600, y = pos.y + 5400 }
    end

    if pos.y >= 720000 then
        return
    end

    return pos
end

---@see 更新联盟主界面的领土建造标识
function GuildBuildLogic:updateGuildBuildFlag( _guildId, _territoryBuildFlag )
    _territoryBuildFlag = _territoryBuildFlag or false
    if not _territoryBuildFlag then
        local guildBuilds = self:getGuildBuild( _guildId ) or {}
        for _, buildInfo in pairs( guildBuilds ) do
            if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                _territoryBuildFlag = true
                break
            end
        end
    end

    local oldBuildFlag = GuildLogic:getGuild( _guildId, Enum.Guild.territoryBuildFlag ) or false
    if oldBuildFlag ~= _territoryBuildFlag then
        GuildLogic:setGuild( _guildId, { [Enum.Guild.territoryBuildFlag] = _territoryBuildFlag } )
        MSM.GuildIndexMgr[_guildId].post.addGuildIndex( _guildId )
    end
end

---@see 部队增援联盟建筑
function GuildBuildLogic:reinforceGuildBuildCallBack( _rid, _armyIndex, _armyInfo, _fromType, _targetType, _reinforceObjectIndex, _reinforceIndex, _mapGuildBuildInfo )
    -- 判断部队是否在地图上
    local armyInMap, objectIndex, fpos, tpos, isOutCity, mapArmyInfo, radius
    objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
    if objectIndex then
        -- 部队在地图上
        armyInMap = true
        mapArmyInfo = MSM.SceneArmyMgr[objectIndex].req.getArmyInfo( objectIndex )
        fpos = mapArmyInfo.pos
        ArmyLogic:checkArmyOldTarget( _rid, _armyIndex, _armyInfo, true )
    else
        -- 部队不在地图上
        local oldTargetObjectIndex = _armyInfo.targetArg.targetObjectIndex
        if oldTargetObjectIndex == _reinforceObjectIndex then
            -- 无旧的目标
            fpos = RoleLogic:getRole( _rid, Enum.Role.pos )
            isOutCity = true
            radius = CFG.s_Config:Get("cityRadius") * 100
        else
            -- 部队旧的目标的处理
            fpos, _fromType, radius = ArmyLogic:checkArmyOldTarget( _rid, _armyIndex, _armyInfo, true )
        end
    end
    tpos = _mapGuildBuildInfo.pos
    -- 更新部队信息
    local changeArmyInfo = {}
    changeArmyInfo.targetType = _targetType
    _armyInfo.status = ArmyLogic:getArmyStatusByTargetType( _targetType )

    if not _armyInfo.targetArg or not _armyInfo.targetArg.targetObjectIndex ~= _reinforceObjectIndex then
        changeArmyInfo.targetArg = { targetObjectIndex = _reinforceObjectIndex }
    end
    if not table.empty( changeArmyInfo ) then
        ArmyLogic:updateArmyInfo( _rid, _armyIndex, changeArmyInfo )
    end

    -- 发起行军
    local arrivalTime
    if armyInMap then
        -- 移动部队,发起行军
        mapArmyInfo.buildArmyIndex = _reinforceIndex
        arrivalTime = MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, _reinforceObjectIndex, nil, _armyInfo.status, _targetType, nil, nil, nil, nil, mapArmyInfo )
    else
        -- 行军部队加入地图
        arrivalTime = ArmyLogic:armyEnterMap( _rid, _armyIndex, _armyInfo, _fromType, _mapGuildBuildInfo.objectType, fpos, tpos,
                                            _reinforceObjectIndex, _targetType, radius, _mapGuildBuildInfo.armyRadius, isOutCity, _reinforceIndex )
    end

    return arrivalTime
end

---@see 联盟建筑测试
function GuildBuildLogic:guildBuildTest()
    local rids = { 30000073, 30000074, 30000075, 30000076, 30000077, 30000078, 30000079, 30000080, 30000081, 30000082 }
    local pos = { x = 3600, y = 3600 * 10 }
    for _, rid in pairs( rids ) do
        if pos.y >= 720000 then
            break
        end
        local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
        if guildId > 0 then
            self:createGuildBuildTest( guildId, rid, 1, Enum.GuildBuildType.CENTER_FORTRESS, pos )
            pos = self:getBuildNextTestPos( pos )
            if not pos then
                break
            end

            for i = 2, 501 do
                self:createGuildBuildTest( guildId, rid, i, Enum.GuildBuildType.FLAG, pos )
                pos = self:getBuildNextTestPos( pos )
                if not pos then
                    break
                end
            end
            pos = { x = 3600, y = pos.y + 1800 * 5 }
        end
    end
end

return GuildBuildLogic