--[[
* @file : RuneMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon May 18 2020 09:19:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 符文刷新服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local RoleLogic = require "RoleLogic"
local ArmyLogic = require "ArmyLogic"

---@class defaultRuneAttrClass
local defaultRuneAttr = {
    pos                         =                   {},                         -- 坐标
    runeId                      =                   0,                          -- s_MapItemType表ID
    runeRefreshTime             =                   0,                          -- 符文刷新出来的时间s
    collectRids                 =                   {},                         -- 正在采集符文的部队
    holyLandId                  =                   0,                          -- 圣地ID
}

---@see 符文信息
---@type table<int, defaultRuneAttrClass>
local runes = {}

---@see 符文定时器
local runeTimers = {}

-- 符文超时
local function runeTimeOut( _objectIndex )
    local runeInfo = runes[_objectIndex]

    if runeInfo then
        -- 符文离开aoi
        MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.runeLeave( Enum.MapLevel.RESOURCE, _objectIndex, { x = -1, y = -1 } )
        -- 正在采集的角色取消采集
        local objectIndex
        for rid, armys in pairs( runeInfo.collectRids ) do
            for armyIndex, timerId in pairs( armys ) do
                Timer.delete( timerId )
                -- 更新部队采集符文时间
                objectIndex = MSM.RoleArmyMgr[rid].req.getRoleArmyIndex( rid, armyIndex )
                MSM.SceneArmyMgr[objectIndex].post.syncArmyCollectRuneTime( objectIndex, 0 )
            end
        end
    end

    runes[_objectIndex] = nil
    runeTimers[_objectIndex] = nil
end

---@see 添加符文
function accept.addRuneInfo( _runeId, _pos, _holyLandId, _objectIndex )
    local sMapItemType = CFG.s_MapItemType:Get( _runeId )
    if not sMapItemType or table.empty( sMapItemType ) then
        return
    end

    local nowTime = os.time()
    local pos = { x = _pos.x, y = _pos.y }

    -- 加入AOI
    local runeInfo = {
        runeId = _runeId,
        runeRefreshTime = nowTime,
        holyLandId = _holyLandId,
    }
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.runeEnter( Enum.MapLevel.RESOURCE, _objectIndex, pos, pos, runeInfo )

    -- 增加符文信息
    runes[_objectIndex] = {
        runeId = _runeId,
        runeRefreshTime = nowTime,
        pos = pos,
        collectRids = {},
    }

    local deleteTime = nowTime + sMapItemType.showTime
    -- 增加符文定时器
    runeTimers[_objectIndex] = Timer.runAt( deleteTime, runeTimeOut, _objectIndex )
end

---@see 角色符文采集结束
local function collectRuneFinish( _rid, _armyIndex, _runeIndex )
    local runeInfo = runes[_runeIndex]
    if runeInfo then
        -- 角色增加此符文信息
        local buffData = CFG.s_MapItemType:Get( runeInfo.runeId, "buffData" )
        for _, buffId in pairs( buffData or {} ) do
            RoleLogic:addCityBuff( _rid, buffId, true )
        end

        -- 发送角色采集完成通知
        RoleLogic:roleNotify( _rid, Enum.RoleNotifyType.RUNE_COLLECT_FINISH, { _armyIndex, runeInfo.runeId } )
        -- 移除角色采集信息
        if runeInfo.collectRids[_rid] and runeInfo.collectRids[_rid][_armyIndex] then
            runeInfo.collectRids[_rid][_armyIndex] = nil
        end

        local objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
        local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex, { Enum.Army.status, Enum.Army.targetArg } )
        local isArmyStation = ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.STATIONING )
        if isArmyStation then
            -- 原地驻扎
            ArmyLogic:updateArmyInfo( _rid, _armyIndex, { [Enum.Army.status] = Enum.ArmyStatus.STATIONING, [Enum.Army.targetArg] = { pos = armyInfo.targetArg.pos } } )
            -- 更新部队采集符文时间
            MSM.SceneArmyMgr[objectIndex].post.syncArmyCollectRuneTime( objectIndex, 0, Enum.ArmyStatus.STATIONING )
        else
            -- 部队回城
            local rolePos = RoleLogic:getRole( _rid, Enum.Role.pos )
            local targetObjectIndex = RoleLogic:getRoleCityIndex( _rid )
            -- 更新部队采集符文时间
            MSM.SceneArmyMgr[objectIndex].post.syncArmyCollectRuneTime( objectIndex, 0 )
            MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, targetObjectIndex, rolePos, Enum.ArmyStatus.RETREAT_MARCH )
        end

        -- 增加活动进度
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.COLLECTION_BUFF_COUNT, 1 )
    end
end

---@see 角色开始采集符文
function accept.roleStartCollectRune( _rid, _armyIndex, _runeIndex )
    local runeInfo = runes[_runeIndex]
    if runeInfo then
        local collectCircleTime = CFG.s_Config:Get( "collectCircleTime" )
        -- 添加角色采集信息
        if not runeInfo.collectRids[_rid] then
            runeInfo.collectRids[_rid] = {}
        end
        local nowTime = os.time()
        runeInfo.collectRids[_rid][_armyIndex] = Timer.runAt( nowTime + collectCircleTime, collectRuneFinish, _rid, _armyIndex, _runeIndex )
        -- 更新部队采集符文时间
        local armyStatus = ArmyLogic:getArmy( _rid, _armyIndex, Enum.Army.status )
        armyStatus = ArmyLogic:delArmyStatus( armyStatus, Enum.ArmyStatus.COLLECT_MARCH )
        armyStatus = ArmyLogic:addArmyStatus( armyStatus, Enum.ArmyStatus.COLLECTING_NO_DELETE )
        local objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
        MSM.SceneArmyMgr[objectIndex].post.syncArmyCollectRuneTime( objectIndex, nowTime, armyStatus )
        -- 更新部队状态为采集中
        ArmyLogic:updateArmyStatus( _rid, _armyIndex, armyStatus )
    end
end

---@see 取消角色符文采集
function accept.cancelCollectRune( _rid, _armyIndex, _runeIndex )
    local runeInfo = runes[_runeIndex]

    if runeInfo then
        local objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
        local armyStatus = ArmyLogic:getArmy( _rid, _armyIndex, Enum.Army.status )
        armyStatus = ArmyLogic:delArmyStatus( armyStatus, Enum.ArmyStatus.COLLECTING_NO_DELETE )
        ArmyLogic:updateArmyStatus( _rid, _armyIndex, armyStatus )
        -- 移除角色采集定时器
        if runeInfo.collectRids[_rid] and runeInfo.collectRids[_rid][_armyIndex] then
            -- 删除符文采集定时器
            Timer.delete( runeInfo.collectRids[_rid][_armyIndex] )
            -- 更新部队采集符文时间
            MSM.SceneArmyMgr[objectIndex].post.syncArmyCollectRuneTime( objectIndex, 0, armyStatus )

            runeInfo.collectRids[_rid][_armyIndex] = nil
            if table.empty( runeInfo.collectRids[_rid] ) then
                runeInfo.collectRids[_rid] = nil
            end
        else
            MSM.SceneArmyMgr[objectIndex].post.syncArmyCollectRuneTime( objectIndex, 0, armyStatus )
        end
    end
end

---@see 清空符文
function accept.cleanRunes()
    for objectIndex, runeInfo in pairs( runes or {} ) do
        if runeTimers[objectIndex] then
            Timer.delete( runeTimers[objectIndex] )
        end

        runeTimeOut( objectIndex )
    end
end