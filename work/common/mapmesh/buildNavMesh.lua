--[[
 * @file : buildNavMesh.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-26 19:30:53
 * @Last Modified time: 2020-04-26 19:30:53
 * @department : Arabic Studio
 * @brief : 根据obj生成racastNavigation的导航网格
 * Copyright(C) 2019 IGG, All rights reserved
]]

package.cpath = "common/luaclib/?.so"

local recastcore = require "recast.core"

local arg = ...
assert(arg, "lua buildNavMesh.lua type(pvp|world|nobuild)")

if tostring(arg) == "pvp" then
    print("build map_pvp_co_1_Walkable_NavMesh to Bin ...")
    -- 初始化
    recastcore.initObstaclesNavMeshObj("common/mapmesh/map_pvp_co_1_Walkable_NavMesh.obj")
    -- 生成Bin
    if recastcore.saveObstaclesNavMeshToBin("common/mapmesh/map_pvp_co_1_Walkable_NavMesh.bin") then
        print("build map_pvp_co_1_Walkable_NavMesh to Bin ... OK")
    else
        print("build map_pvp_co_1_Walkable_NavMesh to Bin ... FAIL")
    end
elseif tostring(arg) == "world" then
    print("build map_4_Walkable_NavMesh to Bin ...")
    -- 初始化
    recastcore.initObstaclesNavMeshObj("common/mapmesh/map_4_Walkable_NavMesh.obj")
    -- 生成Bin
    if recastcore.saveObstaclesNavMeshToBin("common/mapmesh/map_4_Walkable_NavMesh.bin") then
        print("build map_4_Walkable_NavMesh to Bin ... OK")
    else
        print("build map_4_Walkable_NavMesh to Bin ... FAIL")
    end
elseif tostring(arg) == "nobuild" then
    print("build map_4_NoBuilding_NavMesh to Bin ...")
    -- 初始化
    recastcore.initObstaclesNavMeshObj("common/mapmesh/map_4_Building_NavMesh.obj")
    -- 生成Bin
    if recastcore.saveObstaclesNavMeshToBin("common/mapmesh/map_4_Building_NavMesh.bin") then
        print("build map_4_NoBuilding_NavMesh to Bin ... OK")
    else
        print("build map_4_NoBuilding_NavMesh to Bin ... FAIL")
    end
end