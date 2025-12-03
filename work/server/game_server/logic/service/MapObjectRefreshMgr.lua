--[[
* @file : MapObjectRefreshMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Wed May 13 2020 15:36:24 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图对象刷新服务(野蛮人城寨)
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local MapLogic = require "MapLogic"
local HolyLandLogic = require "HolyLandLogic"
local MonsterCityLogic = require "MonsterCityLogic"
local ResourceLogic = require "ResourceLogic"
local MonsterLogic = require 'MonsterLogic'

local allServiceCount = 0
local finishServiceCount = 0

---@see 服务刷新信息
---@type table<int, table<string, int>>
local refreshServiceInfos = {}

---@see 初始化
function response.Init()
    -- 初始化调用在MapObjectMgr之后
    local maxZoneIndex = MapLogic:getMaxZoneIndex()
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM

    -- 瓦片平均分配给每个服务
    local serviceZones = {}
    local serviceIndex
    for i = 1, maxZoneIndex do
        serviceIndex = i % multiSnaxNum + 1
        if not serviceZones[serviceIndex] then
            serviceZones[serviceIndex] = { i }
        else
            table.insert( serviceZones[serviceIndex], i )
        end
    end

    local refreshType
    -- 野蛮人城寨刷新
    refreshType = Enum.MapObjectRefreshType.BARBARIAN_CITY
    refreshServiceInfos[refreshType] = {
        serviceCount = multiSnaxNum,
        finishServiceCount = 0,
        refreshGroup = 1
    }
    if MonsterCityLogic:monsterCityInit( serviceZones ) then
        -- 服务器重启刷新，等待刷新完成添加下一次刷新定时器
        allServiceCount = allServiceCount + multiSnaxNum
        refreshServiceInfos[refreshType].refreshGroup = 0
    else
        -- 未到时间刷新，添加下一次刷新定时器
        local groupZones = MapLogic:getGroupZoneIndexs( refreshType, refreshServiceInfos[refreshType].refreshGroup, multiSnaxNum )
        refreshServiceInfos[refreshType].serviceCount = table.size( groupZones or {} )
        MonsterCityLogic:addMonsterCityRefreshTimer( refreshServiceInfos[refreshType].refreshGroup )
    end

    -- 野蛮人刷新处理
    refreshType = Enum.MapObjectRefreshType.BARBARIAN
    refreshServiceInfos[refreshType] = {
        serviceCount = multiSnaxNum,
        finishServiceCount = 0,
        refreshGroup = 1
    }
    if MonsterLogic:monsterInit( serviceZones ) then
        allServiceCount = allServiceCount + multiSnaxNum
        refreshServiceInfos[refreshType].refreshGroup = 0
    else
        -- 未到时间刷新，添加下一次刷新定时器
        local groupZones = MapLogic:getGroupZoneIndexs( refreshType, refreshServiceInfos[refreshType].refreshGroup, multiSnaxNum )
        refreshServiceInfos[refreshType].serviceCount = table.size( groupZones or {} )
        MonsterLogic:addMonsterRefreshTimer( refreshServiceInfos[refreshType].refreshGroup )
    end

    -- 资源点刷新处理
    refreshType = Enum.MapObjectRefreshType.RESOURCE
    refreshServiceInfos[refreshType] = {
        serviceCount = multiSnaxNum,
        finishServiceCount = 0,
        refreshGroup = 1
    }
    if ResourceLogic:resourceInit( serviceZones ) then
        -- 服务器重启刷新，等待刷新完成添加下一次刷新定时器
        allServiceCount = allServiceCount + multiSnaxNum
        refreshServiceInfos[refreshType].refreshGroup = 0
    else
        -- 未到时间刷新，添加下一次刷新定时器
        local groupZones = MapLogic:getGroupZoneIndexs( refreshType, refreshServiceInfos[refreshType].refreshGroup, multiSnaxNum )
        refreshServiceInfos[refreshType].serviceCount = table.size( groupZones or {} )
        ResourceLogic:addResourceRefreshTimer( refreshServiceInfos[refreshType].refreshGroup )
    end

    -- 守护者刷新处理
    if HolyLandLogic:guardInit() then
        allServiceCount = allServiceCount + multiSnaxNum
    end

    -- 等待地图对象刷新完成
    LOG_INFO("wait for all(%d) refresh service over", allServiceCount)
    while allServiceCount > finishServiceCount do
        skynet.sleep( 100 )
    end
    LOG_INFO("all(%d) refresh service over", allServiceCount)
end

function response.addFinishService( _isInit, _refreshType )
    if _isInit then
        -- 启动日志
        finishServiceCount = finishServiceCount + 1
        LOG_INFO("MapObjectRefreshMgr complete(%d/%d)", finishServiceCount, allServiceCount)
    end

    if _refreshType and refreshServiceInfos[_refreshType] then
        local refreshServiceInfo = refreshServiceInfos[_refreshType]
        refreshServiceInfo.finishServiceCount = refreshServiceInfo.finishServiceCount + 1
        if _refreshType == Enum.MapObjectRefreshType.RESOURCE then
            -- 资源田刷新
            if refreshServiceInfo.finishServiceCount >= refreshServiceInfo.serviceCount then
                LOG_INFO("ResourceLogic resourceRefresh group(%s) over", tostring(refreshServiceInfo.refreshGroup))
                refreshServiceInfo.finishServiceCount = 0
                refreshServiceInfo.refreshGroup = refreshServiceInfo.refreshGroup + 1
                local resourceFreshTileGap = CFG.s_Config:Get( "resourceFreshTileGap" )
                if not resourceFreshTileGap or resourceFreshTileGap <= 1 then
                    resourceFreshTileGap = 18
                end
                if refreshServiceInfo.refreshGroup > resourceFreshTileGap then
                    refreshServiceInfo.refreshGroup = 1
                end
                refreshServiceInfo.serviceCount = table.size( MapLogic:getGroupZoneIndexs( _refreshType, refreshServiceInfo.refreshGroup ) )
                ResourceLogic:addResourceRefreshTimer( refreshServiceInfo.refreshGroup )
            end
        elseif _refreshType == Enum.MapObjectRefreshType.BARBARIAN_CITY then
            -- 野蛮人城寨刷新
            if refreshServiceInfo.finishServiceCount >= refreshServiceInfo.serviceCount then
                LOG_INFO("MonsterCityLogic monsterCityRefresh group(%s) over", tostring(refreshServiceInfo.refreshGroup))
                refreshServiceInfo.finishServiceCount = 0
                refreshServiceInfo.refreshGroup = refreshServiceInfo.refreshGroup + 1
                local fortressFreshTileGap = CFG.s_Config:Get( "fortressFreshTileGap" )
                if not fortressFreshTileGap or fortressFreshTileGap <= 1 then
                    fortressFreshTileGap = 18
                end
                if refreshServiceInfo.refreshGroup > fortressFreshTileGap then
                    refreshServiceInfo.refreshGroup = 1
                end
                refreshServiceInfo.serviceCount = table.size( MapLogic:getGroupZoneIndexs( _refreshType, refreshServiceInfo.refreshGroup ) )
                MonsterCityLogic:addMonsterCityRefreshTimer( refreshServiceInfo.refreshGroup )
            end
        elseif _refreshType == Enum.MapObjectRefreshType.BARBARIAN then
            -- 野蛮人刷新
            if refreshServiceInfo.finishServiceCount >= refreshServiceInfo.serviceCount then
                LOG_INFO("MonsterLogic monsterRefresh group(%s) over", tostring(refreshServiceInfo.refreshGroup))
                refreshServiceInfo.finishServiceCount = 0
                refreshServiceInfo.refreshGroup = refreshServiceInfo.refreshGroup + 1
                local barbarianFreshTileGap = CFG.s_Config:Get( "barbarianFreshTileGap" )
                if not barbarianFreshTileGap or barbarianFreshTileGap <= 1 then
                    barbarianFreshTileGap = 18
                end
                if refreshServiceInfo.refreshGroup > barbarianFreshTileGap then
                    refreshServiceInfo.refreshGroup = 1
                end
                refreshServiceInfo.serviceCount = table.size( MapLogic:getGroupZoneIndexs( _refreshType, refreshServiceInfo.refreshGroup ) )
                MonsterLogic:addMonsterRefreshTimer( refreshServiceInfo.refreshGroup )
            end
        end
    end
end
