--[[
* @file : GuildTimerMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Tue Apr 21 2020 10:26:11 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟相关定时器服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local RoleLogic = require "RoleLogic"
local ArmyLogic = require "ArmyLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local GuildLogic = require "GuildLogic"
local ResourceLogic = require "ResourceLogic"
local snax = require "skynet.snax"
local MapObjectLogic = require "MapObjectLogic"
local RoleChatLogic = require "RoleChatLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local CommonCacle = require "CommonCacle"
local LogLogic = require "LogLogic"

---@see 联盟建筑定时器
local guildTimers = {} -- { guildId = { buildIndex = timerId } }
---@see 资源中心定时器
local resourceCenterTimers = {}
---@see 科技研究定时器
local technologyResearchTimers = {}
---@see 联盟建筑建造中超时定时器
local guildBuildStatusTimers = {}

---@see 建造完成
local function guildBuildFinish( _guildId, _buildIndex, _isInit, _buildFinishTime )
    local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
    -- 所有驻守中的队伍都返回城市
    local nowTime = _buildFinishTime or os.time()
    local reinforces = table.copy( buildInfo.reinforces, true )
    local cityPos, armyInfo, targetObjectIndex, addGuildBuildPoint, rid, armyChangeInfo, iggid
    local targetType = Enum.MapMarchTargetType.RETREAT
    local sBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )
    local allianceCoinReward = sBuildingType.allianceCoinReward / 3600
    local objectType = GuildBuildLogic:buildTypeToObjectType( buildInfo.type )
    local deleteBuildArmyIndexs = {}
    local buildArmyNum = 0
    local objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100
    local buildRadius = MSM.SceneGuildBuildMgr[_guildId].req.getBuildRadius( objectIndex ) or 0
    for index, reinforce in pairs( buildInfo.reinforces or {} ) do
        rid = reinforce.rid
        armyInfo = ArmyLogic:getArmy( rid, reinforce.armyIndex )
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
            buildArmyNum = buildArmyNum + 1
            armyChangeInfo = {}
            -- 联盟个人积分获得
            if allianceCoinReward > 0 then
                addGuildBuildPoint = math.floor( allianceCoinReward * ( nowTime - reinforce.startTime ) )
                if addGuildBuildPoint > 0 then
                    armyChangeInfo.guildBuildPoint = ( armyInfo.guildBuildPoint or 0 ) + addGuildBuildPoint
                end
            end
            -- 参与建造时间
            armyChangeInfo.guildBuildTime = ( armyChangeInfo.guildBuildTime or 0 ) + ( nowTime - reinforce.startTime )
            MSM.ActivityRoleMgr[rid].req.setActivitySchedule( rid, Enum.ActivityActionType.BUILD_ALLIANCE_TIME,
                nil, nil, nil, nil, nil, nil, nowTime - reinforce.startTime )
            -- 更新军队信息
            ArmyLogic:setArmy( rid, reinforce.armyIndex, armyChangeInfo )
            if not MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                cityPos = RoleLogic:getRole( rid, Enum.Role.pos )
                targetObjectIndex = RoleLogic:getRoleCityIndex( rid )
                ArmyLogic:armyEnterMap( rid, reinforce.armyIndex, armyInfo, objectType, Enum.RoleType.CITY, buildInfo.pos, cityPos,
                                        targetObjectIndex, targetType, buildRadius, cityRadius )
                table.insert( deleteBuildArmyIndexs, index )
                reinforces[index] = nil
                if not _isInit and objectIndex then
                    -- 联盟建筑,从建筑退出,不再驻守
                    MSM.SceneGuildBuildMgr[objectIndex].post.delGarrisonArmy( objectIndex, rid, reinforce.armyIndex )
                end
                -- 部队离开建造中的联盟建筑
                iggid = RoleLogic:getRole( rid, Enum.Role.iggid )
                LogLogic:guildBuildTroops( {
                    logType = Enum.LogType.ARMY_LEAVE_GUILD_BUILD, iggid = iggid, guildId = _guildId,
                    buildIndex = _buildIndex, buildType = buildInfo.type, rid = rid, mainHeroId = armyInfo.mainHeroId,
                    deputyHeroId = armyInfo.deputyHeroId, buildTime = nowTime - reinforce.startTime, soldiers = armyInfo.soldiers
                } )
            end
        end
    end

    -- 建造完成回调
    local buildStatus = GuildBuildLogic:buildFinishCallBack( _guildId, _buildIndex )
    local durableLimit = GuildBuildLogic:getBuildDurableLimit( _guildId, buildInfo.type )
    -- 更新联盟建筑的建造状态
    GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, {
        status = buildStatus,
        buildRateInfo = { finishTime = nowTime },
        reinforces = reinforces,
        durable = durableLimit,
        durableLimit = durableLimit,
    } )

    -- 发送联盟建筑建造完成邮件
    local emailId = sBuildingType.buildSuccessMail or 0
    if emailId > 0 then
        local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
        local builderInfo = RoleLogic:getRole( buildInfo.memberRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
        local guildEmail = {
            roleName = builderInfo.name,
            roleHeadId = builderInfo.headId,
            roleHeadFrameId = builderInfo.headFrameID,
            buildCostGuildCurrencies = {},
        }
        for type, curremcy in pairs( buildInfo.consumeCurrencies or {} ) do
            table.insert( guildEmail.buildCostGuildCurrencies, {
                type = type,
                num = curremcy.num
            } )
        end
        local posArg = string.format( "%d,%d", buildInfo.pos.x, buildInfo.pos.y )
        local emailOtherInfo = {
            subType = Enum.EmailSubType.GUILD_BUILD,
            emailContents = { buildInfo.type, posArg, posArg },
            guildEmail = guildEmail,
            subTitleContents = { buildInfo.type },
        }
        MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, members, emailId, emailOtherInfo )
    end

    if guildTimers[_guildId] then
        guildTimers[_guildId][_buildIndex] = nil
        if table.empty( guildTimers[_guildId] ) then
            guildTimers[_guildId] = nil
        end
    end

    -- 删除建造超时定时器
    if guildBuildStatusTimers[_guildId] then
        if guildBuildStatusTimers[_guildId][_buildIndex] then
            Timer.delete( guildBuildStatusTimers[_guildId][_buildIndex] )
        end
        guildBuildStatusTimers[_guildId][_buildIndex] = nil
        if table.empty( guildBuildStatusTimers[_guildId] ) then
            guildBuildStatusTimers[_guildId] = nil
        end
    end

    -- 建造完成,更新地图联盟建筑状态
    if not _isInit then
        if objectIndex then
            local updateMapBuildInfo = {
                guildBuildStatus = buildStatus,
                durable = durableLimit,
                durableLimit = durableLimit,
            }
            MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo )
        end
        -- 更新联盟建筑修改标识
        MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
        if MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
            -- 重置定时器
            MSM.GuildTimerMgr[_guildId].req.resetResourceCenterTimer( _guildId, _buildIndex, nil, Enum.GuildResourceCenterReset.BUILD_FINISH )
        end
        -- 推送联盟建筑部队信息到关注角色中
        if #deleteBuildArmyIndexs > 0 then
            GuildBuildLogic:syncGuildBuildArmy( objectIndex, nil, nil, deleteBuildArmyIndexs )
        end
        -- 更新联盟主界面领土建筑图标
        GuildBuildLogic:updateGuildBuildFlag( _guildId )
    end
    -- 增加纪念碑事件
    if buildInfo.type == Enum.GuildBuildType.FLAG then
        MSM.MonumentRoleMgr[0].post.setSchedule( nil,
            { type = Enum.MonumentType.SERVER_ALLICNCE_FLAG_COUNT, guildId = _guildId, count = 1 })
    end

    -- 联盟建筑建造完成事件
    LogLogic:guildBuild( {
        logType = Enum.LogType.GUILD_BUILD_FINISH, guildId = _guildId,
        buildIndex = _buildIndex, buildType = buildInfo.type,
        buildNum = GuildBuildLogic:getBuildNum( _guildId, buildInfo.type ),
        logType2 = buildArmyNum
    } )

    return durableLimit
end

---@see 建筑耐久燃烧结束
local function guildBuildBurnFinish( _guildId, _buildIndex, _buildInfo, _isInit )
    _buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
    local nowTime = os.time()
    -- 燃烧持续时间
    local burnTime = nowTime - _buildInfo.buildBurnInfo.burnTime
    -- 当前剩余耐久
    local durableLeft = math.floor( _buildInfo.durable - burnTime * _buildInfo.buildBurnInfo.burnSpeed / Enum.GuildBuildBurnSpeedMulti )

    if guildTimers[_guildId] then
        guildTimers[_guildId][_buildIndex] = nil
        if table.empty( guildTimers[_guildId] ) then
            guildTimers[_guildId] = nil
        end
    end

    if durableLeft <= 0 then
        -- 移除联盟建筑
        GuildBuildLogic:removeGuildBuild( _guildId, _buildIndex, _buildInfo, _isInit )
        local emailId = CFG.s_AllianceBuildingType:Get( _buildInfo.type, "buildDestoryMail" ) or 0
        if emailId > 0 then
            -- 发送联盟建筑摧毁邮件
            local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}

            local posArg = string.format( "%d,%d", _buildInfo.pos.x, _buildInfo.pos.y )
            local emailOtherInfo = {
                subTitleContents = { _buildInfo.type },
                emailContents = { _buildInfo.type, posArg, posArg },
            }
            MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, members, emailId, emailOtherInfo )
        end

        if _buildInfo.attackGuild and _buildInfo.attackGuild.guildId > 0 then
            local attackGuildInfo = GuildLogic:getGuild( _buildInfo.attackGuild.guildId, { Enum.Guild.name, Enum.Guild.abbreviationName } )
            local marqueeArgs
            if attackGuildInfo and not table.empty( attackGuildInfo ) then
                marqueeArgs = { attackGuildInfo.name, attackGuildInfo.abbreviationName }
            else
                marqueeArgs = { _buildInfo.attackGuild.guildName, _buildInfo.attackGuild.guildAbbName }
            end
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.name, Enum.Guild.abbreviationName } )
            table.insert( marqueeArgs, guildInfo.name )
            table.insert( marqueeArgs, guildInfo.abbreviationName )
            table.insert( marqueeArgs, _buildInfo.pos.x )
            table.insert( marqueeArgs, _buildInfo.pos.y )
            table.insert( marqueeArgs, _buildInfo.type )
            -- 发送跑马灯
            RoleChatLogic:sendMarquee( 732047, marqueeArgs )
        end

        -- 联盟建筑被烧毁事件
        LogLogic:guildBuild( {
            logType = Enum.LogType.GUILD_BUILD_BURN, guildId = _guildId,
            buildIndex = _buildIndex, buildType = _buildInfo.type,
            buildNum = GuildBuildLogic:getBuildNum( _guildId, _buildInfo.type ),
        } )
    else
        -- 联盟建筑当前属性修改
        local buildChangeInfo = {
            status = Enum.GuildBuildStatus.REPAIR,
            durable = durableLeft,
            buildBurnInfo = {
                lastRepairTime = _buildInfo.buildBurnInfo and _buildInfo.buildBurnInfo.lastRepairTime,
                lastDurableTime = nowTime
            }
        }
        GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, buildChangeInfo )
        -- 增加回复耐久定时器
        if _isInit then
            MSM.GuildTimerMgr[_guildId].req.initGuildBuildDurableTimer( _guildId, _buildIndex, _buildInfo )
        else
            MSM.GuildTimerMgr[_guildId].post.addGuildBuildDurableTimer( _guildId, _buildIndex )
            -- 更新联盟建筑修改标识
            MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
        end

        return true
    end
