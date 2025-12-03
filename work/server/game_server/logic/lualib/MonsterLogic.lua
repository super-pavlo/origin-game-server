--[[
 * @file : MonsterLogic.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2020-03-09 16:12:37
 * @Last Modified time: 2020-03-09 16:12:37
 * @department : Arabic Studio
 * @brief : 怪物相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Timer = require "Timer"
local skynet = require "skynet"
local MapLogic = require "MapLogic"
local AttrDef = require "AttrDef"
local Random = require "Random"

local MonsterLogic = {}

---@see 计算野蛮人部队和数量
function MonsterLogic:cacleMonsterArmyCount( _monsterId )
    local monsterInfo = CFG.s_Monster:Get( _monsterId )
    local sMonsterTroops = CFG.s_MonsterTroops:Get( monsterInfo.monsterTroopsId )
    local soldierTroopsAttr = CFG.s_MonsterTroopsAttr:Get( sMonsterTroops.troopsId )
    if not soldierTroopsAttr then
        return 0, {}
    end
    local sArms = CFG.s_Arms:Get()
    local soldiers = {}
    for _, soldierTroopsAttrInfo in pairs(soldierTroopsAttr) do
        if not soldiers[soldierTroopsAttrInfo.armType] then
            soldiers[soldierTroopsAttrInfo.armType] = {
                id = soldierTroopsAttrInfo.armType,
                type = sArms[soldierTroopsAttrInfo.armType].armsType,
                level = sArms[soldierTroopsAttrInfo.armType].armsLv,
                num = soldierTroopsAttrInfo.armNum
            }
        else
            soldiers[soldierTroopsAttrInfo.armType].num = soldiers[soldierTroopsAttrInfo.armType].num + soldierTroopsAttrInfo.armNum
        end
    end

    local ArmyLogic = require "ArmyLogic"
    local armyCount = ArmyLogic:getArmySoldierCount( soldiers )
    return armyCount, soldiers
end

---@see 判断野蛮人是否恢复血量
function MonsterLogic:checkRecoverArmyCount( _monsterId )
    local monsterInfo = CFG.s_Monster:Get( _monsterId )
    return monsterInfo.recover and monsterInfo.recover == 1
end

---@see 野蛮人刷新
function MonsterLogic:monsterRefresh( _isInit, _group )
    LOG_INFO("MonsterLogic monsterRefresh group(%s) start", tostring(_group))
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    if _isInit then
        -- 服务器重启，全部服务的瓦片都要刷新
        for i = 1, multiSnaxNum do
            -- 刷新该服务的资源点
            MSM.MonsterMgr[i].post.refreshMonsters( _isInit )
        end
    else
        -- 刷新分组内的瓦片
        local groupZones = MapLogic:getGroupZoneIndexs( Enum.MapObjectRefreshType.BARBARIAN, _group, multiSnaxNum ) or {}
        for serviceIndex, zoneIndexs in pairs( groupZones ) do
            MSM.MonsterMgr[serviceIndex].post.refreshMonsters( _isInit, zoneIndexs )
        end
    end
end

---@see 野蛮人初始化
function MonsterLogic:monsterInit( _serviceZones )
    -- 野蛮人服务瓦片索引初始化
    for index, zoneIndexs in pairs( _serviceZones ) do
        MSM.MonsterMgr[index].req.InitZoneIndex( zoneIndexs )
    end

    -- 野蛮人城寨刷新处理
    local nowTime = os.time()
    local refreshInfo = SM.c_refresh.req.Get( Enum.RefreshType.SAVAGE ) or {}
    if not refreshInfo.nextRefreshTime then
        refreshInfo.nextRefreshTime = 0
    end

    if refreshInfo.nextRefreshTime <= nowTime then
        -- 到刷新时间，直接刷新
        self:monsterRefresh( true )

        return true
    end
end

---@see 获取野蛮人所在服务
function MonsterLogic:getMonsterService( _objectIndex, _pos )
    local pos = _pos or MSM.SceneMonsterMgr[_objectIndex].req.getMonsterInitPos( _objectIndex )
    return MapLogic:getObjectService( pos )
end

---@see 获取怪物属性
function MonsterLogic:getMonsterAttr( _monsterId )
    local sMonsterInfo = CFG.s_Monster:Get( _monsterId )
    local attr = AttrDef:getDefaultBattleAttr()
    if sMonsterInfo then
        if sMonsterInfo.monsterTroopsId and sMonsterInfo.monsterTroopsId > 0 then
            local sMonsterTroopsInfo = CFG.s_MonsterTroops:Get( sMonsterInfo.monsterTroopsId )
            if sMonsterTroopsInfo.troopsAttrTypes then
                for index, name in pairs(sMonsterTroopsInfo.troopsAttrTypes) do
                    attr[name] = sMonsterTroopsInfo.troopsAttrDatas[index]
                end
            end
        end
    end
    return attr
end

---@see 添加野蛮人刷新定时器
function MonsterLogic:addMonsterRefreshTimer( _group )
    -- 增加下次刷新定时器
    local nextRefreshTime
    local nowTime = os.time()
    local refreshInfo = SM.c_refresh.req.Get( Enum.RefreshType.SAVAGE )
    if refreshInfo and refreshInfo.nextRefreshTime then
        if refreshInfo.nextRefreshTime > nowTime then
            nextRefreshTime = refreshInfo.nextRefreshTime
        else
            nextRefreshTime = nowTime + ( CFG.s_Config:Get( "barbarianFreshTimeGap" ) or 120 )
            SM.c_refresh.req.Set( Enum.RefreshType.SAVAGE, { nextRefreshTime = nextRefreshTime } )
        end
    else
        nextRefreshTime = nowTime + ( CFG.s_Config:Get( "barbarianFreshTimeGap" ) or 120 )
        SM.c_refresh.req.Add( Enum.RefreshType.SAVAGE, { nextRefreshTime = nextRefreshTime } )
    end

    -- 增加下次刷新定时器
    return Timer.runAt( nextRefreshTime, self.monsterRefresh, self, nil, _group )
end

---@see 野蛮人超时
function MonsterLogic:monsterTimeOut( _monsters, _zoneMonsters, _monsterTimers, _deleteMonsters, _deleteTime )
    if not _monsterTimers[_deleteTime] then return end

    local ArmyLogic = require "ArmyLogic"
    -- 处理该定时器下的所有怪物信息
    local monster, monsterStatus
    for monsterIndex in pairs( _monsterTimers[_deleteTime].monsterIndexs or {} ) do
        monster = _monsters[monsterIndex]
        if monster then
            -- 当前没有被攻击，直接移除
            monsterStatus = MSM.SceneMonsterMgr[monsterIndex].req.getMonsterStatus( monsterIndex )
            if not monsterStatus or not ArmyLogic:checkArmyStatus( monsterStatus, Enum.ArmyStatus.BATTLEING ) then
                if Common.getMapObjectLoadFinish() then
                    -- 移除地图怪物信息
                    MSM.MapObjectMgr[monsterIndex].req.monsterLeave( monster.monsterId, monsterIndex )
                else
                    _deleteMonsters[monsterIndex] = monster.monsterId
                end
                -- 移除瓦片怪物信息
                if monster.zoneIndex and _zoneMonsters[monster.zoneIndex] and _zoneMonsters[monster.zoneIndex][monsterIndex] then
                    _zoneMonsters[monster.zoneIndex][monsterIndex] = nil
                end

                -- 移除怪物信息
                _monsters[monsterIndex] = nil
            end
        end
    end

    -- 移除怪物定时器信息
    _monsterTimers[_deleteTime] = nil
end

---@see 添加野蛮人
function MonsterLogic:addMonster( _monsters, _zoneMonsters, _monsterTimers, _deleteMonsters, _monsterTypeId, _pos, _refreshTime )
    local pos = { x = _pos.x, y = _pos.y }
    local zoneIndex = MapLogic:getZoneIndexByPos( pos )
    -- 怪物信息进入aoi
    local sMonster = CFG.s_Monster:Get( _monsterTypeId )
    local monsterId, monsterIndex = MSM.MapObjectMgr[_monsterTypeId].req.monsterAddMap( _monsterTypeId, pos, _refreshTime )
    -- 更新怪物记录
    _monsters[monsterIndex] = {
        monsterId = monsterId, zoneIndex = zoneIndex, pos = pos,
        monsterTypeId = _monsterTypeId, refreshTime = _refreshTime
    }
    -- 更新瓦片怪物信息
    if not _zoneMonsters[zoneIndex] then _zoneMonsters[zoneIndex] = {} end
    _zoneMonsters[zoneIndex][monsterIndex] = true
    -- 增加定时器
    local deleteTime = _refreshTime + sMonster.showTime
    if _monsterTimers[deleteTime] then
        _monsterTimers[deleteTime].monsterIndexs[monsterIndex] = true
    else
        _monsterTimers[deleteTime] = {}
        _monsterTimers[deleteTime].timerId = Timer.runAt( deleteTime, self.monsterTimeOut, self, _monsters, _zoneMonsters, _monsterTimers, _deleteMonsters, deleteTime )
        _monsterTimers[deleteTime].monsterIndexs = {}
        _monsterTimers[deleteTime].monsterIndexs[monsterIndex] = true
    end

    return monsterIndex
end

---@see 刷新瓦片中的野蛮人
function MonsterLogic:refreshZoneMonsters( _monsters, _zoneMonsters, _monsterTimers, _deleteMonsters, _refreshZones )
    -- 配置数据
    local sConfig = CFG.s_Config:Get()
    local sMonsterPoint = CFG.s_MonsterPoint:Get()
    local allMonsterPoints = sMonsterPoint[Enum.MonsterType.BARBARIAN]
    -- 获取当天刷新配置信息
    local sMonsterRefresh = CFG.s_MonsterRefreshLevel:Get()
    local openDay = Common.getSelfNodeOpenDays()
    -- 野蛮人配置信息
    local sMonster = CFG.s_Monster:Get()
    local dayList, monsterRefreshs
    for dayArg, refresh in pairs( sMonsterRefresh[Enum.MonsterType.BARBARIAN] or {} ) do
        dayList = string.split( dayArg, "-" )
        if tonumber( dayList[1] ) <= openDay and openDay <= tonumber( dayList[2] ) then
            monsterRefreshs = refresh
            break
        end
    end

    local newRefreshNum = 0
    local nowTime = os.time()
    local barbarianSum, allPoints, pointRate, monsterRate, zoneLevel, isIdel, setObstracleRef
    local sMonsterZoneLevel = CFG.s_MonsterZoneLevel:Get()
    for i in pairs( _refreshZones or {} ) do
        if _zoneMonsters[i] then
            -- 当前瓦片区域野蛮人数量
            barbarianSum = table.size( _zoneMonsters[i] )
            if sConfig.barbarianNum > barbarianSum then
                -- 获取坐标
                allPoints = table.copy( allMonsterPoints[i] or {}, true )
                local index = 0
                zoneLevel = sMonsterZoneLevel[i] and sMonsterZoneLevel[i].zoneLevel or nil
                if zoneLevel and monsterRefreshs[zoneLevel] then
                    while index < sConfig.barbarianNum - barbarianSum do
                        if #allPoints <= 0 then
                            break
                        end
                        pointRate = Random.GetRange( 1, #allPoints, 1 )[1]
                        monsterRate = Random.GetId( monsterRefreshs[zoneLevel] )
                        isIdel, setObstracleRef = MapLogic:checkPosIdle( allPoints[pointRate], sMonster[monsterRate.monsterLevel].radiusCollide, true, nil, true )
                        if isIdel then
                            -- 添加怪物
                            MonsterLogic:addMonster( _monsters, _zoneMonsters, _monsterTimers, _deleteMonsters, monsterRate.monsterLevel, allPoints[pointRate], nowTime )
                            index = index + 1
                            newRefreshNum = newRefreshNum + 1
                            if newRefreshNum >= 100 then
                                nowTime = os.time()
                                newRefreshNum = 0
                            end
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
            LOG_ERROR("MonsterMgr refreshMonsters error, zoneIndex(%d) not in this service", i)
        end
    end
end

return MonsterLogic