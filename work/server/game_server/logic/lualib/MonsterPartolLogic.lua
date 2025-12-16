--[[
 * @file : MonsterPartolLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-03-20 16:38:33
 * @Last Modified time: 2020-03-20 16:38:33
 * @department : Arabic Studio
 * @brief : 野蛮人巡逻逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local ArmyWalkLogic = require "ArmyWalkLogic"
local MonsterLogic = require "MonsterLogic"
local MapLogic = require "MapLogic"
local ArmyLogic = require "ArmyLogic"
local Random = require "Random"
local CommonCacle = require "CommonCacle"

local MonsterPartolLogic = {}

---@see 野蛮人巡逻处理
---@param _monsterInfos table<int, defaultMapMonsterInfoClass>
function MonsterPartolLogic:dispatchMonsterPartol( _monsterInfos )
    local path
    local now = os.time()
    for objectIndex, monsterInfo in pairs(_monsterInfos) do
        repeat
            -- 没到巡逻时间
            if monsterInfo.nextPartolTime > now then
                break
            end

            -- 没角色在关注
            if monsterInfo.roleWatchRef <= 0 then
                -- 重新随机下次巡逻时间
                local monsterId = monsterInfo.monsterId
                local cdMin = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCD") / 1000 )
                local cdMax = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCdMax") / 1000 )
                monsterInfo.nextPartolTime = os.time() + Random.Get(cdMin,cdMax)
                break
            end

            -- 是否在待机
            if not ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.ARMY_STANBY ) then
                break
            end

            -- 是否在战斗
            if ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.BATTLEING ) then
                break
            end

            -- 待机状态,开始巡逻
            local sMonsterInfo = CFG.s_Monster:Get( monsterInfo.monsterId, { "patrolRadius" } )
            if sMonsterInfo and sMonsterInfo.patrolRadius then
                -- 判断野蛮人是否在阻挡内
                if not MapLogic:checkPosIdle( monsterInfo.pos, 0, nil, nil, nil, true ) then
                    -- 怪物删除
                    local serviceIndex = MonsterLogic:getMonsterService( objectIndex )
                    MSM.MonsterMgr[serviceIndex].req.deleteMonster( objectIndex )
                    return
                end
                -- 计算野蛮人巡逻坐标
                path = ArmyWalkLogic:cacleMonsterPartolPos( monsterInfo.initPos, monsterInfo.pos, sMonsterInfo.patrolRadius, nil, true )
                if path and table.size(path) >= 2 then
                    -- 状态变为巡逻
                    monsterInfo.path = path
                    local movePath = table.copy( path, true )
                    monsterInfo.pos = movePath[1]
                    monsterInfo.next = movePath[2]
                    table.remove( movePath, 1 )
                    table.remove( movePath, 1 )
                    monsterInfo.movePath = movePath
                    -- 计算到达时间
                    local arrivalTime = ArmyLogic:cacleArrivalTime( path, monsterInfo.speed )
                    -- 计算移动角度
                    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( path, monsterInfo.speed )
                    monsterInfo.angle = math.floor( angle * 100 )
                    monsterInfo.moveSpeed = { x = speedx, y = speedy }
                    monsterInfo.arrivalTime = arrivalTime
                    monsterInfo.status = Enum.ArmyStatus.PATROL
                    -- 同步路径
                    MSM.SceneMonsterMgr[objectIndex].post.updateMonsterPath( objectIndex, path, arrivalTime, os.time(), nil, Enum.ArmyStatus.PATROL, true )
                else
                    -- 无路径,等待下次巡逻
                    local monsterId = monsterInfo.monsterId
                    local cdMin = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCD") / 1000 )
                    local cdMax = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCdMax") / 1000 )
                    monsterInfo.nextPartolTime = os.time() + Random.Get(cdMin,cdMax)
                end
            end
        until true
    end
end

---@see 野蛮人巡逻坐标更新
function MonsterPartolLogic:updateMonsterPartolPos( _monsterInfos, _monsterLastUpdatePos, _armyWalkToInfo )
    local isReach
    for objectIndex, monsterInfo in pairs(_monsterInfos) do
        if ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.PATROL ) then
            -- 模拟移动
            monsterInfo.pos, isReach = ArmyWalkLogic:cacleNowPos( monsterInfo.pos, monsterInfo.next, monsterInfo.moveSpeed, monsterInfo.arrivalTime )
            -- 坐标更新处理
            self:updateMonsterPosImpl( objectIndex, monsterInfo.pos, monsterInfo, _monsterLastUpdatePos, _armyWalkToInfo )
            if isReach then
                if table.empty(monsterInfo.movePath) then -- 全部行走完毕
                    self:monsterPartolOver( objectIndex, monsterInfo )
                else
                    -- 还有下一个目标点
                    monsterInfo.next = table.remove(monsterInfo.movePath, 1)
                    -- 重新计算角度和速度
                    monsterInfo.angle, monsterInfo.moveSpeed.x, monsterInfo.moveSpeed.y = ArmyWalkLogic:cacleSpeed( { monsterInfo.pos, monsterInfo.next }, monsterInfo.speed )
                end
            end
        end
    end
