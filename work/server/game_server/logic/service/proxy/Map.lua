--[[
 * @file : Map.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2019-12-09 11:18:37
 * @Last Modified time: 2019-12-09 11:18:37
 * @department : Arabic Studio
 * @brief : 地图协议服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local BuildingLogic = require "BuildingLogic"
local ScoutsLogic = require "ScoutsLogic"
local ArmyLogic = require "ArmyLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local MapLogic = require "MapLogic"
local ItemLogic = require "ItemLogic"
local RoleSync = require "RoleSync"
local GuildLogic = require "GuildLogic"
local ArmyMarchLogic = require "ArmyMarchLogic"
local DenseFogLogic = require "DenseFogLogic"
local MapScoutsLogic = require "MapScoutsLogic"
local MapObjectLogic = require "MapObjectLogic"
local HolyLandLogic = require "HolyLandLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"
local MapProvinceLogic = require "MapProvinceLogic"
local TransportLogic = require "TransportLogic"
local CommonCacle = require "CommonCacle"
local CityReinforceLogic = require "CityReinforceLogic"
local MapMarkerLogic = require "MapMarkerLogic"
local LogLogic = require "LogLogic"

---@see 地图行军
function response.March( msg )
    local rid = msg.rid
    local armyIndex = msg.armyIndex
    local targetType = msg.targetType
    local targetArg = msg.targetArg
    local isSituStation = msg.isSituStation
    local armyIndexs = msg.armyIndexs

    -- 兼容老版本客户端处理
    if not armyIndexs or table.empty( armyIndexs ) then
        if armyIndex then
            armyIndexs = { armyIndex }
        end
    end

    -- 参数检查
    if not armyIndexs or table.empty( armyIndexs ) or not targetType then
        LOG_ERROR("rid(%d) March error, no armyIndexs or no targetType arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    local roleInfo = RoleLogic:getRole( rid, {
        Enum.Role.pos, Enum.Role.technologies, Enum.Role.barbarianLevel,
        Enum.Role.actionForce, Enum.Role.guildId, Enum.Role.level, Enum.Role.situStation
    } )

    -- 目标是否还存在
    local targetInfo, checkError = ArmyMarchLogic:checkMarchTargetExist( rid, targetArg, targetType, armyIndexs )
    if not targetInfo and checkError then
        return nil, checkError
    end

    -- 检查部队是否满足行军条件
    local armyList = {}
    local armyInfo, fixLen, roleSituStation
    local needActiveForce = 0
    local armys = ArmyLogic:getArmy( rid ) or {}
    for i, index in pairs( armyIndexs ) do
        -- 军队是否存在
        armyInfo = armys[index]
        if not armyInfo then
            LOG_ERROR("rid(%d) March error, armyIndex(%d) not exist", rid, index)
            return nil, ErrorCode.MAP_ARMY_NOT_EXIST
        end

        -- 集结和驻防的部队无法操作
        if armyInfo.isInRally then
            LOG_ERROR("rid(%d) March error, armyIndex(%d) in rally", rid, index)
            return nil, ErrorCode.MAP_OPERATE_RALLY_ARMY
        end

        -- 是否处于溃败状态
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
            LOG_ERROR("rid(%d) March error, armyIndex(%d) in failed status", rid, index)
            return nil, ErrorCode.MAP_ARMY_FAILED_STATUS
        end

        armyList[index] = {}

        -- 集结部队不能自由行军
        local objectIndex = MSM.RoleArmyMgr[rid].req.getRoleArmyIndex( rid, index )
        if objectIndex then
            armyList[index].armyObjectIndex = objectIndex
            local objectInfo = MSM.SceneArmyMgr[objectIndex].req.getArmyInfo( objectIndex )
            if objectInfo.isRally then
                -- 集结部队不能自由行军
                LOG_ERROR("rid(%d) March error, armyIndex(%d) in rally army", rid, index)
                return nil, ErrorCode.MAP_RALLY_CANNOT_MOVE
            end
        end

        armyList[index].fromPos = ArmyMarchLogic:getArmyPos( rid, armyInfo )
        armyList[index].armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
        if targetInfo then
            armyList[index].targetRadius = targetInfo.armyRadius
            armyList[index].toType = targetInfo.objectType
        end

        if i == 1 and targetType == Enum.MapMarchTargetType.SPACE then
            -- 向空地行军的第一支部队是否在部队的半径范围内
            -- 在半径范围内，其他部队与第一支部队目标为同一个坐标
            -- 不在半径范围内，其他部队按照第一支部队的半径修正目标坐标
            if not MapLogic:checkRadius( armyList[index].fromPos, targetArg.pos, armyList[index].armyRadius ) then
                fixLen = armyList[index].armyRadius
            end
        end
        if i == 1 then
            -- 第一支部队不需要修正目标坐标
            table.mergeEx(
                armyList[index],
                ArmyMarchLogic:getTargetPos( rid, targetType, targetArg, targetInfo, roleInfo, armyInfo, isSituStation )
            )
        else
            table.mergeEx(
                armyList[index],
                ArmyMarchLogic:getTargetPos( rid, targetType, targetArg, targetInfo, roleInfo,
                    armyInfo, isSituStation, nil, fixLen, armyList[index].fromPos )
            )
        end
        -- 需要消耗的行动力之和
        needActiveForce = needActiveForce + ( armyList[index].needActiveForce or 0 )
        roleSituStation = armyList[index].roleSituStation

        if not armyList[index].targetPos then
            LOG_ERROR("rid(%d) March error, not found targetPos", rid)
            return nil, armyList[index].armyStatus
        end

        local oldTargetIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex or nil
        if oldTargetIndex then
            armyList[index].oldTargetIndex = oldTargetIndex
            armyList[index].oldTargetInfo = MSM.MapObjectTypeMgr[oldTargetIndex].req.getObjectInfo( oldTargetIndex )
        end

        -- 关卡出来判断是否可行走
        if armyList[index].oldTargetInfo and MapObjectLogic:checkIsHolyLandObject( armyList[index].oldTargetInfo.objectType )
            and ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) and
            targetType == Enum.MapMarchTargetType.SPACE then
            if not ArmyWalkLogic:findPath( armyList[index].targetPos, armyList[index].targetPos ) then
                LOG_ERROR("rid(%d) March error, can't arrive targetPos(%s)", rid, tostring(armyList[index].targetPos))
                return
            end
        end

        -- 判断路径是否连通
        if not ArmyWalkLogic:fixPathPoint( nil, armyList[index].toType, { armyList[index].fromPos, armyList[index].targetPos },
                armyList[index].armyRadius, armyList[index].targetRadius, nil, rid, nil, true ) then
            return nil, ErrorCode.MAP_MARCH_PATH_NOT_FOUND
        end
    end

    -- 检查角色行动力是否足够
    if needActiveForce > 0 and not RoleLogic:checkActionForce( rid, needActiveForce ) then
        LOG_ERROR("rid(%d) March error, role actionForce(%d) not enough", rid, needActiveForce)
        return nil, ErrorCode.MAP_MARCH_ACTION_NOT_ENOUGH
    end

    -- 部队行军处理
    local isJoin, oldTargetInfo, armyObjectIndex, marchFlag, targetObjectIndex, oldTargetIndex
    for _, index in pairs( armyIndexs ) do
        isJoin = false
        armyInfo = armys[index]
        oldTargetInfo = armyList[index].oldTargetInfo
        armyObjectIndex = armyList[index].armyObjectIndex
        -- 默认可以行军
        marchFlag = true
        if oldTargetInfo and armyObjectIndex then
            local changeStatus = armyInfo.status
            local isReinforce = ArmyLogic:checkArmyStatus( changeStatus, Enum.ArmyStatus.REINFORCE_MARCH )
            isJoin = ArmyLogic:checkArmyStatus( changeStatus, Enum.ArmyStatus.RALLY_JOIN_MARCH )
            if isReinforce then
                -- 增援行军,取消增援
                if oldTargetInfo.objectType == Enum.RoleType.ARMY then
                    local guildId = RoleLogic:getRole( oldTargetInfo.rid, Enum.Role.guildId )
                    if not MSM.RallyMgr[guildId].req.cacleReinforce( oldTargetInfo.rid, rid ) then
                        LOG_ERROR("army reinforce arrival, can't armymove")
                        marchFlag = false
                    end
                elseif oldTargetInfo.objectType == Enum.RoleType.CITY then
                    -- 原先向城市增援,取消
                    CityReinforceLogic:cancleReinforceCity( oldTargetInfo.rid, rid, true, armyObjectIndex )
                end
                -- 移除增援状态
                changeStatus = ArmyLogic:delArmyStatus( changeStatus, Enum.ArmyStatus.REINFORCE_MARCH )
            elseif isJoin then
                -- 加入集结行军,取消加入集结
                local guildId = RoleLogic:getRole( oldTargetInfo.rid, Enum.Role.guildId )
                if not MSM.RallyMgr[guildId].req.cacleJoinRally( oldTargetInfo.rid, rid ) then
                    LOG_ERROR("army joinRally arrival, can't armymove")
                    marchFlag = false
                end
                -- 移除加入集结状态
                changeStatus = ArmyLogic:delArmyStatus( changeStatus, Enum.ArmyStatus.RALLY_JOIN_MARCH )
            end

            if changeStatus ~= armyInfo.status and marchFlag then
                -- 更新部队状态
                MSM.SceneArmyMgr[armyObjectIndex].req.updateArmyStatus( armyObjectIndex, changeStatus, nil, true )
            end
        end

        oldTargetIndex = armyList[index].oldTargetIndex
        targetObjectIndex = armyList[index].targetObjectIndex

        if marchFlag and ( not targetObjectIndex or not oldTargetIndex or targetObjectIndex ~= oldTargetIndex ) then
            -- 目标变换，返还之前预扣除的行动力
            if not isJoin then
                -- 如果不处于战斗,直接返还,否则等待战斗结束
                if not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
                    ArmyMarchLogic:checkReturnActionForce( rid, roleInfo, armyInfo )
                end
            end
            -- 预扣除行动力
            if armyList[index].needActiveForce and armyList[index].needActiveForce > 0 then
                -- 预扣除行动力
                RoleLogic:addActionForce( rid, - armyList[index].needActiveForce, nil, Enum.LogType.ATTACK_COST_ACTION )
            end
            -- 处理行军
            ArmyMarchLogic:dispatchArmyMarch( rid, armyInfo, targetArg, targetType, armyList[index].targetPos, armyList[index].armyStatus,
                    targetObjectIndex, { preCostActionForce = armyList[index].needActiveForce or 0 }, oldTargetIndex, roleInfo, targetInfo )
        end
    end

    -- 更新角色部队驻扎属性
    if roleInfo.situStation ~= roleSituStation then
        -- 更新原地驻扎状态
        RoleLogic:setRole( rid, Enum.Role.situStation, roleSituStation )
        -- 通知客户端
        RoleSync:syncSelf( rid, { [Enum.Role.situStation] = roleSituStation }, true )
    end
