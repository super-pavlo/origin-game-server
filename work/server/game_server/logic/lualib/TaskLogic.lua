--[[
* @file : TaskLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Dec 31 2019 15:27:38 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 任务相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local LogLogic = require "LogLogic"
local ItemLogic = require "ItemLogic"
local BuildingLogic = require "BuildingLogic"
local math = require "math"
local HeroLogic = require "HeroLogic"

local TaskLogic = {}

---@see 获取任务属性
function TaskLogic:getTask( _rid, _taskId, _fields )
    return MSM.d_task[_rid].req.Get( _rid, _taskId, _fields )
end

---@see 计算任务分组
function TaskLogic:getTaskGroupType( _taskId )
    return math.tointeger( _taskId / 100000 // 1 )
end

---@see 领取任务
function TaskLogic:taskAccept( _rid, _taskId, _noSync )
    -- 现在只有主线任务需要领取
    RoleLogic:setRole( _rid, { [Enum.Role.mainLineTaskId] = _taskId } )

    if not _noSync then
        -- 推送主线任务ID
        RoleSync:syncSelf( _rid, { [Enum.Role.mainLineTaskId] = _taskId }, true, true )
    end
end

---@see 是否是章节任务
function TaskLogic:checkChapterTask( _taskId )
    return self:getTaskGroupType( _taskId ) == Enum.TaskGroupType.CHAPTER
end

---@see 是否是主线任务
function TaskLogic:checkMainLineTask( _taskId )
    return self:getTaskGroupType( _taskId ) == Enum.TaskGroupType.MAIN_LINE
end

---@see 是否是支线任务
function TaskLogic:checkSideLineTask( _taskId )
    return self:getTaskGroupType( _taskId ) == Enum.TaskGroupType.SIDE_LINE
end

---@see 是否是支线任务
function TaskLogic:checkDailyTask( _taskId )
    return self:getTaskGroupType( _taskId ) == Enum.TaskGroupType.DAILY
end

---@see 检查统计完成次数
function TaskLogic:checkStatisticsNum( _taskStatistics, _type, _arg, _needTimes )
    local num = 0
    if _taskStatistics and _taskStatistics[_type] then
        for _, statistics in pairs( _taskStatistics[_type].statistics or {} ) do
            if ( ( not _arg or _arg <= 0 ) and statistics.arg == Enum.TaskArgDefault ) or ( _arg and _arg == statistics.arg ) then
                num = statistics.num
                break
            end
        end
    end

    return num >= _needTimes
end

---@see 统计完成次数
function TaskLogic:getStatisticsNum( _taskStatistics, _type, _arg )
    local num = 0
    if _taskStatistics and _taskStatistics[_type] then
        for _, statistics in pairs( _taskStatistics[_type].statistics or {} ) do
            if ( ( not _arg or _arg <= 0 ) and statistics.arg == Enum.TaskArgDefault ) or ( _arg and _arg == statistics.arg ) then
                num = statistics.num
                break
            end
        end
    end

    return num
end


---@see 检查任务条件是否满足
function TaskLogic:checkTaskFinish( _rid, _taskStatistics, _type, _param1, _param2, _require )
    -- 按照任务条件类型判断
    if _type == Enum.TaskType.SAVAGE_KILL then
        -- 野蛮人击杀数
        return self:checkStatisticsNum( _taskStatistics, _type, _param1, _require )
    elseif _type == Enum.TaskType.TECHNOLOGY_UPGRADE then
        -- 科技升级
        if _param1 and _param1 > 0 then
            -- 科技升级到指定等级
            local level = 0
            local technologies = RoleLogic:getRole( _rid, Enum.Role.technologies ) or {}
            if technologies[_param1] then
                level = technologies[_param1].level
            end

            return level >= ( _param2 or 0 )
        else
            -- 升级科技指定次数
            return self:checkStatisticsNum( _taskStatistics, _type, nil, _require )
        end
    elseif _type == Enum.TaskType.SOLDIER_NUM then
        -- 兵种类型数量
        -- local num = 0
        -- local soldiers = RoleLogic:getRole( _rid, Enum.Role.soldiers ) or {}
        -- for _, soldierInfo in pairs( soldiers ) do
        --     if not _param1 or _param1 == 0 or soldierInfo.type == _param1 then
        --         num = num + soldierInfo.num
        --     end
        -- end

        -- return num >= _require
        return true
    elseif _type == Enum.TaskType.BUILDING_UPGRADE then
        -- 建筑提升
        if _param1 and _param1 > 0 then
            local buildings = BuildingLogic:getBuilding( _rid ) or {}
            for _, building in pairs( buildings ) do
                if building.type == _param1 and building.level >= _param2 then
                    return true
                end
            end

            return false
        else
            return self:checkStatisticsNum( _taskStatistics, _type, nil, _require )
        end
    elseif _type == Enum.TaskType.CITY_RESOURCE or _type == Enum.TaskType.MAP_RESOURCE then
        -- 城市内收集资源、地图采集资源
        if _param1 and _param1 > 0 then
            -- 收集指定资源
            return self:checkStatisticsNum( _taskStatistics, _type, _param1, _require )
        else
            -- 收集任意一种资源
            if _taskStatistics and _taskStatistics[_type] then
                for _, statistics in pairs( _taskStatistics[_type].statistics or {} ) do
                    if statistics.num >= _require then
                        return true
                    end
                end
            end

            return false
        end
    elseif _type == Enum.TaskType.SOLDIER_SUMMON then
        -- 士兵招募
        return self:checkStatisticsNum( _taskStatistics, _type, _param1, _require )
    elseif _type == Enum.TaskType.BUILDING_NUM then
        -- 建筑数量
        local num = 0
        local buildings = BuildingLogic:getBuilding( _rid ) or {}
        for _, building in pairs( buildings ) do
            if building.type == _param1 then
                num = num + 1
            end
        end

        return num >= _require
    elseif _type == Enum.TaskType.FOG_EXPLORE then
        if RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) then
            -- 迷雾全开, 不需要判断迷雾探索个数
            return true
        end
        -- 迷雾探索
        return self:checkStatisticsNum( _taskStatistics, _type, nil, _require )
    elseif _type == Enum.TaskType.SCORE_NUM then
        -- 战力
        local historyPower = RoleLogic:getRole( _rid, Enum.Role.historyPower )
        return historyPower >= _require
    elseif _type == Enum.TaskType.RESOURCE_NUM then
        -- 资源产量
        local roleInfo =  RoleLogic:getRole( _rid )
        local addRate = 0
        local buildType
        -- 产量加成
        if _param1 == Enum.ResourceType.FARMLAND then
            addRate = roleInfo.foodCapacityMulti or 0
            buildType = Enum.BuildingType.FARM
        elseif _param1 == Enum.ResourceType.WOOD then
            addRate = roleInfo.woodCapacityMulti or 0
            buildType = Enum.BuildingType.WOOD
        elseif _param1 == Enum.ResourceType.STONE then
            addRate = roleInfo.stoneCapacityMulti or 0
            buildType = Enum.BuildingType.STONE
        elseif _param1 == Enum.ResourceType.GOLD then
            addRate = roleInfo.glodCapacityMulti or 0
            buildType = Enum.BuildingType.GOLD
        end
        local num = 0
        local sBuildingResourcesProduce = CFG.s_BuildingResourcesProduce:Get()
        local buildings = BuildingLogic:getBuilding( _rid ) or {}
        for _, building in pairs( buildings ) do
            if building.type == buildType then
                num = num + ( sBuildingResourcesProduce[building.type][building.level].produceSpeed or 0 )
            end
        end

        return ( num * ( 1000 + addRate ) / 1000 ) >= _require
    elseif _type == Enum.TaskType.DISPATCH_ARMY then
        -- 部队派遣次数
        return self:checkStatisticsNum( _taskStatistics, _type, nil, _require )
    elseif _type == Enum.TaskType.HEAL_SOLDIER then
        -- 治疗获得伤兵数
        return self:checkStatisticsNum( _taskStatistics, _type, nil, _require )
    elseif _type == Enum.TaskType.SOLDIER_TRAIN then
        -- 士兵训练
        return self:checkStatisticsNum( _taskStatistics, _type, _param1, _require )
    elseif _type == Enum.TaskType.TECHNOLOGY_NUM then
        -- 开始科技研究次数
        return self:checkStatisticsNum( _taskStatistics, _type, nil, _require )
    elseif _type == Enum.TaskType.JOIN_GUILD or _type == Enum.TaskType.OCCUPY_HOLYlAND or _type == Enum.TaskType.OCCUPY_CHECKPOINT
        or _type == Enum.TaskType.MODIFY_NAME or _type == Enum.TaskType.TAVERN_BOX or _type == Enum.TaskType.HERO_SKILL_NUM
        or _type == Enum.TaskType.HERO_TALENT_NUM or _type == Enum.TaskType.MONSTER_CITY_NUM or _type == Enum.TaskType.SCOUT_NUM
        or _type == Enum.TaskType.MODIFY_HEADID or _type == Enum.TaskType.VILLAGE_REWARD or _type == Enum.TaskType.SCOUT_CAVE
        or _type == Enum.TaskType.HELP_GUILD_MEMBER or _type == Enum.TaskType.SHOP_BUY or _type == Enum.TaskType.MYSTERY_BUY
        or _type == Enum.TaskType.EQUIP_QUALITY or _type == Enum.TaskType.EQUIP_BOOK or _type == Enum.TaskType.MATERIAL_QUALITY
        or _type == Enum.TaskType.PRODUCE_MATERIAL_QUALITY or _type == Enum.TaskType.RESOLVE_EQUIP_QUALITY
        or _type == Enum.TaskType.RESOLVE_MATERIAL_QUALITY then
        -- 加入联盟、占领圣地、占领关卡、修改昵称
        return self:checkStatisticsNum( _taskStatistics, _type, _param1, _require )
    elseif _type == Enum.TaskType.HERO_LEVEL then
        -- 统帅等级
        local heros = HeroLogic:getHero( _rid ) or {}
        for _, heroInfo in pairs(heros) do
            if heroInfo.level >= _require then
                return true
            end
        end
    elseif _type == Enum.TaskType.HERO_STAR_NUM then
        -- 统帅升星
        local num = 0
        local heros = HeroLogic:getHero( _rid ) or {}
        for _, heroInfo in pairs(heros) do
            if heroInfo.star >= _param1 then
                num = num + 1
            end
        end

        return num >= _require
    elseif _type == Enum.TaskType.DISCOVER_CHECKPOINT or _type == Enum.TaskType.DISCOVER_HOLYLAND then
        -- 发现关卡、发现圣地
        if RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) then
            -- 迷雾全开, 不需要判断关卡圣地探索个数
            return true
        end

        return self:checkStatisticsNum( _taskStatistics, _type, _param1, _require )
    elseif _type == Enum.TaskType.EXPEDITION then
        -- 远征关卡
        local expeditionInfo = RoleLogic:getRole( _rid, Enum.Role.expeditionInfo ) or {}
        return expeditionInfo[_param1] and true or false
    end
end

---@see 完成主线任务
function TaskLogic:finishMainLineTask( _rid, _taskId )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.mainLineTaskId, Enum.Role.iggid, Enum.Role.taskStatisticsSum } )
    -- 当前是否是此主线任务
    if roleInfo.mainLineTaskId ~= _taskId then
        LOG_ERROR("rid(%d) finishMainLineTask, role not accept mainLineTaskId(%d)", _rid, _taskId)
        return false, ErrorCode.TASK_NOT_ACCEPT_MAINLINE
    end

    -- 任务配置是否存在
    local sTask = CFG.s_TaskMain:Get( _taskId )
    if not sTask or table.empty( sTask ) then
        LOG_ERROR("rid(%d) finishMainLineTask, s_TaskMain taskId(%d) cfg not exist", _rid, _taskId)
        return false, ErrorCode.CFG_ERROR
    end

    -- 判断任务条件是否满足
    if not self:checkTaskFinish( _rid, roleInfo.taskStatisticsSum, sTask.type, sTask.param1, sTask.param2, sTask.require ) then
        LOG_ERROR("rid(%d) finishMainLineTask, taskId(%d) not finish", _rid, _taskId)
        return false, ErrorCode.TASK_NOT_FINISH
    end

    -- 领取奖励
    ItemLogic:getItemPackage( _rid, sTask.reward )
    -- 记录日志
    LogLogic:roleTask( { iggid = roleInfo.iggid, taskId = _taskId, rid = _rid } )

    local nextTaskId = sTask.nextId
    if not nextTaskId or nextTaskId <= 0 then
        -- 完成所有的主线任务后为-1
        nextTaskId = -1
    end
    -- 领取下一个主线任务
    self:taskAccept( _rid, nextTaskId )

    return true
