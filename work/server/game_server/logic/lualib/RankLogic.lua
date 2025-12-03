--[[
* @file : RankLogic.lua
* @type : lualib
* @author : chenlei
* @created : Mon Apr 20 2020 16:31:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 排行版相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local BuildingLogic = require "BuildingLogic"
local GuildLogic = require "GuildLogic"
local RoleLogic = require "RoleLogic"

local RankLogic = {}

---@see 更新排行版数据
function RankLogic:update( _id, _type, _score, _tableKey, _star )
    local sLeaderboard = CFG.s_Leaderboard:Get(_type)
    if not table.empty(sLeaderboard.level) then
        local level = BuildingLogic:getBuildingLv( _id, Enum.BuildingType.TOWNHALL )
        if level < sLeaderboard.level[1] or (sLeaderboard.level[2] and level > sLeaderboard.level[2]) then
            return
        end
    end
    local key = self:getKey( _type )
    local oldScore, star
    local selfNode = Common.getSelfNodeName()
    local guildNameCenter
    if _type == Enum.RankType.HELL_ORIGINAL or _type == Enum.RankType.HELL_CLASSICAL or _type == Enum.RankType.HELL_DARK or _type == Enum.RankType.HELL_FEUDAL or 
    _type == Enum.RankType.HELL_INDUSTRY or _type == Enum.RankType.HELL_MODERN then
        local allNodes = Common.getClusterNodeByName( "center", true ) or {}
        for _, nodeName in pairs( allNodes ) do
            guildNameCenter = Common.rpcCall( nodeName, "HellActivityPorxy", "getGuildNameCenter" )
            if guildNameCenter then
                oldScore = Common.rpcMultiCall( nodeName, "RankMgr", "queryOneRecord", _id, key )
                break
            end
        end
    else
        local newKey = self:getKey( _type, _tableKey )
        oldScore = MSM.RankMgr[_id].req.queryOneRecord( _id, newKey )
    end
    if oldScore then
        oldScore, star = self:getScore( oldScore, _type )
        oldScore = tonumber(oldScore)
    else
        oldScore = 0
    end
    if (not _score or _score <= 0 or _score == oldScore) and _type ~= Enum.RankType.ALLIANCE_KILL then
        _score = 0
        if _type == Enum.RankType.ROLE_KILL or _type == Enum.RankType.ALLIACEN_ROLE_KILL then
            local killCount = RoleLogic:getRole( _id, Enum.Role.killCount )
            for _, killInfo in pairs( killCount or {} ) do
                _score = _score + killInfo.count
            end
            if not _score or ( oldScore > 0 and _score == oldScore ) then
                return
            end
        -- elseif _type == Enum.RankType.ALLIANCE_KILL then
        --     local roleKillCount
        --     local members = GuildLogic:getGuild( _id, Enum.Guild.members )
        --     for memberRid in pairs( members ) do
        --         roleKillCount = RoleLogic:getRole( memberRid, Enum.Role.killCount )
        --         for _, killInfo in pairs( roleKillCount or {} ) do
        --             _score = _score + killInfo.count
        --         end
        --     end
        --     if not _score or ( oldScore > 0 and _score == oldScore ) then
        --         return
        --     end
        elseif _type == Enum.RankType.ALLIANCE_FLAG then
            if _score == oldScore then
                return
            end
        elseif not ( _type == Enum.RankType.ALLIACEN_ROLE_DONATE or _type == Enum.RankType.ALLIACEN_ROLE_HELP
            or _type == Enum.RankType.ALLIACEN_ROLE_BUILD or _type == Enum.RankType.ALLIACEN_ROLE_RES_HELP ) then
            if _type == Enum.RankType.EXPEDITION then
                if _star <= star then
                    return
                end
            else
                return
            end
        end
    else
        if _type == Enum.RankType.EXPEDITION then
            if _score < oldScore then
                return
            end
        end
    end
    if _type == Enum.RankType.ALLIANCE_KILL then
        _score = _score + oldScore
    end
    if _type == Enum.RankType.ALLIANCE_FLAG or _type == Enum.RankType.MAIN_TOWN_LEVEL or _type == Enum.RankType.ALLIACEN_ROLE_DONATE
        or _type == Enum.RankType.ALLIACEN_ROLE_HELP or _type == Enum.RankType.ALLIACEN_ROLE_BUILD then
        local time_score = Enum.RankCommon.MAXTIME - os.time()
        --高32位存分数,低32bit 用来放时间
        _score = ( _score << 32 ) | ( time_score & 0xFFFFFFFF )
    end
    if _type == Enum.RankType.EXPEDITION then
        local time_score = Enum.RankCommon.MAXTIME - os.time()
        if _score == oldScore then
            local newKey = self:getKey( _type, _tableKey )
            oldScore = MSM.RankMgr[_id].req.queryOneRecord( _id, newKey )
            _score = oldScore - star +  _star
        else
            --高32位存分数,低32bit 用来放时间
            _score = ( ( _score << 32 ) | ( time_score & 0xFFFFFFFF ) ) * 10 + _star
        end
    end
    if _type == Enum.RankType.HELL_ORIGINAL or _type == Enum.RankType.HELL_CLASSICAL or _type == Enum.RankType.HELL_DARK or _type == Enum.RankType.HELL_FEUDAL or 
        _type == Enum.RankType.HELL_INDUSTRY or _type == Enum.RankType.HELL_MODERN then
        if guildNameCenter then
            Common.rpcMultiCall( guildNameCenter, "RankMgr", "update", _id, key, _score, selfNode )
        end
    else
        MSM.RankMgr[_id].req.update( _id, key, _score, selfNode, _tableKey )
    end
end


---@see 删除排行版数据
function RankLogic:delete( _id, _type, _tableKey )
    local key = self:getKey( _type )
    MSM.RankMgr[_id].post.deleteRecord( key, _id, _tableKey )
end

---@see 查询排行版
function RankLogic:queryRank( _rid, _type, _num )
    local tableKey
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headFrameID, Enum.Role.headId })
    if _type == Enum.RankType.ALLIACEN_ROLE_BUILD or _type == Enum.RankType.ALLIACEN_ROLE_DONATE
        or _type == Enum.RankType.ALLIACEN_ROLE_HELP or _type == Enum.RankType.ALLIACEN_ROLE_KILL
        or _type == Enum.RankType.ALLIACEN_ROLE_POWER or _type == Enum.RankType.ALLIACEN_ROLE_RES_HELP then
        tableKey = roleInfo.guildId
    end
    local key = self:getKey( _type, tableKey )
    local sLeaderboard = CFG.s_Leaderboard:Get(_type)
    local rankInfos = MSM.RankMgr[_rid].req.queryRank( key, 1, _num or sLeaderboard.showLimit, true )
    local returnInfo = {}
    local rankList = {}
    if _type == Enum.RankType.ALLIANCE_POWER or _type == Enum.RankType.ALLIANCE_KILL or _type == Enum.RankType.ALLIANCE_FLAG or
        _type == Enum.RankType.FIGHT_HORN_ALLIANCE or _type == Enum.RankType.TRIBE_KING then
        for i, rankInfo in pairs( rankInfos ) do
            local member = tonumber(rankInfo.member)
            local score = self:getScore( tonumber(rankInfo.score), _type )
            local guildInfo = GuildLogic:getGuildInfo( member ) or {}
            if guildInfo.leaderRid and guildInfo.leaderRid > 0 then
                local leaderName = RoleLogic:getRole( guildInfo.leaderRid, Enum.Role.name )
                table.insert( rankList, { guildId  = member , score = score, signs = guildInfo.signs, guildName = guildInfo.name, index = i,
                                abbreviationName = guildInfo.abbreviationName, leaderName = leaderName, oldRank = rankInfo.oldRank or i } )
            end
        end
        if roleInfo.guildId and roleInfo.guildId > 0 then
            local rank = MSM.RankMgr[_rid].req.getRank( roleInfo.guildId, key, true )
            local oldRank = MSM.RankMgr[_rid].req.queryOneRecord( roleInfo.guildId, string.format( "%s_copy", key ) )
            returnInfo.selfRank = rank
            returnInfo.selfOldRank = oldRank or rank
            local score = self:getScore( MSM.RankMgr[roleInfo.guildId].req.queryOneRecord( roleInfo.guildId, key ), _type )
            returnInfo.score = score
        end
        returnInfo.rankList = rankList
    elseif _type == Enum.RankType.ROLE_POWER or _type == Enum.RankType.ROLE_KILL or _type == Enum.RankType.MAIN_TOWN_LEVEL
        or _type == Enum.RankType.ROLE_RES or _type == Enum.RankType.COMBAT_FIRST or _type == Enum.RankType.RISE_UP
        or _type == Enum.RankType.RESERVE or _type == Enum.RankType.EXPEDITION or _type == Enum.RankType.MGE_TOTAL
        or _type == Enum.RankType.ALLIACEN_ROLE_BUILD or _type == Enum.RankType.ALLIACEN_ROLE_DONATE
        or _type == Enum.RankType.ALLIACEN_ROLE_HELP or _type == Enum.RankType.ALLIACEN_ROLE_KILL
        or _type == Enum.RankType.ALLIACEN_ROLE_POWER or _type == Enum.RankType.ALLIACEN_ROLE_RES_HELP
        or _type == Enum.RankType.FIGHT_HORN then
        for i, rankInfo in pairs( rankInfos ) do
            local member = tonumber(rankInfo.member)
            local score = self:getScore( tonumber(rankInfo.score), _type )
            local abbreviationName
            local guildName
            local role = RoleLogic:getRole( member, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headFrameID, Enum.Role.headId })
            if role.guildId and role.guildId > 0 then
                local guildInfo = GuildLogic:getGuildInfo( role.guildId ) or {}
                abbreviationName = guildInfo.abbreviationName
                guildName = guildInfo.name
            end
            table.insert( rankList, { rid  = member , score = score, headFrameID = role.headFrameID, name = role.name, index = i,
                                        abbreviationName = abbreviationName, guildName = guildName, oldRank = rankInfo.oldRank or i, headId = role.headId } )
        end
        local rank = MSM.RankMgr[_rid].req.getRank( _rid, key, true)
        local oldRank = MSM.RankMgr[_rid].req.queryOneRecord( _rid, string.format( "%s_copy", key ))
        local score = self:getScore( MSM.RankMgr[_rid].req.queryOneRecord( _rid, key ), _type )
        returnInfo.selfRank = rank
        returnInfo.selfOldRank = oldRank or rank
        returnInfo.score = score
        returnInfo.rankList = rankList
    end
    returnInfo.type = _type
    return returnInfo
