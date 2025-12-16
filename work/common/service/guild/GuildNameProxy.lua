--[[
* @file : GuildNameProxy.lua
* @type : snax single service
* @author : dingyuchao 九  零 一  起 玩 w w w . 9 0 1  7 5 . co m
* @created : Tue Apr 07 2020 20:28:46 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟名称简称代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local skynet = require "skynet"
local EntityImpl = require "EntityImpl"

local guildNameCenter
local index = 0

---@see 读取联盟信息
local function getGuildInfo( _index, _indexLimit )
    local guilds = {}
    _index = _index or 0
	_indexLimit = _indexLimit or 2000

	local cmd = string.format( "select * from c_guild limit %d,%d", _index, _indexLimit )
	local sqlRet = Common.mysqlExecute( cmd )
	if #sqlRet <= 0 then return guilds end

	local decodeRow
	for _, row in pairs(sqlRet) do
		assert(table.size(row) >= 2, "mysql table(c_guild) schema must be key-value")
        decodeRow = EntityImpl:unserializeSproto( "c_guild", row.value )
        table.insert(
            guilds,
            {
                guildId = decodeRow.guildId,
                name = decodeRow.name,
                abbreviationName = decodeRow.abbreviationName,
                gameNode = decodeRow.gameNode,
            }
        )
	end

    return guilds
end

---@see 获取联盟信息
function response.getCenterGuildInfo( _centerNode, _index, _indexLimit )
    if _centerNode ~= Common.getSelfNodeName() then
        return Common.rpcCall( _centerNode, "GuildNameProxy", "getCenterGuildInfo", index, _indexLimit )
    else
        return getGuildInfo( _index, _indexLimit )
    end
end

local function initGuildNameCenter()
    local selfNode = Common.getSelfNodeName()
    local flag = skynet.getenv( "guildnamecenter" )
    if flag == "true" then
        -- 通知其他的game和center服
        local allNodes = Common.getClusterNodeByName( "game", true ) or {}
        table.merge( allNodes, Common.getClusterNodeByName( "center", true ) or {} )
        for _, nodeName in pairs( allNodes ) do
            if selfNode ~= nodeName then
                Common.rpcCall( nodeName, "GuildNameProxy", "updateGuildNameCenter", selfNode )
            else
                guildNameCenter = selfNode
            end
        end
    else
        -- 从其他center服获取
        local centerNodes = Common.getClusterNodeByName( "center", true ) or {}
        for _, centerNode in pairs( centerNodes ) do
            guildNameCenter = Common.rpcCall( centerNode, "GuildNameProxy", "getGuildNameCenter" )
            if guildNameCenter then
                break
            end
        end
    end
end

---@see 更新联盟guildName到redis
local function initRedisGuildName()
    local indexNum, guildList
    local indexLimit = 2000
    local selfNode = Common.getSelfNodeName()
    if string.find( selfNode, "^center" ) then
        local flag = skynet.getenv( "guildnamecenter" )
        local centers = Common.getClusterNodeByName( "center", true )
        if flag == "true" then
            -- 记录guildName的center服
            for _, centerNode in pairs( centers or {} ) do
                indexNum = 0
                while true do
                    guildList = Common.rpcCall( centerNode, "GuildNameProxy", "getCenterGuildInfo", centerNode, indexNum, indexLimit ) or {}
                    MSM.GuildNameMgr[0].post.addRedisGuildName( _, guildList )
                    if #guildList < indexLimit then
                        break
                    end
                    indexNum = indexNum + indexLimit
                end
            end
        else
            -- 不是记录guildName的center服
            indexNum = 0
            while true do
                guildList = getGuildInfo( indexNum, indexLimit )
                if #guildList > 0 then
                    Common.rpcMultiSend( guildNameCenter, "GuildNameMgr", "addRedisGuildName", index, guildList )
                end
                if #guildList < indexLimit then
                    break
                end
                indexNum = indexNum + indexLimit
            end
        end
    end
end

---@see 初始化
function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)

    LOG_INFO("GuildNameProxy Init start")
    -- 获取记录guildName的center服
    initGuildNameCenter()
    -- 更新联盟guildName到redis
    initRedisGuildName()
    LOG_INFO("GuildNameProxy Init over")
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

---@see 检查联盟名称是否重复
function response.checkGuildNameRepeat( _name )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "checkGuildNameRepeat", index, _name )
    end
end

---@see 检查联盟简称是否重复
function response.checkGuildAbbNameRepeat( _abbreviationName )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "checkGuildAbbNameRepeat", index, _abbreviationName )
    end
end

---@see 占用联盟名称简称
function response.addGuildNameAndAbbName( _name, _abbreviationName )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "addGuildNameAndAbbName", index, _name, _abbreviationName )
    end
end

---@see 删除联盟名称简称
function accept.delGuildNameAndAbbName( _name, _abbreviationName )
    if guildNameCenter then
        index = index + 1
        Common.rpcMultiSend( guildNameCenter, "GuildNameMgr", "delGuildNameAndAbbName", index, _name, _abbreviationName )
    end
end

---@see 创建联盟成功更新联盟名称简称到center服
function accept.updateCenterGuildName( _gameNode, _guildId, _name, _abbreviationName )
    if guildNameCenter then
        index = index + 1
        local guildInfo = {
            gameNode = _gameNode, guildId = _guildId, name = _name, abbreviationName = _abbreviationName
        }
        Common.rpcMultiSend( guildNameCenter, "GuildNameMgr", "addRedisGuildName", index, { guildInfo } )
    end
end

---@see 解散联盟删除center服的联盟名称简称
function accept.delCenterGuildName( _guildId, _name, _abbreviationName )
    if guildNameCenter then
        Common.rpcMultiSend( guildNameCenter, "GuildNameMgr", "delRedisGuildName", _guildId, _name, _abbreviationName )
    end
end

---@see 获取联盟所在game服
function response.getGuildGameNode( _guildId )
    if guildNameCenter then
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "getGuildGameNode", _guildId )
    end
end

---@see 按关键字搜索联盟简称名称
function response.searchGuildByKeyName( _keyName )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "searchGuildByKeyName", index, _keyName )
    end
end

---@see 检查角色名称是否重复
function response.checkRoleNameRepeat( _name )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "checkRoleNameRepeat", index, _name )
    end
end

---@see 占用角色名称
function response.addRoleName( _name, _rid, _gameNode )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "addRoleName", index, _name, _rid, _gameNode )
    end
end

---@see 删除角色名称
function accept.delRoleName( _name )
    if guildNameCenter then
        index = index + 1
        Common.rpcMultiSend( guildNameCenter, "GuildNameMgr", "delRoleName", index, _name )
    end
end

---@see 修改联盟名称
function response.modifyGuildName( _gameNode, _guildId, _name, _oldName )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "modifyGuildName", index, _guildId, _gameNode, _name, _oldName )
    end
end

---@see 修改联盟简称
function response.modifyGuildAbbName( _gameNode, _guildId, _abbName, _oldAbbName )
    if guildNameCenter then
        index = index + 1
        return Common.rpcMultiCall( guildNameCenter, "GuildNameMgr", "modifyGuildAbbName", index, _guildId, _gameNode, _abbName, _oldAbbName )
    end
end