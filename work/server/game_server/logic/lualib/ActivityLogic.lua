--[[
* @file : ActivityLogic.lua
* @type : lua lib
* @author : chenlei
* @created : Wed Apr 08 2020 12:58:00 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 活动相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]
local RoleSync = require "RoleSync"
local BuildingLogic = require "BuildingLogic"
local RoleLogic = require "RoleLogic"
local HeroLogic = require "HeroLogic"
local ItemLogic = require "ItemLogic"
local EmailLogic = require "EmailLogic"
local Timer = require "Timer"
local RankLogic = require "RankLogic"
local LogLogic = require "LogLogic"

local ActivityLogic = {}

---@see 判断活动是否开启
function ActivityLogic:checkActivityTime( _activityId, _activityInfo, _rid )
    local activityInfo = _activityInfo or SM.ActivityMgr.req.getActivityInfo( _activityId )
    if not activityInfo then return false end
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(_activityId)
    local time = os.time()
    if not sActivityCalendar or table.empty( sActivityCalendar ) then
        LOG_ERROR("s_ActivityCalendar no activityId(%s) cfg", tostring( _activityId ))
        return false
    end
    if sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
        -- 判断时间
        local newActivityOpenTime = RoleLogic:getRole( _rid, Enum.Role.newActivityOpenTime )
        local endTime = Timer.GetTimeDayX(
            newActivityOpenTime, (sActivityCalendar.durationTime + 1) / 24 / 3600 , CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
        if time >= newActivityOpenTime and time <= endTime  then
            return true, activityInfo
        end
    elseif sActivityCalendar.timeType == Enum.ActivityTimeType.CREATE_TIME then
        -- 判断时间
        local createTime = RoleLogic:getRole( _rid, Enum.Role.createTime )
        local beginTime = Timer.GetTimeDayX(
            createTime, sActivityCalendar.timeData1 - 1, CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
        local endTime = Timer.GetTimeDayX(
            beginTime, (sActivityCalendar.durationTime + 1) / 24 / 3600 , CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true ) - 1
        if time >= beginTime and time <= endTime then
            return true, activityInfo
        end
    else
        if activityInfo.startTime == -1 then
            return true, activityInfo
        elseif time >= activityInfo.startTime and time <= activityInfo.endTime then
            return true, activityInfo
        end
    end
    return false
end

---@see 地狱活动领奖
function ActivityLogic:hellReward( _rid, _activityId, _id, _index, _noShowLog, _isLogin )
    local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
    local activityInfo = SM.ActivityMgr.req.getActivityInfo( _activityId )
    if not activity or not activity[_activityId] or ( _isLogin and (activityInfo and activityInfo.startTime == activity[_activityId].startTime)) then
        if not _noShowLog then
            LOG_ERROR("rid(%d) hellReward error, this reward is awarded ", _rid )
        end
        return nil, ErrorCode.ACTIVITY_CAN_NOT_AWARD
    end
    if activity and activity[_activityId] and activity[_activityId].rewards and activity[_activityId].rewards[_index] then
        if not _noShowLog then
            LOG_ERROR("rid(%d) hellReward error, this reward is awarded ", _rid )
        end
        return nil, ErrorCode.ACTIVITY_AWARDED
    end
    activityInfo = activity[_activityId]
    local order
    local orderConfig
    for _, id in pairs(activityInfo.ids or {}) do
        local config = CFG.s_ActivityInfernal:Get(id)
        if not order or config.order > order then
            order = config.order
            orderConfig = config
        end
    end
    if not activity or not activity[_activityId] or activity[_activityId].score < orderConfig.score[_index] then
        if not _noShowLog then
            LOG_ERROR("rid(%d) hellReward error, this reward is awarded ", _rid )
        end
        return nil, ErrorCode.ACTIVITY_CAN_NOT_AWARD
    end
    -- 判断是否领奖
    -- if activity and activity[_activityId] and table.exist(activity[_activityId].rewardId, _id) then
    --     LOG_ERROR("rid(%d) killTypeReward error, this reward is awarded ", _rid )
    --     return nil, ErrorCode.ACTIVITY_AWARDED
    -- end
    if not activity[_activityId].rewards then activity[_activityId].rewards = {} end
    activity[_activityId].rewards[_index] = { index = _index }
    --local synActiviy = {}
    --synActiviy[_activityId] = activity[_activityId]
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
    if not _isLogin then
        self:synReward( _rid, _index, _activityId )
    end
    local rewardInfo
    if not _noShowLog then
        rewardInfo = ItemLogic:getItemPackage( _rid, orderConfig.reward[_index] )
    else
        rewardInfo = ItemLogic:getItemPackage( _rid, orderConfig.reward[_index], true )
        EmailLogic:sendEmail( _rid, CFG.s_Config:Get("activityInfernalMail"), { rewards = rewardInfo, emailContents = { _index } } )
    end

    return { rewardInfo = rewardInfo, activityId = _activityId, id = _id, index = _index }
end

---@see 最强执政官领奖
function ActivityLogic:killTypeReward( _rid, _activityId, _id, _index )
    local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo(_activityId)
    local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[_activityId]
    -- 判断今天是第几阶段
    local startTime = activityTimeInfo.startTime
    local stage = 0
    for i=1,table.size(configStage) do
        local continueTime = configStage[i].continueTime
        if os.time() >= startTime and os.time() <= startTime + continueTime then
            stage = i
            break
        else
            startTime = startTime + continueTime
        end
    end
    local config = CFG.s_ActivityKillType:Get(_id)
    if config.stage ~= stage then
        LOG_ERROR("rid(%d) killTypeReward error, can't award this reward ", _rid )
        return nil, ErrorCode.ACTIVITY_DAY_ERROR
    end
    -- 判断是否领奖
    local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
    -- if activity and activity[_activityId] and table.exist(activity[_activityId].rewardId, _id) then
    --     LOG_ERROR("rid(%d) killTypeReward error, this reward is awarded ", _rid )
    --     return nil, ErrorCode.ACTIVITY_AWARDED
    -- end
    if activity and activity[_activityId] and activity[_activityId].rewards and activity[_activityId].rewards[_index] then
        LOG_ERROR("rid(%d) killTypeReward error, this reward is awarded ", _rid )
        return nil, ErrorCode.ACTIVITY_AWARDED
    end
    if not activity or not activity[_activityId] or activity[_activityId].score < config.standard[_index] then
        LOG_ERROR("rid(%d) killTypeReward error, this reward is awarded ", _rid )
        return nil, ErrorCode.ACTIVITY_CAN_NOT_AWARD
    end
    if not activity[_activityId].rewards then activity[_activityId].rewards = {} end
    activity[_activityId].rewards[_index] = { index = _index }
    --local synActiviy = {}
    --synActiviy[_activityId] = activity[_activityId]
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
    self:synReward( _rid, _index, _activityId )
    local rewardInfo = ItemLogic:getItemPackage( _rid, config.itemPackage[_index] )
    return { rewardInfo = rewardInfo, activityId = _activityId, id = _id, index = _index }
end

---@see 领取活动奖励
function ActivityLogic:receiveReward( _rid, _activityId, _id, _noAdd, _activity, _isLogin )
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(_activityId)
    local config
    local activity = _activity or RoleLogic:getRole( _rid, Enum.Role.activity )
    if not activity or not activity[_activityId] then return end
    if activity and activity[_activityId] and table.exist(activity[_activityId].rewardId, _id) then return end
    if sActivityCalendar.activityType == Enum.ActivityType.BASIC_TARGER or sActivityCalendar.activityType == Enum.ActivityType.DAY_RESET
                or sActivityCalendar.activityType == Enum.ActivityType.TARGER_RANK then
        config = CFG.s_ActivityTargetType:Get(_id)
    elseif sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN
        or sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
        config = CFG.s_ActivityDaysType:Get(_id)
    end
    if config.lv and config.lv ~= -1 and config.lv ~= activity[_activityId].level then
        LOG_ERROR("rid(%d) ReceiveReward error, config error ", _rid )
        return nil, ErrorCode.ACTIVITY_CITY_LEVEL_ERROR
    end
    if activity and activity[_activityId] and table.exist(activity[_activityId].rewardId, _id) then
        LOG_ERROR("rid(%d) ReceiveReward error, this reward is awarded ", _rid )
        return nil, ErrorCode.ACTIVITY_AWARDED
    end
    local condition = config.data3
    local count = config.data0
    -- if config.playerBehavior == Enum.ActivityActionType.KILL_BARB_WALL_LEVEL_COUNT then
    --     condition = config.data0
    --     count = config.data1
    -- end
    if table.empty(activity[_activityId].scheduleInfo) or not activity[_activityId].scheduleInfo[config.playerBehavior].data[condition] or
        activity[_activityId].scheduleInfo[config.playerBehavior].data[condition].count == 0 or
        activity[_activityId].scheduleInfo[config.playerBehavior].data[condition].count < count then
        --LOG_ERROR("rid(%d) ReceiveReward error, can't award this reward ", _rid )
        return nil, ErrorCode.ACTIVITY_CAN_NOT_AWARD
    end
    if not activity[_activityId].rewardId then activity[_activityId].rewardId = {} end
    table.insert( activity[_activityId].rewardId, _id )
    if config.day and config.day > (activity[_activityId].day or 0 ) then
        activity[_activityId].day = config.day
    end
    --local synActiviy = {}
    --synActiviy[_activityId] = activity[_activityId]
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
    if not _noAdd then
        self:synReward( _rid, _id, _activityId )
    else
        if _activityId == 100001 then
            local rewardInfo = ItemLogic:getItemPackage( _rid, config.itemPackage )
            EmailLogic:sendEmail( _rid, 100030, { takeEnclosure = true, rewards = rewardInfo, emailContents = { _activityId }, subTitleContents = { _activityId } }, _isLogin )
        else
            local rewardInfo = ItemLogic:getItemPackage( _rid, config.itemPackage, true )
            EmailLogic:sendEmail( _rid, 100030, { rewards = rewardInfo, emailContents = { _activityId }, subTitleContents = { _activityId } }, _isLogin )
        end
        return true
    end
    --RoleSync:syncSelf( _rid, { [Enum.Role.activity] = synActiviy }, true )
    return { rewardInfo = ItemLogic:getItemPackage( _rid, config.itemPackage, nil, _isLogin ), activityId = _activityId, id = _id }
    -- if config.specialItem and config.specialItem > 0 then
    --     ItemLogic:getItemPackage( _rid, config.specialItem )
    -- end
end

---@see 开服活动自动领取前置奖励
function ActivityLogic:autoRewardOpenActivity( _rid, _sActivityCalendar, _activityInfo, _isLogin )
    local configs = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[_sActivityCalendar.prepositionID]
    local update = false
    for id in pairs(configs) do
        local flag = ActivityLogic:receiveReward( _rid, _sActivityCalendar.prepositionID, id, true, _activityInfo, _isLogin )
        if flag then
            update = true
        end
    end
    if update then
        local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
        local id = _sActivityCalendar.prepositionID
        if not _isLogin then
            RoleSync:syncSelf( _rid, { [Enum.Role.activity] = { [id] = activity[id] } }, true )
        end
    end
end


---@see 领取开服活动最后奖励
function ActivityLogic:rewardOpenServer( _rid, _activityId, _noAdd, _isLogin )
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(_activityId)
    local prepositionID = sActivityCalendar.prepositionID
    local activityInfo = RoleLogic:getRole( _rid, Enum.Role.activity )
    if activityInfo and activityInfo[_activityId] and activityInfo[_activityId].rewardBox then
        LOG_ERROR("rid(%d) ReceiveReward error, this reward is awarded ", _rid )
        return nil, ErrorCode.ACTIVITY_AWARDED
    end
    if not activityInfo[prepositionID] or not activityInfo[prepositionID].rewardId or table.size(activityInfo[prepositionID].rewardId) <= 0 then
        LOG_ERROR("rid(%d) rewardOpenServer error, can't award this reward ", _rid )
        return nil, ErrorCode.ACTIVITY_CAN_NOT_AWARD
    end
    if not activityInfo[_activityId] then activityInfo[_activityId] = {} end
    activityInfo[_activityId].acitivityId = _activityId
    activityInfo[_activityId].rewardBox = true
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activityInfo } )
    if not _isLogin then
        self:synRewardBox( _rid, _activityId )
    end
    local config
    local rewardInfo = {}
    for _, id in pairs(activityInfo[prepositionID].rewardId) do
        config = CFG.s_ActivityDaysType:Get(id)
        ItemLogic:mergeReward(rewardInfo, ItemLogic:getItemPackage(_rid, config.specialItem, _noAdd))
    end
    if _noAdd then
        EmailLogic:sendEmail( _rid, 100030, { rewards = rewardInfo, emailContents = { _activityId }, subTitleContents = { _activityId } }, _isLogin )
        return
    end
    return { rewardInfo = rewardInfo, activityId = _activityId }
end

---@see 活动自动发奖
function ActivityLogic:autoSendReward( _rid, _config, _update )
    local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
    if _update then
        local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo(_config.activityType)
        self:startReset( _rid, _config.activityType, activity, activityTimeInfo, {} )
        if not activity[_config.activityType].rewards then activity[_config.activityType].rewards = {} end
        activity[_config.activityType].rewards[_config.ID] = { index = _config.ID }
    end
    local emailContents = { _config.activityType, _config.stage }
    local rewardInfo = ItemLogic:getItemPackage( _rid, _config.itemPackage )
    EmailLogic:sendEmail( _rid, _config.mailID, { rewards = rewardInfo, emailContents = emailContents, takeEnclosure = true } )
    if _update then
        RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
        --RoleSync:syncSelf( _rid, { [Enum.Role.activity] = activity[_config.activityType] }, true )
    end
end

---@see 活动进度设置
function ActivityLogic:setActivitySchedule( _rid, _actionType, _addNum, _condition, _condition2, _reset,
                        _oldActionType, _isLogin, _times, _free, _discount )
    _condition = ( _condition or 0) * 10000 + ( _condition2 or 0 )
    local activityInfo = RoleLogic:getRole( _rid, Enum.Role.activity ) or {}
    local update = false

    for activityId, activity in pairs(activityInfo) do
        local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
        local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo(activityId)
        if self:checkActivityTime( activityId, activityTimeInfo, _rid ) then
            if _actionType == Enum.ActivityActionType.LOGIN_DAY then
                if activityInfo[activityId] and activityInfo[activityId].scheduleInfo and activityInfo[activityId].scheduleInfo[_actionType] then
                    local lastLoginTime = activityInfo[activityId].scheduleInfo[_actionType].lastLoginTime or 0
                    if not Timer.isDiffDay(lastLoginTime) then
                        _addNum = 0
                    end
                end
                if _addNum > 0 and activityInfo[activityId].scheduleInfo[_actionType] then
                    activityInfo[activityId].scheduleInfo[_actionType].lastLoginTime = os.time()
                end
            end
            local config = {}
            local updateSonRank = 0
            local updateRank = 0
            local day
            local maxScore
            local stage
            local allianceRank = 0
            local autoSendReward = 0
            local autoConfig
            if sActivityCalendar.activityType == Enum.ActivityType.BASIC_TARGER or sActivityCalendar.activityType == Enum.ActivityType.DAY_RESET
                or sActivityCalendar.activityType == Enum.ActivityType.TARGER_RANK then
                config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_TRAGET_TYPE )[activityId] or {}
            elseif sActivityCalendar.activityType == Enum.ActivityType.DROP or sActivityCalendar.activityType == Enum.ActivityType.DROP_RANK
                or sActivityCalendar.activityType == Enum.ActivityType.LUOHA then
                config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DROP_TYPE )[activityId] or {}
            elseif sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
                config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[activityId]
                if sActivityCalendar.timeType == Enum.ActivityTimeType.CREATE_TIME then
                    -- 判断时间
                    local createTime = RoleLogic:getRole( _rid, Enum.Role.createTime )
                    local beginTime = Timer.GetTimeDayX(
                        createTime, sActivityCalendar.timeData1 - 1, CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
                    day = Timer.getDiffDays( beginTime, os.time() ) + 1
                else
                    -- 计算当前时间是第几天
                    day = Timer.getDiffDays( activityTimeInfo.startTime, os.time() ) + 1
                end
            elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
                config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[activityId]
                -- 计算当前时间是第几天
                local newActivityOpenTime = RoleLogic:getRole( _rid, Enum.Role.newActivityOpenTime )
                day = Timer.getDiffDays( newActivityOpenTime, os.time() ) + 1
            elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
                local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[activityId]
                -- 判断今天是第几阶段
                local startTime = activityTimeInfo.startTime
                stage = 0
                for i=1,table.size(configStage) do
                    local continueTime = configStage[i].continueTime
                    if os.time() >= startTime and os.time() <= startTime + continueTime then
                        stage = i
                        break
                    else
                        startTime = startTime + continueTime
                    end
                end
                if stage > 0 then
                    local groupsType = configStage[stage].groupsType
                    config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[activityId][groupsType]
                    updateSonRank = configStage[stage].leaderboardID
                end
            elseif sActivityCalendar.activityType == Enum.ActivityType.HELL and activityTimeInfo then
                local age = BuildingLogic:checkAge( _rid, activity.level ).age
                for _, id in pairs(activity.ids) do
                    local sActivityInfernal = CFG.s_ActivityInfernal:Get(id)
                    if not maxScore or maxScore < sActivityInfernal.score[3] then
                        maxScore = sActivityInfernal.score[3]
                    end
                    table.merge(config, CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[activityId][sActivityInfernal.type])
                end
                if age == Enum.RoleAge.ORIGINAL then
                    updateRank = Enum.RankType.HELL_ORIGINAL
                elseif age == Enum.RoleAge.CLASSICAL then
                    updateRank = Enum.RankType.HELL_CLASSICAL
                elseif age == Enum.RoleAge.DARK then
                    updateRank = Enum.RankType.HELL_DARK
                elseif age == Enum.RoleAge.FEUDAL then
                    updateRank = Enum.RankType.HELL_FEUDAL
                elseif age == Enum.RoleAge.INDUSTRY then
                    updateRank = Enum.RankType.HELL_INDUSTRY
                elseif age == Enum.RoleAge.MODERN then
                    updateRank = Enum.RankType.HELL_MODERN
                end
            elseif sActivityCalendar.activityType == Enum.ActivityType.FIGHT_HORN
            or sActivityCalendar.activityType == Enum.ActivityType.TRIBE_KING then
                autoConfig = CFG.s_ActivityIntegralType:Get(activityId)
                local firstConfig = table.first(autoConfig).value
                local groupsType = firstConfig.groupsType
                allianceRank = sActivityCalendar.allianceleaderboard
                config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[activityId][groupsType]
                autoSendReward = firstConfig.target
            elseif sActivityCalendar.activityType == Enum.ActivityType.TURN_TABLE then
                table.insert(config, { playerBehavior = Enum.ActivityActionType.TURN_TABLE, data3 = 0 })
            end
            if sActivityCalendar.leaderboard > 0 and sActivityCalendar.activityType ~= Enum.ActivityType.HELL and
            sActivityCalendar.activityType ~= Enum.ActivityType.MEG_END_SHOW and sActivityCalendar.activityType ~= Enum.ActivityType.TARGER_RANK_END
            and sActivityCalendar.activityType ~= Enum.ActivityType.DROP_RANK_END and sActivityCalendar.activityType ~= Enum.ActivityType.FIGHT_HORN_SHOW and
            sActivityCalendar.activityType ~= Enum.ActivityType.TRIBE_KING_SHOW then
                updateRank = sActivityCalendar.leaderboard
            end
            --- 比较特殊的玩家行为
            local specially = false
            if _actionType == Enum.ActivityActionType.TRAIN_LEVEL_INFANTRY or _actionType == Enum.ActivityActionType.TRAIN_LEVEL_CAVALRY
                            or _actionType == Enum.ActivityActionType.TRAIN_LEVEL_ARCHER or _actionType == Enum.ActivityActionType.TRAIN_LEVEL_SIEGE_UNIT
                            or _actionType == Enum.ActivityActionType.TRAIN_LEVEL_ALL or _actionType == Enum.ActivityActionType.KILL_BARB_LEVEL2_COUNT then
                specially = true
            end
            --- 建筑，英雄的玩家行为要额外处理
            local buildAction = {}
            buildAction[Enum.ActivityActionType.BUILD_TO_LEVEL] = Enum.ActivityActionType.BUILD_TO_LEVEL
            buildAction[Enum.ActivityActionType.BUILD_TO_LEVEL_COUNT] = Enum.ActivityActionType.BUILD_TO_LEVEL_COUNT
            buildAction[Enum.ActivityActionType.HERO_LEVEL_COUNT] = Enum.ActivityActionType.HERO_LEVEL_COUNT

            if activity.scheduleInfo and activity.scheduleInfo[_actionType] then
                local thisConfig = {}
                local config2 = {}
                local addFlag = true
                -- 开服活动需要判断天数
                if sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
                    local flag = false
                    for _, v in pairs( config ) do
                        if not v.lv or v.lv == -1 or activity.level == v.lv then
                            if buildAction[_actionType] and _actionType == v.playerBehavior and v.day <= day then
                                table.insert(thisConfig,v)
                                flag = true
                            elseif specially and _actionType == v.playerBehavior and _condition >= (v.data1 * 10000 + v.data2 ) and v.day <= day then
                                thisConfig[v.data3] = v
                                flag = true
                            elseif _actionType == v.playerBehavior and _condition == (v.data1 * 10000 + v.data2 ) and v.day <= day and not thisConfig[v.data3] then
                                if not v.data3 then
                                    table.insert(config2,v)
                                else
                                    thisConfig[v.data3] = v
                                end
                                flag = true
                            end
                        end
                    end
                    if not flag then addFlag = false end
                elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
                    local flag = false
                    for _, v in pairs( config ) do
                        if not v.lv or v.lv == -1 or activity.level == v.lv then
                            if buildAction[_actionType] and _actionType == v.playerBehavior and v.day == day then
                                table.insert(thisConfig,v)
                                flag = true
                            elseif specially and _actionType == v.playerBehavior and _condition >= (v.data1 * 10000 + v.data2 ) and v.day == day then
                                thisConfig[v.data3] = v
                                flag = true
                            elseif _actionType == v.playerBehavior and _condition == (v.data1 * 10000 + v.data2 ) and v.day == day and not thisConfig[v.data3] then
                                if not v.data3 then
                                    table.insert(config2,v)
                                else
                                    thisConfig[v.data3] = v
                                end
                                flag = true
                            end
                        end
                    end
                    if not flag then addFlag = false end
                else
                    for _, v in pairs( config ) do
                        if not v.lv or v.lv == -1 or activity.level == v.lv then
                            if buildAction[_actionType] and _actionType == v.playerBehavior then
                                table.insert(thisConfig,v)
                            elseif specially and _actionType == v.playerBehavior and ( not v.data3 or _condition >= v.data3 ) then
                                thisConfig[v.data3] = v
                            elseif _actionType == v.playerBehavior and ( not v.data3 or ( _condition == v.data3 and not thisConfig[v.data3] ) )then
                                if not v.data3 then
                                    table.insert(config2,v)
                                else
                                    thisConfig[v.data3] = v
                                end
                            end
                        end
                    end
                end
                if not table.empty(config2) then
                    table.merge(config2, thisConfig)
                    thisConfig = config2
                end
                if table.empty(thisConfig) then addFlag = false end
                if addFlag then
                    update = true
                    if not _addNum then _addNum = 0 end
                    for _, activities in pairs(thisConfig) do
                        local actionType = activities.playerBehavior
                        local condition = activities.data3 or 0
                        local addNum
                        local scheduleCount = activityInfo[activityId].scheduleInfo[actionType].data[condition].count
                        local times = activityInfo[activityId].scheduleInfo[actionType].data[condition].times or 0
                        local turnCount = activityInfo[activityId].count or 0
                        local dayCount = activityInfo[activityId].dayCount or 0
                        if actionType == Enum.ActivityActionType.BUILD_TO_LEVEL then
                            _addNum = BuildingLogic:getBuildingLv( _rid, activities.data1 )
                            if _addNum > scheduleCount then
                                addNum = _addNum - scheduleCount
                                scheduleCount = _addNum
                            end
                        elseif actionType == Enum.ActivityActionType.BUILD_TO_LEVEL_COUNT then
                            _addNum = BuildingLogic:getBuildingLvCount( _rid, activities.data1, activities.data2 )
                            if _addNum > scheduleCount then
                                addNum = _addNum - scheduleCount
                                scheduleCount = _addNum
                            end
                        elseif actionType == Enum.ActivityActionType.HERO_LEVEL_COUNT then
                            _addNum = HeroLogic:checkHeroLevelCount( _rid, activities.data1 )
                            if _addNum > scheduleCount then
                                addNum = _addNum - scheduleCount
                                scheduleCount = _addNum
                            end
                        elseif actionType == Enum.ActivityActionType.BUILD_ALLIANCE_TIME then
                            times = times + _times
                            _addNum = times / 60 // 1
                            if _addNum > scheduleCount then
                                addNum = _addNum - scheduleCount
                                scheduleCount = _addNum
                            end
                            activityInfo[activityId].scheduleInfo[actionType].data[condition].times = times
                        elseif _reset then
                            if _addNum > scheduleCount then
                                addNum = _addNum - scheduleCount
                                scheduleCount = _addNum
                            end
                        else
                            scheduleCount = scheduleCount + _addNum
                            addNum = _addNum
                        end

                        -- 移除小数点
                        scheduleCount = math.floor(scheduleCount)

                        if actionType == Enum.ActivityActionType.TURN_TABLE then
                            turnCount = turnCount + _addNum
                            activityInfo[activityId].count = turnCount
                            if not _free and not _discount then
                                dayCount = dayCount + _addNum
                                activityInfo[activityId].dayCount = dayCount
                            elseif _free then
                                local freeCount = activityInfo[activityId].free or 0
                                freeCount = freeCount + 1
                                activityInfo[activityId].free = freeCount
                            elseif _discount then
                                activityInfo[activityId].discount = true
                            end
                        end
                        if addNum and addNum > 0 and not _isLogin then
                            local free = activityInfo[activityId].free or 0
                            local discount = activityInfo[activityId].discount
                            self:synScheduleInfo( _rid, activityId, actionType, condition, scheduleCount, turnCount, dayCount, free, discount )
                        end
                        if addNum and addNum > 0 then
                            if sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
                                self:severOpenLog( _rid, activityId, actionType, day, condition, scheduleCount, scheduleCount - addNum )
                            elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
                                self:severNewActivityLog( _rid, activityId, actionType, day, condition, scheduleCount, scheduleCount - addNum  )
                            end
                        end
                        -- 自动发奖
                        local addCount = addNum
                        if activities.award and activities.award > 0 then
                            if scheduleCount >= activities.data0 then
                                local rewardInfo = ItemLogic:getItemPackage( _rid, activities.itemPackage, true )
                                if table.size(rewardInfo) > 1 then
                                    addCount = 0
                                    EmailLogic:sendEmail( _rid, activities.mailID, { rewards = rewardInfo } )
                                    for _, itemInfo in pairs(rewardInfo.items) do
                                        addCount = addCount + itemInfo.itemNum
                                    end
                                end
                            end
                        end
                        -- 赋值
                        activityInfo[activityId].scheduleInfo[actionType].data[condition].count = scheduleCount

                        -- 排行版计算
                        local score = 0
                        local rank = 0
                        local addScore = 0
                        local sLeaderboard
                        local rankOfAlliance = 0
                        local allianceScore = 0
                        if updateRank > 0 and ( sActivityCalendar.leaderboardPlayerBehavior == 0 or sActivityCalendar.leaderboardPlayerBehavior == _actionType ) then
                            -- 计算分数
                            addScore = addCount
                            local count = 0
                            if activities.integral and activities.integral > 0 then
                                if activities.data0 == 0 then
                                    count = addCount / 1
                                else
                                    count = math.floor(addCount / activities.data0)
                                end
                                if count == 0 then
                                    count = 1
                                end
                                addScore = count * activities.integral
                            end
                            if _oldActionType then
                                for _, v in pairs( config ) do
                                    if _oldActionType == v.playerBehavior then
                                        addScore = addScore - v.integral * count
                                        break
                                    end
                                end
                            end
                            local oldScore = 0
                            if maxScore and maxScore > 0 then
                                oldScore = activityInfo[activityId].score
                                score = (activityInfo[activityId].score or 0 ) + addScore
                                if score > maxScore then
                                    RankLogic:update( _rid, updateRank, score)
                                    rank = RankLogic:getRank( _rid, updateRank, true )
                                end
                            else
                                oldScore = activityInfo[activityId].score
                                score = (RankLogic:queryOneRecord( _rid, updateRank ) or 0 ) + addScore
                                RankLogic:update( _rid, updateRank, score)
                                rank = RankLogic:getRank( _rid, updateRank, true )
                            end
                            if sActivityCalendar.activityType == Enum.ActivityType.HELL then
                                self:hellLog( _rid, activityId, score, oldScore )
                            end
                            sLeaderboard = CFG.s_Leaderboard:Get(updateRank)
                            -- 自动发奖处理
                            if Enum.AutoRewardType.PERSON == autoSendReward then
                                local nowScore = math.modf(score)
                                oldScore = tonumber(oldScore)
                                for _, cInfo in pairs(autoConfig) do
                                    if oldScore < cInfo.standard and nowScore >= cInfo.standard then
                                        if not activityInfo[activityId] or not activityInfo[activityId].rewards
                                            or not activityInfo[activityId].rewards[cInfo.ID] then
                                            self:autoSendReward( _rid, cInfo )
                                            if not activityInfo[activityId].rewards then activityInfo[activityId].rewards = {} end
                                            activityInfo[activityId].rewards[cInfo.ID] = { index = cInfo.ID }
                                        end
                                    end
                                end
                            end
                        end
                        if updateSonRank > 0 and ( sActivityCalendar.leaderboardPlayerBehavior == 0 or sActivityCalendar.leaderboardPlayerBehavior == _actionType ) then
                            -- 计算分数
                            local sonRank
                            local sonScore
                            if stage and stage > 0 then
                                if not activityInfo[activityId].ranks then
                                    activityInfo[activityId].ranks = {}
                                end
                                if not activityInfo[activityId].ranks[stage] then
                                    activityInfo[activityId].ranks[stage] = { index = stage, rank = 0, score = 0 }
                                end
                                if not activityInfo[activityId].ranks[6] then
                                    activityInfo[activityId].ranks[6] = { index = 6, rank = 0, score = 0 }
                                end
                                activityInfo[activityId].ranks[stage].score = activityInfo[activityId].ranks[stage].score + addScore
                                activityInfo[activityId].ranks[6].score = activityInfo[activityId].ranks[6].score + addScore
                            end
                            sonScore = (activityInfo[activityId].score or 0 ) + addScore
                            RankLogic:update( _rid, updateSonRank, sonScore)
                            sonRank = RankLogic:getRank( _rid, updateSonRank, true )
                            score = sonScore
                            rank = sonRank
                            sLeaderboard = CFG.s_Leaderboard:Get(updateSonRank)
                        end
                        local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
                        if guildId > 0 and allianceRank > 0 and ( sActivityCalendar.leaderboardPlayerBehavior == 0 or sActivityCalendar.leaderboardPlayerBehavior == _actionType ) then
                            -- 计算分数
                            addScore = addCount
                            local count = 0
                            if activities.integral and activities.integral > 0 then
                                if activities.data0 == 0 then
                                    count = addCount / 1
                                else
                                    count = math.floor(addCount / activities.data0)
                                end
                                if count == 0 then
                                    count = 1
                                end
                                addScore = count * activities.integral
                            end
                            if _oldActionType then
                                for _, v in pairs( config ) do
                                    if _oldActionType == v.playerBehavior then
                                        addScore = addScore - v.integral * count
                                        break
                                    end
                                end
                            end
                            local oldScore = RankLogic:queryOneRecord(guildId, allianceRank) or 0
                            allianceScore = oldScore + addScore
                            RankLogic:update( guildId, allianceRank, allianceScore)
                            rankOfAlliance = RankLogic:getRank( guildId, allianceRank, true )
                            local GuildLogic = require "GuildLogic"
                            if Enum.AutoRewardType.ALLIANCE == autoSendReward then
                                local nowScore = math.modf(allianceScore)
                                oldScore = tonumber(oldScore)
                                for _, cInfo in pairs(autoConfig) do
                                    if oldScore < cInfo.standard and nowScore >= cInfo.standard then
                                        local members = GuildLogic:getGuild( guildId, Enum.Guild.members ) or {}
                                        for memberRid in pairs( members ) do
                                            local memActivity = RoleLogic:getRole( memberRid, Enum.Role.activity )
                                            if not memActivity[activityId] or not memActivity[activityId].rewards
                                            or not memActivity[activityId].rewards[cInfo.ID] then
                                                local updateFlag = true
                                                if memberRid == _rid then
                                                    updateFlag = false
                                                    if not activityInfo[activityId].rewards then activityInfo[activityId].rewards = {} end
                                                    activityInfo[activityId].rewards[cInfo.ID] = { index = cInfo.ID }
                                                end
                                                self:autoSendReward( memberRid, cInfo, updateFlag )
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if sLeaderboard and not table.empty(sLeaderboard) and not sLeaderboard.recordLimit then
                            LOG_INFO("size(%d)", table.size(sLeaderboard))
                        end
                        if sLeaderboard and not table.empty(sLeaderboard) and sLeaderboard.recordLimit and sLeaderboard.list ~= 3 then
                            local recordLimit = sLeaderboard.recordLimit
                            if rank > recordLimit then
                                rank = 0
                            end
                        end

                        if score > 0 or rank > 0 and not _isLogin then
                            activityInfo[activityId].score = score
                            activityInfo[activityId].rank = rank or 0
                            if sActivityCalendar.activityType ~= Enum.ActivityType.FIGHT_HORN
                            and sActivityCalendar.activityType ~= Enum.ActivityType.TRIBE_KING then
                                self:synRankInfo( _rid, activityId, activityInfo[activityId].score, activityInfo[activityId].rank,
                                            rankOfAlliance , allianceScore )
                            end
                        end
                    end
                end
            end
        end
    end
    if update then
        RoleLogic:setRole( _rid, { [Enum.Role.activity] = activityInfo } )
    end
end

function ActivityLogic:startReset( _rid, _activityId, _activity, _activityTimeInfo, _synActivity )
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(_activityId)
    if not sActivityCalendar then
        _activity[_activityId] = nil
        return
    end
    if sActivityCalendar.activityType == Enum.ActivityType.HELL then
        local townHall = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.TOWNHALL )[1]
        if townHall.level < CFG.s_Config:Get("activityInfernalLevelLimit") then
            return false
        end
    end
    local config = {}
    local updateRank = 0
    local updateSonRank = 0
    local day = 0
    local stage = 0
    local ids = {}
    if sActivityCalendar.activityType == Enum.ActivityType.BASIC_TARGER or sActivityCalendar.activityType == Enum.ActivityType.DAY_RESET
        or sActivityCalendar.activityType == Enum.ActivityType.TARGER_RANK then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_TRAGET_TYPE )[_activityId] or {}
    elseif sActivityCalendar.activityType == Enum.ActivityType.DROP or sActivityCalendar.activityType == Enum.ActivityType.DROP_RANK or
        sActivityCalendar.activityType == Enum.ActivityType.LUOHA then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DROP_TYPE )[_activityId] or {}
    elseif sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[_activityId]
        if sActivityCalendar.timeType == Enum.ActivityTimeType.CREATE_TIME then
            -- 判断时间
            local createTime = RoleLogic:getRole( _rid, Enum.Role.createTime )
            local beginTime = Timer.GetTimeDayX(
                createTime, sActivityCalendar.timeData1 - 1, CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
            day = Timer.getDiffDays( beginTime, os.time() ) + 1
            _activityTimeInfo.startTime = beginTime
            local endTime = Timer.GetTimeDayX(
            beginTime, (sActivityCalendar.durationTime + 1) / 24 / 3600 , CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true ) - 1
            _activityTimeInfo.endTime = endTime
        else
            -- 计算当前时间是第几天
            day = Timer.getDiffDays( _activityTimeInfo.startTime, os.time() ) + 1
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[_activityId]
        -- 计算当前时间是第几天
        local newActivityOpenTime = RoleLogic:getRole( _rid, Enum.Role.newActivityOpenTime )
        _activityTimeInfo.startTime = newActivityOpenTime
        day = Timer.getDiffDays( newActivityOpenTime, os.time() ) + 1
    elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
        local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[_activityId]
        -- 判断今天是第几阶段
        local startTime = _activityTimeInfo.startTime
        for i=1,table.size(configStage) do
            local continueTime = configStage[i].continueTime
            if os.time() >= startTime and os.time() < startTime + continueTime then
                stage = i
                break
            else
                startTime = startTime + continueTime
            end
        end
        if stage > 0 then
            local groupsType = configStage[stage].groupsType
            config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[_activityId][groupsType]
            updateSonRank = configStage[stage].leaderboardID
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_END_SHOW then
        if self:checkActivityTime( _activityId, _activityTimeInfo, _rid ) and ( not _activity[_activityId] or _activity[_activityId].startTime ~= _activityTimeInfo.startTime) then
            _activity[_activityId] = {
                activityId = _activityId,
                scheduleInfo = {},
                startTime = _activityTimeInfo.startTime,
                rewardId = {},
                level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                exchange = {},
                isNew = true,
            }
            local ranks = {}
            local key
            local rank
            local score
            for i=1,5 do
                key = string.format("kill_type_%d", i)
                rank = MSM.RankMgr[_rid].req.getRank( _rid, key, true)
                score = RankLogic:getScore( MSM.RankMgr[_rid].req.queryOneRecord( _rid, key ), Enum.RankType.MGE_TOTAL )
                ranks[i] = { index = i, rank = rank, score = score }
            end
            key = string.format("kill_type_all")
            rank = MSM.RankMgr[_rid].req.getRank( _rid, key, true )
            score = RankLogic:getScore( MSM.RankMgr[_rid].req.queryOneRecord( _rid, key ), Enum.RankType.MGE_TOTAL )
            ranks[6] = { index = 6, rank = rank, score = score }
            _activity[_activityId].ranks = ranks
            _activity[_activityId].score = score
            _activity[_activityId].season = table.size(SM.c_kill_type_history.req.Get()) + 1
            _synActivity[_activityId] = _activity[_activityId]
            return _synActivity
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.HELL then
        local age = BuildingLogic:checkAge( _rid ).age
        for _, id in pairs(_activityTimeInfo.rule[age].ids) do
            local sActivityInfernal = CFG.s_ActivityInfernal:Get(id)
            table.merge( config,CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[_activityId][sActivityInfernal.type])
            table.insert(ids, id)
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.FIGHT_HORN
        or sActivityCalendar.activityType == Enum.ActivityType.TRIBE_KING then
        local sActivityInfernal = CFG.s_ActivityIntegralType:Get(_activityId)
        local firstConfig = table.first(sActivityInfernal).value
        local groupsType = firstConfig.groupsType
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[_activityId][groupsType]
    elseif sActivityCalendar.activityType == Enum.ActivityType.TURN_TABLE then
        table.insert(config, { playerBehavior = Enum.ActivityActionType.TURN_TABLE, data3 = 0 })
    end

    if self:checkActivityTime( _activityId, _activityTimeInfo, _rid ) or
        ( _activity[_activityId] and _activity[_activityId].startTime ~= _activityTimeInfo.startTime ) then
        if sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
            if not _activity[_activityId] then
                _activity[_activityId] = {
                    activityId = _activityId,
                    scheduleInfo = {},
                    startTime = _activityTimeInfo.startTime,
                    rewardId = {},
                    level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                    exchange = {},
                    stage = stage,
                    score = 0,
                    rank = 0,
                    ranks = {},
                    count = 0,
                    dayCount = 0,
                    free = 0,
                    discount = false,
                    isNew = true,
                }
            elseif _activity[_activityId].startTime > 0 and _activity[_activityId].startTime ~= _activityTimeInfo.startTime then
                _activity[_activityId] = {
                    activityId = _activityId,
                    scheduleInfo = {},
                    startTime = _activityTimeInfo.startTime,
                    rewardId = {},
                    level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                    exchange = {},
                    stage = stage,
                    score = 0,
                    rank = 0,
                    ranks = {},
                    count = 0,
                    dayCount = 0,
                    free = 0,
                    discount = false,
                    isNew = true,
                }
            elseif _activity[_activityId].stage ~= stage then
                _activity[_activityId].scheduleInfo = {}
                _activity[_activityId].rewards = {}
                _activity[_activityId].rank = 0
                _activity[_activityId].score = 0
                _activity[_activityId].stage = stage
            end
        elseif not _activity[_activityId] then
            _activity[_activityId] = {
                activityId = _activityId,
                scheduleInfo = {},
                startTime = _activityTimeInfo.startTime,
                rewardId = {},
                level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                exchange = {},
                stage = stage,
                score = 0,
                rank = 0,
                ids = ids,
                activeReward = false,
                times = 0,
                count = 0,
                dayCount = 0,
                free = 0,
                discount = false,
                isNew = true,
            }
        elseif _activity[_activityId].startTime > 0 and _activity[_activityId].startTime ~= _activityTimeInfo.startTime then
            _activity[_activityId] = {
                activityId = _activityId,
                scheduleInfo = {},
                startTime = _activityTimeInfo.startTime,
                rewardId = {},
                level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                exchange = {},
                stage = stage,
                ids = ids,
                score = 0,
                rank = 0,
                activeReward = false,
                times = 0,
                count = 0,
                dayCount = 0,
                free = 0,
                discount = false,
                isNew = true,
            }
        end

        _synActivity[_activityId] = _activity[_activityId]
        local scheduleInfo = _activity[_activityId].scheduleInfo
        -- if sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN and _activity[_activityId].startTime == _activityTimeInfo.startTime then
        --     scheduleInfo = _activity[_activityId].scheduleInfo
        -- end
        for _, configInfo in pairs(config) do
            if not scheduleInfo[configInfo.playerBehavior] then scheduleInfo[configInfo.playerBehavior] = { type = configInfo.playerBehavior, data = {} } end
            local count = 0
            -- 统计数量
            if not configInfo.day or configInfo.day <= day then
                if configInfo.playerBehavior == Enum.ActivityActionType.BUILD_COUNT then
                    count = table.size(BuildingLogic:getBuildingInfoByType( _rid, configInfo.data1 ))
                elseif configInfo.playerBehavior == Enum.ActivityActionType.BUILD_TO_LEVEL then
                    count = BuildingLogic:getBuildingLv( _rid, config.data1 )
                elseif configInfo.playerBehavior == Enum.ActivityActionType.BUILD_TO_LEVEL_COUNT then
                    count = BuildingLogic:getBuildingLvCount( _rid, config.data1, config.data2 )
                elseif configInfo.playerBehavior == Enum.ActivityActionType.RES_BUILD_LEVEL then
                    count = BuildingLogic:getResBuilding( _rid, { Enum.BuildingType.FARM, Enum.BuildingType.WOOD, Enum.BuildingType.STONE, Enum.BuildingType.GOLD } )
                elseif configInfo.playerBehavior == Enum.ActivityActionType.TRAIN_BUILD_LEVEL then
                    count = BuildingLogic:getResBuilding( _rid, { Enum.BuildingType.BARRACKS, Enum.BuildingType.STABLE, Enum.BuildingType.ARCHERYRANGE, Enum.BuildingType.SIEGE } )
                elseif configInfo.playerBehavior == Enum.ActivityActionType.HERO_LEVEL_COUNT then
                    count = HeroLogic:checkHeroLevelCount( _rid, configInfo.data1 )
                end
            end
            if ( _activity[_activityId] and _activity[_activityId].startTime ~= _activityTimeInfo.startTime ) then
                count = 0
            end
            local condition = configInfo.data3
            if sActivityCalendar.activityType == Enum.ActivityType.DROP or sActivityCalendar.activityType == Enum.ActivityType.DROP_RANK or
                sActivityCalendar.activityType == Enum.ActivityType.LUOHA then
                condition = 0
            end
            if not scheduleInfo[configInfo.playerBehavior].data[condition] then
                scheduleInfo[configInfo.playerBehavior].data[condition] = { condition = condition, count = count }
            end
            -- 如果该活动存在排行版并且数量大于0，更新排行版
            if updateRank > 0 and count > 0 then
                -- 计算分数
                if configInfo.integral then count = count *  configInfo.integral end
                local score = (RankLogic:queryOneRecord( _rid, updateRank ) or 0 ) + count
                RankLogic:update( _rid, updateRank, score)
            end
            if updateSonRank > 0 and count > 0 then
                -- 计算分数
                if configInfo.integral then count = count * configInfo.integral end
                local score = (RankLogic:queryOneRecord( _rid, updateSonRank ) or 0 ) + count
                RankLogic:update( _rid, updateSonRank, score)
                _activity[_activityId].score = score
                _activity[_activityId].rank = MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(updateSonRank), true )
            end
        end
        _activity[_activityId].scheduleInfo = scheduleInfo
    end
