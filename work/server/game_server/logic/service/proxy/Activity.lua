--[[
* @file : Activity.lua
* @type : snax multi service
* @author : chenlei
* @created : Fri Apr 17 2020 17:05:38 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 活动协议管理
* Copyright(C) 2017 IGG, All rights reserved
]]
local ActivityLogic = require "ActivityLogic"
local RoleLogic = require "RoleLogic"
local ItemLogic = require "ItemLogic"
local GuildLogic = require "GuildLogic"
local Timer = require "Timer"
local RankLogic = require "RankLogic"
local BuildingLogic = require "BuildingLogic"

---@see 领取奖励
function response.ReceiveReward( msg )
    local rid = msg.rid
    local id = msg.id
    local activityId = msg.activityId
    local index = msg.index
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
    local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo( activityId )
    -- 判断是否在活动时间内
    if not ActivityLogic:checkActivityTime( activityId, activityTimeInfo, rid ) then
        LOG_ERROR("rid(%d) ReceiveReward error, activity time out ", rid )
        return nil, ErrorCode.ACTIVITY_TIME_OUT
    end
    -- 如果是开服活动，判断天数是否正确
    if sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
        local day
        if sActivityCalendar.timeType == Enum.ActivityTimeType.CREATE_TIME then
            local createTime = RoleLogic:getRole( rid, Enum.Role.createTime )
            local beginTime = Timer.GetTimeDayX(
                createTime, sActivityCalendar.timeData1 - 1, CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
            day = Timer.getDiffDays( beginTime, os.time() ) + 1
        else
            day = Timer.getDiffDays( activityTimeInfo.startTime, os.time() ) + 1
        end
        local sActivityDaysType = CFG.s_ActivityDaysType:Get(id)
        if day < sActivityDaysType.day then
            LOG_ERROR("rid(%d) ReceiveReward error, day error ", rid )
            return nil, ErrorCode.ACTIVITY_DAY_ERROR
        end
    elseif sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
        local newActivityOpenTime = RoleLogic:getRole( rid, Enum.Role.newActivityOpenTime )
        local day = Timer.getDiffDays( newActivityOpenTime, os.time() ) + 1
        local sActivityDaysType = CFG.s_ActivityDaysType:Get(id)
        if day < sActivityDaysType.day then
            LOG_ERROR("rid(%d) ReceiveReward error, day error ", rid )
            return nil, ErrorCode.ACTIVITY_DAY_ERROR
        end
    end
    -- 如果已经领取过，返回
    local activity = RoleLogic:getRole( rid, Enum.Role.activity )
    if sActivityCalendar.activityType == Enum.ActivityType.GET_BOX then
        return ActivityLogic:rewardOpenServer( rid, activityId )
    elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
        return ActivityLogic:killTypeReward( rid, activityId, id, index )
    elseif sActivityCalendar.activityType == Enum.ActivityType.HELL then
        return ActivityLogic:hellReward( rid, activityId, id, index )
    else
        if activity and activity[activityId] and table.exist(activity[activityId].rewardId, id) then
            LOG_ERROR("rid(%d) ReceiveReward error, this reward is awarded ", rid )
            return nil, ErrorCode.ACTIVITY_AWARDED
        end
    end
    return ActivityLogic:receiveReward( rid, activityId, id )
end

---@see 兑换道具
function response.Exchange( msg )
    local rid = msg.rid
    local id = msg.id
    local activityId = msg.activityId
    -- 判断是否在活动时间内
    if not ActivityLogic:checkActivityTime( activityId, nil, rid ) then
        LOG_ERROR("rid(%d) Exchange error, activity time out ", rid )
        return nil, ErrorCode.ACTIVITY_TIME_OUT
    end
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
    if not sActivityCalendar.activityType == Enum.ActivityType.EXCHANGE then
        LOG_ERROR("rid(%d) Exchange error, activity type out", rid )
        return nil, ErrorCode.ACTIVITY_TYPE_ERROR
    end
    -- 领取是否达到上限
    local activity = RoleLogic:getRole( rid, Enum.Role.activity )
    local sActivityConversionType = CFG.s_ActivityConversionType:Get( id )
    if activity[activityId] and activity[activityId].exchange and activity[activityId].exchange[id]
            and activity[activityId].exchange[id].count >= sActivityConversionType.timeLimit then
        LOG_ERROR("rid(%d) Exchange error, activity exchange num max ", rid )
        return nil, ErrorCode.ACTIVITY_EXCHANGE_TIME_MAX
    end
    -- 道具是否充足
    for i=1,table.size(sActivityConversionType.conversionItem) do
        if not ItemLogic:checkItemEnough( rid, sActivityConversionType.conversionItem[i],
            sActivityConversionType.num[i]) then
            LOG_ERROR("rid(%d) ReceiveReward error, item no error", rid )
            return nil, ErrorCode.ITEM_NOT_ENOUGH
        end
    end
    -- vip等级
    local vip = RoleLogic:getRole( rid, Enum.Role.vip )
    if RoleLogic:getVipLv(vip) < sActivityConversionType.vipLimit then
        LOG_ERROR("rid(%d) ReceiveReward error, item no error", rid )
        return nil, ErrorCode.ROLE_VIP_NOT_ENOUGH
    end
    return ActivityLogic:exchange( rid, activityId, id )
end

---@see 获取历届
function response.GetHistoryRank( msg )
    local list = SM.c_kill_type_history.req.Get()
    local rankList = {}
    for index, info in pairs( list ) do
        rankList[index] = { index = index, historyInfo = info.historyInfo, time = info.time }
    end
    return { rankList = rankList }
end

---@see 获取活动列表
function response.GetRank( msg )
    local rid = msg.rid
    local type = msg.type
    local activityId = msg.activityId
    local rankList = {}
    local selfRank = {}
    if type == Enum.ActivityType.MEG_MAIN then
        local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[activityId]
        -- 判断今天是第几阶段
        local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo(activityId)
        local startTime = activityTimeInfo.startTime
        local stage = 5
        for i=1,table.size(configStage) do
            local continueTime = configStage[i].continueTime
            if os.time() >= startTime and os.time() <= startTime + continueTime then
                stage = i
                break
            else
                startTime = startTime + continueTime
            end
        end
        for i=1,stage do
            local ranks = {}
            local key = string.format("kill_type_%d", i)
            local rankInfos = MSM.RankMgr[rid].req.queryRank( key, 1, 10, true )
            for j, rankInfo in pairs( rankInfos ) do
                local member = tonumber(rankInfo.member)
                local score = RankLogic:getScore( tonumber(rankInfo.score), Enum.RankType.MGE_TOTAL )
                local abbreviationName
                local guildName
                local role = RoleLogic:getRole( member, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headFrameID, Enum.Role.headId })
                if role.guildId then
                    local guildInfo = GuildLogic:getGuildInfo( role.guildId )
                    abbreviationName = guildInfo.abbreviationName
                    guildName = guildInfo.name
                end
                table.insert( ranks, { rid  = member , score = score, headFrameID = role.headFrameID, name = role.name, index = j,
                                            abbreviationName = abbreviationName, guildName = guildName, oldRank = rankInfo.oldRank, headId = role.headId } )
            end
            local rank = MSM.RankMgr[rid].req.getRank( rid, key, true)
            local activity = RoleLogic:getRole( rid, Enum.Role.activity )
            local score = 0
            if activity[activityId] and activity[activityId].ranks and activity[activityId].ranks[i] then
                score = activity[activityId].ranks[i].score or 0
            end
            rankList[i] = { index = i, ranks = ranks }
            selfRank[i] = { index = i, rank = rank, score = score }
        end
    end
    return { rankList = rankList, selfRank = selfRank }
