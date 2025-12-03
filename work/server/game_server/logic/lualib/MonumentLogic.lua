--[[
* @file : MonumentLogic.lua
* @type : lua lib
* @author : chenlei
* @created : Fri May 01 2020 01:55:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 纪念碑逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local GuildLogic = require "GuildLogic"
local BuildingLogic = require "BuildingLogic"
local ItemLogic = require "ItemLogic"
local HolyLandLogic = require "HolyLandLogic"
local RankLogic = require "RankLogic"
local Random = require "Random"

local MonumentLogic = {}

---@see 设置进度
function MonumentLogic:setSchedule( _rid, _args )
    -- 判断当前的服务器纪念碑类型
    local step = SM.MonumentMgr.req.GetStep()
    if not step then
        local cMonument = SM.c_monument.req.Get() or {}
        if table.size( cMonument ) > 0 then
            for _, info in pairs(cMonument) do
                if info.finishTime then
                    if not step or info.id > step then
                        step = info.id
                    end
                end
            end
            if not step then return end
        end
    end

    local sEvolutionMileStone = CFG.s_EvolutionMileStone:Get(step)
    if _args.type == sEvolutionMileStone.type and _args.type ~= Enum.MonumentType.SERVER_CITY_LEVEL then
        local cMonument= SM.c_monument.req.Get(step)
        local monumentInfo
        if _rid and _rid > 0 then
            monumentInfo = RoleLogic:getRole( _rid, Enum.Role.monumentInfo )
            if not monumentInfo[step] then monumentInfo[step] = { step = step, count = 0, reward = false, canReward = false } end
        end
        local setGuildFlag = false
        if _args.type == Enum.MonumentType.SERVER_SCOUT then
            -- 所有执政官共同完成{p1}块迷雾的探索
            if _rid then
                monumentInfo[step].count = monumentInfo[step].count + _args.count
            end
            cMonument.count = cMonument.count + _args.count
        elseif _args.type == Enum.MonumentType.SERVER_KILL_MONSTER then
            -- 全服玩家累计击杀{p1}支等级{p2}及以上野蛮人部队
            if not _args.level or _args.level >= sEvolutionMileStone.param1 then
                if _rid then
                    monumentInfo[step].count = monumentInfo[step].count + _args.count
                end
                cMonument.count = cMonument.count + _args.count
            end
        elseif _args.type == Enum.MonumentType.SERVER_ALLICNCE_MEMBER_COUNT then
            --成员超过{p1}的联盟达到{r1}个
            if sEvolutionMileStone.recordRank == Enum.MonumentnShowRank.YES then
                if not _args.count or _args.count >= sEvolutionMileStone.param1 then
                    cMonument.guildList[_args.guildId] = { guildId = _args.guildId, count = _args.count }
                else
                    if cMonument.guildList[_args.guildId] then
                        cMonument.guildList[_args.guildId] = nil
                    end
                end
                cMonument.count = table.size(cMonument.guildList or {})
            end
        elseif _args.type == Enum.MonumentType.SERVER_ALLICNCE_FLAG_COUNT then
            -- 全王国总共建造{p1}面联盟旗帜
            if sEvolutionMileStone.recordRank == Enum.MonumentnShowRank.YES then
                if not cMonument.guildList[_args.guildId] then
                    cMonument.guildList[_args.guildId] = { guildId = _args.guildId, count = 0 }
                end
                cMonument.guildList[_args.guildId].count = cMonument.guildList[_args.guildId].count + _args.count
                if cMonument.guildList[_args.guildId].count < 0 then
                    cMonument.guildList[_args.guildId].count = 0
                end
            end
            cMonument.count = cMonument.count + _args.count
        elseif _args.type == Enum.MonumentType.SERVER_SANCTUARY then
            -- {r1}座圣所被首次占领
            if not _args.buildType or _args.buildType == sEvolutionMileStone.param1 then
                if sEvolutionMileStone.recordRank == Enum.MonumentnShowRank.YES then
                    if not cMonument.guildList[_args.guildId] then
                        cMonument.guildList[_args.guildId] = { guildId = _args.guildId, count = 0 }
                    end
                    cMonument.guildList[_args.guildId].count = cMonument.guildList[_args.guildId].count + _args.count
                    cMonument.count = cMonument.count + _args.count
                    if cMonument.guildList[_args.guildId].count < 0 then
                        cMonument.guildList[_args.guildId].count = 0
                    end
                end
            end
        elseif _args.type == Enum.MonumentType.SERVER_ALLICNCE_KILL_WALLED then
            -- 所在联盟击败{r1}个等级{p1}或以上的野蛮人城寨
            if _args.level >= sEvolutionMileStone.param1 then
                --monumentInfo = GuildLogic:getGuild( _args.guildId, Enum.Guild.monumentInfo )
                --if not monumentInfo[step] then monumentInfo[step] = { step = step, count = 0, reward = false, canReward = false } end
                --monumentInfo[step].count = monumentInfo[step].count + _args.count
                if sEvolutionMileStone.recordRank == Enum.MonumentnShowRank.YES then
                    if not cMonument.guildList[_args.guildId] then
                        cMonument.guildList[_args.guildId] = { guildId = _args.guildId, count = 0 }
                    end
                    cMonument.guildList[_args.guildId].count = cMonument.guildList[_args.guildId].count + _args.count
                    if cMonument.guildList[_args.guildId].count < 0 then
                        cMonument.guildList[_args.guildId].count = 0
                    end
                end
            end
            setGuildFlag = true
        elseif _args.type == Enum.MonumentType.SERVER_ALLICNCE_POWER then
            -- 角逐王国联盟战力20强
            --monumentInfo = GuildLogic:getGuild( _args.guildId, Enum.Guild.monumentInfo )
            --if not monumentInfo[step] then monumentInfo[step] = { step = step, count = 0, reward = false, canReward = false } end
            --monumentInfo[step].count = 1
            if sEvolutionMileStone.recordRank == Enum.MonumentnShowRank.YES then
                if not cMonument.guildList[_args.guildId] then
                    cMonument.guildList[_args.guildId] = { guildId = _args.guildId, count = 0 }
                end
                cMonument.guildList[_args.guildId].count = _args.count
            end
            setGuildFlag = true
        elseif _args.type == Enum.MonumentType.SERVER_ALLICNCE_BUILD_COUNT then
            -- 倒计时结束时，您所在的联盟正占领着一座圣坛
            if _args.buildType == sEvolutionMileStone.param1 then
                --monumentInfo = GuildLogic:getGuild( _args.guildId, Enum.Guild.monumentInfo )
                --if not monumentInfo[step] then monumentInfo[step] = { step = step, count = 0, reward = false, canReward = false } end
                --monumentInfo[step].count = monumentInfo[step].count + _args.count
                if sEvolutionMileStone.recordRank == Enum.MonumentnShowRank.YES then
                    if not cMonument.guildList[_args.guildId] then
                        cMonument.guildList[_args.guildId] = { guildId = _args.guildId, count = 0 }
                    end
                    cMonument.guildList[_args.guildId].count = cMonument.guildList[_args.guildId].count + _args.count
                    if cMonument.guildList[_args.guildId].count < 0 then
                        cMonument.guildList[_args.guildId].count = 0
                    end
                end
            end
            setGuildFlag = true
        end
        SM.c_monument.req.Set(step, cMonument)
        if not setGuildFlag and monumentInfo then
            RoleLogic:setRole( _rid, { [Enum.Role.monumentInfo] = monumentInfo } )
            RoleSync:syncSelf( _rid, { [Enum.Role.monumentInfo] = { [step] = monumentInfo[step] } }, true, true )
        elseif monumentInfo then
            --GuildLogic:setGuild( _args.guildId, { [Enum.Guild.monumentInfo] = monumentInfo } )
        end
    elseif _args.type == Enum.MonumentType.SERVER_CITY_LEVEL then
        local monumentInfo
        if _rid then
            monumentInfo = RoleLogic:getRole( _rid, Enum.Role.monumentInfo )
        end
        local synInfo = {}
        for _, info in pairs(CFG.s_EvolutionMileStone:Get()) do
            if _args.type == info.type then
                local cMonument= SM.c_monument.req.Get(info.order)
                -- {r1}名执政官进入XX时代
                if (not _args.level or _args.level == info.param1) and (not cMonument.finishTime or cMonument.finishTime > os.time()) then
                    if _rid then
                        if not monumentInfo[info.order] then monumentInfo[info.order] = { step = info.order, count = 0, reward = false, canReward = false } end
                        monumentInfo[info.order].count = _args.level
                        synInfo[info.order] = monumentInfo[info.order]
                    end
                    cMonument.count = cMonument.count + _args.count
                    SM.c_monument.req.Set(info.order, cMonument)
                end
            end
        end
        if _rid then
            RoleLogic:setRole( _rid, { [Enum.Role.monumentInfo] = monumentInfo } )
            RoleSync:syncSelf( _rid, { [Enum.Role.monumentInfo] = synInfo }, true, true )
        end
    end
    -- 判断当前阶段能否提前关闭
    local cMonument = SM.c_monument.req.Get(step)
    if sEvolutionMileStone.closeType == Enum.MonumentCloseType.CONDITION_AND_TIME and cMonument.count >= sEvolutionMileStone.require then
        MonumentLogic:monumentEnd()
    end
end

---@see 纪念碑数据修正
function MonumentLogic:fixData( _id )
    local service = SM.MonumentMgr
    local step = service.req.GetStep()
    if not step then
        local cMonument = SM.c_monument.req.Get() or {}
        if table.size( cMonument ) > 0 then
            for _, info in pairs(cMonument) do
                if info.finishTime then
                    if not step or info.id > step then
                        step = info.id
                    end
                end
            end
            if not step then return end
        end
    end
    local sOldEvolutionMileStone = CFG.s_EvolutionMileStone:Get(step)
    if not sOldEvolutionMileStone.adjustRuleId or sOldEvolutionMileStone.adjustRuleId <= 0 then
        return
    end
    if sOldEvolutionMileStone.gobalFlag == Enum.MonumentRewardType.SERVER and
        ( sOldEvolutionMileStone.type ~= Enum.MonumentType.SERVER_ALLICNCE_POWER and sOldEvolutionMileStone.type ~= Enum.MonumentType.SERVER_SANCTUARY )then
        local sEvolutionGoalFillData = CFG.s_EvolutionGoalFillData:Get(_id)
        local cMonument= SM.c_monument.req.Get(step)
        local nowCount = 0
        if cMonument then nowCount = cMonument.count end
        if nowCount <= sEvolutionGoalFillData.goalCnt then
            local Q = sEvolutionGoalFillData.goalCnt - nowCount
            local addCount = math.floor(Random.Get(sEvolutionGoalFillData.adjustMin, sEvolutionGoalFillData.adjustMax)/1000 * Q)
            local info = { type = sOldEvolutionMileStone.type, count = addCount , guildId = 0}
            if sOldEvolutionMileStone.type == Enum.MonumentType.SERVER_CITY_LEVEL then
                info.level = sOldEvolutionMileStone.param1
            end
            MonumentLogic:setSchedule( nil, info )
        end
        -- 如果还有定时器，增加下一次定时器
        service.req.addFixTiemr(step)
    end
end

---@see 纪念碑结束处理
function MonumentLogic:monumentEnd()
    local service = SM.MonumentMgr
    local step = service.req.GetStep()
    if not step then
        local cMonument = SM.c_monument.req.Get() or {}
        if table.size( cMonument ) > 0 then
            for _, info in pairs(cMonument) do
                if info.finishTime then
                    if not step or info.id > step then
                        step = info.id
                    end
                end
            end
            if not step then return end
        end
    end
    local newStep = step + 1
    local sOldEvolutionMileStone = CFG.s_EvolutionMileStone:Get(step)
    -- 发送跑马灯
    local RoleChatLogic = require "RoleChatLogic"
    RoleChatLogic:sendMarquee( 183016, { sOldEvolutionMileStone.order, sOldEvolutionMileStone.l_nameId } )
    local sEvolutionMileStone = CFG.s_EvolutionMileStone:Get(newStep)
    -- 记录日志
    local LogLogic = require "LogLogic"
    local mounmentInfo = SM.c_monument.req.Get(step)
    LogLogic:roleEvolution( {
                   id = sOldEvolutionMileStone.ID, count = mounmentInfo.count,
            } )
    service.req.deleteFixTiemr()
    -- 增加定时器，增加过期时间
    local cMonument
    if sEvolutionMileStone then
        cMonument = SM.c_monument.req.Get(newStep)
        local oldMonument = SM.c_monument.req.Get(step)
        if oldMonument.finishTime > os.time() then
            oldMonument.finishTime = os.time()
        end
        cMonument.finishTime = oldMonument.finishTime + sEvolutionMileStone.expireTime
        SM.c_monument.req.Set( newStep, cMonument )
        service.req.addMonumentTimer(cMonument.finishTime)
        service.post.SetStep(cMonument.order)
    end
    cMonument = SM.c_monument.req.Get(step)
    if cMonument.finishTime > os.time() then
        cMonument.finishTime = os.time()
    end
    if sOldEvolutionMileStone.type == Enum.MonumentType.SERVER_ALLICNCE_POWER then
        cMonument.guildList = {}
        local key = RankLogic:getKey( Enum.RankType.ALLIANCE_POWER )
        local rankInfos = MSM.RankMgr[0].req.queryRank( key, 1, 20, true )
        for _, rankInfo in pairs( rankInfos ) do
            local member = tonumber(rankInfo.member)
            local score = RankLogic:getScore( tonumber(rankInfo.score), Enum.RankType.ALLIANCE_POWER )
            table.insert(cMonument.guildList, { guildId = member, count = score })
        end
    end
    SM.c_monument.req.Set( step, cMonument )
    if sEvolutionMileStone then
        service.req.addFixTiemr(newStep)
    end
    -- 推送在线玩家，纪念碑结束
    local onlines = SM.OnlineMgr.req.getAllOnlineRid()
    for _, rid in pairs(onlines) do
        Common.syncMsg( rid, "Monument_End", { flag = true } )
    end
    if sOldEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE or
        sOldEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE_RANK then
        local guildList = {}
        for _, guidlInfo in pairs(cMonument.guildList) do
            table.insert( guildList, { guildId = guidlInfo.guildId, count = guidlInfo.count } )
        end
        table.sort( guildList, function (a, b)
            return a.count > b.count
        end)
        for index, guildInfo in pairs(guildList) do
            if sOldEvolutionMileStone.type ~= Enum.MonumentType.SERVER_ALLICNCE_KILL_WALLED then
                local members = GuildLogic:getGuild( guildInfo.guildId, Enum.Guild.members )
                for memberRid in pairs( members or {} ) do
                    local monumentInfo = RoleLogic:getRole( memberRid, Enum.Role.monumentInfo )
                    if not monumentInfo[step] then monumentInfo[step] = { step = step, count = 0, reward = false, canReward = false } end
                    monumentInfo[step].canReward = true
                    monumentInfo[step].count = guildInfo.count
                    if sOldEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE_RANK then
                        monumentInfo[step].rank = index
                    end
                    RoleLogic:setRole( memberRid, { [Enum.Role.monumentInfo] = monumentInfo })
                end
            elseif guildInfo.count >= sOldEvolutionMileStone.require then
                local members = GuildLogic:getGuild(  guildInfo.guildId, Enum.Guild.members )
                for memberRid in pairs( members or {} ) do
                    local monumentInfo = RoleLogic:getRole( memberRid, Enum.Role.monumentInfo )
                    if not monumentInfo[step] then monumentInfo[step] = { step = step, count = 0, reward = false, canReward = false } end
                    monumentInfo[step].canReward = true
                    monumentInfo[step].count = guildInfo.count
                    if sOldEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE_RANK then
                        monumentInfo[step].rank = index
                    end
                    RoleLogic:setRole( memberRid, { [Enum.Role.monumentInfo] = monumentInfo })
                end
            end
        end
    end
    -- 纪念碑事件解锁圣地
    HolyLandLogic:mileStoneUnlockHolyLands( sOldEvolutionMileStone.ID, cMonument.finishTime )
    if sEvolutionMileStone then
        cMonument = SM.c_monument.req.Get(newStep)
        if sEvolutionMileStone.type == Enum.MonumentType.SERVER_ALLICNCE_MEMBER_COUNT then
            local centerNode = Common.getCenterNode()
            -- 本服所有联盟ID
            local guildIds = Common.rpcCall( centerNode, "GuildProxy", "queryGuildMemberCount", Common.getSelfNodeName() ) or {}
            for guildId, guildInfo in pairs( guildIds ) do
                --成员超过{p1}的联盟达到{r1}个
                if guildInfo.size >= sEvolutionMileStone.param1 then
                    cMonument.guildList[guildId] = { guildId = guildId, count = guildInfo.size }
                    cMonument.count = cMonument.count + 1
                end
            end
            SM.c_monument.req.Set( newStep, cMonument )
        end

        if sEvolutionMileStone.closeType == Enum.MonumentCloseType.CONDITION_AND_TIME and cMonument.count >= sEvolutionMileStone.require then
            MonumentLogic:monumentEnd()
        end
    end
    -- 判断迷雾全开
    if sOldEvolutionMileStone.ID == CFG.s_Config:Get("allDenseFogMileStone") then
        -- 通知所有在线的玩家,迷雾全开
        local DenseFogLogic = require "DenseFogLogic"
        DenseFogLogic:onMonumentOpenAllDenseFog()
    end

end

---@see 获取纪念碑信息
function MonumentLogic:getMonument( _rid )
    local cMonument = SM.c_monument.req.Get()
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.createTime, Enum.Role.monumentInfo, Enum.Role.guildId, Enum.Role.denseFogOpenTime, Enum.Role.denseFogOpenFlag } )
    local monumentList = {}
    local monumentInfo = roleInfo.monumentInfo
    local monumentBuilding = BuildingLogic:getBuildingInfoByType( _rid, Enum.BuildingType.MONUMENT )
    if not monumentBuilding or table.empty(monumentBuilding) then
        return { monumentList = monumentList }
    end
    --monumentBuilding = monumentBuilding[1]
    for id, cMonumentInfo in pairs(cMonument) do
        if cMonumentInfo.finishTime then

            local roleMonument = monumentInfo[id] or {}
            local monument = {}
            monument.id = id
            local sEvolutionMileStone = CFG.s_EvolutionMileStone:Get(id)
            if sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE then
                monument.reward = roleMonument.reward
                monument.canReward = roleMonument.canReward
                if roleInfo.guildId and roleInfo.guildId > 0 and cMonumentInfo.guildList and cMonumentInfo.guildList[roleInfo.guildId] then
                    monument.count = cMonumentInfo.guildList[roleInfo.guildId].count
                end
                local guildRank = {}
                for guilidId, guild in pairs(cMonumentInfo.guildList or {}) do
                    local guildInfo = GuildLogic:getGuild( guilidId )
                    if guildInfo then
                        table.insert( guildRank, { count = guild.count, signs = guildInfo.signs, guildName = guildInfo.name, abbreviationName = guildInfo.abbreviationName } )
                    else
                        table.insert( guildRank, { count = guild.count, signs = nil, guildName = nil, abbreviationName = nil } )
                    end
                end
                monument.guildRank = guildRank
            elseif sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE_RANK then
                monument.reward = roleMonument.reward
                monument.canReward = roleMonument.canReward
                if roleInfo.guildId and roleInfo.guildId > 0 and cMonumentInfo.guildList and cMonumentInfo.guildList[roleInfo.guildId] then
                    monument.count = cMonumentInfo.guildList[roleInfo.guildId].count
                end
                local guildRank = {}
                for guilidId, guild in pairs(cMonumentInfo.guildList or {}) do
                    local guildInfo = GuildLogic:getGuild( guilidId )
                    if guildInfo then
                        table.insert( guildRank, { count = guild.count, signs = guildInfo.signs, guildName = guildInfo.name, abbreviationName = guildInfo.abbreviationName } )
                    else
                        table.insert( guildRank, { count = guild.count, signs = nil, guildName = nil, abbreviationName = nil } )
                    end
                end
                monument.guildRank = guildRank
            elseif sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.SERVER then
                monument.reward = roleMonument.reward
                monument.canReward = false
                monument.serverCount = cMonumentInfo.count
                if cMonumentInfo.count >= sEvolutionMileStone.require then
                    monument.canReward = true
                end
                monument.count = roleMonument.count
                local guildRank = {}
                for guilidId, guild in pairs(cMonumentInfo.guildList or {}) do
                    local guildInfo = GuildLogic:getGuild( guilidId )
                    if guildInfo then
                        table.insert( guildRank, { count = guild.count, signs = guildInfo.signs, guildName = guildInfo.name, abbreviationName = guildInfo.abbreviationName } )
                    else
                        table.insert( guildRank, { count = guild.count, signs = nil, guildName = nil, abbreviationName = nil } )
                    end
                end
                monument.guildRank = guildRank
            elseif sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.PERSON then
                monument.canReward = false
                monument.reward = roleMonument.reward
                monument.count = roleMonument.count
                -- 先检查角色是否已经全部手动探索完
                local DenseFogLogic = require "DenseFogLogic"
                DenseFogLogic:checkDenseFogOnRoleLogin( _rid )
                if roleInfo.denseFogOpenTime < cMonumentInfo.finishTime
                    and RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) then
                    monument.count = 1
                    monument.canReward = true
                end
            end
            if not monument.reward then
                monument.reward = false
            end
            monument.finishTime = cMonumentInfo.finishTime
            monumentList[id] = monument
        end
    end
    return { monumentList = monumentList }
