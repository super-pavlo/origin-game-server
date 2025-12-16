--[[
* @file : RankMgr.lua
* @type : multi snax service
* @author : chenlei
* @created : Mon Apr 20 2020 13:10:38 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 排行版服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local rankTypes = {}

local function initRankType()
    rankTypes["role_power"] = { name = "c_role_power", rankType = Enum.RankType.ROLE_POWER }
    rankTypes["alliance_power"] = { name = "c_alliance_power", rankType = Enum.RankType.ALLIANCE_POWER }
    rankTypes["alliance_kill"] = { name = "c_alliance_kill", rankType = Enum.RankType.ALLIANCE_KILL }
    rankTypes["alliance_flag"] = { name = "c_alliance_flag", rankType = Enum.RankType.ALLIANCE_FLAG }
    rankTypes["townhall"] = { name = "c_townhall", rankType = Enum.RankType.MAIN_TOWN_LEVEL }
    rankTypes["role_kill"] = { name = "c_role_kill", rankType = Enum.RankType.ROLE_KILL }
    rankTypes["role_collect_res"] = { name = "c_role_collect_res", rankType = Enum.RankType.ROLE_RES }
    rankTypes["reserve"] = { name = "c_reserve", rankType = Enum.RankType.RESERVE }
    rankTypes["combat_first"] = { name = "c_combat_first", rankType = Enum.RankType.COMBAT_FIRST }
    rankTypes["rise_up"] = { name = "c_rise_up", rankType = Enum.RankType.RISE_UP }
    rankTypes["kill_type_all"] = { name = "c_kill_type", rankType = Enum.RankType.MGE_TOTAL, formatString = true }
    rankTypes["kill_type_1"] = { name = "c_kill_type", rankType = Enum.RankType.MGE_TARIN, format = 1 }
    rankTypes["kill_type_2"] = { name = "c_kill_type", rankType = Enum.RankType.MGE_KILL_BARB, format = 2 }
    rankTypes["kill_type_3"] = { name = "c_kill_type", rankType = Enum.RankType.MGE_COLLECT_RES, format = 3 }
    rankTypes["kill_type_4"] = { name = "c_kill_type", rankType = Enum.RankType.MGE_POWER_UP, format = 4 }
    rankTypes["kill_type_5"] = { name = "c_kill_type", rankType = Enum.RankType.MGE_KILL, format = 5 }
    rankTypes["expedition"] = { name = "c_expedition", rankType = Enum.RankType.EXPEDITION }
    rankTypes["hell_activity_1"] = { name = "c_hell_activity_rank", type = 1, rankType = Enum.RankType.HELL_ORIGINAL }
    rankTypes["hell_activity_2"] = { name = "c_hell_activity_rank", type = 2, rankType = Enum.RankType.HELL_CLASSICAL }
    rankTypes["hell_activity_3"] = { name = "c_hell_activity_rank", type = 3, rankType = Enum.RankType.ALLIANCE_KILL }
    rankTypes["hell_activity_4"] = { name = "c_hell_activity_rank", type = 4, rankType = Enum.RankType.HELL_DARK }
    rankTypes["hell_activity_5"] = { name = "c_hell_activity_rank", type = 5, rankType = Enum.RankType.HELL_INDUSTRY }
    rankTypes["hell_activity_6"] = { name = "c_hell_activity_rank", type = 6, rankType = Enum.RankType.HELL_MODERN }
    rankTypes["guild_role_power"] = { name = "c_guild_role_power", rankType = Enum.RankType.ALLIACEN_ROLE_POWER, multiTable = true }
    rankTypes["guild_role_kill"] = { name = "c_guild_role_kill", rankType = Enum.RankType.ALLIACEN_ROLE_KILL, multiTable = true }
    rankTypes["guild_role_donate"] = { name = "c_guild_role_donate", rankType = Enum.RankType.ALLIACEN_ROLE_DONATE, multiTable = true }
    rankTypes["guild_role_build"] = { name = "c_guild_role_build", rankType = Enum.RankType.ALLIACEN_ROLE_BUILD, multiTable = true }
    rankTypes["guild_role_help"] = { name = "c_guild_role_help", rankType = Enum.RankType.ALLIACEN_ROLE_HELP, multiTable = true }
    rankTypes["guild_resource_help"] = { name = "c_guild_resource_help", rankType = Enum.RankType.ALLIACEN_ROLE_RES_HELP, multiTable = true }
    rankTypes["tribe_king"] = { name = "c_tribe_king", rankType = Enum.RankType.TRIBE_KING }
    rankTypes["fight_horn"] = { name = "c_fight_horn", rankType = Enum.RankType.FIGHT_HORN }
    rankTypes["fight_horn_alliance"] = { name = "c_fight_horn_alliance", rankType = Enum.RankType.FIGHT_HORN_ALLIANCE }

end

function init(index)
	snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)

    initRankType()
end

function response.updateDb( _key, _member, _score, _gameNode, _lastScore, _tableKey )
    local sLeaderboard
    local tableName = rankTypes[_key].name
    local type = rankTypes[_key].type
    local rankType = rankTypes[_key].rankType
    if rankTypes[_key].multiTable then
        local data = SM[tableName].req.Get( _tableKey, _member )
        if not data or table.empty( data ) then
            SM[tableName].req.Add( _tableKey, _member, { score = _score, rid = _member, lastScore = _lastScore } )
        else
            SM[tableName].req.Set( _tableKey, _member, { score = _score, rid = _member, lastScore = _lastScore } )
        end
    else
        if rankTypes[_key].format then _member = string.format( "%d_%d", _member, rankTypes[_key].format ) end
        if rankTypes[_key].formatString then _member = tostring(_member) end
        local data = SM[tableName].req.Get(_member)
        if not data then
            SM[tableName].req.Add(_member, { score = _score, gameNode = _gameNode, rankType = type, lastScore = _lastScore  })
        else
            SM[tableName].req.Set(_member, { score = _score, gameNode = _gameNode, rankType = type, lastScore = _lastScore  })
        end
    end
    sLeaderboard = CFG.s_Leaderboard:Get(rankType)
    if sLeaderboard.list ~= 3 then
        local recordLimit = sLeaderboard.recordLimit
        local rankList = Common.redisExecute( { "ZREVRANGE", _key, recordLimit, -1 } )
        if rankList then
            for _, member in pairs(rankList) do
                member = tonumber(member)
                snax.self().post.deleteRecord( _key, member )
            end
        end
    end
end

local function deleteDb( _key, _member, _tableKey )
    local tableName = rankTypes[_key].name
    if rankTypes[_key].multiTable then
        SM[tableName].req.Delete( _tableKey, _member )
    else
        if not _member then
            SM[tableName].req.DeleteAll()
        else
            SM[tableName].req.Delete(_member)
        end
    end
end


---@see 查询排行版
function response.queryRank(_key, _page, _maxRecord, _showScore, _all)
    local startRecord = ( (_page or 1) - 1 ) * (_maxRecord or 10)
    local endRecord = ( (_page or 1) ) * (_maxRecord or 10) - 1
    if _all then
        startRecord = 0
        endRecord = -1
    end
    local redisCmd = { "ZREVRANGE", _key, startRecord, endRecord }
    if _showScore then
        redisCmd = { "ZREVRANGE", _key, startRecord, endRecord, "WITHSCORES" }
    end
    local rankList = Common.redisExecute( redisCmd )
    if _showScore then
        local ranks = {}
        local temp
        local copyKey = string.format("%s_copy", _key )
        for i, rank in pairs(rankList) do
            if i%2 == 1 then
                temp = {}
                temp.member = rank
                local oldRank = snax.self().req.queryOneRecord( rank, copyKey )
                if oldRank then
                    temp.oldRank = oldRank
                end
            else
                temp.score = rank
                table.insert( ranks, temp )
            end
        end
        rankList = ranks
    else
        local ranks = {}
        local temp
        local copyKey = string.format("%s_copy", _key )
        for _, rank in pairs(rankList) do
            temp = {}
            temp.member = rank
            local oldRank = snax.self().req.queryOneRecord( rank, copyKey )
            if oldRank then
                temp.oldRank = oldRank
            end
            table.insert( ranks, temp )
        end
    end
    return rankList
end

---@see 插入排行版
function response.update( _member, _key, _score, _gameNode, _tableKey )
    local newKey
    if _tableKey then
        newKey = string.format( "%s_%d", _key, _tableKey )
    else
        newKey = _key
    end
    local redisCmd
    local copyKey = string.format("%s_copy", newKey )
    --local oldRank = snax.self().req.queryOneRecord( _member, copyKey)
    local oldRank = snax.self().req.getRank( _member, newKey, true )
    --redisCmd = string.format("DEL %s", copyKey)
    --Common.redisExecute( redisCmd )
    --Common.redisExecute( string.format("ZUNIONSTORE %s 2 %s %s", copyKey, copyKey, _key ) )
    redisCmd = { "ZADD", newKey, _score, _member }
    Common.redisExecute( redisCmd )
    local rank = snax.self().req.getRank( _member, newKey, true )
    if oldRank ~= rank then
        snax.self().req.updateDb( _key, _member, _score, _gameNode, oldRank or rank, _tableKey )
        redisCmd = { "ZADD", copyKey, oldRank or rank, _member }
        Common.redisExecute( redisCmd )
    else
        snax.self().req.updateDb( _key, _member, _score, _gameNode, nil, _tableKey )
    end
    return true
end

---@see 删除key
function accept.deleteKey( _key, _noDeleteDb, _tableKey )
    local newKey
    if _tableKey then
        newKey = string.format( "%s_%d", _key, _tableKey )
    else
        newKey = _key
    end
    local redisCmd = { "DEL", newKey }
    local copyKey = string.format( "%s_copy", newKey )
    if not _noDeleteDb then
        deleteDb( _key, nil, _tableKey )
    end
    Common.redisExecute( { "DEL", copyKey } )
    return Common.redisExecute( redisCmd )
end

---@see 查询某条记录
function response.queryOneRecord( _member, _key )
    local redisCmd = { "ZSCORE", _key, _member }
    return Common.redisExecute( redisCmd )
end

---@see 移除某条记录
function accept.deleteRecord( _key, _member, _tableKey )
    local redisCmd
    if _tableKey then
        redisCmd = { "ZREM", string.format("%s_%d", _key, _tableKey), _member }
    else
        redisCmd = { "ZREM", _key, _member }
    end
    local copyKey
    if _tableKey then
        copyKey = string.format("%s_%d_copy", _key, _tableKey )
    else
        copyKey = string.format("%s_copy", _key )
    end
    deleteDb( _key, _member, _tableKey )

    Common.redisExecute( { "ZREM", copyKey, _member } )
    return Common.redisExecute( redisCmd )
end

---@see 返回排行
function response.getRank( _member, _key, _MaxtoMin)
    local redisCmd =  { "ZRANK", _key, _member }
    local rank = Common.redisExecute( redisCmd )
    if not rank then return nil end
    if _MaxtoMin then
        rank = Common.redisExecute( { "ZCARD", _key } ) - rank
    end
    return rank
end

local function update( _key, _member, _score, _oldScore)
    local redisCmd
    if _oldScore then
        local copyKey = string.format("%s_copy", _key )
        redisCmd = { "ZADD", copyKey, _oldScore, _member }
        Common.redisExecute( redisCmd )
    end
    redisCmd = { "ZADD", _key, _score, _member }
    return Common.redisExecute( redisCmd )
end

---@see 初始化
function response.Init()
    local flag = skynet.getenv( "hellactivitycenter" )
    if not flag then
        local rankList = SM.c_role_power.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("role_power", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_alliance_power.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("alliance_power", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_alliance_kill.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("alliance_kill", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_alliance_flag.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("alliance_flag", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_role_kill.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("role_kill", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_townhall.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("townhall", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_role_collect_res.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("role_collect_res", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_reserve.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("reserve", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_combat_first.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("combat_first", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_rise_up.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("rise_up", rid, rankInfo.score, rankInfo.lastScore )
        end
        rankList = SM.c_kill_type.req.Get() or {}
        for id, rankInfo in pairs(rankList) do
            local ids = string.split(id, "_")
            local rid = tonumber(ids[1])
            local rankType = ids[2]
            if rankType then
                update(string.format("kill_type_%d", ids[2]), rid, rankInfo.score, rankInfo.lastScore )
            else
                update("kill_type_all", rid, rankInfo.score, rankInfo.lastScore )
            end
        end
        rankList = SM.c_expedition.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("expedition", rid, rankInfo.score, rankInfo.lastScore )
        end

        rankList = SM.c_tribe_king.req.Get() or {}
        for guildId, rankInfo in pairs(rankList) do
            update("tribe_king", guildId, rankInfo.score, rankInfo.lastScore )
        end

        rankList = SM.c_fight_horn.req.Get() or {}
        for rid, rankInfo in pairs(rankList) do
            update("fight_horn", rid, rankInfo.score, rankInfo.lastScore )
        end

        rankList = SM.c_fight_horn_alliance.req.Get() or {}
        for guildId, rankInfo in pairs(rankList) do
            update("fight_horn_alliance", guildId, rankInfo.score, rankInfo.lastScore )
        end

        local centerNode = Common.getCenterNode()
        -- 本服所有联盟ID
        local guildIds = Common.rpcCall( centerNode, "GuildProxy", "getGuildIds", Common.getSelfNodeName() ) or {}
        for guildId in pairs( guildIds ) do
            rankList = SM.c_guild_role_power.req.Get( guildId ) or {}
            for rid, rankInfo in pairs( rankList ) do
                update( string.format( "guild_role_power_%d", guildId ), rid, rankInfo.score, rankInfo.lastScore )
            end

            rankList = SM.c_guild_role_kill.req.Get( guildId ) or {}
            for rid, rankInfo in pairs( rankList ) do
                update( string.format( "guild_role_kill_%d", guildId ), rid, rankInfo.score, rankInfo.lastScore )
            end

            rankList = SM.c_guild_role_donate.req.Get( guildId ) or {}
            for rid, rankInfo in pairs( rankList ) do
                update( string.format( "guild_role_donate_%d", guildId ), rid, rankInfo.score, rankInfo.lastScore )
            end

            rankList = SM.c_guild_role_build.req.Get( guildId ) or {}
            for rid, rankInfo in pairs( rankList ) do
                update( string.format( "guild_role_build_%d", guildId ), rid, rankInfo.score, rankInfo.lastScore )
            end

            rankList = SM.c_guild_role_help.req.Get( guildId ) or {}
            for rid, rankInfo in pairs( rankList ) do
                update( string.format( "guild_role_help_%d", guildId ), rid, rankInfo.score, rankInfo.lastScore )
            end

            rankList = SM.c_guild_resource_help.req.Get( guildId ) or {}
            for rid, rankInfo in pairs( rankList ) do
                update( string.format( "guild_resource_help_%d", guildId ), rid, rankInfo.score, rankInfo.lastScore )
            end
        end
    else
        local rankList = SM.c_hell_activity_rank.req.Get() or {}
        for id, rankInfo in pairs(rankList) do
            local rid = tonumber(id)
            local age = rankInfo.rankType
            if age then
                update(string.format("hell_activity_%d", age), rid, rankInfo.score, rankInfo.lastScore )
            end
        end
    end

    --Timer.runEveryHour( saveHistory )
end