end

---@see 建筑耐久恢复完成定时器
local function guildBuildDurableFinish( _guildId, _buildIndex, _buildInfo, _isInit )
    _buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )

    local buildStatus = Enum.GuildBuildStatus.NORMAL
    if _buildInfo.type == Enum.GuildBuildType.FLAG then
        -- 旗帜状态判断
        local fromPos = GuildBuildLogic:getGuildSearchMapPos( _guildId )
        local toPos = GuildTerritoryLogic:mapPosToSearchMapPos( _buildInfo.pos )
        if not MSM.AStarMgr[_guildId].req.findPath( _guildId, fromPos, toPos ) then
            -- 旗帜所在点到达不了要塞所在点
            buildStatus = Enum.GuildBuildStatus.INVALID
            -- 更新联盟建筑修改标识
            MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
        else
            GuildBuildLogic:syncMemberDeleteBuild( _guildId, _buildIndex )
        end
    else
        -- 更新联盟建筑修改标识
        MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
    end

    -- 更新联盟建筑耐久和状态
    GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, {
        [Enum.GuildBuild.status] = buildStatus,
        [Enum.GuildBuild.durable] = _buildInfo.durableLimit,
    } )

    if guildTimers[_guildId] then
        guildTimers[_guildId][_buildIndex] = nil
        if table.empty( guildTimers[_guildId] ) then
            guildTimers[_guildId] = nil
        end
    end

    if _isInit then
        -- 服务器启动时，联盟建筑进入Aoi
        local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.name, Enum.Guild.abbreviationName, Enum.Guild.signs } )
        local mapBuildInfo = {
            guildFullName = guildInfo.name,
            guildAbbName = guildInfo.abbreviationName,
            guildBuildStatus = buildStatus,
            guildId = _guildId,
            pos = _buildInfo.pos,
            buildIndex = _buildIndex,
            durable = _buildInfo.durableLimit,
            durableLimit = _buildInfo.durableLimit,
            objectType = GuildBuildLogic:buildTypeToObjectType( _buildInfo.type ),
        }
        -- 增加领土数量
        if _buildInfo.type == Enum.GuildBuildType.FLAG
            or _buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
            or _buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
            or _buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
            mapBuildInfo.guildFlagSigns = guildInfo.signs
        end
        -- 联盟建筑进入地图
        MSM.MapObjectMgr[_buildIndex].req.guildBuildAddMap( mapBuildInfo )
    else
        -- 更新地图建筑信息
        local updateMapBuildInfo = { guildBuildStatus = buildStatus, durable = _buildInfo.durableLimit }
        local objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
        if objectIndex then
            MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo )
        end
        -- 更新联盟建筑修改标识
        MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
    end
end


local guildResourceCenterTimeOut

---@see 联盟资源中心定时器
local function guildResourceCenterCollectFinish( _guildId, _buildIndex )
    local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex ) or {}
    if table.empty( buildInfo ) then
        return
    end

    -- 检查角色，采集已满的离开资源中心
    local nowTime = os.time()
    local armyList = {}
    local leftLoad, realCollect, resourceLoads, resourceLoadIndex, armyInfo
    local cityPos, targetObjectIndex, objectIndex, resourceRealLeft, armyRadius
    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    local lastCollectTime = buildInfo.resourceCenter.lastCollectTime
    local targetType = Enum.MapMarchTargetType.RETREAT
    local toType = Enum.RoleType.CITY
    local buildObjectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
    local targetArmyRadius = MSM.SceneGuildBuildMgr[buildObjectIndex].req.getBuildRadius( buildObjectIndex )

    -- 资源类型
    local collectSumSpeed = 0
    local newReinforces = {}
    local roleCollectFinishTime = {}
    resourceRealLeft = buildInfo.resourceCenter.resourceNum
    local objectType = GuildBuildLogic:buildTypeToObjectType( buildInfo.type )
    local resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( buildInfo.type )
    local deleteBuildArmyIndexs = {}
    for index, army in pairs( buildInfo.reinforces or {} ) do
        -- 部队信息
        armyInfo = ArmyLogic:getArmy( army.rid, army.armyIndex )
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            -- 部队剩余负载量
            leftLoad = ResourceLogic:getArmyLeftLoad( army.rid, army.armyIndex, armyInfo )
            -- 剩余负载转换为资源携带量
            leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
            leftLoad = leftLoad - armyInfo.collectResource.collectNum

            realCollect = army.collectSpeed * ( nowTime - lastCollectTime ) / collectSpeedMultiple
            if leftLoad <= realCollect then
                realCollect = leftLoad
                resourceLoads = armyInfo.resourceLoads or {}
                -- 角色采集已满
                for loadIndex, loadInfo in pairs( resourceLoads ) do
                    -- 如果已有该资源点的采集信息，合并处理
                    if loadInfo.guildId and loadInfo.guildId == _guildId and loadInfo.guildBuildIndex == _buildIndex then
                        resourceLoadIndex = loadIndex
                        loadInfo.load = loadInfo.load + math.floor( realCollect ) + armyInfo.collectResource.collectNum
                        break
                    end
                end
                -- 不存在该资源点的采集信息，新增采集信息
                if not resourceLoadIndex then
                    table.insert( resourceLoads, {
                        pos = { x = buildInfo.pos.x, y = buildInfo.pos.y },
                        load = math.floor( realCollect ) + armyInfo.collectResource.collectNum,
                        guildId = _guildId,
                        guildBuildIndex = _buildIndex,
                        guildBuildType = buildInfo.type,
                        isGuildTerritory = true,
                    } )
                end
                -- 当前资源点资源量
                resourceRealLeft = resourceRealLeft - math.ceil( realCollect )
                -- 更新部队采集信息
                ArmyLogic:setArmy( army.rid, army.armyIndex, { [Enum.Army.resourceLoads] = resourceLoads, [Enum.Army.collectResource] = {} } )
                -- 通知客户端
                ArmyLogic:syncArmy( army.rid, army.armyIndex, { [Enum.Army.resourceLoads] = resourceLoads, [Enum.Army.collectResource] = {} }, true )
                -- 部队回城
                cityPos = RoleLogic:getRole( army.rid, Enum.Role.pos )
                -- 行军部队加入地图
                targetObjectIndex = RoleLogic:getRoleCityIndex( army.rid )
                armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                ArmyLogic:armyEnterMap( army.rid, army.armyIndex, armyInfo, objectType, toType, buildInfo.pos, cityPos, targetObjectIndex,
                                        targetType, armyRadius, targetArmyRadius )
                table.insert( deleteBuildArmyIndexs, index )
            else
                -- 角色未采集满
                armyInfo.collectResource.collectNum = armyInfo.collectResource.collectNum + math.floor( realCollect )
                armyList[army.rid] = armyInfo
                newReinforces[index] = army
                -- 所有部队的采集速度和
                collectSumSpeed = collectSumSpeed + army.collectSpeed
                -- 实际资源剩余量
                resourceRealLeft = resourceRealLeft - math.ceil( realCollect )
                -- 计算每个角色采集负载满完成时间
                roleCollectFinishTime[army.rid] = {
                    finishTime = lastCollectTime + math.ceil( leftLoad * collectSpeedMultiple / army.collectSpeed ),
                }
            end
        else
            armyList[army.rid] = armyInfo
        end
    end

    resourceCenterTimers[_guildId] = nil

    if resourceRealLeft <= 0 then
        -- 资源中心被采集完
        for rid, army in pairs( armyList ) do
            -- 部队回城
            cityPos = RoleLogic:getRole( rid, Enum.Role.pos )
            if ArmyLogic:checkArmyStatus( army.status, Enum.ArmyStatus.COLLECTING ) then
                resourceLoads = army.resourceLoads or {}
                for loadIndex, loadInfo in pairs( resourceLoads ) do
                    -- 如果已有该资源点的采集信息，合并处理
                    if loadInfo.guildId and loadInfo.guildId == _guildId and loadInfo.guildBuildIndex == _buildIndex then
                        resourceLoadIndex = loadIndex
                        loadInfo.load = loadInfo.load + army.collectResource.collectNum
                        break
                    end
                end
                -- 不存在该资源点的采集信息，新增采集信息
                if not resourceLoadIndex then
                    table.insert( resourceLoads, {
                        pos = { x = buildInfo.pos.x, y = buildInfo.pos.y },
                        load = army.collectResource.collectNum,
                        guildId = _guildId,
                        guildBuildIndex = _buildIndex,
                        guildBuildType = buildInfo.type,
                        isGuildTerritory = true,
                    } )
                end
                -- 更新军队行军状态
                ArmyLogic:setArmy( rid, army.armyIndex, { [Enum.Army.collectResource] = {}, [Enum.Army.resourceLoads] = resourceLoads } )
                -- 通知客户端
                ArmyLogic:syncArmy( rid, army.armyIndex, { [Enum.Army.collectResource] = {}, [Enum.Army.resourceLoads] = resourceLoads }, true )
                -- 行军部队加入地图
                targetObjectIndex = RoleLogic:getRoleCityIndex( rid )
                armyRadius = CommonCacle:getArmyRadius( army.soldiers )
                ArmyLogic:armyEnterMap( rid, army.armyIndex, army, objectType, toType, buildInfo.pos, cityPos, targetObjectIndex,
                                        targetType, armyRadius, targetArmyRadius )
            else
                objectIndex = MSM.RoleArmyMgr[rid].req.getRoleArmyIndex( rid, army.armyIndex )
                if objectIndex then
                    MSM.MapMarchMgr[objectIndex].req.marchBackCity( rid, objectIndex )
                end
            end
        end
        -- 删除建筑信息
        SM.c_guild_building.req.Delete( _guildId, _buildIndex )
        -- 联盟资源中心离开地图
        objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
        for index in pairs( newReinforces or {} ) do
            table.insert( deleteBuildArmyIndexs, index )
        end
        if #deleteBuildArmyIndexs > 0 then
            GuildBuildLogic:syncGuildBuildArmy( objectIndex, nil, nil, deleteBuildArmyIndexs )
        end
        MSM.MapObjectMgr[objectIndex].post.guildBuildLeave( objectIndex, objectType )
        -- 删除联盟建筑修改索引
        MSM.GuildIndexMgr[_guildId].post.delBuildIndex( _guildId, _buildIndex )
        GuildBuildLogic:syncMemberDeleteBuild( _guildId, _buildIndex )
    else
        -- 资源中心未采集完
        -- 更新联盟建筑信息
        buildInfo.resourceCenter.resourceNum = resourceRealLeft
        buildInfo.resourceCenter.lastCollectTime = nowTime
        buildInfo.resourceCenter.collectSpeed = collectSumSpeed
        GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, {
            [Enum.GuildBuild.resourceCenter] = buildInfo.resourceCenter,
            [Enum.GuildBuild.reinforces] = newReinforces,
        } )

        -- 增加新的定时器
        local stillTime = CFG.s_AllianceBuildingType:Get( buildInfo.type, "stillTime" ) or 0
        -- 联盟资源中心超时删除时间
        local resourceTimeOut = buildInfo.buildRateInfo.finishTime + stillTime
        -- 资源点被采集完的时间
        local closeTime = resourceTimeOut
        local minTime = closeTime
        if collectSumSpeed > 0 then
            local resourceCollectFinishTime = nowTime + math.ceil( resourceRealLeft / collectSumSpeed * collectSpeedMultiple )
            closeTime = math.min( closeTime, resourceCollectFinishTime )
            minTime = closeTime
        end
        -- 剩下角色中最短的采集时间
        for _, roleCollect in pairs( roleCollectFinishTime ) do
            if closeTime > roleCollect.finishTime then
                closeTime = roleCollect.finishTime
            end
        end

        local collectResource, roleFinishTime
        for rid, army in pairs( armyList ) do
            -- 角色采集未满
            collectResource = army.collectResource or {}
            roleFinishTime = roleCollectFinishTime[rid] and roleCollectFinishTime[rid].finishTime
            if roleFinishTime then
                collectResource.endTime = math.min( minTime, roleFinishTime )
            end
            collectResource.lastSpeedChangeTime = nowTime

            -- 更新军队行军状态
            ArmyLogic:setArmy( rid, army.armyIndex, { [Enum.Army.status] = army.status, [Enum.Army.collectResource] = collectResource } )
            -- 通知客户端
            ArmyLogic:syncArmy( rid, army.armyIndex, { [Enum.Army.status] = army.status, [Enum.Army.collectResource] = collectResource }, true )
        end

        if closeTime == resourceTimeOut then
            -- 资源中心超时消失定时器
            resourceCenterTimers[_guildId] = Timer.runAt( closeTime, guildResourceCenterTimeOut, _guildId, _buildIndex )
        else
            -- 资源中心被采集完或角色采集满定时器
            resourceCenterTimers[_guildId] = Timer.runAt( closeTime, guildResourceCenterCollectFinish, _guildId, _buildIndex )
        end

        -- 更新地图联盟资源中心
        local updateMapBuildInfo = {
            resourceAmount = buildInfo.resourceCenter.resourceNum,
            collectSpeed = collectSumSpeed,
            collectRoleNum = table.size( armyList ),
            collectTime = nowTime,
        }
        objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
        MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo )
        -- 更新联盟建筑修改标识
        MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
        if #deleteBuildArmyIndexs > 0 then
            GuildBuildLogic:syncGuildBuildArmy( objectIndex, nil, nil, deleteBuildArmyIndexs )
        end
    end
