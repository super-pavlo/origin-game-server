--[[
 * @file : ScoutsLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-02-20 16:02:07
 * @Last Modified time: 2020-02-20 16:02:07
 * @department : Arabic Studio
 * @brief : 斥候相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local EmailLogic = require "EmailLogic"
local ArmyLogic = require "ArmyLogic"
local DenseFogLogic = require "DenseFogLogic"
local MapObjectLogic = require "MapObjectLogic"
local LogLogic = require "LogLogic"

local ScoutsLogic = {}

---@see 斥候探索迷雾
function ScoutsLogic:discoverDenseFog( _rid, _objectIndex, _scoutsIndex, _pos )
    local scoutView = RoleLogic:getRole( _rid, Enum.Role.scoutView )
    local allDesenFog, allDesenFogPos = DenseFogLogic:getAllDenseFog( _rid, scoutView, _pos, true )
    -- 计算下一个探索坐标点
    local nextPos = self:getNextDenseFogPos( allDesenFog, allDesenFogPos, _pos )
    -- 继续移动探索
    if nextPos then
        MSM.MapMarchMgr[_objectIndex].post.scoutsDiscoverDenseFog(  _rid, _objectIndex, _scoutsIndex, { _pos, nextPos }, allDesenFog, allDesenFogPos )
    else
        -- 直接全开
        DenseFogLogic:openAllDenseFog( _rid, _objectIndex, _scoutsIndex, allDesenFog, _pos )
    end
end

---@see 计算斥候在迷雾内的下一个坐标点
function ScoutsLogic:getNextDenseFogPos( _allDesenFog, _allDenseFogPos, _scoutsPos )
    if not _allDesenFog then
        return
    end
    -- 找出大于21距离的未探索的迷雾点
    local pos
    for index, rule in pairs(_allDesenFog) do
        if rule == 0 then
            pos = _allDenseFogPos[index]
            if math.sqrt( ( pos.x - _scoutsPos.x) ^ 2 + ( pos.y - _scoutsPos.y) ^ 2 ) >= 21 then
                return pos
            end
        end
    end
end

---@see 根据坐标获取斥候视野内的迷雾列表
function ScoutsLogic:getDenseFogWithScoutView( _pos, _roleDenseFog )
    -- 找出斥候视野范围内的迷雾(斥候视野固定3600*3600,2格小迷雾)
    local allDenseFogIndex = {}
    local denseFogIndex
    local desenFogSize = Enum.DesenFogSize
    for x = _pos.x, _pos.x + desenFogSize, 100 do
        for y = _pos.y, _pos.y + desenFogSize, 100 do
            denseFogIndex = DenseFogLogic:getDenseFogIndexByPos({ x = x, y = y } )
            if denseFogIndex >= 1 then
                if not allDenseFogIndex[denseFogIndex] then
                    allDenseFogIndex[denseFogIndex] = DenseFogLogic:getSmallFogRule( _roleDenseFog, denseFogIndex )
                end
            end
        end
    end
    for x = _pos.x, _pos.x - desenFogSize, -100 do
        for y = _pos.y, _pos.y - desenFogSize, -100 do
            denseFogIndex = DenseFogLogic:getDenseFogIndexByPos({ x = x, y = y } )
            if denseFogIndex >= 1 then
                if not allDenseFogIndex[denseFogIndex] then
                    allDenseFogIndex[denseFogIndex] = DenseFogLogic:getSmallFogRule( _roleDenseFog, denseFogIndex )
                end
            end
        end
    end
    for x = _pos.x, _pos.x - desenFogSize, -100 do
        for y = _pos.y, _pos.y + desenFogSize, 100 do
            denseFogIndex = DenseFogLogic:getDenseFogIndexByPos({ x = x, y = y } )
            if denseFogIndex >= 1 then
                if not allDenseFogIndex[denseFogIndex] then
                    allDenseFogIndex[denseFogIndex] = DenseFogLogic:getSmallFogRule( _roleDenseFog, denseFogIndex )
                end
            end
        end
    end
    for x = _pos.x, _pos.x + desenFogSize, 100 do
        for y = _pos.y, _pos.y - desenFogSize, -100 do
            if denseFogIndex >= 1 then
                denseFogIndex = DenseFogLogic:getDenseFogIndexByPos( { x = x, y = y } )
                if not allDenseFogIndex[denseFogIndex] then
                    allDenseFogIndex[denseFogIndex] = DenseFogLogic:getSmallFogRule( _roleDenseFog, denseFogIndex )
                end
            end
        end
    end
    return allDenseFogIndex
end

---@see 增加斥候队列上限
function ScoutsLogic:addScoutsMax( _rid, _isLogin )
    local scoutNumber = RoleLogic:getRole( _rid, Enum.Role.scoutNumber )
    local scoutsInfo = self:getScouts( _rid )
    local curCount = table.size(scoutsInfo)
    if curCount < scoutNumber then
        local addScoutsInfo
        for i = curCount + 1, scoutNumber do
            -- 新增斥候
            addScoutsInfo =  {
                scoutsIndex = i,
                scoutsStatus = Enum.ArmyStatus.STANBY
            }
            self:addScouts( _rid, i, addScoutsInfo )
            -- 同步给客户端
            if not _isLogin then
                self:syncScouts( _rid, { [i] = addScoutsInfo } )
            end
        end

        RoleLogic:setRole( _rid, { [Enum.Role.scoutNumber] = scoutNumber } )
    end
end

---@see 同步斥候信息
function ScoutsLogic:syncScouts( _rid, _scoutsQueue, _scoutsIndex )
    local scoutsQueue = _scoutsQueue or self:getScouts( _rid, _scoutsIndex )
    Common.syncMsg( _rid, "Role_ScoutsInfo", { scoutsQueue = scoutsQueue } , true, true )
end

---@see 同步斥候状态
function ScoutsLogic:syncScountsStatus( _rid, _scoutsIndex, _status )
    local scoutsInfo = self:getScouts( _rid, _scoutsIndex )
    if scoutsInfo then
        scoutsInfo.scoutsStatus = _status
        self:setScouts( _rid, _scoutsIndex, { scoutsStatus = _status } )
        -- 同步给客户端
        Common.syncMsg( _rid, "Role_ScoutsInfo", { scoutsQueue = {
                                                                    [_scoutsIndex] = {
                                                                                        scoutsIndex = _scoutsIndex,
                                                                                        scoutsStatus = _status
                                                                                }
                                                                }
                                                } , true, true )
    end
end

---@see 增加斥候地图索引
function ScoutsLogic:addObjectIndexToScouts( _rid, _scoutsIndex, _objectIndex )
    local scoutsInfo = self:getScouts( _rid, _scoutsIndex )
    if scoutsInfo then
        scoutsInfo.objectIndex = _objectIndex
        self:setScouts( _rid, _scoutsIndex, { objectIndex = _objectIndex } )
        -- 同步给客户端
        Common.syncMsg( _rid, "Role_ScoutsInfo", { scoutsQueue = {
                                                                    [_scoutsIndex] = {
                                                                                        scoutsIndex = _scoutsIndex,
                                                                                        objectIndex = _objectIndex
                                                                                }
                                                                }
                                                } , true, true )
    end
end

---@see 检查斥候索引状态
function ScoutsLogic:checkScoutsObjectIndex( _rid )
    local scoutsInfos = self:getScouts( _rid )
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    for scountIndex, scoutsInfo in pairs(scoutsInfos) do
        if not scoutsInfo.objectIndex or scoutsInfo.objectIndex <= 0 then
            -- 地图上没有斥候对象了
            if not ArmyLogic:checkArmyStatus( scoutsInfo.scoutsStatus, Enum.ArmyStatus.STANBY ) then
                LogLogic:roleScout( {
                    logType = Enum.LogType.SCOUT_MARCHBACK, iggid = iggid, rid = _rid,
                    logType2 = scoutsInfo.denseFogNum or 0, logType3 = os.time() - ( scoutsInfo.leaveCityTime or 0 )
                } )
                self:setScouts( _rid, scountIndex, {
                    scoutsStatus = Enum.ArmyStatus.STANBY, scoutsTargetIndex = 0, denseFogNum = 0, leaveCityTime = 0,
                } )
            end
        else
            -- 判断斥候是否还在
            local scountInfo = MSM.MapObjectTypeMgr[scoutsInfo.objectIndex].req.getObjectType( scoutsInfo.objectIndex )
            if not scountInfo or scountInfo.objectType ~= Enum.RoleType.SCOUTS then
                LogLogic:roleScout( {
                    logType = Enum.LogType.SCOUT_MARCHBACK, iggid = iggid, rid = _rid,
                    logType2 = scoutsInfo.denseFogNum or 0, logType3 = os.time() - ( scoutsInfo.leaveCityTime or 0 )
                } )
                self:setScouts( _rid, scountIndex, {
                    scoutsStatus = Enum.ArmyStatus.STANBY, scoutsTargetIndex = 0, denseFogNum = 0, leaveCityTime = 0
                } )
            end
        end
    end
end

---@see 更新斥候到达时间
function ScoutsLogic:updateScountsArrivalTime( _rid, _scoutsIndex, _arrivalTime, _startTime, _noSync )
    local scoutsInfo = self:getScouts( _rid, _scoutsIndex ) or {}
    if scoutsInfo then
        scoutsInfo.arrivalTime = _arrivalTime
        scoutsInfo.startTime = _startTime
        self:setScouts( _rid, _scoutsIndex, scoutsInfo )
        if not _noSync then
            -- 通知客户端
            Common.syncMsg( _rid, "Role_ScoutsInfo", { scoutsQueue = {
                                                                    [_scoutsIndex] = {
                                                                                        scoutsIndex = _scoutsIndex,
                                                                                        arrivalTime = _arrivalTime,
                                                                                        startTime = _startTime
                                                                                }
                                                                }
                                                } , true, true )
        end
    end
end

---@see 更新斥候到达路径
function ScoutsLogic:updateScountsPath( _rid, _scoutsIndex, _scoutsPath, _noSync )
    local scoutsInfo = self:getScouts( _rid, _scoutsIndex ) or {}
    if scoutsInfo then
        scoutsInfo.scoutsPath = _scoutsPath
        self:setScouts( _rid, _scoutsIndex, scoutsInfo )
        if not _noSync then
            -- 通知客户端
            Common.syncMsg( _rid, "Role_ScoutsInfo", { scoutsQueue = {
                                                                    [_scoutsIndex] = {
                                                                                        scoutsIndex = _scoutsIndex,
                                                                                        scoutsPath = _scoutsPath,
                                                                                }
                                                                }
                                                } , true, true )
        end
    end
end

---@see 更新斥候信息
function ScoutsLogic:updateScoutsInfo( _rid, _scoutsIndex, _scoutsInfo, _noSync )
    self:setScouts( _rid, _scoutsIndex, _scoutsInfo )
    if not _noSync then
        -- 通知客户端
        Common.syncMsg( _rid, "Role_ScoutsInfo", { scoutsQueue = { [_scoutsIndex] = _scoutsInfo } } )
    end
end

---@see 探索发现村庄山洞邮件发送
function ScoutsLogic:scoutDiscoverVillageCaves( _rid, _openDenseFogs )
    if not _openDenseFogs or table.empty( _openDenseFogs ) then return end

    local mapFixPoint, mapFixPointIds, emailOtherInfo, posArg
    local sMapFixPoint = CFG.s_MapFixPoint:Get()
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    local villageCaves = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.VILLAGE_CAVE ) or {}
    local villageMailFind = CFG.s_Config:Get( "villageMailFind" )
    local caveMailFind = CFG.s_Config:Get( "caveMailFind" )
    for _, indexInfo in pairs( _openDenseFogs ) do
        -- 在此迷雾中的山洞村庄
        mapFixPointIds = villageCaves[indexInfo.index] and villageCaves[indexInfo.index][indexInfo.saveIndex] or {}
        for _, mapFixPointId in pairs( mapFixPointIds ) do
            mapFixPoint = sMapFixPoint[mapFixPointId]
            if mapFixPoint and mapFixPoint.type and sResourceGatherType[mapFixPoint.type] then
                posArg = string.format( "%d,%d", mapFixPoint.posX, mapFixPoint.posY )
                emailOtherInfo = {
                    discoverReport = {
                        pos = { x = mapFixPoint.posX, y = mapFixPoint.posY },
                        mapFixPointId = mapFixPointId,
                    },
                    subType = Enum.EmailSubType.DISCOVER_REPORT,
                    emailContents = { posArg, posArg },
                }
                if sResourceGatherType[mapFixPoint.type].type == Enum.ResourceType.CAVE then
                    -- 发现山洞
                    EmailLogic:sendEmail( _rid, caveMailFind, emailOtherInfo )
                elseif sResourceGatherType[mapFixPoint.type].type == Enum.ResourceType.VILLAGE then
                    -- 发现村庄
                    EmailLogic:sendEmail( _rid, villageMailFind, emailOtherInfo )
                end
            end
        end
    end
end

---@see 探索发现圣地邮件发送
function ScoutsLogic:scoutDiscoverHolyLands( _rid, _openDenseFogs )
    if not _openDenseFogs or table.empty( _openDenseFogs ) then return end

    local TaskLogic = require "TaskLogic"
    local holyLandIds, sHoldData, emailOtherInfo, posArg
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local checkPointMailFind = CFG.s_Config:Get( "checkPointMailFind" )
    local holyLandMailFind = CFG.s_Config:Get( "holyLandMailFind" )
    local holyLandDensefogs = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HOLY_LAND_DENSEFOG ) or {}
    for _, indexInfo in pairs( _openDenseFogs ) do
        -- 在此迷雾中的山洞村庄
        holyLandIds = holyLandDensefogs[indexInfo.index] and holyLandDensefogs[indexInfo.index][indexInfo.saveIndex] or {}
        for _, holyLandId in pairs( holyLandIds ) do
            sHoldData = sStrongHoldData[holyLandId]
            if sHoldData and sHoldData.type then
                posArg = string.format( "%d,%d", sHoldData.posX, sHoldData.posY )
                emailOtherInfo = {
                    discoverReport = {
                        pos = { x = sHoldData.posX, y = sHoldData.posY },
                        strongHoldType = sHoldData.type,
                    },

                    subType = Enum.EmailSubType.DISCOVER_REPORT,
                    emailContents = { posArg, posArg },
                }
                if sHoldData.type >= Enum.HolyLandType.CHECKPOINT_LEVEL_1 and sHoldData.type <= Enum.HolyLandType.CHECKPOINT_LEVEL_3 then
                    -- 发现关卡
                    EmailLogic:sendEmail( _rid, checkPointMailFind, emailOtherInfo )
                    -- 增加发现关卡次数
                    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.DISCOVER_CHECKPOINT, Enum.TaskArgDefault, 1 )
                else
                    -- 发现圣地
                    EmailLogic:sendEmail( _rid, holyLandMailFind, emailOtherInfo )
                    -- 增加发现圣地次数
                    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.DISCOVER_HOLYLAND, Enum.TaskArgDefault, 1 )
                end
            end
        end
    end
