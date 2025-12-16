--[[
* @file : AgentMgr.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 09:15:16 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 管理 uid 和 agent handler 的映射关系
* Copyright(C) 2017 IGG, All rights reserved
]]

local agentRidHandles = {}

function response.addRid( _rid, _username, _handle )
    if agentRidHandles[_rid] == nil then
        agentRidHandles[_rid] = {}
        agentRidHandles[_rid].ref = 1
    else
        if agentRidHandles[_rid].username == _username then
            agentRidHandles[_rid].ref = agentRidHandles[_rid].ref + 1
        else
            agentRidHandles[_rid].ref = 1
        end
    end

    agentRidHandles[_rid].handle = _handle
    agentRidHandles[_rid].username = _username
end

function response.delRid( _rid, _username )
    if agentRidHandles[_rid] == nil then
        return
    end
    if agentRidHandles[_rid].username ~= _username then
        return
    end
    agentRidHandles[_rid].ref = agentRidHandles[_rid].ref - 1
    if agentRidHandles[_rid].ref <= 0 then
        agentRidHandles[_rid] = nil
    end
end

function response.getAgentHandle( _rid )
    if agentRidHandles[_rid] then
        return agentRidHandles[_rid].handle
    end
end

function response.getUserNameByRid( _rid )
    if agentRidHandles[_rid] then
        return agentRidHandles[_rid].username
    end
end

function response.getUserNameAndAgentByRid( _rid )
    if agentRidHandles[_rid] then
        return agentRidHandles[_rid].username, agentRidHandles[_rid].handle
    end
end

function response.updateUserName( _rid, _username )
    if agentRidHandles[_rid] then
        agentRidHandles[_rid].username = _username
    end
end