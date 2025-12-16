--[[
 * @file : RallyLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-08 13:34:42
 * @Last Modified time: 2020-05-08 13:34:42
 * @department : Arabic Studio
 * @brief : 集结相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local EmailLogic = require "EmailLogic"
local RoleLogic = require "RoleLogic"
local ArmyLogic = require "ArmyLogic"
local ArmyMarchLogic = require "ArmyMarchLogic"
local RallyDef = require "RallyDef"
local GuildLogic = require "GuildLogic"
local MapObjectLogic = require "MapObjectLogic"
local CityReinforceLogic = require "CityReinforceLogic"
local HeroLogic = require "HeroLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local HolyLandLogic = require "HolyLandLogic"

local RallyLogic = {}

---@see 集结定时处理
---@param _rallyTeamInfo table<int, table<int, defaultRallyTeamClass>>
function RallyLogic:dispatchRallyTimer( _rallyTeamInfo )
    local now = os.time()
    for guildId, guildRallyTeamInfo in pairs(_rallyTeamInfo) do
        for rallyRid, rallyTeamInfo in pairs(guildRallyTeamInfo) do
            -- 集结准备、等待完成
            if rallyTeamInfo.rallyMarchTime <= 0 and now >= rallyTeamInfo.rallyWaitTime then
                -- 判断是否有人响应集结
                if table.size(rallyTeamInfo.rallyArmy) <= 1 then
                    -- 无人响应集结,发送通知
                    local emailArg
                    if rallyTeamInfo.rallyTargetType == Enum.RoleType.MONSTER_CITY or rallyTeamInfo.rallyTargetType == Enum.RoleType.SUMMON_RALLY_MONSTER then
                        -- 野蛮人城寨、召唤怪物
                        emailArg = { rallyTeamInfo.rallyTargetMonsterId }
                        EmailLogic:sendEmail( rallyRid, 110001, { subTitleContents = emailArg, emailContents = emailArg } )
                        -- 退还体力
                        local armyInfo = ArmyLogic:getArmy( rallyRid, rallyTeamInfo.rallyArmy[rallyRid] )
                        local roleInfo = RoleLogic:getRole( rallyRid, { Enum.Role.name, Enum.Role.guildId, Enum.Role.actionForce } )
                        local armyChangeInfo = {}
                        ArmyMarchLogic:checkReturnActionForce( rallyRid, roleInfo, armyInfo, armyChangeInfo )
                        if not table.empty( armyChangeInfo ) then
                            ArmyLogic:setArmy( rallyRid, rallyTeamInfo.rallyArmy[rallyRid], armyChangeInfo )
                        end
                    elseif MapObjectLogic:checkIsAttackGuildBuildObject( rallyTeamInfo.rallyTargetType ) then
                        -- 联盟建筑
                        emailArg = { GuildBuildLogic:objectTypeToBuildType(rallyTeamInfo.rallyTargetType) }
                        EmailLogic:sendEmail( rallyRid, 110002, { subTitleContents = emailArg, emailContents = emailArg } )
                    elseif MapObjectLogic:checkIsHolyLandObject( rallyTeamInfo.rallyTargetType ) then
                        -- 圣地
                        local holyLandInfo = MSM.SceneHolyLandMgr[rallyTeamInfo.rallyTargetIndex].req.getHolyLandInfo( rallyTeamInfo.rallyTargetIndex )
                        if holyLandInfo then
                            emailArg = { holyLandInfo.strongHoldId }
                            EmailLogic:sendEmail( rallyRid, 110003, { subTitleContents = emailArg, emailContents = emailArg } )
                        end
                    elseif rallyTeamInfo.rallyTargetType == Enum.RoleType.CITY then
                        -- 城市
                        local cityInfo = MSM.SceneCityMgr[rallyTeamInfo.rallyTargetIndex].req.getCityInfo( rallyTeamInfo.rallyTargetIndex )
                        if cityInfo then
                            local guildAndRoleName = RoleLogic:getGuildNameAndRoleName( cityInfo.rid )
                            emailArg = { guildAndRoleName }
                            EmailLogic:sendEmail( rallyRid, 110004, { subTitleContents = emailArg, emailContents = emailArg } )
                        end
                    end

                    -- 解散部队
                    ArmyLogic:disbandArmy( rallyRid, rallyTeamInfo.rallyArmy[rallyRid] )
                    -- 通知联盟战争,取消集结
                    self:notifyGuildCancleRally( rallyRid, guildId, rallyTeamInfo, true )
                    -- 单独通知发起集结者
                    GuildLogic:guildNotify( rallyRid, Enum.GuildNotify.RALLY_MEMBER_NOT_ENOUGH )
                    -- 通知被集结目标取消了集结
                    local targetIndex = rallyTeamInfo.rallyTargetIndex
                    local targetGuildId = MSM.MapObjectTypeMgr[targetIndex].req.getObjectGuildId( targetIndex )
                    SM.RallyTargetMgr.req.deleteRallyTargetIndex( targetIndex, targetGuildId, rallyRid, guildId )
                    -- 取消集结
                    _rallyTeamInfo[guildId][rallyRid] = nil
                else
                    -- 有人响应,向目标发起行军
                    self:rallyArmyEnterMap( rallyRid, rallyTeamInfo )
                end
            end
        end
    end
end

---@see 计算集结部队数量
function RallyLogic:cacleRallyArmyCount( _rallyArmy )
    local soldiers = {}
    for rid, armyIndex in pairs(_rallyArmy) do
        local armySoldiers = ArmyLogic:getArmy( rid, armyIndex, Enum.Army.soldiers )
        if armySoldiers then
            for soldierId, soldierInfo in pairs(armySoldiers) do
                if not soldiers[soldierId] then
                    soldiers[soldierId] = soldierInfo
                else
                    soldiers[soldierId].num = soldiers[soldierId].num + soldierInfo.num
                end
            end
        end
    end
    return soldiers
end

---@see 发起集结行军
---@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:rallyArmyEnterMap( _rallyRid, _rallyTeamInfo )
    -- 合并士兵
    local soldiers = self:cacleRallyArmyCount( _rallyTeamInfo.rallyArmy )
    -- 生成一个新的对象ID
    local objectIndex = Common.newMapObjectIndex()
    -- 集结发起者公会
    local guildId = RoleLogic:getRole( _rallyTeamInfo.rallyRid, Enum.Role.guildId )
    -- 部队信息
    local armyInfo = ArmyLogic:getArmy( _rallyRid, _rallyTeamInfo.rallyArmy[_rallyRid] )
    if not armyInfo or table.empty(armyInfo) then
        -- 发起集结的部队不存在了
        LOG_ERROR("rallyArmyEnterMap, not found rallyRid(%d) armyIndex(%d)", _rallyRid, _rallyTeamInfo.rallyArmy[_rallyRid])
        -- 取消集结
        MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rallyTeamInfo.rallyRid, false, false, true )
        return
    end
    armyInfo.soldiers = soldiers
    armyInfo.rallyArmy = _rallyTeamInfo.rallyArmy
    armyInfo.status = Enum.ArmyStatus.RALLY_MARCH

    -- 路径
    local targetIndex = _rallyTeamInfo.rallyTargetIndex
    local fPos = RoleLogic:getRole( _rallyTeamInfo.rallyRid, Enum.Role.pos )
    local targetInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
    if not targetInfo then
        -- 解散
        MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rallyTeamInfo.rallyRid, false, false, true )
        return
    end
    local tPos = targetInfo.pos
    local targetGuildId = targetInfo.guildId or 0

    -- 修改集结部队中的其他部队状态
    for joinRid, joinArmyIndex in pairs(_rallyTeamInfo.rallyArmy) do
        ArmyLogic:updateArmyStatus( joinRid, joinArmyIndex, Enum.ArmyStatus.RALLY_MARCH, nil, true )
    end

    local path = { fPos, tPos }
    -- 行军部队加入地图,发起攻击
    local arrivalTime, _, rallyPath = MSM.MapMarchMgr[objectIndex].req.armyEnterMap( _rallyTeamInfo.rallyRid, objectIndex, armyInfo, path,
                                                    Enum.MapMarchTargetType.RALLY_ATTACK, targetIndex, true, nil, true )
    if not arrivalTime then
        -- 解散
        MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rallyTeamInfo.rallyRid )
        return
    end
    -- 更新集结行军到达时间
    _rallyTeamInfo.rallyMarchTime = arrivalTime
    -- 更新集结队伍地图对象索引
    _rallyTeamInfo.rallyObjectIndex = objectIndex
    -- 集结队伍路径
    _rallyTeamInfo.rallyPath = rallyPath
    -- 同步给联盟
    local rallyGuildId = RoleLogic:getRole( _rallyRid, Enum.Role.guildId )
    self:syncGuildRallyMarchTime( _rallyRid, rallyGuildId, arrivalTime, rallyPath, targetGuildId, targetIndex, objectIndex )
end

