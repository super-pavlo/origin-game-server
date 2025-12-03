--[[
* @file : HospitalLogic.lua
* @type : lualib
* @author : chenlei
* @created : Tue Jan 07 2020 09:49:40 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 医院相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local ArmyTrainLogic = require "ArmyTrainLogic"
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local SoldierLogic = require "SoldierLogic"
local HospitalLogic = {}

---@see 伤兵治疗
function HospitalLogic:treatment( _rid, _soldiers )
    -- 扣除对应资源
    local costFood = 0
    local costWood = 0
    local costStone = 0
    local costGold = 0
    local needTime = 0
    -- local time1 = 0
    -- local time2 = 0
    -- local time3 = 0
    -- local time4 = 0
    -- local time5 = 0
    -- local num1 = 0
    -- local num2 = 0
    -- local num3 = 0
    -- local num4 = 0
    -- local num5 = 0
    for _, v in pairs(_soldiers) do
        local config = CFG.s_Arms:Get(v.id)
        if config.woundedFood then
            costFood = costFood + config.woundedFood * v.num
        end
        if config.woundedWood then
            costWood = costWood + config.woundedWood * v.num
        end
        if config.woundedStone then
            costStone = costStone + config.woundedStone * v.num
        end
        if config.woundedGlod then
            costGold = costGold + config.woundedGlod * v.num
        end
        needTime = needTime + config.woundedTime * v.num
        -- if v.level == 1 then
        --     time1 = time1 + config.woundedTime * v.num
        --     num1 = num1 + v.num
        -- elseif v.level == 2 then
        --     time2 = time2 + config.woundedTime * v.num
        --     num2 = num2 + v.num
        -- elseif v.level == 3 then
        --     time3 = time3 + config.woundedTime * v.num
        --     num3 = num3 + v.num
        -- elseif v.level == 4 then
        --     time4 = time4 + config.woundedTime * v.num
        --     num4 = num4 + v.num
        -- elseif v.level == 5 then
        --     time5 = time5 + config.woundedTime * v.num
        --     num5 = num5 + v.num
        -- end
    end
    local minTime = CFG.s_Config:Get("cureMinTime") or 3
    -- if num1 > 0 then
    --     time1 = minTime
    -- end
    -- if num2 > 0 and time2 < minTime then
    --     time2 = minTime
    -- end
    -- if num3 > 0 and time3 < minTime then
    --     time3 = minTime
    -- end
    -- if num4 > 0 and time4 < minTime then
    --     time4 = minTime
    -- end
    -- if num5 > 0 and time5 < minTime then
    --     time5 = minTime
    -- end
    -- needTime = time1 + time2 + time3 + time4 + time5
    if costFood > 0 then
        RoleLogic:addFood( _rid, -costFood, nil, Enum.LogType.HEAL_SOLDIER_COST_DENAR )
    end
    if costWood > 0 then
        RoleLogic:addWood( _rid, -costWood, nil, Enum.LogType.HEAL_SOLDIER_COST_DENAR )
    end
    if costStone > 0 then
        RoleLogic:addStone( _rid, -costStone, nil, Enum.LogType.HEAL_SOLDIER_COST_DENAR )
    end
    if costGold > 0 then
        RoleLogic:addGold( _rid, -costGold, nil, Enum.LogType.HEAL_SOLDIER_COST_DENAR )
    end
    local treatmentQueue = RoleLogic:getRole( _rid, Enum.Role.treatmentQueue ) or {}
    local healSpeedMulti = RoleLogic:getRole( _rid, "healSpeedMulti" ) or 0
    local totalTime =  math.tointeger( (needTime/(1 + healSpeedMulti/1000)//1) )
    if totalTime < minTime then
        totalTime = minTime
    end
    local finishTime = os.time() + totalTime
    treatmentQueue.finishTime = finishTime
    treatmentQueue.treatmentSoldiers = _soldiers
    treatmentQueue.beginTime = os.time()
    treatmentQueue.queueIndex = 1
    treatmentQueue.firstFinishTime = finishTime
    treatmentQueue.timerId = MSM.RoleTimer[_rid].req.addTreatmentTimer( _rid, treatmentQueue.finishTime )
    treatmentQueue.healSpeedMulti = healSpeedMulti
    RoleLogic:setRole( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue } )
    RoleSync:syncSelf( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue }, true, true )
    return { soldiers = {} }
end

---@see 治疗士兵回调
function HospitalLogic:treatmentCallBack( _rid, _isLogin )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.treatmentQueue, Enum.Role.guildId } ) or {}
    local treatmentQueue = roleInfo.treatmentQueue or {}
    local requestHelpIndex = treatmentQueue.requestHelpIndex
    treatmentQueue.timerId = -1
    treatmentQueue.requestGuildHelp = nil
    treatmentQueue.requestHelpIndex = nil
    RoleLogic:setRole( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue }, true )
    end
    -- 非联盟帮助减速完成
    if roleInfo.guildId and roleInfo.guildId > 0 and requestHelpIndex then
        MSM.GuildMgr[roleInfo.guildId].post.roleQueueFinishCallBack( roleInfo.guildId, requestHelpIndex, _isLogin )
    end
    -- 删除治疗定时器
    MSM.RoleTimer[_rid].req.deleteTreatmentTimer( _rid )
