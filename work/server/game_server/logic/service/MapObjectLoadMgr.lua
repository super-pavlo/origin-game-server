--[[
 * @file : MapObjectLoadMgr.lua
 * @type : snax single service
 * @author : linfeng
 * @created : 2020-05-06 19:16:01
 * @Last Modified time: 2020-05-06 19:16:01
 * @department : Arabic Studio
 * @brief : 地图对象加载管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local BuildingLogic = require "BuildingLogic"
local ArmyLogic = require "ArmyLogic"
local MapObjectLogic = require "MapObjectLogic"
local ResourceLogic = require "ResourceLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local CityReinforceLogic = require "CityReinforceLogic"
local MapLogic = require "MapLogic"
local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"

function accept.loadMapObject( _fromIndex, _limit )
    LOG_INFO("MapObjectMgr start Init %d", _fromIndex)
    local dbNode = Common.getDbNode()
    local index = _fromIndex
    local cityInfo
    local sResourceGatherType = CFG.s_ResourceGatherType:Get()
    local sMonster = CFG.s_Monster:Get()
    local resourceInfo, monsterInfo, collectRid, armyIndex
    local armyInfo, resourceLoadIndex, serviceIndex, roleInfo, mapResourceInfo
    local deleteIndexs = {}
    local collectSpeedMultiple = Enum.ResourceCollectSpeedMultiple
    local ret = Common.rpcCall( dbNode, "CommonLoadMgr", "loadCommonMysqlImpl", "c_map_object", index, _limit )
    if not ret or table.empty(ret) then
        LOG_INFO("MapObjectMgr over Init %d, not found any", _fromIndex)
        return
    end
    local nowTime = os.time()
    local sCityHideData = CFG.s_CityHideData:Get()
    local hideCityExitAlliance = CFG.s_Config:Get( "hideCityExitAlliance" ) or 9
    for objectId, objectInfo in pairs(ret) do
        repeat
            -- 加入地图AOI
            local objectIndex = Common.newMapObjectIndex()
            if objectInfo.objectType == Enum.RoleType.CITY then
                -- 城市
                local attrs = { Enum.Role.lastLogoutTime, Enum.Role.createTime, Enum.Role.level, Enum.Role.name, Enum.Role.guildId }
                roleInfo = RoleLogic:getRole( objectInfo.objectRid, attrs )
                if not roleInfo then
                    break
                end

                local bLegal = true
                if not roleInfo or table.size(roleInfo) < table.size(attrs) then
                    bLegal = false
                    LOG_ERROR("rid:%d %s", objectInfo.objectRid, tostring(roleInfo))
                end

                if bLegal and not sCityHideData[roleInfo.level] or roleInfo.lastLogoutTime + sCityHideData[roleInfo.level].hideCityTime > nowTime
                    or roleInfo.createTime + sCityHideData[roleInfo.level].hideCityTime > nowTime
                    or ( roleInfo.guildId > 0 and ( GuildLogic:getRoleGuildJob( roleInfo.guildId, objectInfo.objectRid ) or 0 ) == Enum.GuildJob.LEADER )
                    or not SM.MapCityMgr.req.checkMapCityFullOnServerReboot() then
                    -- 1. 该等级城市不需要回收
                    -- 2. 城市还未到回收时间
                    -- 3. 角色为盟主
                    -- 4. 地图上的城市数量还未到限定值
                    cityInfo = {
                        rid = objectInfo.objectRid,
                        name = objectInfo.objectName,
                        country = objectInfo.objectCountry,
                        pos = objectInfo.objectPos
                    }
                    MSM.AoiMgr[Enum.MapLevel.CITY].req.cityEnter( Enum.MapLevel.CITY, objectIndex, objectInfo.objectPos, objectInfo.objectPos, cityInfo )
                    BuildingLogic:serverResetWall( objectInfo.objectRid, objectIndex )
                    -- 检查角色增援信息
                    CityReinforceLogic:checkRoleReinforceOnReboot( objectInfo.objectRid, objectIndex )
                    if sCityHideData[roleInfo.level] then
                        -- 添加到城市隐藏服务中
                        MSM.CityHideMgr[objectInfo.objectRid].post.addCity( objectInfo.objectRid )
                    end
                    -- 添加到角色推荐和角色昵称查询服务中
                    SM.RoleRecommendMgr.post.initRole( objectInfo.objectRid, roleInfo )
                    -- 更新地图城市数量管理服务
                    SM.MapCityMgr.post.addCityNum()
                else
                    table.insert( deleteIndexs, objectId )
                    RoleLogic:setRole( objectInfo.objectRid, Enum.Role.cityId, 0 )
                    -- 角色等级小于指定等级，退出联盟
                    if roleInfo.guildId and roleInfo.guildId > 0 and roleInfo.level and roleInfo.level <= hideCityExitAlliance
                        and ( GuildLogic:getRoleGuildJob( roleInfo.guildId, objectInfo.objectRid ) or 0 ) ~= Enum.GuildJob.LEADER then
                        MSM.GuildMgr[roleInfo.guildId].req.exitGuild( roleInfo.guildId, objectInfo.objectRid, Enum.GuildExitType.EXIT )
                    end
                end
            elseif MapObjectLogic:checkIsResourceObject( objectInfo.objectType ) then
                -- 资源点
                resourceInfo = sResourceGatherType[objectInfo.resourceId]
                if ( not objectInfo.collectRid or objectInfo.collectRid <= 0 ) then
                    -- 资源未被采集
                    if objectInfo.refreshTime + resourceInfo.timeLimit <= nowTime then
                        -- 资源点已过期, 删除资源点
                        -- SM.c_map_object.req.Delete( objectId )
                        table.insert( deleteIndexs, objectId )
                    else
                        -- 资源点未过期, 资源点加入地图aoi
                        MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.resourceEnter( Enum.MapLevel.RESOURCE, objectIndex, objectInfo.objectPos,
                                    objectInfo.objectPos, objectInfo, objectInfo.objectType )
                        -- ResourceMgr服务增加资源点信息
                        serviceIndex = MapLogic:getObjectService( objectInfo.objectPos )
                        MSM.ResourceMgr[serviceIndex].req.addResourceInfo( objectId, objectIndex, objectInfo )
                    end
                else
                    -- 资源点正在被采集
                    local collectSum = ( objectInfo.collectSpeed or 0 ) / collectSpeedMultiple * ( nowTime - objectInfo.collectTime )
                    if objectInfo.armyIndex and objectInfo.armyIndex > 0 then
                        armyInfo = ArmyLogic:getArmy( objectInfo.collectRid, objectInfo.armyIndex )
                        if armyInfo and not table.empty(armyInfo) and ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                            mapResourceInfo = nil
                            if armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex > 0 then
                                mapResourceInfo = MSM.SceneResourceMgr[armyInfo.targetArg.targetObjectIndex].req.getResourceInfo( armyInfo.targetArg.targetObjectIndex )
                            end
                            if not mapResourceInfo or mapResourceInfo.collectRid ~= objectInfo.collectRid or mapResourceInfo.armyIndex ~= objectInfo.armyIndex then
                                -- 已经采集的总量
                                for _, speedInfo in pairs( armyInfo.collectResource and armyInfo.collectResource.collectSpeeds or {} ) do
                                    collectSum = collectSum + speedInfo.collectSpeed / collectSpeedMultiple * speedInfo.collectTime
                                end
                                collectSum = math.floor( collectSum )
                                -- 部队负载总量
                                local armyLoadSum = ResourceLogic:getArmyLoad( objectInfo.collectRid, objectInfo.armyIndex, armyInfo )
                                -- 负载转为该资源携带量
                                armyLoadSum = ResourceLogic:loadToResourceCount( resourceInfo.type, armyLoadSum )
                                -- 实际采集量
                                local realCollect = collectSum
                                if realCollect > armyLoadSum then
                                    realCollect = armyLoadSum
                                end
                                if realCollect >= objectInfo.resourceAmount then
                                    realCollect = objectInfo.resourceAmount
                                end
                                if realCollect >= objectInfo.resourceAmount or realCollect >= armyLoadSum then
                                    -- 资源点被采集完或者部队负载已满，部队回城处理
                                    if not armyInfo.resourceLoads then
                                        armyInfo.resourceLoads = {}
                                    end
                                    for loadIndex, loadInfo in pairs( armyInfo.resourceLoads ) do
                                        -- 如果已有该资源点的采集信息，合并处理
                                        if loadInfo.resourceId == objectId then
                                            resourceLoadIndex = loadIndex
                                            loadInfo.load = loadInfo.load + realCollect
                                            break
                                        end
                                    end

                                    -- 不存在该资源点的采集信息，新增采集信息
                                    if not resourceLoadIndex then
                                        table.insert( armyInfo.resourceLoads, {
                                            resourceTypeId = objectInfo.resourceId, pos = objectInfo.objectPos,
                                            load = realCollect, resourceId = objectId
                                        } )
                                    end
                                    -- 清除军队正在采集的资源信息
                                    armyInfo.collectResource = {}
                                    -- 更新部队信息
                                    ArmyLogic:setArmy( objectInfo.collectRid, objectInfo.armyIndex, armyInfo )
                                    collectRid = objectInfo.collectRid
                                    armyIndex = objectInfo.armyIndex
                                    if realCollect >= objectInfo.resourceAmount or objectInfo.refreshTime + resourceInfo.timeLimit <= nowTime then
                                        -- 资源点被采集完或者已超时，移除资源点信息
                                        -- SM.c_map_object.req.Delete( objectId )
                                        table.insert( deleteIndexs, objectId )
                                    else
                                        -- 资源点未被采集完未超时
                                        objectInfo.resourceAmount = objectInfo.resourceAmount - realCollect
                                        objectInfo.collectTime = 0
                                        objectInfo.collectRid = 0
                                        objectInfo.collectSpeed = 0
                                        objectInfo.armyIndex = 0
                                        objectInfo.objectName = ""
                                        SM.c_map_object.req.Set( objectId, objectInfo )
                                        objectInfo.resourceGuildAbbName = GuildTerritoryLogic:getTerritoryGuildAbbName( nil, objectInfo.objectPos )
                                        -- 资源点进入地图
                                        MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.resourceEnter( Enum.MapLevel.RESOURCE, objectIndex, objectInfo.objectPos,
                                                objectInfo.objectPos, objectInfo, objectInfo.objectType )
                                        -- ResourceMgr服务增加资源点信息
                                        serviceIndex = MapLogic:getObjectService( objectInfo.objectPos )
                                        MSM.ResourceMgr[serviceIndex].req.addResourceInfo( objectId, objectIndex, objectInfo )
                                    end
                                    -- 部队就地解散回城
                                    ArmyLogic:disbandArmy( collectRid, armyIndex, true, true )
                                else
                                    -- 未采集完，资源点加入ResourceMgr服务，继续被采集
                                    objectInfo.resourceGuildAbbName = GuildTerritoryLogic:getTerritoryGuildAbbName( nil, objectInfo.objectPos )
                                    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.resourceEnter( Enum.MapLevel.RESOURCE, objectIndex, objectInfo.objectPos,
                                                objectInfo.objectPos, objectInfo, objectInfo.objectType )
                                    -- ResourceMgr服务增加资源点信息
                                    serviceIndex = MapLogic:getObjectService( objectInfo.objectPos )
                                    MSM.ResourceMgr[serviceIndex].req.addResourceInfo( objectId, objectIndex, objectInfo )
                                end
                            else
                                -- 部队在其他资源点开始采集，
                                table.insert( deleteIndexs, objectId )
                            end
                        else
                            -- 军队不存在，移除资源点
                            -- SM.c_map_object.req.Delete( objectId )
                            table.insert( deleteIndexs, objectId )
                        end
                    else
                        -- 移除资源点，
                        -- SM.c_map_object.req.Delete( objectId )
                        table.insert( deleteIndexs, objectId )
                    end
                end
            elseif objectInfo.objectType == Enum.RoleType.MONSTER then
                -- 野蛮人
                monsterInfo = sMonster[objectInfo.monsterId]
                if objectInfo.refreshTime + monsterInfo.showTime <= nowTime then
                    -- 野蛮人超时，删除野蛮人
                    table.insert( deleteIndexs, objectId )
                else
                    -- 野蛮人未超时，野蛮人加入地图aoi
                    MSM.AoiMgr[Enum.MapLevel.ARMY].req.monsterEnter( Enum.MapLevel.ARMY, objectIndex, objectInfo.objectPos, objectInfo.objectPos, objectInfo )
                    -- MonsterMgr服务增加野蛮人信息
                    serviceIndex = MapLogic:getObjectService( objectInfo.objectPos )
                    MSM.MonsterMgr[serviceIndex].req.addMonsterInfo( objectId, objectIndex, objectInfo )
                end
            elseif objectInfo.objectType == Enum.RoleType.MONSTER_CITY then
                -- 野蛮人城寨
                monsterInfo = sMonster[objectInfo.monsterId]
                if objectInfo.refreshTime + monsterInfo.showTime <= nowTime then
                    -- 野蛮人城寨超时，删除野蛮人城寨
                    table.insert( deleteIndexs, objectId )
                else
                    -- 野蛮人城寨未超时，野蛮人城寨加入地图aoi
                    MSM.AoiMgr[Enum.MapLevel.ARMY].req.monsterCityEnter( Enum.MapLevel.ARMY, objectIndex, objectInfo.objectPos, objectInfo.objectPos, objectInfo )
                    -- MonsterCityMgr服务增加野蛮人城寨信息
                    serviceIndex = MapLogic:getObjectService( objectInfo.objectPos )
                    MSM.MonsterCityMgr[serviceIndex].req.addMonsterCityInfo( objectId, objectIndex, objectInfo )
                end
            elseif objectInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or objectInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
                -- 召唤怪物
                monsterInfo = sMonster[objectInfo.monsterId]
                if objectInfo.refreshTime + monsterInfo.showTime <= nowTime then
                    -- 怪物超时，删除怪物
                    table.insert( deleteIndexs, objectId )
                else
                    -- 怪物未超时，怪物加入地图aoi
                    MSM.AoiMgr[Enum.MapLevel.ARMY].req.summonMonsterEnter( Enum.MapLevel.ARMY, objectIndex, objectInfo.objectPos, objectInfo.objectPos, objectInfo )
                    MSM.MonsterSummonMgr[objectIndex].req.addSummonMonsterInfo( objectId, objectIndex, objectInfo )
                end
            end
        until true
    end

    LOG_INFO("MapObjectMgr over Init %d", _fromIndex)
    -- 通知加载完成
    MSM.MapObjectMgr[0].req.loadMapObjectOver( deleteIndexs )
    snax.exit()
end