---@see 其他人加入集结
---@param _rallyTeamInfo table<int, table<int, defaultRallyTeamClass>>
function RallyLogic:joinRally( _rallyTeamInfo, _guildId, _rid, _rallyRid, _armyIndex, _mainHeroId, _deputyHeroId, _soldiers, _soldierSum )
    -- 判断目标是否发起了集结
    if not _rallyTeamInfo[_guildId] or not _rallyTeamInfo[_guildId][_rid] then
        return nil, ErrorCode.RALLY_JOIN_NOT_FOUND
    end

    local rallyTeamInfo = _rallyTeamInfo[_guildId][_rid]

    -- 判断是否已经加入了集结
    if rallyTeamInfo.rallyArmy[_rallyRid] then
        return nil, ErrorCode.RALLY_JOIN_HAD_JOIN
    end

    -- 判断是否超过集结最大容量
    if not self:checkRallyCapacity( rallyTeamInfo, _rid, _soldierSum ) then
        return nil, ErrorCode.RALLY_OVER_MAX_MASS_TROOPS
    end

    -- 集结部队如果已经出发,无法再加入集结
    if rallyTeamInfo.rallyObjectIndex and rallyTeamInfo.rallyObjectIndex > 0 then
        return nil, ErrorCode.RALLY_JOIN_ON_ARMY_MATCH
    end

    -- 如果目标是向野蛮人城寨发起的集结,判断行动力是否足够
    local needActionForce, armyInfo
    local targetIndex = rallyTeamInfo.rallyTargetIndex
    local targetType = rallyTeamInfo.rallyTargetType
    if targetType == Enum.RoleType.MONSTER_CITY or targetType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        local rallyTargetMonsterId = rallyTeamInfo.rallyTargetMonsterId or 0
        if rallyTargetMonsterId <= 0 then
            local monsterCityInfo
            if targetType == Enum.RoleType.MONSTER_CITY then
                monsterCityInfo = MSM.SceneMonsterCityMgr[targetIndex].req.getMonsterCityInfo( targetIndex )
            else
                monsterCityInfo = MSM.SceneMonsterMgr[targetIndex].req.getMonsterInfo( targetIndex )
            end
            rallyTargetMonsterId = monsterCityInfo and monsterCityInfo.monsterId or 0
        end
        needActionForce = CFG.s_Monster:Get( rallyTargetMonsterId, "rallyAP" ) or 0
        if needActionForce then
            if _armyIndex then
                armyInfo = ArmyLogic:getArmy( _rallyRid, _armyIndex )
                needActionForce = HeroLogic:subHeroVitality( _rallyRid, armyInfo, nil, nil, needActionForce )
            else
                needActionForce = HeroLogic:subHeroVitality( _rallyRid, nil, _mainHeroId, _deputyHeroId, needActionForce )
            end
        end
        if RoleLogic:getRole( _rallyRid, Enum.Role.actionForce ) < needActionForce then
            return nil, ErrorCode.RALLY_ACTION_FORCE_NO_ENOUGH
        end
    end

    local arrivalTime, objectIndex

    -- 判断部队是否在城外
    local armyInMap = false
    if _armyIndex then
        objectIndex = MSM.RoleArmyMgr[_rallyRid].req.getRoleArmyIndex( _rallyRid, _armyIndex )
        if objectIndex then
            -- 部队在地图上
            armyInMap = true
        end
    end

    local toPos = RoleLogic:getRole( _rid, Enum.Role.pos )
    if not armyInMap then
        local fromType
        local fpos
        if not _armyIndex then
            -- 创建部队,发起集结行军
            _armyIndex, armyInfo = ArmyLogic:createArmy( _rallyRid, _mainHeroId, _deputyHeroId, _soldiers,
                                                    needActionForce, targetType, nil, Enum.ArmyStatus.RALLY_JOIN_MARCH )
            if not _armyIndex then
                return false, ErrorCode.RALLY_CREATE_ARMY_FAIL
            end
            fromType = Enum.RoleType.CITY
            fpos = RoleLogic:getRole( _rallyRid, Enum.Role.pos )
        else
            -- 从建筑出来的
            armyInfo = armyInfo or ArmyLogic:getArmy( _rallyRid, _armyIndex )
            -- 修改为加入集结行军
            ArmyLogic:updateArmyStatus( _rallyRid, _armyIndex, Enum.ArmyStatus.RALLY_JOIN_MARCH )
            -- 扣除行动力
            if needActionForce then
                -- 删除预扣除的活动力
                ArmyLogic:setArmy( _rallyRid, _armyIndex, { [Enum.Army.preCostActionForce] = needActionForce } )
                -- 通知客户端预扣除行动力
                ArmyLogic:syncArmy( _rallyRid, _armyIndex, { [Enum.Army.preCostActionForce] = needActionForce }, true )
                -- 预扣除角色行动力
                RoleLogic:addActionForce( _rallyRid, - needActionForce, nil, Enum.LogType.ATTACK_COST_ACTION )
            end
            local armyTargetIndex = armyInfo.targetArg.targetObjectIndex
            local armyTargetInfo = MSM.MapObjectTypeMgr[armyTargetIndex].req.getObjectInfo( armyTargetIndex )
            fromType = armyTargetInfo.objectType
            fpos = armyTargetInfo.pos
            -- 处理部队旧目标
            ArmyLogic:checkArmyOldTarget( _rallyRid, _armyIndex, armyInfo )
        end

        -- 行军部队加入地图
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        arrivalTime, objectIndex = ArmyLogic:armyEnterMap( _rallyRid, _armyIndex, armyInfo, fromType, Enum.RoleType.CITY,
                                                fpos, toPos, cityIndex, Enum.MapMarchTargetType.RALLY, nil, nil, true )
    else
        -- 扣除行动力
        if needActionForce then
            -- 删除预扣除的活动力
            ArmyLogic:setArmy( _rallyRid, _armyIndex, { [Enum.Army.preCostActionForce] = needActionForce } )
            -- 通知客户端预扣除行动力
            ArmyLogic:syncArmy( _rallyRid, _armyIndex, { [Enum.Army.preCostActionForce] = needActionForce }, true )
            -- 预扣除角色行动力
            RoleLogic:addActionForce( _rallyRid, - needActionForce, nil, Enum.LogType.ATTACK_COST_ACTION )
        end
        -- 获取部队的对象索引
        armyInfo = MSM.SceneArmyMgr[objectIndex].req.getArmyInfo( objectIndex )
        _armyIndex = armyInfo.armyIndex
        -- 移动部队,发起集结行军
        local cityIndex = RoleLogic:getRoleCityIndex( _rid )
        arrivalTime = MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, cityIndex, nil, Enum.ArmyStatus.RALLY_JOIN_MARCH,
                                                                    Enum.MapMarchTargetType.RALLY )
    end

    if not arrivalTime then
        -- 没有路径,取消加入集结
        return nil, ErrorCode.RALLY_NO_PATH_TO_TARGET
    end

    -- 预加入集结队伍
    rallyTeamInfo.rallyArmy[_rallyRid] = _armyIndex
    -- 加入集结队伍信息
    local defaultJoinRally = RallyDef:getDefaultJoinRally()
    defaultJoinRally.arrivalTime = arrivalTime
    defaultJoinRally.objectIndex = objectIndex
    defaultJoinRally.joinTime = os.time()
    rallyTeamInfo.rallyWaitArmyInfo[_rallyRid] = defaultJoinRally

    -- 同步联盟战争加入集结信息
    self:syncJoinRally( _rid, _guildId, rallyTeamInfo.rallyTargetIndex, _rallyRid, rallyTeamInfo )

    if rallyTeamInfo.rallyWaitTime < arrivalTime then
        -- 更新集结等待时间
        rallyTeamInfo.rallyWaitTime = arrivalTime
        -- 更新集结等待时间
        self:syncGuildRallyWaitTime( _rid, _guildId, arrivalTime, rallyTeamInfo.rallyTargetGuildId, targetIndex )
    end
end

---@see 获取集结部队最大容量
------@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:getRallyArmyMax( _rid, _rallyTeamInfo )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.massTroopsCapacity, Enum.Role.massTroopsCapacityMulti } )
    local massTroopsCapacity = roleInfo.massTroopsCapacity
    local massTroopsCapacityMulti = roleInfo.massTroopsCapacityMulti

    -- 统帅技能天赋影响
    if _rallyTeamInfo.rallyMainHeroId and _rallyTeamInfo.rallyMainHeroId > 0 then
        massTroopsCapacity = massTroopsCapacity + HeroLogic:getHeroAttr( _rid, _rallyTeamInfo.rallyMainHeroId, Enum.Role.massTroopsCapacity )
        massTroopsCapacityMulti = massTroopsCapacityMulti + HeroLogic:getHeroAttr( _rid, _rallyTeamInfo.rallyMainHeroId, Enum.Role.massTroopsCapacityMulti )
    end
    if _rallyTeamInfo.rallyDeputyHeroId and _rallyTeamInfo.rallyDeputyHeroId > 0 then
        massTroopsCapacity = massTroopsCapacity + HeroLogic:getHeroAttr( _rid, _rallyTeamInfo.rallyDeputyHeroId, Enum.Role.massTroopsCapacity, true )
        massTroopsCapacityMulti = massTroopsCapacityMulti + HeroLogic:getHeroAttr( _rid, _rallyTeamInfo.rallyDeputyHeroId, Enum.Role.massTroopsCapacityMulti, true )
    end

    if MapObjectLogic:checkIsGuildBuildObject( _rallyTeamInfo.rallyTargetType ) then
        -- 集结目标是联盟建筑时
        local guildBuildInfo = MSM.SceneGuildBuildMgr[_rallyTeamInfo.rallyTargetIndex].req.getGuildBuildInfo( _rallyTeamInfo.rallyTargetIndex )
        return math.floor( math.min( guildBuildInfo.armyCntLimit * ( 1 + massTroopsCapacityMulti / 1000 ),
                            massTroopsCapacity * ( 1 + massTroopsCapacityMulti / 1000 ) ) )
    elseif MapObjectLogic:checkIsHolyLandObject( _rallyTeamInfo.rallyTargetType ) then
        -- 集结目标是圣地
        local holyLandInfo = MSM.SceneHolyLandMgr[_rallyTeamInfo.rallyTargetIndex].req.getHolyLandInfo( _rallyTeamInfo.rallyTargetIndex )
        return math.floor( math.min( holyLandInfo.armyCntLimit * ( 1 + massTroopsCapacityMulti / 1000 ),
                            massTroopsCapacity * ( 1 + massTroopsCapacityMulti / 1000 ) ) )
    else
        return math.floor( massTroopsCapacity * ( 1 + massTroopsCapacityMulti / 1000 ) )
    end