end


---@see 开启角色所在坐标的大迷雾
---@param _rid integer 角色rid
---@param _pos table 坐标
---@param _sync boolean 是否同步开启的迷雾块给客户端
function ScoutsLogic:openDenseFogOnPosOnCreate( _rid, _pos, _sync )
    local desenFogSize = Enum.DesenFogSize
    local desenFogLineSize = math.floor( Enum.MapSize / Enum.DesenFogSize )
    -- 计算坐标所在的迷雾索引
    local xIndex = math.ceil( _pos.x / desenFogSize )
    if xIndex <= 0 then
        xIndex = 1
    end
    local yIndex = math.floor( _pos.y / desenFogSize )
    if yIndex < 0 then
        yIndex = 0
    end
    local fogSize = 2
    local leftDesenFogIndex = xIndex - fogSize
    local rightDesenFogIndex = xIndex + fogSize
    local bottomDesenFogIndex = yIndex - fogSize
    local topDesenFogIndex = yIndex + fogSize
    -- 判断边界是否越界
    -- 左右必须和中心处于同一行
    if leftDesenFogIndex < 1 then
        -- 修正为最左边
        leftDesenFogIndex = 1
    end
    if rightDesenFogIndex > desenFogLineSize then
        -- 修正为最右边
        rightDesenFogIndex = desenFogLineSize
    end
    -- 上下不能越出地图
    if bottomDesenFogIndex < 0 then
        bottomDesenFogIndex = 0
    end
    if topDesenFogIndex > desenFogLineSize-1 then
        topDesenFogIndex = desenFogLineSize-1
    end

    -- 计算实际小迷雾索引
    local allDenseFog = {}
    for y = bottomDesenFogIndex, topDesenFogIndex do
        for x = leftDesenFogIndex, rightDesenFogIndex do
            table.insert( allDenseFog, x + y * desenFogLineSize )
        end
    end

    -- 转换成角色迷雾数据
    local retDenseFog = {}
    local bitIndex
    local openDenseFogIndexs = {}
    for _, denseFogIndex in pairs(allDenseFog) do
        local saveIndex = math.ceil( denseFogIndex / 64 )
        if not retDenseFog[saveIndex] then
            retDenseFog[saveIndex] = { index = saveIndex, rule = 0 }
        end
        bitIndex = self:denseFogIndexToBitIndex( denseFogIndex )
        local syncClient = self:getSmallFogRule( retDenseFog, denseFogIndex ) == 0
        retDenseFog[saveIndex].rule = retDenseFog[saveIndex].rule | ( 1 << bitIndex )
        if syncClient then
            -- 从未开启变为开启,需要通知客户端
            table.insert( openDenseFogIndexs, denseFogIndex )
        end
    end

    if _sync then
        Common.syncMsg( _rid, "Map_DenseFogOpen", { denseFogIndex = openDenseFogIndexs } )
    end

    return retDenseFog
