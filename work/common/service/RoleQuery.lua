--[[
 * @file : RoleQuery.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2019-12-24 10:55:47
 * @Last Modified time: 2019-12-24 10:55:47
 * @department : Arabic Studio
 * @brief : 角色查询服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

function init(index)
    snax.enablecluster()
	cluster.register(SERVICE_NAME .. index)
end

function response.Init()
    -- body
end

---@see 查询角色列表
function response.QueryRoleList( _uid, _iggid )
    local accountInfo = SM.c_account.req.Get(_iggid) or {}
    local roleInfos = MSM.d_user[_uid].req.Get( _uid, "roleInfos" )
    local retRoleInfos = {}
    if roleInfos then
        for rid, roleInfo in pairs(roleInfos) do
            local ret = Common.rpcMultiCall( roleInfo.gameNode, "RoleQuery", "getRoleNameAndPowerFromGameServer", rid )
            if ret then
                retRoleInfos[rid] = ret
            end
        end
    end
    return retRoleInfos, accountInfo.ban
end

---@see 增加角色列表
function response.AddRoleList( _uid, _rid, _name, _gameNode )
    local roleInfos = MSM.d_user[_uid].req.Get( _uid, "roleInfos" )

    if roleInfos then
        -- 判断是否已存在
        if roleInfos[_rid] then
            LOG_ERROR("uid(%d) rid(%d) AddRoleList error, had exits", _uid, _rid)
            return false
        end

        -- 插入
        roleInfos[_rid] =  { rid = _rid, gameNode = _gameNode, name = _name }
        MSM.d_user[_uid].req.Set( _uid, { roleInfos = roleInfos } )
    else
        -- 新增加
        MSM.d_user[_uid].req.Add( _uid, { roleInfos = { [_rid] = { rid = _rid, gameNode = _gameNode, name = _name } } } )
    end

    return true
end

---@see 检查角色是否已满
function response.CheckRoleMax( _uid, _gameNode )
    local roleInfos = MSM.d_user[_uid].req.Get( _uid, "roleInfos" )

    if roleInfos then
        local roleCount = 0
        -- 统计所在服务器的角色
        for _, roleInfo in pairs(roleInfos) do
            if roleInfo.gameNode == _gameNode then
                roleCount = roleCount + 1
            end
        end

        local maxRoleCount = CFG.s_Config:Get("createRoleMax")
        return roleCount < maxRoleCount
    else
        return true
    end
end

---@see 修改角色所属服务器
function response.ChangeRoleGameNode(_uid,  _iggid, _oldRid, _newRid, _newGameNode )
    local roleInfos = MSM.d_user[_uid].req.Get( _uid, "roleInfos" )
    if roleInfos then
        -- 判断是否存在
        if not roleInfos[_oldRid] then
            LOG_ERROR("uid(%d) rid(%d) ChangeRoleGameNode error, not exits", _uid, _oldRid)
            return false
        end
        -- 更新所属服务器
        roleInfos[_oldRid].gameNode = _newGameNode
        roleInfos[_newRid] = roleInfos[_oldRid]
        roleInfos[_newRid].rid = _newRid
        roleInfos[_oldRid] = nil
        -- 修改最后登录服务器
        local accountInfo = SM.c_account.req.Get(_iggid)
        if not accountInfo then
            return false
        end
        accountInfo.gameNode = _newGameNode

        -- 更新
        MSM.d_user[_uid].req.Set( _uid, { roleInfos = roleInfos } )
        SM.c_account.req.Set( _iggid, accountInfo )

        return true
    end
end

---@see 查询角色详细信息
function response.getRoleDetailList( _, _iggid, _rid )
    local accountInfo = SM.c_account.req.Get(_iggid)
    if not accountInfo or table.empty(accountInfo) then
        return
    end
    local uid = accountInfo.uid
    local roleInfos = MSM.d_user[uid].req.Get( uid, "roleInfos" )
    local ret
    local roleList = {}
    if roleInfos then
        local ban = 0
        if accountInfo.ban then
            ban = 1
        end
        if _rid then
            if roleInfos[_rid] then
                -- 查询某个角色
                ret = Common.rpcMultiCall( roleInfos[_rid].gameNode, "RoleQuery", "getRoleInfoFromGameServer", _rid, ban )
                if ret then
                    table.insert( roleList, ret )
                end
            end
        else
            -- 查询iggid下的所有角色
            for rid, roleInfo in pairs(roleInfos) do
                ret = Common.rpcMultiCall( roleInfo.gameNode, "RoleQuery", "getRoleInfoFromGameServer", rid, ban )
                if ret then
                    table.insert( roleList, ret )
                end
            end
        end
    end

    return roleList
end

---@see 从游服获取角色详细信息
function response.getRoleInfoFromGameServer( _rid, _ban )
    local RoleLogic = require "RoleLogic"
    local roleInfo = RoleLogic:getRole( _rid )
    if roleInfo then
        return {
            iggid = roleInfo.iggid,
            rid = _rid,
            level = roleInfo.level,
            serverId = Common.getSelfNodeName(),
            denar = roleInfo.denar,
            guildId = roleInfo.guildId,
            ban = _ban,
            x = math.floor( roleInfo.pos.x / 600 ),
            y = math.floor( roleInfo.pos.y / 600 ),
            createTime = roleInfo.createTime,
            allLoginTime = roleInfo.allLoginTime
        }
    end
end

---@see 从游服获取角色名字和战力
function response.getRoleNameAndPowerFromGameServer( _rid )
    local RoleLogic = require "RoleLogic"
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.name, Enum.Role.combatPower,
                                        Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.lastLoginTime } )
    if roleInfo then
        local guildAbbName
        if roleInfo.guildId > 0 then
            local GuildLogic = require "GuildLogic"
            -- 取联盟简称
            local guildInfo = GuildLogic:getGuild( roleInfo.guildId, { Enum.Guild.abbreviationName } )
            if guildInfo then
                guildAbbName = guildInfo.abbreviationName
            end
        end
        return {
            rid = _rid,
            name = roleInfo.name,
            gameNode = Common.getSelfNodeName(),
            combatPower = roleInfo.combatPower,
            headId = roleInfo.headId,
            headFrameID = roleInfo.headFrameID,
            guildAbbName = guildAbbName,
            lastLoginTime = roleInfo.lastLoginTime
        }
    end
