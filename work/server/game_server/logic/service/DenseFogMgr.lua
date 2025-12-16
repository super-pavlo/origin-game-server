--[[
 * @file : DenseFogMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2019-12-24 15:07:47
 * @Last Modified time: 2019-12-24 15:07:47
 * @department : Arabic Studio
 * @brief : 迷雾管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local ScoutsLogic = require "ScoutsLogic"
local TaskLogic = require "TaskLogic"
local DenseFogLogic = require "DenseFogLogic"

---@see 斥候移动
---@param _rid integer 角色rid
---@param _pos table 斥候位置
function response.scoutsMove( _rid, _pos, _targetDenseFogInfo, _objectIndex, _scoutsIndex )
    -- 未开启的迷雾数量
    local rawDenseFogCount = 0
    if _targetDenseFogInfo then
        for _, rule in pairs(_targetDenseFogInfo) do
            if rule == 0 then
                rawDenseFogCount = rawDenseFogCount + 1
            end
        end
    end
    -- 找出斥候视野范围内的迷雾(斥候视野固定3600*3600)
    local saveIndex, bitIndex
    local roleDenseFog = RoleLogic:getRole( _rid, Enum.Role.denseFog )
    local allDenseFogIndex = ScoutsLogic:getDenseFogWithScoutView( _pos, roleDenseFog )

    local scoutCount = 0
    local allNewOpenDenseFog = {}
    -- 判断迷雾是否开启
    local openDenseFogIndexs = {}
    if not table.empty(allDenseFogIndex) then
        for index, denseFogRule in pairs(allDenseFogIndex) do
            if denseFogRule == 0 and index >= 1 then
                -- 处于迷雾状态,开启迷雾
                saveIndex = math.ceil(index / 64)
                if saveIndex >= 1 and saveIndex <= 2500 then
                    table.insert( openDenseFogIndexs, index )
                    bitIndex = DenseFogLogic:denseFogIndexToBitIndex( index )
                    if not roleDenseFog[saveIndex] then
                        roleDenseFog[saveIndex] = { index = saveIndex, rule = 0 }
                    end
                    roleDenseFog[saveIndex].rule = roleDenseFog[saveIndex].rule ~ ( 1 << bitIndex )
                    -- 更新
                    allDenseFogIndex[index] = 1
                    table.insert( allNewOpenDenseFog, { index = index, saveIndex = bitIndex } )
                    scoutCount = scoutCount + 1
                    if _targetDenseFogInfo and _targetDenseFogInfo[index] then
                        _targetDenseFogInfo[index] = 1
                    end
                end
            end
        end
    end

    local denseFogCount = 0
    if rawDenseFogCount > 0 then
        -- 未开启的迷雾数量
        if _targetDenseFogInfo then
            for _, rule in pairs(_targetDenseFogInfo) do
                if rule == 0 then
                    denseFogCount = denseFogCount + 1
                end
            end
        end

        --[[
        -- 未开启的迷雾小于等于3个,直接开启
        if denseFogCount <= 3 then
            if _targetDenseFogInfo then
                for index, rule in pairs(_targetDenseFogInfo) do
                    if rule == 0 then
                        table.insert( openDenseFogIndexs, index )
                        saveIndex = math.ceil(index / 64)
                        bitIndex = ScoutsLogic:denseFogIndexToBitIndex( index )
                        roleDenseFog[saveIndex].rule = roleDenseFog[saveIndex].rule ~ ( 1 << bitIndex )
                        table.insert( allNewOpenDenseFog, { index = index, saveIndex = saveIndex } )
                        scoutCount = scoutCount + 1
                        _targetDenseFogInfo[index] = 1
                    end
                end
                denseFogCount = 0
            end
        end
        ]]

        if denseFogCount <= 0 then
            -- 迷雾探索完成,斥候回城
            _pos.x = math.floor(_pos.x)
            _pos.y = math.floor(_pos.y)
            local cityPos = RoleLogic:getRole( _rid, Enum.Role.pos )
            MSM.MapMarchMgr[_objectIndex].post.scoutsBackCity( _rid, _objectIndex, { _pos, cityPos } )
        end
    end

    if not table.empty(openDenseFogIndexs) then
        -- 更新到角色属性
        RoleLogic:setRole( _rid, Enum.Role.denseFog, roleDenseFog )
        -- 同步给客户端
        Common.syncMsg( _rid, "Map_DenseFogOpen", { denseFogIndex = openDenseFogIndexs } )
        -- 增加迷雾探索标识
        RoleLogic:addScoutDenseFogFlag( _rid, _scoutsIndex )
    end

    -- 增加迷雾探索数
    if scoutCount > 0 then
        TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.FOG_EXPLORE, Enum.TaskArgDefault, scoutCount )
        -- 增加斥候迷雾探索数量
        ScoutsLogic:addScoutDenseFogNum( _rid, _scoutsIndex, scoutCount )
    end

    -- 增加活动进度
    if scoutCount > 0 then
        -- 登陆设置活动进度
        local addNum
        if RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) then
            -- 迷雾全开, 不需要判断迷雾探索个数
            addNum = 160000
        else
            local taskStatistics = RoleLogic:getRole( _rid, Enum.Role.taskStatisticsSum )
            addNum = TaskLogic:getStatisticsNum( taskStatistics, Enum.TaskType.FOG_EXPLORE )
        end
        -- 迷雾探索
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.SCOUT_MIST, addNum, nil, nil, true )
        MSM.MonumentRoleMgr[_rid].post.setSchedule( _rid, { type = Enum.MonumentType.SERVER_SCOUT,  count = scoutCount })
    end

    -- 发送探索发现邮件
    ScoutsLogic:scoutDiscoverVillageCaves( _rid, allNewOpenDenseFog )
    ScoutsLogic:scoutDiscoverHolyLands( _rid, allNewOpenDenseFog )

    -- 返回未开启的迷雾数量
    return denseFogCount, _targetDenseFogInfo
