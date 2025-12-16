--[[
* @file : ArmyTrainLogic.lua
* @type : lualib
* @author : chenlei
* @created : Thu Dec 26 2019 10:14:35 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 部队训练逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local LogLogic = require "LogLogic"

local ArmyTrainLogic = {}

---@see 根据士兵id获取士兵类型和等级
function ArmyTrainLogic:getTypeLevelById( _soldierId )
    local level = _soldierId % 100
    local type = math.tointeger( ( _soldierId - level ) / 100 // 1 )

    return type, level
end

---@see 判断某种兵种能训练的最大等级
function ArmyTrainLogic:getArmyMaxLv( _rid, _type )
    local maxLv = 0
    for i=1,5 do
        if RoleLogic:unlockArmy( _rid, _type, i ) and i > maxLv then
            maxLv = i
        end
    end
    return maxLv
end

---@see 返回某种兵的属性
function ArmyTrainLogic:getSoldiersAttr( _rid, _type, _level )
    local config = self:getArmsConfig( _rid, _type, _level )
    -- 影响的属性后续补充
    local attack = config.attack
    local defense = config.defense
    local hpMax = config.hpMax
    local speed = config.speed
    local capactiy = config.capactiy
    return { attack = attack, defense = defense, hpMax = hpMax, speed = speed, capactiy = capactiy }
end

---@see 增加士兵
function ArmyTrainLogic:addSoldiers( _rid, _type, _level, _addNum, _eventType, _eventType2, _noAddLog, _noSync )
   return MSM.RoleOperatingMgr[_rid].req.addSoldiers( _rid, _type, _level, _addNum, _eventType, _eventType2, _noAddLog, _noSync )
end

---@see 判断当前文明兵种类型兵种等级取对应配置
function ArmyTrainLogic:getArmsConfig( _rid, _type, _level, _sArms, _country )
    local country = _country or RoleLogic:getRole( _rid, Enum.Role.country )
    local sArms = _sArms or CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ARMY )
    if not sArms or not sArms[country] or not sArms[country][_type] then return nil end
    return sArms[country][_type][_level]
end

---@see 兵种训练晋升
function ArmyTrainLogic:trainArmy( _rid, _type, _level, _trainNum, _isUpdate, _buildingIndex, _guide )
    local config
    if _isUpdate == Enum.ArmyUpdate.YES then
        config = ArmyTrainLogic:getArmsConfig( _rid, _type, self:getArmyMaxLv( _rid, _type ) )
    else
        config = ArmyTrainLogic:getArmsConfig( _rid, _type, _level )
    end
    local totalFood
    local totalWood
    local totalStone
    local totalGlod
    if config.needFood then
        totalFood = config.needFood * _trainNum
    end
    if config.needWood then
        totalWood = config.needWood * _trainNum
    end
    if config.needStone then
        totalStone = config.needStone * _trainNum
    end
    if config.needGlod then
        totalGlod = config.needGlod * _trainNum
    end
    --添加定时器信息
    local roleInfo = RoleLogic:getRole(_rid, { Enum.Role.armyQueue, Enum.Role.trainSpeedMulti,
                                Enum.Role.itemAddTroopsCapacity, Enum.Role.itemAddTroopsCapacityCount } )
    local armyQueue = roleInfo.armyQueue
    local trainSpeedMulti =  roleInfo.trainSpeedMulti or 0
    local finishTime = math.tointeger(config.endTime * ( 1- trainSpeedMulti/1000 ) * _trainNum // 1)
    local logType = Enum.LogType.TRAIN_SOLDIER_COST_DENAR
    if _isUpdate == Enum.ArmyUpdate.YES then
        logType = Enum.LogType.UPGRADE_SOLDIER_COST_DENAR
        config = ArmyTrainLogic:getArmsConfig( _rid, _type, _level )
        if config.needFood then
            totalFood = totalFood - config.needFood * _trainNum
        end
        if config.needWood then
            totalWood = totalWood - config.needWood * _trainNum
        end
        if config.needStone then
            totalStone = totalStone - config.needStone * _trainNum
        end
        if config.needGlod then
            totalGlod = totalGlod - config.needGlod * _trainNum
        end
        finishTime = finishTime - math.tointeger(config.endTime * ( 1- trainSpeedMulti/1000 ) * _trainNum // 1)
    end
    -- 扣除相应资源
    if totalFood and totalFood > 0 then
        RoleLogic:addFood( _rid, -totalFood, nil, logType )
    end
    if totalWood and totalWood > 0 then
        RoleLogic:addWood( _rid, -totalWood, nil, logType )
    end
    if totalStone and totalStone > 0 then
        RoleLogic:addStone( _rid, -totalStone, nil, logType )
    end
    if totalGlod and totalGlod > 0 then
        RoleLogic:addGold( _rid, -totalGlod, nil, logType )
    end
    -- 如果是晋升扣除对应士兵
    if _isUpdate == Enum.ArmyUpdate.YES then
        self:addSoldiers( _rid, _type, _level, -_trainNum, nil, nil, true )
    end
    if _guide then
        finishTime = CFG.s_Config:Get("trainingFirstTime")
    end

    -- 扣除预备部队次数
    if roleInfo.itemAddTroopsCapacityCount > 0 then
        local roleChangeInfo = {}
        roleChangeInfo.itemAddTroopsCapacityCount = roleInfo.itemAddTroopsCapacityCount - 1
        if roleChangeInfo.itemAddTroopsCapacityCount == 0 then
            roleChangeInfo.itemAddTroopsCapacity = 0
        end
        RoleLogic:setRole( _rid, roleChangeInfo )
        RoleSync:syncSelf( _rid, roleChangeInfo, true, true )
    end

    if not armyQueue[_type] then
        armyQueue[_type] = {
            queueIndex = _type
        }
    end

    armyQueue[_type].finishTime = os.time() + finishTime
    armyQueue[_type].firstFinishTime = armyQueue[_type].finishTime
    armyQueue[_type].armyType = _type
    armyQueue[_type].armyNum = _trainNum
    armyQueue[_type].newArmyLevel = _level
    if _isUpdate == Enum.ArmyUpdate.YES then
        local level = self:getArmyMaxLv( _rid, _type )
        armyQueue[_type].newArmyLevel = level
        armyQueue[_type].oldArmyLevel = _level
    end
    armyQueue[_type].beginTime = os.time()
    armyQueue[_type].buildingIndex = _buildingIndex
    armyQueue[_type].timerId = MSM.RoleTimer[_rid].req.addTrainTimer( _rid, armyQueue[_type].finishTime, _type, armyQueue[_type].queueIndex )
    RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
    RoleSync:syncSelf( _rid, { [Enum.Role.armyQueue] = { [armyQueue[_type].queueIndex] = armyQueue[_type] } }, true, true )

    -- 增加士兵训练累计个数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.SOLDIER_TRAIN, _type, _trainNum )

    return { }
end

---@see 训练士兵回调
function ArmyTrainLogic:trainArmyCallBack( _rid, _type, _queueIndex )
    local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue )
    if armyQueue[_queueIndex].armyType == _type then
        armyQueue[_queueIndex].timerId = 0
    end

    RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )

    -- 增加推送
    local config = self:getArmsConfig( _rid, _type, armyQueue[_queueIndex].newArmyLevel )
    if config then
        SM.PushMgr.post.sendPush( { pushRid = _rid, pushType = Enum.PushType.TARIN, args = { arg1 = config.ID } })
    end

    return { result = true }
end

---@see 领取士兵
function ArmyTrainLogic:awardArmy( _rid, _type )
    local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue )
    local queue = armyQueue[_type]
    local soldiers = {}
    local config
    if queue.armyNum > 0 then
        local logType = Enum.LogType.TRAIN_ARMY
        if queue.oldArmyLevel and queue.oldArmyLevel > 0 then
            logType = Enum.LogType.ARMY_LEVEL_UP_ADD
        end
        -- 增加士兵
        self:addSoldiers( _rid, queue.armyType, queue.newArmyLevel, queue.armyNum, logType )

        config = self:getArmsConfig( _rid, queue.armyType, queue.newArmyLevel )
        RoleLogic:reduceTime( _rid, config.mysteryStoreCD * queue.armyNum )
        local oldArmyLevel = queue.oldArmyLevel
        local oldArmyNum = queue.armyNum
        local oldPower = 0
        local oldActionType
        if queue.oldArmyLevel and queue.oldArmyLevel > 0 then
            config = self:getArmsConfig( _rid, _type, queue.oldArmyLevel )
            oldPower = config.militaryCapability * queue.armyNum
            if queue.oldArmyLevel == 1 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL1_COUNT
            elseif queue.oldArmyLevel == 2 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL2_COUNT
            elseif queue.oldArmyLevel == 3 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL3_COUNT
            elseif queue.oldArmyLevel == 4 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL4_COUNT
            elseif queue.oldArmyLevel == 5 then
                oldActionType = Enum.ActivityActionType.TRAIN_LEVEL5_COUNT
            end
        end
        config = self:getArmsConfig( _rid, _type, queue.newArmyLevel )
        local changePower = config.militaryCapability * queue.armyNum - oldPower
        local id = queue.armyType*100 + queue.newArmyLevel
        soldiers = {}
        soldiers[id]= { id = id, type = queue.armyType, level =  queue.newArmyLevel, num = queue.armyNum }

        -- 增加士兵招募累计个数
        local TaskLogic = require "TaskLogic"
        TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.SOLDIER_SUMMON, queue.armyType, queue.armyNum )
        -- 更新每日任务进度
        TaskLogic:updateTaskSchedule( _rid, { [Enum.TaskType.SOLDIER_SUMMON] = { arg = queue.armyType, addNum = queue.armyNum } } )
        -- 计算角色最高战力
        RoleLogic:cacleSyncHistoryPower( _rid )
        -- 设置活动进度
        self:setActivitySchedule( _rid, queue.armyType, queue.newArmyLevel, queue.armyNum, oldActionType )
        if changePower > 0 then
            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.ARMY_POWER_UP, changePower )
        end
        queue.finishTime = -1
        queue.beginTime = 0
        RoleSync:syncSelf( _rid, { [Enum.Role.armyQueue] = { [queue.queueIndex] = queue } }, true, true )
        queue.armyType = 0
        queue.armyNum = 0
        queue.newArmyLevel = 0
        queue.oldArmyLevel = 0
        queue.buildingIndex = 0
        queue.firstFinishTime = -1
        RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
        if oldArmyLevel and oldArmyLevel > 0 then
            local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.soldiers, Enum.Role.iggid } )
            local newSoldiers = roleInfo.soldiers
            config = self:getArmsConfig( _rid, _type, oldArmyLevel )
            id = config.ID
            local soldiersNum = 0
            if newSoldiers[id] then
                soldiersNum = newSoldiers[id].num
            end
            LogLogic:armsChange( {
                logType = Enum.LogType.ARMY_LEVEL_UP_REDUCE,
                armsID = id,
                changeNum = oldArmyNum,
                oldNum = soldiersNum + oldArmyNum,
                newNum = soldiersNum,
                rid = _rid,
                iggid = roleInfo.iggid
            } )
        end
    end
    return { soldiers = soldiers }