end

---@see 获取个人分数以及信息
function response.GetSelfRank( msg )
    local activityId = msg.activityId
    local rid = msg.rid
    local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo(activityId)
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
    local activityInfo = RoleLogic:getRole( rid, Enum.Role.activity )
    local rankOfAlliance = 0
    local allianceScore = 0
    local noCheck = false
    if sActivityCalendar.postpositionID > 0 then
        local postConfig = CFG.s_ActivityCalendar:Get(sActivityCalendar.postpositionID)
        if postConfig.timeType == Enum.ActivityTimeType.PRE_ACTIVITY then
            noCheck = true
        end
    end
    if noCheck or ActivityLogic:checkActivityTime( activityId, activityTimeInfo, rid ) then
        local config = {}
        local updateSonRank = 0
        local updateRank = 0
        local day
        local maxScore
        if sActivityCalendar.activityType == Enum.ActivityType.BASIC_TARGER or sActivityCalendar.activityType == Enum.ActivityType.DAY_RESET
            or sActivityCalendar.activityType == Enum.ActivityType.TARGER_RANK then
            config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_TRAGET_TYPE )[activityId] or {}
        elseif sActivityCalendar.activityType == Enum.ActivityType.DROP or sActivityCalendar.activityType == Enum.ActivityType.DROP_RANK or
            sActivityCalendar.activityType == Enum.ActivityType.LUOHA then
            config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DROP_TYPE )[activityId] or {}
        elseif sActivityCalendar.activityType == Enum.ActivityType.SERVER_OPEN then
            config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_DAYS_TYPE )[activityId]
            -- 计算当前时间是第几天
            day = Timer.getDiffDays( activityTimeInfo.startTime, os.time() ) + 1
        elseif sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
            local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[activityId]
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
            if stage > 0 then
                local groupsType = configStage[stage].groupsType
                config = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_INT)[activityId][groupsType]
                updateSonRank = configStage[stage].leaderboardID
            end
        elseif sActivityCalendar.activityType == Enum.ActivityType.HELL and activityTimeInfo then
            local age = BuildingLogic:checkAge( rid, activityInfo[activityId].level ).age
            for _, id in pairs(activityInfo[activityId].ids) do
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
        elseif sActivityCalendar.activityType == Enum.ActivityType.TRIBE_KING or sActivityCalendar.activityType == Enum.ActivityType.FIGHT_HORN then
            local allianceRank = sActivityCalendar.allianceleaderboard
            if sActivityCalendar.leaderboard > 0 then
                updateRank = sActivityCalendar.leaderboard
            end
            local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
            if guildId > 0 then
                rankOfAlliance = RankLogic:getRank( guildId, allianceRank, true ) or 0
                allianceScore = RankLogic:queryOneRecord( guildId, allianceRank ) or 0
            end
        end
        if sActivityCalendar.leaderboard > 0 and sActivityCalendar.activityType ~= Enum.ActivityType.HELL and
        sActivityCalendar.activityType ~= Enum.ActivityType.MEG_END_SHOW and sActivityCalendar.activityType ~= Enum.ActivityType.TARGER_RANK_END
        and sActivityCalendar.activityType ~= Enum.ActivityType.DROP_RANK_END then
            updateRank = sActivityCalendar.leaderboard
        end
        local rank = 0
        if updateRank > 0 then
            rank = RankLogic:getRank( rid, updateRank, true ) or 0
        end
        local rewards = activityInfo[activityId].rewards
        ActivityLogic:synRankInfo( rid, activityId, activityInfo[activityId].score, rank, rankOfAlliance, allianceScore, rewards )
    end