end

---@see 完成支线任务
function TaskLogic:finishSideLineTask( _rid, _taskId )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.finishSideTasks, Enum.Role.iggid, Enum.Role.taskStatisticsSum } )
    -- 支线任务是否已完成
    if roleInfo.finishSideTasks and roleInfo.finishSideTasks[_taskId] then
        LOG_ERROR("rid(%d) finishSideLineTask, taskId(%d) finished", _rid, _taskId)
        return false, ErrorCode.TASK_SIDE_FINISHED
    end
    -- 任务配置是否存在
    local sTask = CFG.s_TaskSide:Get( _taskId )
    if not sTask or table.empty( sTask ) then
        LOG_ERROR("rid(%d) finishSideLineTask, s_TaskSide taskId(%d) cfg not exist", _rid, _taskId)
        return false, ErrorCode.CFG_ERROR
    end

    -- 判断任务条件是否满足
    if not self:checkTaskFinish( _rid, roleInfo.taskStatisticsSum, sTask.type, sTask.param1, sTask.param2, sTask.require ) then
        LOG_ERROR("rid(%d) finishSideLineTask, taskId(%d) not finish", _rid, _taskId)
        return false, ErrorCode.TASK_NOT_FINISH
    end

    -- 领取奖励
    ItemLogic:getItemPackage( _rid, sTask.reward )

    -- 更新支线任务完成列表
    local finishSideTasks = roleInfo.finishSideTasks or {}
    finishSideTasks[_taskId] = { taskId = _taskId }
    RoleLogic:setRole( _rid, { [Enum.Role.finishSideTasks] = finishSideTasks } )
    -- 通知客户端
    RoleSync:syncSelf( _rid, { [Enum.Role.finishSideTasks] = { [_taskId] = finishSideTasks[_taskId] } }, true, true )
    -- 记录日志
    LogLogic:roleTask( { iggid = roleInfo.iggid, taskId = _taskId, rid = _rid } )

    return true
