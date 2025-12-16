--[[
* @file : Task.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu Jan 02 2020 15:53:17 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 任务相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local TaskLogic = require "TaskLogic"
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local ItemLogic = require "ItemLogic"
local LogLogic = require "LogLogic"

---@see 完成任务
function response.TaskFinish( msg )
    local rid = msg.rid
    local taskId = msg.taskId

    -- 参数检查
    if not taskId then
        LOG_ERROR("rid(%d) TaskFinish, no taskId arg", rid)
        return nil, ErrorCode.TASK_ARG_ERROR
    end

    -- 完成任务
    local ret, code = TaskLogic:taskFinish( rid, taskId )
    if ret then
        return { taskId = taskId }
    else
        return nil, code
    end
end

---@see 领取章节
function response.ChapterAccept( msg )
    local rid = msg.rid

    -- 角色当前是否已领取章节
    local chapterId = RoleLogic:getRole( rid, Enum.Role.chapterId )
    if chapterId and chapterId > 0 then
        LOG_ERROR("rid(%d) ChapterAccept, role already have chapterId(%d)", rid, chapterId)
        return nil, ErrorCode.TASK_ALREADY_HAVE_CHAPTER
    end

    -- 角色已经完成所有的章节
    if chapterId and chapterId < 0 then
        LOG_ERROR("rid(%d) ChapterAccept, role already finish all chapterId", rid)
        return nil, ErrorCode.TASK_FINISH_ALL_CHAPTER
    end

    -- 领取章节
    chapterId = 1
    RoleLogic:setRole( rid, { [Enum.Role.chapterId] = chapterId } )
    -- 通知客户端
    RoleSync:syncSelf( rid, { [Enum.Role.chapterId] = chapterId }, true )
end

---@see 完成章节
function response.ChapterFinish( msg )
    local rid = msg.rid

    -- 角色当前是否已领取章节
    local roleInfo = RoleLogic:getRole( rid,{ Enum.Role.chapterId, Enum.Role.chapterTasks } )
    if not roleInfo.chapterId or roleInfo.chapterId <= 0 then
        LOG_ERROR("rid(%d) ChapterFinish, role not have chapterId", rid)
        return nil, ErrorCode.TASK_NOT_HAVE_CHAPTER
    end

    -- 角色当前是否已完成所有的章节任务
    local allChapterTasks = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.CHAPTER_TASK ) or {}
    for taskId in pairs( allChapterTasks[roleInfo.chapterId] or {} ) do
        if not roleInfo.chapterTasks[taskId] or roleInfo.chapterTasks[taskId].status ~= Enum.ChapterTaskStatus.FINISH then
            -- 该章节任务未完成
            LOG_ERROR("rid(%d) ChapterFinish, role not finish chapterTaskId(%d)", rid, taskId)
            return nil, ErrorCode.TASK_NOT_FINISH_ALL_CHAPTER_TASK
        end
    end

    local newChapterId = roleInfo.chapterId + 1
    local newTaskChapterData = CFG.s_TaskChapterData:Get( newChapterId )
    if not newTaskChapterData or table.empty( newTaskChapterData ) then
        newChapterId = -1
    end
    local roleChangeInfo = {}
    local roleSyncInfo = {}
    -- 章节进度更新
    roleChangeInfo.chapterId = newChapterId
    roleSyncInfo.chapterId = newChapterId
    roleChangeInfo.chapterTasks = {}
    roleSyncInfo.chapterTasks = {}
    for taskId in pairs( roleInfo.chapterTasks ) do
        roleSyncInfo.chapterTasks[taskId] = { taskId = taskId, status = Enum.ChapterTaskStatus.DELETE }
    end

    -- 更新章节信息和章节任务信息
    RoleLogic:setRole( rid, roleChangeInfo )
    -- 通知客户端
    RoleSync:syncSelf( rid, roleSyncInfo, true, true )
    -- 领取章节完成奖励
    local reward = CFG.s_TaskChapterData:Get( roleInfo.chapterId, "reward" )
    ItemLogic:getItemPackage( rid, reward )

    return { chapterId = newChapterId }
end

---@see 领取活跃度奖励
function response.TakeActivePointReward( msg )
    local rid = msg.rid
    local activePoint = msg.activePoint

    -- 参数检查
    if not activePoint then
        LOG_ERROR("rid(%d) TakeActivePointReward, no activePoint arg", rid)
        return nil, ErrorCode.TASK_ARG_ERROR
    end

    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.activePointRewards, Enum.Role.level } )
    -- 活跃度是否足够
    if not RoleLogic:checkActivePoint( rid, activePoint ) then
        LOG_ERROR("rid(%d) TakeActivePointReward, role activePoint not enough", rid)
        return false, ErrorCode.TASK_ACTIVE_POINT_NOT_ENOUGH
    end

    -- 奖励是否已经发放过
    local activePointRewards = roleInfo.activePointRewards or {}
    if table.exist( activePointRewards, activePoint ) then
        LOG_ERROR("rid(%d) TakeActivePointReward, role have take activePoint(%d) reward", rid, activePoint)
        return false, ErrorCode.TASK_ACTIVE_POINT_NOT_ENOUGH
    end

    local sTaskActivityReward = CFG.s_TaskActivityReward:Get( roleInfo.level )
    if not sTaskActivityReward or table.empty( sTaskActivityReward ) then
        LOG_ERROR("rid(%d) TakeActivePointReward, s_TaskActivityReward not have level(%d)", rid, roleInfo.level )
        return false, ErrorCode.CFG_ERROR
    end
    if not sTaskActivityReward[activePoint] then
        LOG_ERROR("rid(%d) TakeActivePointReward, s_TaskActivityReward level(%d) not activePoint(%d) cfg",
                    rid, roleInfo.dailytaskAge, activePoint)
        return false, ErrorCode.CFG_ERROR
    end
    -- 奖励领取状态修改
    table.insert( activePointRewards, activePoint )
    RoleLogic:setRole( rid, { [Enum.Role.activePointRewards] = activePointRewards } )
    -- 通知客户端
    RoleSync:syncSelf( rid, { [Enum.Role.activePointRewards] = activePointRewards }, true )

    -- 发放奖励
    ItemLogic:getItemPackage( rid, sTaskActivityReward[activePoint] )
end