end

---@see 联盟资源中心超时消失
guildResourceCenterTimeOut = function( _guildId, _buildIndex )
    local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex ) or {}
    if table.empty( buildInfo ) then
        return
    end

    local nowTime = os.time()
    local realCollect, armyInfo, resourceLoads, resourceLoadIndex
    local cityPos, objectIndex, targetObjectIndex, armyRadius, collectResource
    -- 上次更新采集时间
    local deleteBuildArmyIndexs = {}
    local toType = Enum.RoleType.CITY
    local targetType = Enum.MapMarchTargetType.RETREAT
    local lastCollectTime = buildInfo.resourceCenter.lastCollectTime
    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    local objectType = GuildBuildLogic:buildTypeToObjectType( buildInfo.type )
    local targetArmyRadius = CFG.s_AllianceBuildingType:Get( buildInfo.type, "radius" ) * 100
    for index, army in pairs( buildInfo.reinforces or {} ) do
        realCollect = math.floor( army.collectSpeed * ( nowTime - lastCollectTime ) / collectSpeedMultiple )
        -- 部队信息
        armyInfo = ArmyLogic:getArmy( army.rid, army.armyIndex )
        resourceLoads = armyInfo.resourceLoads or {}
        collectResource = armyInfo.collectResource or {}
        -- 角色采集已满
        for loadIndex, loadInfo in pairs( resourceLoads ) do
            -- 如果已有该资源点的采集信息，合并处理
            if loadInfo.guildId and loadInfo.guildId == _guildId and loadInfo.guildBuildIndex == _buildIndex then
                resourceLoadIndex = loadIndex
                loadInfo.load = loadInfo.load + realCollect + ( collectResource.collectNum or 0 )
                break
            end
        end
        -- 不存在该资源点的采集信息，新增采集信息
        if not resourceLoadIndex then
            table.insert( resourceLoads, {
                pos = { x = buildInfo.pos.x, y = buildInfo.pos.y },
                load = realCollect,
                guildId = _guildId,
                guildBuildIndex = _buildIndex,
                guildBuildType = buildInfo.type,
                isGuildTerritory = true,
            } )
        end
        -- 更新部队采集信息
        ArmyLogic:setArmy( army.rid, army.armyIndex, { [Enum.Army.resourceLoads] = resourceLoads, [Enum.Army.collectResource] = {} } )
        -- 通知客户端
        ArmyLogic:syncArmy( army.rid, army.armyIndex, { [Enum.Army.resourceLoads] = resourceLoads, [Enum.Army.collectResource] = {} }, true )
        -- 部队回城
        cityPos = RoleLogic:getRole( army.rid, Enum.Role.pos )
        -- 行军部队加入地图
        targetObjectIndex = RoleLogic:getRoleCityIndex( army.rid )
        armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
        ArmyLogic:armyEnterMap( army.rid, army.armyIndex, armyInfo, objectType, toType, buildInfo.pos, cityPos, targetObjectIndex,
                                    targetType, armyRadius, targetArmyRadius )
        table.insert( deleteBuildArmyIndexs, index )
    end

    -- 删除建筑信息
    SM.c_guild_building.req.Delete( _guildId, _buildIndex )
    -- 联盟资源中心离开地图
    objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
    if #deleteBuildArmyIndexs > 0 then
        GuildBuildLogic:syncGuildBuildArmy( objectIndex, nil, nil, deleteBuildArmyIndexs )
    end
    MSM.MapObjectMgr[objectIndex].post.guildBuildLeave( objectIndex, objectType )
    -- 删除联盟建筑修改索引
    MSM.GuildIndexMgr[_guildId].post.delBuildIndex( _guildId, _buildIndex )
    GuildBuildLogic:syncMemberDeleteBuild( _guildId, _buildIndex )
    -- 联盟资源中心超时移除事件
    LogLogic:guildBuild( {
        logType = Enum.LogType.GUILD_BUILD_TIMEOUT, guildId = _guildId,
        buildIndex = _buildIndex, buildType = buildInfo.type,
        buildNum = GuildBuildLogic:getBuildNum( _guildId, buildInfo.type ),
    } )
end

---@see 解散联盟删除定时器
function response.delGuildTimers( _guildId )
    for _, timerId in pairs( guildTimers[_guildId] or {} ) do
        Timer.delete( timerId )
    end

    guildTimers[_guildId] = nil
    -- 删除联盟资源中心定时器
    if resourceCenterTimers[_guildId] then
        Timer.delete( resourceCenterTimers[_guildId] )
        resourceCenterTimers[_guildId] = nil
    end
    -- 删除联盟研究定时器
    if technologyResearchTimers[_guildId] then
        Timer.delete( technologyResearchTimers[_guildId] )
        technologyResearchTimers[_guildId] = nil
    end

    -- 删除建造超时定时器
    for _, timerId in pairs( guildBuildStatusTimers[_guildId] or {} ) do
        Timer.delete( timerId )
    end
    guildBuildStatusTimers[_guildId] = nil
end

