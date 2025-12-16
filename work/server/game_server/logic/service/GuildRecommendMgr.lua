--[[
* @file : GuildRecommendMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Thu Apr 09 2020 09:26:38 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟推荐服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Random = require "Random"

---@see 初始化
function response.Init()
    local centerNode = Common.getCenterNode()
    local guildIds = Common.rpcCall( centerNode, "GuildProxy", "queryGuilds", Common.getSelfNodeName() ) or {}

    local count = 0
    local cmds = {}
    for guildId, guildInfo in pairs( guildIds ) do
        if guildInfo.languageId == Enum.LanguageType.ALL and not guildInfo.needExamine then
            table.insert( cmds, { "ZADD", "GuildRecommendMain", guildInfo.power or 0, guildId } )
        end
        table.insert( cmds, { "ZADD", string.format("GuildRecommendJoin_%d", guildInfo.languageId), guildInfo.power or 0, guildId } )
        count = count + 1
        if count >= 200 then
            count = 0
            Common.redisExecute( cmds, 0, true )
            cmds = {}
        end
    end

    if count > 0 then
        Common.redisExecute( cmds, 0, true )
    end
end

---@see 获取推荐的联盟Id
function response.getRecommendGuilds( _type, _languageId )
    local guildRate = {}
    local guildNum
    local gameNode = Common.getSelfNodeName()
    if _type == Enum.GuildSearchType.MAIN_WIN then
        -- 主界面推荐
        guildNum = 1
        local allianceInviteNumLimit = CFG.s_Config:Get( "allianceInviteNumLimit" ) or 10
        local ret = Common.redisExecute( { "ZREVRANGE", "GuildRecommendMain", 0, allianceInviteNumLimit - 1 } ) or {}
        for _, guildId in pairs( ret ) do
            table.insert( guildRate, { id = { guildId = tonumber( guildId ), gameNode = gameNode }, rate = 1 } )
        end
    elseif _type == Enum.GuildSearchType.JOIN_WIN then
        -- 加入联盟界面推荐
        guildNum = 30
        local guild
        local guildList = {}
        local ret = Common.redisExecute( { "ZREVRANGE", string.format("GuildRecommendJoin_%d", Enum.LanguageType.ALL), 0, guildNum - 1, "WITHSCORES" } ) or {}
        table.merge( ret, Common.redisExecute( { "ZREVRANGE", string.format( "GuildRecommendJoin_%d", _languageId ),  0, guildNum - 1, "WITHSCORES" } ) or {} )
        for index, value in pairs( ret ) do
            if index % 2 == 1 then
                guild = {}
                guild.guildId = tonumber( value )
            else
                guild.power = tonumber( value )
                table.insert( guildList, guild )
            end
        end
        table.sort( guildList, function ( a, b ) return a.power > b.power end )
        for i = 1, guildNum do
            if not guildList[i] then
                break
            end
            table.insert( guildRate, { id = { guildId = guildList[i].guildId, gameNode = gameNode } } )
        end
    end

    local guilds = {}
    if #guildRate > guildNum then
        guilds = Random.GetIds( guildRate, guildNum )
    else
        for _, guild in pairs( guildRate ) do
            table.insert( guilds, guild.id )
        end
    end

    return guilds
end

---@see 增加成员数不满联盟
function accept.addGuildId( _guildId, _needExamine, _languageId, _power )
    local cmds = {}
    if _languageId == Enum.LanguageType.ALL and not _needExamine then
        table.insert( cmds, { "ZADD", "GuildRecommendMain", _power, _guildId } )
    end
    table.insert( cmds, { "ZADD", string.format("GuildRecommendJoin_%d", _languageId), _power, _guildId } )
    Common.redisExecute( cmds, 0, true )
end

---@see 删除成员数已满或解散的联盟
function accept.delGuildId( _guildId, _languageId )
    local cmds = {
        { "ZREM", "GuildRecommendMain", _guildId },
        { "ZREM", string.format( "GuildRecommendJoin_%d", _languageId), _guildId }
    }
    Common.redisExecute( cmds, 0, true )
end

---@see 联盟信息修改
function accept.modifyGuildInfo( _guildId, _oldGuildInfo, _newGuildInfo )
    local cmds = {}
    table.insert( cmds, { "ZREM", "GuildRecommendMain", _guildId } )
    table.insert( cmds, { "ZREM", string.format( "GuildRecommendJoin_%d ", _oldGuildInfo.languageId), _guildId } )

    if not _newGuildInfo.needExamine and _newGuildInfo.languageId == Enum.LanguageType.ALL then
        table.insert( cmds, { "ZADD", "GuildRecommendMain", _newGuildInfo.power, _guildId } )
    end
    table.insert( cmds, { "ZADD", string.format( "GuildRecommendJoin_%d", _newGuildInfo.languageId), _newGuildInfo.power, _guildId } )
    Common.redisExecute( cmds, 0, true )
end