end

---@see 领取治疗士兵
function HospitalLogic:awardTreatment( _rid )
    local TaskLogic = require "TaskLogic"
    local treatmentQueue = RoleLogic:getRole( _rid, Enum.Role.treatmentQueue ) or {}
    local synSoldiers = table.copy(treatmentQueue.treatmentSoldiers, true)
    local treatmentSum
    local taskType = Enum.TaskType.HEAL_SOLDIER
    local taskArgDefault = Enum.TaskArgDefault
    local addSoldierInfo

    treatmentSum, addSoldierInfo = SoldierLogic:subSeriousInLock( _rid, treatmentQueue.treatmentSoldiers )

    treatmentQueue.finishTime = -1
    treatmentQueue.firstFinishTime = -1
    treatmentQueue.beginTime = -1
    treatmentQueue.timerId = -1
    treatmentQueue.healSpeedMulti = 0
    local taskStatisticsSum = TaskLogic:addTaskStatisticsSum( _rid, taskType, taskArgDefault, treatmentSum, true ) or 0
    RoleSync:syncSelf( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue, [Enum.Role.taskStatisticsSum] = { [taskType] = taskStatisticsSum[taskType] } }, true, true )
    treatmentQueue.treatmentSoldiers = {}
    RoleLogic:setRole( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue } )

    -- 增加士兵
    SoldierLogic:addSoldier( _rid, addSoldierInfo, true )

    -- 更新每日任务进度
    TaskLogic:updateTaskSchedule( _rid, { [taskType] = { arg = 0, addNum = treatmentSum } } )

    -- 计算角色最高战力
    RoleLogic:cacleSyncHistoryPower( _rid, nil, nil, true, nil, nil, true )

    -- 更新活动
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TREATMENT_NUM, treatmentSum )

    -- 治疗士兵完成处理
    local ArmyLogic = require "ArmyLogic"
    ArmyLogic:addSoldierCallback( _rid, synSoldiers )

    return { soldiers = synSoldiers }
end

