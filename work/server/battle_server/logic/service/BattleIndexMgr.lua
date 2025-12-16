--[[
* @file : BattleIndexMgr.lua
* @type : service
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 战斗索引管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local BattleIndex = 0
---@type table<integer, boolean>
local BattleIndexUse = {}

function init()
    setmetatable(BattleIndexUse, { __mode = "k" } )
end

---@see 返回一个可用的BattleIndex
function response.newBattleIndex()
    BattleIndex = BattleIndex + 1
    BattleIndexUse[BattleIndex] = true
    return BattleIndex
end

---@see 归还BattleIndex
function response.revertBattleIndex( _battleIndex )
    if _battleIndex > 0 and BattleIndexUse[_battleIndex] then
        BattleIndexUse[_battleIndex] = nil
        -- 移除 BattleLoop 里的数据
        MSM.BattleLoop[_battleIndex].req.delBattle( _battleIndex )
    end
end