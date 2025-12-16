--[[
* @file : BuildingRoleMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Fri Apr 17 2020 13:37:10 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色建筑管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]


local queue = require "skynet.queue"
local BuildingLogic = require "BuildingLogic"
local RoleLogic = require "RoleLogic"
local buildingLock = {} -- { role = { lock = function } }

---@see 角色逻辑互斥锁
local function checkBuildingRoleLock( _rid )
    if not buildingLock[_rid] then
        buildingLock[_rid] = { lock = queue() }
    end
end

---@see 收集城内资源
function response.awardResources( _rid, _buildingIndexs, _action, _onlyCache )
    -- 检查互斥锁
    checkBuildingRoleLock( _rid )

    return buildingLock[_rid].lock(
        function ()

            local type = {}
            type[Enum.BuildingType.FARM] = Enum.BuildingType.FARM
            type[Enum.BuildingType.WOOD] = Enum.BuildingType.WOOD
            type[Enum.BuildingType.STONE] = Enum.BuildingType.STONE
            type[Enum.BuildingType.GOLD] = Enum.BuildingType.GOLD

            if _action == Enum.RoleResourcesAction.PLUNDER then
                local buildings = BuildingLogic:getBuilding( _rid )
                local synBuildInfo = {}
                local food = 0
                local wood = 0
                local stone = 0
                local gold = 0
                local roleInfo =  RoleLogic:getRole( _rid )
                for _, buildInfo in pairs(buildings) do
                    if buildInfo.type and type[buildInfo.type] then
                        local sBuildingResourcesProduce = CFG.s_BuildingResourcesProduce:Get()
                        if not table.empty(buildInfo) and buildInfo.level > 0 then
                            local config = sBuildingResourcesProduce[buildInfo.type][buildInfo.level]
                            local addRate = 0
                            if buildInfo.type == Enum.BuildingType.FARM then
                                addRate = roleInfo.foodCapacityMulti or 0
                            elseif buildInfo.type == Enum.BuildingType.WOOD then
                                addRate = roleInfo.woodCapacityMulti or 0
                            elseif buildInfo.type == Enum.BuildingType.STONE then
                                addRate = roleInfo.stoneCapacityMulti or 0
                            elseif buildInfo.type == Enum.BuildingType.GOLD then
                                addRate = roleInfo.glodCapacityMulti or 0
                            end
                            local addNum
                            local gatherMax = math.floor(config.gatherMax * ( 1000 + addRate ) / 1000)
                            local buildingGainInfo = buildInfo.buildingGainInfo
                            if not buildingGainInfo then buildingGainInfo = { num = 0, changeTime = os.time() } end
                            addNum = buildingGainInfo.num
                            if addNum < gatherMax then
                                addNum = addNum + math.floor(config.produceSpeed / 3600 * ( os.time() - buildingGainInfo.changeTime ) * ( 1000 + addRate ) / 1000)
                                if addNum > gatherMax then
                                    addNum = gatherMax
                                end
                            end
                            if buildInfo.type == Enum.BuildingType.FARM then
                                food = food + addNum
                            elseif buildInfo.type == Enum.BuildingType.WOOD then
                                wood = wood + addNum
                            elseif buildInfo.type == Enum.BuildingType.STONE then
                                stone = stone + addNum
                            elseif buildInfo.type == Enum.BuildingType.GOLD then
                                gold = gold + addNum
                            end

                            if not _onlyCache then
                                -- 执行收取城内资源动作
                                buildingGainInfo.changeTime = os.time()
                                buildingGainInfo.num = 0
                                buildInfo.buildingGainInfo = buildingGainInfo
                                MSM.d_building[_rid].req.Set( _rid, buildInfo.buildingIndex, buildInfo )
                                synBuildInfo[buildInfo.buildingIndex] = buildInfo
                            end
                        end
                    end
                end
                BuildingLogic:syncBuilding( _rid, nil , synBuildInfo, true )
                return { food = food, wood = wood, stone = stone, gold = gold }
            elseif _action == Enum.RoleResourcesAction.REWARD then
                return BuildingLogic:awardResources( _rid, _buildingIndexs )
            elseif _action == Enum.RoleResourcesAction.SCOUT then
                local buildings = BuildingLogic:getBuilding( _rid )
                local food = 0
                local wood = 0
                local stone = 0
                local gold = 0
                local roleInfo =  RoleLogic:getRole( _rid )
                for _, buildInfo in pairs(buildings) do
                    if buildInfo.type and type[buildInfo.type] then
                        local sBuildingResourcesProduce = CFG.s_BuildingResourcesProduce:Get()
                        if not table.empty(buildInfo) and buildInfo.level > 0 then
                            local config = sBuildingResourcesProduce[buildInfo.type][buildInfo.level]
                            local addRate = 0
                            if buildInfo.type == Enum.BuildingType.FARM then
                                addRate = roleInfo.foodCapacityMulti or 0
                            elseif buildInfo.type == Enum.BuildingType.WOOD then
                                addRate = roleInfo.woodCapacityMulti or 0
                            elseif buildInfo.type == Enum.BuildingType.STONE then
                                addRate = roleInfo.stoneCapacityMulti or 0
                            elseif buildInfo.type == Enum.BuildingType.GOLD then
                                addRate = roleInfo.glodCapacityMulti or 0
                            end
                            local addNum
                            local gatherMax = math.floor(config.gatherMax * ( 1000 + addRate ) / 1000)
                            local buildingGainInfo = buildInfo.buildingGainInfo
                            if not buildingGainInfo then buildingGainInfo = { num = 0, changeTime = os.time() } end
                            addNum = buildingGainInfo.num
                            if addNum < gatherMax then
                                addNum = addNum + math.floor(config.produceSpeed / 3600 * ( os.time() - buildingGainInfo.changeTime ) * ( 1000 + addRate ) / 1000)
                                if addNum > gatherMax then
                                    addNum = gatherMax
                                end
                            end
                            if buildInfo.type == Enum.BuildingType.FARM then
                                food = food + addNum
                            elseif buildInfo.type == Enum.BuildingType.WOOD then
                                wood = wood + addNum
                            elseif buildInfo.type == Enum.BuildingType.STONE then
                                stone = stone + addNum
                            elseif buildInfo.type == Enum.BuildingType.GOLD then
                                gold = gold + addNum
                            end
                        end
                    end
                end
                return { food = food, wood = wood, stone = stone, gold = gold }
            end
        end
    )
end