end

---@see 领取奖励
function response.ReceiveActiveReward( msg )
    local rid = msg.rid
    local id = msg.id
    local activityId = msg.activityId
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
    local activityTimeInfo = SM.ActivityMgr.req.getActivityInfo( activityId )
    -- 判断是否在活动时间内
    if not ActivityLogic:checkActivityTime( activityId, activityTimeInfo, rid ) then
        LOG_ERROR("rid(%d) ReceiveReward error, activity time out ", rid )
        return nil, ErrorCode.ACTIVITY_TIME_OUT
    end
    if sActivityCalendar.activityType == Enum.ActivityType.NEW_ACTIVITY then
        local newActivityOpenTime = RoleLogic:getRole( rid, Enum.Role.newActivityOpenTime )
        local day = Timer.getDiffDays( newActivityOpenTime, os.time() ) + 1
        local sActivityNewPlayer = CFG.s_ActivityNewPlayer:Get(id)
        if day < sActivityNewPlayer.day then
            LOG_ERROR("rid(%d) ReceiveActiveReward error, day error ", rid )
            return nil, ErrorCode.ACTIVITY_DAY_ERROR
        end
    end
    -- 如果已经领取过，返回
    local activity = RoleLogic:getRole( rid, Enum.Role.activity )
    if activity and activity[activityId] and activity[activityId].activeReward then
        LOG_ERROR("rid(%d) ReceiveReward error, this reward is awarded ", rid )
        return nil, ErrorCode.ACTIVITY_AWARDED
    end
    return ActivityLogic:receiveActivityReward( rid, activityId, id )