end

---@see 完成章节任务
function TaskLogic:finishChapterTask( _rid, _taskId )
    -- 角色当前是否已领取章节
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.chapterId, Enum.Role.chapterTasks, Enum.Role.iggid, Enum.Role.taskStatisticsSum } )
    if not roleInfo.chapterId or roleInfo.chapterId <= 0 then
        LOG_ERROR("rid(%d) finishChapterTask, role not have chapterId", _rid)
        return false, ErrorCode.TASK_NOT_HAVE_CHAPTER
    end

    -- 章节任务是否存在
    local sTaskChapter = CFG.s_TaskChapter:Get( _taskId )
    if not sTaskChapter or table.empty( sTaskChapter ) then
        LOG_ERROR("rid(%d) finishChapterTask, s_TaskChapter chapterTaskId(%d) not exist", _rid, _taskId)
        return false, ErrorCode.CFG_ERROR
    end

    -- 该任务是否为当前章节中的任务
    if sTaskChapter.chapterId ~= roleInfo.chapterId then
        LOG_ERROR("rid(%d) finishChapterTask, chapterId(%d) not have chapterTaskId(%d)", _rid, roleInfo.chapterId, _taskId)
        return false, ErrorCode.TASK_CHAPTER_NOT_TASK
    end

    -- 该任务是否已完成并领取奖励
    if roleInfo.chapterTasks and roleInfo.chapterTasks[_taskId]
        and roleInfo.chapterTasks[_taskId].status == Enum.ChapterTaskStatus.FINISH then
        LOG_ERROR("rid(%d) finishChapterTask, role already finish chapterTaskId(%d)", _rid, _taskId)
        return false, ErrorCode.TASK_ALREADY_FINISH_CHAPTER_TASK
    end

    -- 判断任务条件是否满足
    if not self:checkTaskFinish( _rid, roleInfo.taskStatisticsSum, sTaskChapter.type, sTaskChapter.param1, sTaskChapter.param2, sTaskChapter.require ) then
        LOG_ERROR("rid(%d) finishChapterTask, taskId(%d) not finish", _rid, _taskId)
        return false, ErrorCode.TASK_NOT_FINISH
    end

    -- 完成章节任务
    roleInfo.chapterTasks[_taskId] = { taskId = _taskId, status = Enum.ChapterTaskStatus.FINISH }
    RoleLogic:setRole( _rid, { [Enum.Role.chapterTasks] = roleInfo.chapterTasks } )
    -- 通知客户端
    RoleSync:syncSelf( _rid, { [Enum.Role.chapterTasks] = { [_taskId] = roleInfo.chapterTasks[_taskId] } }, true, true )
    -- 领取奖励
    ItemLogic:getItemPackage( _rid, sTaskChapter.reward )

    -- 记录日志
    LogLogic:roleTask( { iggid = roleInfo.iggid, taskId = _taskId, rid = _rid } )

    return true
