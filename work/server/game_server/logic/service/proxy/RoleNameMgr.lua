--[[
* @file : RoleNameMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon Apr 13 2020 09:29:36 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色名称服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Random = require "Random"

---@see 模糊匹配昵称查询角色信息
function response.getRoleByParam( _param )
    local ridRate = {}
    local matchKey = string.format( "%s*", _param )
    local matchInfo = Common.scanQuery( "HSCAN", "RoleName", matchKey, nil, true )
    for _, rid in pairs( matchInfo or {} ) do
        table.insert( ridRate, { id = rid, rate = 1 } )
    end

    local rids
    if #ridRate > 20 then
        rids = Random.GetIds( ridRate, 20 )
    else
        rids = {}
        for _, role in pairs( ridRate ) do
            table.insert( rids, role.id )
        end
    end

    return rids
end

---@see 角色改名更新redis
function accept.roleModifyName( _rid, _oldName, _newName )
    local cmds = {}
    -- 更新redis
    table.insert( cmds, { "HDEL", "RoleName", _oldName } )
    table.insert( cmds, { "HSET", "RoleName", _newName, _rid } )

    Common.redisExecute( cmds, 0, true )
end

---@see 创建角色加入redis
function accept.addRole( _rid, _name )
    local cmds = {}
    -- 更新redis
    table.insert( cmds, { "HSET", "RoleName", _name, _rid } )

    Common.redisExecute( cmds, 0, true )
end