--[[
* @file : HolyLandLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri May 15 2020 13:03:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 圣地相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local RoleLogic = require "RoleLogic"
local Timer = require "Timer"
local skynet = require "skynet"
local CommonCacle = require "CommonCacle"

local HolyLandLogic = {}

local holyLandGroupTypes

local function checkHolyLandGroupTypes()
    if holyLandGroupTypes then return end

    holyLandGroupTypes = {}
    holyLandGroupTypes[Enum.HolyLandGroupType.SANCTUARY] = Enum.MapUnitViewType.SANCTUARY
    holyLandGroupTypes[Enum.HolyLandGroupType.ALTAR] = Enum.MapUnitViewType.ALTAR
    holyLandGroupTypes[Enum.HolyLandGroupType.HOLY_SHRINE] = Enum.MapUnitViewType.HOLY_SHRINE
    holyLandGroupTypes[Enum.HolyLandGroupType.TEMPLE] = Enum.MapUnitViewType.TEMPLE
    holyLandGroupTypes[Enum.HolyLandGroupType.CHECKPOINT_LEVEL_1] = Enum.MapUnitViewType.CHECKPOINT
    holyLandGroupTypes[Enum.HolyLandGroupType.CHECKPOINT_LEVEL_2] = Enum.MapUnitViewType.CHECKPOINT
    holyLandGroupTypes[Enum.HolyLandGroupType.CHECKPOINT_LEVEL_3] = Enum.MapUnitViewType.CHECKPOINT
end

---@see 圣地类型转为视野范围类型
function HolyLandLogic:holyLandGroupTypeToUnitType( _holyLandGroupType )
    checkHolyLandGroupTypes()

    return holyLandGroupTypes[_holyLandGroupType]
end

---@see 获取圣地信息
function HolyLandLogic:getHolyLand( _holyLandId, _fields )
    return SM.c_holy_land.req.Get( _holyLandId, _fields )
end

---@see 更新圣地信息
function HolyLandLogic:setHolyLand( _holyLandId, _fields, _data )
    return SM.c_holy_land.req.Set( _holyLandId, _fields, _data )
end

---@see 检查是否是关卡类型
function HolyLandLogic:isCheckPointType( _holyLandGroupType )
    if _holyLandGroupType >= Enum.HolyLandGroupType.CHECKPOINT_LEVEL_1
        and _holyLandGroupType <= Enum.HolyLandGroupType.CHECKPOINT_LEVEL_3 then
        return true
    end
end

---@see 检查是否是圣地类型
function HolyLandLogic:isRelicType( _holyLandGroupType )
    if _holyLandGroupType >= Enum.HolyLandGroupType.SANCTUARY
        and _holyLandGroupType <= Enum.HolyLandGroupType.TEMPLE then
        return true
    end
end

---@see 检查坐标或地块是否在圣地范围内
---@return boolean true 在圣地范围内
function HolyLandLogic:checkInHolyLand( _pos, _territoryId, _guildFlag )
    -- 删除圣地占用地块
    return SM.HolyLandMgr.req.checkInHolyLand( _territoryId, _pos, _guildFlag )
end

---@see 纪念碑事件解锁圣地
function HolyLandLogic:mileStoneUnlockHolyLands( _mileStoneId, _finishTime )
    local DenseFogLogic = require "DenseFogLogic"

    local holyLandMileStones = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HOLY_LAND_STORE ) or {}
    if holyLandMileStones[_mileStoneId] and #holyLandMileStones[_mileStoneId] > 0 then
        -- 解锁圣地状态
        SM.HolyLandMgr.post.unlockHolyLands( holyLandMileStones[_mileStoneId], _finishTime )
        -- 所有在线角色开圣地迷雾
        local allOnlineRids = SM.OnlineMgr.req.getAllOnlineRid()
        local sUnitView = CFG.s_UnitView:Get()
        local sStrongHoldData = CFG.s_StrongHoldData:Get()
        local sStrongHoldType = CFG.s_StrongHoldType:Get()
        local sHoldData, sHoldType, pos, unitViewType, radius
        for _, holyLandId in pairs( holyLandMileStones[_mileStoneId] ) do
            sHoldData = sStrongHoldData[holyLandId]
            sHoldType = sStrongHoldType[sHoldData.type]
            pos = { x = sHoldData.posX, y = sHoldData.posY }
            -- 视野范围类型
            unitViewType = self:holyLandGroupTypeToUnitType( sHoldType.group )

            if unitViewType and sUnitView[unitViewType] then
                radius = sUnitView[unitViewType].viewRange
                for _, rid in pairs( allOnlineRids ) do
                    -- 圣地解锁开启圣地附近迷雾
                    DenseFogLogic:openDenseFogInPos( rid, pos, radius )
                end
            end
        end
    end
end

---@see 检查是否需要开启圣地迷雾
function HolyLandLogic:checkHolyLandDensefog( _rid, _noSync )
    local MonumentLogic = require "MonumentLogic"
    local DenseFogLogic = require "DenseFogLogic"

    local sUnitView = CFG.s_UnitView:Get()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()
    local sHoldData, sHoldType, pos, unitViewType, radius
    local holyLandMileStones = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HOLY_LAND_STORE ) or {}
    for mileStoneId, holyLands in pairs( holyLandMileStones ) do
        -- 纪念碑事件已完成
        if MonumentLogic:checkMonumentStatus( mileStoneId ) then
            for _, holyLandId in pairs( holyLands ) do
                sHoldData = sStrongHoldData[holyLandId]
                sHoldType = sStrongHoldType[sHoldData.type]
                pos = { x = sHoldData.posX, y = sHoldData.posY }
                -- 视野范围类型
                unitViewType = self:holyLandGroupTypeToUnitType( sHoldType.group )
                -- 开迷雾
                if unitViewType and sUnitView[unitViewType] then
                    radius = sUnitView[unitViewType].viewRange
                    -- 圣地解锁开启圣地附近迷雾
                    DenseFogLogic:openDenseFogInPos( _rid, pos, radius, _noSync )
                end
            end
        end
    end
