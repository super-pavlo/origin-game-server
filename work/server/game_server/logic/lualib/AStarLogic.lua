--[[
 * @file : AStarLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-29 18:49:24
 * @Last Modified time: 2020-04-29 18:49:24
 * @department : Arabic Studio
 * @brief : A*寻路模块
 * Copyright(C) 2019 IGG, All rights reserved
]]

local astarCode = require "astar.core"

local AStarLogic = {}
---@see 地图信息2D
local blockMap = {}

---@see 相邻块比较函数
function AStarLogic.neighborComparator( w, h, fx, fy, tx, ty, guildId )
    local idx = tx + (ty - 1) * w
    if blockMap[guildId].map[idx] ~= 0 or ( fx ~= tx and fy ~= ty ) then
        return
    end
    local dis = (tx - fx) * (ty - fy) > 0 and 1.4 or 1
    return true, dis
end

---@see 设置地图信息
function AStarLogic:setMapInfo( _guildId, _blockMap, _width, _height )
    if not blockMap[_guildId] then
        blockMap[_guildId] = {}
        blockMap[_guildId].map = _blockMap
        blockMap[_guildId].width = _width
        blockMap[_guildId].height = _height
    end
end

---@see 设置地图点属性
function AStarLogic:setWalkable( _astarSearchPtr, _guildId, _pos, _walkable )
    if blockMap[_guildId] then
        for _, idx in pairs( _pos ) do
            blockMap[_guildId].map[idx] = _walkable
        end
    end
end

---@see 建立寻路地图
function AStarLogic:newAStarMap( _astarSearchPtr, _guildId, _width, _height )
    if _astarSearchPtr[_guildId] then
        -- 先GC
        _astarSearchPtr[_guildId] = nil
        collectgarbage()
    end

    -- new astar
    _astarSearchPtr[_guildId] = astarCode.new( _width, _height, self.neighborComparator, _guildId )
end

---@see 释放寻路地图
function AStarLogic:freeAStarMap( _astarSearchPtr, _guildId )
    if _astarSearchPtr[_guildId] then
        -- 先GC
        _astarSearchPtr[_guildId] = nil
        collectgarbage()
    end
end

return AStarLogic