---@see 联盟建筑建造超时
local function guildBuildStatusTimeOut( _guildId, _buildIndex, _isInit )
    -- 移除联盟建造定时器
    if guildTimers[_guildId] then
        if guildTimers[_guildId][_buildIndex] then
            Timer.delete( guildTimers[_guildId][_buildIndex] )
            guildTimers[_guildId][_buildIndex] = nil
        end
        if table.empty( guildTimers[_guildId] ) then
            guildTimers[_guildId] = nil
        end
    end
    -- 发送超时移除联盟建筑邮件
    local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
    local emailId = CFG.s_AllianceBuildingType:Get( buildInfo.type, "buildFailMail" ) or 0
    if emailId > 0 then
        local members = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
        local builderInfo = RoleLogic:getRole( buildInfo.memberRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
        if builderInfo and not table.empty( builderInfo ) then
            local guildEmail = {
                roleName = builderInfo.name,
                roleHeadId = builderInfo.headId,
                roleHeadFrameId = builderInfo.headFrameID,
                buildCostGuildCurrencies = {},
            }
            for type, curremcy in pairs( buildInfo.consumeCurrencies or {} ) do
                table.insert( guildEmail.buildCostGuildCurrencies, {
                    type = type,
                    num = curremcy.num
                } )
            end
            local pos = string.format( "%d,%d", buildInfo.pos.x, buildInfo.pos.y )
            local emailOtherInfo = {
                subTitleContents = { buildInfo.type },
                emailContents = { buildInfo.type, pos, pos },
                guildEmail = guildEmail
            }
            MSM.GuildMgr[_guildId].post.sendGuildEmail( _guildId, members, emailId, emailOtherInfo )
        end
    end
    -- 移除联盟建筑
    GuildBuildLogic:removeGuildBuild( _guildId, _buildIndex, nil, _isInit )
    -- 联盟建筑建造超时移除事件
    LogLogic:guildBuild( {
        logType = Enum.LogType.GUILD_BUILD_TIMEOUT, guildId = _guildId,
        buildIndex = _buildIndex, buildType = buildInfo.type,
        buildNum = GuildBuildLogic:getBuildNum( _guildId, buildInfo.type ),
    } )
end

---@see 服务器重启初始化联盟建筑建造定时器
function response.initGuildBuildTimer( _guildId, _buildIndex, _buildInfo, _guildInfo )
    local buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )

    local nowTime = os.time()
    -- 建造进度
    local buildRate = buildInfo.buildRateInfo and buildInfo.buildRateInfo.buildRate or 0
    local oldBuildRate = buildRate
    -- 旧的建造速度
    local oldBuildSpeed = buildInfo.buildRateInfo and buildInfo.buildRateInfo.buildSpeed or 0
    local lastRateTime = buildInfo.buildRateInfo and buildInfo.buildRateInfo.lastRateTime or 0
    -- 当前的建造速度
    local newBuildSpeed, ret = GuildBuildLogic:getGuildBuildSpeed( _guildId, _buildIndex, buildInfo )
    local mapBuildInfo = {
        guildFullName = _guildInfo.name,
        guildAbbName = _guildInfo.abbreviationName,
        guildBuildStatus = buildInfo.status,
        guildId = _guildId,
        pos = buildInfo.pos,
        buildIndex = _buildIndex,
        objectType = GuildBuildLogic:buildTypeToObjectType( buildInfo.type ),
    }

    local buildFinish
    local buildSpeedMulti = Enum.GuildBuildBuildSpeedMulti
    local sBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )
    local buildTimeOut = _buildInfo.createTime + sBuildingType.timeDefault
    if ret then
        -- 当前是否已超过建造超时时间
        if buildTimeOut <= nowTime then
            guildBuildStatusTimeOut( _guildId, _buildIndex, true )
            return
        end
        -- 当前无建造速度，不需要增加定时器
        mapBuildInfo.buildProgress = buildRate
        mapBuildInfo.needBuildTime = math.ceil( ( sBuildingType.S - buildRate ) * buildSpeedMulti / newBuildSpeed )
    else
        -- 当前有建造速度,计算当前时间建筑是否已经建造完成
        buildRate = buildRate + math.floor( oldBuildSpeed * ( nowTime - lastRateTime ) / buildSpeedMulti )
        if buildRate < sBuildingType.S then
            -- 建造未完成
            -- 当前是否已超过建造超时时间
            if buildTimeOut <= nowTime then
                guildBuildStatusTimeOut( _guildId, _buildIndex, true )
                return
            end
            -- 建造进度信息
            local buildRateInfo = {
                buildRate = buildRate,
                buildSpeed = newBuildSpeed,
                lastRateTime = nowTime,
                finishTime = nowTime + math.ceil( ( sBuildingType.S - buildRate ) * buildSpeedMulti / newBuildSpeed )
            }
            -- 更新建筑信息
            GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.buildRateInfo] = buildRateInfo } )

            -- 添加定时器
            if not guildTimers[_guildId] then
                guildTimers[_guildId] = {}
            end
            guildTimers[_guildId][_buildIndex] = Timer.runAt( buildRateInfo.finishTime, guildBuildFinish, _guildId, _buildIndex )
            -- 地图建筑信息
            mapBuildInfo.buildProgress = buildRateInfo.buildRate
            mapBuildInfo.buildProgressTime = nowTime
            mapBuildInfo.buildFinishTime = buildRateInfo.finishTime
        else
            -- 在建造完成前, 联盟建筑已经超时
            local buildFinishTime = lastRateTime + ( sBuildingType.S - oldBuildRate ) * buildSpeedMulti / oldBuildSpeed
            if buildFinishTime > buildTimeOut then
                guildBuildStatusTimeOut( _guildId, _buildIndex, true )
                return
            end
            -- 建造已完成
            local durableLimit = guildBuildFinish( _guildId, _buildIndex, true, buildFinishTime )
            mapBuildInfo.guildBuildStatus = Enum.GuildBuildStatus.NORMAL
            mapBuildInfo.durable = durableLimit
            mapBuildInfo.durableLimit = durableLimit
            buildFinish = true
        end
    end

    -- 增加领土数量
    if _buildInfo.type == Enum.GuildBuildType.FLAG
        or _buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
        or _buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
        or _buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
        mapBuildInfo.guildFlagSigns = _guildInfo.signs
    elseif MapObjectLogic:checkIsGuildResourceCenterBuild( _buildInfo.type ) then
        mapBuildInfo.guildFlagSigns = _guildInfo.signs
        if buildFinish then
            -- 建造完成
            mapBuildInfo.resourceCenterDeleteTime = nowTime + sBuildingType.stillTime
        else
            -- 建造中
            mapBuildInfo.resourceCenterDeleteTime = _buildInfo.createTime + sBuildingType.timeDefault
        end
    end

    -- 建筑进入地图
    MSM.MapObjectMgr[_buildIndex].req.guildBuildAddMap( mapBuildInfo )

    if not buildFinish then
        -- 未建造完成，增加建造超时定时器
        if not guildBuildStatusTimers[_guildId] then
            guildBuildStatusTimers[_guildId] = {}
        end
        guildBuildStatusTimers[_guildId][_buildIndex] = Timer.runAt( buildTimeOut, guildBuildStatusTimeOut, _guildId, _buildIndex )
    elseif MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
        -- 建造完成的联盟资源中心, 重置联盟资源中心定时器
        snax.self().req.resetResourceCenterTimer( _guildId, _buildIndex, nil, Enum.GuildResourceCenterReset.BUILD_FINISH )
    end

    return true
end

---@see 创建建筑增加联盟建筑建造超时定时器
function accept.addGuildBuildStatusTimer( _guildId, _buildIndex, _buildInfo )
    if not guildBuildStatusTimers[_guildId] then
        guildBuildStatusTimers[_guildId] = {}
    end

    local buildType = _buildInfo and _buildInfo.type or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex, Enum.GuildBuild.type )
    local timeDefault = CFG.s_AllianceBuildingType:Get( buildType, "timeDefault" )
    local buildTimeOut = _buildInfo.createTime + timeDefault
    guildBuildStatusTimers[_guildId][_buildIndex] = Timer.runAt( buildTimeOut, guildBuildStatusTimeOut, _guildId, _buildIndex )
end

---@see 重新计算联盟建造定时器
function response.resetGuildBuildTimer( _guildId, _buildIndex )
    local buildInfo = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )

    local nowTime = os.time()
    -- 旧的建造速度
    local oldBuildSpeed = buildInfo.buildRateInfo and buildInfo.buildRateInfo.buildSpeed or 0
    -- 当前的建造速度
    local newBuildSpeed, ret = GuildBuildLogic:getGuildBuildSpeed( _guildId, _buildIndex, buildInfo )

    local updateMapBuildInfo = { guildBuildStatus = buildInfo.status }
    local sBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )

    local buildSpeedMulti = Enum.GuildBuildBuildSpeedMulti
    if not guildTimers[_guildId] then
        guildTimers[_guildId] = {}
    end
    -- 删除旧的定时器
    if guildTimers[_guildId][_buildIndex] then
        Timer.delete( guildTimers[_guildId][_buildIndex] )
    end
    -- 建造进度
    local buildRate = buildInfo.buildRateInfo and buildInfo.buildRateInfo.buildRate or 0
    local lastRateTime = buildInfo.buildRateInfo and buildInfo.buildRateInfo.lastRateTime or 0
    -- 建造速度变化, 更新建造进度
    buildRate = buildRate + math.floor( oldBuildSpeed * ( nowTime - lastRateTime ) / buildSpeedMulti )
    local buildRateInfo = {
        buildRate = buildRate,
        buildSpeed = newBuildSpeed,
        lastRateTime = nowTime,
    }

    if buildRate < sBuildingType.S then
        -- 建造未完成
        if ret then
            -- 当前无建造速度，不需要增加定时器
            buildRateInfo.buildSpeed = 0
            -- 更新联盟建筑建造信息
            GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.buildRateInfo] = buildRateInfo } )
            -- 地图联盟建筑信息修改
            updateMapBuildInfo.buildProgress = buildRate
            updateMapBuildInfo.needBuildTime = math.ceil( ( sBuildingType.S - buildRate ) * buildSpeedMulti / newBuildSpeed )
            updateMapBuildInfo.buildFinishTime = 0
        else
            -- 当前有建造速度
            buildRateInfo.finishTime = nowTime + math.ceil( ( sBuildingType.S - buildRate ) * buildSpeedMulti / newBuildSpeed )
            GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.buildRateInfo] = buildRateInfo } )
            -- 增加新的定时器
            guildTimers[_guildId][_buildIndex] = Timer.runAt( buildRateInfo.finishTime, guildBuildFinish, _guildId, _buildIndex )
            -- 地图联盟建筑信息修改
            updateMapBuildInfo.buildProgress = buildRate
            updateMapBuildInfo.buildProgressTime = nowTime
            updateMapBuildInfo.buildFinishTime = buildRateInfo.finishTime
            updateMapBuildInfo.needBuildTime = 0
        end
        -- 更新地图建筑信息
        local objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
        if objectIndex then
            MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo )
        end
    else
        -- 建造已完成
        guildBuildFinish( _guildId, _buildIndex )
    end
    -- 更新联盟建筑修改标识
    MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
end

---@see 移除建筑定时器
function response.removeGuildBuildTimer( _guildId, _buildIndex )
    if guildTimers[_guildId] and guildTimers[_guildId][_buildIndex] then
        Timer.delete( guildTimers[_guildId][_buildIndex] )
        guildTimers[_guildId][_buildIndex] = nil
        if table.empty( guildTimers[_guildId] ) then
            guildTimers[_guildId] = nil
        end
    end

    -- 删除建造超时定时器
    if guildBuildStatusTimers[_guildId] then
        if guildBuildStatusTimers[_guildId][_buildIndex] then
            Timer.delete( guildBuildStatusTimers[_guildId][_buildIndex] )
        end
        guildBuildStatusTimers[_guildId][_buildIndex] = nil
        if table.empty( guildBuildStatusTimers[_guildId] ) then
            guildBuildStatusTimers[_guildId] = nil
        end
    end
end