end

function RankLogic:getRank( _member, _type, _MaxtoMin )
    local key = self:getKey( _type )
    local rank
    local guildNameCenter
    if _type == Enum.RankType.HELL_ORIGINAL or _type == Enum.RankType.HELL_CLASSICAL or _type == Enum.RankType.HELL_DARK or _type == Enum.RankType.HELL_FEUDAL or 
    _type == Enum.RankType.HELL_INDUSTRY or _type == Enum.RankType.HELL_MODERN then
        local allNodes = Common.getClusterNodeByName( "center", true ) or {}
        for _, nodeName in pairs( allNodes ) do
            guildNameCenter = Common.rpcCall( nodeName, "HellActivityPorxy", "getGuildNameCenter" )
            if guildNameCenter then
                rank = Common.rpcMultiCall( nodeName, "RankMgr", "getRank", _member, key, _MaxtoMin )
                break
            end
        end
    else
        rank = MSM.RankMgr[_member].req.getRank( _member, key, _MaxtoMin )
    end
    return rank
end

function RankLogic:getKey( _type, _tableKey )
    if _type == Enum.RankType.ALLIANCE_POWER then
        return "alliance_power"
    elseif _type == Enum.RankType.ALLIANCE_KILL then
        return "alliance_kill"
    elseif _type == Enum.RankType.ALLIANCE_FLAG then
        return "alliance_flag"
    elseif _type == Enum.RankType.ROLE_POWER then
        return "role_power"
    elseif _type == Enum.RankType.ROLE_KILL then
        return "role_kill"
    elseif _type == Enum.RankType.MAIN_TOWN_LEVEL then
        return "townhall"
    elseif _type == Enum.RankType.ROLE_RES then
        return "role_collect_res"
    elseif _type == Enum.RankType.COMBAT_FIRST then
        return "combat_first"
    elseif _type == Enum.RankType.RISE_UP then
        return "rise_up"
    elseif _type == Enum.RankType.RESERVE then
        return "reserve"
    elseif _type == Enum.RankType.MGE_TOTAL then
        return "kill_type_all"
    elseif _type == Enum.RankType.MGE_TARIN then
        return "kill_type_1"
    elseif _type == Enum.RankType.MGE_KILL_BARB then
        return "kill_type_2"
    elseif _type == Enum.RankType.MGE_COLLECT_RES then
        return "kill_type_3"
    elseif _type == Enum.RankType.MGE_POWER_UP then
        return "kill_type_4"
    elseif _type == Enum.RankType.MGE_KILL then
        return "kill_type_5"
    elseif _type == Enum.RankType.HELL_ORIGINAL then
        return "hell_activity_1"
    elseif _type == Enum.RankType.HELL_CLASSICAL then
        return "hell_activity_2"
    elseif _type == Enum.RankType.HELL_DARK then
        return "hell_activity_3"
    elseif _type == Enum.RankType.HELL_FEUDAL then
        return "hell_activity_4"
    elseif _type == Enum.RankType.HELL_INDUSTRY then
        return "hell_activity_5"
    elseif _type == Enum.RankType.HELL_MODERN then
        return "hell_activity_6"
    elseif _type == Enum.RankType.EXPEDITION then
        --return "townhall"
        return "expedition"
    elseif _type == Enum.RankType.FIGHT_HORN then
        return "fight_horn"
    elseif _type == Enum.RankType.TRIBE_KING then
        return "tribe_king"
    elseif _type == Enum.RankType.FIGHT_HORN_ALLIANCE then
        return "fight_horn_alliance"
    elseif _type == Enum.RankType.ALLIACEN_ROLE_POWER then
        if _tableKey then
            return string.format( "guild_role_power_%d", _tableKey )
        else
            return "guild_role_power"
        end
    elseif _type == Enum.RankType.ALLIACEN_ROLE_KILL then
        if _tableKey then
            return string.format( "guild_role_kill_%d", _tableKey )
        else
            return "guild_role_kill"
        end
    elseif _type == Enum.RankType.ALLIACEN_ROLE_DONATE then
        if _tableKey then
            return string.format( "guild_role_donate_%d", _tableKey )
        else
            return "guild_role_donate"
        end
    elseif _type == Enum.RankType.ALLIACEN_ROLE_BUILD then
        if _tableKey then
            return string.format( "guild_role_build_%d", _tableKey )
        else
            return "guild_role_build"
        end
    elseif _type == Enum.RankType.ALLIACEN_ROLE_HELP then
        if _tableKey then
            return string.format( "guild_role_help_%d", _tableKey )
        else
            return "guild_role_help"
        end
    elseif _type == Enum.RankType.ALLIACEN_ROLE_RES_HELP then
        if _tableKey then
            return string.format( "guild_resource_help_%d", _tableKey )
        else
            return "guild_resource_help"
        end
    end
