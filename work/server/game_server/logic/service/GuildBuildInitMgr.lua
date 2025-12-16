--[[
* @file : GuildBuildInitMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Fri Apr 24 2020 15:25:24 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟建筑初始化服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local snax = require "skynet.snax"
local GuildLogic = require "GuildLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local ArmyLogic = require "ArmyLogic"
local MapObjectLogic = require "MapObjectLogic"

---@type table<int, table<int, table>>
local guildBuildPos = {}

---@see 初始化建筑信息到地图中
function response.Init()
    LOG_INFO("GuildBuildInitMgr start Init")
    -- 初始化圣地关卡坐标信息
    SM.HolyLandMgr.req.Init()

    local index = 0
    local dbNode = Common.getDbNode()
    local ret, guildInfo, mapBuildInfo, territoryFlag, territoryIds, newReinforces
    local buildObjectIndex, blockMap, armyStatus
    local guildIds = {}
    local sBuildingType = CFG.s_AllianceBuildingType:Get()
    local sConfig = CFG.s_Config:Get()
    local width = math.ceil( sConfig.kingdomMapLength / sConfig.territorySizeMin )
    local height = math.ceil( sConfig.kingdomMapWidth / sConfig.territorySizeMin )
    while true do
        ret = Common.rpcCall( dbNode, "CommonLoadMgr", "loadCommonMysqlImpl", "c_guild_building", index )
        if not ret or table.empty(ret) then
            break
        end

        for guildId, guildBuilds in pairs( ret ) do
            guildInfo = GuildLogic:getGuild( guildId )
            if guildInfo then
                guildIds[guildId] = true
                -- 添加联盟领土寻路图
                blockMap = {}
                for _ = 1, width * height do
                    table.insert( blockMap, 1 )
                end
                MSM.AStarMgr[guildId].req.InitSearchMap( guildId, blockMap, width, height )
                for _, builds in pairs( guildBuilds ) do
                    for buildIndex, buildInfo in pairs( builds ) do
                        if buildInfo.type then
                            -- body
                            territoryFlag = true
                            -- 检查建筑中是否有已解散的部队
                            newReinforces = {}
                            for reinforceIndex, reinforce in pairs( buildInfo.reinforces or {} ) do
                                armyStatus = ArmyLogic:getArmy( reinforce.rid, reinforce.armyIndex, Enum.Army.status )
                                if armyStatus and ( ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.GARRISONING )
                                    or ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.COLLECTING ) ) then
                                    newReinforces[reinforceIndex] = reinforce
                                end
                            end
                            buildInfo.reinforces = newReinforces
                            GuildBuildLogic:setGuildBuild( guildId, buildIndex, { [Enum.GuildBuild.reinforces] = newReinforces } )

                            if buildInfo.status == Enum.GuildBuildStatus.BUILDING then
                                -- 添加建造中的联盟建筑定时器，内部处理联盟建筑进入aoi
                                if not MSM.GuildTimerMgr[guildId].req.initGuildBuildTimer( guildId, buildIndex, buildInfo, guildInfo ) then
                                    territoryFlag = false
                                end
                            elseif buildInfo.status == Enum.GuildBuildStatus.BURNING then
                                -- 燃烧中
                                if not MSM.GuildTimerMgr[guildId].req.initGuildBuildBurnTimer( guildId, buildIndex, buildInfo, guildInfo ) then
                                    territoryFlag = false
                                end
                            elseif buildInfo.status == Enum.GuildBuildStatus.REPAIR then
                                -- 维修中
                                MSM.GuildTimerMgr[guildId].req.initGuildBuildDurableTimer( guildId, buildIndex, buildInfo )
                            elseif MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                                -- 增加联盟资源中心定时器
                                MSM.GuildTimerMgr[guildId].req.initResourceCenterTimer( guildId, buildIndex, buildInfo, guildInfo )
                            else
                                -- 进入地图
                                mapBuildInfo = {
                                    guildFullName = guildInfo.name,
                                    guildAbbName = guildInfo.abbreviationName,
                                    guildBuildStatus = buildInfo.status,
                                    guildId = guildId,
                                    pos = buildInfo.pos,
                                    buildIndex = buildIndex,
                                    objectType = GuildBuildLogic:buildTypeToObjectType( buildInfo.type ),
                                    durable = buildInfo.durable,
                                    durableLimit = buildInfo.durableLimit,
                                }
                                if buildInfo.type == Enum.GuildBuildType.FLAG
                                    or buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
                                    or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
                                    or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
                                    mapBuildInfo.guildFlagSigns = guildInfo.signs
                                end
                                -- 联盟建筑进入Aoi
                                MSM.MapObjectMgr[buildIndex].req.guildBuildAddMap( mapBuildInfo )
                            end

                            if territoryFlag == true and ( buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS
                                or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
                                or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND
                                or buildInfo.type == Enum.GuildBuildType.FLAG ) then
                                -- 地块占用
                                territoryIds = GuildTerritoryLogic:getPosTerritoryIds( buildInfo.pos, sBuildingType[buildInfo.type].territorySize )
                                -- 删除圣地占用地块
                                territoryIds = SM.HolyLandMgr.req.deleteHolyLandTerritoryIds( territoryIds )
                                if GuildBuildLogic:getGuildBuild( guildId, buildIndex, Enum.GuildBuild.status ) ~= Enum.GuildBuildStatus.BUILDING then
                                    -- 占用
                                    SM.TerritoryMgr.req.occupyTerritory( guildId, buildIndex, buildInfo.createTime, territoryIds, true )
                                else
                                    -- 预占用
                                    SM.TerritoryMgr.req.preOccupyTerritory( guildId, buildIndex, buildInfo.createTime, territoryIds, true )
                                end
                            end

                            if territoryFlag == true then
                                -- 更新角色中的行军目标索引
                                buildObjectIndex = MSM.GuildBuildIndexMgr[guildId].req.getGuildBuildIndex( guildId, buildIndex )
                                newReinforces = GuildBuildLogic:getGuildBuild( guildId, buildIndex, Enum.GuildBuild.reinforces ) or {}
                                for buildArmyIndex, reinforce in pairs( newReinforces or {} ) do
                                    ArmyLogic:setArmy( reinforce.rid, reinforce.armyIndex, {
                                        [Enum.Army.targetArg] = { targetObjectIndex = buildObjectIndex, pos = buildInfo.pos }
                                    } )
                                    -- 非联盟资源中心的建筑需要驻守
                                    if not MapObjectLogic:checkIsGuildResourceCenterBuild( buildInfo.type ) then
                                        -- 联盟建筑,驻守建筑
                                        MSM.SceneGuildBuildMgr[buildObjectIndex].post.addGarrisonArmy( buildObjectIndex, reinforce.rid, reinforce.armyIndex, buildArmyIndex )
                                    end
                                end
                            end

                            if not guildBuildPos[buildInfo.type] then
                                guildBuildPos[buildInfo.type] = { { x = buildInfo.pos.x, y = buildInfo.pos.y } }
                            else
                                table.insert( guildBuildPos[buildInfo.type], { x = buildInfo.pos.x, y = buildInfo.pos.y } )
                            end
                        else
                            SM.c_guild_building.req.Delete( guildId, buildIndex )
                        end
                    end
                end
            end
        end

        index = index + table.size( ret )
    end

    -- 地图联盟建筑占用地块按照时间排序
    SM.TerritoryMgr.req.sortTerritories()
    -- 初始化联盟圣地关卡信息
    SM.HolyLandMgr.req.InitGuildHolyLands()

    local allGuildBuilds, toPos
    local fromPos = {}
    local allFlags
    for guildId in pairs( guildIds ) do
        allFlags = {}
        allGuildBuilds = GuildBuildLogic:getGuildBuild( guildId )
        if table.size( allGuildBuilds ) > 0 then
            for buildIndex, buildInfo in pairs( allGuildBuilds ) do
                if buildInfo.type == Enum.GuildBuildType.CENTER_FORTRESS or buildInfo.type == Enum.GuildBuildType.FORTRESS_FIRST
                    or buildInfo.type == Enum.GuildBuildType.FORTRESS_SECOND then
                    if buildInfo.status ~= Enum.GuildBuildStatus.BUILDING then
                        table.insert( fromPos, GuildTerritoryLogic:mapPosToSearchMapPos( buildInfo.pos )[1] )
                    end
                elseif buildInfo.type == Enum.GuildBuildType.FLAG then
                    allFlags[buildIndex] = buildInfo
                end
            end

            -- 检查所有联盟建筑状态
            for buildIndex, buildInfo in pairs( allFlags ) do
                if buildInfo.status == Enum.GuildBuildStatus.INVALID or buildInfo.status == Enum.GuildBuildStatus.NORMAL then
                    toPos = GuildTerritoryLogic:territoryIdToSearchMapPos( GuildTerritoryLogic:getPosTerritoryId( buildInfo.pos ) )
                    if MSM.AStarMgr[guildId].req.findPath( guildId, fromPos, toPos ) then
                        if buildInfo.status == Enum.GuildBuildStatus.INVALID then
                            GuildBuildLogic:setGuildBuild( guildId, buildIndex, { [Enum.GuildBuild.status] = Enum.GuildBuildStatus.NORMAL } )
                            buildObjectIndex = MSM.GuildBuildIndexMgr[guildId].req.getGuildBuildIndex( guildId, buildIndex )
                            MSM.SceneGuildBuildMgr[buildObjectIndex].post.updateGuildBuildInfo( buildObjectIndex, { guildBuildStatus = Enum.GuildBuildStatus.NORMAL } )
                        end
                    else
                        if buildInfo.status == Enum.GuildBuildStatus.NORMAL then
                            GuildBuildLogic:setGuildBuild( guildId, buildIndex, { [Enum.GuildBuild.status] = Enum.GuildBuildStatus.INVALID } )
                            buildObjectIndex = MSM.GuildBuildIndexMgr[guildId].req.getGuildBuildIndex( guildId, buildIndex )
                            MSM.SceneGuildBuildMgr[buildObjectIndex].post.updateGuildBuildInfo( buildObjectIndex, { guildBuildStatus = Enum.GuildBuildStatus.INVALID } )
                        end
                    end
                end
            end
            -- 更新有效旗帜数量
            GuildLogic:setGuild( guildId, { [Enum.Guild.territory] = table.size( allFlags ) } )
        end
        -- 更新联盟主界面领土建筑图标
        GuildBuildLogic:updateGuildBuildFlag( guildId )
    end

    LOG_INFO("GuildBuildInitMgr Init over")

    Timer.runAfter( 300, function ()
        snax.exit()
    end)
end