---@see 服务器重启增加联盟建筑燃烧定时器
function response.initGuildBuildBurnTimer( _guildId, _buildIndex, _buildInfo, _guildInfo )
    local nowTime = os.time()
    _buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
    local sBuildingType = CFG.s_AllianceBuildingType:Get( _buildInfo.type )
    -- 计算建筑燃烧时长
    local burnTime = nowTime - _buildInfo.buildBurnInfo.burnTime
    if burnTime > sBuildingType.burnLast then
        burnTime = sBuildingType.burnLast
    end
    local burnSpeedMulti = Enum.GuildBuildBurnSpeedMulti
    -- 计算当前耐久
    local durableLeft = math.floor( _buildInfo.durable - burnTime * _buildInfo.buildBurnInfo.burnSpeed / burnSpeedMulti )
    if durableLeft > 0 then
        -- 还有剩余耐久
        if not guildTimers[_guildId] then
            guildTimers[_guildId] = {}
        end

        if guildTimers[_guildId][_buildIndex] then
            Timer.delete( guildTimers[_guildId][_buildIndex] )
        end

        if _buildInfo.buildBurnInfo.burnTime + sBuildingType.burnLast > nowTime then
            -- 当前还在燃烧，增加燃烧定时器
            -- 当前耐久燃烧完成时间点
            local durableLeftFinishTime = nowTime + math.ceil( durableLeft / ( _buildInfo.buildBurnInfo.burnSpeed / burnSpeedMulti ) )
            -- 本次燃烧状态完成时间点
            local burnStatusFinishTime = _buildInfo.buildBurnInfo.burnTime + sBuildingType.burnLast
            guildTimers[_guildId][_buildIndex] = Timer.runAt( math.min( durableLeftFinishTime, burnStatusFinishTime ), guildBuildBurnFinish, _guildId, _buildIndex )

            -- 未燃烧完的联盟建筑进入AOI
            local mapBuildInfo = {
                guildFullName = _guildInfo.name,
                guildAbbName = _guildInfo.abbreviationName,
                guildBuildStatus = _buildInfo.status,
                guildId = _guildId,
                pos = _buildInfo.pos,
                buildIndex = _buildIndex,
                durable = _buildInfo.durable,
                durableLimit = _buildInfo.durableLimit,
                buildBurnSpeed = _buildInfo.buildBurnInfo.burnSpeed,
                buildBurnTime = _buildInfo.buildBurnInfo.burnTime,
                objectType = GuildBuildLogic:buildTypeToObjectType( _buildInfo.type )
            }
            -- 增加领土数量
            if _buildInfo.type == Enum.GuildBuildType.FLAG
                or _buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
            or _buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
            or _buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
                mapBuildInfo.guildFlagSigns = _guildInfo.signs
            end
            -- 建筑进入地图
            MSM.MapObjectMgr[_buildIndex].req.guildBuildAddMap( mapBuildInfo )

            return true
        else
            -- 当前不在燃烧
            return guildBuildBurnFinish( _guildId, _buildIndex, _buildInfo, true )
        end
    else
        if _buildInfo.attackGuild and _buildInfo.attackGuild.guildId > 0 then
            local attackGuildInfo = GuildLogic:getGuild( _buildInfo.attackGuild.guildId, { Enum.Guild.name, Enum.Guild.abbreviationName } )
            local marqueeArgs
            if attackGuildInfo and not table.empty( attackGuildInfo ) then
                marqueeArgs = { attackGuildInfo.name, attackGuildInfo.abbreviationName }
            else
                marqueeArgs = { _buildInfo.attackGuild.guildName, _buildInfo.attackGuild.guildAbbName }
            end
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.name, Enum.Guild.abbreviationName } )
            table.insert( marqueeArgs, guildInfo.name )
            table.insert( marqueeArgs, guildInfo.abbreviationName )
            table.insert( marqueeArgs, _buildInfo.pos.x )
            table.insert( marqueeArgs, _buildInfo.pos.y )
            table.insert( marqueeArgs, _buildInfo.type )
            -- 发送跑马灯
            RoleChatLogic:sendMarquee( 732047, marqueeArgs )
        end

        -- 移除联盟建筑
        GuildBuildLogic:removeGuildBuild( _guildId, _buildIndex, _buildInfo, true )
        -- 联盟建筑被烧毁事件
        LogLogic:guildBuild( {
            logType = Enum.LogType.GUILD_BUILD_BURN, guildId = _guildId,
            buildIndex = _buildIndex, buildType = _buildInfo.type,
            buildNum = GuildBuildLogic:getBuildNum( _guildId, _buildInfo.type ),
        } )
    end
end

---@see 新增联盟建筑燃烧定时器
function accept.addGuildBuildBurnTimer( _guildId, _buildIndex, _buildInfo )
    if not guildTimers[_guildId] then
        guildTimers[_guildId] = {}
    end
    -- 删除已有的定时器
    if guildTimers[_guildId][_buildIndex] then
        Timer.delete( guildTimers[_guildId][_buildIndex] )
    end

    _buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
    local burnLast = CFG.s_AllianceBuildingType:Get( _buildInfo.type, "burnLast" )
    -- 当前耐久可以燃烧的最长时间
    local burnTime = math.ceil( _buildInfo.durable / ( _buildInfo.buildBurnInfo.burnSpeed / Enum.GuildBuildBurnSpeedMulti ) )
    -- 获取燃烧时间点
    local finishTime = os.time() + math.min( burnTime, burnLast )
    -- 增加燃烧完成定时器
    guildTimers[_guildId][_buildIndex] = Timer.runAt( finishTime, guildBuildBurnFinish, _guildId, _buildIndex )
    -- 更新联盟建筑修改标识
    MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
    -- 更新地图建筑信息
    local updateMapBuildInfo = {
        guildBuildStatus = _buildInfo.status,
        durable = _buildInfo.durable,
        durableLimit = _buildInfo.durableLimit,
        buildBurnSpeed = _buildInfo.buildBurnInfo.burnSpeed,
        buildBurnTime = _buildInfo.buildBurnInfo.burnTime,
    }
    local objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
    if objectIndex then
        MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo )
    end
end

---@see 服务器重启增加联盟建筑恢复耐久定时器
function response.initGuildBuildDurableTimer( _guildId, _buildIndex, _buildInfo )
    _buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )

    local nowTime = os.time()
    -- 每秒恢复耐久
    local durableUp = CFG.s_AllianceBuildingType:Get( _buildInfo.type, "durableUp" ) / 3600
    local durable = _buildInfo.durable + math.floor( durableUp * ( nowTime - ( _buildInfo.buildBurnInfo.lastDurableTime or nowTime ) ) )
    if durable >= _buildInfo.durableLimit then
        -- 耐久已恢复满，修改联盟建筑状态
        guildBuildDurableFinish( _guildId, _buildIndex, _buildInfo, true )
    else
        -- 耐久未恢复满, 计算耐久恢复时间点
        local finishTime = os.time() + math.ceil( ( _buildInfo.durableLimit - _buildInfo.durable ) / durableUp )
        if not guildTimers[_guildId] then
            guildTimers[_guildId] = {}
        end
        -- 增加耐久完全恢复定时器
        guildTimers[_guildId][_buildIndex] = Timer.runAt( finishTime, guildBuildDurableFinish, _guildId, _buildIndex )
        -- 服务器启动时，联盟建筑进入Aoi
        local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.name, Enum.Guild.abbreviationName, Enum.Guild.signs } )
        local mapBuildInfo = {
            guildFullName = guildInfo.name,
            guildAbbName = guildInfo.abbreviationName,
            guildBuildStatus = _buildInfo.status,
            guildId = _guildId,
            pos = _buildInfo.pos,
            buildIndex = _buildIndex,
            durable = _buildInfo.durable,
            durableLimit = _buildInfo.durableLimit,
            buildDurableRecoverTime = _buildInfo.buildBurnInfo.lastDurableTime,
            objectType = GuildBuildLogic:buildTypeToObjectType( _buildInfo.type ),
            lastOutFireTime = _buildInfo.buildBurnInfo.lastRepairTime,
        }
        -- 增加领土数量
        if _buildInfo.type == Enum.GuildBuildType.FLAG
            or _buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
            or _buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
            or _buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
            mapBuildInfo.guildFlagSigns = guildInfo.signs
        end
        -- 建筑进入地图
        MSM.MapObjectMgr[_buildIndex].req.guildBuildAddMap( mapBuildInfo )
    end
end

---@see 新增联盟建筑恢复耐久定时器
function accept.addGuildBuildDurableTimer( _guildId, _buildIndex, _buildInfo )
    if not guildTimers[_guildId] then
        guildTimers[_guildId] = {}
    end
    -- 删除已有的定时器
    if guildTimers[_guildId][_buildIndex] then
        Timer.delete( guildTimers[_guildId][_buildIndex] )
    end

    _buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )
    -- 耐久不到上限增加定时器
    if _buildInfo.durableLimit > _buildInfo.durable then
        -- 每秒恢复耐久
        local durableUp = CFG.s_AllianceBuildingType:Get( _buildInfo.type, "durableUp" ) / 3600
        -- 耐久恢复时间点
        local finishTime = os.time() + math.ceil( ( _buildInfo.durableLimit - _buildInfo.durable ) / durableUp )
        -- 增加耐久完全恢复定时器
        guildTimers[_guildId][_buildIndex] = Timer.runAt( finishTime, guildBuildDurableFinish, _guildId, _buildIndex )
        -- 更新地图建筑信息
        local updateMapBuildInfo = {
            guildBuildStatus = _buildInfo.status,
            buildDurableRecoverTime = _buildInfo.buildBurnInfo.lastDurableTime,
            durableLimit = _buildInfo.durableLimit,
            durable = _buildInfo.durable,
            lastOutFireTime = _buildInfo.buildBurnInfo.lastRepairTime,
        }
        local objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
        if objectIndex then
            MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo )
        end
        -- 更新联盟建筑修改标识
        MSM.GuildIndexMgr[_guildId].post.addBuildIndex( _guildId, _buildIndex )
    else
        -- 耐久已恢复满，修改联盟建筑状态
        guildBuildDurableFinish( _guildId, _buildIndex, _buildInfo )
    end
end

