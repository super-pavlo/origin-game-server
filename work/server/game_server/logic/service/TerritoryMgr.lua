--[[
* @file : TerritoryMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Thu Apr 23 2020 09:20:45 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图领地区块管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildTerritoryLogic = require "GuildTerritoryLogic"
local GuildBuildLogic = require "GuildBuildLogic"

---@see 本服领土信息
local territories = {}

local function getGuildBuildInfoInTerritory( _guildId, _buildIndex, _guildbuilds )
    if not _guildbuilds[_guildId] then
        _guildbuilds[_guildId] = {}
    end
    if not _guildbuilds[_guildId][_buildIndex] then
        _guildbuilds[_guildId][_buildIndex] = GuildBuildLogic:getGuildBuild( _guildId, _buildIndex, { Enum.GuildBuild.pos, Enum.GuildBuild.status } )
    end

    return _guildbuilds[_guildId][_buildIndex]
end

---@see 排序占用时间
function response.sortTerritories()
    local guildId, buildIndex, occupyGuildId, occupyBuildIndex, buildInfo
    local buildingStatus = Enum.GuildBuildStatus.BUILDING
    local guildTerritoryIds = {}
    local guildBuilds = {}
    for territoryId, territory in pairs( territories ) do
        table.sort( territory.occupy, function ( a, b )
            if a.occupyTime == b.occupyTime then
                return a.guildId < b.guildId
            else
                return a.occupyTime < b.occupyTime
            end
        end )

        if territory.occupy[1] then
            guildId = territory.occupy[1].guildId
            buildIndex = territory.occupy[1].buildIndex
            occupyGuildId = nil
            occupyBuildIndex = nil
            for _, occupyInfo in pairs( territory.occupy ) do
                buildInfo = getGuildBuildInfoInTerritory( occupyInfo.guildId, occupyInfo.buildIndex, guildBuilds )
                if GuildTerritoryLogic:getPosTerritoryId( buildInfo.pos ) == territoryId then
                    occupyGuildId = occupyInfo.guildId
                    occupyBuildIndex = occupyInfo.buildIndex
                    break
                end
            end


            if occupyGuildId and guildId ~= occupyGuildId then
                guildId = occupyGuildId
                buildIndex = occupyBuildIndex
            end

            buildInfo = getGuildBuildInfoInTerritory( guildId, buildIndex, guildBuilds )
            if buildInfo.status == buildingStatus then
                buildIndex = nil
                for _, occupyInfo in pairs( territory.occupy ) do
                    if occupyInfo.guildId == guildId and occupyInfo.buildIndex ~= buildIndex then
                        buildInfo = getGuildBuildInfoInTerritory( occupyInfo.guildId, occupyInfo.buildIndex, guildBuilds )
                        if buildInfo.status ~= buildingStatus then
                            buildIndex = occupyInfo.buildIndex
                            break
                        end
                    end
                end
                if not buildIndex then
                    buildIndex = territory.occupy[1].buildIndex
                end
            end

            if not guildTerritoryIds[guildId] then
                guildTerritoryIds[guildId] = {
                    occupyTerritoryIds = {},
                    preOccupyTerritoryIds = {},
                }
            end
            buildInfo = getGuildBuildInfoInTerritory( guildId, buildIndex, guildBuilds )
            if buildInfo.status ~= buildingStatus then
                territory.occupyGuildId = guildId
                territory.occupyBuildIndex = buildIndex
                table.insert( guildTerritoryIds[guildId].occupyTerritoryIds, territoryId )
            else
                table.insert( guildTerritoryIds[guildId].preOccupyTerritoryIds, territoryId )
            end
        end
    end

    for id, guildInfo in pairs( guildTerritoryIds ) do
        -- 旗帜所在点设置为可行走点
        MSM.AStarMgr[id].req.setWalkable( id, guildInfo.occupyTerritoryIds )
        -- 联盟占领地块
        MSM.GuildTerritoryMgr[id].req.addGuildTerritory( id, guildInfo.occupyTerritoryIds, guildInfo.preOccupyTerritoryIds, true )
    end
end

---@see 移除领土占用
function response.delTerritories( _guildId, _buildIndex, _territories, _lock, _disbandGuild )
    local guildId, buildIndex, territoryInfo, occupyIndex, buildInfo, buildStatus
    local occupyGuildTerritorys = {}
    local delOccupyTerritories = {}
    for _, territoryId in pairs( _territories ) do
        territoryInfo = territories[territoryId]
        if territoryInfo then
            if ( not territoryInfo.occupyGuildId or territoryInfo.occupyGuildId <= 0 )
                or ( territoryInfo.occupyGuildId == _guildId and territoryInfo.occupyBuildIndex == _buildIndex ) then
                -- 未被占领或被该建筑占领
                guildId = nil
                buildIndex = nil
                occupyIndex = nil
                buildStatus = nil
                for index, occupyInfo in pairs( territoryInfo.occupy or {} ) do
                    if occupyInfo.guildId == _guildId and occupyInfo.buildIndex == _buildIndex then
                        occupyIndex = index
                    else
                        -- 该地块上是否有联盟建筑
                        buildInfo = GuildBuildLogic:getGuildBuild( occupyInfo.guildId, occupyInfo.buildIndex, { Enum.GuildBuild.pos, Enum.GuildBuild.status } )

                        if GuildTerritoryLogic:getPosTerritoryId( buildInfo.pos ) == territoryId then
                            guildId = occupyInfo.guildId
                            buildIndex = occupyInfo.buildIndex
                            buildStatus = buildInfo.status
                            -- break
                        end
                    end
                end
                if occupyIndex then
                    table.remove( territoryInfo.occupy, occupyIndex )
                end
                -- 地块上无建筑, 找到建造时间最早的联盟建筑
                if not guildId then
                    if territoryInfo.occupy[1] then
                        guildId = territoryInfo.occupy[1].guildId
                        buildIndex = territoryInfo.occupy[1].buildIndex
                        buildStatus = GuildBuildLogic:getGuildBuild( guildId, buildIndex, Enum.GuildBuild.status )
                    end
                end

                -- 当前地块还在被占用中
                if guildId then
                    if buildStatus == Enum.GuildBuildStatus.BUILDING then
                        -- 检查同联盟是否有其他状态的建筑
                        for _, occupyInfo in pairs( territoryInfo.occupy or {} ) do
                            if occupyInfo.guildId == guildId and occupyInfo.buildIndex ~= buildIndex then
                                buildStatus = GuildBuildLogic:getGuildBuild( occupyInfo.guildId, occupyInfo.buildIndex, Enum.GuildBuild.status )
                                if buildStatus ~= Enum.GuildBuildStatus.BUILDING then
                                    guildId = occupyInfo.guildId
                                    buildIndex = occupyInfo.buildIndex
                                    break
                                end
                            end
                        end
                    end
                    if not occupyGuildTerritorys[guildId] then
                        occupyGuildTerritorys[guildId] = {
                            occupy = {},
                            preOccupy = {}
                        }
                    end
                    -- 被其他联盟占领
                    if guildId ~= _guildId or buildStatus == Enum.GuildBuildStatus.BUILDING then
                        table.insert( delOccupyTerritories, territoryId )
                    end
                    -- 联盟占领状态
                    if buildStatus ~= Enum.GuildBuildStatus.BUILDING then
                        territoryInfo.occupyGuildId = guildId
                        territoryInfo.occupyBuildIndex = buildIndex
                        table.insert( occupyGuildTerritorys[guildId].occupy, territoryId )
                    else
                        territoryInfo.occupyGuildId = nil
                        territoryInfo.occupyBuildIndex = nil
                        table.insert( occupyGuildTerritorys[guildId].preOccupy, territoryId )
                    end
                else
                    -- 未被占领
                    table.insert( delOccupyTerritories, territoryId )
                    territoryInfo.occupyGuildId = nil
                    territoryInfo.occupyBuildIndex = nil
                end
            else
                -- 被该联盟其他建筑占领
                for index, occupyInfo in pairs( territoryInfo.occupy or {} ) do
                    if occupyInfo.guildId == _guildId and occupyInfo.buildIndex == _buildIndex then
                        table.remove( territoryInfo.occupy, index )
                        break
                    end
                end
            end
        end
    end
    -- 相应坐标设为不可行走
    MSM.AStarMgr[_guildId].req.setUnwalkable( _guildId, delOccupyTerritories )

    -- 联盟移除地块
    local delGuildTerritory
    local delGuildTerritories = {}
    if #delOccupyTerritories > 0 then
        delGuildTerritory = MSM.GuildTerritoryMgr[_guildId].req.deleteGuildTerritory( _guildId, delOccupyTerritories, _lock, _disbandGuild, true )
        if delGuildTerritory then
            table.merge( delGuildTerritories, delGuildTerritory )
        end
    end

    -- 联盟增加地块
    local addGuildTerritory
    local addGuildTerritories = {}
    for id, occupyInfo in pairs( occupyGuildTerritorys ) do
        if not ( _disbandGuild and id == _guildId ) then
            -- 旗帜所在点设置为可行走点
            MSM.AStarMgr[id].req.setWalkable( id, occupyInfo.occupy )
            -- 联盟占领地块
            addGuildTerritory, delGuildTerritory = MSM.GuildTerritoryMgr[id].req.addGuildTerritory( id, occupyInfo.occupy, occupyInfo.preOccupy, true )
            table.merge( addGuildTerritories, addGuildTerritory or {} )
            table.merge( delGuildTerritories, delGuildTerritory or {} )
        end
    end

    if _disbandGuild then
        delGuildTerritories = nil
    end

    if not _disbandGuild and ( #addGuildTerritories > 0 or #( delGuildTerritories or {} ) > 0 ) then
        GuildTerritoryLogic:syncGuildTerritories( nil, nil, addGuildTerritories, delGuildTerritories )
    end

    return delOccupyTerritories, addGuildTerritories, delGuildTerritories
end

---@see 获取占用领地的联盟ID
function response.getTerritoryGuildId( _territoryId, _isPreOccupy )
    if territories[_territoryId] then
        if territories[_territoryId].occupyGuildId and territories[_territoryId].occupyGuildId > 0 then
            return territories[_territoryId].occupyGuildId, territories[_territoryId].occupyBuildIndex
        end
        if _isPreOccupy then
            local buildInfo
            for _, occupyInfo in pairs( territories[_territoryId].occupy ) do
                buildInfo = GuildBuildLogic:getGuildBuild( occupyInfo.guildId, occupyInfo.buildIndex, { Enum.GuildBuild.pos, Enum.GuildBuild.status } )
                if GuildTerritoryLogic:getPosTerritoryId( buildInfo.pos ) == _territoryId then
                    return occupyInfo.guildId, occupyInfo.buildIndex
                end
            end
            if #territories[_territoryId].occupy > 0 then
                return territories[_territoryId].occupy[1].guildId, territories[_territoryId].occupy[1].buildIndex
            end
        end
    end
end

---@see 获取未被占领或指定联盟占领的地块
function response.deleteOtherGuildTerritory( _territoryIds, _guildId, _preOccupy )
    local newTerritoryIds = {}
    for _, territoryId in pairs( _territoryIds ) do
        if territories[territoryId] then
            if territories[territoryId].occupyGuildId and territories[territoryId].occupyGuildId > 0 then
                if territories[territoryId].occupyGuildId == _guildId then
                    -- 已被该联盟占领
                    table.insert( newTerritoryIds, territoryId )
                end
            elseif _preOccupy then
                -- 还未被占领查看是否有预占领联盟
                local buildPos, addFlag
                for _, occupyInfo in pairs( territories[territoryId].occupy ) do
                    if _guildId == occupyInfo.guildId then
                        buildPos = GuildBuildLogic:getGuildBuild( occupyInfo.guildId, occupyInfo.buildIndex, Enum.GuildBuild.pos )
                        if GuildTerritoryLogic:getPosTerritoryId( buildPos ) == territoryId then
                            table.insert( newTerritoryIds, territoryId )
                            addFlag = true
                            break
                        end
                    end
                end
                if not addFlag and ( not territories[territoryId].occupy[1] or territories[territoryId].occupy[1].guildId == _guildId ) then
                    table.insert( newTerritoryIds, territoryId )
                end
            end
        else
            -- 领土未占领
            table.insert( newTerritoryIds, territoryId )
        end
    end

    return newTerritoryIds
end

---@see 检查地块是否属于指定联盟
function response.checkGuildTerritory( _territoryIds, _guildId )
    for territoryId in pairs( _territoryIds ) do
        if territories[territoryId] and territories[territoryId].occupyGuildId
            and territories[territoryId].occupyGuildId == _guildId then
            return true
        end
    end

    return false
end

---@see 建造中建筑预占领地块
function response.preOccupyTerritory( _guildId, _buildIndex, _occupyTime, _territories, _territoryId, _isInit )
    if _territoryId then
        local territoryInfo = territories[_territoryId]
        if territoryInfo then
            if territoryInfo.occupyGuildId and territoryInfo.occupyGuildId > 0 then
                if territoryInfo.occupyGuildId ~= _guildId then
                    -- 该地块被其他联盟占领
                    return false
                end
            else
                if territoryInfo.occupy[1] and territoryInfo.occupy[1].guildId ~= _guildId then
                    -- 该地块被其他联盟预占领
                    return false
                end
            end
        end
    end

    local occupyIndex
    local preOccupyTerritoryIds = {}
    for _, territoryId in pairs( _territories ) do
        if not territories[territoryId] then
            territories[territoryId] = {
                occupy = {},
            }
        end

        occupyIndex = nil
        for index, occupyInfo in pairs( territories[territoryId].occupy ) do
            -- 根据预占领时间和联盟id排序
            if occupyInfo.occupyTime > _occupyTime
                or ( occupyInfo.occupyTime == _occupyTime and _guildId < occupyInfo.guildId ) then
                table.insert( territories[territoryId].occupy, {
                    guildId = _guildId,
                    buildIndex = _buildIndex,
                    occupyTime = _occupyTime,
                } )
                occupyIndex = index
                break
            end
        end
        if not occupyIndex then
            table.insert( territories[territoryId].occupy, {
                guildId = _guildId,
                buildIndex = _buildIndex,
                occupyTime = _occupyTime,
            } )
        end
        if not _isInit and territories[territoryId].occupy[1].guildId == _guildId
            and territories[territoryId].occupy[1].buildIndex == _buildIndex then
            table.insert( preOccupyTerritoryIds, territoryId )
        end
    end

    if not _isInit then
        -- 联盟预占领地块
        MSM.GuildTerritoryMgr[_guildId].req.addGuildTerritory( _guildId, nil, preOccupyTerritoryIds )
    end

    return true
end

---@see 占用领土
function response.occupyTerritory( _guildId, _buildIndex, _occupyTime, _territoryIds, _isInit, _centerTerritoryId )
    local occupyTerritories = {}
    for _, territoryId in pairs( _territoryIds ) do
        if not territories[territoryId] then
            territories[territoryId] = {
                occupy = {},
            }
        end

        if _isInit then
            table.insert( territories[territoryId].occupy, {
                guildId = _guildId,
                buildIndex = _buildIndex,
                occupyTime = _occupyTime,
            } )
        else
            if ( _centerTerritoryId and _centerTerritoryId == territoryId ) or ( territories[territoryId].occupy[1]
                and territories[territoryId].occupy[1].guildId == _guildId ) then
                -- 地块占用成功
                territories[territoryId].occupyGuildId = _guildId
                territories[territoryId].occupyBuildIndex = _buildIndex
                table.insert( occupyTerritories, territoryId )
            end
        end
    end

    if not _isInit and #occupyTerritories > 0 then
        -- 旗帜所在点设置为可行走点
        MSM.AStarMgr[_guildId].req.setWalkable( _guildId, occupyTerritories )
        -- 联盟占领地块
        MSM.GuildTerritoryMgr[_guildId].req.addGuildTerritory( _guildId, occupyTerritories )
    end

    return occupyTerritories
end

---@see 检查地块上是否已有联盟建筑
function response.checkTerritoryBuild( _territoryId )
    if territories[_territoryId] then
        local pos
        for _, occupyInfo in pairs( territories[_territoryId].occupy ) do
            pos = GuildBuildLogic:getGuildBuild( occupyInfo.guildId, occupyInfo.buildIndex, Enum.GuildBuild.pos )
            if GuildTerritoryLogic:getPosTerritoryId( pos ) == _territoryId then
                return occupyInfo.guildId, occupyInfo.buildIndex
            end
        end
    end
end