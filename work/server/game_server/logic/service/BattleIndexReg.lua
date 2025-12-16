--[[
 * @file : BattleIndexReg.lua
 * @type : single snax service
 * @author : linfeng 九  零 一 起 玩 w w w . 9 0 1 7 5 . co m
 * @created : 2020-01-21 14:59:17
 * @Last Modified time: 2020-01-21 14:59:17
 * @department : Arabic Studio
 * @brief : 对象战斗索引管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local Timer = require "Timer"
local BattleCallback = require "BattleCallback"

local objectBattleIndexs = {}
local checkBattleServerNode = {}

---@see 检查战斗服务器是否活跃
local function checkBattleNodeAlive()
    local deadBattleNode = {}
    for battleNode in pairs(checkBattleServerNode) do
        if not Common.checkNodeAlive(battleNode, "MonitorSubscribe") then
            deadBattleNode[battleNode] = true
        end
    end

    for objectIndex, nodeInfo in pairs(objectBattleIndexs) do
        -- 战斗服务器连接中断
        if deadBattleNode[nodeInfo.battleNode] then
            BattleCallback:deleteObjectBattleStatus( { objectIndex = objectIndex, objectType = nodeInfo.objectType } )
            snax.self().req.removeObjectBattleIndex( objectIndex )
        end
    end

    -- 移除关闭的战斗节点
    for battleNode in pairs(deadBattleNode) do
        checkBattleServerNode[battleNode] = nil
    end
end

function init()
    Timer.runEvery(500, checkBattleNodeAlive )
end

---@see 添加对象战斗索引
function response.addObjectBattleIndex( _objectInfos, _battleIndex, _battleNode, _isTmpJoin )
    for _, objectInfo in pairs(_objectInfos) do
        objectBattleIndexs[objectInfo.objectIndex] = { battleIndex= _battleIndex, battleNode = _battleNode, objectType = objectInfo.objectType, tmpJoin = _isTmpJoin }
    end

    if not checkBattleServerNode[_battleNode] then
        checkBattleServerNode[_battleNode] = 1
    else
        checkBattleServerNode[_battleNode] = checkBattleServerNode[_battleNode] + 1
    end
end

---@see 获取对象战斗索引
function response.getObjectBattleIndex( _objectIndex, _isCheckTmpJoin )
    if objectBattleIndexs[_objectIndex] then
        if _isCheckTmpJoin then
            return objectBattleIndexs[_objectIndex].battleIndex, objectBattleIndexs[_objectIndex].tmpJoin
        else
            return objectBattleIndexs[_objectIndex].battleIndex
        end
    end
end

---@see 删除对象战斗索引
function response.removeObjectBattleIndex( _objectIndex )
    if not Common.isTable( _objectIndex ) then
        _objectIndex = { _objectIndex }
    end
    for _, objectIndex in pairs(_objectIndex) do
        if objectBattleIndexs[objectIndex] then
            local battleNode = objectBattleIndexs[objectIndex].battleNode
            if battleNode and checkBattleServerNode[battleNode] then
                checkBattleServerNode[battleNode] = checkBattleServerNode[battleNode] - 1
                if checkBattleServerNode[battleNode] <= 0 then
                    checkBattleServerNode[battleNode] = nil
                end
            end
            objectBattleIndexs[objectIndex] = nil
        end
    end
end

---@see 更新对象战斗索引
function response.updateObjectBattleIndex( _objectIndexs, _newBattleIndex )
    for _, objectIndex in pairs(_objectIndexs) do
        if objectBattleIndexs[objectIndex] then
            objectBattleIndexs[objectIndex].battleIndex = _newBattleIndex
        end
    end
end