end

---@see 野蛮人巡逻结束
---@param _monsterInfo defaultMapMonsterInfoClass
function MonsterPartolLogic:monsterPartolOver( _objectIndex, _monsterInfo )
    if _monsterInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND then
        -- 更新圣地守护者坐标
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.guardHolyLandUpdate( Enum.MapLevel.ARMY, _objectIndex, _monsterInfo.pos, _monsterInfo.pos )
    elseif _monsterInfo.objectType == Enum.RoleType.MONSTER then
        -- 更新怪物坐标
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.monsterUpdate( Enum.MapLevel.ARMY, _objectIndex, _monsterInfo.pos, _monsterInfo.pos )
    elseif _monsterInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or _monsterInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 更新召唤怪物坐标
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.summonMonsterUpdate( Enum.MapLevel.ARMY, _objectIndex, _monsterInfo.pos, _monsterInfo.pos, _monsterInfo.objectType )
    end
    -- 下次巡逻时间
    local monsterId = _monsterInfo.monsterId
    local cdMin = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCD") / 1000 )
    local cdMax = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCdMax") / 1000 )
    _monsterInfo.nextPartolTime = os.time() + Random.Get(cdMin,cdMax)
    -- 状态变为待机
    _monsterInfo.status = Enum.ArmyStatus.ARMY_STANBY
    -- 通过AOI通知
    local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
    sceneObject.post.syncObjectInfo( _objectIndex, { status = Enum.ArmyStatus.ARMY_STANBY } )
end

---@see 野蛮人坐标更新处理
function MonsterPartolLogic:updateMonsterPosImpl( _objectIndex, _pos, _monsterInfo, _monsterLastUpdatePos, _armyWalkToInfo )
    -- 如果处于战斗,更新坐标
    if ArmyLogic:checkArmyStatus( _monsterInfo.status, Enum.ArmyStatus.BATTLEING ) then
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
        if battleIndex then
            -- 通知对象更新坐标
            local BattleCreate = require "BattleCreate"
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            Common.rpcMultiSend( battleNode, "BattleLoop", "updateObjectPos", battleIndex, _objectIndex, _pos )
        end
    end

    local now = os.time()
    -- 每秒更新一次路径(跟随)
    if not _monsterLastUpdatePos[_objectIndex] or ( now - _monsterLastUpdatePos[_objectIndex] >= 1 ) then
        -- 如果有部队向怪物行军,更新路径
        if _armyWalkToInfo[_objectIndex] then
            for armyObjectIndex in pairs(_armyWalkToInfo[_objectIndex]) do
                local armyInfo = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyInfo( armyObjectIndex )
                if armyInfo then
                    if armyInfo.targetObjectIndex == _objectIndex then
                        -- 修正坐标
                        local fPos = armyInfo.pos
                        local fixPos = MSM.MapMarchMgr[armyObjectIndex].req.fixObjectPosWithMillisecond( armyObjectIndex, true )
                        if fixPos then
                            fPos = fixPos
                        end
                        local path = { fPos, _pos }
                        -- 修正坐标
                        local armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                        local monsterRadius = CFG.s_Monster:Get( _monsterInfo.monsterId, "radius" ) * Enum.MapPosMultiple
                        path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.MONSTER, path, armyRadius, monsterRadius )
                        -- 更新部队路径
                        MSM.MapMarchMgr[armyObjectIndex].post.updateArmyMovePath( armyObjectIndex, _objectIndex, path )
                    end
                else
                    -- 部队不存在了
                    _armyWalkToInfo[_objectIndex][armyObjectIndex] = nil
                    if table.empty(_armyWalkToInfo[_objectIndex]) then
                        _armyWalkToInfo[_objectIndex] = nil
                    end
                end
            end
        end
        _monsterLastUpdatePos[_objectIndex] = now
    end
end

return MonsterPartolLogic