end

---@see 迷雾索引转位索引
function ScoutsLogic:denseFogIndexToBitIndex( _denseFogIndex )
    local bitIndex = _denseFogIndex % 64 - 1
    if bitIndex < 0 then
        bitIndex = 63
    end
    return bitIndex
end

---@see 获取小迷雾权限
function ScoutsLogic:getSmallFogRule( _roleDenseFogInfo, _denseFogIndex )
    local saveIndex = math.ceil( _denseFogIndex / 64 )
    if saveIndex <= 0 then
        saveIndex = 1
    end
    local rule
    if _roleDenseFogInfo[saveIndex] then
        rule = _roleDenseFogInfo[saveIndex].rule
    else
        rule = 0
    end
    return rule & ( 1 << self:denseFogIndexToBitIndex( _denseFogIndex ) )
end

---@see 获取斥候
function ScoutsLogic:getScouts( _rid, _scoutsIndex, _field )
    return MSM.d_scouts[_rid].req.Get( _rid, _scoutsIndex, _field )
end

---@see 设置斥候
function ScoutsLogic:setScouts( _rid, _scoutsIndex, _field, _value )
    return MSM.d_scouts[_rid].req.Set( _rid, _scoutsIndex, _field, _value )
end

---@see 添加斥候
function ScoutsLogic:addScouts( _rid, _scoutsIndex, _scoutsInfo )
    return MSM.d_scouts[_rid].req.Add( _rid, _scoutsIndex, _scoutsInfo )