end

---@see 重置活动信息
function ActivityLogic:activityStartReset( _rid, _activityId, _activity, _activityTimeInfo, _synActivity )
    ActivityLogic:startReset( _rid, _activityId, _activity, _activityTimeInfo, _synActivity )
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(_activityId)
    local prepositionID = 0
    if sActivityCalendar then
        prepositionID = sActivityCalendar.prepositionID
    end
    local activityInfo
    if prepositionID > 0 then
        activityInfo = SM.ActivityMgr.req.getActivityInfo(prepositionID)
    end
    if self:checkActivityTime( _activityId, _activityTimeInfo, _rid ) and prepositionID > 0 and ( not _activity[prepositionID] or _activity[prepositionID].startTime ~= activityInfo.startTime) then
        ActivityLogic:reset( _rid, prepositionID, _activity, activityInfo, _synActivity )
    end
    return _synActivity
end


function ActivityLogic:reset( _rid, _activityId, _activity, _activityTimeInfo, _synActivity )
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(_activityId)
    if not sActivityCalendar then
        _activity[_activityId] = nil
        return
    end
    if sActivityCalendar.activityType == Enum.ActivityType.HELL then
        local townHall = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.TOWNHALL )[1]
        if townHall.level < CFG.s_Config:Get("activityInfernalLevelLimit") then
            return false
        end
    end
    local config = {}
    local updateRank = 0
    local updateSonRank = 0
    local day = 0
    local stage = 0
    local ids = {}
    if sActivityCalendar.activityType == Enum.ActivityType.BASIC_TARGER or sActivityCalendar.activityType == Enum.ActivityType.DAY_RESET
        or sActivityCalendar.activityType == Enum.ActivityType.TARGER_RANK then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_TRAGET_TYPE )[_activityId] or {}
    elseif sActivityCalendar.activityType == Enum.ActivityType.DROP or sActivityCalendar.activityType == Enum.ActivityType.DROP_RANK or
        sActivityCalendar.activityType == Enum.ActivityType.LUOHA then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DROP_TYPE )[_activityId] or {}
    elseif sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[_activityId]
        if sActivityCalendar.timeType == Enum.ActivityTimeType.CREATE_TIME then
            -- 判断时间
            local createTime = RoleLogic:getRole( _rid, Enum.Role.createTime )
            local beginTime = Timer.GetTimeDayX(
                createTime, sActivityCalendar.timeData1 - 1, CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
            day = Timer.getDiffDays( beginTime, os.time() ) + 1
            _activityTimeInfo.startTime = beginTime
            local endTime = Timer.GetTimeDayX(
            beginTime, (sActivityCalendar.durationTime + 1) / 24 / 3600 , CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true ) - 1
            _activityTimeInfo.endTime = endTime
        else
            -- 计算当前时间是第几天
            day = Timer.getDiffDays( _activityTimeInfo.startTime, os.time() ) + 1
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[_activityId]
        -- 计算当前时间是第几天
        local newActivityOpenTime = RoleLogic:getRole( _rid, Enum.Role.newActivityOpenTime )
        _activityTimeInfo.startTime = newActivityOpenTime
        day = Timer.getDiffDays( newActivityOpenTime, os.time() ) + 1
    elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
        local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[_activityId]
        -- 判断今天是第几阶段
        local startTime = _activityTimeInfo.startTime
        for i=1,table.size(configStage) do
            local continueTime = configStage[i].continueTime
            if os.time() >= startTime and os.time() < startTime + continueTime then
                stage = i
                break
            else
                startTime = startTime + continueTime
            end
        end
        if stage > 0 then
            local groupsType = configStage[stage].groupsType
            config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[_activityId][groupsType]
            updateSonRank = configStage[stage].leaderboardID
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_END_SHOW then
        if self:checkActivityTime( _activityId, _activityTimeInfo, _rid ) and ( not _activity[_activityId] or _activity[_activityId].startTime ~= _activityTimeInfo.startTime) then
            _activity[_activityId] = {
                activityId = _activityId,
                scheduleInfo = {},
                startTime = _activityTimeInfo.startTime,
                rewardId = {},
                level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                exchange = {},
                isNew = true,
            }
            local ranks = {}
            local key
            local rank
            local score
            for i=1,5 do
                key = string.format("kill_type_%d", i)
                rank = MSM.RankMgr[_rid].req.getRank( _rid, key, true)
                score = RankLogic:getScore( MSM.RankMgr[_rid].req.queryOneRecord( _rid, key ), Enum.RankType.MGE_TOTAL )
                ranks[i] = { index = i, rank = rank, score = score }
            end
            key = string.format("kill_type_all")
            rank = MSM.RankMgr[_rid].req.getRank( _rid, key, true )
            score = RankLogic:getScore( MSM.RankMgr[_rid].req.queryOneRecord( _rid, key ), Enum.RankType.MGE_TOTAL )
            ranks[6] = { index = 6, rank = rank, score = score }
            _activity[_activityId].ranks = ranks
            _activity[_activityId].score = score
            _activity[_activityId].season = table.size(SM.c_kill_type_history.req.Get()) + 1
            _synActivity[_activityId] = _activity[_activityId]
            return _synActivity
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.HELL then
        local age = BuildingLogic:checkAge( _rid ).age
        for _, id in pairs(_activityTimeInfo.rule[age].ids) do
            local sActivityInfernal = CFG.s_ActivityInfernal:Get(id)
            table.merge( config,CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[_activityId][sActivityInfernal.type])
            table.insert(ids, id)
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.FIGHT_HORN
        or sActivityCalendar.activityType == Enum.ActivityType.TRIBE_KING then
        local sActivityInfernal = CFG.s_ActivityIntegralType:Get(_activityId)
        local firstConfig = table.first(sActivityInfernal).value
        local groupsType = firstConfig.groupsType
        config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[_activityId][groupsType]
    elseif sActivityCalendar.activityType == Enum.ActivityType.TURN_TABLE then
        table.insert(config, { playerBehavior = Enum.ActivityActionType.TURN_TABLE, data3 = 0 })
    end
    if ( not _activity[_activityId] or _activity[_activityId].startTime ~= _activityTimeInfo.startTime ) then
        if sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
            if not _activity[_activityId] then
                _activity[_activityId] = {
                    activityId = _activityId,
                    scheduleInfo = {},
                    startTime = _activityTimeInfo.startTime,
                    rewardId = {},
                    level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                    exchange = {},
                    stage = stage,
                    score = 0,
                    rank = 0,
                    ranks = {},
                    isNew = true,
                }
            elseif _activity[_activityId].startTime > 0 and _activity[_activityId].startTime ~= _activityTimeInfo.startTime then
                _activity[_activityId] = {
                    activityId = _activityId,
                    scheduleInfo = {},
                    startTime = _activityTimeInfo.startTime,
                    rewardId = {},
                    level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                    exchange = {},
                    stage = stage,
                    score = 0,
                    rank = 0,
                    ranks = {},
                    count = 0,
                    dayCount = 0,
                    free = 0,
                    discount = false,
                    isNew = true,
                }
            elseif _activity[_activityId].stage ~= stage then
                _activity[_activityId].scheduleInfo = {}
                _activity[_activityId].rewards = {}
                _activity[_activityId].rank = 0
                _activity[_activityId].score = 0
                _activity[_activityId].stage = stage
            end
        elseif not _activity[_activityId] then
            _activity[_activityId] = {
                activityId = _activityId,
                scheduleInfo = {},
                startTime = _activityTimeInfo.startTime,
                rewardId = {},
                level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                exchange = {},
                stage = stage,
                score = 0,
                rank = 0,
                ids = ids,
                count = 0,
                dayCount = 0,
                free = 0,
                discount = false,
                isNew = true,
            }
        elseif _activity[_activityId].startTime > 0 and _activity[_activityId].startTime ~= _activityTimeInfo.startTime then
            _activity[_activityId] = {
                activityId = _activityId,
                scheduleInfo = {},
                startTime = _activityTimeInfo.startTime,
                rewardId = {},
                level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
                exchange = {},
                stage = stage,
                ids = ids,
                score = 0,
                rank = 0,
                activeReward = false,
                times = 0,
                count = 0,
                dayCount = 0,
                free = 0,
                discount = false,
                isNew = true,
            }
        end
        _synActivity[_activityId] = _activity[_activityId]
        local scheduleInfo = _activity[_activityId].scheduleInfo
        -- if sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN and _activity[_activityId].startTime == _activityTimeInfo.startTime then
        --     scheduleInfo = _activity[_activityId].scheduleInfo
        -- end
        for _, configInfo in pairs(config) do
            if not scheduleInfo[configInfo.playerBehavior] then scheduleInfo[configInfo.playerBehavior] = { type = configInfo.playerBehavior, data = {} } end
            local count = 0
            local condition = configInfo.data3
            if sActivityCalendar.activityType == Enum.ActivityType.DROP or sActivityCalendar.activityType == Enum.ActivityType.DROP_RANK
                or sActivityCalendar.activityType == Enum.ActivityType.LUOHA then
                condition = 0
            end
            if not scheduleInfo[configInfo.playerBehavior].data[condition] then
                scheduleInfo[configInfo.playerBehavior].data[condition] = { condition = condition, count = count }
            end
            -- 如果该活动存在排行版并且数量大于0，更新排行版
            if updateRank > 0 and count > 0 then
                -- 计算分数
                if configInfo.integral then count = count *  configInfo.integral end
                local score = (RankLogic:queryOneRecord( _rid, updateRank ) or 0 ) + count
                RankLogic:update( _rid, updateRank, score)
            end
            if updateSonRank > 0 and count > 0 then
                -- 计算分数
                if configInfo.integral then count = count * configInfo.integral end
                local score = (RankLogic:queryOneRecord( _rid, updateSonRank ) or 0 ) + count
                RankLogic:update( _rid, updateSonRank, score)
                _activity[_activityId].score = score
                _activity[_activityId].rank = MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(updateSonRank), true )
            end
        end
        _activity[_activityId].scheduleInfo = scheduleInfo
    end