end

---@see 转盘抽奖
function response.TurnTable( msg )
    local activityId = msg.activityId
    local type = msg.type
    local free = msg.free
    local discount = msg.discount
    local rid = msg.rid
    -- 判断活动是否开启
    if not ActivityLogic:checkActivityTime( activityId, nil, rid ) then
        LOG_ERROR("rid(%d) TurnTable error, turnTable not open ", rid )
        return nil, ErrorCode.ACTIVITY_TIME_OUT
    end
    -- 判断等级是否达到
    local level = BuildingLogic:getBuildingLv( rid, Enum.BuildingType.TOWNHALL )
    local needLevel = CFG.s_Config:Get("turntableLev")
    if level < needLevel then
        LOG_ERROR("rid(%d) TurnTable error, townHall level(%d) not enough (%)", rid, level, needLevel )
        return nil, ErrorCode.ACTIVITY_LEVEL_NOT_ENOUGH
    end
    local activity = RoleLogic:getRole( rid, Enum.Role.activity )
    local sTurnTableDraw = CFG.s_TurntableDraw:Get(type)
    local count = sTurnTableDraw.fornum
    -- if (free or discount) and count == 1 then
    --     count = 1
    -- end
    -- 每日抽奖次数是否达到上限
    local turntableDrawParam = CFG.s_Config:Get("turntableDrawParam")

    if free then
        if activity[activityId] and activity[activityId].free
        and activity[activityId].free + count > turntableDrawParam[1] then
            LOG_ERROR("rid(%d) TurnTable error, today free count max", rid )
            return nil, ErrorCode.ACTIVITY_FREE_COUNT_MAX
        end
    end

    if discount then
        if activity[activityId] and activity[activityId].discount then
            LOG_ERROR("rid(%d) TurnTable error, today discount count max", rid )
            return nil, ErrorCode.ACTIVITY_DISCOUNT_COUNT_MAX
        end
    end

    if not free and not discount then
        if activity[activityId] and activity[activityId].dayCount
            and activity[activityId].dayCount + count > turntableDrawParam[2] then
            LOG_ERROR("rid(%d) TurnTable error, today count max", rid )
            return nil, ErrorCode.ACTIVITY_DAY_COUNT_MAX
        end
    end

    local costDenar = sTurnTableDraw.Cost
    if free and count == 1 then
        costDenar = 0
    elseif discount then
        if sTurnTableDraw.Cost_firt_discount > 0 then
            costDenar = math.floor( costDenar * sTurnTableDraw.Cost_firt_discount / 100 )
        end
    end
    -- 判断钻石是否充足
    if costDenar > 0 and not RoleLogic:checkDenar( rid, costDenar ) then
        LOG_ERROR("rid(%d) TurnTable error, denar not enough ", rid )
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end
    -- 扣除钻石
    RoleLogic:addDenar( rid, -costDenar, nil, Enum.LogType.TURN_TABLE_COST_DENAR )

    local groupIds = {}
    local newCount = count
    if not activity[activityId].count or activity[activityId].count == 0 then
        newCount = newCount - 1
        activity[activityId].count = (activity[activityId].count or 0) + 1
        table.insert( groupIds, sTurnTableDraw.safety_first)
    end
    local turntableSafetynum = CFG.s_Config:Get("turntableSafetynum")

    for _ = 1, newCount do
        activity[activityId].count = activity[activityId].count + 1
        if activity[activityId].count / turntableSafetynum[1] == 0 then
            table.insert( groupIds, turntableSafetynum[2])
        else
            table.insert( groupIds, sTurnTableDraw.itempack)
        end
    end
    -- 设置进度
    if count == 0 then count = 1 end
    MSM.ActivityRoleMgr[rid].req.setActivitySchedule( rid, Enum.ActivityActionType.TURN_TABLE,
                            count, nil, nil, nil, nil, nil, nil, free, discount )
    -- 发放奖励
    local finalReward = {}
    local packageIds = {}
    local sTurntableDrawRange = CFG.s_TurntableDrawRange:Get()
    for _, groupId in pairs(groupIds) do
        if groupId and groupId > 0 then
            local rewardInfo, packageId = ItemLogic:getItemPackage( rid, groupId )
            if not sTurntableDrawRange[packageId] then
                table.insert(packageIds, packageId)
            else
                table.insert(packageIds, sTurntableDrawRange[packageId].Escape)
            end
            ItemLogic:mergeReward(finalReward, rewardInfo)
        end
    end
    return { rewardInfo = finalReward, packageIds = packageIds, activityId = activityId }