end

---@see 主角色移动
function response.Move( msg )
    local rid = msg.rid
    if not rid then
        return
    end
    local posInfo = msg.posInfo
    local isPreview = msg.isPreview
    local guideHideMapObject = CFG.s_Config:Get("guideHideMapObject")
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.noviceGuideStep, Enum.Role.inPreview } )
    if roleInfo.noviceGuideStep >= guideHideMapObject then
        SM.MapLevelMgr.post.roleUpdateMapLevel( rid, posInfo, isPreview, roleInfo.inPreview, msg.fd, msg.secret )
    end
end

---@see 资源点搜索
function response.SearchResource( msg )
    local rid = msg.rid
    local resourceType = msg.resourceType
    local resourceLevel = msg.resourceLevel

    -- 参数检查
    if not resourceType or not resourceLevel then
        LOG_ERROR("rid(%d) SearchResource, no resourceType or no resourceLevel arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    -- 找到搜索区域半径范围内的所有瓦片索引
    local radius = CFG.s_Config:Get( "resourceGatherFindRadius" ) * Enum.MapPosMultiple
    local pos = RoleLogic:getRole( rid, Enum.Role.pos )
    local zoneIndexs = MapLogic:getZoneIndexsByPosRadius( pos, radius )

    -- 所有满足要求的资源类型ID
    local resourceTypes = {}
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    for id, resourceGatherType in pairs( sResourceGatherType ) do
        if resourceGatherType.type == resourceType and resourceGatherType.level >= resourceLevel then
            resourceTypes[id] = true
        end
    end

    local serviceIndex
    local resources = {}
    for _, zoneIndex in pairs( zoneIndexs ) do
        serviceIndex = MapLogic:getObjectService( nil, zoneIndex )
        table.merge( resources, MSM.ResourceMgr[serviceIndex].req.searchResource( rid, zoneIndex, resourceTypes ) or {} )
    end

    return { resourceType = resourceType, resources = resources }
end

---@see 野蛮人搜索
function response.SearchBarbarian( msg )
    local rid = msg.rid
    local level = msg.level

    -- 参数检查
    if not level or not level then
        LOG_ERROR("rid(%d) SearchBarbarian, no level arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    local openDays = Common.getSelfNodeOpenDays()
    local barbarianRefreshs = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.BARBARIAN_REFRESH ) or {}
    local dayList
    local monsterId = 0
    for dayArg, refreshId in pairs( barbarianRefreshs ) do
        dayList = string.split( dayArg, "-" )
        if tonumber( dayList[1] ) <= openDays and openDays <= tonumber( dayList[2] ) then
            monsterId = refreshId
        end
    end
    -- 超出可刷新等级
    local sMonster = CFG.s_Monster:Get( monsterId )
    if not sMonster or table.empty( sMonster ) then
        LOG_ERROR("rid(%d) SearchBarbarian, s_Monster not monsterId(%d) cfg", rid, monsterId)
        return nil, ErrorCode.CFG_ERROR
    end
    if level > sMonster.level then
        LOG_ERROR("rid(%d) SearchBarbarian, level(%d) great than max level(%d)", rid, level, sMonster.level)
        return nil, ErrorCode.MAP_MAX_LEVEL_LIMIT
    end

    -- 是否存在此配置
    monsterId = Enum.MonsterType.BARBARIAN * 1000 + level
    sMonster = CFG.s_Monster:Get( monsterId )
    if not sMonster or table.empty( sMonster ) then
        LOG_ERROR("rid(%d) SearchBarbarian, s_Monster not monsterId(%d) cfg", rid, monsterId)
        return nil, ErrorCode.CFG_ERROR
    end

    local serviceIndex
    local allBarbarians = {}
    local cityPos = RoleLogic:getRole( rid, Enum.Role.pos )
    sMonster = CFG.s_Monster:Get( monsterId )
    local refreshRadius = sMonster.refreshRadius * Enum.MapPosMultiple
    local allZoneIndexs = MapLogic:getZoneIndexsByPosRadius( cityPos, refreshRadius )
    for _, zoneIndex in pairs( allZoneIndexs ) do
        serviceIndex = MapLogic:getObjectService( nil, zoneIndex )
        table.merge( allBarbarians, MSM.MonsterMgr[serviceIndex].req.searchBarbarian( zoneIndex, monsterId, cityPos ) or {} )
    end

    if table.empty( allBarbarians ) and level <= CFG.s_Config:Get( "barbarianLevelLimit" ) then
        local sMonsterPoint = CFG.s_MonsterPoint:Get()
        local allMonsterPoints = sMonsterPoint[Enum.MonsterType.BARBARIAN]
        -- 获取瓦片索引下所有满足条件的坐标点
        local posRate = {}
        for _, index in pairs( allZoneIndexs ) do
            for _, posInfo in pairs( allMonsterPoints[index] or {} ) do
                if MapLogic:checkRadius( cityPos, posInfo, refreshRadius ) then
                    serviceIndex = MapLogic:getObjectService( posInfo )
                    if not posRate[serviceIndex] then
                        posRate[serviceIndex] = {}
                    end
                    table.insert( posRate[serviceIndex], posInfo )
                end
            end
        end

        local ret, refreshBarbarians
        for index, allPos in pairs( posRate ) do
            ret, refreshBarbarians = MSM.MonsterMgr[index].req.searchAddBarbarian( allPos, sMonster )
            if ret then
                table.insert( allBarbarians, refreshBarbarians )
                break
            end
        end
    end

    return { level = level, barbarians = allBarbarians }
end

---@see 斥候侦查
function response.Scouts( msg )
    local rid = msg.rid
    local scoutIndex = msg.scoutIndex
    local pos = msg.pos
    local targetIndex = msg.targetIndex

    -- 判断是否有此斥候
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.pos, Enum.Role.scoutSpeed, Enum.Role.scoutSpeedMulti, Enum.Role.iggid } )
    local scoutsInfo = ScoutsLogic:getScouts( rid, scoutIndex )
    if not scoutsInfo then
        return nil, ErrorCode.SCOUTS_NOT_FOUND
    end

    -- 斥候侦查忙碌状态
    if ArmyLogic:checkArmyStatus( scoutsInfo.scoutsStatus, Enum.ArmyStatus.SCOUTING_DELETE ) then
        return nil, ErrorCode.SCOUTS_SCOUTSING_BUSY
    end

    -- 如果有对象,获取对象坐标
    if targetIndex then
        local error
        pos, error = MapScoutsLogic:checkScoutTargetInfo( rid, targetIndex )
        if not pos then
            return nil, error
        end
    else
        -- 探索迷雾,判断目的地是否还有未探索的迷雾
        local exist = DenseFogLogic:checkExistDenseFog( rid, pos )
        if not exist then
            return nil, ErrorCode.SCOUTS_NOT_POS_DENSEFOG
        end

        -- 如果坐标是在阻挡内,寻找迷雾内的一个可行走坐标
        if not MapLogic:checkPosIdle( pos, 0.1 ) then
            local scoutView = RoleLogic:getRole( rid, Enum.Role.scoutView )
            local _, allDesenFogPos = DenseFogLogic:getAllDenseFog( rid, scoutView, pos, true )
            for _, newPos in pairs(allDesenFogPos) do
                if MapLogic:checkPosIdle( newPos, 0.1 ) then
                    pos = newPos
                    break
                end
            end
        end
        -- 记录斥候日志
        LogLogic:roleScout( {
            logType = Enum.LogType.SCOUT_DENSEFOG, iggid = roleInfo.iggid,
            logType2 = pos and pos.x or 0, logType3 = pos and pos.y or 0, rid = rid
        } )
    end

    -- 计算斥候速度(最终斥候行军速度 = 斥候行军速度 *（1000 + 斥候行军速度百分比）/1000)
    local speed = math.floor( roleInfo.scoutSpeed * ( 1000 + roleInfo.scoutSpeedMulti ) / 1000 )

    -- 斥候不处于待命中
    if not ArmyLogic:checkArmyStatus( scoutsInfo.scoutsStatus, Enum.ArmyStatus.STANBY ) then
        local objectIndex = scoutsInfo.objectIndex
        local scoutsPos = MSM.SceneScoutsMgr[objectIndex].req.getScoutsPos( objectIndex )
        if not scoutsPos then
            local path = { roleInfo.pos, pos }
            -- 出发侦查
            MSM.MapMarchMgr[objectIndex].req.addScouts( rid, objectIndex, scoutIndex, path, targetIndex, speed )
        else
            local path = { scoutsPos, pos }
            -- 改变目标点
            MSM.MapMarchMgr[objectIndex].req.scoutsChangePos( rid, scoutIndex, path, targetIndex, speed, objectIndex )
        end
    else
        local path = { roleInfo.pos, pos }
        -- 生成一个新的对象ID
        local objectIndex = Common.newMapObjectIndex()
        -- 更新斥候离开城市时间
        ScoutsLogic:updateScoutsInfo( rid, scoutIndex, { leaveCityTime = os.time() } )
        -- 出发侦查
        MSM.MapMarchMgr[objectIndex].req.addScouts( rid, objectIndex, scoutIndex, path, targetIndex, speed )
    end

    return { scoutIndex = scoutIndex }
