--[[
* @file : RoleRecommendMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Fri Apr 10 2020 19:57:11 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟邀请推荐角色服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Random = require "Random"
local snax = require "skynet.snax"
local skynet = require "skynet"
local RoleLogic = require "RoleLogic"

local roleRate = {}
local maxObjectCount = 0
local waitLoadOver = 0

---@see 初始化入盟申请推荐
local function initRoleRecommend( _roles )
    for rid, roleInfo in pairs( _roles ) do
        if ( not roleInfo.guildId or roleInfo.guildId <= 0 ) and not string.find( roleInfo.name, "^ID" ) then
            table.insert( roleRate, { id = rid, rate = 1 } )
        end
    end
end

---@see 初始化角色昵称
local function initRoleName( _roles )
    local cmds = {}
    local count = 0
    for rid, roleInfo in pairs( _roles ) do
        table.insert(
            cmds,
            { "HSET", "RoleName", roleInfo.name, rid }
        )
        count = count + 1
        if count >= 100 then
            count = 0
            Common.redisExecute( cmds, 0, true )
            cmds = {}
        end
    end

    if count > 0 then
        Common.redisExecute( cmds, 0, true )
    end
end

---@see 初始化
function accept.Init()
    LOG_INFO("RoleRecommendMgr init start")

    local dbNode = Common.getDbNode()
    local count = Common.rpcCall( dbNode, "CommonLoadMgr", "getCommonCount", "d_role" )
    local startTime = skynet.time()

    local service
    local step = 2000
    for index = 1, count, step do
        service = snax.newservice( "RoleLoadMgr" )
        service.post.loadRoleInfo( index-1, step )
        maxObjectCount = maxObjectCount + 1
    end

    -- 等待加载完成
    LOG_INFO("wait for all(%d) RoleRecommendMgr", maxObjectCount)
    while waitLoadOver ~= maxObjectCount do
        skynet.sleep(100)
    end

    LOG_INFO("RoleRecommendMgr init over, use time(%s)", tostring(skynet.time() - startTime))
end

function accept.initRoles( _roles )
    -- 初始化入盟申请推荐
    initRoleRecommend( _roles )
    -- 初始化角色昵称到redis
    initRoleName( _roles )

    waitLoadOver = waitLoadOver + 1
end

---@see 角色退盟添加角色ID
function accept.addRole( _rid, _name )
    _name = _name or RoleLogic:getRole( _rid, Enum.Role.name )
    if _name and not string.find( _name, "^ID" ) then
        table.insert( roleRate, { id = _rid, rate = 1 } )
    end
end

---@see 角色入盟删除角色ID
function accept.delRole( _rid )
    for index, role in pairs( roleRate ) do
        if role.id == _rid then
            table.remove( roleRate, index )
            break
        end
    end
end

---@see 获取随机角色ID
function response.getRecommendRids()
    local rids
    if #roleRate > 10 then
        rids = Random.GetIds( roleRate, 10 )
    else
        rids = {}
        for _, role in pairs( roleRate ) do
            table.insert( rids, role.id )
        end
    end

    return rids
end

---@see 角色改名
function accept.roleModifyName( _rid, _oldName, _newName )
    local oldNameFlag = string.find( _oldName, "^ID" )
    local newNameFlag = string.find( _newName, "^ID" )
    if oldNameFlag and not newNameFlag then
        -- 旧名有ID，新名无ID
        table.insert( roleRate, { id = _rid, rate = 1 } )
    elseif not oldNameFlag and newNameFlag then
        -- 旧名无ID，新名有ID
        snax.self().post.delRole( _rid )
    end
end

---@see 添加角色
function accept.initRole( _rid, _roleInfo )
    _roleInfo = _roleInfo or RoleLogic:getRole( _rid, { Enum.Role.name, Enum.Role.guildId } )
    if _roleInfo and not table.empty( _roleInfo ) then
        if ( not _roleInfo.guildId or _roleInfo.guildId <= 0 ) and not string.find( _roleInfo.name, "^ID" ) then
            table.insert( roleRate, { id = _rid, rate = 1 } )
        end

        Common.redisExecute( { "HSET", "RoleName", _roleInfo.name, _rid } )
    end
end