end

---@see 完成每日任务
function TaskLogic:finishDailyTask( _rid, _taskId )
    local taskInfo = self:getTask( _rid, _taskId )

    -- 任务是否存在
    if not taskInfo or table.empty( taskInfo ) then
        LOG_ERROR("rid(%d) finishDailyTask, taskId(%d) not exist", _rid, _taskId)
        return false, ErrorCode.TASK_NOT_EXIST
    end

    local sTaskDaily = CFG.s_TaskDaily:Get( _taskId )
    if not sTaskDaily or table.empty( sTaskDaily ) then
        LOG_ERROR("rid(%d) finishDailyTask, s_TaskDaily not have taskId(%d)", _rid, _taskId)
        return false, ErrorCode.CFG_ERROR
    end

    -- 任务进度是否已完成
    if not ( taskInfo.taskSchedule > 0 and taskInfo.taskSchedule > sTaskDaily.param2 ) then
        LOG_ERROR("rid(%d) finishDailyTask, taskId(%d) not finish", _rid, _taskId)
        return false, ErrorCode.TASK_NOT_FINISH
    end

    -- 删除任务
    MSM.d_task[_rid].req.Delete( _rid, _taskId )
    -- 通知客户端
    self:syncTask( _rid, _taskId, { taskId = _taskId, taskSchedule = -1 }, true )

    -- 发放任务奖励
    ItemLogic:getItemPackage( _rid, sTaskDaily.reward )
    -- 角色增加活跃度值
    if sTaskDaily.score > 0 then
        RoleLogic:addActivePoint( _rid, sTaskDaily.score )
    end

    return true
