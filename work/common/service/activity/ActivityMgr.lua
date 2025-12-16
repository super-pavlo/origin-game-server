--[[
* @file : ActivityMgr.lua
* @type : snax single service
* @author : chenlei
* @created : Tue Apr 07 2020 13:31:35 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 活动管理
* Copyright(C) 2017 IGG, All rights reserved
]]
local Timer = require "Timer"
local RoleSync = require "RoleSync"
local RoleLogic = require "RoleLogic"
local ActivityLogic = require "ActivityLogic"
local RankLogic = require "RankLogic"
local GuildLogic = require "GuildLogic"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local ItemLogic = require "ItemLogic"
local EmailLogic = require "EmailLogic"
local BuildingLogic = require "BuildingLogic"

local ActivityEndTimer = {}
local ActivityStartTimer = {}

local ActivityInfo = {}
local setActivityTime

function init()
	snax.enablecluster()
	cluster.register(SERVICE_NAME)
end

---@see 检查副本当天是否开放
---@param _dungeoId integer @副本ID
---@return boolean @true为开放,false为未开放
local function checkWeek( _time )
    local dayTime = { year = 1970, month = 1, day = 1, hour = 0, min = 0, sec = 0 }
    local openTime = os.time(dayTime)
    local now = _time or os.time()
    local diffWeek = ( Timer.getDiffWeeks( openTime, now ) + 1 ) % 2
    return diffWeek
end

local function resetRank( _sActivityCalendar, _time, _clean )
    if (not _sActivityCalendar.leaderboard or _sActivityCalendar.leaderboard <= 0)
        and (not _sActivityCalendar.allianceleaderboard or _sActivityCalendar.allianceleaderboard <= 0) then
        return
    end
    -- 最强执政官要另外处理
    if _sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
        ActivityLogic:sendRankReward( Enum.RankType.MGE_TOTAL ,_sActivityCalendar.ID )
    elseif _sActivityCalendar.activityType == Enum.ActivityType.MEG_END_SHOW then
        -- 存入历史执政官信息
        local key = RankLogic:getKey( _sActivityCalendar.leaderboard )
        local rankList = MSM.RankMgr[0].req.queryRank( key, 1, 10, true )
        local list = SM.c_kill_type_history.req.Get()
        local index = table.size(list) + 1
        local historyInfo = {}
        for i, rankInfo in pairs( rankList ) do
            local member = tonumber(rankInfo.member)
            local score = RankLogic:getScore( tonumber(rankInfo.score), _sActivityCalendar.leaderboard )
            local roleInfo = RoleLogic:getRole( member, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headFrameID, Enum.Role.headId })
            local abbreviationName = ""
            if roleInfo.guildId then
                local guildInfo = GuildLogic:getGuildInfo( roleInfo.guildId )
                abbreviationName = guildInfo.abbreviationName
            end
            table.insert( historyInfo, {score = score, name = roleInfo.name, rank = i, abbreviationName = abbreviationName} )
        end
        if _clean then
            -- local t = Timer.GetTimeDayX(
            --     ActivityInfo[_sActivityCalendar.ID].startTime, -5 , CFG.s_Config:Get("systemDayTime") or 0, 0, 0, true )
            SM.c_kill_type_history.req.Add( index, { historyInfo = historyInfo, time = _time })
            MSM.RankMgr[0].post.deleteKey( RankLogic:getKey( _sActivityCalendar.leaderboard))
            MSM.RankMgr[0].post.deleteKey( RankLogic:getKey( Enum.RankType.MGE_POWER_UP))
            MSM.RankMgr[0].post.deleteKey( RankLogic:getKey( Enum.RankType.MGE_TARIN))
            MSM.RankMgr[0].post.deleteKey( RankLogic:getKey( Enum.RankType.MGE_KILL_BARB))
            MSM.RankMgr[0].post.deleteKey( RankLogic:getKey( Enum.RankType.MGE_COLLECT_RES))
            MSM.RankMgr[0].post.deleteKey( RankLogic:getKey( Enum.RankType.MGE_KILL))
        end
    elseif _sActivityCalendar.activityType == Enum.ActivityType.FIGHT_HORN or _sActivityCalendar.activityType == Enum.ActivityType.TRIBE_KING then
        if _clean then
            if _sActivityCalendar.leaderboard and _sActivityCalendar.leaderboard > 0 then
                MSM.RankMgr[0].post.deleteKey(RankLogic:getKey(_sActivityCalendar.leaderboard))
            end
            if _sActivityCalendar.allianceleaderboard and _sActivityCalendar.allianceleaderboard > 0 then
                MSM.RankMgr[0].post.deleteKey(RankLogic:getKey(_sActivityCalendar.allianceleaderboard))
            end
        end
        if _sActivityCalendar.leaderboard and _sActivityCalendar.leaderboard > 0 then
            ActivityLogic:sendRankReward( _sActivityCalendar.leaderboard, _sActivityCalendar.ID )
        end
        if _sActivityCalendar.allianceleaderboard and _sActivityCalendar.allianceleaderboard > 0 then
            ActivityLogic:sendAllianceRankReward( _sActivityCalendar.allianceleaderboard, _sActivityCalendar.ID )
        end
    else
        if _clean then
            if _sActivityCalendar.leaderboard and _sActivityCalendar.leaderboard > 0 then
                MSM.RankMgr[0].post.deleteKey(RankLogic:getKey(_sActivityCalendar.leaderboard))
            end
            if _sActivityCalendar.allianceleaderboard and _sActivityCalendar.allianceleaderboard > 0 then
                MSM.RankMgr[0].post.deleteKey(RankLogic:getKey(_sActivityCalendar.allianceleaderboard))
            end
        end
        if _sActivityCalendar.leaderboard and _sActivityCalendar.leaderboard > 0 then
            ActivityLogic:sendRankReward( _sActivityCalendar.leaderboard, _sActivityCalendar.ID )
        end
        if _sActivityCalendar.allianceleaderboard and _sActivityCalendar.allianceleaderboard > 0 then
            ActivityLogic:sendAllianceRankReward( _sActivityCalendar.allianceleaderboard, _sActivityCalendar.ID )
        end
    end
