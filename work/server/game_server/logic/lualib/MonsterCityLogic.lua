--[[
* @file : MonsterCityLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Wed May 13 2020 15:02:58 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 野蛮人城寨相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local MapLogic = require "MapLogic"
local MonumentLogic = require "MonumentLogic"
local Timer = require "Timer"
local Random = require "Random"

local MonsterCityLogic = {}

---@see 根据索引计算城寨所在服务
function MonsterCityLogic:getMonsterCityServiceByIndex( _objectIndex )
    local pos = MSM.SceneMonsterCityMgr[_objectIndex].req.getMonsterCityPos( _objectIndex )
    return MapLogic:getObjectService( pos )
end

---@see 击败野蛮人城寨删除野蛮人城寨信息
---@param _objectIndex integer 野蛮人城寨地图对象ID
---@param _pos table 野蛮人城寨坐标
function MonsterCityLogic:defeatMonsterCityCallBack( _objectIndex )
    local serviceIndex = self:getMonsterCityServiceByIndex( _objectIndex )
    -- 删除野蛮人城寨
    MSM.MonsterCityMgr[serviceIndex].post.deleteMonsterCity( _objectIndex )
end

---@see 获取当前所有野蛮人城寨的坐标
function MonsterCityLogic:getAllMonsterCityPos()
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM

    local allMonsterCityPos = {}
    for i = 1, multiSnaxNum do
        table.merge(
            allMonsterCityPos,
            MSM.MonsterCityMgr[i].req.getAllMonsterCityPos()
        )
    end

    return allMonsterCityPos
end

---@see 野蛮人城寨刷新
function MonsterCityLogic:monsterCityRefresh( _isInit, _group )
    local maxMonsterCityLevel = 0
    local monsterCityStones = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.MONSTER_CITY_STONE ) or {}
    for _, monsterCityStone in pairs( monsterCityStones ) do
        if MonumentLogic:checkMonumentStatus( monsterCityStone.openMileStone ) then
            maxMonsterCityLevel = monsterCityStone.monsterId
            break
        end
    end

    LOG_INFO("MonsterCityLogic monsterCityRefresh group(%s) start", tostring(_group))
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    if _isInit then
        -- 服务器重启，全部服务的瓦片都要刷新
        for i = 1, multiSnaxNum do
            -- 刷新该服务的野蛮人城寨
            MSM.MonsterCityMgr[i].post.refreshMonsterCitys( maxMonsterCityLevel, _isInit )
        end
    else
        -- 刷新分组内的瓦片
        local groupZones = MapLogic:getGroupZoneIndexs( Enum.MapObjectRefreshType.BARBARIAN_CITY, _group, multiSnaxNum ) or {}
        for serviceIndex, zoneIndexs in pairs( groupZones ) do
            MSM.MonsterCityMgr[serviceIndex].post.refreshMonsterCitys( maxMonsterCityLevel, _isInit, zoneIndexs )
        end
    end

    return true
end

---@see 野蛮人城寨处理
function MonsterCityLogic:monsterCityInit( _serviceZones )
    -- 野蛮人城寨服务瓦片索引初始化
    for index, zoneIndexs in pairs( _serviceZones ) do
        MSM.MonsterCityMgr[index].req.InitZoneIndex( zoneIndexs )
    end

    -- 野蛮人城寨刷新处理
    local nowTime = os.time()
    local refreshInfo = SM.c_refresh.req.Get( Enum.RefreshType.MONSTER_CITY ) or {}
    if not refreshInfo.nextRefreshTime then
        refreshInfo.nextRefreshTime = 0
    end

    if refreshInfo.nextRefreshTime <= nowTime then
        -- 到刷新时间，直接刷新
        return self:monsterCityRefresh( true )
    end
end

---@see 添加资源点刷新定时器
function MonsterCityLogic:addMonsterCityRefreshTimer( _group )
    -- 增加下次刷新定时器
    local nextRefreshTime
    local nowTime = os.time()
    local refreshInfo = SM.c_refresh.req.Get( Enum.RefreshType.MONSTER_CITY )
    if refreshInfo and refreshInfo.nextRefreshTime then
        if refreshInfo.nextRefreshTime > nowTime then
            nextRefreshTime = refreshInfo.nextRefreshTime
        else
            nextRefreshTime = nowTime + ( CFG.s_Config:Get( "fortressFreshTimeGap" ) or 120 )
            SM.c_refresh.req.Set( Enum.RefreshType.MONSTER_CITY, { nextRefreshTime = nextRefreshTime } )
        end
    else
        nextRefreshTime = nowTime + ( CFG.s_Config:Get( "fortressFreshTimeGap" ) or 120 )
        SM.c_refresh.req.Add( Enum.RefreshType.MONSTER_CITY, { nextRefreshTime = nextRefreshTime } )
    end

    -- 增加下次刷新定时器
    return Timer.runAt( nextRefreshTime, self.monsterCityRefresh, self, nil, _group )
end

---@see 野蛮人城寨超时删除
function MonsterCityLogic:monsterCityTimeOut( _monsterCitys, _zoneMonsterCitys, _monsterCityTimers, _deleteMonsterCitys, _deleteTime )
    if not _monsterCityTimers[_deleteTime] then return end

    -- 处理该定时器下的所有野蛮人城寨信息
    local monsterCity
    for objectIndex in pairs( _monsterCityTimers[_deleteTime].objectIndexs or {} ) do
        monsterCity = _monsterCitys[objectIndex]
        if monsterCity then
            -- 当前没有被攻击，直接移除
            if not monsterCity.attackArmyNum or monsterCity.attackArmyNum <= 0 then
                if Common.getMapObjectLoadFinish() then
                    -- 移除地图野蛮人城寨信息
                    MSM.MapObjectMgr[objectIndex].req.monsterCityLeave( monsterCity.objectId, objectIndex )
                else
                    _deleteMonsterCitys[objectIndex] = monsterCity.objectId
                end
                -- 移除瓦片野蛮人城寨信息
                if monsterCity.zoneIndex and _zoneMonsterCitys[monsterCity.zoneIndex] then
                    _zoneMonsterCitys[monsterCity.zoneIndex][objectIndex] = nil
                end

                -- 移除野蛮人城寨信息
                _monsterCitys[objectIndex] = nil
            end
        end
    end

    -- 移除野蛮人城寨定时器信息
    _monsterCityTimers[_deleteTime] = nil
end

---@see 添加野蛮人城寨
function MonsterCityLogic:addMonsterCity( _monsterCitys, _zoneMonsterCitys, _monsterCityTimers, _deleteMonsterCitys, _monsterId, _pos, _refreshTime )
    local pos = { x = _pos.x, y = _pos.y }
    local zoneIndex = MapLogic:getZoneIndexByPos( pos )
    -- 野蛮人城寨信息进入aoi
    local sMonster = CFG.s_Monster:Get( _monsterId )
    local objectId, objectIndex = MSM.MapObjectMgr[_monsterId].req.monsterCityAddMap( _monsterId, pos, _refreshTime )
    -- 更新野蛮人城寨记录
    _monsterCitys[objectIndex] = {
        objectId = objectId,
        zoneIndex = zoneIndex,
        pos = pos,
        monsterId = _monsterId,
        refreshTime = _refreshTime
    }

    -- 更新瓦片野蛮人城寨信息
    if not _zoneMonsterCitys[zoneIndex] then _zoneMonsterCitys[zoneIndex] = {} end
    _zoneMonsterCitys[zoneIndex][objectIndex] = true
    -- 增加定时器
    local deleteTime = _refreshTime + sMonster.showTime
    if _monsterCityTimers[deleteTime] then
        _monsterCityTimers[deleteTime].objectIndexs[objectIndex] = true
    else
        _monsterCityTimers[deleteTime] = {}
        _monsterCityTimers[deleteTime].timerId = Timer.runAt( deleteTime, self.monsterCityTimeOut, self, _monsterCitys,
                                                _zoneMonsterCitys, _monsterCityTimers, _deleteMonsterCitys, deleteTime )
        _monsterCityTimers[deleteTime].objectIndexs = {}
        _monsterCityTimers[deleteTime].objectIndexs[objectIndex] = true
    end

    return objectIndex
end

---@see 刷新瓦片区域内的野蛮人城寨
function MonsterCityLogic:refreshZoneMonsterCitys( _monsterCitys, _zoneMonsterCitys, _monsterCityTimers, _deleteMonsterCitys, _maxMonsterCityLevel, _refreshZones )
    local sConfig = CFG.s_Config:Get()
    -- 瓦片区域对应的等级
    local sMonsterZoneLevel = CFG.s_MonsterZoneLevel:Get()
    local zoneLevelSize = {}
    zoneLevelSize[1] = sConfig.barbarenFestungenNum1 or 0
    zoneLevelSize[2] = sConfig.barbarenFestungenNum2 or 0
    zoneLevelSize[3] = sConfig.barbarenFestungenNum3 or 0

    local sMonster = CFG.s_Monster:Get()
    -- 所有的野蛮人城寨坐标点
    local sMonsterPoint = CFG.s_MonsterPoint:Get()
    local allMonsterPoints = sMonsterPoint[Enum.MonsterType.BARBARIAN_CITY] or {}

    -- 野蛮人城寨刷新等级信息
    local sMonsterRefresh = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.MONSTER_CITY_REFRESH ) or {}
    local monsterRefreshs = {}
    for level, refreshs in pairs( sMonsterRefresh ) do
        if not monsterRefreshs[level] then
            monsterRefreshs[level] = {}
        end
        for _, refreshLevel in pairs( refreshs ) do
            if refreshLevel.monsterLevel <= _maxMonsterCityLevel then
                table.insert( monsterRefreshs[level], { id = refreshLevel.monsterLevel, rate = refreshLevel.chance } )
            end
        end
    end

    local nowTime = os.time()
    local newRefreshNum = 0
    local allPoints, monsterId
    local zoneLevel, monsterCitySize, addSize, pointRate, isIdel, setObstracleRef
    for zoneIndex in pairs( _refreshZones ) do
        if _zoneMonsterCitys[zoneIndex] then
            -- 瓦片所在区域等级
            zoneLevel = sMonsterZoneLevel[zoneIndex].zoneLevel
            -- 当前野蛮人城寨数
            monsterCitySize = table.size( _zoneMonsterCitys[zoneIndex] )
            addSize = zoneLevelSize[zoneLevel] - monsterCitySize
            if addSize > 0 then
                -- 该瓦片区域野蛮人城寨数不满
                allPoints = table.copy( allMonsterPoints[zoneIndex] or {}, true )
                local index = 0
                if zoneLevel and monsterRefreshs[zoneLevel] and #monsterRefreshs[zoneLevel] > 0 then
                    while index < addSize do
                        if #allPoints <= 0 then
                            break
                        end
                        pointRate = Random.GetRange( 1, #allPoints, 1 )[1]
                        monsterId = Random.GetId( monsterRefreshs[zoneLevel] )
                        isIdel, setObstracleRef = MapLogic:checkPosIdle( allPoints[pointRate], sMonster[monsterId].radiusCollide, nil, nil, true )
                        if isIdel then
                            -- 添加野蛮人城寨
                            self:addMonsterCity( _monsterCitys, _zoneMonsterCitys, _monsterCityTimers, _deleteMonsterCitys, monsterId, allPoints[pointRate], nowTime )
                            -- 重置当前时间
                            newRefreshNum = newRefreshNum + 1
                            if newRefreshNum >= 100 then
                                nowTime = os.time()
                                newRefreshNum = 0
                            end
                            index = index + 1
                            -- 移除旧的阻挡
                            if setObstracleRef then
                                SM.NavMeshObstracleMgr.post.delObstracleByRef( setObstracleRef )
                            end
                        end
                        table.remove( allPoints, pointRate )
                    end
                end
            end
        else
            LOG_ERROR("MonsterCityMgr refreshMonsterCitys error, zoneIndex(%d) not in this service", zoneIndex)
        end
    end
end

return MonsterCityLogic