end

---@see 解封封号角色
function response.banRole( _, _iggid, _ban )
    -- 更新账号封号状态
    local accountInfo = SM.c_account.req.Get( _iggid )
    if not accountInfo or table.empty(accountInfo) then
        return false
    else
        accountInfo.ban = _ban
        SM.c_account.req.Set( _iggid, accountInfo )
        -- 如果是封号,需要通知游服,踢出在线的角色
        if _ban then
            local uid = accountInfo.uid
            local roleInfos = MSM.d_user[uid].req.Get( uid, "roleInfos" )
            for rid, roleInfo in pairs(roleInfos) do
                Common.rpcMultiCall( roleInfo.gameNode, "RoleQuery", "kickRoleOnBan", rid )
            end
        end
        return true
    end
end

---@see 封号踢掉角色
function response.kickRoleOnBan( _rid )
    local RoleLogic = require "RoleLogic"
    local online = RoleLogic:getRole( _rid, Enum.Role.online )
    if online then
        -- 踢出角色
        local usernames, agents = Common.getUserNameAndAgentByRid( _rid )
        if agents then
            local RoleSync = require "RoleSync"
            RoleSync:syncKick( _rid, Enum.SystemKick.BAN )
            agents[1].req.kickAgent( usernames[1], true )
            LOG_INFO("rid(%d) username(%s) kickRoleOnBan, kickAgent", _rid, usernames[1])
        end
    end
end

---@see 禁言角色
function response.silenceRole( _, _iggid, _time )
    local accountInfo = SM.c_account.req.Get( _iggid )
    if not accountInfo or table.empty(accountInfo) then
        return false
    else
        if _time and _time > 0 then
            accountInfo.silence = os.time() + _time
        else
            accountInfo.silence = 0
        end
        SM.c_account.req.Set( _iggid, accountInfo )
        -- 同步给游服下的角色
        local uid = accountInfo.uid
        local roleInfos = MSM.d_user[uid].req.Get( uid, "roleInfos" )
        for rid, roleInfo in pairs(roleInfos) do
            Common.rpcMultiCall( roleInfo.gameNode, "RoleQuery", "silenceRoleImpl", rid, accountInfo.silence )
        end
        return true
    end
end

---@see 禁言角色生效处理
function response.silenceRoleImpl( _rid, _time )
    local RoleLogic = require "RoleLogic"
    local RoleSync = require "RoleSync"
    local online = RoleLogic:getRole( _rid, Enum.Role.online )
    RoleLogic:setRole( _rid, Enum.Role.silence, _time )
    RoleSync:syncSelf( _rid, { [Enum.Role.silence] = _time }, true )
    if online then
        -- 通知聊天服务器
        local RoleChatLogic = require "RoleChatLogic"
        RoleChatLogic:syncRoleInfoToChatServer( _rid )
    end
end

---@see token失效.踢出角色
function accept.invalidTokenKickRole( _rid )
    local RoleSync = require "RoleSync"
    if not Common.offOnline( _rid ) then
        -- 踢出
        local userNames, agents = Common.getUserNameAndAgentByRid( _rid )
        if not table.empty(agents) then
            RoleSync:syncKick( _rid, Enum.SystemKick.TOKEN_INVALID )
            agents[1].req.kickAgent( userNames[1] )
            LOG_INFO("rid(%d) username(%s) invalidTokenKickRole, kickAgent", _rid, userNames[1])
        end
    end
end

---@see 运营后台踢人
function accept.kickRoleFromWeb( _rid )
    local RoleLogic = require "RoleLogic"
    local online = RoleLogic:getRole( _rid, Enum.Role.online )
    if online then
        -- 踢出角色
        local usernames, agents = Common.getUserNameAndAgentByRid( _rid )
        if agents then
            local RoleSync = require "RoleSync"
            RoleSync:syncKick( _rid, Enum.SystemKick.KICK_WEB )
            agents[1].req.kickAgent( usernames[1], true )
            LOG_INFO("rid(%d) username(%s) kickRole, kickAgent", _rid, usernames[1])
        end
    end
end

---@see 更新角色最后登录时间
function response.setRoleLastLoginTime( _rid )
    local RoleLogic = require "RoleLogic"
    local lastLoginTime = RoleLogic:getRole( _rid, Enum.Role.lastLoginTime )
    if lastLoginTime then
        RoleLogic:setRole( _rid, Enum.Role.lastLoginTime, os.time())
        return true
    end
    return false
end