end

local function endTime( _activityId, _clean, _time )
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(_activityId)
    local rids = SM.OnlineMgr.req.getAllOnlineRid()
    if _clean then
        for _, rid in pairs(rids) do
            if sActivityCalendar.activityType == Enum.ActivityType.EXCHANGE then
                ActivityLogic:autoExchange( rid, _activityId, true )
            end
            if sActivityCalendar.activityType == Enum.ActivityType.GET_BOX then
                ActivityLogic:rewardOpenServer( rid, _activityId, true )
            end
            local activityInfo = RoleLogic:getRole( rid, Enum.Role.activity ) or {}
            local synActivityInfo = {}
            if activityInfo[_activityId] then
                activityInfo[_activityId] = nil
                synActivityInfo[_activityId] = { activityId = _activityId }
            end
            if sActivityCalendar.prepositionID > 0 then
                activityInfo[sActivityCalendar.prepositionID] = nil
                synActivityInfo[sActivityCalendar.prepositionID] = { activityId = sActivityCalendar.prepositionID }
            end
            RoleLogic:setRole( rid, { [Enum.Role.activity] = activityInfo } )
            RoleSync:syncSelf( rid, { [Enum.Role.activity] = synActivityInfo }, true )
        end
    end
    -- 如果有排行版重置排行版信息
    resetRank( sActivityCalendar, _time, _clean )
    if sActivityCalendar.timeType == Enum.ActivityTimeType.PRE_ACTIVITY then
        setActivityTime(sActivityCalendar)
    elseif sActivityCalendar.postpositionID > 0 then
        local postConfig = CFG.s_ActivityCalendar:Get(sActivityCalendar.postpositionID)
        if postConfig.timeType == Enum.ActivityTimeType.PRE_ACTIVITY then
            setActivityTime(postConfig)
        end
    end
end

local function startActivity( _activityTimeInfo )
    local activityId = _activityTimeInfo.activityId
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(activityId)
    if sActivityCalendar.activityType == Enum.ActivityTimeType.FOREVER then
        return
    end
    local rids = SM.OnlineMgr.req.getAllOnlineRid()
    if sActivityCalendar.activityType ~= Enum.ActivityType.MEG_NOTICE then
        for _, rid in pairs(rids) do
            local synInfo = {}
            if sActivityCalendar.activityType == Enum.ActivityType.GET_BOX then
                ActivityLogic:autoRewardOpenActivity( rid, sActivityCalendar )
            end
            local activityInfo = RoleLogic:getRole( rid, Enum.Role.activity )
            ActivityLogic:activityStartReset( rid, activityId, activityInfo, _activityTimeInfo, {} )
            RoleLogic:setRole( rid, { [Enum.Role.activity] = activityInfo } )
            synInfo[Enum.Role.activity] = {[activityId] = activityInfo[activityId]}
            -- 推送活动信息
            synInfo[Enum.Role.activityTimeInfo] = { [activityId] = _activityTimeInfo }
            RoleSync:syncSelf( rid, synInfo, true )
        end
    end
    --有后置活动，等后置活动一起清理
    local clean = false
    if sActivityCalendar.postpositionID == 0 then
        clean = true
    end
    if ActivityEndTimer[activityId] then
        Timer.delete(ActivityEndTimer[activityId])
    end
    -- 加入定时器
    local time
    if sActivityCalendar.prepositionID and sActivityCalendar.prepositionID > 0 and ActivityInfo[sActivityCalendar.prepositionID] then
        time = ActivityInfo[sActivityCalendar.prepositionID].startTime
    end
    ActivityEndTimer[activityId] = Timer.runAt(_activityTimeInfo.endTime, endTime, activityId, clean, time )
    if sActivityCalendar.activityType == Enum.ActivityType.MEG_MAIN then
        local configStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.ACTIVITY_KILL_STAGE)[activityId]
        -- 判断今天是第几阶段
        local startTime = _activityTimeInfo.startTime
        local stage = 0
        local runTime = 0
        for i=1,table.size(configStage) do
            local continueTime = configStage[i].continueTime
            if os.time() >= startTime and os.time() <= startTime + continueTime then
                stage = i
                runTime = startTime + continueTime
                break
            else
                startTime = startTime + continueTime
            end
        end
        if stage > 0 then
            if ActivityEndTimer[stage] then
                Timer.delete(ActivityEndTimer[stage])
            end
            ActivityEndTimer[stage] = Timer.runAt(runTime, ActivityLogic.sendRankReward, ActivityLogic, configStage[stage].leaderboardID, configStage[stage].subtypeID, stage, activityId )
        end
    end
end