end

---@see 地狱活动奖励自动发放
function ActivityLogic:autoAwardHellReward( _rid, _activityId, _isLogin )
    for i=1,3 do
        self:hellReward( _rid, _activityId, nil, i, true, _isLogin )
    end
end

---@see 登录判断活动是否开启
function ActivityLogic:checkActivityOpen( _rid, _isLogin )
    local activityList = SM.ActivityMgr.req.getActivityInfo()
    self:autoAwardHellReward( _rid, 80001, true )
    local activityInfo = RoleLogic:getRole( _rid, Enum.Role.activity )
    local synActiviy = {}
    for activityId, info in pairs(activityList) do
        self:activityStartReset( _rid, activityId, activityInfo, info, synActiviy )
    end
    -- local deleteAcitvity = {}
    -- for activityId in pairs(activityInfo) do
    --     local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
    --     if not sActivityCalendar then
    --         deleteAcitvity[activityId] = activityId
    --     end
    -- end
    -- for activityId in pairs(deleteAcitvity) do
    --     if activityInfo[activityId] then activityInfo[activityId] = nil end
    -- end
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activityInfo } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.activity] = synActiviy }, true )
    end
end

---@see 隔天重置
function ActivityLogic:resetActivity( _rid, _isLogin )
    local activityInfo = RoleLogic:getRole( _rid, Enum.Role.activity )
    local deleteAcitvity = {}
    for activityId, activity in pairs(activityInfo) do
        local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
        if self:checkActivityTime( activityId, nil, _rid ) and sActivityCalendar then
            if sActivityCalendar.activityType == Enum.ActivityType.DAY_RESET then
                for _, scheduleInfo in pairs( activity.scheduleInfo ) do
                    for _, data in pairs(scheduleInfo.data) do
                        data.count = 0
                    end
                end
                activity.rewardId = {}
            elseif sActivityCalendar.activityType == Enum.ActivityType.TURN_TABLE then
                for _, scheduleInfo in pairs( activity.scheduleInfo ) do
                    for _, data in pairs(scheduleInfo.data) do
                        data.count = 0
                    end
                end
                activity.dayCount = 0
                activity.discount = false
            elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
                local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[activityId]
                -- 判断今天是第几阶段
                local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo(activityId)
                local startTime = activityTimeInfo.startTime
                local stage = 0
                for i=1,table.size(configStage) do
                    local continueTime = configStage[i].continueTime
                    if os.time() >= startTime and os.time() <= startTime + continueTime then
                        stage = i
                        break
                    else
                        startTime = startTime + continueTime
                    end
                end
                if stage > activity.stage then
                    activity.stage = stage
                    activity.rank = 0
                    activity.score = 0
                    activity.rewards = {}
                    activity.scheduleInfo = {}
                end
            elseif sActivityCalendar.activityType == Enum.ActivityType.GET_BOX then
                self:autoRewardOpenActivity( _rid, sActivityCalendar, activityInfo, _isLogin )
            elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
                ActivityLogic:autoRewardNewActivity( _rid, activityId, activityInfo, _isLogin )
                activity.activeReward = false
            end
        else
            if sActivityCalendar and sActivityCalendar.activityType == Enum.ActivityType.EXCHANGE then
                self:autoExchange( _rid, activityId, true, _isLogin )
            end
            if sActivityCalendar and sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
                local activityConfig = CFG.s_ActivityCalendar:Get(sActivityCalendar.postpositionID)
                self:autoRewardOpenActivity( _rid, activityConfig, activityInfo, _isLogin )
                if not self:checkActivityTime(sActivityCalendar.postpositionID, nil, _rid ) then
                    self:rewardOpenServer( _rid, sActivityCalendar.postpositionID, true, _isLogin )
                end
            end
            if sActivityCalendar and sActivityCalendar.activityType == Enum.ActivityType.GET_BOX then
                self:autoRewardOpenActivity( _rid, sActivityCalendar, activityInfo, _isLogin )
                self:rewardOpenServer( _rid, activityId, true, _isLogin )
            end
            if sActivityCalendar and sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
                ActivityLogic:autoRewardNewActivity( _rid, activityId, activityInfo, _isLogin )
                activity.activeReward = false
            end
            if activityInfo[activityId] and sActivityCalendar and ( sActivityCalendar.postpositionID <= 0 or sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN )then
                if sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
                    activityInfo[activityId].rank = 0
                    activityInfo[activityId].score = 0
                    activityInfo[activityId].rewards = {}
                    activityInfo[activityId].scheduleInfo = {}
                else
                    deleteAcitvity[activityId] = deleteAcitvity
                end
            end
            local prepositionID = 0
            if sActivityCalendar then
                prepositionID = sActivityCalendar.prepositionID
            end
            if sActivityCalendar and prepositionID > 0 and not self:checkActivityTime( prepositionID, nil, _rid ) then
                deleteAcitvity[sActivityCalendar.prepositionID] = sActivityCalendar.prepositionID
            end
            if not sActivityCalendar then
                deleteAcitvity[activityId] = activityId
            end
        end
    end
    for activityId in pairs(deleteAcitvity) do
        if activityInfo[activityId] then activityInfo[activityId] = nil end
    end
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activityInfo, [Enum.Role.activityActivePoint] = 0 } )
    if not _isLogin then
        RoleSync:syncSelf( _rid, { [Enum.Role.activity] = activityInfo, [Enum.Role.activityActivePoint] = 0 }, true )
    end