end

---@see 获取集结部队当前容量
function RallyLogic:getRallyArmyCount( _rallyTeamInfo )
    local allArmyCount = 0
    for rid, armyIndex in pairs(_rallyTeamInfo.rallyArmy) do
        allArmyCount = allArmyCount + ArmyLogic:getArmySoldierCount( nil, rid, armyIndex )
    end
    return allArmyCount
end

---@see 检查集结队伍当前容量
---@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:checkRallyCapacity( _rallyTeamInfo, _rid, _soldierSum )
    -- 计算最大容量
    local maxMassTroopsCapacity = self:getRallyArmyMax( _rid, _rallyTeamInfo )
    -- 计算当前容量
    local allArmyCount = self:getRallyArmyCount( _rallyTeamInfo )

    return allArmyCount + _soldierSum <= maxMassTroopsCapacity
end

---@see 退出集结部队
---@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:exitRallyTeam( _rallyTeamInfo, _rid, _exitRid, _isDefeat, _rallyTeamPos,
                                    _endExit, _allPlunderResource, _armyLoadAtPlunder, _forceExit, _forceMoveCity )
    -- 如果集结的是野蛮人城寨,退还体力
    if not _endExit and ( _rallyTeamInfo.rallyTargetType == Enum.RoleType.MONSTER_CITY or _rallyTeamInfo.rallyTargetType == Enum.RoleType.SUMMON_RALLY_MONSTER ) then
        if not _rallyTeamInfo.rallyArrivalTarget then
            -- 如果没达到目标才退还
            local roleInfo = RoleLogic:getRole( _exitRid )
            local armyInfo = ArmyLogic:getArmy( _exitRid, _rallyTeamInfo.rallyArmy[_exitRid] )
            local armyChangeInfo = {}
            ArmyMarchLogic:checkReturnActionForce( _exitRid, roleInfo, armyInfo, armyChangeInfo )
            if not table.empty( armyChangeInfo ) then
                ArmyLogic:setArmy( _exitRid, _rallyTeamInfo.rallyArmy[_exitRid], armyChangeInfo )
            end
        end
    end

    if _rallyTeamInfo.rallyArmy[_exitRid] then
        local armyIndex = _rallyTeamInfo.rallyArmy[_exitRid]
        if _rallyTeamInfo.rallyArrivalTarget then
            MSM.ActivityRoleMgr[_exitRid].req.setActivitySchedule( _exitRid, Enum.ActivityActionType.JOIN_RALLY_COUNT, 1 )
        end
        local objectIndex
        if not _forceExit and ( _rid ~= _exitRid or _rallyTeamInfo.rallyWaitTime <= os.time() ) then
            -- 角色部队返回
            if _rallyTeamInfo.rallyWaitArmyInfo[_exitRid] then
                if _rallyTeamInfo.rallyWaitArmyInfo[_exitRid].arrivalTime > os.time() then
                    objectIndex = _rallyTeamInfo.rallyWaitArmyInfo[_exitRid].objectIndex
                end
            end
            local fpos = RoleLogic:getRole( _rid, Enum.Role.pos )
            if _rallyTeamPos then
                fpos = _rallyTeamPos
            end
            if not objectIndex or objectIndex <= 0 then
                -- 生成一个新的对象ID
                objectIndex = Common.newMapObjectIndex()
                local roleInfo = RoleLogic:getRole( _exitRid, { Enum.Role.pos } )
                local cityIndex = RoleLogic:getRoleCityIndex( _exitRid )
                local path = { fpos, roleInfo.pos }
                local armyInfo = ArmyLogic:getArmy( _exitRid, armyIndex )
                if armyInfo and not table.empty(armyInfo) then
                    if _isDefeat then
                        armyInfo.status = Enum.ArmyStatus.FAILED_MARCH
                    else
                        armyInfo.status = Enum.ArmyStatus.RETREAT_MARCH
                    end
                    -- 计算掠夺资源分配
                    if _allPlunderResource and _armyLoadAtPlunder and _armyLoadAtPlunder > 0 then
                        local armyCount = ArmyLogic:getArmySoldierCount( armyInfo.soldiers )
                        armyInfo.food = math.floor( _allPlunderResource.food * armyCount / _armyLoadAtPlunder )
                        armyInfo.wood = math.floor( _allPlunderResource.wood * armyCount / _armyLoadAtPlunder )
                        armyInfo.stone = math.floor( _allPlunderResource.stone * armyCount / _armyLoadAtPlunder )
                        armyInfo.gold = math.floor( _allPlunderResource.gold * armyCount / _armyLoadAtPlunder )
                    end
                    -- 行军部队加入地图
                    local isOutCity = _rallyTeamInfo.rallyObjectIndex <= 0
                    MSM.MapMarchMgr[objectIndex].req.armyEnterMap( _exitRid, objectIndex, armyInfo, path,
                                                                    Enum.MapMarchTargetType.RETREAT, cityIndex, isOutCity, _isDefeat )
                else
                    LOG_ERROR("exitRallyTeam but not found army, rid(%s) armyIndex(%s)", tostring(_exitRid), tostring(armyIndex))
                end
                -- 修改为不在集结部队中
                ArmyLogic:updateArmyInfo( _exitRid, armyIndex, { [Enum.Army.isInRally] = false }, true )
            else
                -- 部队回城
                MSM.MapMarchMgr[objectIndex].req.marchBackCity( _exitRid, objectIndex, _isDefeat, true )
            end
        else
            -- 发起集结者的部队,直接解散(此时集结队伍还没出发)
            if not _forceMoveCity then
                ArmyLogic:disbandArmy( _rid, armyIndex )
            end
        end

        -- 清理集结信息
        _rallyTeamInfo.rallyArmy[_exitRid] = nil
        _rallyTeamInfo.rallyWaitArmyInfo[_exitRid] = nil

        -- 重新计算集结等待时间
        for _, waitInfo in pairs(_rallyTeamInfo.rallyWaitArmyInfo) do
            _rallyTeamInfo.rallyWaitTime = _rallyTeamInfo.rallyReadyTime
            if waitInfo.arrivalTime > _rallyTeamInfo.rallyWaitTime then
                _rallyTeamInfo.rallyWaitTime = waitInfo.arrivalTime
            end
        end
        return true
    end
end

---@see 通知被集结目标联盟被集结
function RallyLogic:notifyGuildRallyed( _rid, _targetIndex, _targetType )
    local notifyArg = {}
    local opType
    local onlineMembers
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    local guildInfo = GuildLogic:getGuild( guildId, { Enum.Guild.abbreviationName, Enum.Guild.signs } )
    local targetInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
    for _, signId in pairs(guildInfo.signs) do
        table.insert( notifyArg, tostring(signId) )
    end
    table.insert( notifyArg, guildInfo.abbreviationName )
    if not targetInfo.guildId or targetInfo.guildId <= 0 then
        if _targetType == Enum.RoleType.CITY then
            table.insert( notifyArg, targetInfo.name )
            -- 集结的是无联盟的城市
            GuildLogic:guildNotify( { targetInfo.rid }, Enum.GuildNotify.CITY_RALLYED, nil, nil, notifyArg )
        end
        return
    end
    if _targetType == Enum.RoleType.CITY then
        -- 对敌方城市发起集结
        opType = Enum.GuildNotify.CITY_RALLYED
        table.insert( notifyArg, targetInfo.name )
    elseif MapObjectLogic:checkIsGuildBuildObject( _targetType ) then
        -- 联盟建筑
        opType = Enum.GuildNotify.GUILD_BUILD_RALLYED
        table.insert( notifyArg, tostring(_targetType) )
    elseif MapObjectLogic:checkIsHolyLandObject( _targetType ) then
        -- 圣地建筑
        opType = Enum.GuildNotify.HOLY_LAND_RALLYED
        table.insert( notifyArg, tostring(targetInfo.strongHoldId) )
    end

    if targetInfo.guildId > 0 then
        onlineMembers = GuildLogic:getAllOnlineMember( targetInfo.guildId )
    end

    -- 通知在线成员
    if opType then
        if onlineMembers then
            GuildLogic:guildNotify( onlineMembers, opType, nil, nil, notifyArg )
        end
    end
end