end

---@see 村庄探索
function response.ScoutVillage( msg )
    local rid = msg.rid
    local targetIndex = msg.targetIndex

    -- 参数检查
    if not targetIndex or targetIndex <= 0 then
        LOG_ERROR("rid(%d) ScoutVillage, no targetIndex arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    -- 村庄是否存在
    local resourceInfo = MSM.SceneResourceMgr[targetIndex].req.getResourceInfo( targetIndex )
    if not resourceInfo or table.empty( resourceInfo ) then
        LOG_ERROR("rid(%d) ScoutVillage, targetIndex(%d) not exist", rid, targetIndex)
        return nil, ErrorCode.MAP_VILLAGE_NOT_EXIST
    end

    -- 是否是村庄
    if not resourceInfo.resourcePointId or resourceInfo.resourcePointId <= 0 then
        LOG_ERROR("rid(%d) ScoutVillage, targetIndex(%d) not village", rid, targetIndex)
        return nil, ErrorCode.MAP_NOT_VILLAGE
    end

    -- 是否已经探索过
    if RoleLogic:checkVillageCave( rid, resourceInfo.resourcePointId ) then
        LOG_ERROR("rid(%d) ScoutVillage, targetIndex(%d) resourcePointId(%d) already scout", rid, targetIndex, resourceInfo.resourcePointId)
        return nil, ErrorCode.MAP_VILLAGE_ALREADY_SCOUT
    end

    local flag, ret = RoleLogic:villageCaveScoutCallBack( rid, resourceInfo.resourcePointId )
    if flag then
        return { villageRewardId = ret, targetIndex = targetIndex }
    else
        return nil, ret
    end
end

---@see 获取指定角色的内城建筑
function response.GetCityDetail( msg )
    local rid = msg.rid
    local targetRid = msg.targetRid

    if rid == targetRid then
        return nil, ErrorCode.MAP_CITY_DETAIL_SELF
    end

    -- 获取目标建筑信息
    local buildingInfo = BuildingLogic:getBuilding( targetRid )

    return { buildingInfo = buildingInfo, targetRid = targetRid }
end

---@see 斥候回城
function response.ScoutsBack( msg )
    local rid = msg.rid
    local objectIndex = msg.objectIndex

    -- 判断是否是斥候
    local objectTypeInfo = MSM.MapObjectTypeMgr[objectIndex].req.getObjectType( objectIndex )
    if not objectTypeInfo or objectTypeInfo.objectType ~= Enum.RoleType.SCOUTS then
        return nil, ErrorCode.SCOUTS_NOT_SCOUTS_TYPE
    end

    local pos = MSM.SceneScoutsMgr[objectIndex].req.getScoutsPos( objectIndex )
    -- 斥候回城
    local cityPos = RoleLogic:getRole( rid, Enum.Role.pos )
    MSM.MapMarchMgr[objectIndex].post.scoutsBackCity( rid, objectIndex, { pos, cityPos }, Enum.ArmyStatus.BACK_CITY )

    return { objectIndex = objectIndex }
end

---@see 获取关卡圣地或联盟建筑中的部队信息
function response.GetGuildBuildArmys( msg )
    local rid = msg.rid
    local objectIndex = msg.objectIndex

    -- 角色是否在联盟中
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) GetGuildBuildArmys, role not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    local mapObjectInfo = MSM.MapObjectTypeMgr[objectIndex].req.getObjectInfo( objectIndex )
    if mapObjectInfo and not table.empty( mapObjectInfo ) and not mapObjectInfo.focusRids[rid] then
        if mapObjectInfo.guildId == guildId then
            if MapObjectLogic:checkIsGuildBuildObject( mapObjectInfo.objectType ) then
                -- 推送联盟建筑中的部队信息
                GuildBuildLogic:pushGuildBuildArmys( rid, guildId, mapObjectInfo.buildIndex, objectIndex )
                -- 建筑添加该角色的关注信息
                MSM.SceneGuildBuildMgr[objectIndex].post.addFocusRid( objectIndex, rid )
            elseif MapObjectLogic:checkIsHolyLandObject( mapObjectInfo.objectType ) then
                -- 推送圣地关卡中的部队信息
                HolyLandLogic:pushHolyLandArmys( rid, mapObjectInfo.strongHoldId, objectIndex )
                -- 建筑添加该角色的关注信息
                MSM.SceneHolyLandMgr[objectIndex].post.addFocusRid( objectIndex, rid )
            end
        end
    end
