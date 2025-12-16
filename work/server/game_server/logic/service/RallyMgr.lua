--[[
 * @file : RallyMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-05-07 14:43:30
 * @Last Modified time: 2020-05-07 14:43:30
 * @department : Arabic Studio
 * @brief : 集结管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RallyDef = require "RallyDef"
local Timer = require "Timer"
local RallyLogic = require "RallyLogic"
local ArmyLogic = require "ArmyLogic"
local queue = require "skynet.queue"
local RoleLogic = require "RoleLogic"
local CommonCacle = require "CommonCacle"
local BattleCreate = require "BattleCreate"
local ArmyWalkLogic = require "ArmyWalkLogic"
local MapObjectLogic = require "MapObjectLogic"
local EarlyWarningLogic = require "EarlyWarningLogic"

---@type table<int, table<int, defaultRallyTeamClass>>
local rallyTeamInfo = {} -- 集结队伍信息
---@type table<int, function>
local rallyLock = {}


function init()
    Timer.runEvery( 100, RallyLogic.dispatchRallyTimer, RallyLogic, rallyTeamInfo )
end

---@see 初始化
function response.Init()

end

---@see 新增集结队伍
function response.newRallyTeam( _rid, _guildId, _mainHeroId, _deputyHeroId, _soldiers,
                                _targetIndex, _targetType, _rallyTime, _needActionForce, _rallyTimes )

    if not rallyLock[_targetIndex] then
        rallyLock[_targetIndex] = { lock = queue() }
    end

    return rallyLock[_targetIndex].lock(function ()
        -- 判断角色是否已经发起了集结
        if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rid] then
            LOG_ERROR("rid(%d) newRallyTeam error, only one rally", _rid)
            return false, ErrorCode.RALLY_ROLE_MAX_LAUNCH
        end

        -- 判断目标是否已经同联盟的集结
        if SM.RallyTargetMgr.req.checkRallySameGuild( _targetIndex, _guildId ) then
            LOG_ERROR("rid(%d) newRallyTeam error, checkRallySameGuild fail", _rid)
            return false, ErrorCode.RALLY_GUILD_HAD_RALLY
        end

        -- 创建部队
        local targetArg = { targetObjectIndex = _targetIndex, pos = RoleLogic:getRole( _rid, Enum.Role.pos ) }
        local armyIndex = ArmyLogic:createArmy( _rid, _mainHeroId, _deputyHeroId, _soldiers, _needActionForce, _targetType, targetArg, Enum.ArmyStatus.RALLY_WAIT )
        if not armyIndex then
            LOG_ERROR("rid(%d) newRallyTeam error, createArmy fail", _rid)
            return false, ErrorCode.RALLY_CREATE_ARMY_FAIL
        end

        -- 扣除属性影响时间
        _rallyTime = _rallyTime - RoleLogic:getRole( _rid, Enum.Role.rallyTimesReduce )

        -- 创建集结部队
        local defaultRallyTeam = RallyDef:getDefaultRallyTeam()
        defaultRallyTeam.rallyRid = _rid
        defaultRallyTeam.rallyMainHeroId = _mainHeroId
        defaultRallyTeam.rallyDeputyHeroId = _deputyHeroId
        defaultRallyTeam.rallyArmy = { [_rid] = armyIndex }
        defaultRallyTeam.rallyReadyTime = os.time() + _rallyTime
        defaultRallyTeam.rallyWaitTime = os.time() + _rallyTime
        defaultRallyTeam.rallyTargetIndex = _targetIndex
        defaultRallyTeam.rallyTargetType = _targetType
        defaultRallyTeam.rallyTargetGuildId = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectGuildId( _targetIndex )
        defaultRallyTeam.rallyStartTime = os.time()
        defaultRallyTeam.rallyMarchTime = 0

        local targetInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
        if targetInfo.objectType == Enum.RoleType.MONSTER_CITY or targetInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            defaultRallyTeam.rallyTargetMonsterId = targetInfo.monsterId
        end

        if not rallyTeamInfo[_guildId] then
            rallyTeamInfo[_guildId] = {}
        end
        rallyTeamInfo[_guildId][_rid] = defaultRallyTeam

        -- 通知联盟
        RallyLogic:notifyGuildRally( _rid, _guildId, _targetIndex, _targetType, _rallyTimes )
        -- 通知被集结目标联盟
        RallyLogic:notifyGuildRallyed( _rid, _targetIndex, _targetType )
        -- 推送联盟战争信息
        RallyLogic:syncGuildRallyInfo( _rid, _guildId, defaultRallyTeam )

        -- 增加被集结公会目标
        local targetGuildId = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectGuildId( _targetIndex )
        SM.RallyTargetMgr.req.addRallyTargetIndex( _targetIndex, targetGuildId, _rid, _guildId )

        -- 目标是部队,取消护盾
        if _targetType == Enum.RoleType.ARMY then
            RoleLogic:removeCityShield( _rid )
        end

        return true
    end)
end

---@see 加入集结
function response.joinRallyTeam( _guildId, _rid, _rallyRid, _armyIndex, _mainHeroId, _deputyHeroId, _soldiers, _soldierSum )
    if not rallyLock[_rid] then
        rallyLock[_rid] = { lock = queue() }
    end

    return rallyLock[_rid].lock(function ()
        return RallyLogic:joinRally( rallyTeamInfo, _guildId, _rid, _rallyRid, _armyIndex, _mainHeroId, _deputyHeroId, _soldiers, _soldierSum )
    end)
end

---@see 强制退出集结
function response.forceExitRallyTeam( _rid, _exitRid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if rallyTeamInfo[guildId] and rallyTeamInfo[guildId][_rid] then
        local tmpRallyTeamInfo = rallyTeamInfo[guildId][_rid]
        RallyLogic:exitRallyTeam( tmpRallyTeamInfo, _rid, _exitRid, nil, nil, nil, nil, nil, true, true )
        -- 出发的才解散
        if tmpRallyTeamInfo.rallyWaitTime <= os.time() and table.size( tmpRallyTeamInfo.rallyArmy ) <= 1 then
            -- 集结部队数量不够,解散
            MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rid )
        else
            -- 通知集结部队
            MSM.SceneArmyMgr[tmpRallyTeamInfo.rallyObjectIndex].post.rallyMemberExitTeam( tmpRallyTeamInfo.rallyObjectIndex, _exitRid )
            -- 通知联盟战争
            local targetGuildId = tmpRallyTeamInfo.rallyTargetGuildId
            RallyLogic:syncCancleJoinRally( _rid, guildId, tmpRallyTeamInfo.rallyTargetIndex, _exitRid, targetGuildId, tmpRallyTeamInfo )
        end
    end
end

---@see 通知集结部队已达到
function accept.armyRallyArrival( _guildId, _rid, _rallyRid )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rid] then
        local rallyInfo = rallyTeamInfo[_guildId][_rid]
        if rallyInfo.rallyWaitArmyInfo[_rallyRid] then
            -- 修改为加入集结行军
            local toPos = RoleLogic:getRole( _rid, Enum.Role.pos )
            local targetArg = ArmyLogic:getArmy( _rallyRid, rallyInfo.rallyArmy[_rallyRid], Enum.Army.targetArg ) or {}
            targetArg = { targetObjectIndex = targetArg.targetObjectIndex, pos = toPos }
            table.mergeEx( targetArg, ArmyLogic:getArmyRallyMarchTargetArg( rallyInfo.rallyTargetIndex ) )
            ArmyLogic:updateArmyInfo( _rallyRid, rallyInfo.rallyArmy[_rallyRid], {
                [Enum.Army.status] = Enum.ArmyStatus.RALLY_WAIT,
                [Enum.Army.targetArg] = targetArg,
                [Enum.Army.isInRally] = true, -- 设置为在集结部队中
            } )
            rallyInfo.rallyWaitArmyInfo[_rallyRid] = nil
        end
    end