end

---@see 完成任务
function TaskLogic:taskFinish( _rid, _taskId )
    if self:checkMainLineTask( _taskId ) then
        -- 完成主线任务
        return self:finishMainLineTask( _rid, _taskId )
    elseif self:checkSideLineTask( _taskId ) then
        -- 完成支线任务
        return self:finishSideLineTask( _rid, _taskId )
    elseif self:checkChapterTask( _taskId ) then
        -- 完成章节任务
        return self:finishChapterTask( _rid, _taskId )
    elseif self:checkDailyTask( _taskId ) then
        -- 完成每日任务
        return self:finishDailyTask( _rid, _taskId )
    end
end

---@see 增加任务累计统计信息
function TaskLogic:addTaskStatisticsSum( _rid, _type, _arg, _addNum, _noSync )
    local taskStatisticsSum = RoleLogic:getRole( _rid, Enum.Role.taskStatisticsSum ) or {}
    if not taskStatisticsSum[_type] then taskStatisticsSum[_type] = { type = _type, statistics = {} } end
    -- 增加统计信息
    local statisticsIndex
    for index, statisticsInfo in pairs( taskStatisticsSum[_type].statistics ) do
        if _arg == statisticsInfo.arg then
            statisticsIndex = index
            taskStatisticsSum[_type].statistics[index].num = statisticsInfo.num + _addNum
            break
        end
    end
    -- 新增统计信息
    if not statisticsIndex then
        table.insert( taskStatisticsSum[_type].statistics, { arg = _arg, num = _addNum } )
    end

    -- 更新统计信息
    RoleLogic:setRole( _rid, { [Enum.Role.taskStatisticsSum] = taskStatisticsSum } )
    if not _noSync then
        -- 通知客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.taskStatisticsSum] = { [_type] = taskStatisticsSum[_type] } }, true )
    end

    return taskStatisticsSum
