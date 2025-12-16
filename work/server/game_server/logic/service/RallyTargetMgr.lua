--[[
 * @file : RallyTargetMgr.lua
 * @type : snax single service
 * @author : linfeng
 * @created : 2020-05-07 15:22:15
 * @Last Modified time: 2020-05-07 15:22:15
 * @department : Arabic Studio
 * @brief : 集结目标对象状态管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RallyDef = require "RallyDef"

---@type table<int,table<int,int>>
local rallyTargetInfo = {} -- 目标被集结信息
---@type table<int,defaultGuildRallyedClass>
local rallyGuildTargetInfo = {} -- 联盟被集结、增援信息

---@see 判断是否已被指定联盟集结
function response.checkRallySameGuild( _targetIndex, _guildId )
    if rallyTargetInfo[_targetIndex] and rallyTargetInfo[_targetIndex][_guildId] then
        return true
    end
    return false
end

---@see 切换对象的目标联盟目标联盟
function response.switchTargetGuild( _targetIndex, _rawGuildId, _newGuildId )
    if rallyGuildTargetInfo[_rawGuildId] and rallyGuildTargetInfo[_rawGuildId].rally[_targetIndex] then
        local rallyInfo = rallyGuildTargetInfo[_rawGuildId].rally[_targetIndex]
        SM.RallyTargetMgr.req.addRallyGuildTargetInfo( _newGuildId, _targetIndex, nil, rallyInfo )
        rallyGuildTargetInfo[_rawGuildId].rally[_targetIndex] = nil
    end
end

---@see 增加联盟被集结目标信息
function response.addRallyGuildTargetInfo( _guildId, _targetIndex, _rallyRid, _rallyInfos )
    if not rallyGuildTargetInfo[_guildId] then
        rallyGuildTargetInfo[_guildId] = RallyDef:getDefaultGuildRallyed()
    end
    if not rallyGuildTargetInfo[_guildId].rally[_targetIndex] then
        rallyGuildTargetInfo[_guildId].rally[_targetIndex] = {}
    end

    if _rallyInfos then
        rallyGuildTargetInfo[_guildId].rally[_targetIndex] = _rallyInfos
    else
        table.insert( rallyGuildTargetInfo[_guildId].rally[_targetIndex], _rallyRid )
    end
end

---@see 增加目标被集结对象
function response.addRallyTargetIndex( _targetIndex, _targetGuildId, _rid, _guildId )
    if not rallyTargetInfo[_targetIndex] then
        rallyTargetInfo[_targetIndex] = {}
    end

    if rallyTargetInfo[_targetIndex][_guildId] then
        -- 一个对象只能被一个联盟的一个成员集结
        LOG_ERROR("addRallyTargetIndex fail, guildId only one rally")
        return false
    end

    rallyTargetInfo[_targetIndex][_guildId] = _rid

    -- 加入联盟被集结信息
    SM.RallyTargetMgr.req.addRallyGuildTargetInfo( _targetGuildId, _targetIndex, _rid )

    return true
end

---@see 删除目标被集结对象
function response.deleteRallyTargetIndex( _targetIndex, _targetGuildId, _rid, _guildId )
    if rallyTargetInfo[_targetIndex] and rallyTargetInfo[_targetIndex][_guildId] then
        rallyTargetInfo[_targetIndex][_guildId] = nil
        if table.empty(rallyTargetInfo[_targetIndex]) then
            rallyTargetInfo[_targetIndex] = nil
        end
    end

    -- 移除被集结联盟信息
    if rallyGuildTargetInfo[_targetGuildId] then
        if rallyGuildTargetInfo[_targetGuildId].rally[_targetIndex] then
            table.removevalue( rallyGuildTargetInfo[_targetGuildId].rally[_targetIndex], _rid )
            if table.empty( rallyGuildTargetInfo[_targetGuildId].rally[_targetIndex] ) then
                rallyGuildTargetInfo[_targetGuildId].rally[_targetIndex] = nil
                if table.empty(rallyGuildTargetInfo[_targetGuildId].rally) and table.empty(rallyGuildTargetInfo[_targetGuildId].reinforce) then
                    rallyGuildTargetInfo[_targetGuildId] = nil
                end
            end
        end
    end
end

---@see 获取联盟被集结信息
function response.getGuildRallyedInfo( _targetGuildId )
    return rallyGuildTargetInfo[_targetGuildId]
end

---@see 判断目标是否被集结
function response.checkTargetIsRallyed( _targetGuildId, _targetIndex )
    if rallyGuildTargetInfo[_targetGuildId] then
        return rallyGuildTargetInfo[_targetGuildId].rally[_targetIndex]
    end
end

---@see 获取对象被集结信息
function response.getRallyTargetInfo( _objectIndex )
    return rallyTargetInfo[_objectIndex]
end