---@see 服务端重启计算联盟资源中心信息
function response.initResourceCenterTimer( _guildId, _buildIndex, _buildInfo, _guildInfo )
    _buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex )

    -- 建造中的联盟资源中心不需要重新刷
    if _buildInfo.status == Enum.GuildBuildStatus.BUILDING then
        return
    end

    local nowTime = os.time()
    local sBuildingType = CFG.s_AllianceBuildingType:Get( _buildInfo.type )
    -- 联盟资源中心超时删除时间
    local resourceTimeOut = _buildInfo.buildRateInfo.finishTime + sBuildingType.stillTime

    local mapBuildInfo = {
        objectType = GuildBuildLogic:buildTypeToObjectType( _buildInfo.type ),
        guildFullName = _guildInfo.name,
        guildAbbName = _guildInfo.abbreviationName,
        guildBuildStatus = _buildInfo.status,
        guildId = _guildId,
        buildIndex = _buildIndex,
        pos = _buildInfo.pos,
        resourceCenterDeleteTime = resourceTimeOut,
        guildFlagSigns = _guildInfo.signs
    }

    -- 所有部队的采集速度和
    local collectSumSpeed = 0
    -- 获取所有的采集角色信息
    local armyList = {}
    local roleCollectFinishTime = {}
    local leftLoad, armyInfo
    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    local lastCollectTime = _buildInfo.resourceCenter.lastCollectTime
    local newReinforces = {}
    -- 资源类型
    local resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( _buildInfo.type )
    for buildArmyIndex, army in pairs( _buildInfo.reinforces ) do
        -- 部队信息
        armyInfo = ArmyLogic:getArmy( army.rid, army.armyIndex )
        army.collectSpeed = army.collectSpeed or ResourceLogic:getArmyCollectSpeedOnGuildResource( army.rid, army.armyIndex, armyInfo, _buildInfo.type, _buildInfo.pos )
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            newReinforces[buildArmyIndex] = army
            armyList[army.rid] = armyInfo
            -- 所有部队的采集速度和
            collectSumSpeed = collectSumSpeed + army.collectSpeed
            -- 部队剩余负载量
            leftLoad = ResourceLogic:getArmyLeftLoad( army.rid, army.armyIndex, armyList[army.rid] ) - ( ResourceLogic:getArmyCollectLoad( armyList[army.rid].collectResource ) or 0 )
            -- 剩余负载转换为资源携带量
            leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
            -- 计算每个角色采集负载满完成时间
            roleCollectFinishTime[army.rid] = {
                finishTime = lastCollectTime + math.ceil( leftLoad * collectSpeedMultiple / army.collectSpeed ),
                collectSpeed = army.collectSpeed,
                armyIndex = army.armyIndex,
                buildArmyIndex = buildArmyIndex,
            }
        end
    end

    if table.size( _buildInfo.reinforces ) ~= table.size( newReinforces ) then
        _buildInfo.reinforces = newReinforces
        GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, { [Enum.GuildBuild.reinforces] = _buildInfo.reinforces } )
    end

    -- 无正在采集中的部队
    if collectSumSpeed <= 0 then
        -- 资源中心超时消失定时器
        resourceCenterTimers[_guildId] = Timer.runAt( resourceTimeOut, guildResourceCenterTimeOut, _guildId, _buildIndex )
        -- 资源中心进入aoi
        mapBuildInfo.resourceAmount = _buildInfo.resourceCenter.resourceNum
        mapBuildInfo.collectTime = 0
        mapBuildInfo.collectSpeed = 0
        mapBuildInfo.collectRoleNum = 0

        MSM.MapObjectMgr[_buildIndex].req.guildBuildAddMap( mapBuildInfo )

        return
    end

    local resourceCollectFinishTime, newRoleCollectFinishTime, deleteTime, resourceLoads, resourceLoadIndex, realCollect, collectResource, roleFinishTime
    while true do
        -- 计算资源中心被采集空时间
        if collectSumSpeed <= 0 then
            break
        end
        resourceCollectFinishTime = lastCollectTime + math.ceil( _buildInfo.resourceCenter.resourceNum / collectSumSpeed * collectSpeedMultiple )

        deleteTime = math.min( resourceCollectFinishTime, resourceTimeOut )
        newRoleCollectFinishTime = {}
        -- 剔除在资源中心采集结束前采集负载已满的部队，重新计算资源中心采集结束时间
        for rid, roleCollect in pairs( roleCollectFinishTime ) do
            if roleCollect.finishTime < nowTime or deleteTime < nowTime then
                -- 角色采集完, 退出资源中心的采集
                resourceLoads = armyList[rid].resourceLoads or {}
                collectResource = armyList[rid].collectResource or {}
                resourceLoadIndex = nil
                roleFinishTime = math.min( roleCollect.finishTime, deleteTime, nowTime )
                realCollect = math.floor( ( roleFinishTime - lastCollectTime ) * roleCollect.collectSpeed / collectSpeedMultiple )
                -- 部队剩余负载量
                leftLoad = ResourceLogic:getArmyLeftLoad( rid, roleCollect.armyIndex, armyList[rid] ) - ( ResourceLogic:getArmyCollectLoad( armyList[rid].collectResource ) or 0 )
                -- 剩余负载转换为资源携带量
                leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
                realCollect = math.min( leftLoad, realCollect )
                for loadIndex, loadInfo in pairs( resourceLoads ) do
                    -- 如果已有该资源点的采集信息，合并处理
                    if loadInfo.guildId and loadInfo.guildId == _guildId and loadInfo.guildBuildIndex == _buildIndex then
                        resourceLoadIndex = loadIndex
                        loadInfo.load = loadInfo.load + realCollect + ( collectResource.collectNum or 0 )
                        break
                    end
                end
                -- 不存在该资源点的采集信息，新增采集信息
                if not resourceLoadIndex then
                    table.insert( resourceLoads, {
                        pos = { x = _buildInfo.pos.x, y = _buildInfo.pos.y },
                        load = realCollect + ( collectResource.collectNum or 0 ),
                        guildId = _guildId,
                        guildBuildIndex = _buildIndex,
                        guildBuildType = _buildInfo.type,
                        isGuildTerritory = true,
                    } )
                end

                -- 更新军队信息
                ArmyLogic:setArmy( rid, roleCollect.armyIndex, { [Enum.Army.resourceLoads] = resourceLoads } )
                -- 部队采集完成，直接解散部队
                ArmyLogic:disbandArmy( rid, roleCollect.armyIndex, true )
                -- 联盟建筑增援部队删除
                _buildInfo.reinforces[roleCollect.buildArmyIndex] = nil
                _buildInfo.resourceCenter.resourceNum = _buildInfo.resourceCenter.resourceNum - realCollect
                _buildInfo.resourceCenter.collectSpeed = collectSumSpeed
                _buildInfo.resourceCenter.lastCollectTime = nowTime
                -- 总得采集速度变化
                collectSumSpeed = collectSumSpeed - roleCollect.collectSpeed
            else
                newRoleCollectFinishTime[rid] = roleCollect
            end
        end

        if table.size( newRoleCollectFinishTime ) ~= table.size( roleCollectFinishTime ) then
            -- 本次循环有部队解散
            GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, {
                [Enum.GuildBuild.reinforces] = _buildInfo.reinforces,
                [Enum.GuildBuild.resourceCenter] = _buildInfo.resourceCenter
            } )

            roleCollectFinishTime = newRoleCollectFinishTime
        else
            break
        end
    end

    if deleteTime < nowTime then
        -- 资源点在服务器启动之前已经消失
        for rid, roleCollect in pairs( roleCollectFinishTime ) do
            resourceLoads = armyList[rid].resourceLoads or {}
            resourceLoadIndex = nil
            realCollect = math.floor( ( deleteTime - lastCollectTime ) * roleCollect.collectSpeed / collectSpeedMultiple )
            for loadIndex, loadInfo in pairs( resourceLoads ) do
                -- 如果已有该资源点的采集信息，合并处理
                if loadInfo.guildId and loadInfo.guildId == _guildId and loadInfo.guildBuildIndex == _buildIndex then
                    resourceLoadIndex = loadIndex
                    loadInfo.load = loadInfo.load + realCollect
                    break
                end
            end
            -- 不存在该资源点的采集信息，新增采集信息
            if not resourceLoadIndex then
                table.insert( resourceLoads, {
                    pos = { x = _buildInfo.pos.x, y = _buildInfo.pos.y },
                    load = realCollect,
                    guildId = _guildId,
                    guildBuildIndex = _buildIndex,
                    guildBuildType = _buildInfo.type,
                    isGuildTerritory = true,
                } )
            end

            -- 更新军队信息
            ArmyLogic:setArmy( rid, roleCollect.armyIndex, { [Enum.Army.resourceLoads] = resourceLoads } )
            -- 解散部队
            ArmyLogic:disbandArmy( rid, roleCollect.armyIndex, true )
        end
        -- 删除联盟建筑
        SM.c_guild_building.req.Delete( _guildId, _buildIndex )
    else
        -- 资源中心还未消失, 增加定时器
        local closeTime = deleteTime
        for _, roleCollect in pairs( roleCollectFinishTime ) do
            if closeTime > roleCollect.finishTime then
                closeTime = roleCollect.finishTime
            end
        end
        for rid, roleCollect in pairs( roleCollectFinishTime ) do
            collectResource = armyList[rid].collectResource or {}
            collectResource.endTime = math.min( roleCollect.finishTime, closeTime )
            ArmyLogic:setArmy( rid, roleCollect.armyIndex, { [Enum.Army.collectResource] = collectResource } )
        end
        if closeTime == resourceTimeOut then
            -- 资源中心超时消失定时器
            resourceCenterTimers[_guildId] = Timer.runAt( closeTime, guildResourceCenterTimeOut, _guildId, _buildIndex )
        else
            -- 资源中心被采集完或角色采集满定时器
            resourceCenterTimers[_guildId] = Timer.runAt( closeTime, guildResourceCenterCollectFinish, _guildId, _buildIndex )
        end

        -- 资源中心进入aoi
        mapBuildInfo.resourceAmount = _buildInfo.resourceCenter.resourceNum
        mapBuildInfo.collectTime = _buildInfo.resourceCenter.lastCollectTime
        mapBuildInfo.collectSpeed = collectSumSpeed
        mapBuildInfo.collectRoleNum = table.size( _buildInfo.reinforces )

        MSM.MapObjectMgr[_buildIndex].req.guildBuildAddMap( mapBuildInfo )
    end
end

