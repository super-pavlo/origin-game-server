--[[
* @file : RoleInfoMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Sun Jun 21 2020 04:07:31 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 全服角色信息查询服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

local roleCenter

---@see 地图符文信息
---@type defaultGlobalRoleInfoClass
local defaultGlobalRoleInfo = {
    rid                     =                   {},             -- 角色id
    gameNode                =                   "",             -- game节点
}

---@see 全服的角色信息
---@class defaultGlobalRoleInfoClass
local globalRoles = {}

---@see 获取game的roles
local function getGameRoles( _indexNum, _indexLimit )
    local dbNode = Common.getDbNode()
    return Common.rpcCall( dbNode, "RoleProxy", "queryRoles", _indexNum, _indexLimit ) or {}
end

---@see 初始化game的角色信息到center服
local function initGameRoles()
    if roleCenter then
        local indexNum, roles
        local indexLimit = 2000
        local selfNode = Common.getSelfNodeName()
        if roleCenter == selfNode then
            -- role center服重启，从其他game服获取role数据
            local allGameNodes = Common.getClusterNodeByName( "game", true ) or {}
            for _, nodeName in pairs( allGameNodes ) do
                indexNum = 0
                while true do
                    roles = Common.rpcMultiCall( nodeName, "RoleInfoMgr", "getGameRoles", indexNum, indexLimit ) or {}
                    for rid in pairs( roles ) do
                        MSM.RoleInfoMgr[rid].post.addRole( rid, nodeName )
                    end
                    if #roles < indexLimit then
                        break
                    end
                    indexNum = indexNum + indexLimit
                end
            end
        else
            if string.find( selfNode, "game" ) then
                -- game服重启，更新game所有的role到center服
                indexNum = 0
                while true do
                    roles = getGameRoles( indexNum, indexLimit ) or {}
                    for rid in pairs( roles ) do
                        Common.rpcMultiSend( roleCenter, "RoleInfoMgr", "addRole", rid, selfNode)
                    end

                    if #roles < indexLimit then
                        break
                    end
                    indexNum = indexNum + indexLimit
                end
            end
        end
    end
end

---@see 初始化角色信息center服节点
local function initRoleCenter()
    local selfNode = Common.getSelfNodeName()
    local flag = skynet.getenv( "rolecenter" )
    if flag == "true" then
        -- 通知其他的game服
        local allNodes = Common.getClusterNodeByName( "game", true ) or {}
        for _, nodeName in pairs( allNodes ) do
            Common.rpcMultiCall( nodeName, "RoleInfoMgr", "updateRoleCenter", 1, selfNode )
        end
        -- 更新本center所有服务
        MSM.RoleInfoMgr[0].req.updateRoleCenter( nil, selfNode )
    else
        -- 从其他center服获取
        if string.find( selfNode, "game" ) then
            local centerNodes = Common.getClusterNodeByName( "center", true ) or {}
            for _, centerNode in pairs( centerNodes ) do
                roleCenter = Common.rpcMultiCall( centerNode, "RoleInfoMgr", "getRoleCenter", 0 )
                if roleCenter then
                    MSM.RoleInfoMgr[0].req.updateRoleCenter( nil, roleCenter )
                    break
                end
            end
        end
    end
end

function init( index )
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)
end

function response.Init()
    initRoleCenter()
    initGameRoles()
end

---@see 更新本服的center服节点
function response.updateSelfRoleCenter( _roleCenter )
    roleCenter = _roleCenter
    LOG_INFO("role center:%s", _roleCenter)
end

---@see 更新记录roleInfo的center服
function response.updateRoleCenter( _, _roleCenter )
    if _roleCenter then
        local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
        for i = 1, multiSnaxNum do
            MSM.RoleInfoMgr[i].req.updateSelfRoleCenter( _roleCenter )
        end
    end
end

---@see 获取game的role信息
function response.getGameRoles( _indexNum, _indexLimit )
    return getGameRoles( _indexNum, _indexLimit )
end

---@see 获取记录roleInfo的center服
function response.getRoleCenter()
    return roleCenter
end

---@see 根据角色id获取gameNode
function response.getRoleGameNode( _rid )
    if roleCenter then
        if roleCenter == Common.getSelfNodeName() then
            if globalRoles[_rid] then
                return globalRoles[_rid].gameNode
            end
        else
            return Common.rpcMultiCall( roleCenter, "RoleInfoMgr", "getRoleGameNode", _rid )
        end
    end
end

---@see 增加或更新角色信息
function accept.addRole( _rid, _gameNode )
    if roleCenter then
        if roleCenter == Common.getSelfNodeName() then
            globalRoles[_rid] = { gameNode = _gameNode }
        else
            Common.rpcMultiSend( roleCenter, "RoleInfoMgr", "addRole", _rid, _gameNode )
        end
    end
end