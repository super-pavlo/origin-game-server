--[[
* @file : MonsterSummonMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Fri Aug 21 2020 11:07:46 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 怪物召唤服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local MapLogic = require "MapLogic"
local RoleLogic = require "RoleLogic"
local Random = require "Random"
local Timer = require "Timer"
local ArmyLogic = require "ArmyLogic"

---@see 召唤怪物信息
---@class defaultSummonMonsterInfoClass
local defaultSummonMonsterInfo = {
    monsterId                   =                   0,              -- 召唤怪物ID
    pos                         =                   {},             -- 坐标
    objectId                    =                   0,              -- c_map_object表ID
    refreshTime                 =                   {},             -- 刷新时间
    objectType                  =                   0,              -- 怪物对象类型
}

---@see 召唤怪物信息
---@type table<int, defaultSummonMonsterInfoClass>
local monsters = {}
---@see 召唤怪物定时器信息
local monsterTimers = {}
---@see 重启延迟删除列表
local deleteMonsters = {}

local function summonMonsterTimeOut( _deleteTime )
    if not monsterTimers[_deleteTime] then return end

    -- 处理该定时器下的所有怪物信息
    local monster, monsterStatus
    for monsterIndex in pairs( monsterTimers[_deleteTime].monsterIndexs or {} ) do
        monster = monsters[monsterIndex]
        if monster then
            -- 当前没有被攻击，直接移除
            monsterStatus = MSM.SceneMonsterMgr[monsterIndex].req.getMonsterStatus( monsterIndex )
            if not monsterStatus or not ArmyLogic:checkArmyStatus( monsterStatus, Enum.ArmyStatus.BATTLEING ) then
                if Common.getMapObjectLoadFinish() then
                    -- 移除地图怪物信息
                    MSM.MapObjectMgr[monsterIndex].req.summonMonsterLeave( monster.objectId, monsterIndex, monster.objectType )
                else
                    deleteMonsters[monsterIndex] = { objectId = monster.objectId, objectType = monster.objectType }
                end

                -- 移除怪物信息
                monsters[monsterIndex] = nil
            end
        end
    end

    -- 移除怪物定时器信息
    monsterTimers[_deleteTime] = nil
end

---@see 添加召唤怪物
local function addSummonMonster( _monsterId, _pos, _objectIndex )
    local sMonster = CFG.s_Monster:Get( _monsterId )
    local objectType = Enum.RoleType.SUMMON_SINGLE_MONSTER
    if sMonster.battleType == Enum.MonsterBattleType.RALLY then
        objectType = Enum.RoleType.SUMMON_RALLY_MONSTER
    end
    local nowTime = os.time()
    local pos = { x = _pos.x, y = _pos.y }
    local objectId = MSM.MapObjectMgr[_objectIndex].req.summonMonsterAddMap( _monsterId, pos, nowTime, _objectIndex, objectType )
    ---@type defaultSummonMonsterInfoClass
    local monsterInfo = const( table.copy( defaultSummonMonsterInfo, true ) )
    monsterInfo.monsterId = _monsterId
    monsterInfo.objectId = objectId
    monsterInfo.pos = pos
    monsterInfo.refreshTime = nowTime
    monsterInfo.objectType = objectType
    -- 更新怪物记录
    monsters[_objectIndex] = monsterInfo

    -- 增加定时器
    local deleteTime = nowTime + sMonster.showTime
    if monsterTimers[deleteTime] then
        monsterTimers[deleteTime].monsterIndexs[_objectIndex] = true
    else
        monsterTimers[deleteTime] = {}
        monsterTimers[deleteTime].timerId = Timer.runAt( deleteTime, summonMonsterTimeOut, deleteTime )
        monsterTimers[deleteTime].monsterIndexs = {}
        monsterTimers[deleteTime].monsterIndexs[_objectIndex] = true
    end
end

---@see 召唤怪物
function response.summonMonster( _rid, _monsterId, _objectIndex )
    local sMonster = CFG.s_Monster:Get( _monsterId )
    if not sMonster or table.empty( sMonster ) then
        LOG_ERROR("rid(%d) summonMonster, s_Monster no monsterId(%d) cfg", _rid, _monsterId)
        return
    end

    local cityPos = RoleLogic:getRole( _rid, Enum.Role.pos )
    local refreshRadius = sMonster.refreshRadius * Enum.MapPosMultiple
    local allZoneIndexs = MapLogic:getZoneIndexsByPosRadius( cityPos, refreshRadius )
    -- 有效坐标点
    local sMonsterPoint = CFG.s_MonsterPoint:Get()
    local allMonsterPoints = sMonsterPoint[Enum.MonsterType.BARBARIAN]
    local posRate = {}
    for _, index in pairs( allZoneIndexs ) do
        for _, posInfo in pairs( allMonsterPoints[index] or {} ) do
            if MapLogic:checkRadius( cityPos, posInfo, refreshRadius ) then
                table.insert( posRate, posInfo )
            end
        end
    end

    local posIndex, isIdel, setObstracleRef
    while #posRate > 0 do
        posIndex = Random.GetRange( 1, #posRate, 1 )[1]
        isIdel, setObstracleRef = MapLogic:checkPosIdle( posRate[posIndex], sMonster.radiusCollide, true, nil, true )
        if isIdel then
            -- 添加召唤怪物
            addSummonMonster( _monsterId, posRate[posIndex], _objectIndex )
            -- 移除旧的阻挡
            if setObstracleRef then
                SM.NavMeshObstracleMgr.post.delObstracleByRef( setObstracleRef )
            end
            return posRate[posIndex]
        else
            table.remove( posRate, posIndex )
        end
    end
end

---@see 重启延迟删除
function accept.deleteObjectOnReboot()
    for objectIndex, monsterInfo in pairs( deleteMonsters ) do
        MSM.MapObjectMgr[objectIndex].req.summonMonsterLeave( monsterInfo.objectId, objectIndex, monsterInfo.objectType )
    end
    deleteMonsters = {}
end

---@see 服务器重启添加召唤怪物信息
function response.addSummonMonsterInfo( _objectId, _objectIndex, _monsterInfo )
    ---@type defaultSummonMonsterInfoClass
    local monsterInfo = const( table.copy( defaultSummonMonsterInfo, true ) )
    monsterInfo.monsterId = _monsterInfo.monsterId
    monsterInfo.objectId = _objectId
    monsterInfo.pos = { x = _monsterInfo.objectPos.x, y = _monsterInfo.objectPos.y }
    monsterInfo.refreshTime = _monsterInfo.refreshTime
    monsterInfo.objectType = _monsterInfo.objectType
    -- 更新怪物记录
    monsters[_objectIndex] = monsterInfo

    -- 增加定时器
    local sMonster = CFG.s_Monster:Get( _monsterInfo.monsterId )
    local deleteTime = _monsterInfo.refreshTime + sMonster.showTime
    if monsterTimers[deleteTime] then
        monsterTimers[deleteTime].monsterIndexs[_objectIndex] = true
    else
        -- 定时器不存在
        monsterTimers[deleteTime] = {}
        monsterTimers[deleteTime].timerId = Timer.runAt( deleteTime, summonMonsterTimeOut, deleteTime )
        monsterTimers[deleteTime].monsterIndexs = {}
        monsterTimers[deleteTime].monsterIndexs[_objectIndex] = true
    end
end

---@see 删除被击杀召唤怪
function response.deleteSummonMonster( _objectIndex )
    local monsterInfo = monsters[_objectIndex]
    if monsterInfo then
        -- 删除怪物的定时器信息
        local sMonster = CFG.s_Monster:Get( monsterInfo.monsterId )
        local deleteTime = monsterInfo.refreshTime + sMonster.showTime
        if monsterTimers[deleteTime] then
            if monsterTimers[deleteTime].monsterIndexs and monsterTimers[deleteTime].monsterIndexs[_objectIndex] then
                monsterTimers[deleteTime].monsterIndexs[_objectIndex] = nil
            end

            if table.empty( monsterTimers[deleteTime].monsterIndexs ) then
                Timer.delete( monsterTimers[deleteTime].timerId )
                monsterTimers[deleteTime] = nil
            end
        end
    end

    -- 地图移除怪物信息
    MSM.MapObjectMgr[_objectIndex].req.summonMonsterLeave( monsterInfo and monsterInfo.objectId, _objectIndex, monsterInfo and monsterInfo.objectType )

    -- 删除怪物信息
    monsters[_objectIndex] = nil

    return monsterInfo
end

---@see 检查怪物是否超时
function accept.checkMonsterTimeOut( _monsterIndex )
    local monsterInfo = monsters[_monsterIndex]
    if monsterInfo then
        local sMonster = CFG.s_Monster:Get( monsterInfo.monsterId )
        if monsterInfo.refreshTime + sMonster.showTime <= os.time() then
            -- 移除地图怪物信息
            MSM.MapObjectMgr[_monsterIndex].req.monsterLeave( monsterInfo.objectId, _monsterIndex )

            monsters[_monsterIndex] = nil
        else
            -- 怪物恢复巡逻
            MSM.SceneMonsterMgr[_monsterIndex].req.updateMonsterStatus( _monsterIndex, Enum.ArmyStatus.ARMY_STANBY )
        end
    end
end