end

---@see 推送圣地关卡部队信息
function HolyLandLogic:pushHolyLandArmys( _rid, _holyLandId, _objectIndex )
    local armyList = {}
    local roleInfos = {}
    local leaderBuildArmyIndex, armyInfo
    local roleFields = { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID }
    local reinforces = self:getHolyLand( _holyLandId, Enum.HolyLand.reinforces ) or {}
    local leaderRid, leaderArmyIndex = MSM.SceneHolyLandMgr[_objectIndex].req.getGarrisonLeader( _objectIndex )
    for index, reinforce in pairs( reinforces ) do
        if not roleInfos[reinforce.rid] then
            roleInfos[reinforce.rid] = RoleLogic:getRole( reinforce.rid, roleFields )
        end
        armyInfo = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex )
        if armyInfo and not table.empty( armyInfo ) then
            armyList[index] = {
                buildArmyIndex = index,
                rid = reinforce.rid,
                armyIndex = reinforce.armyIndex,
                mainHeroId = armyInfo.mainHeroId,
                deputyHeroId = armyInfo.deputyHeroId,
                soldiers = armyInfo.soldiers,
                status = armyInfo.status,
                arrivalTime = armyInfo.arrivalTime,
                mainHeroLevel = armyInfo.mainHeroLevel,
                deputyHeroLevel = armyInfo.deputyHeroLevel,
                roleName = roleInfos[reinforce.rid].name,
                roleHeadId = roleInfos[reinforce.rid].headId,
                roleHeadFrameId = roleInfos[reinforce.rid].headFrameID,
            }
            if leaderRid and leaderRid == reinforce.rid and leaderArmyIndex == reinforce.armyIndex then
                leaderBuildArmyIndex = index
            end
        end
    end

    Common.syncMsg( _rid, "Map_HolyLandArmys", { armyList = armyList, leaderBuildArmyIndex = leaderBuildArmyIndex, objectIndex = _objectIndex } )
end

---@see 推送联盟圣地部队信息
function HolyLandLogic:syncHolyLandArmy( _objectIndex, _armyList, _leaderBuildArmyIndex, _deleteBuildArmyIndexs, _focusRids )
    local focusRids = _focusRids or MSM.SceneHolyLandMgr[_objectIndex].req.getFocusRids( _objectIndex ) or {}
    if table.size( focusRids ) > 0 then
        Common.syncMsg( table.indexs( focusRids ), "Map_HolyLandArmys", {
            armyList = _armyList,
            leaderBuildArmyIndex = _leaderBuildArmyIndex,
            objectIndex = _objectIndex,
            deleteBuildArmyIndexs = _deleteBuildArmyIndexs,
        } )
    end
