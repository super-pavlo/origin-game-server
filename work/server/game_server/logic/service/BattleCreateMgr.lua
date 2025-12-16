--[[
 * @file : BattleCreateMgr.lua
 * @type : snax single service
 * @author : linfeng
 * @created : 2020-06-28 11:01:45
 * @Last Modified time: 2020-06-28 11:01:45
 * @department : Arabic Studio
 * @brief : 战斗创建管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local queue = require "skynet.queue"
local BattleCreate = require "BattleCreate"
local lock

function init()
    lock = queue()
end

---@see 创建战斗.避免并发创建战斗
function response.LockCreateBattle( _attackIndex, _defenseIndex )
    return lock( BattleCreate.syncCreateBattle, BattleCreate, _attackIndex, _defenseIndex )
end