end

---@see 更新任务进度
function TaskLogic:updateTaskSchedule( _rid, _typeSchedules, _noSync )
    if not _typeSchedules or table.empty( _typeSchedules ) then return end

    local sTaskDaily = CFG.s_TaskDaily:Get()
    local allTasks = self:getTask( _rid ) or {}
    local noFinishTasks = {}
    -- 找出所有未完成的任务
    for taskId, taskInfo in pairs( allTasks ) do
        if sTaskDaily[taskId] and taskInfo.taskSchedule < sTaskDaily[taskId].require then
            if not noFinishTasks[sTaskDaily[taskId].type] then
                noFinishTasks[sTaskDaily[taskId].type] = {}
            end
            noFinishTasks[sTaskDaily[taskId].type][taskId] = {
                taskSchedule = taskInfo.taskSchedule,
                require = sTaskDaily[taskId].require,
                arg = sTaskDaily[taskId].param1,
            }
        end
    end

    if not table.empty( noFinishTasks ) then
        -- 更新未完成任务进度
        local newTaskSchedule
        local syncTasks = {}
        for type, scheduleInfo in pairs( _typeSchedules ) do
            for taskId, taskInfo in pairs( noFinishTasks[type] or {} ) do
                if taskInfo.arg == 0 or taskInfo.arg == scheduleInfo.arg then
                    newTaskSchedule = taskInfo.taskSchedule + scheduleInfo.addNum
                    if newTaskSchedule > taskInfo.require then
                        newTaskSchedule = taskInfo.require
                    end
                    MSM.d_task[_rid].req.Set( _rid, taskId, { taskSchedule = newTaskSchedule } )
                    syncTasks[taskId] = {
                        taskId = taskId, taskSchedule = newTaskSchedule
                    }
                end
            end
        end

        if not _noSync and not table.empty( syncTasks ) then
            -- 通知客户端
            self:syncTask( _rid, nil, syncTasks, true )
        end
    end
end

---@see 更新道具使用类每日任务
function TaskLogic:updateItemUseTaskSchedule( _rid, _itemId, _num, _sItem )
    if not _sItem and not _itemId then return end
    local sItem = _sItem or CFG.s_Item:Get( _itemId )

    local sTaskDaily = CFG.s_TaskDaily:Get()
    local allTasks = self:getTask( _rid ) or {}
    local noFinishTasks = {}
    -- 找出所有未完成的任务
    for taskId, taskInfo in pairs( allTasks ) do
        if sTaskDaily[taskId] and sTaskDaily[taskId].type == Enum.TaskType.USE_ITEM
            and taskInfo.taskSchedule < sTaskDaily[taskId].require then
            noFinishTasks[taskId] = {
                taskSchedule = taskInfo.taskSchedule,
                require = sTaskDaily[taskId].require,
                param1 = sTaskDaily[taskId].param1,
                param2 = sTaskDaily[taskId].param2,
            }
        end
    end

    if not table.empty( noFinishTasks ) then
        -- 更新未完成任务进度
        local newTaskSchedule
        local syncTasks = {}
        for taskId, taskInfo in pairs( noFinishTasks ) do
            newTaskSchedule = nil
            if taskInfo.param2 > 0 then
                if taskInfo.param2 == sItem.type and taskInfo.param1 == sItem.typeGroup then
                    newTaskSchedule = taskInfo.taskSchedule + _num
                end
            elseif taskInfo.param1 == sItem.subType then
                newTaskSchedule = taskInfo.taskSchedule + _num
            end
            if newTaskSchedule then
                if newTaskSchedule > taskInfo.require then
                    newTaskSchedule = taskInfo.require
                end
                MSM.d_task[_rid].req.Set( _rid, taskId, { taskSchedule = newTaskSchedule } )
                syncTasks[taskId] = {
                    taskId = taskId, taskSchedule = newTaskSchedule
                }
            end
        end

        if not table.empty( syncTasks ) then
            -- 通知客户端
            self:syncTask( _rid, nil, syncTasks, true )
        end
    end