end

---@see 活动道具兑换
function ActivityLogic:exchange( _rid, _activityId, _id )
    local sActivityConversionType = CFG.s_ActivityConversionType:Get( _id )
    local activityInfo = RoleLogic:getRole( _rid, Enum.Role.activity )
    for i=1,table.size(sActivityConversionType.conversionItem) do
        ItemLogic:delItemById( _rid, sActivityConversionType.conversionItem[i],
                    sActivityConversionType.num[i], nil, Enum.LogType.ACTIVITY_EXCHANGE_COST_ITEM)
    end
    local activityTime = SM.ActivityMgr.req.getActivityInfo(_activityId)
    if not activityInfo[_activityId] then
        activityInfo[_activityId] = {
            activityId = _activityId,
            startTime = activityTime.startTime,
            level = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.TOWNHALL ),
            exchange = {},
        }
    end
    if not activityInfo[_activityId].exchange[_id] then activityInfo[_activityId].exchange[_id] = { id = _id, count = 0 } end
    activityInfo[_activityId].exchange[_id].count = activityInfo[_activityId].exchange[_id].count + 1
    local rewardInfo = ItemLogic:getItemPackage( _rid, sActivityConversionType.itemPackage )
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activityInfo } )
    --RoleSync:syncSelf( _rid, { [Enum.Role.activity] = { [_activityId] = activityInfo[_activityId] } }, true )
    return { activityId = _activityId, id = _id, count = activityInfo[_activityId].exchange[_id].count, rewardInfo = rewardInfo }
