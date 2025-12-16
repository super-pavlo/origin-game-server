--[[
* @file : TechnologyLogic.lua
* @type : lualib
* @author : chenlei
* @created : Fri Jan 03 2020 15:36:06 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 科技研究相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"

local TechnologyLogic = {}

---@see 科技研究
function TechnologyLogic:researchTechnology( _rid, _technologyType )
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    local technologies = RoleLogic:getRole( _rid, Enum.Role.technologies ) or {}
    local level = 0
    if not table.empty(technologies) and technologies[_technologyType] and technologies[_technologyType].level  then
        level = technologies[_technologyType].level
    end
    local technologyId = studyConfig[_technologyType][level + 1].id
    local config = CFG.s_Study:Get(technologyId)
    -- 扣除资源
    if config.needFood then
        RoleLogic:addFood( _rid, -config.needFood, nil, Enum.LogType.TECH_RESEARCH_COST_DENAR )
    end
    if config.needWood then
        RoleLogic:addWood( _rid, -config.needWood, nil, Enum.LogType.TECH_RESEARCH_COST_DENAR )
    end
    if config.needStone then
        RoleLogic:addStone( _rid, -config.needStone, nil, Enum.LogType.TECH_RESEARCH_COST_DENAR )
    end
    if config.needGold then
        RoleLogic:addGold( _rid, -config.needGold, nil, Enum.LogType.TECH_RESEARCH_COST_DENAR )
    end
    local technologyQueue = RoleLogic:getRole( _rid, Enum.Role.technologyQueue ) or {}
    local researchSpeedMulti =  RoleLogic:getRole( _rid, Enum.Role.researchSpeedMulti ) or 0
    local finishTime = config.costTime / ( 1 + researchSpeedMulti/1000 ) // 1
    technologyQueue.finishTime = math.tointeger(os.time() + finishTime)
    technologyQueue.beginTime = os.time()
    technologyQueue.technologyType = _technologyType
    technologyQueue.firstFinishTime = technologyQueue.finishTime
    technologyQueue.timerId = MSM.RoleTimer[_rid].req.addTechnologyTimer( _rid, technologyQueue.finishTime )
    RoleLogic:setRole( _rid, { [Enum.Role.technologyQueue] = technologyQueue } )
    RoleSync:syncSelf( _rid, { [Enum.Role.technologyQueue] = technologyQueue }, true )
    -- 增加开始科技研究累计次数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.TECHNOLOGY_NUM, Enum.TaskArgDefault, 1 )

    return { result = true }
end

---@see 科技研究回调
function TechnologyLogic:researchCallBack( _rid, _isLogin, _isGuildHelp )
    MSM.RoleTimer[_rid].req.deleteTechnologyTimer( _rid )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.technologyQueue, Enum.Role.guildId } ) or {}
    local technologyQueue = roleInfo.technologyQueue or {}
    local requestHelpIndex = technologyQueue.requestHelpIndex
    technologyQueue.finishTime = -1
    technologyQueue.requestGuildHelp = nil
    technologyQueue.requestHelpIndex = nil
    RoleLogic:setRole( _rid, { [Enum.Role.technologyQueue] = technologyQueue } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.technologyQueue] = technologyQueue }, true )
    end
    -- 非联盟帮助减速完成
    if roleInfo.guildId and roleInfo.guildId > 0 and not _isGuildHelp and requestHelpIndex then
        MSM.GuildMgr[roleInfo.guildId].post.roleQueueFinishCallBack( roleInfo.guildId, requestHelpIndex, _isLogin )
    end
    -- 增加推送
    local technologies = RoleLogic:getRole( _rid, Enum.Role.technologies )
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    local technologyType = technologyQueue.technologyType
    local level = 0
    if not table.empty(technologies) and technologies[technologyType] and technologies[technologyType].level then
        level = technologies[technologyType].level
    end
    -- 推送到push server
    if studyConfig[technologyType] and studyConfig[technologyType][level + 1] then
        local technologyId = studyConfig[technologyType][level + 1].id
        SM.PushMgr.post.sendPush( { pushRid = _rid, pushType = Enum.PushType.TECH, args = { arg1 = technologyId } })
    end