end

---@see 领取纪念碑奖励
function MonumentLogic:getMonumentReward( _rid, _id )
    local monumentInfo = RoleLogic:getRole( _rid, Enum.Role.monumentInfo )
    if not monumentInfo[_id] then monumentInfo[_id] = { step = _id, count = 0, reward = false, canReward = true } end
    monumentInfo[_id].reward = true
    RoleLogic:setRole( _rid, { [Enum.Role.monumentInfo] = monumentInfo })
    RoleSync:syncSelf( _rid, { [Enum.Role.monumentInfo] = { [_id] = monumentInfo[_id] } }, true )
    local s_EvolutionMileStone = CFG.s_EvolutionMileStone:Get(_id)
    local rewardInfo
    if s_EvolutionMileStone.recordRankReward == Enum.MonumentnRankReward.PERSON then
        local rewardId =  s_EvolutionMileStone.reward
        rewardInfo = ItemLogic:getItemPackage( _rid, rewardId )
    else
        local sEvolutionRankReward = CFG.s_EvolutionRankReward:Get(s_EvolutionMileStone.recordRankReward)
        local rank = monumentInfo[_id].rank
        for _, config in pairs(sEvolutionRankReward) do
            if config.rankMin <= rank and rank <= config.rankMax then
                rewardInfo = ItemLogic:getItemPackage( _rid, config.reward )
                break
            end
        end
    end
    return { rewardInfo = rewardInfo }
end

---@see 判断纪念碑某章节是否结束
function MonumentLogic:checkMonumentStatus( _id )
    local sEvolutionMileStone = CFG.s_EvolutionMileStone:Get()
    for order, evolutionMileStone in pairs(sEvolutionMileStone) do
        if evolutionMileStone.ID == _id then
            local cMonument = SM.c_monument.req.Get(order)
            if not cMonument or not cMonument.finishTime or cMonument.finishTime >= os.time() then
                return false
            end
            return true, cMonument.finishTime
        end
    end
end

---@see 登录推送纪念碑信息
function MonumentLogic:pushMonument( _rid )
    local monumentList = self:getMonument( _rid ).monumentList
    for _, info in pairs(monumentList) do
        if info.canReward and not info.reward then
            -- 推送信息
            Common.syncMsg( _rid, "Monument_RewardNodify", { canReward = true } )
            return
        end
    end
    Common.syncMsg( _rid, "Monument_RewardNodify", { canReward = false } )
end

return MonumentLogic