---@see 重伤加入医院
function HospitalLogic:addToHospital( _rid, _soldiers, _notUpdateSoldier )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.hospitalSpaceMulti, Enum.Role.seriousInjured, Enum.Role.country } )

    local BuildingLogic = require "BuildingLogic"
    local hospitals = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.HOSPITAL )
    local maxNum = 0
    local hospitalSpaceMulti = roleInfo.hospitalSpaceMulti or 0
    for _, hospital in pairs(hospitals) do
        maxNum = maxNum + CFG.s_BuildingHospital:Get(hospital.level, "armyCnt")
    end
    maxNum = maxNum * ( 1 + hospitalSpaceMulti / 1000) // 1

    local seriousInjured = roleInfo.seriousInjured
    local seriousInjuredNum = 0
    local copy = table.copy(_soldiers, true)
    local soldiersList = {}

    for _, info in pairs(seriousInjured) do
        seriousInjuredNum = seriousInjuredNum + info.num
    end
    -- 判断之前医院重伤容量
    local beforeSeriousRate = seriousInjuredNum / maxNum * 100 // 1

    for _, info in pairs(_soldiers) do
        seriousInjuredNum = seriousInjuredNum + info.num
    end
    -- 判断本次医院重伤容量
    local newSeriousRate = seriousInjuredNum / maxNum * 100 // 1

    local cureTriggerProportion = CFG.s_Config:Get("cureTriggerProportion")
    local seriousMailList = {}
    for _, rate in pairs(cureTriggerProportion) do
        if beforeSeriousRate < rate and newSeriousRate >= rate then
            table.insert(seriousMailList, rate)
        end
    end

    local config
    local id
    local armyType = { Enum.ArmyType.INFANTRY, Enum.ArmyType.CAVALRY, Enum.ArmyType.ARCHER, Enum.ArmyType.SIEGE_UNIT }
    if seriousInjuredNum > maxNum then
        -- 死亡的士兵总数
        local deadNum = seriousInjuredNum - maxNum
        -- 低级兵优先死亡
        for i=1,5 do
            local levelNum = 0
            for _, type in pairs(armyType) do
                config = ArmyTrainLogic:getArmsConfig( _rid, type, i, nil, roleInfo.country )
                id = config.ID
                if _soldiers[id] then
                    levelNum = levelNum + _soldiers[id].num
                end
            end
            if levelNum < deadNum and deadNum > 0 then
                deadNum = deadNum - levelNum
                for _, type in pairs(armyType) do
                    config = ArmyTrainLogic:getArmsConfig( _rid, type, i, nil, roleInfo.country )
                    id = config.ID
                    if _soldiers[id] then
                        _soldiers[id] = nil
                    end
                end
            elseif levelNum >= deadNum and deadNum > 0 then
                -- 计算对应比例
                local soldierDead = {}
                local rate = deadNum/levelNum
                local reduceNum = 0
                for _, type in pairs(armyType) do
                    config = ArmyTrainLogic:getArmsConfig( _rid, type, i, nil, roleInfo.country )
                    id = config.ID
                    if _soldiers[id] then
                        local num =  _soldiers[id].num * rate // 1
                        _soldiers[id].num = _soldiers[id].num - num
                        reduceNum = reduceNum + num
                        soldierDead[type] = num
                    end
                end
                while reduceNum < deadNum do
                    if table.size(soldierDead) <= 0 then
                        break
                    end
                    local minType = 0
                    local minNum = 0
                    for key, value in pairs(soldierDead) do
                        if minNum == 0 or value < minNum then
                            minNum = value
                            minType = key
                        end
                    end
                    soldierDead[minType] = nil
                    local num = deadNum - reduceNum
                    config = ArmyTrainLogic:getArmsConfig( _rid, minType, i, nil, roleInfo.country )
                    LOG_INFO("addToHospital rid(%d) type(%d) i (%d)", _rid, minType, i )
                    id = config.ID
                    if _soldiers[id].num > num then
                        _soldiers[id].num = _soldiers[id].num - num
                        reduceNum = reduceNum + num
                    else
                        reduceNum = reduceNum + _soldiers[id].num
                        _soldiers[id].num = 0
                    end
                end
                deadNum = 0
            end
        end
    end
    -- 更新伤兵数量
    SoldierLogic:addSeriousInLock( _rid, _soldiers )

    for _, soldierInfo in pairs( _soldiers ) do
        if copy[soldierInfo.id] then
            copy[soldierInfo.id].num = copy[soldierInfo.id].num - soldierInfo.num
        end
    end

    local cureFullMailID = CFG.s_Config:Get("cureFullMailID")
    for _, rate in pairs(seriousMailList) do
        MSM.EmailMgr[_rid].post.sendEmail( _rid, cureFullMailID, { emailContents = { rate }, subTitleContents = { rate } } )
    end

    soldiersList.seriousInjured = _soldiers
    soldiersList.dead = copy

    return soldiersList
end

---@see 检测治疗队列状态
function HospitalLogic:checkTreatmentQueue( _rid )
    local treatmentQueue = RoleLogic:getRole( _rid, Enum.Role.treatmentQueue ) or {}
    if treatmentQueue.timerId and treatmentQueue.finishTime and treatmentQueue.timerId > 0 and treatmentQueue.finishTime > 0 and treatmentQueue.finishTime < os.time() then
        self:treatmentCallBack( _rid, true )
    elseif treatmentQueue.timerId and treatmentQueue.timerId > 0 and not MSM.RoleTimer[_rid].req.checkTreatmentTimer( _rid ) then
        treatmentQueue.timerId = MSM.RoleTimer[_rid].req.addTreatmentTimer( _rid, treatmentQueue.finishTime )
        RoleLogic:setRole( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue } )
    end
end

---@see 伤兵治疗加速
function HospitalLogic:speedUp( _rid, _sec, _isGuildHelp )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.treatmentQueue, Enum.Role.guildId } ) or {}
    local treatmentQueue = roleInfo.treatmentQueue or {}
    treatmentQueue.finishTime = treatmentQueue.finishTime - _sec
    MSM.RoleTimer[_rid].req.deleteTreatmentTimer( _rid )
    local finishTime = 0
    local requestHelpIndex
    if treatmentQueue.finishTime > os.time() then
        treatmentQueue.timerId = MSM.RoleTimer[_rid].req.addTreatmentTimer( _rid, treatmentQueue.finishTime )
        finishTime = treatmentQueue.finishTime
    else
        requestHelpIndex = treatmentQueue.requestHelpIndex
        treatmentQueue.requestGuildHelp = nil
        treatmentQueue.requestHelpIndex = nil
    end
    RoleLogic:setRole( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue } )
    RoleSync:syncSelf( _rid, { [Enum.Role.treatmentQueue] = treatmentQueue }, true )

    -- 非联盟帮助减速完成
    if roleInfo.guildId and roleInfo.guildId > 0 and not _isGuildHelp and requestHelpIndex then
        MSM.GuildMgr[roleInfo.guildId].post.roleQueueFinishCallBack( roleInfo.guildId, requestHelpIndex )
    end
    if not _isGuildHelp then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USE_SPEED_MIN, _sec/60 )
    end
    return finishTime
end

return HospitalLogic