end

---@see 迁城
function response.MoveCity( msg )
    local rid = msg.rid
    local type = msg.type
    local pos = msg.pos

    -- 参数检查
    if not type or type < Enum.MapCityMoveType.NOVICE or type > Enum.MapCityMoveType.RANDOM then
        LOG_ERROR("rid(%d) MoveCity, no type or no pos arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    -- 迁城检查角色部队
    local ret, error = ArmyLogic:checkArmyOnMoveCity( rid )
    if not ret then
        return nil, error
    end

    -- 检查斥候状态
    if not ScoutsLogic:checkScoutsOnMoveCity( rid ) then
        return nil, ErrorCode.MAP_MOVE_CITY_SCOUTS_ERROR
    end

    -- 检查是否正在运输资源
    local allTransport = TransportLogic:getTransport( rid ) or {}
    if not table.empty( allTransport ) then
        return nil, ErrorCode.MAP_MOVE_CITY_MARCH_BATTLE
    end

    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.pos, Enum.Role.usedMoveCityTypes } ) or 0
    local guildId = roleInfo.guildId or 0

    local cityPos
    local sConfig = CFG.s_Config:Get()
    if type == Enum.MapCityMoveType.RANDOM then
        -- 随机迁城, 角色道具是否足够
        if sConfig.cityRemoveItem4 > 0 then
            if not ItemLogic:checkItemEnough( rid, sConfig.cityRemoveItem4, 1 )  then
                LOG_ERROR("rid(%d) MoveCity, itemId(%d) not enough", rid, sConfig.cityRemoveItem4)
                return nil, ErrorCode.MAP_MOVE_CITY_ITEM_NOT_ENOUGH
            end
            -- 扣除道具
            ItemLogic:delItemById( rid, sConfig.cityRemoveItem4, 1, nil, Enum.LogType.MOVE_CITY_COST_CURRENCY )
        end
        -- 随机迁城
        local provinceIndex = MapProvinceLogic:getPosInProvince( roleInfo.pos )
        cityPos = MapLogic:randomCityIdlePos( rid, msg.uid or 0, provinceIndex, true )
    else
        if not pos or table.empty( pos ) then
            return nil, ErrorCode.MAP_ARG_ERROR
        end
        -- 检查角色是否可以迁城
        ret, error = RoleLogic:checkRoleMoveCity( rid, type, pos, true )
        if not ret then
            return nil, error
        end

        cityPos = { x = pos.x, y = pos.y }
    end

    local roleChangeInfo = { [Enum.Role.pos] = cityPos }
    local usedMoveCityTypes = roleInfo.usedMoveCityTypes or {}
    if not table.exist( usedMoveCityTypes, type ) then
        table.insert( usedMoveCityTypes, type )
        roleChangeInfo[Enum.Role.usedMoveCityTypes] = usedMoveCityTypes
    end

    -- 更新当前城市坐标
    RoleLogic:setRole( rid, roleChangeInfo )
    -- 通知客户端
    RoleSync:syncSelf( rid, roleChangeInfo, true )
    -- 地图城市对象移动
    local cityId = RoleLogic:getRole( rid, Enum.Role.cityId )
    local cityIndex = RoleLogic:getRoleCityIndex( rid )
    MSM.MapObjectMgr[rid].req.cityMove( rid, cityId, cityIndex, cityPos )
    -- 向该城市移动的目标回城处理，结束被攻城战斗
    MSM.SceneCityMgr[cityIndex].post.cityMove( cityIndex, cityPos )
    -- 解锁城堡附近迷雾
    DenseFogLogic:openDenseFogInPos( rid, cityPos, 2 * Enum.DesenFogSize )
    -- 角色在联盟中，同步角色位置给联盟成员
    if guildId > 0 then
        local members = GuildLogic:getAllOnlineMember( roleInfo.guildId ) or {}
        GuildLogic:syncGuildMemberPos( members, { [rid] = { rid = rid, pos = cityPos } } )
    end
    -- 处理城市内的增援部队坐标信息
    ArmyLogic:checkReinforceArmyOnMoveCity( rid, cityPos )
