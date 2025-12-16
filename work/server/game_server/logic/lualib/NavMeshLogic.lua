--[[
 * @file : NavMeshLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-24 17:07:42
 * @Last Modified time: 2020-04-24 17:07:42
 * @department : Arabic Studio
 * @brief : 导航网格相关逻辑处理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local MapObjectLogic = require "MapObjectLogic"
local MapLogic = require "MapLogic"
local detourCore = require "detour.core"

local NavMeshLogic = {}

---@see 定时更新阻挡
function NavMeshLogic:tickUpdate( _navMeshQueryPtr, _tileCachePtr )
    detourCore.tickUpdate( _navMeshQueryPtr, _tileCachePtr )
end

---@see 初始化寻路地图
function NavMeshLogic:initRecastNavigationMap( _fname )
    -- 初始化NavMeshQuery
    local navMeshQueryPtr = detourCore.newNavMeshQuery()
    if not navMeshQueryPtr then
        assert(false, "new NavMeshQuery fail")
    end
    -- 初始化TileCache
    local tileCachePtr = detourCore.newTileCache()
    if not tileCachePtr then
        assert(false, "new newTileCache fail")
    end
    -- 加载导航网格
    if not detourCore.initObstaclesMapMesh( navMeshQueryPtr, tileCachePtr, _fname ) then
        assert(false, "init detour NavMesh error")
    end
    return navMeshQueryPtr, tileCachePtr
end

---@see 释放寻路地图相关资源
function NavMeshLogic:unInitRecastNavigationMap( _navMeshQueryPtr, _tileCachePtr )
    detourCore.freeNavMeshQuery( _navMeshQueryPtr )
    detourCore.freeTileCache( _tileCachePtr )
end

---@see 初始化寻路地图
function NavMeshLogic:initStaticRecastNavigationMap( _fname )
    LOG_INFO("initStaticRecastNavigationMap ...")
    -- 初始化NavMeshQuery
    local navMeshQueryPtr = detourCore.newNavMeshQuery()
    if not navMeshQueryPtr then
        assert(false, "new NavMeshQuery fail")
    end

    -- 加载导航网格
    if not detourCore.initMapMesh( navMeshQueryPtr, _fname ) then
        assert(false, "init detour NavMesh error")
    end
    LOG_INFO("initStaticRecastNavigationMap ... OK")
    return navMeshQueryPtr
end

---@see 释放寻路地图相关资源
function NavMeshLogic:unInitStaticRecastNavigationMap( _navMeshQueryPtr )
    detourCore.freeNavMeshQuery( _navMeshQueryPtr )
end

---@see 使用racastNavigation寻路
function NavMeshLogic:findPath( _navMeshQueryPtr, _spos, _epos, _noFarCheck )
    local path = detourCore.findStraightPath( _navMeshQueryPtr, _spos.x, 0, _spos.y, _epos.x, 0, _epos.y )
    if _noFarCheck then
        return path
    end
    local retPath
    if path then
        retPath = {}
        for _ = 1, 10 do
            -- 判断是否因为过远导致路径中断
            local pathCount = #path
            if math.sqrt( (path[pathCount].x - _epos.x ) ^ 2 + ( path[pathCount].y - _epos.y ) ^ 2 ) > Enum.FindPathDistance then
                -- 继续寻路,移除最后一个点
                _spos = table.remove( path )
                for _, pathNode in pairs(path) do
                    table.insert( retPath, pathNode )
                end
                path = detourCore.findStraightPath( _navMeshQueryPtr, _spos.x, 0, _spos.y, _epos.x, 0, _epos.y )
                if not path then
                    break
                end
            else
                for _, pathNode in pairs(path) do
                    table.insert( retPath, pathNode )
                end
                break
            end
        end
    end
    if table.empty(retPath) then retPath = nil end
    return retPath
end

---@see 添加动态障碍
function NavMeshLogic:addObstracle( _navMeshQueryPtr, _tileCaclePtr, _pos, _radius, _delayUpdate )
    if _delayUpdate == nil then
        _delayUpdate = false
    end
    local ret, obstracleRef = detourCore.addObstacles( _navMeshQueryPtr, _tileCaclePtr, _pos.x, 0, _pos.y, _radius, _delayUpdate )
    if not ret then
        LOG_ERROR("addObstracle pos.x(%d) pos.y(%d) radius(%s)", _pos.x, _pos.y, _radius)
        return 0
    else
        return obstracleRef
    end
end

---@see 移除动态障碍
function NavMeshLogic:delObstracle( _navMeshQueryPtr, _tileCachePtr, _ref )
    local ret = detourCore.removeObstacles( _navMeshQueryPtr, _tileCachePtr, _ref )
    if not ret then
        LOG_ERROR("delObstracle ref(%d) fail", _ref)
    end
end

---@see 执行添加动态障碍
function NavMeshLogic:addObstracleInBuild( navMeshQueryPtr, tileCachePtr, monsterNavMeshQueryPtr, monsterTileCachePtr,
                                    _objectIndex, _objectType, _pos, _objectId, _delayUpdate )
    local obstracleRef, monsterObstracleRef
    if _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 野蛮人、圣地守护者、召唤怪
        local radius = CFG.s_Monster:Get( _objectId, "radiusCollide" )
        obstracleRef = self:addObstracle( monsterNavMeshQueryPtr, monsterTileCachePtr, _pos, radius, _delayUpdate )
    else
        local radius = MapObjectLogic:getBuildRadiusCollide( _objectType, _objectId )
        -- 建筑也要加入到monster中
        monsterObstracleRef = self:addObstracle( monsterNavMeshQueryPtr, monsterTileCachePtr, _pos, radius, _delayUpdate )
        -- 其他建筑
        obstracleRef = self:addObstracle( navMeshQueryPtr, tileCachePtr, _pos, radius, _delayUpdate )
        if _objectType == Enum.RoleType.CITY then
            -- 只有城市加入寻路阻挡
            MapLogic:addObstracle( _objectIndex, _objectType, _pos, _objectId )
        end
    end

    if obstracleRef then
        -- 更新动态障碍索引
        MSM.MapObjectTypeMgr[_objectIndex].post.updateObstracleRef( _objectIndex, obstracleRef, nil, monsterObstracleRef )
    end
end

return NavMeshLogic