---@see 重置联盟资源中心建造完成后的定时器
function response.resetResourceCenterTimer( _guildId, _buildIndex, _buildInfo, _type, _memberRid, _marchArgs, _disbandArmy )
    local buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex ) or {}
    if table.empty( buildInfo ) then return end

    -- 建造中的联盟资源中心不需要重新刷
    if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
        return
    end

    if resourceCenterTimers[_guildId] then
        Timer.delete( resourceCenterTimers[_guildId] )
    end

    local nowTime = os.time()
    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    local sBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )
    -- 资源类型
    local resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( buildInfo.type )
    -- 计算所有角色的采集速度
    local collectSumSpeed = 0
    local leftLoad, roleCollectFinishTime, armyInfo, resourceLoads, resourceLoadIndex, realCollect, armyChangeInfo, collectResource
    -- 联盟资源中心超时删除时间
    local resourceTimeOut = buildInfo.buildRateInfo.finishTime + sBuildingType.stillTime
    -- 计算采集完成结束时间
    local closeTime = resourceTimeOut
    local curResourceNum = buildInfo.resourceCenter.resourceNum
    local updateMapBuildInfo = {}
    local syncArmys = {}
    local collectRoleNum = 0
    -- 更新地图联盟资源中心
    local objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, _buildIndex )
    if _type == Enum.GuildResourceCenterReset.BUILD_FINISH then
        for _, army in pairs( buildInfo.reinforces or {} ) do
            armyInfo = ArmyLogic:getArmy( army.rid, army.armyIndex )
            if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
                -- 驻守中的部队转为采集中
                -- 计算部队当前的采集速度
                army.collectSpeed = ResourceLogic:getArmyCollectSpeedOnGuildResource( army.rid, army.armyIndex, armyInfo, buildInfo.type, buildInfo.pos )
                -- 采集总速度
                collectSumSpeed = collectSumSpeed + army.collectSpeed
                -- 负载量
                leftLoad = ResourceLogic:getArmyLeftLoad( army.rid, army.armyIndex, armyInfo )
                -- 负载量转换为资源携带量
                leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
                roleCollectFinishTime = nowTime + math.ceil( leftLoad / army.collectSpeed * collectSpeedMultiple )
                if closeTime > roleCollectFinishTime then
                    closeTime = roleCollectFinishTime
                end
                armyChangeInfo = {
                    [Enum.Army.status] = Enum.ArmyStatus.COLLECTING,
                    [Enum.Army.collectResource] = {
                        collectNum = 0,
                        startTime = nowTime,
                        collectSpeed = army.collectSpeed,
                        lastSpeedChangeTime = nowTime,
                        guildBuildType = buildInfo.type,
                        endTime = roleCollectFinishTime,
                    },
                }
                -- 通知客户端
                syncArmys[army.rid] = {}
                syncArmys[army.rid][army.armyIndex] = armyChangeInfo
                collectRoleNum = collectRoleNum + 1
            end
        end

        curResourceNum = sBuildingType.resAmount
        updateMapBuildInfo.resourceCenterDeleteTime = buildInfo.buildRateInfo.finishTime + sBuildingType.stillTime
    elseif _type == Enum.GuildResourceCenterReset.MEMBER_JOIN then
        local collectTime = nowTime - buildInfo.resourceCenter.lastCollectTime
        -- 联盟成员进入资源中心开始采集
        for _, army in pairs( buildInfo.reinforces or {} ) do
            armyInfo = ArmyLogic:getArmy( army.rid, army.armyIndex )
            if army.rid == _memberRid then
                -- 角色开始采集
                army.collectSpeed = ResourceLogic:getArmyCollectSpeedOnGuildResource( army.rid, army.armyIndex, armyInfo, buildInfo.type, buildInfo.pos )
                collectSumSpeed = collectSumSpeed + army.collectSpeed
                -- 负载量
                leftLoad = ResourceLogic:getArmyLeftLoad( army.rid, army.armyIndex, armyInfo )
                -- 负载量转换为资源携带量
                leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
                roleCollectFinishTime = nowTime + math.ceil( leftLoad / army.collectSpeed * collectSpeedMultiple )
                if closeTime > roleCollectFinishTime then
                    closeTime = roleCollectFinishTime
                end
                armyChangeInfo = {
                    [Enum.Army.status] = Enum.ArmyStatus.COLLECTING,
                    [Enum.Army.collectResource] = {
                        collectNum = 0,
                        startTime = nowTime,
                        collectSpeed = army.collectSpeed,
                        lastSpeedChangeTime = nowTime,
                        guildBuildType = buildInfo.type,
                        endTime = roleCollectFinishTime,
                    },
                }
                -- 通知客户端
                syncArmys[army.rid] = {}
                syncArmys[army.rid][army.armyIndex] = armyChangeInfo
                collectRoleNum = collectRoleNum + 1
            else
                if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                    -- 采集中角色获得资源
                    collectSumSpeed = collectSumSpeed + army.collectSpeed
                    collectResource = armyInfo.collectResource or {}
                    -- 实际采集量
                    realCollect = math.floor( collectTime * army.collectSpeed / collectSpeedMultiple )
                    collectResource.collectNum = ( collectResource.collectNum or 0 ) + realCollect
                    collectResource.lastSpeedChangeTime = nowTime
                    curResourceNum = curResourceNum - realCollect
                    -- 负载量
                    leftLoad = ResourceLogic:getArmyLeftLoad( army.rid, army.armyIndex, armyInfo )
                    -- 负载量转换为资源携带量
                    leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
                    leftLoad = leftLoad - collectResource.collectNum
                    roleCollectFinishTime = nowTime + math.ceil( leftLoad / army.collectSpeed * collectSpeedMultiple )
                    if closeTime > roleCollectFinishTime then
                        closeTime = roleCollectFinishTime
                    end
                    collectResource.endTime = roleCollectFinishTime
                    syncArmys[army.rid] = {}
                    syncArmys[army.rid][army.armyIndex] = {
                        [Enum.Army.collectResource] = collectResource
                    }
                    collectRoleNum = collectRoleNum + 1
                end
            end
        end
    elseif _type == Enum.GuildResourceCenterReset.MEMBER_LEAVE then
        -- 联盟成员离开资源中心
        local collectTime = nowTime - buildInfo.resourceCenter.lastCollectTime
        local buildArmyIndex
        for index, army in pairs( buildInfo.reinforces or {} ) do
            armyInfo = ArmyLogic:getArmy( army.rid, army.armyIndex )
            if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                -- 部队在采集状态
                collectResource = armyInfo.collectResource or {}
                -- 实际采集量
                realCollect = math.floor( collectTime * army.collectSpeed / collectSpeedMultiple )
                collectResource.collectNum = collectResource.collectNum + realCollect
                collectResource.lastSpeedChangeTime = nowTime
                -- 更新资源中心当前储量
                curResourceNum = curResourceNum - realCollect
                if army.rid == _memberRid then
                    -- 离开的角色
                    resourceLoadIndex = nil
                    resourceLoads = armyInfo.resourceLoads or {}
                    for loadIndex, loadInfo in pairs( resourceLoads ) do
                        -- 如果已有该资源点的采集信息，合并处理
                        if loadInfo.guildId and loadInfo.guildId == _guildId and loadInfo.guildBuildIndex == _buildIndex then
                            resourceLoadIndex = loadIndex
                            loadInfo.load = loadInfo.load + collectResource.collectNum
                            break
                        end
                    end
                    -- 不存在该资源点的采集信息，新增采集信息
                    if not resourceLoadIndex then
                        table.insert( resourceLoads, {
                            pos = { x = buildInfo.pos.x, y = buildInfo.pos.y },
                            load = collectResource.collectNum,
                            guildId = _guildId,
                            guildBuildIndex = _buildIndex,
                            guildBuildType = buildInfo.type,
                            isGuildTerritory = true,
                        } )
                    end

                    -- 通知客户端
                    syncArmys[army.rid] = {}
                    syncArmys[army.rid][army.armyIndex] = {
                        [Enum.Army.resourceLoads] = resourceLoads,
                        [Enum.Army.collectResource] = {},
                    }
                else
                    -- 其他角色继续采集
                    collectSumSpeed = collectSumSpeed + army.collectSpeed
                    -- 负载量
                    leftLoad = ResourceLogic:getArmyLeftLoad( army.rid, army.armyIndex, armyInfo )
                    -- 负载量转换为资源携带量
                    leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
                    leftLoad = leftLoad - collectResource.collectNum
                    roleCollectFinishTime = nowTime + math.ceil( leftLoad / army.collectSpeed * collectSpeedMultiple )
                    collectResource.endTime = roleCollectFinishTime
                    if closeTime > roleCollectFinishTime then
                        closeTime = roleCollectFinishTime
                    end
                    -- 通知客户端
                    syncArmys[army.rid] = {}
                    syncArmys[army.rid][army.armyIndex] = {
                        [Enum.Army.collectResource] = collectResource
                    }
                    collectRoleNum = collectRoleNum + 1
                end
            end
            if army.rid == _memberRid then
                -- 角色离开资源中心
                if not _disbandArmy then
                    local fromType = GuildBuildLogic:buildTypeToObjectType( buildInfo.type )
                    local toType, targetRadius
                    if _marchArgs.targetObjectIndex then
                        local targetInfo = MSM.MapObjectTypeMgr[_marchArgs.targetObjectIndex].req.getObjectInfo( _marchArgs.targetObjectIndex )
                        toType = targetInfo and targetInfo.objectType
                        targetRadius = targetInfo and targetInfo.armyRadius or 0
                    end
                    local buildRadius = sBuildingType.radius * 100
                    ArmyLogic:armyEnterMap( _memberRid, army.armyIndex, armyInfo, fromType, toType, buildInfo.pos, _marchArgs.targetPos,
                                        _marchArgs.targetObjectIndex, _marchArgs.targetType, buildRadius, targetRadius or 0 )
                end
                buildArmyIndex = index
            end
        end
        -- 移除离开的部队
        if buildArmyIndex then
            buildInfo.reinforces[buildArmyIndex] = nil
            -- 推送联盟建筑部队信息到关注角色中
            GuildBuildLogic:syncGuildBuildArmy( objectIndex, nil, nil, { buildArmyIndex } )
        end
    elseif _type == Enum.GuildResourceCenterReset.SPEED_CHANGE then
        -- 联盟成员采集速度变化
        local memberRids
        if _memberRid then
            if not Common.isTable( _memberRid ) then
                memberRids = {}
                memberRids[_memberRid] = true
            else
                memberRids = _memberRid
            end
        else
            memberRids = GuildLogic:getGuild( _guildId, Enum.Guild.members ) or {}
        end
        -- 本次采集时间
        local collectTime = nowTime - ( buildInfo.resourceCenter and buildInfo.resourceCenter.lastCollectTime or nowTime )
        for _, army in pairs( buildInfo.reinforces or {} ) do
            armyInfo = ArmyLogic:getArmy( army.rid, army.armyIndex )
            if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                collectResource = armyInfo.collectResource or {}
                -- 实际采集量
                realCollect = math.floor( collectTime * army.collectSpeed / collectSpeedMultiple )
                collectResource.collectNum = collectResource.collectNum + realCollect
                collectResource.lastSpeedChangeTime = nowTime
                -- 更新资源中心当前储量
                curResourceNum = curResourceNum - realCollect

                if memberRids[army.rid] then
                    -- 角色采集速度有变化
                    army.collectSpeed = ResourceLogic:getArmyCollectSpeedOnGuildResource( army.rid, army.armyIndex, armyInfo, buildInfo.type, buildInfo.pos )
                    collectResource.collectSpeed = army.collectSpeed
                end
                collectSumSpeed = collectSumSpeed + army.collectSpeed
                -- 负载量
                leftLoad = ResourceLogic:getArmyLeftLoad( army.rid, army.armyIndex, armyInfo )
                -- 负载量转换为资源携带量
                leftLoad = ResourceLogic:loadToResourceCount( resourceType, leftLoad )
                leftLoad = leftLoad - collectResource.collectNum
                roleCollectFinishTime = nowTime + math.ceil( leftLoad / army.collectSpeed * collectSpeedMultiple )
                collectResource.endTime = roleCollectFinishTime
                if closeTime > roleCollectFinishTime then
                    closeTime = roleCollectFinishTime
                end
                -- 通知客户端
                syncArmys[army.rid] = {}
                syncArmys[army.rid][army.armyIndex] = { [Enum.Army.collectResource] = collectResource }
                collectRoleNum = collectRoleNum + 1
            end
        end
    end

    -- 取离当前时间点最近的时间
    local collectFinishTime
    if collectSumSpeed > 0 then
        collectFinishTime = nowTime + math.ceil( curResourceNum / collectSumSpeed * collectSpeedMultiple )
        closeTime = math.min( closeTime, collectFinishTime )
    end

    buildInfo.resourceCenter = {
        resourceNum = curResourceNum,
        lastCollectTime = nowTime,
        collectSpeed = collectSumSpeed,
    }
    updateMapBuildInfo.resourceAmount = curResourceNum
    updateMapBuildInfo.collectTime = nowTime
    updateMapBuildInfo.collectSpeed = collectSumSpeed
    updateMapBuildInfo.collectRoleNum = collectRoleNum

    -- 更新联盟资源中心信息
    GuildBuildLogic:setGuildBuild( _guildId, _buildIndex, {
        [Enum.GuildBuild.resourceCenter] = buildInfo.resourceCenter,
        [Enum.GuildBuild.reinforces] = buildInfo.reinforces,
    } )

    -- 通知客户端
    local minTime = math.min( resourceTimeOut, collectFinishTime or 0 )
    for memberRid, armys in pairs( syncArmys ) do
        for armyIndex, army in pairs( armys ) do
            if army.collectResource.endTime then
                army.collectResource.endTime = math.min( army.collectResource.endTime, minTime )
            end
            ArmyLogic:setArmy( memberRid, armyIndex, army )
            ArmyLogic:syncArmy( memberRid, armyIndex, army, true )
        end
    end

    if closeTime == resourceTimeOut then
        -- 资源中心超时消失定时器
        resourceCenterTimers[_guildId] = Timer.runAt( closeTime, guildResourceCenterTimeOut, _guildId, _buildIndex )
    else
        -- 资源中心被采集完或角色采集满定时器
        resourceCenterTimers[_guildId] = Timer.runAt( closeTime, guildResourceCenterCollectFinish, _guildId, _buildIndex )
    end

    MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, updateMapBuildInfo )