end

---@see 强制迁城时处理斥候
function ScoutsLogic:checkScoutsOnForceMoveCity( _rid )
    local objectIndex
    local scouts = self:getScouts( _rid ) or {}
    for _, scoutInfo in pairs( scouts ) do
        objectIndex = scoutInfo.objectIndex
        if not ArmyLogic:checkArmyStatus( scoutInfo.scoutsStatus, Enum.ArmyStatus.STANBY ) and objectIndex and objectIndex > 0 then
            MSM.MapMarchMgr[objectIndex].post.deleteScoutObject( objectIndex )
        end
    end
end

---@see 根据部标类型获取斥候状态
function ScoutsLogic:getScoutStatusByTargetType( _targetObjectIndex, _targetObjectType )
    local scoutsStatus = Enum.ArmyStatus.DISCOVER
    if not _targetObjectType and _targetObjectIndex then
        local taregetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
        _targetObjectType = taregetObjectInfo.objectType
    end

    if _targetObjectType then
        if _targetObjectType == Enum.RoleType.ARMY then
            -- 侦查部队
            scoutsStatus = Enum.ArmyStatus.SCOUTING
        elseif _targetObjectType == Enum.RoleType.CAVE then
            -- 山洞调查中
            scoutsStatus = Enum.ArmyStatus.SURVEYING
        elseif _targetObjectType == Enum.RoleType.CITY or _targetObjectType == Enum.RoleType.RELIC or _targetObjectType == Enum.RoleType.CHECKPOINT
            or MapObjectLogic:checkIsResourceObject( _targetObjectType ) or MapObjectLogic:checkIsAttackGuildBuildObject( _targetObjectType ) then
            -- 斥候侦查
            scoutsStatus = Enum.ArmyStatus.SCOUTING
        elseif _targetObjectType == Enum.RoleType.CITY then
            -- 斥候回城
            scoutsStatus = Enum.ArmyStatus.BACK_CITY
        end
    end

    return scoutsStatus
end

---@see 检查斥候状态是否可以迁城
function ScoutsLogic:checkScoutsOnMoveCity( _rid )
    local scouts = self:getScouts( _rid ) or {}
    for _, scoutInfo in pairs( scouts ) do
        if not ArmyLogic:checkArmyStatus( scoutInfo.scoutsStatus, Enum.ArmyStatus.STANBY ) then
            return false
        end
    end

    return true
end

---@see 增加斥候探索迷雾数量
function ScoutsLogic:addScoutDenseFogNum( _rid, _scoutsIndex, _addNum )
    if _scoutsIndex and _scoutsIndex > 0 then
        local scoutInfo = self:getScouts( _rid, _scoutsIndex ) or {}
        self:setScouts( _rid, _scoutsIndex, { denseFogNum = ( scoutInfo.denseFogNum or 0 ) + _addNum } )
    end
end

return ScoutsLogic