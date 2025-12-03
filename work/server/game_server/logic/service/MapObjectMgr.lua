--[[
 * @file : MapObjectMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2019-12-26 14:26:49
 * @Last Modified time: 2019-12-26 14:26:49
 * @department : Arabic Studio
 * @brief : 地图对象管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local ResourceLogic = require "ResourceLogic"
local snax = require "skynet.snax"
local skynet = require "skynet"
local MapObjectLogic = require "MapObjectLogic"

local maxObjectCount = 0
local waitLoadOver = 0
local allDeleteIndexs = {}

---@see 初始化地图物件
function response.Init()
    local dbNode = Common.getDbNode()
    local count = Common.rpcCall( dbNode, "CommonLoadMgr", "getCommonCount", "c_map_object" )
    local tsBegin = os.time()

    Common.redisExecute( { "SET", Enum.Share.MapObjectLoad, 0 } )
    local service
    local step = 2000
    for index = 1, count, step do
        service = snax.newservice("MapObjectLoadMgr")
        service.post.loadMapObject( index-1, step )
        maxObjectCount = maxObjectCount + 1
    end

    -- 等待加载完成
    LOG_INFO("wait for all(%d) MapObjectLoadMgr", maxObjectCount)
    while waitLoadOver ~= maxObjectCount do
        skynet.sleep(100)
    end

    Common.redisExecute( { "SET", Enum.Share.MapObjectLoad, 1 } )
    -- 删除超时野蛮人和资源点、野蛮人城寨
    for _, objectId in pairs( allDeleteIndexs ) do
        SM.c_map_object.req.Delete( objectId )
    end
    allDeleteIndexs = {}
    -- 通知各服务删除过期对象
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        MSM.MonsterCityMgr[i].post.deleteObjectOnReboot()
        MSM.MonsterMgr[i].post.deleteObjectOnReboot()
        MSM.ResourceMgr[i].post.deleteObjectOnReboot()
    end

    LOG_INFO("wait for all(%d) MapObjectLoadMgr over, cost time: %ds", maxObjectCount, os.time() - tsBegin)
end

---@see 加载服务完成
function response.loadMapObjectOver( _deleteIndexs )
    waitLoadOver = waitLoadOver + 1
    table.merge( allDeleteIndexs, _deleteIndexs )
    LOG_INFO("MapObjectLoadMgr complete(%d) all(%d)", waitLoadOver, maxObjectCount)
end

---@see 城市加入地图.新建的角色
function response.cityAddMap( _rid, _name, _level, _country, _pos )
    -- 加入地图对象表
    local cityId = SM.c_map_object.req.Add( nil, {
        objectName = _name,
        objectType = Enum.RoleType.CITY,
        objectPos = _pos,
        objectCountry = _country,
        objectRid = _rid
     } )

    local cityInfo = {
        rid = _rid,
        name = _name,
        level = _level,
        country = _country,
        pos = _pos
    }

    -- 加入AOI
    local objectIndex = Common.newMapObjectIndex()
    MSM.AoiMgr[Enum.MapLevel.CITY].req.cityEnter( Enum.MapLevel.CITY, objectIndex, _pos, _pos, cityInfo )

    -- 更新地图城市数量管理服务
    SM.MapCityMgr.post.addCityNum()

    return cityId
end

---@see 城市移动
function response.cityMove( _, _cityId, _cityIndex, _pos )
    SM.c_map_object.req.Set( _cityId, { objectPos = _pos } )

    MSM.AoiMgr[Enum.MapLevel.CITY].post.cityUpdate( Enum.MapLevel.CITY, _cityIndex, _pos, _pos )
end

---@see 刷新的资源点进入地图
function response.resourceAddMap( _resourceId, _pos, _refreshTime, _objectType, _resAmount, _resourceGuildAbbName )
    local resourceInfo = {
        objectPos = _pos,
        objectType = _objectType,
        refreshTime = _refreshTime,
        resourceAmount = _resAmount,
        resourceId = _resourceId,
        resourceGuildAbbName = _resourceGuildAbbName,
    }

    local objectId = SM.c_map_object.req.Add( nil, resourceInfo )

    -- 加入AOI
    local objectIndex = Common.newMapObjectIndex()
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.resourceEnter( Enum.MapLevel.RESOURCE, objectIndex, _pos, _pos, resourceInfo, resourceInfo.objectType )

    return objectId, objectIndex
end

---@see 更新资源点信息
function response.resourceUpdate( _objectId, _objectIndex, _resourceAmount, _collectTime, _collectRid,
            _collectSpeed, _armyIndex, _name, _collectSpeeds, _guildAbbName, _guildId, _cityLevel, _isDefeat )
    local updateResourceInfo = {
        resourceAmount = _resourceAmount, collectTime = _collectTime, collectRid = _collectRid,
        collectSpeed = _collectSpeed, armyIndex = _armyIndex, objectName = _name
    }
    SM.c_map_object.req.Set( _objectId, updateResourceInfo )

    updateResourceInfo.objectName = nil
    updateResourceInfo.cityName = _name
    updateResourceInfo.collectSpeeds = _collectSpeeds
    updateResourceInfo.guildAbbName = _guildAbbName
    updateResourceInfo.guildId = _guildId
    updateResourceInfo.cityLevel = _cityLevel

    -- 更新地图对象信息
    MSM.SceneResourceMgr[_objectIndex].post.updateResourceInfo( _objectIndex, updateResourceInfo, _isDefeat )
end

---@see 移除资源点
function response.resourceLeave( _objectId, _objectIndex, _objectPos, _objectType )
    -- 移除资源点
    SM.c_map_object.req.Delete( _objectId )
    -- 更新aoi
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.resourceLeave( Enum.MapLevel.RESOURCE, _objectIndex, _objectPos, _objectType )
end

---@see 新刷新的野蛮人进入地图
function response.monsterAddMap( _monsterTypeId, _pos, _refreshTime )
    local monsterInfo = {
        objectPos = _pos,
        objectType = Enum.RoleType.MONSTER,
        refreshTime = _refreshTime,
        monsterId = _monsterTypeId
    }

    local objectId = SM.c_map_object.req.Add( nil, monsterInfo )
    -- 加入AOI
    local objectIndex = Common.newMapObjectIndex()
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.monsterEnter( Enum.MapLevel.ARMY, objectIndex, _pos, _pos, monsterInfo )

    return objectId, objectIndex
end

---@see 移除地图野蛮人
function response.monsterLeave( _objectId, _objectIndex )
    -- 移除野蛮人
    SM.c_map_object.req.Delete( _objectId )
    -- 更新aoi
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.monsterLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
end

---@see 村庄山洞进入地图
function response.villageCaveAddMap( _objectId, _pos, _objectType )
    local objectInfo = {
        objectPos = _pos,
        resourcePointId = _objectId,
        objectType = ResourceLogic:resourceTypeToObjectType( _objectType ),
    }

    -- 加入AOI
    local objectIndex = Common.newMapObjectIndex()
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.resourceEnter( Enum.MapLevel.RESOURCE, objectIndex, _pos, _pos, objectInfo, objectInfo.objectType )

    return objectIndex
end

---@see 联盟建筑进入地图
function response.guildBuildAddMap( _buildInfo )
    -- 加入AOI
    local objectIndex = Common.newMapObjectIndex()
    if MapObjectLogic:checkIsGuildFortressObject( _buildInfo.objectType ) or MapObjectLogic:checkIsGuildResourceCenterObject( _buildInfo.objectType ) then
        MSM.AoiMgr[Enum.MapLevel.PREVIEW].req.guildBuildEnter( Enum.MapLevel.PREVIEW, objectIndex, _buildInfo.pos, _buildInfo.pos, _buildInfo, _buildInfo.objectType )
    else
        MSM.AoiMgr[Enum.MapLevel.GUILD].req.guildBuildEnter( Enum.MapLevel.GUILD, objectIndex, _buildInfo.pos, _buildInfo.pos, _buildInfo, _buildInfo.objectType )
    end

    return objectIndex
end

---@see 更新联盟建筑信息
function accept.guildBuildUpdate( _objectIndex, _updateBuildInfo )
    -- 更新地图对象信息
    MSM.SceneGuildBuildMgr[_objectIndex].post.updateGuildBuildInfo( _objectIndex, _updateBuildInfo )
end

---@see 移除联盟建筑
function accept.guildBuildLeave( _objectIndex, _objectType )
    -- 更新aoi
    if MapObjectLogic:checkIsGuildFortressObject( _objectType ) or MapObjectLogic:checkIsGuildResourceCenterObject( _objectType ) then
        MSM.AoiMgr[Enum.MapLevel.PREVIEW].post.guildBuildLeave( Enum.MapLevel.PREVIEW, _objectIndex, { x = -1, y = -1 }, _objectType )
    else
        MSM.AoiMgr[Enum.MapLevel.GUILD].post.guildBuildLeave( Enum.MapLevel.GUILD, _objectIndex, { x = -1, y = -1 }, _objectType )
    end
end

---@see 新刷新的野蛮人城寨进入地图
function response.monsterCityAddMap( _monsterCityTypeId, _pos, _refreshTime )
    local monsterCityInfo = {
        objectPos = _pos,
        objectType = Enum.RoleType.MONSTER_CITY,
        refreshTime = _refreshTime,
        monsterId = _monsterCityTypeId
    }

    local objectId = SM.c_map_object.req.Add( nil, monsterCityInfo )
    -- 加入AOI
    local objectIndex = Common.newMapObjectIndex()
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.monsterCityEnter( Enum.MapLevel.ARMY, objectIndex, _pos, _pos, monsterCityInfo )

    return objectId, objectIndex
end

---@see 移除地图野蛮人城寨
function response.monsterCityLeave( _objectId, _objectIndex )
    -- 移除野蛮人
    SM.c_map_object.req.Delete( _objectId )
    -- 更新aoi
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.monsterCityLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
end

---@see 圣地进入地图
function response.holyLandAddMap( _holyLandId, _pos, _guildId, _status, _finishTime, _objectType )
    local holyLandInfo = {
        targetPos = _pos,
        guildId = _guildId,
        strongHoldId = _holyLandId,
        holyLandStatus = _status,
        holyLandFinishTime = _finishTime
    }

    local objectIndex = Common.newMapObjectIndex()
    MSM.AoiMgr[Enum.MapLevel.PREVIEW].req.holyLandEnter( Enum.MapLevel.PREVIEW, objectIndex, _pos, _pos, holyLandInfo, _objectType )

    return objectIndex
end

---@see 守护者进入地图
function response.guardAddMap( _monsterId, _pos, _refreshTime, _holyLandId )
    local monsterInfo = {
        objectPos = _pos,
        objectType = Enum.RoleType.GUARD_HOLY_LAND,
        refreshTime = _refreshTime,
        monsterId = _monsterId,
        holyLandId = _holyLandId,
    }

    -- 加入AOI
    local objectIndex = Common.newMapObjectIndex()
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.guardHolyLandEnter( Enum.MapLevel.ARMY, objectIndex, _pos, _pos, monsterInfo )

    return objectIndex
end

---@see 城市离开地图
function response.cityLeave( _rid, _cityId, _cityIndex )
    SM.c_map_object.req.Delete( _cityId )

    -- 更新aoi
    MSM.AoiMgr[Enum.MapLevel.CITY].req.cityLeave( Enum.MapLevel.CITY, _cityIndex, { x = -1, y = -1 }, _rid )
end

---@see 召唤的怪物进入地图
function response.summonMonsterAddMap( _monsterTypeId, _pos, _refreshTime, _objectIndex, _objectType )
    local monsterInfo = {
        objectPos = _pos,
        objectType = _objectType,
        refreshTime = _refreshTime,
        monsterId = _monsterTypeId
    }

    local objectId = SM.c_map_object.req.Add( nil, monsterInfo )
    -- 加入AOI
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.summonMonsterEnter( Enum.MapLevel.ARMY, _objectIndex, _pos, _pos, monsterInfo )

    return objectId
end

---@see 移除召唤怪物
function response.summonMonsterLeave( _objectId, _objectIndex, _objectType )
    if _objectId then
        -- 移除召唤怪物
        SM.c_map_object.req.Delete( _objectId )
    end

    -- 更新aoi
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.summonMonsterLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 }, _objectType )
end