---@see 通知联盟发起集结
function RallyLogic:notifyGuildRally( _rid, _guildId, _targetIndex, _targetType, _rallyTimes )
    -- 连通通知
    local onlineMembers = GuildLogic:getAllOnlineMember( _guildId )
    local name = RoleLogic:getRole( _rid, Enum.Role.name )
    local notifyArg = { name }
    local opType, guildName
    if _targetType == Enum.RoleType.CITY then
        -- 对敌方城市发起集结
        local cityInfo = MSM.SceneCityMgr[_targetIndex].req.getCityInfo( _targetIndex )
        local guildId = RoleLogic:getRole( cityInfo.rid, Enum.Role.guildId )
        guildName = GuildLogic:getGuild( guildId, Enum.Guild.abbreviationName )
        table.insert( notifyArg, guildName )
        table.insert( notifyArg, cityInfo.name )
        opType = Enum.GuildNotify.RALLY_CITY
    elseif _targetType == Enum.RoleType.ARMY then
        -- 对敌方部队发起集结
        local armyInfo = MSM.SceneArmyMgr[_targetIndex].req.getArmyInfo( _targetIndex )
        table.insert( notifyArg, RoleLogic:getRole( armyInfo.rid, Enum.Role.name ) )
        opType = Enum.GuildNotify.RALLY_ARMY
        guildName = GuildLogic:getGuild( armyInfo.guildId, Enum.Guild.name )
        table.insert( notifyArg, guildName )
    elseif _targetType == Enum.RoleType.MONSTER_CITY then
        -- 对野蛮人城寨发起集结
        opType = Enum.GuildNotify.RALLY_MONSTER_CITY
        local monsterCityInfo = MSM.SceneMonsterCityMgr[_targetIndex].req.getMonsterCityInfo( _targetIndex )
        table.insert( notifyArg, tostring(monsterCityInfo.monsterId) )
    elseif _targetType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 对召唤怪物发起集结optype与城寨一致
        opType = Enum.GuildNotify.RALLY_MONSTER_CITY
        local monsterInfo = MSM.SceneMonsterMgr[_targetIndex].req.getMonsterInfo( _targetIndex )
        table.insert( notifyArg, tostring(monsterInfo.monsterId) )
    elseif MapObjectLogic:checkIsGuildBuildObject( _targetType ) then
        -- 联盟建筑
        opType = Enum.GuildNotify.RALLY_GUILD_BUILD
        guildName = GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName )
        notifyArg = {}
        table.insert( notifyArg, guildName )
        local targetGuildId = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectGuildId( _targetIndex )
        local targetGuildName = GuildLogic:getGuild( targetGuildId, Enum.Guild.abbreviationName )
        table.insert( notifyArg, targetGuildName )
        table.insert( notifyArg, tostring(_targetType) )
    elseif MapObjectLogic:checkIsHolyLandObject( _targetType ) then
        -- 圣地建筑
        local holyLandInfo = MSM.SceneHolyLandMgr[_targetIndex].req.getHolyLandInfo( _targetIndex )
        if holyLandInfo.holyLandStatus == Enum.HolyLandStatus.INIT_PROTECT
        or holyLandInfo.holyLandStatus == Enum.HolyLandStatus.INIT_SCRAMBLE then
            -- 未被其他联盟占领
            guildName = GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName )
            notifyArg = {}
            table.insert( notifyArg, guildName )
            table.insert( notifyArg, tostring( holyLandInfo.holyLandType ) )
            opType = Enum.GuildNotify.RALLY_NO_GUILD_HOLY_LAND
        else
            -- 被其他联盟占领
            guildName = GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName )
            notifyArg = {}
            table.insert( notifyArg, guildName )
            local targetGuildId = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectGuildId( _targetIndex )
            local targetGuildName = GuildLogic:getGuild( targetGuildId, Enum.Guild.abbreviationName )
            table.insert( notifyArg, targetGuildName )
            table.insert( notifyArg, tostring( holyLandInfo.holyLandType ) )
            opType = Enum.GuildNotify.RALLY_GUILD_HOLY_LAND
        end
    end

    -- 通知在线成员
    if opType then
        GuildLogic:guildNotify( onlineMembers, opType, nil, nil, notifyArg )
        -- 推送所有成员
        local members = GuildLogic:getAllNotOnlineMember( _guildId )
        local abbreviationName = GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName )
        for _, rid in pairs( members ) do
            SM.PushMgr.post.sendPush( { pushRid = rid, pushType = Enum.PushType.RALLY, args = { arg1 = abbreviationName, arg2 = _rallyTimes } })
        end
    end
end

---@see 通知联盟取消集结
---@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:notifyGuildCancleRally( _rid, _guildId, _rallyTeamInfo, _endExit )
    local onlineMembers = GuildLogic:getAllOnlineMember( _guildId )
    if not _endExit then
        -- 通知在线成员
        GuildLogic:guildNotify( onlineMembers, Enum.GuildNotify.CANCLE_RALLY, nil, nil, { RoleLogic:getRole( _rid, Enum.Role.name ) } )
    end
    -- 通知联盟战争信息
    local rallyTargetGuildId = _rallyTeamInfo.rallyTargetGuildId
    local targetIndex = _rallyTeamInfo.rallyTargetIndex

    -- 通知联盟战争,集结队伍解散
    self:syncRallyDelete( _rid, _guildId, rallyTargetGuildId, targetIndex )
end

---@see 生成加入集结者信息
---@param _rallyTeam defaultRallyTeamClass
function RallyLogic:getJoinRallyDetail( _rid, _rallyTeam )
    local joinRallyDetail = {}
    local joinRoleInfo
    for joinRid, joinArmyIndex in pairs(_rallyTeam.rallyArmy) do
        local armyInfo = ArmyLogic:getArmy( joinRid, joinArmyIndex )
        joinRoleInfo = RoleLogic:getRole( joinRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.pos } )
        local joinTime, joinArrivalTime
        if _rallyTeam.rallyWaitArmyInfo and _rallyTeam.rallyWaitArmyInfo[joinRid] then
            joinTime = _rallyTeam.rallyWaitArmyInfo[joinRid].joinTime
            joinArrivalTime = _rallyTeam.rallyWaitArmyInfo[joinRid].arrivalTime
        end

        table.insert( joinRallyDetail, {
            joinRid = joinRid,
            joinName = joinRoleInfo.name,
            joinHeadId = joinRoleInfo.headId,
            joinHeadFrameId = joinRoleInfo.headFrameID,
            joinPos = joinRoleInfo.pos,
            joinMainHeroId = armyInfo.mainHeroId,
            joinDeputyHeroId = armyInfo.deputyHeroId,
            joinSoldiers = armyInfo.soldiers,
            joinTime = joinTime,
            joinArrivalTime = joinArrivalTime,
            joinArmyIndex = joinArmyIndex,
            joinMainHeroLevel = armyInfo.mainHeroLevel,
            joinDeputyHeroLevel = armyInfo.deputyHeroLevel
        })
    end

    return joinRallyDetail
end

---@see 获取集结者信息
function RallyLogic:getRallyDetail( _rallyRids )
    local rallyDetails = {}
    if not _rallyRids then
        return rallyDetails
    end
    local roleInfo
    ---@type defaultRallyTeamClass
    local rallyTeamInfo
    for _, rid in pairs(_rallyRids) do
        roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.pos } )
        rallyTeamInfo = MSM.RallyMgr[roleInfo.guildId].req.getRallyTeamInfo( roleInfo.guildId, rid )
        if rallyTeamInfo then
            -- 计算集结着部队信息
            rallyTeamInfo.rallyArmyCountMax = self:getRallyArmyMax( rallyTeamInfo.rallyRid, rallyTeamInfo )
            rallyTeamInfo.rallyArmyCount = self:getRallyArmyCount( rallyTeamInfo )
            rallyTeamInfo.rallyGuildName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
            rallyTeamInfo.rallyName = roleInfo.name
            rallyTeamInfo.rallyHeadId = roleInfo.headId
            rallyTeamInfo.rallyHeadFrameId = roleInfo.headFrameID
            rallyTeamInfo.rallyPos = roleInfo.pos
            rallyDetails[rallyTeamInfo.rallyRid] = rallyTeamInfo
        end
    end

    return rallyDetails
end

---@see 获取增援者信息
function RallyLogic:getReinforceDetail( _rid, _reinforceRids )
    local reinforceDetails = {}
    if not _reinforceRids then
        return reinforceDetails
    end
    local reinforceTeam
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    for _, reinforceRid in pairs(_reinforceRids) do
        reinforceTeam = MSM.RallyMgr[guildId].req.getReinforceTeamInfo( guildId, _rid, reinforceRid )
        table.insert( reinforceDetails, reinforceTeam )
    end

    return reinforceDetails
end

