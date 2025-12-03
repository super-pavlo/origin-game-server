--[[
 * @file : PVENavMeshMapMgr.lua
 * @type : multi snax service
 * @author : linfeng
 * @created : 2020-04-24 17:06:01
 * @Last Modified time: 2020-04-24 17:06:01
 * @department : Arabic Studio
 * @brief : PVE导航网格处理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local NavMeshLogic = require "NavMeshLogic"
local detourCore = require "detour.core"

---@type userdata
local navMeshQueryPtr = {}

function init()
    local sExpeditionBattle = CFG.s_ExpeditionBattle:Get()
    for _, expeditionBattleInfo in pairs(sExpeditionBattle) do
        local mapID = expeditionBattleInfo.mapID
        if not navMeshQueryPtr[mapID] then
            -- 初始化RacastRecation
            navMeshQueryPtr[mapID] = NavMeshLogic:initRecastNavigationMap( "common/mapmesh/" .. mapID .. "_Walkable_NavMesh.bin" )
        end
    end
end

function response.Init()

end

---@see 反初始化
function response.UnInit()
    for _, mapName in pairs(navMeshQueryPtr) do
        NavMeshLogic:unInitRecastNavigationMap( navMeshQueryPtr[mapName] )
    end
end

---@see 获取寻路路径
function response.findPath( _mapName, _spos, _epos )
    if navMeshQueryPtr[_mapName] then
        return NavMeshLogic:findPath( navMeshQueryPtr[_mapName], _spos, _epos )
    end
end

function response.checkPosIdle( _mapName, _pos )
    local ret = detourCore.checkIdlePos( navMeshQueryPtr[_mapName], _pos.x, 0, _pos.y, _pos.x, 0, _pos.y )
    if not ret then
        return false
    end
    return true
end