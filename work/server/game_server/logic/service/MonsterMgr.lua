--[[
* @file : MonsterMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Mon Jan 13 2020 14:34:16 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 怪物刷新服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local MapLogic = require "MapLogic"
local Random = require "Random"
local Timer = require "Timer"
local MonsterLogic = require "MonsterLogic"

---@see 怪物信息
-- { [monsterIndex] = {
--    monsterId = monsterId1, zoneIndex = index2, monsterTypeId = id1
--    refreshTime = time1, pos = pos1 }
-- } }
---@type table<int, defaultMonsterAttrClass>
local monsters = {}
---@see 瓦片怪物信息
---@type table<int, table<int, boolean>>
local zoneMonsters = {}  -- { [zoneIndex] = { [monsterIndex] = {} } }

---@see 怪物定时器信息
---@type table<int, table<string, value>>
local monsterTimers = {} -- { [deleteTime] = { timerId = id1, monsterIndexs = {} } }
---@see 重启延迟删除列表
local deleteMonsters = {}

function accept.refreshMonsters( _isInit, _groupZoneIndexs )
    local refreshZones
    if _isInit then
        -- 重启刷新所有的瓦片
        refreshZones = zoneMonsters
    else
        -- 定时刷新分组内的瓦片
        refreshZones = _groupZoneIndexs
    end

    -- 刷新瓦片资源点
    local ret, err = xpcall( MonsterLogic.refreshZoneMonsters, debug.traceback, MonsterLogic, monsters, zoneMonsters, monsterTimers, deleteMonsters, refreshZones )
    if not ret then
        LOG_ERROR("refreshZoneMonsters err:%s", err)
    end
    SM.MapObjectRefreshMgr.req.addFinishService( _isInit, Enum.MapObjectRefreshType.BARBARIAN )
end

---@see 服务器重启更新野蛮人信息
function response.addMonsterInfo( _monsterId, _monsterIndex, _monsterInfo )
    local zoneIndex = MapLogic:getZoneIndexByPos( _monsterInfo.objectPos )
    -- 更新怪物记录
    monsters[_monsterIndex] = {
        monsterId = _monsterId, zoneIndex = zoneIndex, monsterTypeId = _monsterInfo.monsterId,
        refreshTime = _monsterInfo.refreshTime, pos = _monsterInfo.objectPos,
    }
    -- 更新瓦片怪物信息
    if not zoneMonsters[zoneIndex] then zoneMonsters[zoneIndex] = {} end
    zoneMonsters[zoneIndex][_monsterIndex] = true

    -- 增加定时器
    local sMonster = CFG.s_Monster:Get( _monsterInfo.monsterId )
    local deleteTime = _monsterInfo.refreshTime + sMonster.showTime
    if monsterTimers[deleteTime] then
        monsterTimers[deleteTime].monsterIndexs[_monsterIndex] = true
    else
        -- 定时器不存在
        monsterTimers[deleteTime] = {}
        monsterTimers[deleteTime].timerId = Timer.runAt( deleteTime, MonsterLogic.monsterTimeOut, MonsterLogic, monsters, zoneMonsters, monsterTimers, deleteMonsters, deleteTime )
        monsterTimers[deleteTime].monsterIndexs = {}
        monsterTimers[deleteTime].monsterIndexs[_monsterIndex] = true
    end
end

---@see 删除被击杀野蛮人
function response.deleteMonster( _monsterIndex )
    local monsterInfo = monsters[_monsterIndex]
    if not monsterInfo then
        return
    end
    -- 删除该野蛮人的定时器信息
    local sMonster = CFG.s_Monster:Get( monsterInfo.monsterTypeId )
    local deleteTime = monsterInfo.refreshTime + sMonster.showTime
    if monsterTimers[deleteTime] then
        if monsterTimers[deleteTime].monsterIndexs and monsterTimers[deleteTime].monsterIndexs[_monsterIndex] then
            monsterTimers[deleteTime].monsterIndexs[_monsterIndex] = nil
        end

        if table.empty( monsterTimers[deleteTime].monsterIndexs ) then
            Timer.delete( monsterTimers[deleteTime].timerId )
            monsterTimers[deleteTime] = nil
        end
    end

    -- 地图移除该野蛮人信息
    MSM.MapObjectMgr[monsterInfo.monsterId].req.monsterLeave( monsterInfo.monsterId, _monsterIndex )

    -- 更新瓦片区域野蛮人信息
    if zoneMonsters[monsterInfo.zoneIndex] and zoneMonsters[monsterInfo.zoneIndex][_monsterIndex] then
        zoneMonsters[monsterInfo.zoneIndex][_monsterIndex] = nil
    end

    -- 删除野蛮人信息
    monsters[_monsterIndex] = nil

    return monsterInfo
end

---@see 搜索野蛮人
function response.searchBarbarian( _zoneIndex, _monsterId, _cityPos )
    local monsterPos
    local allPos = {}
    local sMonster = CFG.s_Monster:Get( _monsterId )
    local refreshRadius = sMonster.refreshRadius * Enum.MapPosMultiple
    for monsterIndex in pairs( zoneMonsters[_zoneIndex] or {} ) do
        if _monsterId == monsters[monsterIndex].monsterTypeId then
            monsterPos = MSM.SceneMonsterMgr[monsterIndex].req.getMonsterPos( monsterIndex )
            if MapLogic:checkRadius( _cityPos, monsterPos, refreshRadius ) then
                table.insert( allPos, { pos = monsterPos, objectId = monsterIndex } )
            end
        end
    end

    return allPos
end

---@see 搜索野蛮人
function response.searchAddBarbarian( _allPos, _sMonster )
    local posIndex, monsterIndex
    while #_allPos > 0 do
        -- 随机此次的坐标
        posIndex = Random.GetRange( 1, #_allPos, 1 )[1]
        -- 坐标占用成功
        if MapLogic:checkPosIdle( _allPos[posIndex], _sMonster.radiusCollide, true ) then
            -- 添加野蛮人
            monsterIndex = MonsterLogic:addMonster( monsters, zoneMonsters, monsterTimers, deleteMonsters, _sMonster.ID, _allPos[posIndex], os.time() )
            return true, { pos = _allPos[posIndex], objectId = monsterIndex }
        else
            -- 坐标占用失败从所有坐标中删除此坐标
            table.remove( _allPos, posIndex )
        end
    end
end

---@see 获取怪物信息
function response.getMonsterInfo( _monsterIndex )
    return monsters[_monsterIndex]
end

---@see 检查坐标范围内是否有怪物
function response.checkPosMonster( _pos, _redius, _zoneIndexs )
    local monsterTypeId
    local sMonster = CFG.s_Monster:Get()
    local posMultiple = Enum.MapPosMultiple

    for _, zoneIndex in pairs( _zoneIndexs or {} ) do
        for monsterIndex in pairs( zoneMonsters[zoneIndex] or {} ) do
            monsterTypeId = monsters[monsterIndex] and monsters[monsterIndex].monsterTypeId or nil
            if monsterTypeId and sMonster[monsterTypeId] then
                if MapLogic:checkRadius( _pos, monsters[monsterIndex].pos, _redius + sMonster[monsterTypeId].radiusCollide * posMultiple ) then
                    return true
                end
            end
        end
    end

    return false
end

---@see 检查野蛮人是否超时
function accept.checkMonsterTimeOut( _monsterIndex )
    local monsterInfo = monsters[_monsterIndex]
    if monsterInfo then
        local sMonster = CFG.s_Monster:Get( monsterInfo.monsterTypeId )
        if monsterInfo.refreshTime + sMonster.showTime <= os.time() then
            -- 移除地图怪物信息
            if zoneMonsters[monsterInfo.zoneIndex] then
                zoneMonsters[monsterInfo.zoneIndex][_monsterIndex] = nil
            end
            MSM.MapObjectMgr[_monsterIndex].req.monsterLeave( monsterInfo.monsterId, _monsterIndex )

            monsters[_monsterIndex] = nil
        else
            -- 野蛮人恢复巡逻
            MSM.SceneMonsterMgr[_monsterIndex].req.updateMonsterStatus( _monsterIndex, Enum.ArmyStatus.ARMY_STANBY )
        end
    end
end

---@see PMLogic添加野蛮人
function response.addMonster( _monsterId, _pos )
    local zoneIndex = MapLogic:getZoneIndexByPos( _pos )
    -- 查看当前坐标是否已有野蛮人
    local monsterInfo, flag
    for monsterIndex in pairs( zoneMonsters[zoneIndex] or {} ) do
        monsterInfo = monsters[monsterIndex]
        if monsterInfo and monsterInfo.pos and monsterInfo.pos.x == _pos.x and monsterInfo.pos.y == _pos.y then
            flag = true
            break
        end
    end
    if not flag then
        MonsterLogic:addMonster( monsters, zoneMonsters, monsterTimers, deleteMonsters, _monsterId, _pos, os.time() )

        return true
    end

    return false
end

---@see 初始化服务瓦片信息
function response.InitZoneIndex( _zoneIndexs )
    -- 服务瓦片索引初始化
    for _, zoneIndex in pairs( _zoneIndexs ) do
        if not zoneMonsters[zoneIndex] then
            zoneMonsters[zoneIndex] = {}
        end
    end
end

---@see 重启延迟删除
function accept.deleteObjectOnReboot()
    for objectIndex, objectId in pairs( deleteMonsters ) do
        MSM.MapObjectMgr[objectIndex].req.monsterLeave( objectId, objectIndex )
    end
    deleteMonsters = {}
end

---@see PMLogic获取瓦片对象数量
function response.getZoneObjectNum( _zoneIndex )
    if _zoneIndex then
        return { [_zoneIndex] = table.size( zoneMonsters[_zoneIndex] or {} ) }
    else
        local zoneObjectNum = {}
        for zoneIndex, objects in pairs( zoneMonsters ) do
            zoneObjectNum[zoneIndex] = table.size( objects )
        end

        return zoneObjectNum
    end
end