end

---@see 创建联盟资源中心增加超时定时器
function accept.addResourceCenterDeleteTimer( _guildId, _buildIndex, _buildInfo )
    local buildInfo = _buildInfo or GuildBuildLogic:getGuildBuild( _guildId, _buildIndex ) or {}
    if table.empty( buildInfo ) then return end

    if resourceCenterTimers[_guildId] then
        Timer.delete( resourceCenterTimers[_guildId] )
    end

    local sBuildingType = CFG.s_AllianceBuildingType:Get( buildInfo.type )

    -- 联盟资源中心超时删除时间
    local resourceTimeOut = buildInfo.createTime + sBuildingType.stillTime
    resourceCenterTimers[_guildId] = Timer.runAt( resourceTimeOut, guildResourceCenterTimeOut, _guildId, _buildIndex )
end

---@see 联盟研究完成
local function technologyResearchFinish( _guildId )
    -- 研究完成
    MSM.GuildMgr[_guildId].req.guildTechnologyResearchFinish( _guildId )
    -- 删除定时器
    technologyResearchTimers[_guildId] = nil
end

---@see 增加联盟科技研究完成定时器
function response.addTechnologyResearchTimer( _guildId )
    local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.technologies, Enum.Guild.researchTechnologyType, Enum.Guild.researchTime } )
    local technologyType = guildInfo.researchTechnologyType
    if not technologyType or technologyType <= 0 then return end
    -- 研究的科技ID
    local technologyId = technologyType * 100 + guildInfo.technologies[technologyType].level + 1
    local sAllianceStudy = CFG.s_AllianceStudy:Get( technologyId )
    if not sAllianceStudy then
        GuildLogic:setGuild( _guildId, { [Enum.Guild.researchTechnologyType] = 0, [Enum.Guild.researchTime] = 0 } )
        return
    end
    local nowTime = os.time()
    if guildInfo.researchTime + sAllianceStudy.costTime > nowTime then
        -- 研究还未完成, 增加定时器
        technologyResearchTimers[_guildId] = Timer.runAt( guildInfo.researchTime + sAllianceStudy.costTime, technologyResearchFinish, _guildId )
    else
        -- 研究已完成
        technologyResearchFinish( _guildId )
    end
end

---@see 联盟建筑耐久上限变化
function response.buildDurableLimitChange( _guildId )
    local nowTime = os.time()
    local durableLimit, objectIndex, durableUp, finishTime, durable, buildBurnInfo
    local durableMulti = GuildLogic:getGuildAttr( _guildId, Enum.Guild.allianceBuildingDurableMulti ) or 0
    local guildBuilds = GuildBuildLogic:getGuildBuild( _guildId ) or {}
    for buildIndex, buildInfo in pairs( guildBuilds ) do
        -- 联盟旗帜或者联盟要塞的上限才会变化
        if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
            or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND or buildInfo.type == Enum.GuildBuildType.FLAG then
            durableLimit = GuildBuildLogic:getBuildDurableLimit( _guildId, buildInfo.type, durableMulti )
            durable = buildInfo.durable
            if durable > durableLimit then
                durable = durableLimit
            end
            if buildInfo.status == Enum.GuildBuildStatus.INVALID then
                -- 失效状态变为维修状态
                buildInfo.buildBurnInfo = buildInfo.buildBurnInfo or {}
                buildInfo.buildBurnInfo.lastDurableTime = nowTime
                GuildBuildLogic:setGuildBuild( _guildId, buildIndex, {
                    [Enum.GuildBuild.durableLimit] = durableLimit,
                    [Enum.GuildBuild.status] = Enum.GuildBuildStatus.REPAIR,
                    [Enum.GuildBuild.durable] = durable,
                    [Enum.GuildBuild.buildBurnInfo] = buildInfo.buildBurnInfo,
                } )
                -- 增加回复耐久定时器定时器
                snax.self().post.addGuildBuildDurableTimer( _guildId, buildIndex )
            elseif buildInfo.status == Enum.GuildBuildStatus.BURNING then
                -- 燃烧中
                GuildBuildLogic:setGuildBuild( _guildId, buildIndex, { [Enum.GuildBuild.durableLimit] = durableLimit, [Enum.GuildBuild.durable] = durable } )
                -- 更新建筑aoi耐久上限
                objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, buildIndex )
                MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, { durableLimit = durableLimit, durable = durable } )
            elseif buildInfo.status == Enum.GuildBuildStatus.NORMAL then
                -- 正常状态变为维修状态
                buildBurnInfo = buildInfo.buildBurnInfo or {}
                buildBurnInfo.lastDurableTime = nowTime
                GuildBuildLogic:setGuildBuild( _guildId, buildIndex, {
                    [Enum.GuildBuild.durableLimit] = durableLimit,
                    [Enum.GuildBuild.status] = Enum.GuildBuildStatus.REPAIR,
                    [Enum.GuildBuild.durable] = durable,
                    [Enum.GuildBuild.buildBurnInfo] = buildBurnInfo,
                } )
                -- 增加回复耐久定时器定时器
                snax.self().post.addGuildBuildDurableTimer( _guildId, buildIndex )
            elseif buildInfo.status == Enum.GuildBuildStatus.REPAIR then
                GuildBuildLogic:setGuildBuild( _guildId, buildIndex, {
                    [Enum.GuildBuild.durableLimit] = durableLimit,
                    [Enum.GuildBuild.durable] = durable
                } )
                -- 维修中,更新维修完成时间
                if not guildTimers[_guildId] then
                    guildTimers[_guildId] = {}
                end

                if guildTimers[_guildId][buildIndex] then
                    Timer.delete( guildTimers[_guildId][buildIndex] )
                end
                durableUp = CFG.s_AllianceBuildingType:Get( buildInfo.type, "durableUp" ) / 3600
                -- 耐久恢复时间点
                durable = buildInfo.durable + math.floor( durableUp * ( nowTime - buildInfo.buildBurnInfo.lastDurableTime ) )
                if durable >= durableLimit then
                    guildBuildDurableFinish( _guildId, buildIndex )
                else
                    finishTime = nowTime + math.ceil( ( durableLimit - durable ) / durableUp )
                    -- 增加耐久完全恢复定时器
                    guildTimers[_guildId][buildIndex] = Timer.runAt( finishTime, guildBuildDurableFinish, _guildId, buildIndex )
                    -- 更新地图建筑信息
                    objectIndex = MSM.GuildBuildIndexMgr[_guildId].req.getGuildBuildIndex( _guildId, buildIndex )
                    if objectIndex then
                        MSM.SceneGuildBuildMgr[objectIndex].post.updateGuildBuildInfo( objectIndex, { durableLimit = durableLimit } )
                    end
                end
            end
        end
    end
end

---@see 删除联盟建筑定时器
function accept.deleteGuildBuildTimer( _guildId, _buildIndex )
    -- 删除建筑建造定时器
    if guildTimers[_guildId] and guildTimers[_guildId][_buildIndex] then
        if guildTimers[_guildId][_buildIndex] then
            Timer.delete( guildTimers[_guildId][_buildIndex] )
        end

        guildTimers[_guildId][_buildIndex] = nil
        if table.empty( guildTimers[_guildId] ) then
            guildTimers[_guildId] = nil
        end
    end

    -- 删除建造超时定时器
    if guildBuildStatusTimers[_guildId] then
        if guildBuildStatusTimers[_guildId][_buildIndex] then
            Timer.delete( guildBuildStatusTimers[_guildId][_buildIndex] )
        end
        guildBuildStatusTimers[_guildId][_buildIndex] = nil
        if table.empty( guildBuildStatusTimers[_guildId] ) then
            guildBuildStatusTimers[_guildId] = nil
        end
    end
end