end

---@see 训练设置活动进度
function ArmyTrainLogic:setActivitySchedule( _rid, _type, _level, _num, _oldActionType )
    if _level == 1 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL1_COUNT, _num, nil, nil, nil, _oldActionType )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_ALL, _num )
    elseif _level == 2 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL2_COUNT, _num, nil, nil, nil, _oldActionType )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_ALL, _num )
    elseif _level == 3 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL3_COUNT, _num, nil, nil, nil, _oldActionType )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_ALL, _num )
    elseif _level == 4 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL4_COUNT, _num, nil, nil, nil, _oldActionType )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_ALL, _num )
    elseif _level == 5 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL5_COUNT, _num, nil, nil, nil, _oldActionType )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_ALL, _num )
    end

    if _type == Enum.ArmyType.INFANTRY then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_INFANTRY, _num )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_INFANTRY, _num, _level )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_ALL, _num, _level )
    elseif _type == Enum.ArmyType.CAVALRY then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_CAVALRY, _num )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_CAVALRY, _num, _level )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_ALL, _num, _level )
    elseif _type == Enum.ArmyType.ARCHER then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_ARCHER, _num )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_ARCHER, _num, _level )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_ALL, _num, _level )
    elseif _type == Enum.ArmyType.SIEGE_UNIT then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_SIEGE_UNIT, _num )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_SIEGE_UNIT, _num, _level )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TRAIN_LEVEL_ALL, _num, _level )
    end
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TARIN_ACTION, 1 )
end


