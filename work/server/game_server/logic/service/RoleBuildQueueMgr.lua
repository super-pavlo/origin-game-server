--[[
* @file : RoleBuildQueueMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon Nov 16 2020 11:19:43 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色建筑队列服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local RoleLogic = require "RoleLogic"
local BuildingLogic = require "BuildingLogic"
local RoleSync = require "RoleSync"
local ItemLogic = require "ItemLogic"

local roleLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkRoleLock( _rid )
    if not roleLock[_rid] then
        roleLock[_rid] = { lock = queue() }
    end
end

---@see 角色内城建筑升级回调互斥处理
function response.upGradeBuildCallBack( _rid, _buildingIndex, _queueIndex, _isLogin, _isGuildHelp )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            return BuildingLogic:upGradeBuildCallBackImpl( _rid, _buildingIndex, _queueIndex, _isLogin, _isGuildHelp )
        end
    )
end

---@see 角色创建建筑
function response.createBuliding( _rid, _type, _x, _y )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            return BuildingLogic:createBulidingImpl( _rid, _type, _x, _y )
        end
    )
end

---@see 角色升级建筑
function response.upGradeBuliding( _rid, _buildingIndex )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            return BuildingLogic:upGradeBulidingImpl( _rid, _buildingIndex )
        end
    )
end

---@see 更新建筑定时器
function response.updateBuildTimer( _rid, _queueIndex, _sec )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
            if buildQueue[_queueIndex] and buildQueue[_queueIndex].finishTime and buildQueue[_queueIndex].finishTime > os.time() then
                buildQueue[_queueIndex].finishTime = buildQueue[_queueIndex].finishTime - ( _sec or 0 )
                buildQueue[_queueIndex].timerId = MSM.RoleTimer[_rid].req.addBuildTimer( _rid, buildQueue[_queueIndex].finishTime, buildQueue[_queueIndex].buildingIndex, buildQueue[_queueIndex].queueIndex  )
                RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
                RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [_queueIndex] = buildQueue[_queueIndex] } }, true )

                return buildQueue[_queueIndex].finishTime
            end
        end
    )
end

---@see 更新建筑定时器
function response.unlockQueue( _rid, _addSec, _roleInfo, _isLogin )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            return BuildingLogic:unlockQueueImpl( _rid, _addSec, _roleInfo, _isLogin )
        end
    )
end

---@see 联盟求助更新建筑升级队列属性
function response.guildHelpUpdateBuildQueueInfo( _rid, _queueIndex, _requestHelpIndex )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
            -- 建筑队列是否存在
            if not buildQueue[_queueIndex] or buildQueue[_queueIndex].finishTime <= os.time() then
                LOG_ERROR("rid(%d) guildHelpUpdateBuildQueueInfo, buildQueue queueIndex(%d) not exist", _rid, _queueIndex)
                return nil, ErrorCode.GUILD_HELP_QUEUE_NOT_EXIST
            end

            -- 是否已发送过联盟求助
            if buildQueue[_queueIndex].requestGuildHelp then
                LOG_ERROR("rid(%d) guildHelpUpdateBuildQueueInfo, queueIndex(%d) already send guild help", _rid, _queueIndex)
                return nil, ErrorCode.GUILD_ALREADY_SEND_GUILD_HELP
            end
            -- 更新联盟求助信息
            buildQueue[_queueIndex].requestGuildHelp = true
            buildQueue[_queueIndex].requestHelpIndex = _requestHelpIndex
            RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
            -- 通知客户端九  零 一  起 玩 w w w . 9 0 1  7 5 . co m
            RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [_queueIndex] = buildQueue[_queueIndex] } }, true )

            return buildQueue[_queueIndex]
        end
    )
end

