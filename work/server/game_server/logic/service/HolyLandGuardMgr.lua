--[[
* @file : HolyLandGuardMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Sun May 17 2020 15:12:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 圣地守护者刷新服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local Random = require "Random"
local ArmyLogic = require "ArmyLogic"

---@class defaultGuardAttrClass
local defaultGuardAttr = {
    pos                         =                   {},                         -- 坐标
    monsterId                   =                   0,                          -- s_Monster表ID
    refreshTime                 =                   0,                          -- 守护者刷新出来的时间
    holyLandId                  =                   0,                          -- 圣地关卡ID
}

---@type table<int, defaultGuardAttr>
local guards = {}

---@see 圣地对应的守护者
---@type table<int, table<int>>
local holyLandGuards = {}

---@see 守护者定时器
local guardTimers = {}

---@see 初始化服务瓦片信息
function response.InitHolyLandGuard( _holyLandId )
    -- 服务瓦片索引初始化
    if not holyLandGuards[_holyLandId] then
        holyLandGuards[_holyLandId] = {}
    end
end

---@see 守护者超时处理
local function monsterTimeOut( _deleteTime )
    if not guardTimers[_deleteTime] then return end

    -- 处理该定时器下的所有守护者信息
    local guard, guardStatus
    local guardObjectType = Enum.RoleType.GUARD_HOLY_LAND
    for monsterIndex in pairs( guardTimers[_deleteTime].monsterIndexs or {} ) do
        guard = guards[monsterIndex]
        if guard then
            -- 当前守护者没有被攻击，直接移除
            guardStatus = MSM.SceneMonsterMgr[monsterIndex].req.getMonsterStatus( monsterIndex )
            if not guardStatus or not ArmyLogic:checkArmyStatus( guardStatus, Enum.ArmyStatus.BATTLEING ) then
                -- 移除地图守护者信息
                MSM.AoiMgr[Enum.MapLevel.ARMY].req.guardHolyLandLeave( Enum.MapLevel.ARMY, monsterIndex, { x = -1, y = -1 }, guardObjectType )
                -- 移除圣地守护者信息
                if holyLandGuards[guard.holyLandId] and holyLandGuards[guard.holyLandId][monsterIndex] then
                    holyLandGuards[guard.holyLandId][monsterIndex] = nil
                end
                -- 移除怪物信息
                guards[monsterIndex] = nil
            end
        end
    end

    -- 移除怪物定时器信息
    guardTimers[_deleteTime] = nil
end

---@see 添加守护者
local function addGuardInfo( _monsterId, _refreshTime, _pos, _holyLandId )
    local pos = { x = _pos.x, y = _pos.y }
    -- 怪物信息进入aoi
    local sMonster = CFG.s_Monster:Get( _monsterId )
    local monsterIndex = MSM.MapObjectMgr[_monsterId].req.guardAddMap( _monsterId, pos, _refreshTime, _holyLandId )
    -- 更新怪物记录
    guards[monsterIndex] = {
        monsterId = _monsterId,
        pos = pos,
        refreshTime = _refreshTime,
        holyLandId = _holyLandId,
    }
    -- 更新瓦片怪物信息
    if not holyLandGuards[_holyLandId] then holyLandGuards[_holyLandId] = {} end
    holyLandGuards[_holyLandId][monsterIndex] = true
    -- 增加定时器
    local deleteTime = _refreshTime + sMonster.showTime
    if guardTimers[deleteTime] then
        guardTimers[deleteTime].monsterIndexs[monsterIndex] = true
    else
        guardTimers[deleteTime] = {}
        guardTimers[deleteTime].timerId = Timer.runAt( deleteTime, monsterTimeOut, deleteTime )
        guardTimers[deleteTime].monsterIndexs = {}
        guardTimers[deleteTime].monsterIndexs[monsterIndex] = true
    end

    return monsterIndex
end

---@see 刷新守护者
function accept.refreshHolyLandGuards( _isInit )
    local nowTime = os.time()
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    local sStrongHoldType = CFG.s_StrongHoldType:Get()
    local guardSize, sHoldType, sHoldData, needRefreshSize, allPos
    local guardGroupPoints = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.GUARD_GROUP_POINT ) or {}
    for holyLandId, guardIndexs in pairs( holyLandGuards ) do
        sHoldData = sStrongHoldData[holyLandId]
        sHoldType = sStrongHoldType[sHoldData.type]

        guardSize = table.size( guardIndexs )
        needRefreshSize = sHoldType.monsterNum - guardSize
        -- 需要刷新的守护者个数
        if needRefreshSize > 0 and guardGroupPoints[sHoldData.monsterPointGroup] then
            -- 随机坐标
            allPos = Random.GetIds( guardGroupPoints[sHoldData.monsterPointGroup], needRefreshSize )
            -- 添加守护者
            for _, pos in pairs( allPos ) do
                addGuardInfo( sHoldType.monsterType, nowTime, pos, holyLandId )
            end
        end
    end

    SM.MapObjectRefreshMgr.req.addFinishService( _isInit )
end

---@see 删除被击杀守护者
function accept.deleteGuard( _monsterIndex )
    local guardInfo = guards[_monsterIndex]
    if not guardInfo then
        return
    end
    -- 删除该守护者的定时器信息
    local sMonster = CFG.s_Monster:Get( guardInfo.monsterId )
    local deleteTime = guardInfo.refreshTime + sMonster.showTime
    if guardTimers[deleteTime] then
        if guardTimers[deleteTime].monsterIndexs and guardTimers[deleteTime].monsterIndexs[_monsterIndex] then
            guardTimers[deleteTime].monsterIndexs[_monsterIndex] = nil
        end

        if table.empty( guardTimers[deleteTime].monsterIndexs ) then
            Timer.delete( guardTimers[deleteTime].timerId )
            guardTimers[deleteTime] = nil
        end
    end

    -- 地图移除该守护者信息
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.guardHolyLandLeave( Enum.MapLevel.ARMY, _monsterIndex, { x = -1, y = -1 }, Enum.RoleType.GUARD_HOLY_LAND )

    -- 更新圣地守护者信息
    if holyLandGuards[guardInfo.holyLandId] and holyLandGuards[guardInfo.holyLandId][_monsterIndex] then
        holyLandGuards[guardInfo.holyLandId][_monsterIndex] = nil
    end

    -- 删除守护者信息
    guardInfo[_monsterIndex] = nil
end

---@see PMLogic添加守护者
function response.addGuard( _holyLandId, _pos, _monsterId )
    addGuardInfo( _monsterId, os.time(), _pos, _holyLandId )
end

---@see 检查守护者是否超时
function accept.checkMonsterTimeOut( _monsterIndex )
    local guardInfo = guards[_monsterIndex]
    if guardInfo then
        local sMonster = CFG.s_Monster:Get( guardInfo.monsterId )
        if guardInfo.refreshTime + sMonster.showTime <= os.time() then
            -- 移除地图怪物信息
            if holyLandGuards[guardInfo.holyLandId] then
                holyLandGuards[guardInfo.holyLandId][_monsterIndex] = nil
            end

            MSM.AoiMgr[Enum.MapLevel.ARMY].req.guardHolyLandLeave( Enum.MapLevel.ARMY, _monsterIndex, { x = -1, y = -1 }, Enum.RoleType.GUARD_HOLY_LAND )

            guards[_monsterIndex] = nil
        else
            -- 守护者恢复巡逻
            MSM.SceneMonsterMgr[_monsterIndex].req.updateMonsterStatus( _monsterIndex, Enum.ArmyStatus.ARMY_STANBY )
        end
    end
end