---@see 获取被集结者增援信息
function RallyLogic:getRallyTargetReinforceDetail( _rallyedType, _rallyedRid )
    if _rallyedType == Enum.RoleType.CITY then
        local reinforces = RoleLogic:getRole( _rallyedRid, Enum.Role.reinforces )
        for reinforceRid, reinforceInfo in pairs(reinforces) do
            local roleInfo = RoleLogic:getRole( reinforceRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
            reinforceInfo.reinforceName = roleInfo.name
            reinforceInfo.reinforceHeadId = roleInfo.headId
            reinforceInfo.reinforceHeadFrameId = roleInfo.headFrameID
        end
        return table.values( reinforces )
    end
end

---@see 获取被集结目标信息
function RallyLogic:getRallyTargetDetail( _targetObjectIndex )
    local targetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
    if targetObjectInfo then
        local defaultRallyTarget = RallyDef:getDefaultRallyTarget()
        defaultRallyTarget.rallyTargetType = targetObjectInfo.objectType
        defaultRallyTarget.rallyTargetObjectIndex = _targetObjectIndex
        if targetObjectInfo.objectType == Enum.RoleType.CITY or targetObjectInfo.objectType == Enum.RoleType.ARMY then
            -- 城市和部队,取玩家的信息
            local roleInfo = RoleLogic:getRole( targetObjectInfo.rid, { Enum.Role.name, Enum.Role.headId, Enum.Role.pos, Enum.Role.guildId, Enum.Role.headFrameID } )
            defaultRallyTarget.rallyTargetName = roleInfo.name
            defaultRallyTarget.rallyTargetHeadId = roleInfo.headId
            defaultRallyTarget.rallyTargetHeadFrameId = roleInfo.headFrameID
            defaultRallyTarget.rallyTargetPos = roleInfo.pos
            if roleInfo.guildId and roleInfo.guildId > 0 then
                local guildInfo = GuildLogic:getGuild( roleInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.name } )
                defaultRallyTarget.rallyTargetGuildName = guildInfo.abbreviationName
            end
        elseif MapObjectLogic:checkIsGuildFortressObject( targetObjectInfo.objectType )
        or targetObjectInfo.objectType == Enum.RoleType.GUILD_FLAG then
            -- 联盟要塞、联盟旗帜
            local guildBuildInfo = MSM.SceneGuildBuildMgr[_targetObjectIndex].req.getGuildBuildInfo( _targetObjectIndex )
            defaultRallyTarget.rallyTargetPos = guildBuildInfo.pos
            if guildBuildInfo.guildId and guildBuildInfo.guildId > 0 then
                local guildInfo = GuildLogic:getGuild( guildBuildInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.name } )
                defaultRallyTarget.rallyTargetGuildName = guildInfo.abbreviationName
            end
        elseif targetObjectInfo.objectType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨
            local monsterCityInfo = MSM.SceneMonsterCityMgr[_targetObjectIndex].req.getMonsterCityInfo( _targetObjectIndex )
            defaultRallyTarget.rallyTargetPos = monsterCityInfo.pos
            defaultRallyTarget.rallyTargetMonsterId = monsterCityInfo.monsterId
        elseif MapObjectLogic:checkIsHolyLandObject( targetObjectInfo.objectType ) then
            -- 圣地建筑
            local holyLandInfo = MSM.SceneHolyLandMgr[_targetObjectIndex].req.getHolyLandInfo( _targetObjectIndex )
            defaultRallyTarget.rallyTargetPos = holyLandInfo.pos
            defaultRallyTarget.rallyTargetHolyLandId = holyLandInfo.strongHoldId
            if holyLandInfo.guildId and holyLandInfo.guildId > 0 then
                local guildInfo = GuildLogic:getGuild( holyLandInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.name } )
                defaultRallyTarget.rallyTargetGuildName = guildInfo.abbreviationName
            end
        elseif targetObjectInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 召唤怪物
            local monsterInfo = MSM.SceneMonsterMgr[_targetObjectIndex].req.getMonsterInfo( _targetObjectIndex )
            defaultRallyTarget.rallyTargetPos = monsterInfo.pos
            defaultRallyTarget.rallyTargetMonsterId = monsterInfo.monsterId
        end

        return defaultRallyTarget
    end
end

---@see 推送联盟战争信息
function RallyLogic:pushGuildRallyInfo( _rid )
    local roleInfo
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if guildId <= 0 then
        return
    end
    -- 获取联盟集结信息
    ---@type table<int, defaultRallyTeamClass>
    local guildRallyInfo = MSM.RallyMgr[guildId].req.getGuildRallyInfo( guildId )
    local rallyDetails = {}
    if guildRallyInfo then
        for _, rallyInfo in pairs(guildRallyInfo) do
            roleInfo = RoleLogic:getRole( rallyInfo.rallyRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.pos } )
            table.insert( rallyDetails, {
                rallyRid = rallyInfo.rallyRid,
                rallyName = roleInfo.name,
                rallyHeadId = roleInfo.headId,
                rallyHeadFrameId = roleInfo.headFrameID,
                rallyPos = roleInfo.pos,
                rallyArmyCountMax = self:getRallyArmyMax( rallyInfo.rallyRid, rallyInfo ),
                rallyArmyCount = self:getRallyArmyCount( rallyInfo ),
                rallyGuildName = GuildLogic:getGuild( guildId, Enum.Guild.abbreviationName ),
                rallyReadyTime = rallyInfo.rallyReadyTime,
                rallyWaitTime = rallyInfo.rallyWaitTime,
                rallyMarchTime = rallyInfo.rallyMarchTime,
                rallyStartTime = rallyInfo.rallyStartTime,
                rallyPath = rallyInfo.rallyPath,
                rallyJoinDetail = self:getJoinRallyDetail( rallyInfo.rallyRid, rallyInfo ),
                rallyTargetDetail = self:getRallyTargetDetail( rallyInfo.rallyTargetIndex ),
                rallyReinforceDetail = rallyInfo.rallyReinforce,
                rallyObjectIndex = rallyInfo.rallyObjectIndex
            })
        end
    end

    --- 获取联盟被集结信息
    local rallyedDetail = {}
    local targetObjectInfo
    ---@type defaultGuildRallyedClass
    local guildRallyedInfo = SM.RallyTargetMgr.req.getGuildRallyedInfo( guildId )
    if guildRallyedInfo then
        local rallyedReinforceMax
        for beRallyIndex in pairs(guildRallyedInfo.rally) do
            targetObjectInfo = MSM.MapObjectTypeMgr[beRallyIndex].req.getObjectInfo( beRallyIndex )
            if targetObjectInfo then
                if targetObjectInfo.rid then
                    roleInfo = RoleLogic:getRole( targetObjectInfo.rid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
                else
                    roleInfo = {}
                end

                local rallyTargetHolyLandId, reinforceDetail
                local rallyedType = targetObjectInfo.objectType
                if targetObjectInfo.objectType == Enum.RoleType.CITY then
                    rallyedReinforceMax = CityReinforceLogic:getMaxCityReinforce( targetObjectInfo.rid )
                    -- 增援者信息
                    reinforceDetail = self:getRallyTargetReinforceDetail( targetObjectInfo.objectType, targetObjectInfo.rid )
                elseif MapObjectLogic:checkIsGuildBuildObject( targetObjectInfo.objectType ) then
                    -- 联盟建筑
                    rallyedReinforceMax = targetObjectInfo.armyCntLimit
                    reinforceDetail = GuildBuildLogic:getGuildBuildReinforceInfo( guildId, beRallyIndex )
                elseif MapObjectLogic:checkIsHolyLandObject( targetObjectInfo.objectType ) then
                    -- 圣地建筑
                    reinforceDetail = HolyLandLogic:getHolyLandReinforceInfo( beRallyIndex )
                    rallyedReinforceMax = targetObjectInfo.armyCntLimit
                    rallyTargetHolyLandId = targetObjectInfo.strongHoldId
                    rallyedType = MapObjectLogic:getRealHolyLandType( targetObjectInfo.strongHoldId, targetObjectInfo.holyLandStatus, true )
                end
                table.insert( rallyedDetail, {
                    rallyedIndex = beRallyIndex,
                    rallyedName = roleInfo.name,
                    rallyedHeadId = roleInfo.headId,
                    rallyedHeadFrameId = roleInfo.headFrameID,
                    rallyedPos = targetObjectInfo.pos,
                    rallyDetail = self:getRallyDetail( guildRallyedInfo.rally[beRallyIndex] ), -- 集结者信息
                    reinforceDetail = reinforceDetail, -- 增援者信息
                    rallyedReinforceMax = rallyedReinforceMax,
                    rallyTargetHolyLandId = rallyTargetHolyLandId,
                    rallyedType = rallyedType
                })
            end
        end
    end

    -- 推送
    if not table.empty(rallyDetails) or not table.empty(rallyedDetail) then
        if table.empty(rallyDetails) then
            rallyDetails = nil
        end
        if table.empty(rallyedDetail) then
            rallyedDetail = nil
        end
        Common.syncMsg( _rid, "Rally_RallyBattleInfo", {
            rallyDetails = rallyDetails,
            rallyedDetail = rallyedDetail,
        } )
    end
end

---@see 同步新增联盟集结信息
---@param _rallyInfo defaultRallyTeamClass
function RallyLogic:syncGuildRallyInfo( _rid, _guildId, _rallyInfo )
    -- 向集结公会推送集结信息
    local rallyDetails = {}
    local roleInfo = RoleLogic:getRole( _rallyInfo.rallyRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.pos } )
    table.insert( rallyDetails, {
        rallyRid = _rallyInfo.rallyRid,
        rallyName = roleInfo.name,
        rallyHeadId = roleInfo.headId,
        rallyHeadFrameId = roleInfo.headFrameID,
        rallyPos = roleInfo.pos,
        rallyArmyCountMax = self:getRallyArmyMax( _rallyInfo.rallyRid, _rallyInfo ),
        rallyArmyCount = self:getRallyArmyCount( _rallyInfo ),
        rallyGuildName = GuildLogic:getGuild( _guildId, Enum.Guild.abbreviationName ),
        rallyReadyTime = _rallyInfo.rallyReadyTime,
        rallyWaitTime = _rallyInfo.rallyWaitTime,
        rallyStartTime = _rallyInfo.rallyStartTime,
        rallyJoinDetail = self:getJoinRallyDetail( _rid, _rallyInfo ),
        rallyTargetDetail = self:getRallyTargetDetail( _rallyInfo.rallyTargetIndex )
    })

    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = rallyDetails
    } )

    local rallyTargetType = _rallyInfo.rallyTargetType
    local rallyTargetIndex = _rallyInfo.rallyTargetIndex
    -- 向被集结联盟推送被集结信息
    local rallyedDetail = {}
    local targetObjectInfo = MSM.MapObjectTypeMgr[rallyTargetIndex].req.getObjectInfo( rallyTargetIndex )
    if not targetObjectInfo or not targetObjectInfo.guildId then
        -- 无联盟,不推送
        return
    end
    local targetRoleInfo = {}
    local reinforceDetail, rallyedReinforceMax, rallyTargetHolyLandId
    if rallyTargetType == Enum.RoleType.ARMY or rallyTargetType == Enum.RoleType.CITY then
        targetRoleInfo = RoleLogic:getRole( targetObjectInfo.rid, { Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.pos } )
        if rallyTargetType == Enum.RoleType.CITY then
            -- 增援者信息
            reinforceDetail = self:getRallyTargetReinforceDetail( targetObjectInfo.objectType, targetObjectInfo.rid )
            -- 最大增援容量
            rallyedReinforceMax = CityReinforceLogic:getMaxCityReinforce( targetObjectInfo.rid )
        end
    elseif MapObjectLogic:checkIsHolyLandObject( rallyTargetType ) then
        -- 集结圣地
        rallyTargetType = MapObjectLogic:getRealHolyLandType( targetObjectInfo.strongHoldId, targetObjectInfo.holyLandStatus, true )
        rallyTargetHolyLandId = targetObjectInfo.strongHoldId
        rallyedReinforceMax = targetObjectInfo.armyCntLimit
        -- 获取圣地增援信息
        reinforceDetail = HolyLandLogic:getHolyLandReinforceInfo( rallyTargetIndex )
    elseif MapObjectLogic:checkIsGuildBuildObject( rallyTargetType ) then
        -- 联盟建筑
        rallyedReinforceMax = targetObjectInfo.armyCntLimit
        -- 获取联盟建筑增援信息
        reinforceDetail = GuildBuildLogic:getGuildBuildReinforceInfo( targetObjectInfo.guildId, rallyTargetIndex )
    end

    -- 生成信息
    table.insert( rallyedDetail, {
        rallyedIndex = _rallyInfo.rallyTargetIndex,
        rallyedName = targetRoleInfo.name,
        rallyedHeadId = targetRoleInfo.headId,
        rallyedHeadFrameId = targetRoleInfo.headFrameID,
        rallyedPos = targetObjectInfo.pos,
        rallyDetail = self:getRallyDetail( { _rid } ), -- 集结者信息
        reinforceDetail = reinforceDetail,
        rallyedReinforceMax = rallyedReinforceMax,
        rallyedType = rallyTargetType,
        rallyTargetHolyLandId = rallyTargetHolyLandId,
    })

    -- 获取在线成员
    onlineMemberRids = GuildLogic:getAllOnlineMember( targetObjectInfo.guildId )
    -- 推送
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyedDetail = rallyedDetail
    } )
