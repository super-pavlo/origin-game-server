--[[
* @file : GuildNameMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Tue Apr 07 2020 19:26:18 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟名称简称管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local Random = require "Random"

local guildList = {}

function init( index )
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

---@see 初始化
function response.Init()

end

---@see 检查联盟名称是否被占用
function response.checkGuildNameRepeat( _, _name )
    -- 检测是否重名
    local nameInfo = SM.c_guild_name.req.Get( _name )
    if nameInfo and not table.empty( nameInfo ) then
        return true
    end
    return false
end

---@see 检查联盟简称是否被占用
function response.checkGuildAbbNameRepeat( _, _abbreviationName )
    -- 检测是否重名
    local nameInfo = SM.c_guild_abbname.req.Get( _abbreviationName )
    if nameInfo and not table.empty( nameInfo ) then
        return true
    end
    return false
end

---@see 占用联盟名称简称
function response.addGuildNameAndAbbName( _, _name, _abbreviationName )
    -- 插入联盟名称表
    local ret = SM.c_guild_name.req.Add( _name, { name = _name } )
    if not ret then
        LOG_ERROR("addGuildNameAndAbbName, add name(%s) to c_guild_name fail", _name)
        return Enum.GuildNameRepeat.NAME
    end

    -- 插入联盟简称表
    ret = SM.c_guild_abbname.req.Add( _abbreviationName, { abbreviationName = _abbreviationName } )
    if not ret then
        LOG_ERROR("addGuildNameAndAbbName, add abbreviationName(%s) to c_guild_abbname fail", _abbreviationName)
        SM.c_guild_name.req.Delete( _name )
        return Enum.GuildNameRepeat.ABB_NAME
    end

    return Enum.GuildNameRepeat.NO_REPEAT
end

---@see 删除联盟名称
function accept.delGuildNameAndAbbName( _, _name, _abbreviationName )
    SM.c_guild_name.req.Delete( _name )
    SM.c_guild_abbname.req.Delete( _abbreviationName )
end

---@see 更新联盟名称简称到redis
function accept.addRedisGuildName( _, _guildInfos )
    local cmds = {}
    local count = 0
    for _, guildInfo in pairs( _guildInfos ) do
        table.insert(
            cmds,
            { "HSET", "GuildName", guildInfo.name, string.format("%s_%d", guildInfo.gameNode, guildInfo.guildId ) }
        )
        table.insert(
            cmds,
            { "HSET", "GuildAbbName", guildInfo.abbreviationName, string.format("%s_%d", guildInfo.gameNode, guildInfo.guildId ) }
        )

        count = count + 2
        if count >= 100 then
            count = 0
            Common.redisExecute( cmds, 0, true )
            cmds = {}
        end

        MSM.GuildNameMgr[guildInfo.guildId].post.addGuildInfo( guildInfo )
    end

    if count > 0 then
        Common.redisExecute( cmds, 0, true )
    end
end

---@see 删除redis联盟名称简称
function accept.delRedisGuildName( _guildId, _name, _abbreviationName )
    local cmds = {}
    table.insert( cmds, { "HDEL", "GuildName", _name } )
    table.insert( cmds, { "HDEL", "GuildAbbName", _abbreviationName } )

    Common.redisExecute( cmds, 0, true )
    guildList[_guildId] = nil
end

---@see 增加联盟信息
function accept.addGuildInfo( _guildInfo )
    guildList[_guildInfo.guildId] = {
        gameNode = _guildInfo.gameNode,
    }
end

---@see 获取联盟所在game服
function response.getGuildGameNode( _guildId )
    if guildList[_guildId] then
        return guildList[_guildId].gameNode
    end
end

---@see 根据关键字搜索联盟简称和名称
function response.searchGuildByKeyName( _, _keyName )
    local guildRate = {}
    local redisKeys = { "GuildName", "GuildAbbName" }
    local matchKey = string.format( "%s*", _keyName )
    local matchInfo, guildInfo, guildId
    local guildIds = {}
    for _, redisKey in pairs( redisKeys ) do
        matchInfo = Common.scanQuery( "HSCAN", redisKey, matchKey, nil, true )
        for _, value in pairs( matchInfo ) do
            guildInfo = string.split( value, "_" )
            guildId = tonumber(guildInfo[2])
            if guildId and not guildIds[guildId] then
                table.insert( guildRate, { id = { gameNode = guildInfo[1], guildId = guildId }, rate = 1 } )
                guildIds[guildId] = true
            end
        end
    end

    local guild = {}
    if #guildRate > 50 then
        guild = Random.GetIds( guildRate, 50 )
    else
        for _, rate in pairs( guildRate ) do
            table.insert( guild, rate.id )
        end
    end
    return guild
end

---@see 检查角色名称是否被占用
function response.checkRoleNameRepeat( _, _name )
    -- 检测是否重名
    local nameInfo = SM.c_role_name.req.Get( _name )
    if nameInfo and not table.empty( nameInfo ) then
        return true, nameInfo
    end
    return false
end

---@see 占用角色名称
function response.addRoleName( _, _name, _rid, _gameNode )
    -- 插入联盟名称表
    local ret = SM.c_role_name.req.Add( _name, { name = _name, rid = _rid, gameNode = _gameNode } )
    if not ret then
        LOG_ERROR("addRoleName, add name(%s) to c_role_name fail", _name)
        return false
    end
    return true
end

---@see 删除角色名称
function accept.delRoleName( _, _name )
    SM.c_role_name.req.Delete( _name )
end

---@see 修改联盟名称
function response.modifyGuildName( _, _guildId, _guildNode, _name, _oldName )
    -- 插入联盟名称表
    local ret = SM.c_guild_name.req.Add( _name, { name = _name } )
    if not ret then
        LOG_ERROR("modifyGuildName, add name(%s) to c_guild_name fail", _name)
        return Enum.GuildNameRepeat.NAME
    end

    -- 删除旧的联盟名称
    SM.c_guild_name.req.Delete( _oldName )

    -- 更新联盟名称到redis
    local cmds = {}
    table.insert( cmds, { "HDEL", "GuildName", _oldName } )
    table.insert( cmds, { "HSET", "GuildName", _name, string.format("%s_%d", _guildNode, _guildId ) } )

    Common.redisExecute( cmds, 0, true )

    return Enum.GuildNameRepeat.NO_REPEAT
end

---@see 修改联盟简称
function response.modifyGuildAbbName( _, _guildId, _guildNode, _abbName, _oldAbbName )
    -- 插入联盟简称表
    local ret = SM.c_guild_abbname.req.Add( _abbName, { abbreviationName = _abbName } )
    if not ret then
        LOG_ERROR("modifyGuildAbbName, add abbreviationName(%s) to c_guild_abbname fail", _abbName)
        return Enum.GuildNameRepeat.ABB_NAME
    end

    -- 删除旧的联盟简称
    SM.c_guild_abbname.req.Delete( _oldAbbName )

    -- 更新联盟简称到redis
    local cmds = {}
    table.insert( cmds, { "HDEL", "GuildAbbName", _oldAbbName } )
    table.insert( cmds, { "HSET", "GuildAbbName", _abbName, string.format("%s_%d", _guildNode, _guildId ) } )

    Common.redisExecute( cmds, 0, true )

    return Enum.GuildNameRepeat.NO_REPEAT
end