end

---@see 活动道具自动兑换
function ActivityLogic:autoExchange( _rid, _activityId, _flag, _isLogin )
    -- 判断活动是否过期

    if not self:checkActivityTime( _activityId, nil, _rid ) or _flag then
        local configs = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_EXCHANGE_TYPE )[_activityId] or {}
        local itemList = ItemLogic:getItem( _rid ) or {}
        for _, config in pairs(configs) do
            local count = 0
            local deleteItem = {}
            for _, itemInfo in pairs(itemList) do
                if itemInfo.itemId == config.conversionItem then
                    count = count + itemInfo.overlay
                    table.insert(deleteItem, { itemId = itemInfo.itemId, itemNum = count })
                end
            end
            for _, itemInfo in pairs(deleteItem) do
                ItemLogic:delItemById( _rid, itemInfo.itemId, itemInfo.itemNum, _isLogin, Enum.LogType.ACTIVITY_EXCHANGE_COST_ITEM)
            end
            if count > 0 then
                local addCount = math.ceil(count/config.conversionNum)
                local rewardInfo = {}
                for _=1,addCount do
                    local reward = ItemLogic:getItemPackage( _rid, config.itemPackage, true )
                    ItemLogic:mergeReward( rewardInfo, reward)
                end
                local emailContents = {
                    _activityId,
                    config.conversionItem,
                    count,
                    config.conversionItem
                }
                EmailLogic:sendEmail( _rid, config.mailID, { rewards = rewardInfo, emailContents = emailContents, subTitleContents = { config.mailActivity } }, _isLogin )
            end
        end
    end