end

---@see 同步联盟战争加入集结
---@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:syncJoinRally( _rid, _guildId, _rallyTargetIndex, _rallyRid, _rallyTeamInfo )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                rallyRid = _rid,
                rallyJoinDetail = self:getJoinRallyDetail( _rallyRid, _rallyTeamInfo ),
                rallyArmyCountMax = self:getRallyArmyMax( _rallyTeamInfo.rallyRid, _rallyTeamInfo ),
                rallyArmyCount = self:getRallyArmyCount( _rallyTeamInfo ),
            }
        }
    } )

    -- 推送给被集结公会
    if _rallyTeamInfo.rallyTargetGuildId and _rallyTeamInfo.rallyTargetGuildId > 0 then
        onlineMemberRids = GuildLogic:getAllOnlineMember( _rallyTeamInfo.rallyTargetGuildId )
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                    [_rallyTargetIndex] = {
                                            rallyedIndex = _rallyTargetIndex,
                                            rallyDetail = self:getRallyDetail( { _rid } )
                    }
            }
        } )
    end
end

---@see 同步联盟战争取消加入集结
---@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:syncCancleJoinRally( _rid, _guildId, _rallyTargetIndex, _joinRid, _rallyTargetGuildId, _rallyTeamInfo )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                rallyRid = _rid,
                rallyJoinDetail = {
                    [_joinRid] = {
                        joinRid = _joinRid,
                        joinDelete = true,
                    }
                },
                rallyArmyCountMax = self:getRallyArmyMax( _rallyTeamInfo.rallyRid, _rallyTeamInfo ),
                rallyArmyCount = self:getRallyArmyCount( _rallyTeamInfo ),
            }
        }
    } )

    -- 推送给被集结公会
    if _rallyTargetGuildId and _rallyTargetGuildId > 0 then
        onlineMemberRids = GuildLogic:getAllOnlineMember( _rallyTargetGuildId )
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                    [_rallyTargetIndex] = {
                                            rallyedIndex = _rallyTargetIndex,
                                            rallyDetail = {
                                                [_rid] = {
                                                    rallyRid = _rid,
                                                    rallyJoinDetail = {
                                                        [_joinRid] = {
                                                            rallyDelete = true,
                                                            joinRid = _joinRid
                                                        }
                                                    }
                                                }
                                            }
                    }
            }
        } )
    end
end

---@see 更新联盟集结队伍行军到达时间
function RallyLogic:syncGuildRallyMarchTime( _rid, _guildId, _rallyMarchTime, _rallyPath, _rallyTargetGuildId, _rallyTargetIndex, _rallyObjectIndex )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                        rallyRid = _rid,
                        rallyMarchTime = _rallyMarchTime,
                        rallyObjectIndex = _rallyObjectIndex,
                        rallyPath = _rallyPath
            }
        }
    } )

    -- 推送给被集结公会
    if _rallyTargetGuildId and _rallyTargetGuildId > 0 then
        onlineMemberRids = GuildLogic:getAllOnlineMember( _rallyTargetGuildId )
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                    [_rallyTargetIndex] = {
                                            rallyedIndex = _rallyTargetIndex,
                                            rallyDetail = {
                                                [_rid] = {
                                                    rallyRid = _rid,
                                                    rallyMarchTime = _rallyMarchTime,
                                                    rallyObjectIndex = _rallyObjectIndex
                                                }
                                            }
                    }
            }
        } )
    end
end

---@see 更新联盟集结队伍集结等待时间
function RallyLogic:syncGuildRallyWaitTime( _rid, _guildId, _rallyWaitTime, _rallyTargetGuildId, _rallyTargetIndex )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = { rallyRid = _rid, rallyWaitTime = _rallyWaitTime }
        }
    } )

    -- 推送给被集结公会
    if _rallyTargetGuildId and _rallyTargetGuildId > 0 then
        onlineMemberRids = GuildLogic:getAllOnlineMember( _rallyTargetGuildId )
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                    [_rallyTargetIndex] = {
                    rallyedIndex = _rallyTargetIndex,
                    rallyDetail = {
                        [_rid] = {
                            rallyRid = _rid,
                            rallyWaitTime = _rallyWaitTime
                        }
                    }
                }
            }
        } )
    end
end

---@see 集结队伍删除.通知公会
function RallyLogic:syncRallyDelete( _rid, _guildId, _rallyTargetGuildId, _rallyTargetIndex )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = { rallyRid = _rid, rallyDelete = true }
        }
    } )

    -- 推送给被集结公会
    if _rallyTargetGuildId and _rallyTargetGuildId > 0 then
        onlineMemberRids = GuildLogic:getAllOnlineMember( _rallyTargetGuildId )
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                [_rallyTargetIndex] = {
                    rallyedIndex = _rallyTargetIndex,
                    rallyDetail = {
                        [_rid] = {
                            rallyRid = _rid,
                            rallyDelete = true
                        }
                    }
                }
            }
        } )
    end
end

---@see 增加集结部队增援信息
---@param _rallyTeamInfo defaultRallyTeamClass
function RallyLogic:syncRallyAddReinforce( _rid, _guildId, _reinforceRid )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    local rallyReinforceDetail = self:getReinforceDetail( _rid, { _reinforceRid } )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                        rallyRid = _rid,
                        rallyReinforceDetail = rallyReinforceDetail
                    }
        }
    } )
end

---@see 移除集结部队增援信息
function RallyLogic:syncRallyDeleteReinforce( _rid, _guildId, _reinforceRid, _reinforceArmyIndex )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                        rallyRid = _rid,
                        rallyReinforceDetail = {
                            [_reinforceRid] = {
                                reinforceRid = _reinforceRid,
                                reinforceDelete = true,
                                armyIndex = _reinforceArmyIndex
                            }
                        }
                    }
        }
    } )
end