end

---@see 遣返部队
function response.repatriationRallyArmy( _rid, _repatriationRid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    -- 判断是否是集结队长
    if not rallyTeamInfo[guildId][_rid] then
        return false, ErrorCode.RALLY_REPARTRIATION_NOT_LEADER
    end

    local tmpRallyTeamInfo = rallyTeamInfo[guildId][_rid]

    -- 判断是否加入了集结队伍
    if not tmpRallyTeamInfo.rallyArmy[_repatriationRid] then
        return false, ErrorCode.RALLY_REPARTRIATION_NOT_IN_TEAM
    end

    -- 判断集结队伍是否已经出发
    if tmpRallyTeamInfo.rallyWaitTime < os.time() then
        return false, ErrorCode.RALLY_REPARTRIATION_TEAM_LEAVE
    end

    -- 从集结部队中移除
    if RallyLogic:exitRallyTeam( tmpRallyTeamInfo, _rid, _repatriationRid ) then
        -- 通知联盟战争
        local targetGuildId = tmpRallyTeamInfo.rallyTargetGuildId
        RallyLogic:syncCancleJoinRally( _rid, guildId, tmpRallyTeamInfo.rallyTargetIndex, _repatriationRid, targetGuildId, tmpRallyTeamInfo )
        -- 重新计算等待时间
        local waitTime = rallyTeamInfo[guildId][_rid].rallyReadyTime
        for _, reinforceInfo in pairs(rallyTeamInfo[guildId][_rid].rallyWaitArmyInfo) do
            if waitTime < reinforceInfo.arrivalTime then
                waitTime = reinforceInfo.arrivalTime
            end
        end
        rallyTeamInfo[guildId][_rid].rallyWaitTime = waitTime
        -- 同步给客户端
        RallyLogic:syncGuildRallyWaitTime( _rid, guildId, waitTime, tmpRallyTeamInfo.rallyTargetGuildId, tmpRallyTeamInfo.rallyTargetIndex )
    else
        return false, ErrorCode.RALLY_REPARTRIATION_NOT_IN_TEAM
    end

    return true
end

---@see 解散集结部队
function response.disbandRallyArmy( _guildId, _rid, _isDefeat, _endExit, _leaderArmyNoEnter )
    -- 判断集结部队是否存在
    if not rallyTeamInfo[_guildId] or not rallyTeamInfo[_guildId][_rid] then
        LOG_ERROR("disbandRallyArmy error, not found rid(%d), guildId(%d)", _rid, _guildId)
        return false, ErrorCode.RALLY_DISBAND_NOT_RALLY
    end

    local tmpRallyTeamInfo = rallyTeamInfo[_guildId][_rid]
    local targetIndex = tmpRallyTeamInfo.rallyTargetIndex
    local rallyObjectIndex = tmpRallyTeamInfo.rallyObjectIndex

    -- 移除向目标行军
    ArmyWalkLogic:delArmyWalkTargetInfo( targetIndex, tmpRallyTeamInfo.rallyTargetType, rallyObjectIndex )

    -- 如果还没达到目标,取消预警
    if not rallyTeamInfo[_guildId][_rid].rallyArrivalTarget then
        local oldTargetIndex = rallyTeamInfo[_guildId][_rid].rallyTargetIndex
        if oldTargetIndex and oldTargetIndex > 0 then
            local oldTargetTypeInfo = MSM.MapObjectTypeMgr[oldTargetIndex].req.getObjectType( oldTargetIndex )
            if oldTargetTypeInfo then
                if MapObjectLogic:checkIsResourceObject( oldTargetTypeInfo.objectType ) then
                    -- 获取资源类的部队
                    local resourceInfo = MSM.SceneResourceMgr[oldTargetIndex].req.getResourceInfo( oldTargetIndex )
                    EarlyWarningLogic:deleteEarlyWarning( resourceInfo.collectRid, rallyObjectIndex, oldTargetIndex )
                elseif MapObjectLogic:checkIsGuildBuildObject( oldTargetTypeInfo.objectType ) then
                    -- 获取联盟建筑内的成员
                    local memberRids = MSM.SceneGuildBuildMgr[oldTargetIndex].req.getMemberRidsInBuild( oldTargetIndex )
                    for _, memberRid in pairs(memberRids) do
                        EarlyWarningLogic:deleteEarlyWarning( memberRid, rallyObjectIndex, oldTargetIndex )
                    end
                else
                    EarlyWarningLogic:deleteEarlyWarning( oldTargetTypeInfo.rid, rallyObjectIndex, oldTargetIndex )
                end
            end
        end
    end

    -- 正在增援的部队回城
    for reinforceRid, reinforceInfo in pairs(tmpRallyTeamInfo.rallyReinforce) do
        MSM.MapMarchMgr[reinforceInfo.reinforceObjectIndex].req.marchBackCity( reinforceRid, reinforceInfo.reinforceObjectIndex )
    end

    -- 如果集结部队已经在地图上生成了对象,删除此对象
    local fpos, allPlunderResource, armyLoadAtPlunder
    if rallyObjectIndex and rallyObjectIndex > 0 then
        -- 如果正在战斗,退出战斗
        local rallyObjectInfo = MSM.SceneArmyMgr[rallyObjectIndex].req.getArmyInfo( rallyObjectIndex )
        if rallyObjectInfo then
            if not _endExit then
                if ArmyLogic:checkArmyStatus( rallyObjectInfo.status, Enum.ArmyStatus.BATTLEING ) then
                    -- 退出战斗会自动解散集结部队
                    BattleCreate:exitBattle( rallyObjectIndex, true, _leaderArmyNoEnter )
                    return
                end
            end
            -- 处理掠夺资源分配
            allPlunderResource = { food = rallyObjectInfo.food, wood = rallyObjectInfo.wood,
                                    stone = rallyObjectInfo.stone, gold = rallyObjectInfo.gold }
            armyLoadAtPlunder = rallyObjectInfo.armyLoadAtPlunder
        end

        fpos = MSM.MapObjectTypeMgr[rallyObjectIndex].req.getObjectPos( rallyObjectIndex )
        -- 取消移动
        MSM.MapMarchMgr[rallyObjectIndex].req.stopObjectMove( rallyObjectIndex )
        -- 删除地图上的对象
        MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, rallyObjectIndex, { x = -1, y = -1 } )
    end

    -- 解散部队
    local exitRet, exitError
    for exitRid, exitArmyIndex in pairs(tmpRallyTeamInfo.rallyArmy) do
        if _leaderArmyNoEnter and exitRid == _rid then
            exitRet, exitError = xpcall( RallyLogic.exitRallyTeam, debug.traceback, RallyLogic, tmpRallyTeamInfo, _rid, exitRid, _isDefeat, fpos, _endExit, allPlunderResource, armyLoadAtPlunder, true )
            if not exitRet then
                -- 直接解散
                ArmyLogic:disbandArmy( exitRid, exitArmyIndex )
                LOG_ERROR("rid(%d) exitRallyTeam error:%s", _rid, exitError)
            end
        else
            exitRet, exitError = xpcall( RallyLogic.exitRallyTeam, debug.traceback, RallyLogic, tmpRallyTeamInfo, _rid, exitRid, _isDefeat, fpos, _endExit, allPlunderResource, armyLoadAtPlunder )
            if not exitRet then
                -- 直接解散
                ArmyLogic:disbandArmy( exitRid, exitArmyIndex )
                LOG_ERROR("rid(%d) exitRallyTeam error:%s", _rid, exitError)
            end
        end
    end

    -- 通知联盟战争,队伍解散
    RallyLogic:notifyGuildCancleRally( _rid, _guildId, tmpRallyTeamInfo, _endExit )

    -- 通知被集结目标取消了集结
    local targetGuildId = MSM.MapObjectTypeMgr[targetIndex].req.getObjectGuildId( targetIndex )
    SM.RallyTargetMgr.req.deleteRallyTargetIndex( targetIndex, targetGuildId, _rid, _guildId )

    -- 通知集结此队伍的集结,取消集结
    local guildRallyedInfo = SM.RallyTargetMgr.req.getGuildRallyedInfo( _guildId )
    if guildRallyedInfo then
        for rallyedTargetIndex, rallyRids in pairs(guildRallyedInfo.rally) do
            if rallyedTargetIndex == rallyTeamInfo[_guildId][_rid].rallyObjectIndex then
                for _, rallyRid in pairs(rallyRids) do
                    -- 其他联盟对集结队伍发起了反集结,取消集结
                    local rallyGuildId = RoleLogic:getRole( rallyRid, Enum.Role.guildId )
                    MSM.RallyMgr[rallyGuildId].req.disbandRallyArmy( rallyGuildId, rallyRid )
                end
            end
        end
    end

    rallyTeamInfo[_guildId][_rid] = nil

    return true