end

---@see 获取联盟圣地部队最大索引
function HolyLandLogic:getHolyLandArmyMaxIndex( _holyLandId )
    local reinforces = self:getHolyLand( _holyLandId, Enum.HolyLand.reinforces ) or {}

    local reinforceIndex = 0
    for index in pairs( reinforces or {} ) do
        if index > 0 then
            reinforceIndex = index
        end
    end

    return reinforceIndex
end

---@see 检查联盟是否有同类型的联盟圣地
function HolyLandLogic:checkGuildSameHolyLandType( _guildId, _holyLandId )
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local holyLandType = sStrongHoldData[_holyLandId].type
    local guildHolyLands = MSM.GuildHolyLandMgr[_guildId].req.getGuildHolyLand( _guildId ) or {}
    for holyLandId in pairs( guildHolyLands[_guildId] or {} ) do
        if holyLandId ~= _holyLandId and sStrongHoldData[holyLandId].type == holyLandType then
            return true
        end
    end
end

---@see 检查圣地增援部队数量是否已达上限
function HolyLandLogic:checkHolyLandCapacity( _holyLandId, _newSoldiers )
    local soldierNum = ArmyLogic:getArmySoldierCount( _newSoldiers )
    local reinforces = self:getHolyLand( _holyLandId, Enum.HolyLand.reinforces ) or {}
    for _, reinforce in pairs( reinforces ) do
        soldierNum = soldierNum + ArmyLogic:getArmySoldierCount( nil, reinforce.rid, reinforce.armyIndex )
    end

    local holyLandType = CFG.s_StrongHoldData:Get( _holyLandId, "type" )
    local armyCntLimit = CFG.s_StrongHoldType:Get( holyLandType, "armyCntLimit" ) or 0
    return soldierNum <= armyCntLimit
end

---@see 增援圣地关卡
function HolyLandLogic:reinforceHolyLand( _rid, _armyIndex, _armyInfo, _reinforceObjectIndex, _fromType, _reinforceIndex, _mapHolyLandInfo )
    -- 判断部队是否在地图上
    local armyInMap, objectIndex, fpos, tpos, isOutCity
    objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
    if objectIndex then
        -- 部队在地图上
        armyInMap = true
        fpos = MSM.SceneArmyMgr[objectIndex].req.getArmyPos( objectIndex )
        ArmyLogic:checkArmyOldTarget( _rid, _armyIndex, _armyInfo, true )
    else
        -- 部队不在地图上
        local oldTargetObjectIndex = _armyInfo.targetArg.targetObjectIndex
        if oldTargetObjectIndex == _reinforceObjectIndex then
            -- 无旧的目标
            fpos = RoleLogic:getRole( _rid, Enum.Role.pos )
            isOutCity = true
        else
            -- 部队旧的目标的处理
            fpos, _fromType = ArmyLogic:checkArmyOldTarget( _rid, _armyIndex, _armyInfo, true )
        end
    end

    tpos = _mapHolyLandInfo.pos
    -- 更新部队信息
    local targetType = Enum.MapMarchTargetType.REINFORCE
    local changeArmyInfo = {}
    if not _armyInfo.targetType or _armyInfo.targetType ~= targetType then
        changeArmyInfo.targetType = targetType
        _armyInfo.status = ArmyLogic:getArmyStatusByTargetType( targetType )
    end
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
        arrivalTime = MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, _reinforceObjectIndex, nil, _armyInfo.status, targetType )
    else
        local armyRadius = CommonCacle:getArmyRadius( _armyInfo.soldiers )
        -- 行军部队加入地图
        arrivalTime = ArmyLogic:armyEnterMap( _rid, _armyIndex, _armyInfo, _fromType, _mapHolyLandInfo.objectType, fpos, tpos,
                        _reinforceObjectIndex, targetType, armyRadius, _mapHolyLandInfo.armyRadius, isOutCity, _reinforceIndex )
    end

    return arrivalTime
end

---@see 检查圣地对应纪念碑事件是否完成
---@return boolean true 纪念碑事件已完成
function HolyLandLogic:checkHolyLandMileStoneFinish( _holyLandId )
    local MonumentLogic = require "MonumentLogic"

    local type = CFG.s_StrongHoldData:Get( _holyLandId, "type" )
    local openMileStone = CFG.s_StrongHoldType:Get( type, "openMileStone" )

    return MonumentLogic:checkMonumentStatus( openMileStone )