end

---@see 添加地图书签
function response.AddMarker( msg )
    local rid = msg.rid
    local markerId = msg.markerId
    local description = msg.description or ""
    local gameNode = msg.gameNode
    local pos = msg.pos

    -- 参数检查
    if not markerId or not gameNode or not pos then
        LOG_ERROR("rid(%d) AddMarker error, no markerId or no gameNode or no pos arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    local sMapMarkerType = CFG.s_MapMarkerType:Get( markerId )
    if not sMapMarkerType or table.empty( sMapMarkerType ) then
        LOG_ERROR("rid(%d) AddMarker error, s_MapMarkerType no markerId(%d) cfg", rid, markerId)
        return nil, ErrorCode.CFG_ERROR
    end

    -- 书签描述字符个数判断
    if utf8.len( description ) > ( CFG.s_Config:Get( "mapMarkerNameLimit" ) or 100 ) then
        LOG_ERROR("rid(%d) AddMarker error, description(%s) length error", rid, description)
        return nil, ErrorCode.MAP_DESCRIPTION_LENGTH_LIMIT
    end

    if sMapMarkerType.type == Enum.MapMarkerType.PERSON then
        -- 个人书签
        local markers = RoleLogic:getRole( rid, Enum.Role.markers ) or {}
        if table.size( markers ) >= ( CFG.s_Config:Get( "personMarkerLimit" ) or 100 ) then
            LOG_ERROR("rid(%d) AddMarker error, s_MapMarkerType no markerId(%d) cfg", rid, markerId)
            return nil, ErrorCode.MAP_PERSON_MARKER_LIMIT
        end
        -- 添加个人书签
        MapMarkerLogic:addRoleMarker( rid, markerId, description, gameNode, pos, markers, true )
    elseif sMapMarkerType.type == Enum.MapMarkerType.GUILD then
        -- 联盟书签
        local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
        -- 是否在联盟中
        if not guildId or guildId <= 0 then
            LOG_ERROR("rid(%d) AddMarker error, not in guild", rid)
            return nil, ErrorCode.GUILD_NOT_IN_GUILD
        end

        -- 是否有权限
        local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
        if not guildJob or not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.MARK, guildJob ) then
            LOG_ERROR("rid(%d) AddMarker error, not add marker jurisdiction", rid)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end

        -- 添加联盟标签
        local ret, error = MSM.GuildMgr[guildId].req.addGuildMarker( guildId, rid, markerId, description, gameNode, pos )
        if not ret then
            return nil, error
        end
    else
        LOG_ERROR("rid(%d) AddMarker error, not support markerId(%d) type(%d)", rid, markerId, sMapMarkerType.type)
        return nil, ErrorCode.CFG_ERROR
    end

    return { markerId = markerId }