end

---@see 获取集结部队的集结目标
function response.getRallyTargetType( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if rallyTeamInfo[guildId] and rallyTeamInfo[guildId][_rid] then
        return rallyTeamInfo[guildId][_rid].rallyTargetType, rallyTeamInfo[guildId][_rid].rallyTargetIndex
    end
end

---@see 增援目标
function response.reinforceTarget( _rid, _reinforceRid, _armyIndex, _armyInfo, _reinforceObjectIndex, _reinforceObjectType, _ftype )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if rallyTeamInfo[guildId] and rallyTeamInfo[guildId][_rid] then
        local tmpRallyTeamInfo = rallyTeamInfo[guildId][_rid]
        -- 是否已经增援了此集结队伍
        if tmpRallyTeamInfo.rallyReinforce[_reinforceRid] then
            return nil, ErrorCode.RALLY_HAD_REINFORCE_TARGET
        end

        -- 是否已经加入了此集结队伍
        if tmpRallyTeamInfo.rallyArmy[_reinforceRid] then
            return nil, ErrorCode.RALLY_HAD_JOIN_TARGET_REINFORCE
        end

        -- 判断是否超过集结部队上限
        local armyCount = ArmyLogic:getArmySoldierCount( _armyInfo.soldiers )
        if not RallyLogic:checkRallyCapacity( tmpRallyTeamInfo, _rid, armyCount ) then
            return nil, ErrorCode.RALLY_OVER_MAX_MASS_TROOPS
        end

        -- 判断部队是否在地图上
        local armyInMap, objectIndex, fpos, tpos, isOutCity, targetInfo
        local reinforceRoleInfo = RoleLogic:getRole( _reinforceRid, { Enum.Role.pos, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
        if _armyIndex then
            objectIndex = MSM.RoleArmyMgr[_reinforceRid].req.getRoleArmyIndex( _reinforceRid, _armyIndex )
            if objectIndex then
                -- 部队在地图上
                armyInMap = true
                fpos = MSM.SceneArmyMgr[objectIndex].req.getArmyPos( objectIndex )
            else
                if ArmyLogic:checkArmyStatus( _armyInfo.status, Enum.ArmyStatus.COLLECTING )
                or ArmyLogic:checkArmyStatus( _armyInfo.status, Enum.ArmyStatus.GARRISONING )
                or ArmyLogic:checkArmyStatus( _armyInfo.status, Enum.ArmyStatus.RALLY_WAIT ) then
                    -- 在建筑或者采集中
                    local oldTargetObjectIndex = _armyInfo.targetArg and _armyInfo.targetArg.targetObjectIndex or 0
                    local oldTargetInfo
                    if oldTargetObjectIndex > 0 then
                        oldTargetInfo = MSM.MapObjectTypeMgr[oldTargetObjectIndex].req.getObjectInfo( oldTargetObjectIndex )
                    end
                    if oldTargetInfo then
                        fpos = oldTargetInfo.pos
                        _ftype = oldTargetInfo.objectType
                    end
                     -- 处理部队旧目标
                    ArmyLogic:checkArmyOldTarget( _reinforceRid, _armyIndex, _armyInfo )
                else
                    fpos = reinforceRoleInfo.pos
                    isOutCity = true
                end
            end
        else
            fpos = reinforceRoleInfo.pos
            isOutCity = true
        end


        local targetRadius
        if _reinforceObjectType == Enum.RoleType.ARMY then
            -- 目标部队位置
            targetInfo = MSM.SceneArmyMgr[_reinforceObjectIndex].req.getArmyInfo( _reinforceObjectIndex )
            tpos = targetInfo.pos
            targetRadius = CommonCacle:getArmyRadius( targetInfo.soldiers, true )
        end

        local arrivalTime
        if armyInMap then
            -- 移动部队,发起集结行军
            arrivalTime = MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, _reinforceObjectIndex, nil, Enum.ArmyStatus.REINFORCE_MARCH, Enum.MapMarchTargetType.REINFORCE )
        else
            local armyRadius = CommonCacle:getArmyRadius( _armyInfo.soldiers )
            -- 行军部队加入地图
            arrivalTime, objectIndex = ArmyLogic:armyEnterMap( _reinforceRid, _armyIndex, _armyInfo, _ftype, _reinforceObjectType, fpos, tpos,
                                                                _reinforceObjectIndex, Enum.MapMarchTargetType.REINFORCE, armyRadius,
                                                                targetRadius, isOutCity )
        end

        -- 增援目标失败
        if not arrivalTime then
            return false, ErrorCode.RALLY_REINFORCE_FAIL
        end

        -- 加入增援信息
        local defaultRallyReinforce = RallyDef:getDefaultRallyReinforce()
        defaultRallyReinforce.mainHeroId = _armyInfo.mainHeroId
        defaultRallyReinforce.deputyHeroId = _armyInfo.deputyHeroId
        defaultRallyReinforce.mainHeroLevel = _armyInfo.mainHeroLevel
        defaultRallyReinforce.deputyHeroLevel = _armyInfo.deputyHeroLevel
        defaultRallyReinforce.soldiers = _armyInfo.soldiers
        defaultRallyReinforce.arrivalTime = arrivalTime
        defaultRallyReinforce.reinforceTime = os.time()
        defaultRallyReinforce.reinforceRid = _reinforceRid
        defaultRallyReinforce.reinforceObjectIndex = objectIndex
        defaultRallyReinforce.reinforceArmyIndex = _armyIndex
        defaultRallyReinforce.reinforceName = reinforceRoleInfo.name
        defaultRallyReinforce.reinforceHeadId = reinforceRoleInfo.headId
        defaultRallyReinforce.reinforceHeadFrameId = reinforceRoleInfo.headFrameID
        tmpRallyTeamInfo.rallyReinforce[_reinforceRid] = defaultRallyReinforce

        -- 同步增援部队信息
        RallyLogic:syncRallyAddReinforce( _rid, guildId, _reinforceRid )

        return true
    end
end

---@see 增援到达
function response.reinforceArrivalCallback( _rid, _reinforceRid, _reinforceArmyIndex, _reinforceObjectIndex )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if rallyTeamInfo[guildId] and rallyTeamInfo[guildId][_rid]
    and rallyTeamInfo[guildId][_rid].rallyReinforce[_reinforceRid] then
        -- 二次判断是否超过集结部队上限
        local armyInfo = ArmyLogic:getArmy( _reinforceRid, _reinforceArmyIndex )
        local armyCount = ArmyLogic:getArmySoldierCount( armyInfo.soldiers )
        if not RallyLogic:checkRallyCapacity( rallyTeamInfo[guildId][_rid], _rid, armyCount ) then
            LOG_ERROR("_reinforceRid(%d) reinforceArrivalCallback over rally capacity", _reinforceRid)
            return false
        end

        -- 增援部队退出战斗
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
            BattleCreate:exitBattle( _reinforceObjectIndex, true )
        end

        -- 增援的部队加入到集结中
        rallyTeamInfo[guildId][_rid].rallyArmy[_reinforceRid] = _reinforceArmyIndex
        -- 从增援信息中移除
        rallyTeamInfo[guildId][_rid].rallyReinforce[_reinforceRid] = nil
        -- 删除增援信息
        RallyLogic:syncRallyDeleteReinforce( _rid, guildId, _reinforceRid, _reinforceArmyIndex )
        -- 同步联盟战争
        RallyLogic:syncJoinRally( _rid, guildId, rallyTeamInfo[guildId][_rid].rallyTargetIndex, _reinforceRid, rallyTeamInfo[guildId][_rid] )
        if rallyTeamInfo[guildId][_rid].rallyArrivalTarget then
            -- 更新部队状态为集结战斗
            ArmyLogic:updateArmyStatus( _reinforceRid, _reinforceArmyIndex, Enum.ArmyStatus.RALLY_BATTLE )
        else
            -- 更新部队状态为集结行军
            ArmyLogic:updateArmyStatus( _reinforceRid, _reinforceArmyIndex, Enum.ArmyStatus.RALLY_MARCH )
        end
        -- 修改为在集结部队中
        ArmyLogic:updateArmyInfo( _reinforceRid, _reinforceArmyIndex, { [Enum.Army.isInRally] = true }, true )
        return true
    end
end

---@see 取消增援
function response.cacleReinforce( _rid, _reinforceRid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if rallyTeamInfo[guildId] and rallyTeamInfo[guildId][_rid] and rallyTeamInfo[guildId][_rid].rallyReinforce[_reinforceRid] then
        -- 删除增援信息
        RallyLogic:syncRallyDeleteReinforce( _rid, guildId, _reinforceRid, rallyTeamInfo[guildId][_rid].rallyReinforce[_reinforceRid].reinforceArmyIndex )
        -- 从增援信息中移除
        rallyTeamInfo[guildId][_rid].rallyReinforce[_reinforceRid] = nil
    end
    return true
end

---@see 取消加入集结
function response.cacleJoinRally( _rid, _joinRallyRid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if rallyTeamInfo[guildId] and rallyTeamInfo[guildId][_rid] and rallyTeamInfo[guildId][_rid].rallyWaitArmyInfo[_joinRallyRid] then
        -- 已经达到的无法取消
        local tmpRallyTeamInfo = rallyTeamInfo[guildId][_rid]
        if tmpRallyTeamInfo.rallyWaitArmyInfo[_joinRallyRid].arrivalTime > os.time() then
            -- 从加入集结信息中移除
            RallyLogic:exitRallyTeam( rallyTeamInfo[guildId][_rid], _rid, _joinRallyRid )
            -- 获取目标联盟
            local targetGuildId = tmpRallyTeamInfo.rallyTargetGuildId
            -- 通知战争联盟
            RallyLogic:syncCancleJoinRally( _rid, guildId, tmpRallyTeamInfo.rallyTargetIndex, _joinRallyRid, targetGuildId, tmpRallyTeamInfo )
            -- 重新计算等待时间
            local waitTime = rallyTeamInfo[guildId][_rid].rallyReadyTime
            for _, reinforceInfo in pairs(rallyTeamInfo[guildId][_rid].rallyWaitArmyInfo) do
                if waitTime < reinforceInfo.arrivalTime then
                    waitTime = reinforceInfo.arrivalTime
                end
            end
            rallyTeamInfo[guildId][_rid].rallyWaitTime = waitTime
            -- 同步给客户端
            RallyLogic:syncGuildRallyWaitTime( _rid, guildId, waitTime, rallyTeamInfo.rallyTargetGuildId, rallyTeamInfo.targetObjectIndex )
            return true
        else
            return false
        end
    end

    return true
end

---@see 获取联盟集结信息
function response.getGuildRallyInfo( _guildId )
    if rallyTeamInfo[_guildId] then
        return rallyTeamInfo[_guildId]
    end
end

---@see 获取集结队伍信息
function response.getRallyTeamInfo( _guildId, _rid )
    if rallyTeamInfo[_guildId] then
        return rallyTeamInfo[_guildId][_rid]
    end
end

---@see 获取增援队伍信息
function response.getReinforceTeamInfo( _guildId, _rid, _reinforceRid )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rid] then
        return rallyTeamInfo[_guildId][_rid].rallyReinforce[_reinforceRid]
    end
end

---@see 判断角色是否已经增援了目标
function response.checkRoleIsReinforce( _guildId, _rid, _reinforceRid )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rid] then
        return rallyTeamInfo[_guildId][_rid].rallyReinforce[_reinforceRid] ~= nil
    end
end

---@see 角色退出联盟.处理集结相关
function accept.exitGuildDispatchRally( _guildId, _rid )
    if rallyTeamInfo[_guildId] then
        if rallyTeamInfo[_guildId][_rid] then
            -- 角色发起了集结,解散集结部队
            MSM.RallyMgr[_guildId].req.disbandRallyArmy( _guildId, _rid )
        else
            -- 判断角色是否加入了集结、增援
            for rallyRid, rallyInfo in pairs(rallyTeamInfo[_guildId]) do
                if rallyInfo.rallyArmy[_rid] or rallyInfo.rallyReinforce[_rid] then
                    -- 集结、增援部队退出
                    if rallyInfo.rallyWaitTime < os.time() then
                        -- 集结部队已经出发
                        local objectIndex = rallyInfo.rallyObjectIndex
                        local fpos = MSM.MapObjectTypeMgr[objectIndex].req.getObjectPos( objectIndex )
                        RallyLogic:exitRallyTeam( rallyInfo, rallyRid, _rid, nil, fpos )
                        if table.size( rallyInfo.rallyArmy ) <= 1 then
                            -- 集结部队数量不够,解散
                            MSM.RallyMgr[_guildId].req.disbandRallyArmy( _guildId, rallyRid )
                        else
                            -- 通知集结部队
                            MSM.SceneArmyMgr[objectIndex].post.rallyMemberExitTeam( objectIndex, _rid )
                            -- 通知联盟战争
                            local guildId = RoleLogic:getRole( rallyRid, Enum.Role.guildId )
                            local targetGuildId = rallyInfo.rallyTargetGuildId
                            RallyLogic:syncCancleJoinRally( rallyRid, guildId, rallyInfo.rallyTargetIndex, _rid, targetGuildId, rallyInfo )
                        end
                    else
                        -- 退出增援
                        MSM.RallyMgr[_guildId].req.repatriationRallyArmy( rallyRid, _rid )
                    end
                end
            end
        end
    end
end

---@see 联盟解散.处理集结相关
function response.disbanGuildDispatchRally( _guildId )
    if rallyTeamInfo[_guildId] then
        -- 解散全部集结部队
        for rallyRid in pairs(rallyTeamInfo[_guildId]) do
            MSM.RallyMgr[_guildId].req.disbandRallyArmy( _guildId, rallyRid )
        end
    end
end

---@see 判断是否是集结发起人
function response.checkIsRallyCreater( _guildId, _rid )
    if rallyTeamInfo[_guildId] then
        if rallyTeamInfo[_guildId][_rid] then
            return true
        end
    end
end

---@see 集结部队达到目标
function accept.rallyTeamArrival( _guildId, _rid )
    if rallyTeamInfo[_guildId] then
        if rallyTeamInfo[_guildId][_rid] then
            rallyTeamInfo[_guildId][_rid].rallyArrivalTarget = true
        end
    end
end

---@see 更新增援集结角色名称头像等信息
function accept.updateReinforceRoleInfo( _guildId, _rallyRid, _reinforceRid, _name, _headId, _headFrameId )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rallyRid] then
        local rallyReinforce = rallyTeamInfo[_guildId][_rallyRid].rallyReinforce
        if rallyReinforce and rallyReinforce[_reinforceRid] then
            if _name then
                rallyReinforce[_reinforceRid].reinforceName = _name
            end

            if _headId then
                rallyReinforce[_reinforceRid].reinforceHeadId = _headId
            end

            if _headFrameId then
                rallyReinforce[_reinforceRid].reinforceHeadFrameId = _headFrameId
            end
            -- 更新增援角色名称头像等信息
            RallyLogic:syncReinforceRallyRoleInfo( _guildId, _rallyRid, _reinforceRid, _name, _headId, _headFrameId )
        end
    end
end

---@see 获取集结队伍信息
function response.getRallyObjectIndex( _guildId, _rid )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rid] then
        return rallyTeamInfo[_guildId][_rid].rallyObjectIndex
    end
