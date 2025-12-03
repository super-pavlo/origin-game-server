--[[
* @file : RoleOperatingMgr.lua
* @type : multi snax service
* @author : chenlei
* @created : Fri May 22 2020 09:25:32 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色操作服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local ArmyLogic = require "ArmyLogic"
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local LogLogic = require "LogLogic"
local ArmyTrainLogic = require "ArmyTrainLogic"
local SoldierLogic = require "SoldierLogic"

local roleLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkRoleLock( _rid )
    if not roleLock[_rid] then
        roleLock[_rid] = { lock = queue() }
    end
end


---@see 添加士兵
function response.addSoldiers( _rid, _type, _level, _addNum, _eventType, _eventType2, _noAddLog, _noSync )
    -- 检查互斥锁
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.soldiers, Enum.Role.iggid, Enum.Role.historySoldiers } )
            local soldiers = roleInfo.soldiers
            local historySoldiers = roleInfo.historySoldiers
            local config = ArmyTrainLogic:getArmsConfig( _rid, _type, _level )
            local id = config.ID
            local roleChangeInfo = {}

            -- 增加、减少士兵
            if not soldiers[id] then
                soldiers[id] = { id = id, num = 0, minor = 0, type = _type, level = _level }
            end
            soldiers[id].num = soldiers[id].num + _addNum

            if _addNum > 0 then
                -- 增加士兵
                SoldierLogic:addSoldier( _rid, { [id] = { id = id, num = _addNum, minor = 0 } } )
            else
                SoldierLogic:subSoldier( _rid, { [id] = { id = id, num = -_addNum, minor = 0 } } )
            end

            if not _eventType or _eventType == Enum.LogType.TRAIN_ARMY or _eventType == Enum.LogType.ARMY_LEVEL_UP_ADD
                or _eventType == Enum.LogType.PACKAGE_GAIN_ARMY or _eventType == Enum.LogType.ARMY_LEVEL_UP_REDUCE then
                if not historySoldiers[id] then
                    historySoldiers[id] = { id = id, type = _type, level = _level, num = 0, minor = 0 }
                end
                historySoldiers[id].num = historySoldiers[id].num + _addNum
                roleChangeInfo.historySoldiers = historySoldiers
            end
            RoleLogic:setRole( _rid, roleChangeInfo )
            if not _noSync then
                RoleSync:syncSelf( _rid, roleChangeInfo, true)
            end

            if not _noSync and _addNum > 0 then
                -- 训练士兵回调处理
                ArmyLogic:addSoldierCallback( _rid, { [id] = { id = id, type = _type, level = _level, num = _addNum } } )
            end

            -- 日志记录
            if not _noAddLog then
                LogLogic:armsChange( {
                    logType = _eventType,
                    logType2 = _eventType2,
                    armsID = id,
                    changeNum = _addNum,
                    oldNum = soldiers[id].num - _addNum,
                    newNum = soldiers[id].num,
                    rid = _rid,
                    iggid = roleInfo.iggid
                } )
            end

            return roleChangeInfo
        end
    )
end