end

---@see 转盘领取进度
function response.TurnReward( msg )
    local activityId = msg.activityId
    local id = msg.id
    local rid = msg.rid
    local sTurntableDrawProgress = CFG.s_TurntableDrawProgress:Get(id)
    if not ActivityLogic:checkActivityTime( activityId, nil, rid ) then
        LOG_ERROR("rid(%d) TurnReward error, turnTable not open ", rid )
        return nil, ErrorCode.ACTIVITY_TIME_OUT
    end
    -- 判断等级是否达到
    local level = BuildingLogic:getBuildingLv( rid, Enum.BuildingType.TOWNHALL )
    local needLevel = CFG.s_Config:Get("turntableLev")
    if level < needLevel then
        LOG_ERROR("rid(%d) TurnReward error, townHall level(%d) not enough (%)", rid, level, needLevel )
        return nil, ErrorCode.ACTIVITY_LEVEL_NOT_ENOUGH
    end
    local activity = RoleLogic:getRole( rid, Enum.Role.activity )
    if not activity[activityId] or not activity[activityId].count or activity[activityId].count < sTurntableDrawProgress.reach then
        LOG_ERROR("rid(%d) TurnReward error, turn count not enough", rid, level, needLevel )
        return nil, ErrorCode.ACTIVITY_TURN_COUNT_NOT_ENOUGH
    end
    if activity and activity[activityId] and table.exist(activity[activityId].rewardId, id) then
        LOG_ERROR("rid(%d) TurnReward error, this reward is awarded ", rid )
        return nil, ErrorCode.ACTIVITY_AWARDED
    end
    if not activity[activityId].rewardId then activity[activityId].rewardId = {} end
    table.insert( activity[activityId].rewardId, id )
    RoleLogic:setRole( rid, { [Enum.Role.activity] = activity } )
    ActivityLogic:synReward( rid, id, activityId )
    return { rewardInfo = ItemLogic:getItemPackage( rid, sTurntableDrawProgress.itempack), activityId = activityId, id = id }
end

---@see 点击活动
function response.ClickActivity( msg )
    local activityId = msg.activityId
    local rid = msg.rid
    local activity = RoleLogic:getRole( rid, Enum.Role.activity )
    if activity[activityId] then
        activity[activityId].isNew = false
        RoleLogic:setRole( rid, { [Enum.Role.activity] = activity } )
    end
    return { activityId = activityId }
end