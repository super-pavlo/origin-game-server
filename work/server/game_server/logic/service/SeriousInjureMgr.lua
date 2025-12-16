--[[
* @file : SeriousInjureMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Thu Nov 05 2020 14:12:33 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 重伤服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local queue = require "skynet.queue"
local lock = {}

function response.subSeriousInLock( _rid, _soldiers )
    if not lock[_rid] then
        lock[_rid] = queue()
    end

    return lock[_rid](function ()
        local seriousInjured = RoleLogic:getRole( _rid, Enum.Role.seriousInjured  )
        local treatmentSum = 0
        local addSoldierInfo = {}
        for _, treatmentSoldier in pairs( _soldiers ) do
            if seriousInjured[treatmentSoldier.id] then
                seriousInjured[treatmentSoldier.id].num = seriousInjured[treatmentSoldier.id].num - treatmentSoldier.num
            end
            if not addSoldierInfo[treatmentSoldier.id] then
                addSoldierInfo[treatmentSoldier.id] = { id = treatmentSoldier.id, num = 0, minor = 0 }
            end
            addSoldierInfo[treatmentSoldier.id].num = addSoldierInfo[treatmentSoldier.id].num + treatmentSoldier.num
            treatmentSum = treatmentSum + treatmentSoldier.num
        end
        local newSeriousInjured = {}
        local syncNewSeriousInjured = {}
        for _, seriousInjuredInfo in pairs( seriousInjured or {} ) do
            if seriousInjuredInfo.num > 0 then
                newSeriousInjured[seriousInjuredInfo.id] = seriousInjuredInfo
            end
            syncNewSeriousInjured[seriousInjuredInfo.id] = seriousInjuredInfo
        end
        RoleLogic:setRole( _rid, { [Enum.Role.seriousInjured] = newSeriousInjured } )
        RoleSync:syncSelf( _rid, {
            [Enum.Role.seriousInjured] = syncNewSeriousInjured,
        }, true, true )
        return treatmentSum, addSoldierInfo
    end)
end

function accept.addSeriousInLock( _rid, _soldiers )
    if not lock[_rid] then
        lock[_rid] = queue()
    end

    return lock[_rid](function ()
        local seriousInjured = RoleLogic:getRole( _rid, Enum.Role.seriousInjured  )
        for _, soldierInfo in pairs( _soldiers ) do
            if not seriousInjured[soldierInfo.id] then
                seriousInjured[soldierInfo.id] = { id = soldierInfo.id, type = soldierInfo.type, level = soldierInfo.level, num = 0 }
            end
            seriousInjured[soldierInfo.id].num = seriousInjured[soldierInfo.id].num + soldierInfo.num
        end
        RoleLogic:setRole( _rid, { [Enum.Role.seriousInjured] = seriousInjured } )
        RoleSync:syncSelf( _rid, { [Enum.Role.seriousInjured] = seriousInjured }, true )
    end)
end