---@see 终止建筑升级建造
function accept.endBuilding( _rid, _buildingIndex )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.buildQueue, Enum.Role.guildId } )
            local guildId = roleInfo.guildId or 0
            local buildQueue = roleInfo.buildQueue
            local requestHelpIndex
            for _, queueInfo in pairs( buildQueue ) do
                if queueInfo.buildingIndex == _buildingIndex and queueInfo.finishTime > 0 then
                    local buildInfo = BuildingLogic:getBuilding( _rid, _buildingIndex )
                    local level = buildInfo.level + 1
                    local synBuildInfo = {}
                    if level == 1 then
                        --删除建筑信息
                        BuildingLogic:deleteBuilding( _rid, _buildingIndex )
                        synBuildInfo[_buildingIndex] = { level = -1, buildingIndex = _buildingIndex }
                    end
                    local sBuildingLevelData = CFG.s_BuildingLevelData:Get( buildInfo.type * 100 + level )
                    requestHelpIndex = queueInfo.requestHelpIndex
                    --返还资源
                    if sBuildingLevelData.food then
                        RoleLogic:addFood( _rid, sBuildingLevelData.food/2//1, nil, Enum.LogType.BUILD_STOP_GAIN_CURRENCY )
                    end
                    if sBuildingLevelData.wood then
                        RoleLogic:addWood( _rid, sBuildingLevelData.wood/2//1, nil, Enum.LogType.BUILD_STOP_GAIN_CURRENCY )
                    end
                    if sBuildingLevelData.stone then
                        RoleLogic:addStone( _rid, sBuildingLevelData.stone/2//1, nil, Enum.LogType.BUILD_STOP_GAIN_CURRENCY )
                    end
                    if sBuildingLevelData.coin then
                        RoleLogic:addGold( _rid, sBuildingLevelData.coin/2//1, nil, Enum.LogType.BUILD_STOP_GAIN_CURRENCY )
                    end
                    if sBuildingLevelData.itemType1 and sBuildingLevelData.itemType1 > 0 then
                        local num = math.ceil( sBuildingLevelData.itemCnt/2 )
                        ItemLogic:addItem( { rid = _rid, itemId = sBuildingLevelData.itemType1, itemNum = num,  eventType = Enum.LogType.STOP_BUILDING_GAIN_ITEM } )
                    end
                    queueInfo.finishTime = -2
                    MSM.RoleTimer[_rid].req.deleteBuildTimer( _rid, queueInfo.timerId )
                    queueInfo.timerId = -1
                    queueInfo.beginTime = 0
                    RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [queueInfo.queueIndex] = queueInfo } }, true, true )
                    queueInfo.buildingIndex = 0
                    queueInfo.requestGuildHelp = false
                    RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )
                    RoleSync:syncSelf( _rid, { [Enum.Role.buildQueue] = { [queueInfo.queueIndex] = queueInfo } }, true )
                    buildInfo.finishTime = -1
                    if level > 1 then
                        MSM.d_building[_rid].req.Set( _rid, _buildingIndex, buildInfo )
                        synBuildInfo[_buildingIndex] = buildInfo
                    end
                    BuildingLogic:syncBuilding( _rid, nil, synBuildInfo, true )
                    if guildId > 0 and requestHelpIndex then
                        -- 删除联盟求助信息
                        MSM.GuildMgr[guildId].post.roleQueueFinishCallBack( guildId, requestHelpIndex )
                    end
                end
            end
        end
    )
end

---@see 退出联盟清除角色的联盟求助索引
function accept.cleanBuildRequestIndexsOnExitGuild( _rid )
    checkRoleLock( _rid )

    return roleLock[_rid].lock(
        function ()
            local buildQueue = RoleLogic:getRole( _rid, Enum.Role.buildQueue ) or {}
            local changeQueueInfo = {}
            for queueIndex, queueInfo in pairs( buildQueue ) do
                if queueInfo.requestHelpIndex then
                    queueInfo.requestHelpIndex = nil
                    changeQueueInfo[queueIndex] = queueInfo
                end
            end

            if table.empty( changeQueueInfo ) then
                changeQueueInfo = nil
            end

            RoleLogic:setRole( _rid, { [Enum.Role.buildQueue] = buildQueue } )

            return changeQueueInfo
        end
    )
end