--[[
* @file : MapFixPointMgr.lua
* @type : snax single service
* @author : dingyuchao九  零 一 起 玩 w w w . 9 0 1 7 5 . co m
* @created : Mon Feb 24 2020 17:03:30 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 村庄山洞刷新服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local Timer = require "Timer"
local GuildLogic = require "GuildLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"

---@see 初始化
function response.Init()
    -- 刷新村庄山洞进入地图
    local pos, mapGuildResourceInfo, territoryId, guildId, objectIndex
    local guilds = {}
    local sMapFixPoint = CFG.s_MapFixPoint:Get()
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    local sAllianceBuildingType = CFG.s_AllianceBuildingType:Get()
    local refreshNum = 0
    local pointSum = table.size( sMapFixPoint )
    LOG_INFO("MapFixPointMgr init start sum(%d)", pointSum)
    for id, mapFixPoint in pairs( sMapFixPoint ) do
        if mapFixPoint.group == Enum.MapPointFixGroup.VILLAGE_CAVE then
            -- 村庄、山洞进入aoi
            if sResourceGatherType[mapFixPoint.type] then
                pos = { x = mapFixPoint.posX, y = mapFixPoint.posY }
                -- 对象进入地图
                MSM.MapObjectMgr[id].req.villageCaveAddMap( id, pos, sResourceGatherType[mapFixPoint.type].type )
            end
        elseif mapFixPoint.group == Enum.MapPointFixGroup.GUILD_RESOURCE_POINT then
            -- 联盟资源点进入aoi
            if sAllianceBuildingType[mapFixPoint.type] then
                pos = { x = mapFixPoint.posX, y = mapFixPoint.posY }
                -- 坐标所在地块
                territoryId = GuildTerritoryLogic:getPosTerritoryId( pos )
                guildId = SM.TerritoryMgr.req.getTerritoryGuildId( territoryId )
                mapGuildResourceInfo = {
                    pos = pos,
                    objectType = GuildBuildLogic:buildTypeToObjectType( mapFixPoint.type ),
                }
                -- 获取联盟相关信息
                if guildId and guildId > 0 then
                    if not guilds[guildId] then
                        guilds[guildId] = GuildLogic:getGuild( guildId, { Enum.Guild.abbreviationName } )
                    end
                    mapGuildResourceInfo.guildAbbName = guilds[guildId].abbreviationName
                    mapGuildResourceInfo.guildId = guildId
                end
                objectIndex = Common.newMapObjectIndex()
                MSM.AoiMgr[Enum.MapLevel.GUILD].req.guildResourcePointEnter( Enum.MapLevel.GUILD, objectIndex, pos, pos, mapGuildResourceInfo )
                SM.ResourcePointMgr.post.addTerritoryResourcePoint( pos, objectIndex, mapFixPoint.type )
            end
        end
        refreshNum = refreshNum + 1
        if refreshNum % 1000 == 0 then
            LOG_INFO("MapFixPointMgr init %d/%d", refreshNum, pointSum)
        end
    end
    LOG_INFO("MapFixPointMgr init over")

    -- 服务退出
    Timer.runAfter( 3 * 100, function ()
        snax.exit()
    end)
end