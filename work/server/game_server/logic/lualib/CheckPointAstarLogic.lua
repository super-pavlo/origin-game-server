--[[
* @file : CheckPointAstarLogic.lua
* @type : lua lib
* @author : chenlei
* @created : Sat Jul 04 2020 11:35:06 GMT+0800 (中国标准时间)
* @department : Arabic Studio
 * @brief : 关卡A*寻路模块
* Copyright(C) 2017 IGG, All rights reserved
]]

local astarCode = require "astar.core"

local CheckPointAstarLogic = {}
---@see 地图信息2D
local blockMap

---@see 相邻块比较函数
function CheckPointAstarLogic.neighborComparator( w, h, fx, fy, tx, ty )
    local idx = tx + ty * w + 1
    if blockMap.map[idx] ~= 1 or ( fx ~= tx and fy ~= ty ) then
        return
    end
    local dis = (tx - fx) * (ty - fy) > 0 and 1.4 or 1
    return true, dis
end

---@see 设置地图信息
function CheckPointAstarLogic:setMapInfo( _blockMap, _width, _height )
    if not blockMap then
        blockMap = {}
        blockMap.map = _blockMap
        blockMap.width = _width
        blockMap.height = _height
    end
end

---@see 设置地图点属性
function CheckPointAstarLogic:setWalkable( _astarSearchPtr, _pos, _walkable )
    if blockMap then
        for _, idx in pairs( _pos ) do
            blockMap.map[idx] = _walkable
        end
    end
end

---@see 建立寻路地图
function CheckPointAstarLogic:newAStarMap( _astarSearchPtr, _width, _height )
    if _astarSearchPtr then
        -- 先GC
        _astarSearchPtr = nil
        collectgarbage()
    end
    -- new astar
    return astarCode.new( _width, _height, self.neighborComparator, 0 )
end

---@see 释放寻路地图
function CheckPointAstarLogic:freeAStarMap( _astarSearchPtr )
    if _astarSearchPtr then
        -- 先GC
        _astarSearchPtr = nil
        collectgarbage()
    end
end

return CheckPointAstarLogic