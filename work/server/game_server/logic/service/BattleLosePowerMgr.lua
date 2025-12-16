--[[
 * @file : BattleLosePowerMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-11-03 14:00:24
 * @Last Modified time: 2020-11-03 14:00:24
 * @department : Arabic Studio
 * @brief : 战损补偿服务
 * Copyright(C) 2020 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local BattleLosePowerLogic = require "BattleLosePowerLogic"
local queue = require "skynet.queue"
local Timer = require "Timer"
local lock = {}
local waitGuildHelp = {}

---@see 增加角色战损
function accept.addRoleBattleLosePower( _rid, _soldierHurt )
    if not lock[_rid] then
        lock[_rid] = queue()
    end

    lock[_rid](function ()
        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.level, Enum.Role.battleLostPowerCD, Enum.Role.battleLostPowerValue } )
        -- 判断等级
        if roleInfo.level < CFG.s_Config:Get("battleDamComMinLv") then
            return
        end

        local now = os.time()
        -- 判断是否到了CD时间
        if roleInfo.battleLostPowerCD > now then
            return
        end

        -- 计算士兵战力
        local soldierPower = 0
        local sSoldierInfo
        for soldierId, soldierInfo in pairs(_soldierHurt) do
            sSoldierInfo = CFG.s_Arms:Get( soldierId )
            if sSoldierInfo then
                soldierPower = soldierPower + sSoldierInfo.militaryCapability * ( ( soldierInfo.hardHurt or 0 ) + ( soldierInfo.die or 0 ) )
            end
        end

        -- 增加角色战损
        roleInfo.battleLostPowerValue = roleInfo.battleLostPowerValue + soldierPower
        RoleLogic:setRole( _rid, { battleLostPowerValue = roleInfo.battleLostPowerValue } )
    end)
end

---@see 判断是否触发角色战损补偿
function accept.checkRoleBattleLosePower( _rid )
    if not lock[_rid] then
        lock[_rid] = queue()
    end

    lock[_rid](function ()
        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.online, Enum.Role.guildId, Enum.Role.lastBattlePvPRoleName,
                                                Enum.Role.level, Enum.Role.battleLostPowerCD, Enum.Role.battleLostPowerValue } )

        -- 是否在线
        if not roleInfo.online then
            return
        end
        -- 判断等级
        if roleInfo.level < CFG.s_Config:Get("battleDamComMinLv") then
            return
        end

        local now = os.time()
        -- 判断是否到了CD时间
        if roleInfo.battleLostPowerCD > now then
            return
        end

        -- 判断战损是否达到了
        local sSBattleDamageCompensation = CFG.s_BattleDamageCompensation:Get(roleInfo.level)
        if not sSBattleDamageCompensation then
            return
        end

        if roleInfo.battleLostPowerValue >= sSBattleDamageCompensation.power then
            -- 设置CD
            RoleLogic:setRole( _rid, { battleLostPowerCD = now + CFG.s_Config:Get("battleDamComCd") } )
            -- 如果在联盟中,触发联盟帮助
            if roleInfo.guildId > 0 then
                waitGuildHelp[_rid] = { helpMembers = {}, guildHelpIndex = 0 }
                BattleLosePowerLogic:sendGuildHelp( _rid, waitGuildHelp )
            else
                -- 直接给奖励
                BattleLosePowerLogic:sendBattleLosePower( _rid, waitGuildHelp, true )
            end

            -- 通知客户端,弹窗
            RoleLogic:roleNotify( _rid, Enum.RoleNotifyType.BATTLE_LOSE, nil, { roleInfo.lastBattlePvPRoleName } )
        end
    end)
end

---@see 盟友帮助了战损补偿
function accept.guildMemberHelp( _rid, _memberRid )
    if not lock[_rid] then
        lock[_rid] = queue()
    end

    lock[_rid](function ()
        -- 增加帮助的成员信息
        waitGuildHelp[_rid].helpMembers[_memberRid] = RoleLogic:getRole( _memberRid, Enum.Role.name )
        -- 是否已经满了
        if table.size(waitGuildHelp[_rid].helpMembers) >= CFG.s_Config:Get("battleDamMaxNum") then
            -- 移除定时器
            if waitGuildHelp[_rid].timerId and waitGuildHelp[_rid].timerId > 0 then
                Timer.delete( waitGuildHelp[_rid].timerId )
                waitGuildHelp[_rid].timerId = nil
            end
            -- 发送奖励
            BattleLosePowerLogic:sendBattleLosePower( _rid, waitGuildHelp )
        end
    end)
end

---@see 设置联盟帮助索引
function response.setGuildMemberHelpIndex( _rid, _helpIndex )
    if waitGuildHelp[_rid] then
        waitGuildHelp[_rid].guildHelpIndex = _helpIndex
    end
end