end

---@see 领取科技
function TechnologyLogic:awardTechnology( _rid )
    local technologies = RoleLogic:getRole( _rid, Enum.Role.technologies ) or {}
    local technologyQueue = RoleLogic:getRole( _rid, Enum.Role.technologyQueue ) or {}
    local technologyType = technologyQueue.technologyType
    if not technologies[technologyType] then
        technologies[technologyType] = { technologyType = technologyType, level = 0 }
    end
    technologies[technologyType].level = technologies[technologyType].level + 1
    technologyQueue.beginTime = 0
    technologyQueue.technologyType = 0
    technologyQueue.firstFinishTime = -1
    RoleLogic:setRole( _rid, { [Enum.Role.technologies] = technologies, [Enum.Role.technologyQueue] = technologyQueue } )
    RoleSync:syncSelf( _rid, { [Enum.Role.technologies] = { [technologyType] = technologies[technologyType] },
                                [Enum.Role.technologyQueue] = technologyQueue }, true )
    -- 增加科技完成累计次数
    local TaskLogic = require "TaskLogic"
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.TECHNOLOGY_UPGRADE, Enum.TaskArgDefault, 1 )
    -- 更新每日任务进度
    TaskLogic:updateTaskSchedule( _rid, { [Enum.TaskType.TECHNOLOGY_UPGRADE] = { arg = 0, addNum = 1 } } )
    -- 重新计算科技属性加成
    local RoleCacle = require "RoleCacle"
    local roleInfo = RoleLogic:getRole( _rid )
    local oldRoleInfo = table.copy( roleInfo, true )
    local sStudy = RoleCacle:technologyAttrChange( roleInfo, technologyType, technologies[technologyType].level) or {}
    RoleLogic:updateRoleChangeInfo( _rid, oldRoleInfo, roleInfo )
    -- 计算角色最高战力
    RoleLogic:cacleSyncHistoryPower( _rid, roleInfo )
    -- 检查角色相关属性信息是否变化
    RoleCacle:checkRoleAttrChange( _rid, oldRoleInfo, roleInfo )
    -- 登陆设置活动进度
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TECHNOLOGY_RESEARCH, 1 )
    -- 判断战力变化
    local oldPower = 0
    if technologies[technologyType].level > 1 then
        local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
        local level = technologies[technologyType].level - 1
        local technologyId = studyConfig[technologyType][level].id
        local oldStudy = CFG.s_Study:Get(technologyId)
        oldPower = oldStudy.power
    end
    local newPow = sStudy.power
    if newPow > oldPower then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.TECH_POWER_UP, newPow - oldPower )
    end
    local RechargeLogic = require "RechargeLogic"
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    local level = technologies[technologyType].level
    local technologyId = studyConfig[technologyType][level].id
    RechargeLogic:triggerLimitPackage( _rid, { type = Enum.LimitTimeType.TECH_UNLOCK, id = technologyId } )

end

