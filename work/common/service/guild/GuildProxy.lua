--[[
* @file : GuildProxy.lua
* @type : snax single service
* @author : dingyuchao 九   零 一 起 玩 w w w . 9 0  1 7 5 . co m
* @created : Wed Apr 08 2020 18:21:22 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟信息获取代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local EntityImpl = require "EntityImpl"

---@see 初始化
function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

---@see 获取成员人数不满的联盟id
function response.queryGuilds( _gameNode )
    local allGuilds = {}
    local index = 0
    local indexLimit = 1000

    local cmd, sqlRet, decodeRow
    while true do
        cmd = string.format( "select * from c_guild limit %d,%d", index, indexLimit )
        sqlRet = Common.mysqlExecute( cmd )
        if #sqlRet <= 0 then
            break
        end

        for _, row in pairs( sqlRet ) do
            assert(table.size(row) >= 2, "mysql table(c_guild) schema must be key-value")
            decodeRow = EntityImpl:unserializeSproto( "c_guild", row.value )
            if ( not _gameNode or _gameNode == decodeRow.gameNode ) and table.size( decodeRow.members ) < decodeRow.memberLimit then
                allGuilds[row.guildId] = {
                    needExamine = decodeRow.needExamine,
                    languageId = decodeRow.languageId,
                    power = decodeRow.power,
                }
            end
        end

        index = index + #sqlRet
    end

    return allGuilds
end

---@see 获取成员人数不满的联盟id
function response.queryGuildMemberCount( _gameNode )
    local allGuilds = {}
    local index = 0
    local indexLimit = 1000

    local cmd, sqlRet, decodeRow
    while true do
        cmd = string.format( "select * from c_guild limit %d,%d", index, indexLimit )
        sqlRet = Common.mysqlExecute( cmd )
        if #sqlRet <= 0 then
            break
        end

        for _, row in pairs( sqlRet ) do
            assert(table.size(row) >= 2, "mysql table(c_guild) schema must be key-value")
            decodeRow = EntityImpl:unserializeSproto( "c_guild", row.value )
            if ( not _gameNode or _gameNode == decodeRow.gameNode ) then
                allGuilds[row.guildId] = {
                    size = table.size(decodeRow.members),
                }
            end
        end

        index = index + #sqlRet
    end

    return allGuilds
end

---@see 查询所有的联盟ID
function response.getGuildIds( _gameNode )
    local guildIds = {}
    local allGuilds = SM.c_guild.req.Get()
    for guildId, guildInfo in pairs( allGuilds or {} ) do
        if not _gameNode or _gameNode == guildInfo.gameNode then
            guildIds[guildId] = guildId
        end
    end

    return guildIds
end

---@see 查询所有的联盟信息
function response.getGuildInfos( _gameNode )
    local guilds = {}
    local allGuilds = SM.c_guild.req.Get()
    for guildId, guildInfo in pairs( allGuilds or {} ) do
        if not _gameNode or _gameNode == guildInfo.gameNode then
            guilds[guildId] = {
                researchTechnologyType = guildInfo.researchTechnologyType
            }
        end
    end

    return guilds
end