setActivityTime = function( _sactivityInfo )
    local activityInfo = SM.c_activity.req.Get(_sactivityInfo.ID) or {}
    local openTime = os.date('*t', Common.getSelfNodeOpenTime())
	local dayTime = { year = openTime.year, month = openTime.month, day = openTime.day, hour = CFG.s_Config:Get("systemDayTime") or 0, min = 0, sec = 0 }
    openTime = os.time(dayTime)
    if _sactivityInfo.timeType == Enum.ActivityTimeType.OPEN_SERVER then
        if _sactivityInfo.circulation == Enum.ActivityCirculation.NO then
            -- 开服第一次活动
            if table.empty(activityInfo) or activityInfo.endTime < os.time() then
                local flag = true
                local addTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    addTime = _sactivityInfo.concealDay
                end
                local addFlag = true
                if not table.empty(activityInfo) then addFlag = false end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                activityInfo.startTime = Timer.GetTimeDayX( openTime, tonumber(_sactivityInfo.timeData1) - 1 + addTime,
                        math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = openTime
                activityInfo.activityId = _sactivityInfo.ID
                if flag then
                    if addFlag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    else
                        SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                    end
                end
            end
        else
            if activityInfo and activityInfo.endTime and activityInfo.endTime <= os.time() then activityInfo.lastEndTime = activityInfo.endTime end
            if table.empty(activityInfo) or activityInfo.lastEndTime == openTime then
                local addTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    addTime = _sactivityInfo.concealDay
                end
                local flag = true
                local addFlag = true
                if not table.empty(activityInfo) then addFlag = false end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                activityInfo.startTime = Timer.GetTimeDayX( openTime, tonumber(_sactivityInfo.timeData1) - 1 + addTime,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = openTime
                activityInfo.activityId = _sactivityInfo.ID
                if flag then
                    if addFlag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    else
                        SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                    end
                end
            else
                activityInfo.startTime = Timer.GetTimeDayX( activityInfo.lastEndTime, _sactivityInfo.circulationDay, 0, 0, 0, true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = openTime
                activityInfo.activityId = _sactivityInfo.ID
                SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
            end
        end
    elseif _sactivityInfo.timeType == Enum.ActivityTimeType.NORMAL then
        if _sactivityInfo.circulation == Enum.ActivityCirculation.NO then
            local addFlag = true
            local flag = true
            if not table.empty(activityInfo) then addFlag = false end
            local dayInfo = string.split(_sactivityInfo.timeData1,"|")
            local year = math.tointeger(dayInfo[1])
            local month = math.tointeger(dayInfo[2])
            local day = math.tointeger(dayInfo[3])
            local timeInfo = string.split(_sactivityInfo.startTime,"|")
            local hour = math.tointeger(timeInfo[1] or 0 )
            local min = math.tointeger(timeInfo[2] or 0 )
            local sec =  math.tointeger(timeInfo[3] or 0 )
            local next_day = { year = year, month = month, day = day, hour = hour or 0, min = min or 0, sec = sec or 0 }
            activityInfo.startTime = Timer.fixCrossDayTime(os.time(next_day), true)
            activityInfo.endTime = activityInfo.startTime +  _sactivityInfo.durationTime
            activityInfo.activityId = _sactivityInfo.ID
            activityInfo.lastEndTime = activityInfo.startTime
            if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                    flag = false
                end
            end
            local checkTime = 0
            if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                        math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
            end
            if activityInfo.startTime >= checkTime then
                if flag then
                    if addFlag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    else
                        SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                    end
                end
            end
        else
            if table.empty(activityInfo) or os.time() > activityInfo.endTime or os.time() < activityInfo.endTime then
                local addFlag = true
                local flag = true
                if not table.empty(activityInfo) then addFlag = false end
                local dayInfo = string.split(_sactivityInfo.timeData1, "|")
                local year = math.tointeger(dayInfo[1])
                local month = math.tointeger(dayInfo[2])
                local day = math.tointeger(dayInfo[3])
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local hour = math.tointeger(timeInfo[1] or 0 )
                local min = math.tointeger(timeInfo[2] or 0 )
                local sec =  math.tointeger(timeInfo[3] or 0 )
                local next_day = { year = year, month = month, day = day, hour = hour or 0, min = min or 0, sec = sec or 0 }
                activityInfo.startTime = Timer.fixCrossDayTime(os.time(next_day), true)
                activityInfo.endTime = activityInfo.startTime +  _sactivityInfo.durationTime
                activityInfo.activityId = _sactivityInfo.ID
                local checkTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                end
                while true do
                    if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                        break
                    else
                        activityInfo.startTime = activityInfo.endTime + _sactivityInfo.circulationDay * 60 * 60 * 24 + 1
                        activityInfo.endTime = activityInfo.startTime +  _sactivityInfo.durationTime
                    end
                end
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                activityInfo.lastEndTime = activityInfo.startTime
                if flag then
                    if addFlag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    else
                        SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                    end
                end
            end
        end
    elseif _sactivityInfo.timeType == Enum.ActivityTimeType.FOREVER or _sactivityInfo.timeType == Enum.ActivityTimeType.CREATE_TIME then
        local addFlag = true
        if not table.empty(activityInfo) then addFlag = false end
        activityInfo.startTime = -1
        activityInfo.endTime = -1
        activityInfo.lastEndTime = -1
        activityInfo.activityId = _sactivityInfo.ID
        if addFlag then
            SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
        else
            SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
        end
    elseif _sactivityInfo.timeType == Enum.ActivityTimeType.ODD_WEEK then
        local week = checkWeek(openTime)
        if _sactivityInfo.circulation == Enum.ActivityCirculation.NO then
            if table.empty(activityInfo) then
                local addDay = 0
                local day = os.date( "%w" )
                if week == 1 then
                    if day == _sactivityInfo.timeData1 then
                        addDay = 0
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 14 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = _sactivityInfo.timeData1 - day
                    end
                else
                    if day == _sactivityInfo.timeData1 then
                        addDay = 7
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 7 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = 7 + ( _sactivityInfo.timeData1 - day )
                    end
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local checkTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                end
                activityInfo.startTime = Timer.GetTimeDayX( os.time(), addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                        , math.tointeger(timeInfo[3] or 0), true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = activityInfo.startTime
                activityInfo.activityId = _sactivityInfo.ID
                while true do
                    if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                        break
                    else
                        activityInfo.startTime = Timer.GetTimeDayX( activityInfo.endTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                            , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    end
                end
                --activityInfo.count = activityInfo + 1
                local flag = true
                -- 不循环不需要判断
                -- if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                --     if activityInfo.count > _sactivityInfo.circulationTime then
                --         flag = false
                --     end
                -- end
                if flag then
                    SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                end
            end
        else
            local preId = _sactivityInfo.killPrepositionID
            local preActivityInfo = CFG.s_ActivityCalendar:Get(preId)
            if table.empty(activityInfo) and ( preId == 0 or ( preId > 0 and ( ActivityInfo[preId] and ActivityInfo[preId].count >= preActivityInfo.circulationTime - 1 ) ) ) then
                local addDay = 0
                local day = os.date( "%w", openTime )
                if week == 1 then
                    if day == _sactivityInfo.timeData1 then
                        addDay = 0
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 14 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = _sactivityInfo.timeData1 - day
                    end
                else
                    if day == _sactivityInfo.timeData1 then
                        addDay = 7
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 7 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = 7 + ( _sactivityInfo.timeData1 - day )
                    end
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local checkTime = 0
                local addTimeCount = 0
                local killPrepositionID = 0
                if _sactivityInfo.killPrepositionID > 0 then
                    killPrepositionID = _sactivityInfo.killPrepositionID
                    while true do
                        local sActivityCalendar = CFG.s_ActivityCalendar:Get(killPrepositionID)
                        addTimeCount = addTimeCount + sActivityCalendar.circulationTime
                        if sActivityCalendar.killPrepositionID > 0 then
                            killPrepositionID = sActivityCalendar.killPrepositionID
                        else
                            break
                        end
                    end
                end
                if _sactivityInfo.killPrepositionID <= 0 then
                    if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                        checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                                math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                    end
                    activityInfo.startTime = Timer.GetTimeDayX( openTime, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                            , math.tointeger(timeInfo[3] or 0), true )
                    activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    activityInfo.lastEndTime = activityInfo.startTime
                    activityInfo.activityId = _sactivityInfo.ID
                    while true do
                        if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                            break
                        else
                            activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                , math.tointeger(timeInfo[3] or 0), true )
                            activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                        end
                    end
                    activityInfo.count = (activityInfo.count or 0) + 1
                    local flag = true
                    -- 判断循环次数
                    if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                        if activityInfo.count > _sactivityInfo.circulationTime then
                            flag = false
                        end
                    end
                    if flag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    end
                else
                    local sActivityCalendar = CFG.s_ActivityCalendar:Get(killPrepositionID)
                    if sActivityCalendar.openServiceConceal == Enum.OpenServiceConceal.YES then
                        checkTime = Timer.GetTimeDayX( openTime, sActivityCalendar.concealDay,
                                math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                    end

                    activityInfo.startTime = Timer.GetTimeDayX( openTime, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                            , math.tointeger(timeInfo[3] or 0), true )
                    activityInfo.endTime = activityInfo.startTime + sActivityCalendar.durationTime
                    activityInfo.lastEndTime = activityInfo.startTime
                    activityInfo.activityId = _sactivityInfo.ID
                    while true do
                        if activityInfo.startTime >= checkTime then
                            break
                        else
                            activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                , math.tointeger(timeInfo[3] or 0), true )
                            activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                        end
                    end
                    activityInfo.count = (activityInfo.count or 0) + 1
                    local flag = true
                    -- 判断循环次数
                    if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                        if activityInfo.count > _sactivityInfo.circulationTime then
                            flag = false
                        end
                    end
                    for _ = 1,addTimeCount do
                        local next_time = activityInfo.endTime + _sactivityInfo.circulationDay * 60 * 60 * 24 + 1
                        week = checkWeek(next_time)
                        day = os.date( "%w", next_time )
                        addDay = 0
                        if week == 1 then
                            if day == _sactivityInfo.timeData1 then
                                addDay = 0
                            elseif day > _sactivityInfo.timeData1 then
                                addDay = 14 - ( day - _sactivityInfo.timeData1 )
                            elseif day < _sactivityInfo.timeData1 then
                                addDay = _sactivityInfo.timeData1 - day
                            end
                        else
                            if day == _sactivityInfo.timeData1 then
                                addDay = 7
                            elseif day > _sactivityInfo.timeData1 then
                                addDay = 7 - ( day - _sactivityInfo.timeData1 )
                            elseif day < _sactivityInfo.timeData1 then
                                addDay = 7 + ( _sactivityInfo.timeData1 - day )
                            end
                        end
                        timeInfo = string.split(_sactivityInfo.startTime,"|")
                        checkTime = 0
                        if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                            checkTime = Timer.GetTimeDayX( openTime, sActivityCalendar.concealDay,
                                    math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                        end
                        activityInfo.startTime = Timer.GetTimeDayX( next_time, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                                , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                        activityInfo.lastEndTime = activityInfo.startTime
                        activityInfo.activityId = _sactivityInfo.ID
                        while true do
                            if activityInfo.startTime >= checkTime then
                                break
                            else
                                activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                    , math.tointeger(timeInfo[3] or 0), true )
                                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                            end
                        end
                    end
                    if flag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    end
                end
            elseif not table.empty(activityInfo) and activityInfo.endTime <= os.time() and activityInfo.count < _sactivityInfo.circulationTime then
                local next_time = activityInfo.endTime + _sactivityInfo.circulationDay * 60 * 60 * 24 + 1
                week = checkWeek(next_time)
                local day = os.date( "%w", next_time )
                local addDay = 0
                if week == 1 then
                    if day == _sactivityInfo.timeData1 then
                        addDay = 0
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 14 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = _sactivityInfo.timeData1 - day
                    end
                else
                    if day == _sactivityInfo.timeData1 then
                        addDay = 7
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 7 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = 7 + ( _sactivityInfo.timeData1 - day )
                    end
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local checkTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                end
                activityInfo.startTime = Timer.GetTimeDayX( next_time, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                        , math.tointeger(timeInfo[3] or 0), true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = activityInfo.startTime
                activityInfo.activityId = _sactivityInfo.ID
                while true do
                    if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                        break
                    else
                        activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                            , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    end
                end
                activityInfo.count = (activityInfo.count or 0) + 1
                local flag = true
                -- 判断循环次数
                if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                    if activityInfo.count > _sactivityInfo.circulationTime then
                        flag = false
                    end
                end
                if flag then
                    SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                end
            end
        end
    elseif _sactivityInfo.timeType == Enum.ActivityTimeType.EVEN_WEEK then
        local week = checkWeek(openTime)
        if _sactivityInfo.circulation == Enum.ActivityCirculation.NO then
            if table.empty(activityInfo) then
                local addDay = 0
                local day = os.date( "%w", openTime )
                if week == 0 then
                    if day == _sactivityInfo.timeData1 then
                        addDay = 0
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 14 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = _sactivityInfo.timeData1 - day
                    end
                else
                    if day == _sactivityInfo.timeData1 then
                        addDay = 7
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 7 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = 7 + ( _sactivityInfo.timeData1 - day )
                    end
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local checkTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                end
                activityInfo.startTime = Timer.GetTimeDayX( os.time(), addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                        , math.tointeger(timeInfo[3] or 0), true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = activityInfo.startTime
                activityInfo.activityId = _sactivityInfo.ID
                while true do
                    if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                        break
                    else
                        activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                            , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    end
                end
                --activityInfo.count = activityInfo + 1
                local flag = true
                -- 不循环不需要判断
                -- if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                --     if activityInfo.count > _sactivityInfo.circulationTime then
                --         flag = false
                --     end
                -- end
                if flag then
                    SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                end
            end
        else
            local preId = _sactivityInfo.killPrepositionID
            local preActivityInfo = CFG.s_ActivityCalendar:Get(preId)
            if table.empty(activityInfo) and ( preId == 0 or ( preId > 0 and ( ActivityInfo[preId] and ActivityInfo[preId].count >= preActivityInfo.circulationTime - 1 ) ) ) then
                local addDay = 0
                local day = os.date( "%w", openTime )
                if week == 0 then
                    if day == _sactivityInfo.timeData1 then
                        addDay = 0
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 14 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = _sactivityInfo.timeData1 - day
                    end
                else
                    if day == _sactivityInfo.timeData1 then
                        addDay = 7
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 7 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = 7 + ( _sactivityInfo.timeData1 - day )
                    end
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local checkTime = 0
                local addTimeCount = 0
                local killPrepositionID = 0
                if _sactivityInfo.killPrepositionID > 0 then
                    killPrepositionID = _sactivityInfo.killPrepositionID
                    while true do
                        local sActivityCalendar = CFG.s_ActivityCalendar:Get(killPrepositionID)
                        addTimeCount = addTimeCount + sActivityCalendar.circulationTime
                        if sActivityCalendar.killPrepositionID > 0 then
                            killPrepositionID = sActivityCalendar.killPrepositionID
                        else
                            break
                        end
                    end
                end
                if _sactivityInfo.killPrepositionID <= 0 then
                    if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                        checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                                math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                    end
                    activityInfo.startTime = Timer.GetTimeDayX( openTime, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                            , math.tointeger(timeInfo[3] or 0), true )
                    activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    activityInfo.lastEndTime = activityInfo.startTime
                    activityInfo.activityId = _sactivityInfo.ID
                    while true do
                        if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                            break
                        else
                            activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                , math.tointeger(timeInfo[3] or 0), true )
                            activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                        end
                    end
                    activityInfo.count = (activityInfo.count or 0) + 1
                    local flag = true
                    -- 判断循环次数
                    if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                        if activityInfo.count > _sactivityInfo.circulationTime then
                            flag = false
                        end
                    end
                    if flag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    end
                else
                    local sActivityCalendar = CFG.s_ActivityCalendar:Get(killPrepositionID)
                    if sActivityCalendar.openServiceConceal == Enum.OpenServiceConceal.YES then
                        checkTime = Timer.GetTimeDayX( openTime, sActivityCalendar.concealDay,
                                math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                    end
                    activityInfo.startTime = Timer.GetTimeDayX( openTime, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                            , math.tointeger(timeInfo[3] or 0), true )
                    activityInfo.endTime = activityInfo.startTime + sActivityCalendar.durationTime
                    activityInfo.lastEndTime = activityInfo.startTime
                    activityInfo.activityId = _sactivityInfo.ID
                    while true do
                        if activityInfo.startTime >= checkTime then
                            break
                        else
                            activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                , math.tointeger(timeInfo[3] or 0), true )
                            activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                        end
                    end
                    activityInfo.count = (activityInfo.count or 0) + 1
                    local flag = true
                    -- 判断循环次数
                    if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                        if activityInfo.count > _sactivityInfo.circulationTime then
                            flag = false
                        end
                    end
                    for _ = 1, addTimeCount do
                        local next_time = activityInfo.endTime + sActivityCalendar.circulationDay * 60 * 60 * 24 + 1
                        week = checkWeek(next_time)
                        day = os.date( "%w", next_time )
                        addDay = 0
                        if week == 0 then
                            if day == sActivityCalendar.timeData1 then
                                addDay = 0
                            elseif day > sActivityCalendar.timeData1 then
                                addDay = 14 - ( day - sActivityCalendar.timeData1 )
                            elseif day < sActivityCalendar.timeData1 then
                                addDay = _sactivityInfo.timeData1 - day
                            end
                        else
                            if day == sActivityCalendar.timeData1 then
                                addDay = 7
                            elseif day > sActivityCalendar.timeData1 then
                                addDay = 7 - ( day - sActivityCalendar.timeData1 )
                            elseif day < sActivityCalendar.timeData1 then
                                addDay = 7 + ( _sactivityInfo.timeData1 - day )
                            end
                        end
                        timeInfo = string.split(sActivityCalendar.startTime,"|")
                        checkTime = 0
                        if sActivityCalendar.openServiceConceal == Enum.OpenServiceConceal.YES then
                            checkTime = Timer.GetTimeDayX( openTime, sActivityCalendar.concealDay,
                                    math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                        end
                        activityInfo.startTime = Timer.GetTimeDayX( next_time, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                                , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + sActivityCalendar.durationTime
                        activityInfo.lastEndTime = activityInfo.startTime
                        activityInfo.activityId = _sactivityInfo.ID
                        while true do
                            if activityInfo.startTime >= checkTime then
                                break
                            else
                                activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                    , math.tointeger(timeInfo[3] or 0), true )
                                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                            end
                        end
                    end
                    if flag then
                        SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                    end
                end
            elseif not table.empty(activityInfo) and activityInfo.endTime <= os.time() and activityInfo.count < _sactivityInfo.circulationTime then
                local next_time = activityInfo.endTime + _sactivityInfo.circulationDay * 60 * 60 * 24 + 1
                week = checkWeek(next_time)
                local day = os.date( "%w", next_time )
                local addDay = 0
                if week == 0 then
                    if day == _sactivityInfo.timeData1 then
                        addDay = 0
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 14 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = _sactivityInfo.timeData1 - day
                    end
                else
                    if day == _sactivityInfo.timeData1 then
                        addDay = 7
                    elseif day > _sactivityInfo.timeData1 then
                        addDay = 7 - ( day - _sactivityInfo.timeData1 )
                    elseif day < _sactivityInfo.timeData1 then
                        addDay = 7 + ( _sactivityInfo.timeData1 - day )
                    end
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local checkTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                end
                activityInfo.startTime = Timer.GetTimeDayX( next_time, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                        , math.tointeger(timeInfo[3] or 0), true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = activityInfo.startTime
                activityInfo.activityId = _sactivityInfo.ID
                while true do
                    if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                        break
                    else
                        activityInfo.startTime = Timer.GetTimeDayX( activityInfo.startTime, 14, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                            , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    end
                end
                activityInfo.count = (activityInfo.count or 0) + 1
                local flag = true
                -- 判断循环次数
                if _sactivityInfo.circulationTime and _sactivityInfo.circulationTime > 0 then
                    if activityInfo.count > _sactivityInfo.circulationTime then
                        flag = false
                    end
                end
                if flag then
                    SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                end
            end
        end
    elseif _sactivityInfo.timeType == Enum.ActivityTimeType.WEEK then
        if _sactivityInfo.circulation == Enum.ActivityCirculation.NO then
            if table.empty(activityInfo) then
                local day = os.date( "%w" )
                local addDay = 0
                if day == _sactivityInfo.timeData1 then
                    addDay = 0
                elseif day > _sactivityInfo.timeData1 then
                    addDay = 7 - ( day - _sactivityInfo.timeData1 )
                elseif day < _sactivityInfo.timeData1 then
                    addDay = _sactivityInfo.timeData1 - day
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                local checkTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    checkTime = Timer.GetTimeDayX( openTime, _sactivityInfo.concealDay,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                end
                activityInfo.startTime = Timer.GetTimeDayX( os.time(), addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                        , math.tointeger(timeInfo[3] or 0), true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = activityInfo.startTime
                activityInfo.activityId = _sactivityInfo.ID
                while true do
                    if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                        break
                    else
                        local next_time = activityInfo.endTime + _sactivityInfo.circulationDay * 60 * 60 * 24
                        day = os.date( "%w", next_time )
                        if day == _sactivityInfo.timeData1 then
                            addDay = 0
                        elseif day > _sactivityInfo.timeData1 then
                            addDay = 7 - ( day - _sactivityInfo.timeData1 )
                        elseif day < _sactivityInfo.timeData1 then
                            addDay = _sactivityInfo.timeData1 - day
                        end
                        activityInfo.startTime = Timer.GetTimeDayX( next_time, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                            , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    end
                end
                local flag = true
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                if flag then
                    SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                end
            elseif activityInfo.startTime + _sactivityInfo.durationTime >= os.time() then
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.lastEndTime = activityInfo.endTime
                activityInfo.activityId = _sactivityInfo.ID
                local flag = true
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                if flag then
                    SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                end
            end
        else
            if table.empty(activityInfo) then
                local day = os.date( "%w" )
                local addDay = 0
                if day == _sactivityInfo.timeData1 then
                    addDay = 0
                elseif day > _sactivityInfo.timeData1 then
                    addDay = 7 - ( day - _sactivityInfo.timeData1 )
                elseif day < _sactivityInfo.timeData1 then
                    addDay = _sactivityInfo.timeData1 - day
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                activityInfo.startTime = Timer.GetTimeDayX( os.time(), addDay,  math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                                        , math.tointeger(timeInfo[3] or 0), true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.activityId = _sactivityInfo.ID
                local flag = true
                local checkTime = 0
                if _sactivityInfo.openServiceConceal == Enum.OpenServiceConceal.YES then
                    checkTime = Timer.GetTimeDayX( os.time(), _sactivityInfo.concealDay,
                            math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0), math.tointeger(timeInfo[3] or 0), true )
                end
                while true do
                    if activityInfo.endTime > os.time() and activityInfo.startTime >= checkTime then
                        break
                    else
                        local next_time = activityInfo.endTime + _sactivityInfo.circulationDay * 60 * 60 * 24 + 1
                        day = os.date( "%w", next_time )
                        if day == _sactivityInfo.timeData1 then
                            addDay = 0
                        elseif day > _sactivityInfo.timeData1 then
                            addDay = 7 - ( day - _sactivityInfo.timeData1 )
                        elseif day < _sactivityInfo.timeData1 then
                            addDay = _sactivityInfo.timeData1 - day
                        end
                        activityInfo.startTime = Timer.GetTimeDayX( next_time, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0)
                            , math.tointeger(timeInfo[3] or 0), true )
                        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    end
                end
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                if flag then
                    SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
                end
            elseif activityInfo.startTime + _sactivityInfo.durationTime > os.time() then
                local flag = true
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                if flag then
                    activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                    activityInfo.activityId = _sactivityInfo.ID
                    SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                end
            elseif activityInfo.startTime + _sactivityInfo.durationTime <= os.time() then
                activityInfo.lastEndTime = activityInfo.endTime
                local next_time = activityInfo.lastEndTime + _sactivityInfo.circulationDay * 60 * 60 * 24 + 1
                local day = os.date( "%w", next_time )
                local addDay
                if day == _sactivityInfo.timeData1 then
                    addDay = 0
                elseif day > _sactivityInfo.timeData1 then
                    addDay = 7 - ( day - _sactivityInfo.timeData1 )
                elseif day < _sactivityInfo.timeData1 then
                    addDay = _sactivityInfo.timeData1 - day
                end
                local timeInfo = string.split(_sactivityInfo.startTime,"|")
                activityInfo.startTime = Timer.GetTimeDayX( next_time, addDay, math.tointeger(timeInfo[1] or 0 ), math.tointeger(timeInfo[2] or 0),
                            math.tointeger(timeInfo[3] or 0), true )
                activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
                activityInfo.activityId = _sactivityInfo.ID
                local flag = true
                if _sactivityInfo.stopDay and _sactivityInfo.stopDay > 0 then
                    if activityInfo.startTime >= openTime + _sactivityInfo.stopDay * 24 * 60 * 60 then
                        flag = false
                    end
                end
                if flag then
                    SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
                end
            end
        end
    elseif _sactivityInfo.timeType == Enum.ActivityTimeType.PRE_ACTIVITY then
        if not ActivityInfo[_sactivityInfo.prepositionID] or ActivityInfo[_sactivityInfo.prepositionID].endTime < os.time()
            or (ActivityInfo[_sactivityInfo.ID] and ActivityInfo[_sactivityInfo.ID].endTime > os.time()) then
            return
        end
        local update = false
        if not table.empty(activityInfo) then
            update = true
        end
        activityInfo.startTime = ActivityInfo[_sactivityInfo.prepositionID].endTime + 1
        activityInfo.endTime = activityInfo.startTime + _sactivityInfo.durationTime
        activityInfo.activityId = _sactivityInfo.ID
        if update then
            SM.c_activity.req.Set(_sactivityInfo.ID, activityInfo)
        else
            SM.c_activity.req.Add(_sactivityInfo.ID, activityInfo)
        end
    end
    if SM.c_activity.req.Get(_sactivityInfo.ID) then
        if activityInfo.endTime > os.time() then
            if ActivityStartTimer[_sactivityInfo.ID] then
                Timer.delete(ActivityStartTimer[_sactivityInfo.ID])
            end
            if activityInfo.startTime > os.time() then
                -- 加入定时器
                ActivityStartTimer[_sactivityInfo.ID] = Timer.runAt(activityInfo.startTime, startActivity, activityInfo )
            else
                startActivity(activityInfo)
            end
            if activityInfo.count and activityInfo.count >= _sactivityInfo.circulationTime and _sactivityInfo.killPostpositionID > 0 then
                local config = CFG.s_ActivityCalendar:Get(_sactivityInfo.killPostpositionID)
                setActivityTime(config)
            end
            ActivityInfo[_sactivityInfo.ID] = activityInfo
            if _sactivityInfo.postpositionID > 0 then
                local postConfig = CFG.s_ActivityCalendar:Get(_sactivityInfo.postpositionID)
                if postConfig.timeType == Enum.ActivityTimeType.PRE_ACTIVITY then
                    setActivityTime(postConfig)
                end
            end
        end
        ActivityInfo[_sactivityInfo.ID] = activityInfo
    end
end

---@see 地狱活动信息
function accept.acceptHellActivityInfo( activityInfo, rankList, oldActivity, noCheck )
    local activityId = activityInfo.activityId
    local rank = {}
    for age, rule in pairs(oldActivity.rule) do
        local order = 0
        for _, id in pairs(rule.ids) do
            local config = CFG.s_ActivityInfernal:Get(id)
            if not order or config.order > order then
                order = config.order
                rank[age] = CFG.s_ActivityRankingType:Get(config.rewardRank)
            end
        end
    end
    if not noCheck and (ActivityInfo[activityId] and ActivityInfo[activityId].startTime == activityInfo.startTime) then
        return
    end
    ActivityInfo[activityId] = activityInfo
    local rids = SM.OnlineMgr.req.getAllOnlineRid()
    for _, rid in pairs(rids) do
        local townHall = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.TOWNHALL )[1]
        if townHall.level >= CFG.s_Config:Get("activityInfernalLevelLimit") then
            local synInfo = {}
            local activity = RoleLogic:getRole( rid, Enum.Role.activity )
            -- 自动发奖励
            ActivityLogic:autoAwardHellReward( rid, activityId )
            -- 重置活动数据
            ActivityLogic:activityStartReset( rid, activityId, activity, activityInfo, {} )
            RoleLogic:setRole( rid, { [Enum.Role.activity] = activity } )
            synInfo[Enum.Role.activity] = {[activityId] = activity[activityId]}
            -- 推送活动信息
            synInfo[Enum.Role.activityTimeInfo] = { [activityId] = activityInfo }
            RoleSync:syncSelf( rid, synInfo, true )
        end
    end
    -- 排行榜发奖
    if rankList then
        for age, ranks in pairs(rankList) do
            for _, rankInfo in pairs(ranks) do
                for _, config in pairs (rank[age]) do
                    if rankInfo.index >= config.targetMin and rankInfo.index <= config.targetMax then
                        local rewardInfo = ItemLogic:getItemPackage( rankInfo.rid, config.itemPackage, true )
                        EmailLogic:sendEmail( rankInfo.rid, config.mailID, { rewards = rewardInfo, emailContents = { rankInfo.index } } )
                    end
                end
            end
        end
    end
end

---@see 跨周重置活动时间
function accept.weekResetActivity()
    local s_ActivityCalendar = CFG.s_ActivityCalendar:Get()
    for _, sactivityInfo in pairs(s_ActivityCalendar) do
        if sactivityInfo.activityType ~= Enum.ActivityType.HELL and sactivityInfo.timeType ~= Enum.ActivityTimeType.PRE_ACTIVITY then
            setActivityTime( sactivityInfo )
        end
    end
end

---@see 初始化
function response.Init()
    local s_ActivityCalendar = CFG.s_ActivityCalendar:Get()
    for _, sactivityInfo in pairs(s_ActivityCalendar) do
        local activityInfo = SM.c_activity.req.Get(sactivityInfo.ID)
        if sactivityInfo.activityType ~= Enum.ActivityType.HELL and table.empty(activityInfo) then
            setActivityTime( sactivityInfo )
        elseif sactivityInfo.activityType ~= Enum.ActivityType.HELL and not table.empty(activityInfo) then
            if activityInfo.endTime > os.time() then
                if ActivityStartTimer[sactivityInfo.ID] then
                    Timer.delete(ActivityStartTimer[sactivityInfo.ID])
                end
                if activityInfo.startTime > os.time() then
                    -- 加入定时器
                    ActivityStartTimer[sactivityInfo.ID] = Timer.runAt(activityInfo.startTime, startActivity, activityInfo )
                else
                    startActivity(activityInfo)
                end
                if activityInfo.count and activityInfo.count >= sactivityInfo.circulationTime and sactivityInfo.killPostpositionID > 0 then
                    local config = CFG.s_ActivityCalendar:Get(sactivityInfo.killPostpositionID)
                    setActivityTime(config)
                end
                if sactivityInfo.postpositionID > 0 then
                    local postConfig = CFG.s_ActivityCalendar:Get(sactivityInfo.postpositionID)
                    if postConfig.timeType == Enum.ActivityTimeType.PRE_ACTIVITY then
                        setActivityTime(postConfig)
                    end
                end
            end
            ActivityInfo[sactivityInfo.ID] = activityInfo
        end
    end
    local allNodes = Common.getClusterNodeByName( "center", true ) or {}
    for _, nodeName in pairs( allNodes ) do
        local activity = Common.rpcCall( nodeName, "HellActivityPorxy", "getActivityInfo" )
        if activity and not table.empty(activity) then
            ActivityInfo[80001] = activity
            break
        end
    end
end

function accept.resetActivityTimeInfo()
    local s_ActivityCalendar = CFG.s_ActivityCalendar:Get()
    for _, sactivityInfo in pairs(s_ActivityCalendar) do
        setActivityTime( sactivityInfo )
    end
end

---@see 获取活动信息
function response.getActivityInfo( _activityId )
    if not _activityId then return ActivityInfo end
    return ActivityInfo[_activityId]
end

function accept.addActivityTimer( _activityId, _timerId )
    ActivityEndTimer[_activityId] = _timerId
end

---@see 活动修改
function response.PmSetActivity()
    SM.c_activity.req.DeleteAll()
    ActivityInfo = {}
    local s_ActivityCalendar = CFG.s_ActivityCalendar:Get()
    for _, sactivityInfo in pairs(s_ActivityCalendar) do
        local activityInfo = SM.c_activity.req.Get(sactivityInfo.ID)
        if sactivityInfo.activityType ~= Enum.ActivityType.HELL and table.empty(activityInfo) then
            setActivityTime( sactivityInfo )
        elseif sactivityInfo.activityType ~= Enum.ActivityType.HELL and not table.empty(activityInfo) then
            if activityInfo.endTime > os.time() then
                if ActivityStartTimer[sactivityInfo.ID] then
                    Timer.delete(ActivityStartTimer[sactivityInfo.ID])
                end
                if activityInfo.startTime > os.time() then
                    -- 加入定时器
                    ActivityStartTimer[sactivityInfo.ID] = Timer.runAt(activityInfo.startTime, startActivity, activityInfo )
                else
                    startActivity(activityInfo)
                end
                if activityInfo.count and activityInfo.count >= sactivityInfo.circulationTime and sactivityInfo.killPostpositionID > 0 then
                    local config = CFG.s_ActivityCalendar:Get(sactivityInfo.killPostpositionID)
                    setActivityTime(config)
                end
                if sactivityInfo.postpositionID > 0 then
                    local postConfig = CFG.s_ActivityCalendar:Get(sactivityInfo.postpositionID)
                    if postConfig.timeType == Enum.ActivityTimeType.PRE_ACTIVITY then
                        setActivityTime(postConfig)
                    end
                end
            end
            ActivityInfo[sactivityInfo.ID] = activityInfo
        end
    end
    local allNodes = Common.getClusterNodeByName( "center", true ) or {}
    for _, nodeName in pairs( allNodes ) do
        local activity = Common.rpcCall( nodeName, "HellActivityPorxy", "getActivityInfo" )
        if activity and not table.empty(activity) then
            ActivityInfo[80001] = activity
            break
        end
    end
end