end

---@see 解析分数
function RankLogic:getScore( _score, _type )
    _score = tonumber(_score) or 0
    if _type == Enum.RankType.ALLIANCE_FLAG or _type == Enum.RankType.MAIN_TOWN_LEVEL or _type == Enum.RankType.ALLIACEN_ROLE_DONATE
        or _type == Enum.RankType.ALLIACEN_ROLE_HELP or _type == Enum.RankType.ALLIACEN_ROLE_BUILD then
        return _score >> 32
    elseif _type == Enum.RankType.EXPEDITION then
        local star = _score % 10
        _score = _score / 10 // 1
        return _score >> 32, star
    end
    return _score
end

---@see 查询某个成员数据
function RankLogic:queryOneRecord( _memeber, _type )
    local key = self:getKey( _type )
    local score
    local guildNameCenter
    if _type == Enum.RankType.HELL_ORIGINAL or _type == Enum.RankType.HELL_CLASSICAL or _type == Enum.RankType.HELL_DARK or _type == Enum.RankType.HELL_FEUDAL or 
    _type == Enum.RankType.HELL_INDUSTRY or _type == Enum.RankType.HELL_MODERN then
        local allNodes = Common.getClusterNodeByName( "center", true ) or {}
        for _, nodeName in pairs( allNodes ) do
            guildNameCenter = Common.rpcCall( nodeName, "HellActivityPorxy", "getGuildNameCenter" )
            if guildNameCenter then
                score = Common.rpcMultiCall( nodeName, "RankMgr", "queryOneRecord", _memeber, key )
                break
            end
        end
    else
        score = MSM.RankMgr[_memeber].req.queryOneRecord( _memeber, key )
    end
    return self:getScore( score, _type )