end

---@see 编辑个人地图书签
function response.ModifyMarker( msg )
    local rid = msg.rid
    local markerIndex = msg.markerIndex
    local markerId = msg.markerId
    local description = msg.description or ""

    -- 参数检查
    if not markerIndex or not markerId then
        LOG_ERROR("rid(%d) ModifyMarker error, no markerIndex or no markerId arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    -- 书签是否存在
    local markers = RoleLogic:getRole( rid, Enum.Role.markers ) or {}
    if not markers[markerIndex] then
        LOG_ERROR("rid(%d) ModifyMarker error, marker(%d) not exist", rid, markerIndex)
        return nil, ErrorCode.MAP_ROLE_MARKER_NOT_EXIST
    end

    -- 更新个人书签信息
    markers[markerIndex].markerId = markerId
    markers[markerIndex].description = description
    RoleLogic:setRole( rid, Enum.Role.markers, markers )
    -- 通知客户端
    RoleSync:syncSelf( rid, { [Enum.Role.markers] = { [markerIndex] = markers[markerIndex] } }, true, true )

    return { markerId = markerId }
end

---@see 删除书签
function response.DeleteMarker( msg )
    local rid = msg.rid
    local markerIndex = msg.markerIndex or 0
    local markerId = msg.markerId

    -- 参数检查
    if not markerId then
        LOG_ERROR("rid(%d) DeleteMarker error, no markerId arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    local sMapMarkerType = CFG.s_MapMarkerType:Get( markerId )
    if not sMapMarkerType or table.empty( sMapMarkerType ) then
        LOG_ERROR("rid(%d) DeleteMarker error, s_MapMarkerType no markerId(%d) cfg", rid, markerId)
        return nil, ErrorCode.CFG_ERROR
    end

    if sMapMarkerType.type == Enum.MapMarkerType.PERSON then
        -- 个人书签
        local markers = RoleLogic:getRole( rid, Enum.Role.markers ) or {}
        -- 书签是否存在
        if not markers[markerIndex] then
            LOG_ERROR("rid(%d) DeleteMarker error, marker(%d) not exist", rid, markerIndex)
            return nil, ErrorCode.MAP_ROLE_MARKER_NOT_EXIST
        end

        -- 更新个人书签信息
        markers[markerIndex] = nil
        RoleLogic:setRole( rid, Enum.Role.markers, markers )
        -- 通知客户端
        RoleSync:syncSelf( rid, { [Enum.Role.markers] = { [markerIndex] = { markerIndex = markerIndex, status = Enum.MapMarkerStatus.DELETE } } }, true, true )
    elseif sMapMarkerType.type == Enum.MapMarkerType.GUILD then
        -- 联盟书签
        local guildId = RoleLogic:getRole( rid, Enum.Role.guildId ) or 0
        -- 是否在联盟中
        if not guildId or guildId <= 0 then
            LOG_ERROR("rid(%d) DeleteMarker error, not in guild", rid)
            return nil, ErrorCode.GUILD_NOT_IN_GUILD
        end
        -- 是否有权限
        local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
        if not guildJob or not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.MARK, guildJob ) then
            LOG_ERROR("rid(%d) DeleteMarker error, not delete marker jurisdiction", rid)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end

        local ret, error = MSM.GuildMgr[guildId].req.deleteGuildMarker( guildId, rid, markerId )
        if not ret then
            return nil, error
        end
    end

    return { markerId = markerId }
end

---@see 更新联盟书签读取状态
function response.UpdateGuildMarkerStatus( msg )
    local rid = msg.rid

    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId ) or 0
    -- 是否在联盟中
    if not guildId or guildId <= 0 then
        LOG_ERROR("rid(%d) UpdateGuildMarkerStatus error, not in guild", rid)
        return nil, ErrorCode.GUILD_NOT_IN_GUILD
    end

    -- 更新联盟书签读取状态
    MSM.GuildMgr[guildId].post.updateGuildMarkerStatus( guildId, rid )