end

---@see 区域迷雾全开
function response.openAreaDenseFog( _rid, _allDesenFog, _scoutsIndex )
    local openDenseFogIndexs = {}
    local roleDenseFog = RoleLogic:getRole( _rid, Enum.Role.denseFog )
    local saveIndex
    local scoutCount = 0
    local newOpenDenseFog = {}
    local bitIndex
    for denseIndex, rule in pairs(_allDesenFog) do
        if rule == 0 then
            if denseIndex >= 1 then
                table.insert( openDenseFogIndexs, denseIndex )
                saveIndex = math.ceil(denseIndex / 64)
                if saveIndex <= 2500 then
                    bitIndex = DenseFogLogic:denseFogIndexToBitIndex( denseIndex )
                    if not roleDenseFog[saveIndex] then
                        roleDenseFog[saveIndex] = { index = saveIndex, rule = 0 }
                    end
                    roleDenseFog[saveIndex].rule = roleDenseFog[saveIndex].rule ~ ( 1 << bitIndex )
                    table.insert( newOpenDenseFog, { index = denseIndex, saveIndex = saveIndex } )
                    scoutCount = scoutCount + 1
                end
            end
        end
    end

    if not table.empty(openDenseFogIndexs) then
        -- 更新到角色属性
        RoleLogic:setRole( _rid, Enum.Role.denseFog, roleDenseFog )
        -- 同步给客户端
        Common.syncMsg( _rid, "Map_DenseFogOpen", { denseFogIndex = openDenseFogIndexs, noArrivalOpen = true } )
        -- 增加迷雾探索标识
        RoleLogic:addScoutDenseFogFlag( _rid, _scoutsIndex )
    end

    -- 增加迷雾探索数
    if scoutCount > 0 then
        TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.FOG_EXPLORE, Enum.TaskArgDefault, scoutCount )
        -- 增加斥候迷雾探索数量
        ScoutsLogic:addScoutDenseFogNum( _rid, _scoutsIndex, scoutCount )
    end

    -- 增加活动进度
    if scoutCount > 0 then
        -- 登陆设置活动进度
        local addNum
        if RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) then
            -- 迷雾全开, 不需要判断迷雾探索个数
            addNum = 160000
        else
            local taskStatistics = RoleLogic:getRole( _rid, Enum.Role.taskStatisticsSum )
            addNum = TaskLogic:getStatisticsNum( taskStatistics, Enum.TaskType.FOG_EXPLORE )
        end
        -- 迷雾探索
        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.SCOUT_MIST, addNum, nil, nil, true )
    end

    -- 发送探索发现邮件
    ScoutsLogic:scoutDiscoverVillageCaves( _rid, newOpenDenseFog )
    ScoutsLogic:scoutDiscoverHolyLands( _rid, newOpenDenseFog )
end