end

---@see 登陆处理排行版
function RankLogic:roleLogin( _rid )
    local roleInfo = RoleLogic:getRole( _rid )
    local resNum = 0
    if roleInfo.roleStatistics and roleInfo.roleStatistics[Enum.RoleStatisticsType.RESOURCE_COLLECT] and
        roleInfo.roleStatistics[Enum.RoleStatisticsType.RESOURCE_COLLECT].num > 0 then
        resNum = roleInfo.roleStatistics[Enum.RoleStatisticsType.RESOURCE_COLLECT].num
    end
    if resNum > 0 then
        self:update( _rid, Enum.RankType.ROLE_RES, resNum )
    end
    self:update( _rid, Enum.RankType.ROLE_POWER, roleInfo.combatPower )
    self:update( _rid, Enum.RankType.MAIN_TOWN_LEVEL, roleInfo.level )
    self:update( _rid, Enum.RankType.ROLE_KILL )
    if roleInfo.guildId and roleInfo.guildId > 0 then
        self:update( _rid, Enum.RankType.ALLIACEN_ROLE_POWER, roleInfo.combatPower, roleInfo.guildId )
    end
end

---@see 查询排行版第一
function RankLogic:showRankFirst( _rid, _type )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    local rankType
    local guildRoleRankTypes = {
        Enum.RankType.ALLIACEN_ROLE_BUILD, Enum.RankType.ALLIACEN_ROLE_DONATE, Enum.RankType.ALLIACEN_ROLE_HELP,
        Enum.RankType.ALLIACEN_ROLE_KILL, Enum.RankType.ALLIACEN_ROLE_POWER, Enum.RankType.ALLIACEN_ROLE_RES_HELP,
    }
    if _type and _type == Enum.RankQueryType.GUILD then
        rankType = guildRoleRankTypes
    else
        rankType = {
            Enum.RankType.ALLIANCE_POWER, Enum.RankType.ALLIANCE_KILL, Enum.RankType.ALLIANCE_FLAG, Enum.RankType.ROLE_POWER,
            Enum.RankType.ROLE_KILL, Enum.RankType.MAIN_TOWN_LEVEL, Enum.RankType.ROLE_RES, Enum.RankType.EXPEDITION,
        }
    end
    local key, rankInfos
    local rankInfo = {}
    for _, type in pairs(rankType) do
        if table.exist( guildRoleRankTypes, type ) then
            key = self:getKey( type, guildId )
        else
            key = self:getKey( type )
        end
        rankInfos = MSM.RankMgr[0].req.queryRank( key, 1, 1, true )
        if type == Enum.RankType.ALLIANCE_POWER or type == Enum.RankType.ALLIANCE_KILL or type == Enum.RankType.ALLIANCE_FLAG then
            for _, rank in pairs( rankInfos ) do
                local member = tonumber(rank.member)
                local guildInfo = GuildLogic:getGuildInfo( member )
                local leaderName = RoleLogic:getRole( guildInfo.leaderRid, Enum.Role.name )
                rankInfo[type] = { type = type, abbreviationName = guildInfo.abbreviationName, guildName = guildInfo.name, leaderName = leaderName}
            end
        elseif type == Enum.RankType.ROLE_POWER or type == Enum.RankType.ROLE_KILL or type == Enum.RankType.MAIN_TOWN_LEVEL
            or type == Enum.RankType.ROLE_RES or type == Enum.RankType.EXPEDITION then
            for _, rank in pairs( rankInfos ) do
                local member = tonumber(rank.member)
                local abbreviationName
                local guildName
                local roleInfo = RoleLogic:getRole( member, { Enum.Role.guildId, Enum.Role.name })
                if roleInfo.guildId then
                    local guildInfo = GuildLogic:getGuildInfo( roleInfo.guildId )
                    abbreviationName = guildInfo.abbreviationName
                    guildName = guildInfo.name
                end
                rankInfo[type] = { type = type , abbreviationName = abbreviationName, guildName = guildName, name = roleInfo.name }
            end
        elseif type == Enum.RankType.ALLIACEN_ROLE_BUILD or type == Enum.RankType.ALLIACEN_ROLE_DONATE or type == Enum.RankType.ALLIACEN_ROLE_HELP
            or type == Enum.RankType.ALLIACEN_ROLE_KILL or type == Enum.RankType.ALLIACEN_ROLE_POWER or type == Enum.RankType.ALLIACEN_ROLE_RES_HELP then
            for _, rank in pairs( rankInfos ) do
                local member = tonumber(rank.member)
                rankInfo[type] = { type = type, name = RoleLogic:getRole( member, Enum.Role.name ) }
            end
        end
    end
    return { rankInfo = rankInfo }
end


return RankLogic