end

---@see 联盟圣地部队行军
function HolyLandLogic:holyLandArmyMarch( _objectIndex, _rid, _armyIndex, _marchArgs, _targetInfo )
    local holyLandInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    local reinforces = self:getHolyLand( holyLandInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
    local buildArmyIndex
    for index, reinforce in pairs( reinforces ) do
        if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
            buildArmyIndex = index
            break
        end
    end

    if buildArmyIndex then
        reinforces[buildArmyIndex] = nil
        self:setHolyLand( holyLandInfo.strongHoldId, { [Enum.HolyLand.reinforces] = reinforces } )
        local armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
        if armyObjectIndex then
            -- 在地图上
            MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, _marchArgs.targetObjectIndex, _marchArgs.targetPos, _marchArgs.armyStatus )
        else
            -- 从圣地关卡中退出驻守
            MSM.SceneHolyLandMgr[_objectIndex].post.delGarrisonArmy( _objectIndex, _rid, _armyIndex )
            -- 部队进入地图
            local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex )
            local toType = _targetInfo and _targetInfo.objectType or nil
            local targetInfo = _targetInfo
            if ( not targetInfo or not targetInfo.armyRadius ) and _marchArgs.targetObjectIndex and _marchArgs.targetObjectIndex > 0 then
                targetInfo = MSM.MapObjectTypeMgr[_marchArgs.targetObjectIndex].req.getObjectInfo( _marchArgs.targetObjectIndex )
            end
            ArmyLogic:armyEnterMap( _rid, _armyIndex, armyInfo, holyLandInfo.objectType, toType, holyLandInfo.pos,
                                _marchArgs.targetPos, _marchArgs.targetObjectIndex, _marchArgs.targetType, holyLandInfo.armyRadius,
                                targetInfo and targetInfo.armyRadius )
        end

        -- 推送关卡部队信息到关注角色中
        self:syncHolyLandArmy( _objectIndex, nil, nil, { buildArmyIndex } )
    end
end

function HolyLandLogic:arriveHolyLand( _guildId, _rid, _armyIndex, _objectIndex, _targetObjectIndex )
    local mapHolyLandInfo = MSM.SceneHolyLandMgr[_targetObjectIndex].req.getHolyLandInfo( _targetObjectIndex )
    local holyLandInfo = HolyLandLogic:getHolyLand( mapHolyLandInfo.strongHoldId )
    if holyLandInfo.guildId ~= _guildId then
        return false
    end

    local buildArmyIndex
    for index, reinforce in pairs( holyLandInfo.reinforces or {} ) do
        if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
            buildArmyIndex = index
            break
        end
    end

    if buildArmyIndex then
        local armyStatus = Enum.ArmyStatus.GARRISONING
        local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex, { Enum.Army.targetArg, Enum.Army.status } ) or {}
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
            local BattleCreate = require "BattleCreate"
            BattleCreate:exitBattle( _objectIndex, true )
        end
        local targetArg = armyInfo.targetArg or {}
        targetArg.pos = holyLandInfo.pos
        -- 更新部队状态
        ArmyLogic:setArmy( _rid, _armyIndex, { [Enum.Army.targetArg] = targetArg, [Enum.Army.status] = armyStatus } )
        ArmyLogic:syncArmy( _rid, _armyIndex, { [Enum.Army.targetArg] = targetArg, [Enum.Army.status] = armyStatus }, true )
        -- 推送部队状态信息到关注角色中
        local armyList = {
            [buildArmyIndex] = {
                buildArmyIndex = buildArmyIndex,
                status = armyStatus
            }
        }
        HolyLandLogic:syncHolyLandArmy( _targetObjectIndex, armyList )

        -- 删除地图上的对象
        MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
        -- 移除军队索引信息
        MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, _armyIndex )
        -- 增加驻守部队
        MSM.SceneHolyLandMgr[_targetObjectIndex].post.addGarrisonArmy( _targetObjectIndex, _rid, _armyIndex, buildArmyIndex )

        return true
    end

    return false
end