end

---@see 登录活动道具自动兑换
function ActivityLogic:loginAutoExchange( _rid )
    local activityList = SM.ActivityMgr.req.getActivityInfo()
    local sActivityCalendar
    for activityId in pairs(activityList) do
        sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
        if sActivityCalendar and sActivityCalendar.activityType == Enum.ActivityType.EXCHANGE then
            self:autoExchange( _rid, activityId, nil, true )
        end
    end
end

---@see 发送活动排行榜奖励
function ActivityLogic:sendRankReward( _type ,_activityId, _stage, _realActivityId )
    local key = RankLogic:getKey( _type )
    local rankList = MSM.RankMgr[0].req.queryRank( key, 1, 100, true, true )
    local sActivityRankingType = CFG.s_ActivityRankingType:Get(_activityId)
    if not sActivityRankingType then return end
    local rewardInfo
    local emailContents
    for i, rankInfo in pairs (rankList) do
        local rid = tonumber(rankInfo.member)
        for _, config in pairs(sActivityRankingType) do
            if config.targetMin <= i and config.targetMax >= i then
                if _stage and _stage > 0 then
                    emailContents = { _realActivityId * 1000 + _stage * 100 + 1, i }
                else
                    emailContents = { i }
                end
                rewardInfo = ItemLogic:getItemPackage( rid, config.itemPackage )
                EmailLogic:sendEmail( rid, config.mailID, { rewards = rewardInfo, emailContents = emailContents, takeEnclosure = true } )
            end
        end
    end
    if _stage and _stage < 5 then
        local rids = SM.OnlineMgr.req.getAllOnlineRid()
        local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo( _realActivityId )
        for _, rid in pairs(rids) do
            local activityInfo = RoleLogic:getRole( rid, Enum.Role.activity )
            ActivityLogic:activityStartReset( rid, _realActivityId, activityInfo, activityTimeInfo, {} )
            RoleLogic:setRole( rid, { [Enum.Role.activity] = activityInfo } )
            local synInfo = {}
            synInfo[Enum.Role.activity] = {[_realActivityId] = activityInfo[_realActivityId]}
            RoleSync:syncSelf( rid, synInfo, true )
        end
        local stage = _stage + 1
        local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[_realActivityId]
        local continueTime = configStage[stage].continueTime
        local runTime = os.time() + continueTime
        local timerId = Timer.runAt(runTime, ActivityLogic.sendRankReward, ActivityLogic, configStage[stage].leaderboardID, configStage[stage].subtypeID, stage, _realActivityId )
        SM.ActivityMgr.post.addActivityTimer( stage, timerId )
    end
