--[[
* @file : HellActivityPorxy.lua
* @type : snax singer service
* @author : chenlei
* @created : Tue May 12 2020 13:37:51 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地狱活动管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local skynet = require "skynet"
local Random = require "Random"
local Timer = require "Timer"
local guildNameCenter
local activityInfo = {}

local function initGuildNameCenter()
    local selfNode = Common.getSelfNodeName()
    local flag = skynet.getenv( "hellactivitycenter" )
    if flag == "true" then
        -- 通知其他的game和center服
        local allNodes = Common.getClusterNodeByName( "center", true ) or {}
        for _, nodeName in pairs( allNodes ) do
            if selfNode == nodeName then
                guildNameCenter = selfNode
            end
        end
    end
end

---@see 重置s_ActivityInfernal
local function reinitSActivityInfernal()
    local sActivityInfernal = CFG.s_ActivityInfernal:Get()
    local newsActivityInfernal = {}
    for _, activityInfernal in pairs( sActivityInfernal ) do
        if not newsActivityInfernal[activityInfernal.cityAge] then newsActivityInfernal[activityInfernal.cityAge] = {} end
        if not newsActivityInfernal[activityInfernal.cityAge][activityInfernal.difficulty] then newsActivityInfernal[activityInfernal.cityAge][activityInfernal.difficulty] = {} end
        newsActivityInfernal[activityInfernal.cityAge][activityInfernal.difficulty][activityInfernal.ID] = activityInfernal
    end
    SM.s_ActivityInfernal.req.Set( newsActivityInfernal )
end

---@see 初始化地狱活动信息
local function initActivityInfo( _noReset )
    local hallActivity = {}
    if not guildNameCenter then return end
    local rankList = {}
    local oldActivity = table.copy(activityInfo[80001], true)
    -- 排行版处理
    for i=1,6 do
        local key = string.format("hell_activity_%d", i)
        local rankInfos = MSM.RankMgr[0].req.queryRank( key, 1, 100, true )
        for j, info in pairs(rankInfos) do
            local member = tonumber(info.member)
            local data = SM.c_hell_activity_rank.req.Get(member)
            if not rankList[data.gameNode] then rankList[data.gameNode] = {} end
            if not rankList[data.gameNode][i] then rankList[data.gameNode][i] = {} end
            table.insert(rankList[data.gameNode][i], { rid = member, index = j, age = i })
        end
        MSM.RankMgr[0].post.deleteKey(key, true)
    end
    MSM.RankMgr[0].post.deleteKey("hell_activity_1")
    local sActivityInfernal = CFG.s_ActivityInfernal:Get()
    local sActivityCalendar = CFG.s_ActivityCalendar:Get(80001)
    local rule = {}
    -- 确定活动积分来源个数九   零 一 起 玩 w w w . 9 0  1 7 5 . co m
    local activityInfernalTypeNumRate = CFG.s_Config:Get("activityInfernalTypeNumRate")
    local rate = {}
    for i, rateNum in pairs(activityInfernalTypeNumRate) do
        table.insert(rate, { id = i, rate = rateNum })
    end
    local count = Random.GetId(rate)
    local activityInfernalDifficultRate = CFG.s_Config:Get("activityInfernalDifficultRate")
    rate = {}
    for i, rateNum in pairs(activityInfernalDifficultRate) do
        table.insert(rate, { id = i, rate = rateNum })
    end
    local difficulty = Random.GetId(rate)

    for age, activityInfernal in pairs(sActivityInfernal) do
        rate = {}
        local activityInfernalConfig = activityInfernal[difficulty]
        for id, config in pairs(activityInfernalConfig) do
            table.insert(rate, { id = id, rate = config.odds })
        end
        local ids = {}
        for _, id in pairs( Random.GetIds( rate, count ) ) do
            table.insert( ids, id )
        end
        rule[age] = { age = age, ids = ids}
    end
    if not _noReset then
        hallActivity.startTime = os.time()
        hallActivity.endTime = hallActivity.startTime + sActivityCalendar.durationTime
        hallActivity.rule = rule
        hallActivity.activityId = 80001
        -- 推送到所有服务器
        if not SM.c_hallActivity.req.Get(80001) then
            SM.c_hallActivity.req.Add(80001, hallActivity)
        else
            SM.c_hallActivity.req.Set(80001, hallActivity)
        end
        activityInfo[80001] = hallActivity
    else
        hallActivity = activityInfo[80001]
    end
    local allNodes = Common.getClusterNodeByName( "game", true ) or {}
    for _, nodeName in pairs( allNodes ) do
        Common.rpcSend( nodeName, "ActivityMgr", "acceptHellActivityInfo", hallActivity, rankList[nodeName], oldActivity, _noReset )
    end
end

function response.getActivityInfo()
    return activityInfo[80001]
end

---@see 检查活动状态
local function check()
    local hallActivity = SM.c_hallActivity.req.Get(80001)
    if hallActivity and hallActivity.endTime > os.time() then
        -- 直接推送活动数据告诉每个游服
        local allNodes = Common.getClusterNodeByName( "game", true ) or {}
        for _, nodeName in pairs( allNodes ) do
            Common.rpcSend( nodeName, "ActivityMgr", "acceptHellActivityInfo", hallActivity, nil, hallActivity )
        end
        activityInfo[80001] = hallActivity
    elseif hallActivity and hallActivity.endTime <= os.time() then
        activityInfo[80001] = hallActivity
        initActivityInfo( true )
    end
    Timer.runEveryHour(initActivityInfo)
end

---@see 初始化
function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)

    LOG_INFO("HellActivityPorxy Init start")
    -- 重置配置表
    reinitSActivityInfernal()
    -- 获取记录guildName的center服
    initGuildNameCenter()
    -- 初始化活动数据
    check()
    LOG_INFO("HellActivityPorxy Init over")
end

---@see 更新记录guildName的center服
function response.updateGuildNameCenter( _guildNameCenter )
    if _guildNameCenter then
        guildNameCenter = _guildNameCenter
        LOG_INFO("guild name center:%s", _guildNameCenter)
    end
end

---@see 获取记录guildName的center服
function response.getGuildNameCenter()
    return guildNameCenter
end