end

---@see 添加地图书签
function response.ModifyGuildMarker( msg )
    local rid = msg.rid
    local markerId = msg.markerId
    local description = msg.description or ""
    local gameNode = msg.gameNode
    local pos = msg.pos
    local oldMarkerId = msg.oldMarkerId

    -- 参数检查
    if not markerId or not gameNode or not pos then
        LOG_ERROR("rid(%d) ModifyGuildMarker error, no markerId or no gameNode or no pos arg", rid)
        return nil, ErrorCode.MAP_ARG_ERROR
    end

    local sMapMarkerType = CFG.s_MapMarkerType:Get( markerId )
    if not sMapMarkerType or table.empty( sMapMarkerType ) then
        LOG_ERROR("rid(%d) ModifyGuildMarker error, s_MapMarkerType no markerId(%d) cfg", rid, markerId)
        return nil, ErrorCode.CFG_ERROR
    end

    -- 书签描述字符个数判断
    if utf8.len( description ) > ( CFG.s_Config:Get( "mapMarkerNameLimit" ) or 100 ) then
        LOG_ERROR("rid(%d) ModifyGuildMarker error, description(%s) length error", rid, description)
        return nil, ErrorCode.MAP_DESCRIPTION_LENGTH_LIMIT
    end

    if sMapMarkerType.type == Enum.MapMarkerType.GUILD then
        -- 联盟书签
        local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
        -- 是否在联盟中
        if not guildId or guildId <= 0 then
            LOG_ERROR("rid(%d) ModifyGuildMarker error, not in guild", rid)
            return nil, ErrorCode.GUILD_NOT_IN_GUILD
        end

        -- 是否有权限
        local guildJob = GuildLogic:getRoleGuildJob( guildId, rid )
        if not guildJob or not GuildLogic:checkRoleJurisdiction( rid, Enum.GuildJurisdictionType.MARK, guildJob ) then
            LOG_ERROR("rid(%d) ModifyGuildMarker error, not add marker jurisdiction", rid)
            return nil, ErrorCode.GUILD_NO_JURISDICTION
        end

        -- 添加联盟标签
        local ret, error = MSM.GuildMgr[guildId].req.addGuildMarker( guildId, rid, markerId, description, gameNode, pos, oldMarkerId )
        if not ret then
            return nil, error
        end
    else
        LOG_ERROR("rid(%d) ModifyGuildMarker error, markerId(%d) not guild marker type(%d)", rid, markerId, sMapMarkerType.type)
        return nil, ErrorCode.CFG_ERROR
    end

    return { markerId = markerId }
end