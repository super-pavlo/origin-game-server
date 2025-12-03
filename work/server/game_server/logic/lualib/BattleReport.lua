--[[
 * @file : BattleReport.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-02-17 09:42:58
 * @Last Modified time: 2020-02-17 09:42:58
 * @department : Arabic Studio
 * @brief : 战斗报告
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BattleLosePowerLogic = require "BattleLosePowerLogic"
local RoleLogic = require "RoleLogic"
local BattleTypeCacle = require "BattleTypeCacle"
local GuildLogic = require "GuildLogic"
local MapObjectLogic = require "MapObjectLogic"

local BattleReport = {}

---@see 根据战斗参与对象获取邮件ID和参数
---@param _exitArg defaultExitBattleArgClass
function BattleReport:getEmailIdAndArg( _exitArg )
    -- 攻击目标数量类型
    local defArmyCount = table.size( _exitArg.historyBattleObjectType )
    -- 攻击者数量
    local attackArmyCount = table.size( _exitArg.rallyMember ) + 1
    -- 战斗类型
    local battleType = BattleTypeCacle:getBattleType( _exitArg.objectType, _exitArg.attackTargetType, _exitArg.selfIsCheckPointMonster, _exitArg.targetIsCheckPointMonster )
    local sBattleMail = CFG.s_BattleMail:Get( battleType )
    if not sBattleMail then
        return
    end

    -- 判断是否是防御方
    local isDefenseSide
    if _exitArg.objectType == Enum.RoleType.CITY
    or MapObjectLogic:checkIsGuildBuildObject( _exitArg.objectType )
    or MapObjectLogic:checkIsHolyLandObject( _exitArg.objectType ) then
        isDefenseSide = true
    end

    local sEmailId
    -- 单人攻击
    if attackArmyCount == 1 then
        -- 单人战斗
        if _exitArg.win == Enum.BattleResult.WIN then
            -- 胜利
            if defArmyCount == 1 then
                if isDefenseSide then
                    -- 单人目标
                    if _exitArg.rallyLeader == _exitArg.rid then
                        -- 队长
                        sEmailId = sBattleMail.victoryMailID7
                    else
                        -- 队员
                        sEmailId = sBattleMail.victoryMailID9
                    end
                else
                    -- 单人目标
                    sEmailId = sBattleMail.victoryMailID1
                end
            else
                if isDefenseSide then
                    -- 多人目标
                    if _exitArg.rallyLeader == _exitArg.rid then
                        -- 队长
                        sEmailId = sBattleMail.victoryMailID8
                    else
                        -- 队员
                        sEmailId = sBattleMail.victoryMailID10
                    end
                else
                    -- 多人目标
                    sEmailId = sBattleMail.victoryMailID2
                end
            end
        elseif _exitArg.win == Enum.BattleResult.FAIL then
            -- 失败
            if defArmyCount == 1 then
                if isDefenseSide then
                    -- 单人目标
                    if _exitArg.rallyLeader == _exitArg.rid then
                        -- 队长
                        sEmailId = sBattleMail.failMailID7
                    else
                        -- 队员
                        sEmailId = sBattleMail.failMailID9
                    end
                else
                    -- 单人目标
                    sEmailId = sBattleMail.failMailID1
                end
            else
                if isDefenseSide then
                    -- 多人目标
                    if _exitArg.rallyLeader == _exitArg.rid then
                        -- 队长
                        sEmailId = sBattleMail.failMailID8
                    else
                        -- 队员
                        sEmailId = sBattleMail.failMailID10
                    end
                else
                    -- 多人目标
                    sEmailId = sBattleMail.failMailID2
                end
            end
        elseif _exitArg.win == Enum.BattleResult.NORESULT then
            -- 无结果
            if defArmyCount == 1 then
                if isDefenseSide then
                    -- 单人目标
                    if _exitArg.rallyLeader == _exitArg.rid then
                        -- 队长
                        sEmailId = sBattleMail.noResultMailID7
                    else
                        -- 队员
                        sEmailId = sBattleMail.noResultMailID9
                    end
                else
                    -- 单人目标
                    sEmailId = sBattleMail.noResultMailID1
                end
            else
                if isDefenseSide then
                    -- 多人目标
                    if _exitArg.rallyLeader == _exitArg.rid then
                        -- 队长
                        sEmailId = sBattleMail.noResultMailID8
                    else
                        -- 队员
                        sEmailId = sBattleMail.noResultMailID10
                    end
                else
                    -- 多人目标
                    sEmailId = sBattleMail.noResultMailID2
                end
            end
        end
    else
        -- 多人攻击
        if _exitArg.win == Enum.BattleResult.WIN then
            -- 胜利
            if defArmyCount == 1 then
                -- 单人目标
                if _exitArg.rallyLeader == _exitArg.rid then
                    -- 队长
                    sEmailId = sBattleMail.victoryMailID3
                else
                    -- 队员
                    sEmailId = sBattleMail.victoryMailID5
                end
            else
                -- 多人目标
                if _exitArg.rallyLeader == _exitArg.rid then
                    -- 队长
                    sEmailId = sBattleMail.victoryMailID4
                else
                    -- 队员
                    sEmailId = sBattleMail.victoryMailID6
                end
            end
        elseif _exitArg.win == Enum.BattleResult.FAIL then
            -- 失败
            if defArmyCount == 1 then
                -- 单人目标
                if _exitArg.rallyLeader == _exitArg.rid then
                    -- 队长
                    sEmailId = sBattleMail.failMailID3
                else
                    -- 队员
                    sEmailId = sBattleMail.failMailID5
                end
            else
                -- 多人目标
                if _exitArg.rallyLeader == _exitArg.rid then
                    -- 队长
                    sEmailId = sBattleMail.failMailID4
                else
                    -- 队员
                    sEmailId = sBattleMail.failMailID6
                end
            end
        elseif _exitArg.win == Enum.BattleResult.NORESULT then
            -- 无结果
            if defArmyCount == 1 then
                -- 单人目标
                if _exitArg.rallyLeader == _exitArg.rid then
                    -- 队长
                    sEmailId = sBattleMail.noResultMailID3
                else
                    -- 队员
                    sEmailId = sBattleMail.noResultMailID5
                end
            else
                -- 多人目标
                if _exitArg.rallyLeader == _exitArg.rid then
                    -- 队长
                    sEmailId = sBattleMail.noResultMailID4
                else
                    -- 队员
                    sEmailId = sBattleMail.noResultMailID6
                end
            end
        end
    end

    -- 获取邮件参数
    local selfGuildName, enemyGuildName
    local selfRoleInfo = {}
    if _exitArg.rid > 0 then
        selfRoleInfo = RoleLogic:getRole( _exitArg.rid, { Enum.Role.guildId, Enum.Role.name } )
        selfGuildName = GuildLogic:getGuild( selfRoleInfo.guildId, Enum.Guild.abbreviationName )
    end
    local enemyRoleInfo = {}
    if _exitArg.targetRid > 0 then
        enemyRoleInfo = RoleLogic:getRole( _exitArg.targetRid, { Enum.Role.guildId, Enum.Role.name } )
        enemyGuildName = GuildLogic:getGuild( enemyRoleInfo.guildId, Enum.Guild.abbreviationName )
    end
    if _exitArg.targetGuildId and _exitArg.targetGuildId > 0 and not enemyGuildName then
        enemyGuildName = GuildLogic:getGuild( _exitArg.targetGuildId, Enum.Guild.abbreviationName )
    end

    local reportSubTile = {
        tostring(_exitArg.rid),                   -- 已方角色rid
        selfRoleInfo.name or "",                  -- 已方角色名字
        selfGuildName or "",                      -- 已方联盟名称
        tostring(_exitArg.targetRid),             -- 敌方角色rid
        tostring(_exitArg.targetStaticId),        -- 敌方对象ID(建筑类)
        enemyRoleInfo.name or "",                 -- 敌方角色名字
        enemyGuildName or "",                     -- 敌方联盟名称
        tostring(_exitArg.selfStaticId),          -- 己方对象ID(建筑类)
    }

    return sEmailId, reportSubTile, defArmyCount
end

---@see 战斗结果报告
---@param _exitArg defaultExitBattleArgClass
function BattleReport:makeBattleReport( _exitArg )
    local sEmailId, reportSubTile, defArmyCount = self:getEmailIdAndArg( _exitArg )

    for _, objectInfo in pairs(_exitArg.battleReportEx.objectInfos) do
        local rid
        if objectInfo.objectType == Enum.RoleType.ARMY
        or objectInfo.objectType == Enum.RoleType.CITY
        or MapObjectLogic:checkIsResourceObject( objectInfo.objectType ) then
            rid = objectInfo.rid
        elseif MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType )
        or MapObjectLogic:checkIsGuildBuildObject( objectInfo.objectType ) then
            -- 联盟建筑、圣地,取队长
            rid = objectInfo.rallyLeader
        end

        if rid and rid > 0 then
            local roleInfo = RoleLogic:getRole( rid )
            objectInfo.name = roleInfo.name
            objectInfo.headId = roleInfo.headId
            objectInfo.rid = objectInfo.rid
            if roleInfo.guildId and roleInfo.guildId > 0 then
                -- 取联盟简称
                local guildInfo = GuildLogic:getGuild( roleInfo.guildId, { Enum.Guild.abbreviationName } )
                if guildInfo then
                    objectInfo.guildName = guildInfo.abbreviationName
                end
            end
        end

        -- 集结子部队信息,获取角色名字
        if objectInfo.battleRallySoldierHurt then
            for rallyRid, rallyHurtInfo in pairs(objectInfo.battleRallySoldierHurt) do
                rallyHurtInfo.rallyRoleName = RoleLogic:getRole( rallyRid, Enum.Role.name )
            end
        end
    end

    local sendRids = { _exitArg.rid }
    if _exitArg.sendReportRid and _exitArg.sendReportRid > 0 then
        sendRids = { _exitArg.sendReportRid }
    else
        local recaclePower
        -- 如果是联盟建筑或者圣地,取驻守内的
        if MapObjectLogic:checkIsGuildBuildObject( _exitArg.objectType ) then
            sendRids = MSM.SceneGuildBuildMgr[_exitArg.objectIndex].req.getMemberRidsInBuild( _exitArg.objectIndex )
            recaclePower = true
        elseif MapObjectLogic:checkIsHolyLandObject( _exitArg.objectType ) then
            sendRids = MSM.SceneHolyLandMgr[_exitArg.objectIndex].req.getMemberRidsInBuild( _exitArg.objectIndex )
            recaclePower = true
        elseif _exitArg.objectType == Enum.RoleType.ARMY then
            -- 部队,判断是否是集结部队
            if _exitArg.isRally then
                sendRids = table.indexs( _exitArg.rallyMember )
            end
        end

        if recaclePower then
            -- 建筑类退出战斗,重新计算战力
            MSM.RolePowerMgr[_exitArg.rid].post.cacleSyncHistoryPower( sendRids )
        end
    end

    if sEmailId then
        for _, sendRid in pairs(sendRids) do
            if sendRid and sendRid > 0 then
                MSM.EmailMgr[sendRid].post.sendBattleReportEmail( sendRid, sEmailId, reportSubTile, _exitArg.battleReportEx, _exitArg.mainHeroId )
                -- 判断是否触发战损补偿
                BattleLosePowerLogic:checkRoleBattleLosePower( sendRid )
            end
        end
    end

    if _exitArg.objectType == Enum.RoleType.CITY then
        -- 城市,也同时发一份给盟友
        local reinforces = RoleLogic:getRole( _exitArg.rid, Enum.Role.reinforces )
        -- 已经达到的才发
        sendRids = {}
        for reinforceRid, reinforceInfo in pairs(reinforces) do
            if not reinforceInfo.arrivalTime or reinforceInfo.arrivalTime <= os.time() then
                table.insert( sendRids, reinforceRid )
            end
        end
        if table.size( sendRids ) > 0 then
            local sReinforceEmailId
            local sBattleMail = CFG.s_BattleMail:Get( Enum.BattleType.CITY_PVP )
            -- 根据结果获取邮件ID
            if _exitArg.win == Enum.BattleResult.FAIL then
                if defArmyCount == 1 then
                    sReinforceEmailId = sBattleMail.failMailID9
                else
                    sReinforceEmailId = sBattleMail.failMailID10
                end
            elseif _exitArg.win == Enum.BattleResult.WIN then
                if defArmyCount == 1 then
                    sReinforceEmailId = sBattleMail.victoryMailID9
                else
                    sReinforceEmailId = sBattleMail.victoryMailID10
                end
            else
                if defArmyCount == 1 then
                    sReinforceEmailId = sBattleMail.noResultMailID9
                else
                    sReinforceEmailId = sBattleMail.noResultMailID10
                end
            end

            -- 发送
            if sReinforceEmailId then
                for _, sendRid in pairs(sendRids) do
                    if sendRid and sendRid > 0 then
                        MSM.EmailMgr[sendRid].post.sendBattleReportEmail( sendRid, sReinforceEmailId, reportSubTile, _exitArg.battleReportEx, _exitArg.mainHeroId )
                        -- 判断是否触发战损补偿
                        BattleLosePowerLogic:checkRoleBattleLosePower( sendRid )
                    end
                end
            end
        end
    end
end

return BattleReport