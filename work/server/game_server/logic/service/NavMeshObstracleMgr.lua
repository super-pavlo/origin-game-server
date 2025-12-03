--[[
 * @file : NavMeshObstracleMgr.lua
 * @type : single snax service
 * @author : linfeng
 * @created : 2020-07-03 10:15:21
 * @Last Modified time: 2020-07-03 10:15:21
 * @department : Arabic Studio
 * @brief : 地图动态障碍管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local NavMeshLogic = require "NavMeshLogic"
local ArmyLogic = require "ArmyLogic"
local MapObjectLogic = require "MapObjectLogic"
local MapLogic = require "MapLogic"
local detourCore = require "detour.core"
local sharedata = require "skynet.sharedata"

---@see 一般障碍
local navMeshQueryPtr, tileCachePtr
---@see 用于怪物的障碍
local monsterNavMeshQueryPtr, monsterTileCachePtr
---@see 服务器启动时的对象记录
local addObstracleObjects = {}
local addObstracleObjectsCount = 0

---@see 初始化
function response.Init()
    LOG_INFO("init map_4_Building_NavMesh ...")
    navMeshQueryPtr, tileCachePtr = NavMeshLogic:initRecastNavigationMap( "common/mapmesh/map_4_Building_NavMesh.bin" )
    LOG_INFO("init map_4_Building_NavMesh ok ...")

    LOG_INFO("init map_4_Building_NavMesh for monster ...")
    monsterNavMeshQueryPtr, monsterTileCachePtr = NavMeshLogic:initRecastNavigationMap( "common/mapmesh/map_4_Building_NavMesh.bin" )
    LOG_INFO("init map_4_Building_NavMesh for monster over ...")

    MSM.MapObjectTypeMgr[0].req.empty()
end

---@see 反初始化
function exit()
    NavMeshLogic:unInitRecastNavigationMap( navMeshQueryPtr, tileCachePtr )
    NavMeshLogic:unInitRecastNavigationMap( monsterNavMeshQueryPtr, monsterTileCachePtr )
end

---@see 添加动态障碍.一般用于启动服务器时
function accept.addObstracle( _objectIndex, _objectType, _pos, _objectId )
    addObstracleObjects[_objectIndex] = {
        objectType = _objectType,
        pos = _pos,
        objectId = _objectId
    }
    addObstracleObjectsCount = addObstracleObjectsCount + 1
end

---@see 执行添加障碍
function response.addObstracleImpl()
    local begin = os.time()
    LOG_INFO("addObstracleImpl, addObstracleObjectsCount:%d", addObstracleObjectsCount)
    local addCount = 0
    for objectIndex, objectInfo in pairs(addObstracleObjects) do
        NavMeshLogic:addObstracleInBuild( navMeshQueryPtr, tileCachePtr, monsterNavMeshQueryPtr, monsterTileCachePtr,
                                            objectIndex, objectInfo.objectType, objectInfo.pos, objectInfo.objectId, true )
        addCount = addCount + 1
        if addCount % 1000 == 0 then
            LOG_INFO("addObstracleImpl, process:%d/%d", addCount, addObstracleObjectsCount)
        end
    end

    addObstracleObjects = {}
    sharedata.update( Enum.Share.ServerStart, { start = false } )
    sharedata.flush()
    collectgarbage()
    LOG_INFO("addObstracleImpl, over:%ds", os.time() - begin)
end

---@see 添加动态障碍
function response.addObstracle( _objectIndex, _objectType, _pos, _objectId )
    NavMeshLogic:addObstracleInBuild( navMeshQueryPtr, tileCachePtr, monsterNavMeshQueryPtr, monsterTileCachePtr,
                                        _objectIndex, _objectType, _pos, _objectId )
end

---@see 移除动态障碍
function response.delObstracle( _objectIndex )
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectType( _objectIndex )
    if objectInfo then
        -- 移除动态障碍
        if objectInfo.obstracleRef > 0 then
            if objectInfo.objectType == Enum.RoleType.MONSTER or objectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
                or objectInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or objectInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
                -- 野蛮人、圣地守护者、召唤怪物
                NavMeshLogic:delObstracle( monsterNavMeshQueryPtr, monsterTileCachePtr, objectInfo.obstracleRef )
            else
                -- 其他建筑
                if objectInfo.monsterObstracleRef > 0 then
                    NavMeshLogic:delObstracle( monsterNavMeshQueryPtr, monsterTileCachePtr, objectInfo.monsterObstracleRef )
                end
                if objectInfo.findObstracleRef > 0 then
                    MapLogic:delObstracle( _objectIndex, objectInfo.findObstracleRef )
                end

                NavMeshLogic:delObstracle( navMeshQueryPtr, tileCachePtr, objectInfo.obstracleRef )
            end
        end
    else
        LOG_ERROR("delObstracle but not found objectIndex(%d)", _objectIndex)
    end
end

---@see 更新动态障碍
function accept.updateObstracle( _objectIndex, _pos )
    -- 一定是建筑
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    -- 移除动态障碍
    if objectInfo.obstracleRef > 0 then
        NavMeshLogic:delObstracle( navMeshQueryPtr, tileCachePtr, objectInfo.obstracleRef )
    end
    if objectInfo.monsterObstracleRef > 0 then
        NavMeshLogic:delObstracle( monsterNavMeshQueryPtr, monsterTileCachePtr, objectInfo.monsterObstracleRef )
    end

    -- 添加动态障碍
    local objectId = MapObjectLogic:getBuildObjectId( objectInfo )
    local radius = MapObjectLogic:getBuildRadiusCollide( objectInfo.objectType, objectId )
    local obstracleRef = NavMeshLogic:addObstracle( navMeshQueryPtr, tileCachePtr, _pos, radius )
    local monsterObstracleRef = NavMeshLogic:addObstracle( monsterNavMeshQueryPtr, monsterTileCachePtr, _pos, radius )
    if obstracleRef then
        -- 更新动态障碍索引
	    MSM.MapObjectTypeMgr[_objectIndex].post.updateObstracleRef( _objectIndex, obstracleRef, nil, monsterObstracleRef )
    end

    -- 寻路地图
    if objectInfo.objectType == Enum.RoleType.CITY then
        -- 只有城市加入寻路阻挡
        MapLogic:updateObstracle( _objectIndex, _pos )
    end
end

---@see 通过索引删除障碍
function accept.delObstracleByRef( _obstracleRef )
    NavMeshLogic:delObstracle( navMeshQueryPtr, tileCachePtr, _obstracleRef )
end

---@see 检查位置半径内是否有不可达到点
function response.checkPosIdle( _pos, _radius, _isMonsterMap, _cityIndex, _isSet, _isMonsterCheck )
    local objectInfo
    if _cityIndex then
        objectInfo = MSM.SceneCityMgr[_cityIndex].req.getCityInfo( _cityIndex )
        local objectTypeInfo = MSM.MapObjectTypeMgr[_cityIndex].req.getObjectType( _cityIndex )
        -- 先移除城市的阻挡
        if objectTypeInfo.obstracleRef > 0 then
            NavMeshLogic:delObstracle( navMeshQueryPtr, tileCachePtr, objectTypeInfo.obstracleRef )
        end
    end

    -- 中心点也要判断
    local allPos = { _pos }
    -- 取中心半径的8个方向点
    local isIdle = true
    if _radius > 0 then
        for i = 0, 7 do
            -- 判断8个点是否都可以寻到自己
            table.insert( allPos, ArmyLogic:cacleAroudPosXY_8( _pos, i, _radius * 100 ) )
        end
    end

    for _, pos in pairs(allPos) do
        local ret
        if not _isMonsterMap then
            ret = detourCore.checkIdlePos( navMeshQueryPtr, _pos.x, 0, _pos.y, pos.x, 0, pos.y )
            if ret and not _isMonsterCheck and not _cityIndex then
                -- 需要到怪物的地图Ptr里二次Check(怪物本身以及城市除外)
                ret = detourCore.checkIdlePos( monsterNavMeshQueryPtr, _pos.x, 0, _pos.y, pos.x, 0, pos.y )
            end
        else
            ret = detourCore.checkIdlePos( monsterNavMeshQueryPtr, _pos.x, 0, _pos.y, pos.x, 0, pos.y )
        end
        if not ret then
            isIdle = false
            break
        end
    end

    if _cityIndex then
        -- 添加回城市的阻挡
        local radius = MapObjectLogic:getBuildRadiusCollide( Enum.RoleType.CITY )
        local obstracleRef = NavMeshLogic:addObstracle( navMeshQueryPtr, tileCachePtr, objectInfo.pos, radius )
        if obstracleRef then
            -- 更新动态障碍索引
            MSM.MapObjectTypeMgr[_cityIndex].post.updateObstracleRef( _cityIndex, obstracleRef )
        end
    end

    local setObstracleRef
    if _isSet and isIdle then
        -- 直接放置阻挡
        setObstracleRef = NavMeshLogic:addObstracle( navMeshQueryPtr, tileCachePtr, _pos, _radius )
    end

    return isIdle, setObstracleRef
end

---@see 怪物巡逻寻路
function response.findMonsterPartolPath( _spos, _epos )
    return NavMeshLogic:findPath( monsterNavMeshQueryPtr, _spos, _epos )
end