end

---@see 发送活动联盟排行榜奖励
function ActivityLogic:sendAllianceRankReward( _type ,_activityId )
    local key = RankLogic:getKey( _type )
    local rankList = MSM.RankMgr[0].req.queryRank( key, 1, 100, true, true )
    local sActivityInfernal = CFG.s_ActivityIntegralType:Get(_activityId)
    local firstConfig = table.first(sActivityInfernal).value

    local sActivityRankingType = CFG.s_ActivityRankingType:Get(firstConfig.leaderboardType)
    if not sActivityRankingType then return end
    local rewardInfo
    local emailContents
    local GuildLogic = require "GuildLogic"
    for i, rankInfo in pairs (rankList) do
        local guildId = tonumber(rankInfo.member)
        local members = GuildLogic:getGuild( guildId, Enum.Guild.members ) or {}
        for _, config in pairs(sActivityRankingType) do
            if config.targetMin <= i and config.targetMax >= i then
                for memberRid in pairs( members ) do
                    emailContents = { i }
                    rewardInfo = ItemLogic:getItemPackage( memberRid, config.itemPackage )
                    EmailLogic:sendEmail( memberRid, config.mailID, { rewards = rewardInfo, emailContents = emailContents, takeEnclosure = true } )
                end
            end
        end
    end
end


function ActivityLogic:synReward( _rid, _rewardId, _activityId, _activeReward )
    Common.syncMsg( _rid, "Activity_Reward",  { rid = _rid, rewardId = _rewardId, activityId = _activityId, activeReward = _activeReward } )
end

function ActivityLogic:synRewardBox( _rid, _activityId )
    Common.syncMsg( _rid, "Activity_RewardBox",  { rid = _rid, rewardBox = true, activityId = _activityId } )
end

function ActivityLogic:synScheduleInfo( _rid, _activityId, _type, _condition, _num, _count, _dayCount, _free, _discount )
    Common.syncMsg( _rid, "Activity_ScheduleInfo",  { rid = _rid, activityId = _activityId, type = _type,
                                        condition = _condition, num = _num, count = _count, dayCount = _dayCount,
                                        free = _free, discount = _discount } )
end

function ActivityLogic:synRankInfo( _rid, _activityId, _score, _rank, _allianceRank, _allianceScore, _rewards )
    Common.syncMsg( _rid, "Activity_Rank",  { rid = _rid, activityId = _activityId, score = _score, rank = _rank,
                                    allianceRank = _allianceRank, allianceScore = _allianceScore, rewards = _rewards } )
end


