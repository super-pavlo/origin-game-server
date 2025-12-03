--[[
 * @file : BattleLosePowerLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-11-03 17:15:28
 * @Last Modified time: 2020-11-03 17:15:28
 * @department : Arabic Studio
 * @brief : 战损补偿逻辑
 * Copyright(C) 2020 IGG, All rights reserved
]]

local Timer = require "Timer"
local RoleLogic = require "RoleLogic"
local EmailLogic = require "EmailLogic"
local ItemLogic = require "ItemLogic"
local GuildLogic = require "GuildLogic"
local BattleLosePowerLogic = {}

---@see 发战损补偿
function BattleLosePowerLogic:sendBattleLosePower( _rid, _waitGuildHelp, _noGuild )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.level, Enum.Role.guildId, Enum.Role.battleLostPowerValue } )
    if not _noGuild then
        -- 判断是否还在联盟内
        if roleInfo.guildId <= 0 then
            _noGuild = true
        end
    end

    if not _waitGuildHelp[_rid] or ( not _waitGuildHelp[_rid].helpMembers or table.empty(_waitGuildHelp[_rid].helpMembers) ) then
        -- 可能是重启后的,或者没人帮助
        _noGuild = true
    end

    local sSBattleDamageCompensation = CFG.s_BattleDamageCompensation:Get(roleInfo.level)
    if sSBattleDamageCompensation then
        -- 获取邮件ID
        local emailInfo = CFG.s_Config:Get("battleDamComMail")
        local sEmailId = emailInfo[1]
        if _noGuild then
            sEmailId = emailInfo[2]
        end

        -- 计算奖励
        local items = {}
        local reward = string.split(sSBattleDamageCompensation.makeup, "|")
        local rate = math.floor( roleInfo.battleLostPowerValue / sSBattleDamageCompensation.power )
        if rate < 1 then
            rate = 1
        end
        for _, rewardInfo in pairs(reward) do
            rewardInfo = string.split( rewardInfo, "-", true )
            table.insert( items, { itemId = rewardInfo[1], itemNum = rewardInfo[2] * rate } )
        end

        -- 发送奖励邮件
        local allMemberNames
        if _waitGuildHelp[_rid] and _waitGuildHelp[_rid].helpMembers and not table.empty(_waitGuildHelp[_rid].helpMembers) then
            -- 获取联盟成员名字
            allMemberNames = table.values( _waitGuildHelp[_rid].helpMembers )
        end
        local sSEmail = CFG.s_Mail:Get(sEmailId)
        EmailLogic:sendEmail( _rid, sEmailId, { emailContents = allMemberNames, rewards = { items = items }, takeEnclosure = sSEmail.receiveAuto == 1 } )

        -- 如果是自动发送,给具体奖励
        if sSEmail.receiveAuto == 1 then
            for _, itemInfo in pairs(items) do
                itemInfo.eventType = Enum.LogType.BATTLE_LOSE_ITEM
                itemInfo.rid = _rid
                ItemLogic:addItem( itemInfo )
            end
        end

        -- 发送运输车
        if not _noGuild then
            -- 有联盟
            for fromRid in pairs(_waitGuildHelp[_rid].helpMembers) do
                MSM.MapMarchMgr[_rid].post.battleLoseTransportEnterMap( fromRid, _rid )
            end
        else
            -- 无联盟
            MSM.MapMarchMgr[_rid].post.battleLoseTransportEnterMap( _rid, _rid )
        end
    else
        LOG_ERROR("rid(%d) sendBattleLosePower not found level(%d)", _rid, roleInfo.level )
    end

    -- 删除联盟帮助
    if roleInfo.guildId > 0 and _waitGuildHelp[_rid] and _waitGuildHelp[_rid].guildHelpIndex and _waitGuildHelp[_rid].guildHelpIndex > 0 then
        local requestHelps = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.requestHelps ) or {}
        requestHelps[_waitGuildHelp[_rid].guildHelpIndex] = nil
        -- 更新求助信息
        GuildLogic:setGuild( roleInfo.guildId, { [Enum.Guild.requestHelps] = requestHelps } )
        -- 通知客户端删除
        Common.syncMsg( _rid, "Guild_GuildRequestHelps",  { deleteHelpIndexs = { _waitGuildHelp[_rid].guildHelpIndex } } )
    end

    _waitGuildHelp[_rid] = nil

    -- 设置CD,重置损失战力
    RoleLogic:setRole( _rid, { battleLostPowerValue = 0 } )
end

---@see 发起联盟战损补偿帮助
function BattleLosePowerLogic:sendGuildHelp( _rid, _waitGuildHelp )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    -- 下发帮助
    MSM.GuildMgr[guildId].req.sendRequestHelp( guildId, _rid, Enum.GuildRequestHelpType.BATTLELOSE )
    -- 发起定时器
    _waitGuildHelp[_rid].timerId = Timer.runAfter( CFG.s_Config:Get("battleDamHelpTime") * 100, self.sendBattleLosePower, self, _rid, _waitGuildHelp )
end

---@see 检查角色是否触发战损补偿
function BattleLosePowerLogic:checkRoleBattleLosePower( _rid )
    -- 判断是否触发战损补偿
    MSM.BattleLosePowerMgr[_rid].post.checkRoleBattleLosePower( _rid )
end

return BattleLosePowerLogic