end

---@see 更新增援集结部队士兵信息
function accept.updateReinforceRoleSoldiers( _guildId, _rallyRid, _reinforceRid, _soldiers )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rallyRid] then
        local rallyReinforce = rallyTeamInfo[_guildId][_rallyRid].rallyReinforce
        if rallyReinforce and rallyReinforce[_reinforceRid] then
            rallyReinforce[_reinforceRid].soldiers = _soldiers
            -- 更新联盟战争界面增援角色部队信息
            RallyLogic:syncReinforceRallyRoleSoldiers( _guildId, _rallyRid, _reinforceRid, _soldiers )
        end
    end
end

---@see 修改集结目标的公会
function accept.updateTargetGuilId( _guildId, _rallyRid, _targetGuildId )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rallyRid] then
        rallyTeamInfo[_guildId][_rallyRid].rallyTargetGuildId = _targetGuildId
    end
end

---@see 增援部队到达时间改变
function accept.updateReinforceArrivalTime( _guildId, _rid, _reinforceRid, _arrivalTime )
    if rallyTeamInfo[_guildId] and rallyTeamInfo[_guildId][_rid] then
        if rallyTeamInfo[_guildId][_rid].rallyWaitArmyInfo[_reinforceRid] then
            rallyTeamInfo[_guildId][_rid].rallyWaitArmyInfo[_reinforceRid].arrivalTime = _arrivalTime + 1
            -- 重新计算等待时间
            local waitTime = rallyTeamInfo[_guildId][_rid].rallyReadyTime
            for _, reinforceInfo in pairs(rallyTeamInfo[_guildId][_rid].rallyWaitArmyInfo) do
                if waitTime < reinforceInfo.arrivalTime then
                    waitTime = reinforceInfo.arrivalTime
                end
            end
            rallyTeamInfo[_guildId][_rid].rallyWaitTime = waitTime
            -- 同步给客户端
            RallyLogic:syncGuildRallyWaitTime( _rid, _guildId, waitTime, rallyTeamInfo.rallyTargetGuildId, rallyTeamInfo.targetObjectIndex )
        end
    end
end