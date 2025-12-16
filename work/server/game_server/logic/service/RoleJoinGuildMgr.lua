--[[
* @file : RoleJoinGuildMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Fri Jul 03 2020 11:52:54 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色加入联盟服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"

local roleLock = {} -- { rid = { lock = function } }

---@see 联盟逻辑互斥锁
local function checkRoleLock( _rid )
    if not roleLock[_rid] then
        roleLock[_rid] = { lock = queue() }
    end
end

---@see 加入联盟
function response.roleJoinGuild( _rid, _guildId, _guildJob )
    -- 检查互斥锁
    checkRoleLock( _rid )

    local ret, power = roleLock[_rid].lock(
        function ()
            -- 检查角色是否已在联盟中
            if RoleLogic:checkRoleGuild( _rid ) then return nil, ErrorCode.GUILD_ALREADY_IN_GUILD end

            -- 角色加入联盟
            return GuildLogic:joinGuild( _guildId, _rid, _guildJob )
        end
    )

    roleLock[_rid] = nil

    return ret, power
end
