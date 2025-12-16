--[[
* @file : MonsterCityMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Wed May 13 2020 09:21:57 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 野蛮人城寨刷新服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local MapLogic = require "MapLogic"
local MonsterCityLogic = require "MonsterCityLogic"

---@see 野蛮人城寨信息
---@type table<int, defaultMonsterCityAttrClass>
local monsterCitys = {}
---@see 瓦片对应的野蛮人城寨索引
---@type table<int, table<int, boolean>>
local zoneMonsterCitys = {}
---@see 野蛮人城寨超时定时器
local monsterCityTimers = {}
---@see 重启延迟删除列表
local deleteMonsterCitys = {}

---@see 初始化服务瓦片信息
function response.InitZoneIndex( _zoneIndexs )
    -- 服务瓦片索引初始化
    for _, zoneIndex in pairs( _zoneIndexs ) do
        if not zoneMonsterCitys[zoneIndex] then
            zoneMonsterCitys[zoneIndex] = {}
        end
    end
end

---@see 野蛮人城寨刷新
function accept.refreshMonsterCitys( _maxMonsterCityLevel, _isInit, _groupZoneIndexs )
    if _maxMonsterCityLevel > 0 then
        local refreshZones
        if _isInit then
            -- 重启刷新所有的瓦片
            refreshZones = zoneMonsterCitys
        else
            -- 定时刷新分组内的瓦片
            refreshZones = _groupZoneIndexs
        end
        -- 刷新瓦片内的野蛮人城寨
        local ret, err = xpcall( MonsterCityLogic.refreshZoneMonsterCitys, debug.traceback, MonsterCityLogic, monsterCitys, zoneMonsterCitys, monsterCityTimers, deleteMonsterCitys, _maxMonsterCityLevel, refreshZones )
        if not ret then
            LOG_ERROR("refreshZoneMonsterCitys err:%s", err)
        end
    end

    -- 通知刷新服务本服务完成刷新
    SM.MapObjectRefreshMgr.req.addFinishService( _isInit, Enum.MapObjectRefreshType.BARBARIAN_CITY )
end

---@see 服务器重启增加野蛮人城寨信息
function response.addMonsterCityInfo( _objectId, _objectIndex, _monsterInfo )
    local zoneIndex = MapLogic:getZoneIndexByPos( _monsterInfo.objectPos )
    -- 更新野蛮人城寨记录
    monsterCitys[_objectIndex] = {
        objectId = _objectId,
        zoneIndex = zoneIndex,
        pos = _monsterInfo.objectPos,
        monsterId = _monsterInfo.monsterId,
        refreshTime = _monsterInfo.refreshTime,
    }
    -- 更新瓦片野蛮人城寨信息
    if not zoneMonsterCitys[zoneIndex] then zoneMonsterCitys[zoneIndex] = {} end
    zoneMonsterCitys[zoneIndex][_objectIndex] = true

    -- 增加定时器
    local sMonster = CFG.s_Monster:Get( _monsterInfo.monsterId )
    local deleteTime = _monsterInfo.refreshTime + sMonster.showTime
    if monsterCityTimers[deleteTime] then
        monsterCityTimers[deleteTime].objectIndexs[_objectIndex] = true
    else
        -- 定时器不存在
        monsterCityTimers[deleteTime] = {}
        monsterCityTimers[deleteTime].timerId = Timer.runAt( deleteTime, MonsterCityLogic.monsterCityTimeOut, MonsterCityLogic,
                                            monsterCitys, zoneMonsterCitys, monsterCityTimers, deleteMonsterCitys, deleteTime )
        monsterCityTimers[deleteTime].objectIndexs = {}
        monsterCityTimers[deleteTime].objectIndexs[_objectIndex] = true
    end
end


---@see 删除被击杀野蛮人城寨
function accept.deleteMonsterCity( _objectIndex )
    local monsterCity = monsterCitys[_objectIndex]
    if not monsterCity then
        return
    end
    -- 删除该野蛮人城寨的定时器信息
    local sMonster = CFG.s_Monster:Get( monsterCity.monsterId )
    local deleteTime = monsterCity.refreshTime + sMonster.showTime
    if monsterCityTimers[deleteTime] then
        if monsterCityTimers[deleteTime].objectIndexs and monsterCityTimers[deleteTime].objectIndexs[_objectIndex] then
            monsterCityTimers[deleteTime].objectIndexs[_objectIndex] = nil
        end

        if table.empty( monsterCityTimers[deleteTime].objectIndexs ) then
            Timer.delete( monsterCityTimers[deleteTime].timerId )
            monsterCityTimers[deleteTime] = nil
        end
    end

    -- 地图移除该野蛮人城寨信息
    MSM.MapObjectMgr[_objectIndex].req.monsterCityLeave( monsterCity.objectId, _objectIndex )

    -- 更新瓦片区域野蛮人城寨信息
    if zoneMonsterCitys[monsterCity.zoneIndex]then
        zoneMonsterCitys[monsterCity.zoneIndex][_objectIndex] = nil
    end

    -- 删除野蛮人城寨信息
    monsterCitys[_objectIndex] = nil
end

---@see 获取野蛮人城寨的坐标
function response.getAllMonsterCityPos()
    local monsterCityPos = {}
    local sMonster = CFG.s_Monster:Get()
    for _, monsterCity in pairs( monsterCitys ) do
        table.insert( monsterCityPos, { pos = monsterCity.pos, radiusCollide = sMonster[monsterCity.monsterId].radiusCollide } )
    end

    return monsterCityPos
end

---@see 增加该野蛮人城寨的攻击部队数
function accept.addAttackArmyNum( _objectIndex )
    if monsterCitys[_objectIndex] then
        if not monsterCitys[_objectIndex].attackArmyNum then
            monsterCitys[_objectIndex].attackArmyNum = 1
        else
            monsterCitys[_objectIndex].attackArmyNum = monsterCitys[_objectIndex].attackArmyNum + 1
        end
    end
end

---@see 减少野蛮人城寨的攻击部队数
function accept.subAttackArmyNum( _objectIndex )
    local monsterCityInfo = monsterCitys[_objectIndex]
    if monsterCityInfo and monsterCityInfo.attackArmyNum then
        monsterCityInfo.attackArmyNum = monsterCityInfo.attackArmyNum - 1
        if monsterCityInfo.attackArmyNum <= 0 then
            -- 需要判断是否需要删除野蛮人城寨
            local sMonster = CFG.s_Monster:Get( monsterCityInfo.monsterId )
            if monsterCityInfo.refreshTime + sMonster.showTime <= os.time() then
                -- 移除地图怪物信息
                MSM.MapObjectMgr[_objectIndex].req.monsterLeave( monsterCityInfo.objectId, _objectIndex )
                -- 移除瓦片野蛮人城寨信息
                if monsterCityInfo.zoneIndex and zoneMonsterCitys[monsterCityInfo.zoneIndex] then
                    zoneMonsterCitys[monsterCityInfo.zoneIndex][_objectIndex] = nil
                end
                -- 移除怪物信息
                monsterCitys[_objectIndex] = nil
            end
        end
    end
end

---@see 添加野蛮人城寨
function accept.addMonsterCity( _monsterId, _pos )
    local sMonster = CFG.s_Monster:Get( _monsterId )
    if sMonster and not table.empty( sMonster ) and sMonster.type == Enum.MonsterType.BARBARIAN_CITY then
        MonsterCityLogic:addMonsterCity( monsterCitys, zoneMonsterCitys, monsterCityTimers, deleteMonsterCitys, _monsterId, _pos, os.time() )
    end
end

---@see 重启延迟删除
function accept.deleteObjectOnReboot()
    for objectIndex, objectId in pairs( deleteMonsterCitys ) do
        MSM.MapObjectMgr[objectIndex].req.monsterLeave( objectId, objectIndex )
    end
    deleteMonsterCitys = {}
end

---@see PMLogic获取瓦片对象数量
function response.getZoneObjectNum( _zoneIndex )
    if _zoneIndex then
        return { [_zoneIndex] = table.size( zoneMonsterCitys[_zoneIndex] or {} ) }
    else
        local zoneObjectNum = {}
        for zoneIndex, objects in pairs( zoneMonsterCitys ) do
            zoneObjectNum[zoneIndex] = table.size( objects )
        end

        return zoneObjectNum
    end
end