---@see 增加被集结者增援信息
---@param _reinforceInfo defaultReinforceCityClass
function RallyLogic:addRallyedReinforceInfo( _targetIndex, _reinforceRid, _reinforces )
    local targetInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
    -- 判断目标是否被集结
    local targetGuildId
    if targetInfo.objectType == Enum.RoleType.ARMY or targetInfo.objectType == Enum.RoleType.CITY
    or MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
        targetGuildId = RoleLogic:getRole( targetInfo.rid, Enum.Role.guildId )
    end

    local isRally = SM.RallyTargetMgr.req.checkTargetIsRallyed( targetGuildId, _targetIndex )
    if isRally then
        local reinforces = table.copy(_reinforces, true)
        for reinforceRid, reinforceInfo in pairs(reinforces) do
            local roleInfo = RoleLogic:getRole( reinforceRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID } )
            reinforceInfo.reinforceName = roleInfo.name
            reinforceInfo.reinforceHeadId = roleInfo.headId
            reinforceInfo.reinforceHeadFrameId = roleInfo.headFrameID
        end
        local guildId = RoleLogic:getRole( _reinforceRid, Enum.Role.guildId )
        -- 获取公会在线成员
        local onlineMemberRids = GuildLogic:getAllOnlineMember( guildId )
        -- 推送给被集结公会
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                [_targetIndex] = {
                    rallyedIndex = _targetIndex,
                    reinforceDetail = table.values( reinforces )
                }
            }
        } )
    end
end

---@see 删除被集结者增援信息
function RallyLogic:delRallyedReinforceInfo( _targetIndex, _reinforceRid, _reinforceArmyIndex )
    local targetInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
    -- 判断目标是否被集结
    local targetGuildId
    if targetInfo.objectType == Enum.RoleType.ARMY or targetInfo.objectType == Enum.RoleType.CITY
    or MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
        targetGuildId = RoleLogic:getRole( targetInfo.rid, Enum.Role.guildId )
    end

    local isRally = SM.RallyTargetMgr.req.checkTargetIsRallyed( targetGuildId, _targetIndex )
    if isRally then
        local guildId = RoleLogic:getRole( _reinforceRid, Enum.Role.guildId )
        -- 获取公会在线成员
        local onlineMemberRids = GuildLogic:getAllOnlineMember( guildId )
        -- 推送给被集结公会
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                [_targetIndex] = {
                    rallyedIndex = _targetIndex,
                    reinforceDetail = {
                        [1] = {
                            reinforceRid = _reinforceRid,
                            reinforceDelete = true,
                            armyIndex = _reinforceArmyIndex,
                        }
                    }
                }
            }
        } )
    end
end

---@see 刷新增援达到时间
function RallyLogic:refreshReinforceArrivalTime( _rid, _guildId, _reinforceRid, _arrivalTime )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                        rallyRid = _rid,
                        rallyReinforceDetail = {
                            [_reinforceRid] = {
                                reinforceRid = _reinforceRid,
                                arrivalTime = _arrivalTime
                            }
                        }
                    }
        }
    } )
end

---@see 更新集结发起联盟角色名称头像和头像框
function RallyLogic:syncRallyGuildRoleInfo( _rid, _guildId, _rallyObjectIndex, _rallyName, _rallyHeadId, _rallyHeadFrameId, _rallyGuildName, _onlineMemberRids )
    -- 获取公会在线成员
    local onlineMemberRids = _onlineMemberRids or GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                rallyRid = _rid,
                rallyName = _rallyName,
                rallyObjectIndex = _rallyObjectIndex,
                rallyHeadId = _rallyHeadId,
                rallyHeadFrameId = _rallyHeadFrameId,
                rallyGuildName = _rallyGuildName,
                rallyJoinDetail = {
                    [_rid] = {
                        joinRid = _rid,
                        joinName = _rallyName,
                        joinHeadId = _rallyHeadId,
                        joinHeadFrameId = _rallyHeadFrameId,
                    }
                },
            }
        }
    } )
end

---@see 更新被集结联盟发起集结的角色名称等信息
function RallyLogic:syncRallyedGuildRoleInfo( _rid, _rallyTargetIndex, _rallyObjectIndex, _rallyName, _rallyHeadId, _rallyHeadFrameId, _rallyGuildName, _onlineMemberRids )
    -- 推送给被集结公会
    local targetGuildId = MSM.MapObjectTypeMgr[_rallyTargetIndex].req.getObjectGuildId( _rallyTargetIndex )
    if targetGuildId and targetGuildId > 0 then
        local onlineMemberRids = _onlineMemberRids or GuildLogic:getAllOnlineMember( targetGuildId )
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                [_rallyTargetIndex] = {
                    rallyedIndex = _rallyTargetIndex,
                    rallyDetail = {
                        [_rid] = {
                            rallyRid = _rid,
                            rallyName = _rallyName,
                            rallyHeadId = _rallyHeadId,
                            rallyHeadFrameId = _rallyHeadFrameId,
                            rallyObjectIndex = _rallyObjectIndex,
                            rallyGuildName = _rallyGuildName
                        }
                    }
                }
            }
        } )
    end
end

---@see 更新联盟战争加入集结角色名称头像等信息
function RallyLogic:syncJoinRallyRoleInfo( _rid, _guildId, _joinRid, _name, _headId, _headFrameId )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rid] = {
                rallyRid = _rid,
                rallyJoinDetail = {
                    [_joinRid] = {
                        joinRid = _joinRid,
                        joinName = _name,
                        joinHeadId = _headId,
                        joinHeadFrameId = _headFrameId,
                    }
                },
            }
        }
    } )
end

---@see 更新联盟战争增援角色名称头像等信息
function RallyLogic:syncReinforceRallyRoleInfo( _guildId, _rallyRid, _reinforceRid, _name, _headId, _headFrameId )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rallyRid] = {
                rallyRid = _rallyRid,
                rallyReinforceDetail = {
                    [_reinforceRid] = {
                        reinforceRid = _reinforceRid,
                        reinforceName = _name,
                        reinforceHeadId = _headId,
                        reinforceHeadFrameId = _headFrameId,
                    }
                }
            }
        }
    } )
end

---@see 更新被集结城市角色名称等信息
function RallyLogic:syncRallyedRoleCityInfo( _guildId, _objectIndex, _name, _headId, _headFrameId )
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
        -- 推送
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyedDetail = {
            [_objectIndex] = {
                rallyedIndex = _objectIndex,
                rallyedName = _name,
                rallyedHeadId = _headId,
                rallyedHeadFrameId = _headFrameId,
            }
        }
    } )
end

---@see 更新联盟集结城市名称等信息
function RallyLogic:syncGuildRallyRoleCityInfo( _guildId, _rallyRid, _rallyTargetDetail )
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rallyRid] = {
                rallyRid = _rallyRid,
                rallyTargetDetail = _rallyTargetDetail,
            }
        }
    } )
end

---@see 角色名称头像头像框属性变化更新集结队伍属性
function RallyLogic:syncRallyRoleInfo( _rid, _name, _headId, _headFrameId )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if guildId > 0 then
        -- 角色部队信息处理
        local rallyTeams = MSM.RallyMgr[guildId].req.getGuildRallyInfo( guildId ) or {}
        if rallyTeams[_rid] then
            -- 角色发起的集结
            local rallyTeam = rallyTeams[_rid]
            if _name then
                local targetArg
                if ( not rallyTeam.rallyObjectIndex or rallyTeam.rallyObjectIndex <= 0 ) then
                    -- 集结还未出发, 更新还未到集结点的部队目标名称
                    local rallyWaitArmyInfo = rallyTeam.rallyWaitArmyInfo or {}
                    for rallyRid, rallyArmyIndex in pairs( rallyTeam.rallyArmy ) do
                        if rallyWaitArmyInfo[rallyRid] then
                            targetArg = ArmyLogic:getArmy( rallyRid, rallyArmyIndex, Enum.Army.targetArg ) or {}
                            targetArg.targetName = _name
                            ArmyLogic:updateArmyInfo( rallyRid, rallyArmyIndex, { [Enum.Army.targetArg] = targetArg } )
                        end
                    end
                else
                    -- 集结已经出发, 更新增援的部队目标名称
                    for reinforceRid, reinforce in pairs( rallyTeam.rallyReinforce ) do
                        targetArg = ArmyLogic:getArmy( reinforceRid, reinforce.reinforceArmyIndex, Enum.Army.targetArg ) or {}
                        targetArg.targetName = _name
                        ArmyLogic:updateArmyInfo( reinforceRid, reinforce.reinforceArmyIndex, { [Enum.Army.targetArg] = targetArg } )
                    end
                end
            end
            -- 通知联盟战争界面信息
            self:syncRallyGuildRoleInfo( _rid, guildId, rallyTeam.rallyObjectIndex, _name, _headId, _headFrameId )
            -- 通知被集结联盟角色变化信息
            self:syncRallyedGuildRoleInfo( _rid, rallyTeam.rallyTargetIndex, rallyTeam.rallyObjectIndex, _name, _headId, _headFrameId )
        end

        -- 角色加入的集结信息
        for rallyRid, rallyTeam in pairs( rallyTeams ) do
            if rallyRid ~= _rid then
                if rallyTeam.rallyArmy[_rid] then
                    -- 加入集结
                    self:syncJoinRallyRoleInfo( rallyRid, guildId, _rid, _name, _headId, _headFrameId )
                elseif rallyTeam.rallyReinforce[_rid] then
                    -- 增援集结
                    MSM.RallyMgr[guildId].post.updateReinforceRoleInfo( guildId, rallyRid, _rid, _name, _headId, _headFrameId )
                end
            end
        end
    end

    -- 角色城市是否被集结
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local rallyInfos = SM.RallyTargetMgr.req.getRallyTargetInfo( cityIndex ) or {}
    local rallyTargetDetail = self:getRallyTargetDetail( cityIndex )
    for rallyGuildId, rallyRid in pairs( rallyInfos ) do
        -- 通知自己联盟的联盟战争
        if guildId > 0 then
            self:syncRallyedRoleCityInfo( guildId, cityIndex, _name, _headId, _headFrameId )
        end
        -- 通知发起集结联盟的联盟战争
        self:syncGuildRallyRoleCityInfo( rallyGuildId, rallyRid, rallyTargetDetail )
    end

    -- 角色部队增援的盟友城市被集结
    if guildId > 0 then
        local reinforces, reinforceDetail, onlineMemberRids
        local armys = ArmyLogic:getArmy( _rid ) or {}
        for armyIndex, armyInfo in pairs( armys ) do
            if ( ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH )
                or ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) )
                and armyInfo.reinforceRid and armyInfo.reinforceRid > 0 then
                -- 部队在增援行军中或驻守中且目标为城市
                reinforces = RoleLogic:getRole( armyInfo.reinforceRid, Enum.Role.reinforces ) or {}
                if reinforces[_rid] and reinforces[_rid].armyIndex == armyIndex then
                    cityIndex = RoleLogic:getRoleCityIndex( armyInfo.reinforceRid )
                    rallyInfos = SM.RallyTargetMgr.req.getRallyTargetInfo( cityIndex ) or {}
                    if not table.empty( rallyInfos ) then
                        reinforceDetail = self:getRallyTargetReinforceDetail( Enum.RoleType.CITY, armyInfo.reinforceRid )
                        onlineMemberRids = GuildLogic:getAllOnlineMember( guildId ) or {}
                        -- 推送给被集结公会
                        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
                            rallyedDetail = {
                                [cityIndex] = {
                                    rallyedIndex = cityIndex,
                                    reinforceDetail = reinforceDetail
                                }
                            }
                        } )
                    end
                end
            end
        end
    end