---@see 登陆活动信息推送
function ActivityLogic:sendActivityInfo( _rid )
    local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo()
    for activityId, activityInfo in pairs(activityTimeInfo) do
        local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
        if sActivityCalendar and not table.empty( sActivityCalendar ) and sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
            activityInfo.selfRank = {}
            table.insert( activityInfo.selfRank, MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(Enum.RankType.MGE_TARIN), true ))
            table.insert( activityInfo.selfRank, MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(Enum.RankType.MGE_KILL_BARB), true ))
            table.insert( activityInfo.selfRank, MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(Enum.RankType.MGE_COLLECT_RES), true))
            table.insert( activityInfo.selfRank, MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(Enum.RankType.MGE_POWER_UP), true))
            table.insert( activityInfo.selfRank, MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(Enum.RankType.MGE_KILL), true))
            table.insert( activityInfo.selfRank, MSM.RankMgr[_rid].req.getRank( _rid, RankLogic:getKey(Enum.RankType.MGE_TOTAL), true))
        end
    end
    local newTable = {}
    for activityId, activityInfo in pairs(activityTimeInfo) do
        local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
        if sActivityCalendar and not table.empty( sActivityCalendar ) then
            if sActivityCalendar.activityType == Enum.ActivityType.HELL then
                local townHall = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.TOWNHALL )[1]
                if townHall.level >= CFG.s_Config:Get("activityInfernalLevelLimit") then
                    newTable[activityId] = activityInfo
                end
            elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
                -- 判断时间
                local newActivityOpenTime = RoleLogic:getRole( _rid, Enum.Role.newActivityOpenTime )
                local endTime = Timer.GetTimeDayX(
                    newActivityOpenTime, (sActivityCalendar.durationTime + 1) / 24 / 3600 , CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
                if os.time() <= endTime then
                    activityInfo.startTime = newActivityOpenTime
                    activityInfo.endTime = endTime - 1
                    newTable[activityId] = activityInfo
                end
            elseif sActivityCalendar.timeType == Enum.ActivityTimeType.CREATE_TIME then
                -- 判断时间
                local createTime = RoleLogic:getRole( _rid, Enum.Role.createTime )
                local beginTime = Timer.GetTimeDayX(
                    createTime, sActivityCalendar.timeData1 - 1, CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
                local endTime = Timer.GetTimeDayX(
                    beginTime, (sActivityCalendar.durationTime + 1) / 24 / 3600 , CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
                if os.time() <= endTime then
                    activityInfo.startTime = beginTime
                    activityInfo.endTime = endTime - 1
                    newTable[activityId] = activityInfo
                end
            else
                newTable[activityId] = activityInfo
            end
        end
    end
    return newTable
end

---@see 跨天计算活动进度
function ActivityLogic:resetActivitySchedule( _rid, _isLogin )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.LOGIN_DAY, 1, nil, nil, nil, nil, _isLogin )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_TO_LEVEL, nil, nil, nil, nil, nil, _isLogin )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_TO_LEVEL_COUNT, nil, nil, nil, nil, nil, _isLogin )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.HERO_LEVEL_COUNT, nil, nil, nil, nil, nil, _isLogin )
    local expeditionInfo = RoleLogic:getRole( _rid, Enum.Role.expeditionInfo )
    local maxId = 0
    local sExpedition = CFG.s_Expedition:Get()
    for id in pairs(expeditionInfo) do
        if sExpedition[id] and sExpedition[id].level > maxId then
            maxId = sExpedition[id].level
        end
    end
    if maxId > 0 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.EXPEDITION_LEVEL, maxId, nil, nil, true, nil, _isLogin  )
    end
    self:loginSetActivity( _rid, _isLogin )
end

---@see 登录处理迷雾活动
function ActivityLogic:loginSetActivity( _rid, _isLogin )
    local addNum
    local TaskLogic = require "TaskLogic"
    if RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) then
        -- 迷雾全开, 不需要判断迷雾探索个数
        addNum = 160000
    else
        local taskStatistics = RoleLogic:getRole( _rid, Enum.Role.taskStatisticsSum )
        addNum = TaskLogic:getStatisticsNum( taskStatistics, Enum.TaskType.FOG_EXPLORE )
    end
    -- 迷雾探索
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.SCOUT_MIST, addNum, nil, nil, true, nil, _isLogin  )
    if RoleLogic:getRole( _rid, Enum.Role.guildId ) > 0 then
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.JOIN_ALLIANCE, 1 )
    end
end

---@see 开服活动日志记录
function ActivityLogic:severOpenLog( _rid, _activityId, _actionType, _day, _condition, _num, _oldNum )
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    local config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[_activityId]
    --- 比较特殊的玩家行为
    for _, v in pairs(config) do
        local saveLog = false
        if _actionType == v.playerBehavior and _condition == v.data3 and v.day <= _day then
            if _num >= v.data0 and _oldNum < v.data0 then
                saveLog = true
            end
        end
        if saveLog then
            LogLogic:roleActivityDaysType( {
                 rid = _rid, iggid = iggid, id = v.ID
            } )
        end
    end
end

---@see 创角活动日志
function ActivityLogic:severNewActivityLog( _rid, _activityId, _actionType, _day, _condition, _num, _oldNum )
    local iggid = RoleLogic:getRole( _rid, Enum.Role.iggid )
    local config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[_activityId]
    --- 比较特殊的玩家行为
    for _, v in pairs(config) do
        local saveLog = false
        if _actionType == v.playerBehavior and _condition == v.data3 and v.day == _day then
            if _num >= v.data0 and _oldNum < v.data0 then
                saveLog = true
            end
        end
        if saveLog then
            LogLogic:roleNewActivityDaysType( {
                 rid = _rid, iggid = iggid, id = v.ID
            } )
        end
    end
end

---@see 地狱活动日志记录
function ActivityLogic:hellLog( _rid, _activityId, _num, _oldNum )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.iggid, Enum.Role.activity } )
    local activityInfo = roleInfo.activity[_activityId] or {}
    local order
    local orderConfig
    for _, id in pairs(activityInfo.ids or {}) do
        local config = CFG.s_ActivityInfernal:Get(id)
        if not order or config.order > order then
            order = config.order
            orderConfig = config
        end
    end
    --- 比较特殊的玩家行为
    for index, score in pairs( orderConfig.score ) do
        local saveLog = false
        if _num >= score and _oldNum < score then
            saveLog = true
        end
        if saveLog then
            LogLogic:roleActivityInfernal( {
                    rid = _rid, iggid = roleInfo.iggid, id = orderConfig.ID, stage = index,
            } )
        end
    end
end

---@see 领取活动奖励
function ActivityLogic:receiveActivityReward( _rid, _activityId, _id, _noAdd, _activity, _isLogin )
    local config = CFG.s_ActivityNewPlayer:Get(_id)
    local activity = _activity or RoleLogic:getRole( _rid, Enum.Role.activity )
    if not activity or not activity[_activityId] then return end
    if activity and activity[_activityId] and activity[_activityId].activeReward then
        LOG_ERROR("rid(%d) ReceiveReward error, this reward is awarded ", _rid )
        return nil, ErrorCode.ACTIVITY_AWARDED
    end
    local activityActivePoint = RoleLogic:getRole( _rid, Enum.Role.activityActivePoint )
    if activityActivePoint < config.standard then
        --LOG_ERROR("rid(%d) ReceiveReward error, can't award this reward ", _rid )
        return nil, ErrorCode.ACTIVITY_CAN_NOT_AWARD
    end
    if not activity[_activityId].activeReward then activity[_activityId].activeReward = true end
    --local synActiviy = {}
    --synActiviy[_activityId] = activity[_activityId]
    RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
    if not _noAdd then
        self:synReward( _rid, nil, _activityId, true )
    else
        local rewardInfo = ItemLogic:getItemPackage( _rid, config.itemPackage )
        EmailLogic:sendEmail( _rid, config.mailId, { takeEnclosure = true, rewards = rewardInfo, emailContents = { _activityId }, subTitleContents = { _activityId, config.day } }, _isLogin )
        return true
    end
    --RoleSync:syncSelf( _rid, { [Enum.Role.activity] = synActiviy }, true )
    return { rewardInfo = ItemLogic:getItemPackage( _rid, config.itemPackage, nil, _isLogin ), activityId = _activityId, id = _id }
    -- if config.specialItem and config.specialItem > 0 then
    --     ItemLogic:getItemPackage( _rid, config.specialItem )
    -- end
end

---@see 自动领取新手活动
function ActivityLogic:autoRewardNewActivity( _rid, _activityId, _activityInfo, _isLogin )
    local sActivityNewPlayer = CFG.s_ActivityNewPlayer:Get()
    -- 判断天数
    local activityDays = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS )[_activityId]
    local day = 0
    local newActivityOpenTime = RoleLogic:getRole( _rid, Enum.Role.newActivityOpenTime )
    local nowDay = Timer.getDiffDays( newActivityOpenTime, os.time() ) + 1
    if nowDay == 1 then return end
    for _, activityNewPlayer in pairs(sActivityNewPlayer) do
        if activityNewPlayer.day > day then
            day = activityNewPlayer.day
        end
    end
    if nowDay - day >= 2 then
        return
    end
    for i = 1, nowDay - 1 do
        local configs = activityDays[i]
        for _, config in pairs(configs) do
            self:receiveReward( _rid, _activityId, config.ID, true, _activityInfo, _isLogin )
        end
    end
    local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
    local activeDay = 0
    if activity[_activityId] and activity[_activityId].day then
        activeDay = activity[_activityId].day
    end
    for _, activityNewPlayer in pairs(sActivityNewPlayer) do
        if activityNewPlayer.day == activeDay then
            ActivityLogic:receiveActivityReward( _rid, _activityId, activityNewPlayer.ID, true, _activityInfo, _isLogin )
        end
    end
end

---@see 登陆删除地狱活动信息
function ActivityLogic:resetHall( _rid )
    local activity = RoleLogic:getRole( _rid, Enum.Role.activity )
    if activity[80001] and activity[80001].level < CFG.s_Config:Get("activityInfernalLevelLimit") then
        activity[80001] = nil
        RoleLogic:setRole( _rid, { [Enum.Role.activity] = activity } )
    end
end

return ActivityLogic