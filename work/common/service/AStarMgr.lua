--[[
 * @file : AStarMgr.lua
 * @type : multi snax service
 * @author : linfeng
 * @created : 2020-04-29 18:31:14
 * @Last Modified time: 2020-04-29 18:31:14
 * @department : Arabic Studio
 * @brief : A*寻路管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local AStarLogic = require "AStarLogic"

---@see AStar寻路指针
local astarSearchPtr = {}

---@see 初始化AStar寻路地图
---@param _blockMap table
--[[
    local _blockMap = {
        0, 1, 0, 0, 0,
        0, 0, 0, 1, 0,
        1, 1, 1, 1, 0,
        0, 0, 0, 1, 0,
        0, 1, 0, 0, 0,
    }
]]
---@param _width integer 地图宽
---@param _height integer 地图高
function response.InitSearchMap( _guildId, _blockMap, _width, _height )
    -- 设置地图信息
    AStarLogic:setMapInfo( _guildId, _blockMap, _width, _height )
    -- 生成寻路地图
    AStarLogic:newAStarMap( astarSearchPtr, _guildId, _width, _height )
end

---@see 判断两点是否连接
function response.findPath( _guildId, _spos, _epos )
    if not astarSearchPtr[_guildId] then
        return false
    else
        local pathCount
        for _, fromPos in pairs( _spos ) do
            for _, toPos in pairs( _epos ) do
                _, pathCount = astarSearchPtr[_guildId]:path( fromPos.x, fromPos.y, toPos.x, toPos.y )
                if pathCount > 0 then
                    return true
                end
            end
        end
    end
end

---@see 设置点不可行走
function response.setUnwalkable( _guildId, _pos )
    AStarLogic:setWalkable( astarSearchPtr[_guildId], _guildId, _pos, 1 )
end

---@see 设置点可行走
function response.setWalkable( _guildId, _pos )
    AStarLogic:setWalkable( astarSearchPtr[_guildId], _guildId, _pos, 0 )
end

---@see 释放AStar寻路地图
function accept.freeSearchMap( _guildId )
    AStarLogic:freeAStarMap( astarSearchPtr, _guildId )
end