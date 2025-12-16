--[[
 * @file : SoldierLockMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-07-14 09:16:16
 * @Last Modified time: 2020-07-14 09:16:16
 * @department : Arabic Studio
 * @brief : 士兵并发处理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local queue = require "skynet.queue"
local lock = {}

---@see 增加士兵.同角色串行处理
---@param _soldiers table 增减的士兵数量
function response.addSoldiersInLock( _rid, _soldiers, _notCaclePower )
    if not lock[_rid] then
        lock[_rid] = queue()
    end

    return lock[_rid](function ()
        local soldiers = RoleLogic:getRole( _rid, Enum.Role.soldiers )
        for soldierId, soldierInfo in pairs(_soldiers) do
            if soldiers[soldierId] then
                -- 增加士兵
                if soldierInfo.num and soldierInfo.num >= 0 then
                    soldiers[soldierId].num = soldiers[soldierId].num + soldierInfo.num
                else
                    LOG_ERROR("addSoldiersInLock error, rid(%d) soldierId(%d) but num(%s) <= 0", _rid, soldierId, tostring(soldierInfo.num))
                end
                -- 增加轻伤士兵
                if soldierInfo.minor and soldierInfo.minor >= 0 then
                    soldiers[soldierId].minor = ( soldiers[soldierId].minor or 0 ) + soldierInfo.minor
                else
                    LOG_ERROR("addSoldiersInLock error, rid(%d) soldierId(%d) but minor(%s) <= 0", _rid, soldierId, tostring(soldierInfo.minor))
                end
            else
                if soldierInfo.num > 0 or soldierInfo.minor > 0 then
                    -- 获取兵种的类型和等级
                    if not soldierInfo.type or not soldierInfo.level then
                        local sSoldierInfo = CFG.s_Arms:Get(soldierId)
                        soldierInfo.type = sSoldierInfo.armsType
                        soldierInfo.level = sSoldierInfo.armsLv
                    end
                    -- 添加士兵
                    soldierInfo.minor = soldierInfo.minor or 0
                    soldiers[soldierId] = soldierInfo
                else
                    LOG_ERROR("addSoldiersInLock error, rid(%d) add not exist soldierId(%d) but num(%s) minor(%s) <= 0", _rid, soldierId, tostring(soldierInfo.num), tostring(soldierInfo.minor))
                end
            end
        end

        -- 更新士兵到角色身上
        RoleLogic:setRole( _rid, Enum.Role.soldiers, soldiers )
        -- 同步给客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.soldiers] = soldiers }, true )
        if not _notCaclePower then
            -- 刷新角色战力
            RoleLogic:cacleSyncHistoryPower( _rid )
        end
    end)
end

---@see 减少士兵.同角色串行处理
---@param _soldiers table 增减的士兵数量
function response.subSoldiersInLock( _rid, _soldiers )
    if not lock[_rid] then
        lock[_rid] = queue()
    end

    return lock[_rid](function ()
        local soldiers = RoleLogic:getRole( _rid, Enum.Role.soldiers )
        local roleSyncInfo = {}
        for soldierId, soldierInfo in pairs(_soldiers) do
            if soldiers[soldierId] then
                if soldierInfo.num and soldierInfo.num >= 0 then
                    soldiers[soldierId].num = soldiers[soldierId].num - soldierInfo.num
                    if soldiers[soldierId].num < 0 then
                        soldiers[soldierId].num = 0
                    end
                end

                if soldierInfo.minor and soldierInfo.minor >= 0 then
                    soldiers[soldierId].minor = ( soldiers[soldierId].minor or 0 ) - soldierInfo.minor
                    if soldiers[soldierId].minor < 0 then
                        soldiers[soldierId].minor = 0
                    end
                end
                roleSyncInfo[soldierId] = table.copy( soldiers[soldierId] )
                if soldiers[soldierId].num <= 0 and soldiers[soldierId].minor <= 0 then
                    -- 此ID的士兵已经没有了(没有正常和轻伤士兵)
                    soldiers[soldierId] = nil
                end
            else
                -- 减少士兵,但是角色身上没有这个士兵
                LOG_ERROR("subSoldiersInLock error, rid(%d) add not exist soldierId(%d)", _rid, soldierId)
            end
        end

        -- 更新士兵到角色身上
        RoleLogic:setRole( _rid, Enum.Role.soldiers, soldiers )
        -- 同步给客户端
        RoleSync:syncSelf( _rid, { [Enum.Role.soldiers] = roleSyncInfo }, true )
        -- 刷新角色战力
        RoleLogic:cacleSyncHistoryPower( _rid )
    end)
end