---@see 更新联盟圣地驻守队长信息
function HolyLandLogic:updateHolyLandLeader( _mapHolyLandInfo, _objectIndex, _leaderRid, _garrisonArmyIndex )
    local reinforces = self:getHolyLand( _mapHolyLandInfo.strongHoldId, Enum.GuildBuild.reinforces ) or {}
    for index, reinforce in pairs( reinforces ) do
        if reinforce.rid == _leaderRid and reinforce.armyIndex == _garrisonArmyIndex then
            self:syncHolyLandArmy( _objectIndex, nil, index )
            break
        end
    end
end

---@see 删除联盟建筑部队处理
function HolyLandLogic:guildHolyLandArmyExit( _holyLandId, _objectIndex, _isDefeat, _mapHolyLandInfo )
    local armyInfo, cityIndex, toPos, armyObjectIndex
    ---@type defaultMapHolyLandInfoClass
    local mapHolyLandInfo = _mapHolyLandInfo or MSM.SceneHolyLandMgr[_objectIndex].req.getHolyLandInfo( _objectIndex )
    local reinforces = self:getHolyLand( _holyLandId, Enum.HolyLand.reinforces ) or {}
    local objectType = Enum.RoleType.RELIC
    local toType = Enum.RoleType.CITY
    local deleteBuildArmyIndexs = table.indexs( reinforces )
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100
    for _, reinforce in pairs( reinforces ) do
        armyInfo = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex )

        -- 通知客户端部队信息
        cityIndex = RoleLogic:getRoleCityIndex( reinforce.rid )
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
            -- 驻守中的部队取建筑坐标
            toPos = RoleLogic:getRole( reinforce.rid, Enum.Role.pos )
            ArmyLogic:armyEnterMap( reinforce.rid, reinforce.armyIndex, armyInfo, objectType, toType, mapHolyLandInfo.pos, toPos, cityIndex,
                                    Enum.MapMarchTargetType.RETREAT, mapHolyLandInfo.armyRadius, cityRadius, nil, nil, _isDefeat )
        else
            armyObjectIndex = MSM.RoleArmyMgr[reinforce.rid].req.getRoleArmyIndex( reinforce.rid, reinforce.armyIndex )
            MSM.MapMarchMgr[armyObjectIndex].req.marchBackCity( reinforce.rid, armyObjectIndex )
        end
    end

    self:setHolyLand( _holyLandId, { [Enum.HolyLand.reinforces] = {} } )
    if #deleteBuildArmyIndexs > 0 then
        self:syncHolyLandArmy( _objectIndex, nil, nil, deleteBuildArmyIndexs )
    end
end

---@see 守护者刷新
function HolyLandLogic:holyLandGuardRefresh()
    local nowTime = os.date( "*t" )
    local guardianBornTime = CFG.s_Config:Get( "guardianBornTime" ) or {}

    if table.exist( guardianBornTime, nowTime.hour ) then
        -- 刷新每个服务的守护者
        local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
        for i = 1, multiSnaxNum do
            -- 清空符文
            MSM.RuneMgr[i].post.cleanRunes()
            -- 刷新守护者
            MSM.HolyLandGuardMgr[i].post.refreshHolyLandGuards()
        end
    end
end

---@see 守护者处理
function HolyLandLogic:guardInit()
    -- 按照圣地Id分配不同的守护者服务
    local holyLands = HolyLandLogic:getHolyLand()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()

    local sHoldType, sHoldData
    for holyLandId in pairs( holyLands ) do
        sHoldData = sStrongHoldData[holyLandId]
        sHoldType = sStrongHoldType[sHoldData.type]

        if sHoldType.group >= Enum.HolyLandGroupType.SANCTUARY and sHoldType.group <= Enum.HolyLandGroupType.TEMPLE then
            -- 圣地类型
            MSM.HolyLandGuardMgr[holyLandId].req.InitHolyLandGuard( holyLandId )
        end
    end

    -- 服务器启动刷新守护者
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        MSM.HolyLandGuardMgr[i].post.refreshHolyLandGuards( true )
    end

    -- 添加下次刷新守护者定时器
    Timer.runEveryHour( self.holyLandGuardRefresh, self )

    return true
end

---@see 获取增援圣地部队信息.用于联盟战争推送
function HolyLandLogic:getHolyLandReinforceInfo( _objectIndex )
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    local roleFields = { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID }
    local reinforces = self:getHolyLand( objectInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
    local roleInfo, armyInfo
    local reinforceDetail = {}
    for _, reinforce in pairs( reinforces ) do
        roleInfo = RoleLogic:getRole( reinforce.rid, roleFields )
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

return HolyLandLogic