---@see 解散士兵
function ArmyTrainLogic:disbandArmy( _rid, _type, _level, _num )
    self:addSoldiers( _rid, _type, _level, -_num, Enum.LogType.ARMY_REDUCE )
    -- 计算角色最高战力
    RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, nil, true )
end

---@see 检测训练队列状态
function ArmyTrainLogic:checkArmyQueue( _rid )
    local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue ) or {}
    for _, queue in pairs(armyQueue) do
        if queue.timerId and queue.finishTime and queue.timerId > 0 and queue.finishTime > 0 and queue.finishTime < os.time() then
            self:trainArmyCallBack( _rid, queue.armyType, queue.queueIndex )
        elseif queue.timerId and queue.timerId > 0 and not MSM.RoleTimer[_rid].req.checkTrainTimer( _rid, queue.timerId ) then
            armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue ) or {}
            armyQueue[queue.queueIndex].timerId = MSM.RoleTimer[_rid].req.addTrainTimer( _rid, queue.finishTime, queue.armyType, queue.queueIndex )
            RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
        end
    end
end

---@see 训练加速
function ArmyTrainLogic:speedUp( _rid, _queueIndex, _sec )
    local armyQueue = RoleLogic:getRole( _rid, Enum.Role.armyQueue ) or {}
    armyQueue[_queueIndex].finishTime = armyQueue[_queueIndex].finishTime - _sec
    MSM.RoleTimer[_rid].req.deleteTrainTimer( _rid, armyQueue[_queueIndex].timerId)
    local finishTime = 0
    if armyQueue[_queueIndex].finishTime <= os.time() then
        armyQueue[_queueIndex].timerId = 0
        -- 增加推送
        local config = self:getArmsConfig( _rid, armyQueue[_queueIndex].armyType, armyQueue[_queueIndex].newArmyLevel )
        SM.PushMgr.post.sendPush( { pushRid = _rid, pushType = Enum.PushType.TARIN, args = { arg1 = config.ID } })
    else
        armyQueue[_queueIndex].timerId = MSM.RoleTimer[_rid].req.addTrainTimer( _rid, armyQueue[_queueIndex].finishTime, armyQueue[_queueIndex].armyType, _queueIndex )
        finishTime = armyQueue[_queueIndex].finishTime
    end
    RoleLogic:setRole( _rid, { [Enum.Role.armyQueue] = armyQueue } )
    RoleSync:syncSelf( _rid, { [Enum.Role.armyQueue] = { [_queueIndex] = armyQueue[_queueIndex] } }, true, true )
    -- 设置活动进度
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USE_SPEED_MIN, _sec/60 )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USE_SPEED_MIN_IN_TARIN, _sec/60 )
    return finishTime
end

---@see 创角给予玩家士兵
function ArmyTrainLogic:createRoleGiveSoldiers( _rid )
    local initialArmsType = CFG.s_Config:Get("initialArmsType")
    local initialArmsNum = CFG.s_Config:Get("initialArmsNum")

    local nTypeLen = table.size(initialArmsType)
    local nNumLen = table.size(initialArmsNum)
    local nLen = nTypeLen
    if (nTypeLen ~= nNumLen) then
        LOG_ERROR("nTypeLen ~= nNumLen")
        if nNumLen < nTypeLen then
            nLen = nNumLen
        end
    end

    for i=1, nLen do
        local sArms = CFG.s_Arms:Get(initialArmsType[i])
        self:addSoldiers( _rid, sArms.armsType, sArms.armsLv, initialArmsNum[i], nil, nil, true, true )
    end
end

return ArmyTrainLogic