end

---@see 更新集结中的联盟简称信息
function RallyLogic:syncRallyGuildAbbName( _guildId, _guildAbbName )
    -- 更新联盟发起集结信息中的联盟简称
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    local rallyTeams = MSM.RallyMgr[_guildId].req.getGuildRallyInfo( _guildId ) or {}
    for rallyRid, rallyTeam in pairs( rallyTeams ) do
        -- 更新本联盟的集结信息
        self:syncRallyGuildRoleInfo( rallyRid, _guildId, rallyTeam.rallyObjectIndex, nil, nil, nil, _guildAbbName, onlineMemberRids )
        -- 更新对方联盟的被集结信息
        self:syncRallyedGuildRoleInfo( rallyRid, rallyTeam.rallyTargetIndex, rallyTeam.rallyObjectIndex, nil, nil, nil, _guildAbbName )
    end

    -- 更新联盟被集结信息中的联盟简称
    local rallyGuildId, rallyTargetDetail
    local guildRallys = SM.RallyTargetMgr.req.getGuildRallyedInfo( _guildId ) or {}
    for objectIndex, rallyRids in pairs( guildRallys.rally or {} ) do
        for _, rallyRid in pairs( rallyRids ) do
            rallyGuildId = RoleLogic:getRole( rallyRid, Enum.Role.guildId ) or 0
            if rallyGuildId > 0 then
                rallyTargetDetail = self:getRallyTargetDetail( objectIndex )
                -- 通知发起集结联盟的联盟战争
                self:syncGuildRallyRoleCityInfo( rallyGuildId, rallyRid, rallyTargetDetail )
            end
        end
    end
end

---@see 更新联盟战争增援角色名称头像等信息
function RallyLogic:syncReinforceRallyRoleSoldiers( _guildId, _rallyRid, _reinforceRid, _soldiers )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyDetails = {
            [_rallyRid] = {
                rallyRid = _rallyRid,
                rallyReinforceDetail = {
                    [_reinforceRid] = {
                        reinforceRid = _reinforceRid,
                        soldiers = _soldiers,
                    }
                },
            }
        }
    } )
end

---@see 更新加入集结部队士兵数量变化信息
function RallyLogic:syncRallyArmySoldiers( _guildId, _rallyRid, _rid, _soldiers )
    -- 获取公会在线成员
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    -- 推送给集结公会
    local rallyTeam = MSM.RallyMgr[_guildId].req.getRallyTeamInfo( _guildId, _rallyRid )
    if rallyTeam then
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyDetails = {
                [_rallyRid] = {
                    rallyRid = _rallyRid,
                    rallyJoinDetail = {
                        [_rid] = {
                            joinRid = _rid,
                            joinSoldiers = _soldiers,
                        }
                    },
                    rallyArmyCount = self:getRallyArmyCount( rallyTeam ),
                }
            }
        } )
    end
end

---@see 通知删除联盟被集结信息
function RallyLogic:syncDeleteRallyedInfo( _guildId, _rallyRid, _objectIndex )
    local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
    Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
        rallyedDetail = {
            [_objectIndex] = {
                rallyedIndex = _objectIndex,
                rallyDetail = {
                    [_rallyRid] = {
                        rallyRid = _rallyRid,
                        rallyDelete = true
                    }
                }
            }
        }
    } )
end

---@see 角色退出联盟被集结信息处理
function RallyLogic:checkRoleRallyedOnExitGuild( _rid, _oldGuildId )
    local rallyTargetDetail
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    -- 被集结切换
    SM.RallyTargetMgr.req.switchTargetGuild( cityIndex, _oldGuildId, 0 )
    -- 获取角色的被集结信息
    local rallyeds = SM.RallyTargetMgr.req.getRallyTargetInfo( cityIndex ) or {}
    for rallyGuildId, rallyRid in pairs( rallyeds ) do
        -- 通知发起集结的联盟
        rallyTargetDetail = self:getRallyTargetDetail( cityIndex )
        -- 通知发起集结联盟的联盟战争
        self:syncGuildRallyRoleCityInfo( rallyGuildId, rallyRid, rallyTargetDetail )
        -- 通知原联盟删除被集结信息
        self:syncDeleteRallyedInfo( _oldGuildId, rallyRid, cityIndex )
        -- 通知发起集结联盟的目标公会
        MSM.RallyMgr[rallyGuildId].post.updateTargetGuilId( rallyGuildId, rallyRid, 0 )
    end
end

---@see 角色加入联盟推送被集结信息
function RallyLogic:checkRoleRallyedOnJoinGuild( _rid, _guildId )
    local rallyRids = {}
    local targetType = Enum.RoleType.CITY
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local rallyTargetDetail = self:getRallyTargetDetail( cityIndex )
    -- 被集结切换
    SM.RallyTargetMgr.req.switchTargetGuild( cityIndex, 0, _guildId )
    -- 获取角色的被集结信息
    local rallyeds = SM.RallyTargetMgr.req.getRallyTargetInfo( cityIndex ) or {}
    for rallyGuildId, rallyRid in pairs( rallyeds ) do
        if rallyGuildId ~= _guildId then
            -- 通知发起集结联盟的联盟战争
            self:syncGuildRallyRoleCityInfo( rallyGuildId, rallyRid, rallyTargetDetail )
            -- 通知当前联盟增加被集结信息
            table.insert( rallyRids, rallyRid )
            -- 通知被集结目标联盟
            RallyLogic:notifyGuildRallyed( _rid, cityIndex, targetType )
            -- 通知发起集结联盟的目标公会
            MSM.RallyMgr[rallyGuildId].post.updateTargetGuilId( rallyGuildId, rallyRid, _guildId )
        else
            -- 同联盟,取消集结
            MSM.RallyMgr[rallyGuildId].req.disbandRallyArmy( rallyGuildId, rallyRid )
        end
    end

    if #rallyRids > 0 then
        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.pos } )
        local rallyedDetail = {
            [cityIndex] = {
                rallyedIndex = cityIndex,
                rallyedName = roleInfo.name,
                rallyedHeadId = roleInfo.headId,
                rallyedHeadFrameId = roleInfo.headFrameID,
                rallyedPos = roleInfo.pos,
                rallyDetail = self:getRallyDetail( rallyRids ),
                rallyedType = targetType,
                reinforceDetail = self:getRallyTargetReinforceDetail( Enum.RoleType.CITY, _rid ), -- 增援者信息
                rallyedReinforceMax = CityReinforceLogic:getMaxCityReinforce( _rid )
            }
        }
        -- 获取在线成员
        local onlineMemberRids = GuildLogic:getAllOnlineMember( _guildId )
        -- 推送
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = rallyedDetail
        } )
    end
end

---@see 角色迁城更新集结部队未出发的联盟战争信息
function RallyLogic:checkRoleRallyedOnMoveCity( _rid, _pos )
    -- 获取角色的被集结信息
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local rallyTargetDetail = self:getRallyTargetDetail( cityIndex )
    local rallyeds = SM.RallyTargetMgr.req.getRallyTargetInfo( cityIndex ) or {}
    for rallyGuildId, rallyRid in pairs( rallyeds ) do
        -- 通知发起集结的被集结者坐标信息
        self:syncGuildRallyRoleCityInfo( rallyGuildId, rallyRid, rallyTargetDetail )
    end
    -- 通知自己联盟被集结者坐标变化
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
    if guildId > 0 then
        local onlineMemberRids = GuildLogic:getAllOnlineMember( guildId )
        -- 推送
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                [cityIndex] = {
                    rallyedIndex = cityIndex,
                    rallyedPos = _pos
                }
            }
        } )
    end
end

return RallyLogic