end

---@see 更新同步任务信息
function TaskLogic:syncTask( _rid, _taskId, _field, _haskv, _block )
    local taskInfo
    local syncInfo = {}
    if not _haskv then
        if type( _taskId ) == "table" then
            -- 同步多个任务
            for _, taskId in pairs( _taskId ) do
                taskInfo = self:getTask( _rid, taskId )
                taskInfo.taskId = taskId
                syncInfo[taskId] = taskInfo
            end
        else
            taskInfo = self:getTask( _rid, _taskId )
            taskInfo.taskId = _taskId
            syncInfo[_taskId] = taskInfo
        end
    else
        if _taskId then
            _field.taskId = _taskId
            syncInfo[_taskId] = _field
        else
            syncInfo = _field
        end
    end

    -- 同步
    Common.syncMsg( _rid, "Task_TaskInfo",  { taskInfo = syncInfo }, _block )
end

---@see 跨天重置任务相关信息
function TaskLogic:resetTaskInfoDaily( _rid, _isLogin )
    local ageInfo = BuildingLogic:checkAge( _rid )
    local age = ageInfo.age

    local syncTaskInfo = {}
    local allTasks = self:getTask( _rid )
    local dailyTasks = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.DAILY_TASK ) or {}
    local ageTasks = dailyTasks[age] or {}
    -- 移除不在角色当前时代的任务
    for taskId in pairs( allTasks ) do
        if not ageTasks[taskId] then
            MSM.d_task[_rid].req.Delete( _rid, taskId )
            syncTaskInfo[taskId] = {
                taskId = taskId, taskSchedule = -1
            }
        end
    end

    -- 增加角色当前没有的该时代的任务
    local taskInfo
    for taskId in pairs( ageTasks ) do
        if not allTasks[taskId] then
            taskInfo = { taskId = taskId, taskSchedule = 0 }
            MSM.d_task[_rid].req.Add( _rid, taskId, taskInfo )
            syncTaskInfo[taskId] = taskInfo
        end
    end

    -- 重置活跃度
    local roleChangeInfo = {}
    local syncRoleInfo = {}
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.activePoint, Enum.Role.activePointRewards, Enum.Role.dailytaskAge } )
    if roleInfo.activePoint > 0 then
        roleChangeInfo.activePoint = 0
        syncRoleInfo.activePoint = 0
    end
    -- 重置已领取的活跃度奖励信息
    if not table.empty( roleInfo.activePointRewards or {} ) then
        roleChangeInfo.activePointRewards = {}
        syncRoleInfo.activePointRewards = {}
    end
    -- 每日任务时代变化
    if roleInfo.dailytaskAge ~= age then
        roleChangeInfo.dailytaskAge = age
    end

    if not table.empty( roleChangeInfo ) then
        RoleLogic:setRole( _rid, roleChangeInfo )
    end

    -- 通知客户端
    if not _isLogin then
        -- 登录时不推送
        if not table.empty( syncTaskInfo ) then
            self:syncTask( _rid, nil, syncTaskInfo, true )
        end
        if not table.empty( syncRoleInfo ) then
            RoleSync:syncSelf( _rid, syncRoleInfo, true )
        end
    end
end

---@see 推送角色任务信息
function TaskLogic:pushAllTask( _rid )
    local tasks = self:getTask( _rid )
    local syncTaskInfos = {}

    for taskId, taskInfo in pairs( tasks ) do
        syncTaskInfos[taskId] = {
            taskId = taskId,
            taskSchedule = taskInfo.taskSchedule,
        }
    end

    -- 同步
    Common.syncMsg( _rid, "Task_TaskInfo",  { taskInfo = syncTaskInfos } )
end

return TaskLogic