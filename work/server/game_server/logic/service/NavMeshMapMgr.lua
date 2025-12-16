--[[
 * @file : NavMeshMapMgr.lua
 * @type : single snax service
 * @author : linfeng
 * @created : 2020-04-24 17:06:01
 * @Last Modified time: 2020-04-24 17:06:01
 * @department : Arabic Studio
 * @brief : 导航网格处理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local NavMeshLogic = require "NavMeshLogic"
local MapObjectLogic = require "MapObjectLogic"
local ArmyLogic = require "ArmyLogic"
local detourCore = require "detour.core"

---@type userdata
local navMeshQueryPtr
---@type userdata
local tileCachePtr

---@see 初始化
function init()
    LOG_INFO("init map_4_Walkable_NavMesh ...")
    -- 初始化RacastRecation
    navMeshQueryPtr, tileCachePtr = NavMeshLogic:initRecastNavigationMap( "common/mapmesh/map_4_Walkable_NavMesh.bin" )
    assert(navMeshQueryPtr and tileCachePtr )
    LOG_INFO("init map_4_Walkable_NavMesh over ...")
end

function response.Init()

end

---@see 反初始化
function exit()
    NavMeshLogic:unInitRecastNavigationMap( navMeshQueryPtr, tileCachePtr )
end

---@see 获取寻路路径
function response.findPath( _spos, _epos )
    return NavMeshLogic:findPath( navMeshQueryPtr, _spos, _epos )
end

---@see 添加动态障碍
function accept.addObstracle( _objectIndex, _objectType, _pos, _objectId )
    local radius = MapObjectLogic:getBuildRadius( _objectType, _objectId )
    local findObstracleRef = NavMeshLogic:addObstracle( navMeshQueryPtr, tileCachePtr, _pos, radius )
    if findObstracleRef then
        -- 注册到对象类型服务
	    MSM.MapObjectTypeMgr[_objectIndex].post.updateObstracleRef( _objectIndex, nil, findObstracleRef )
    end
end

---@see 移除动态障碍
function accept.delObstracle( _objectIndex, _findObstracleRef )
    -- 移除动态障碍
    if _findObstracleRef > 0 then
        NavMeshLogic:delObstracle( navMeshQueryPtr, tileCachePtr, _findObstracleRef )
    end
end

---@see 更新动态障碍
function accept.updateObstracle( _objectIndex, _pos )
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    -- 移除动态障碍
    if objectInfo.findObstracleRef > 0 then
        NavMeshLogic:delObstracle( navMeshQueryPtr, tileCachePtr, objectInfo.findObstracleRef )
    end

    local objectId = MapObjectLogic:getBuildObjectId( objectInfo )
    local radius = MapObjectLogic:getBuildRadius( objectInfo.objectType, objectId )
    local findObstracleRef = NavMeshLogic:addObstracle( navMeshQueryPtr, tileCachePtr, _pos, radius )
    if findObstracleRef then
        -- 更新障碍索引
        MSM.MapObjectTypeMgr[_objectIndex].post.updateObstracleRef( _objectIndex, nil, findObstracleRef )
    end
end

---@see 检查位置半径内是否有不可达到点
function response.checkPosIdle( _pos, _radius )
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
        local ret = detourCore.checkIdlePos( navMeshQueryPtr, _pos.x, 0, _pos.y, pos.x, 0, pos.y )
        if not ret then
            isIdle = false
            break
        end
    end

    return isIdle
end