---@see 终止科技研究
function TechnologyLogic:stopTechnology( _rid )
    -- local technologyQueue = RoleLogic:getRole( _rid, Enum.Role.technologyQueue ) or {}
    local studyConfig = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.STUDY ) or {}
    -- local technologies = RoleLogic:getRole( _rid, Enum.Role.technologies )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.technologyQueue, Enum.Role.technologies, Enum.Role.guildId } )
    local technologyQueue = roleInfo.technologyQueue or {}
    local requestHelpIndex = technologyQueue.requestHelpIndex
    local technologies = roleInfo.technologies or {}
    local technologyType = technologyQueue.technologyType
    local level = 0
    if not table.empty(technologies) and technologies[technologyType] and technologies[technologyType].level  then
        level = technologies[technologyType].level
    end
    local technologyId = studyConfig[technologyType][level + 1].id
    -- 判断前置是否满足
    local config = CFG.s_Study:Get(technologyId)
    -- 返还资源
    local studyTerminate = CFG.s_Config:Get("studyTerminate")
    if config.needFood then
        RoleLogic:addFood( _rid, config.needFood*studyTerminate/1000//1, nil, Enum.LogType.TECH_RESEARCH_STOP_GAIN_DENAR )
    end
    if config.needWood then
        RoleLogic:addWood( _rid, config.needWood*studyTerminate/1000//1, nil, Enum.LogType.TECH_RESEARCH_STOP_GAIN_DENAR )
    end
    if config.needStone then
        RoleLogic:addStone( _rid, config.needStone*studyTerminate/1000//1, nil, Enum.LogType.TECH_RESEARCH_STOP_GAIN_DENAR )
    end
    if config.needGold then
        RoleLogic:addGold( _rid, config.needGold*studyTerminate/1000//1, nil, Enum.LogType.TECH_RESEARCH_STOP_GAIN_DENAR )
    end
    technologyQueue.finishTime = -1
    technologyQueue.beginTime = os.time()
    technologyQueue.technologyType = 0
    MSM.RoleTimer[_rid].req.deleteTechnologyTimer( _rid )
    technologyQueue.timerId = 0
    technologyQueue.requestGuildHelp = false
    RoleLogic:setRole( _rid, { [Enum.Role.technologyQueue] = technologyQueue } )
    RoleSync:syncSelf( _rid, { [Enum.Role.technologyQueue] = technologyQueue }, true )
    if roleInfo.guildId > 0 and requestHelpIndex then
        -- 删除联盟求助信息
        MSM.GuildMgr[roleInfo.guildId].post.roleQueueFinishCallBack( roleInfo.guildId, requestHelpIndex )
    end

    return { result = true }
end

---@see 检测科技队列状态
function TechnologyLogic:checkTechnologyQueue( _rid )
    local technologyQueue = RoleLogic:getRole( _rid, Enum.Role.technologyQueue ) or {}
    if technologyQueue.finishTime and technologyQueue.finishTime > 0 and technologyQueue.finishTime <= os.time() then
        self:researchCallBack( _rid, true )
    elseif technologyQueue.finishTime and technologyQueue.finishTime > 0 and not MSM.RoleTimer[_rid].req.checkTechnologyTimer( _rid ) then
        technologyQueue.timerId = MSM.RoleTimer[_rid].req.addTechnologyTimer( _rid, technologyQueue.finishTime )
        RoleLogic:setRole( _rid, { [Enum.Role.technologyQueue] = technologyQueue } )
    end
end

---@see 科研加速
function TechnologyLogic:speedUp( _rid, _sec, _isGuildHelp )
    local technologyQueue = RoleLogic:getRole( _rid, Enum.Role.technologyQueue ) or {}
    technologyQueue.finishTime = technologyQueue.finishTime - _sec
    MSM.RoleTimer[_rid].req.deleteTechnologyTimer( _rid )
    local finishTime = 0
    if technologyQueue.finishTime <= os.time() then
        self:researchCallBack( _rid, nil, _isGuildHelp )
    else
        technologyQueue.timerId = MSM.RoleTimer[_rid].req.addTechnologyTimer( _rid, technologyQueue.finishTime )
        RoleLogic:setRole( _rid, { [Enum.Role.technologyQueue] = technologyQueue } )
        RoleSync:syncSelf( _rid, { [Enum.Role.technologyQueue] = technologyQueue }, true )
        finishTime = technologyQueue.finishTime
    end
    -- 设置活动进度
    if not _isGuildHelp then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USE_SPEED_MIN, _sec/60 )
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.USE_SPEED_MIN_IN_TECH, _sec/60 )
    end
    return finishTime
end

return TechnologyLogic