--[[
 * @file : MapMarchMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2019-12-24 15:07:47
 * @Last Modified time: 2019-12-24 15:07:47
 * @department : Arabic Studio
 * @brief : 地图军队定时服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local math = math
local Timer = require "Timer"
local ArmyWalkLogic = require "ArmyWalkLogic"
local ArmyLogic = require "ArmyLogic"
local RoleLogic = require "RoleLogic"
local ScoutsLogic = require "ScoutsLogic"
local HeroLogic = require "HeroLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local TransportLogic = require "TransportLogic"
local EarlyWarningLogic = require "EarlyWarningLogic"
local DenseFogLogic = require "DenseFogLogic"
local MapObjectLogic = require "MapObjectLogic"
local CityReinforceLogic = require "CityReinforceLogic"
local ScoutFollowUpLogic = require "ScoutFollowUpLogic"
local RallyLogic = require "RallyLogic"
local ArmyDef = require "ArmyDef"
local timerCore = require "timer.core"
local CommonCacle = require "CommonCacle"
local Random = require "Random"
local MapLogic = require "MapLogic"
local LogLogic = require "LogLogic"

---@see 军队行走路径
---@type table<int, defaultArmyWalkClass>
local armyWalks = {}

function init()
    Timer.runEvery(100, ArmyWalkLogic.armyWalk, ArmyWalkLogic, armyWalks )
    LOG_INFO("init MapMarchMgr Timer")
end

---@see 军队加入地图.作为一个对象
---@param _rid integer 角色rid
---@param _armyInfo table 军队信息
---@param _path table 移动路径
---@param _marchType integer 行军类型
---@param _isOutCity boolean 是否出城
function response.armyEnterMap( _rid, _objectIndex, _armyInfo, _path, _marchType, _targetIndex, _isOutCity, _isDefeat, _isRally )
    local ftype
    if _isOutCity then
        ftype = Enum.RoleType.CITY
        _armyInfo.outBuild = true
    end

    -- 更新军队信息
    _armyInfo.rid = _rid
    _armyInfo.guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    _armyInfo.path = _path
    _armyInfo.targetObjectIndex = _targetIndex
    _armyInfo.objectIndex = _objectIndex
    _armyInfo.pos = _path[1]

    -- 添加军队主副将等级
    if _armyInfo.mainHeroId then
        _armyInfo.mainHeroLevel = HeroLogic:getHero( _rid, _armyInfo.mainHeroId, "level" )
    end
    if _armyInfo.deputyHeroId then
        _armyInfo.deputyHeroLevel = HeroLogic:getHero( _rid, _armyInfo.deputyHeroId, "level" )
    end

    -- 过滤已经过期的部队BUFF
    if _armyInfo.battleBuff then
        for index, buffInfo in pairs(_armyInfo.battleBuff) do
            if buffInfo.turn and buffInfo.turn > 0 then
                if buffInfo.turn + buffInfo.time <= os.time() then
                    _armyInfo.battleBuff[index] = nil
                end
            end
        end
    end

    -- 计算速度
    _armyInfo.talentAttr = HeroLogic:getHeroTalentAttr( _armyInfo.rid, _armyInfo.mainHeroId ).battleAttr
    _armyInfo.equipAttr = HeroLogic:getHeroEquipAttr( _armyInfo.rid, _armyInfo.mainHeroId ).battleAttr
    _armyInfo.isRally = _isRally
    _armyInfo.skills = HeroLogic:getRoleAllHeroSkills( _armyInfo.rid, _armyInfo.mainHeroId, _armyInfo.deputyHeroId )
    _armyInfo.speed = ArmyLogic:reCacleArmySpeed( _objectIndex, _armyInfo, true )

    -- 计算达到时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, _armyInfo.speed )
    _armyInfo.arrivalTime = arrivalTime
    _armyInfo.startTime = os.time()
    -- 部队半径
    _armyInfo.armyRadius = CommonCacle:getArmyRadius( _armyInfo.soldiers, _isRally )
    -- 移动部队
    arrivalTime = MSM.MapMarchMgr[_objectIndex].req.armyMove( _objectIndex, _targetIndex, _path[#_path],
                                                            _armyInfo.status, _marchType, ftype, true, _isDefeat, nil, _armyInfo )

    return arrivalTime, _objectIndex, _path
end

---@see 军队行军回城
function response.marchBackCity( _rid, _objectIndex, _isDefeat, _noCheckStatus )
    local armyStatus = Enum.ArmyStatus.RETREAT_MARCH
    if _isDefeat then
        armyStatus = Enum.ArmyStatus.FAILED_MARCH
        -- 清除部队旧目标处理
        local mapArmyInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
        if mapArmyInfo then
            ArmyLogic:checkArmyOldTarget( _rid, mapArmyInfo.armyIndex )
        end
    end
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local arrivalTime = MSM.MapMarchMgr[_objectIndex].req.armyMove( _objectIndex, cityIndex, nil, armyStatus,
                                            Enum.MapMarchTargetType.RETREAT, nil, nil, _isDefeat, nil, nil, _noCheckStatus )
    return arrivalTime
end

---@see 地图上军队移动到指定目标
---@param _objectIndex 军队对象索引
---@param _targetIndex 目标索引.非必填
---@param _pos 位置坐标.移动到空地时填
---@param _stationStatusOp 驻扎时状态参数
function response.armyMove( _objectIndex, _targetIndex, _pos, _armyStatus, _marchType, _ftype,
                            _isEnterMove, _isDefeat, _stationStatusOp, _armyInfo, _noCheckStatus, _noWarning )
    -- 部队信息
    local armyInfo = _armyInfo or MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
    if not armyInfo then
        LOG_ERROR("armyMove but not found armyInfo, armyIndex(%s)", tostring(_objectIndex))
        return
    end

    local isFollowUp = _marchType == Enum.MapMarchTargetType.FOLLOWUP
    -- 如果是集结部队,不能自由行军(除了追击)
    if not _isEnterMove and armyInfo.isRally and not isFollowUp then
        LOG_ERROR("armyMove but rally army cann't move, armyIndex(%s)", tostring(_objectIndex))
        return
    end

    -- 如果之前处于移动状态,修正位置
    if armyWalks[_objectIndex] then
        local pos = ArmyWalkLogic:cacleObjectNowPos( armyWalks[_objectIndex] )
        if pos then
            armyInfo.pos = pos
            -- 更新坐标
            MSM.SceneArmyMgr[_objectIndex].post.updateArmyObjectPos( _objectIndex, pos )
        end
        armyWalks[_objectIndex] = nil
    end

    -- 非追击移动,停止追击
    local oldTargetTypeInfo
    if not isFollowUp then
        MSM.SceneArmyMgr[_objectIndex].req.stopFollowUp( _objectIndex )
        if armyInfo.targetObjectIndex and armyInfo.targetObjectIndex > 0 then
            oldTargetTypeInfo = MSM.MapObjectTypeMgr[armyInfo.targetObjectIndex].req.getObjectInfo( armyInfo.targetObjectIndex )
        end
    end

    if not _isEnterMove and not isFollowUp and oldTargetTypeInfo and not _noCheckStatus then
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH ) then
            -- 增援行军,取消增援
            if oldTargetTypeInfo.objectType == Enum.RoleType.ARMY then
                local guildId = RoleLogic:getRole( oldTargetTypeInfo.rid, Enum.Role.guildId )
                if not MSM.RallyMgr[guildId].req.cacleReinforce( oldTargetTypeInfo.rid, armyInfo.rid ) then
                    LOG_ERROR("rid(%d) army reinforce targetRid(%d) arrival, can't armymove", armyInfo.rid, oldTargetTypeInfo.rid)
                    return
                end
            elseif oldTargetTypeInfo.objectType == Enum.RoleType.CITY then
                -- 原先向城市增援,取消
                CityReinforceLogic:cancleReinforceCity( oldTargetTypeInfo.rid, armyInfo.rid, true, _objectIndex )
            end
        elseif ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_JOIN_MARCH ) then
            -- 加入集结行军,取消加入集结
            local guildId = RoleLogic:getRole( oldTargetTypeInfo.rid, Enum.Role.guildId )
            if not MSM.RallyMgr[guildId].req.cacleJoinRally( oldTargetTypeInfo.rid, armyInfo.rid ) then
                LOG_ERROR("rid(%d) army joinRally targetRid(%d) arrival, can't armymove", armyInfo.rid, oldTargetTypeInfo.rid)
                return
            end
        end
    end

    -- 如果有行军目标,取消目标状态
    if oldTargetTypeInfo and not isFollowUp then
        if MapObjectLogic:checkIsResourceObject( oldTargetTypeInfo.objectType ) then
            -- 移除军队攻击资源点
            MSM.SceneResourceMgr[armyInfo.targetObjectIndex].post.armyNoAttackResource( armyInfo.targetObjectIndex, _objectIndex )
        elseif oldTargetTypeInfo.objectType == Enum.RoleType.RUNE then
            -- 取消部队符文采集
            if not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING_NO_DELETE ) then
                -- 更新部队采集完成时间
                MSM.SceneArmyMgr[_objectIndex].post.syncArmyCollectRuneTime( _objectIndex, 0 )
            end
        end

        -- 移除向目标行军
        ArmyWalkLogic:delArmyWalkTargetInfo( armyInfo.targetObjectIndex, oldTargetTypeInfo.objectType, _objectIndex )
    end

    -- 取消部队符文采集
    if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING_NO_DELETE ) then
        local targetArg = ArmyLogic:getArmy( armyInfo.rid, armyInfo.armyIndex, Enum.Army.targetArg ) or {}
        if targetArg.oldTargetObjectIndex and targetArg.oldTargetObjectIndex > 0 then
            MSM.RuneMgr[targetArg.oldTargetObjectIndex].post.cancelCollectRune( armyInfo.rid, armyInfo.armyIndex, targetArg.oldTargetObjectIndex )
        end
    end

    -- 如果之前处于攻击目标,先取消预警
    local oldTargetIndex = armyInfo.targetObjectIndex
    if oldTargetTypeInfo then
        if MapObjectLogic:checkIsResourceObject( oldTargetTypeInfo.objectType ) then
            -- 获取资源类的部队
            local resourceInfo = MSM.SceneResourceMgr[oldTargetIndex].req.getResourceInfo( oldTargetIndex )
            EarlyWarningLogic:deleteEarlyWarning( resourceInfo.collectRid, _objectIndex, oldTargetIndex )
        elseif MapObjectLogic:checkIsGuildBuildObject( oldTargetTypeInfo.objectType ) then
            -- 获取联盟建筑内的成员
            local memberRids = MSM.SceneGuildBuildMgr[oldTargetIndex].req.getMemberRidsInBuild( oldTargetIndex )
            for _, memberRid in pairs(memberRids) do
                EarlyWarningLogic:deleteEarlyWarning( memberRid, _objectIndex, oldTargetIndex )
            end
        elseif MapObjectLogic:checkIsHolyLandObject( oldTargetTypeInfo.objectType ) then
            -- 获取圣地内的成员
            local memberRids = MSM.SceneHolyLandMgr[oldTargetIndex].req.getMemberRidsInBuild( oldTargetIndex )
            for _, memberRid in pairs(memberRids) do
                EarlyWarningLogic:deleteEarlyWarning( memberRid, _objectIndex, oldTargetIndex )
            end
        elseif oldTargetTypeInfo.objectType == Enum.RoleType.ARMY and oldTargetTypeInfo.isRally then
            -- 集结部队
            local memberRids = table.indexs( oldTargetTypeInfo.rallyArmy )
            for _, memberRid in pairs(memberRids) do
                EarlyWarningLogic:deleteEarlyWarning( memberRid, _objectIndex, oldTargetIndex )
            end
        else
            -- 删除预警
            if oldTargetTypeInfo.rid and oldTargetTypeInfo.rid > 0 then
                EarlyWarningLogic:deleteEarlyWarning( oldTargetTypeInfo.rid, _objectIndex, oldTargetIndex )
            end
        end
    end

    if _marchType and _marchType == Enum.MapMarchTargetType.STATION then
        -- 部队驻扎,停止模拟行走
        armyWalks[_objectIndex] = nil
        -- 更新军队状态
        if not _stationStatusOp then
            MSM.SceneArmyMgr[_objectIndex].post.addArmyStation( _objectIndex, armyInfo.pos, true )
        else
            -- 目标消失，删除状态
            MSM.SceneArmyMgr[_objectIndex].req.updateArmyStatus( _objectIndex, _armyStatus, _stationStatusOp, nil, true )
        end
        -- 更新部队目标信息
        local targetArg = ArmyLogic:getArmy( armyInfo.rid, armyInfo.armyIndex, Enum.Army.targetArg ) or {}
        local newTargetArg = {
            pos = targetArg.pos,
            targetObjectIndex = targetArg.targetObjectIndex,
        }
        ArmyLogic:updateArmyInfo( armyInfo.rid, armyInfo.armyIndex, { [Enum.Army.targetArg] = newTargetArg } )

        return
    end

    -- 默认空地移动
    local marchType = Enum.MapMarchTargetType.SPACE
    local status = Enum.ArmyStatus.SPACE_MARCH
    local toType, targetArmyRadius, targetTypeInfo
    local armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers, armyInfo.isRally )
    if not _targetIndex then _targetIndex = 0 end
    if _targetIndex and _targetIndex > 0 then
        -- 判断目标类型
        targetTypeInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
        if targetTypeInfo then
            toType = targetTypeInfo.objectType
            _pos = targetTypeInfo.pos
            if toType == Enum.RoleType.ARMY then
                -- 部队
                -- 进攻、跟随军队
                marchType = Enum.MapMarchTargetType.ATTACK
                status = Enum.ArmyStatus.ATTACK_MARCH
                -- 修正部队坐标
                targetArmyRadius = CommonCacle:getArmyRadius( targetTypeInfo.soldiers )
            elseif MapObjectLogic:checkIsResourceObject( toType ) then
                -- 采集资源
                marchType = Enum.MapMarchTargetType.COLLECT
                status = Enum.ArmyStatus.COLLECT_MARCH
                -- 资源坐标
                -- 如果资源内有非友方部队,则改为攻击
                if ArmyLogic:checkAttacKResourceArmy( armyInfo.rid, _targetIndex ) then
                    marchType = Enum.MapMarchTargetType.ATTACK
                    status = Enum.ArmyStatus.ATTACK_MARCH
                    -- 标记部队攻击资源
                    MSM.SceneResourceMgr[_targetIndex].post.armyAttackResource( _targetIndex, _objectIndex )
                end
            elseif toType == Enum.RoleType.MONSTER or toType == Enum.RoleType.GUARD_HOLY_LAND or toType == Enum.RoleType.SUMMON_SINGLE_MONSTER
                or toType == Enum.RoleType.SUMMON_RALLY_MONSTER then
                -- 野蛮人、圣地守护者、召唤怪物
                marchType = Enum.MapMarchTargetType.ATTACK
                status = Enum.ArmyStatus.ATTACK_MARCH
                -- 如果目标是野蛮人,修正坐标
                targetArmyRadius = targetTypeInfo.armyRadius
            elseif toType == Enum.RoleType.CITY then
                -- 玩家城市
                if targetTypeInfo.rid == armyInfo.rid then
                    -- 回城
                    marchType = Enum.MapMarchTargetType.RETREAT
                    status = Enum.ArmyStatus.RETREAT_MARCH
                else
                    marchType = Enum.MapMarchTargetType.ATTACK
                    status = Enum.ArmyStatus.ATTACK_MARCH
                end
            elseif MapObjectLogic:checkIsGuildBuildObject( toType ) then
                -- 联盟建筑
                if targetTypeInfo.guildBuildStatus == Enum.GuildBuildStatus.NORMAL
                    and MapObjectLogic:checkIsGuildResourceCenterObject( toType ) then
                    -- 联盟资源中心采集行军
                    marchType = Enum.MapMarchTargetType.COLLECT
                    status = Enum.ArmyStatus.COLLECT_MARCH
                else
                    if targetTypeInfo.guildId == armyInfo.guildId then
                        -- 增援行军
                        marchType = Enum.MapMarchTargetType.REINFORCE
                        status = Enum.ArmyStatus.REINFORCE_MARCH
                    else
                        -- 攻击行军
                        marchType = Enum.MapMarchTargetType.ATTACK
                        status = Enum.ArmyStatus.ATTACK_MARCH
                    end
                end
            elseif toType == Enum.RoleType.RUNE then
                -- 符文
                targetArmyRadius = targetTypeInfo.armyRadius
                -- 采集符文
                marchType = Enum.MapMarchTargetType.COLLECT
            elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
                -- 圣地建筑
                targetArmyRadius = targetTypeInfo.armyRadius
                if targetTypeInfo.guildId == armyInfo.guildId then
                    -- 增援
                    marchType = Enum.MapMarchTargetType.REINFORCE
                else
                    -- 攻击
                    marchType = Enum.MapMarchTargetType.ATTACK
                    if armyInfo.isRally then
                        marchType = Enum.MapMarchTargetType.RALLY_ATTACK
                    end
                end
            end
        end
    end

    -- 使用参数行军类型
    if _marchType then
        marchType = _marchType
    end

    LOG_INFO("rid(%s) armyMove marchType(%s) targetObjectType(%s)", tostring(armyInfo.rid), tostring(marchType), tostring(toType))

    -- 触发战争狂热(仅PVP行为)
    if marchType == Enum.MapMarchTargetType.ATTACK then
        if toType ~= Enum.RoleType.MONSTER and toType ~= Enum.RoleType.GUARD_HOLY_LAND
        and toType ~= Enum.RoleType.MONSTER_CITY then
            RoleLogic:addWarCrazy( armyInfo.rid )
        end
    end

    -- 使用参数部队状态
    if _armyStatus then
        status = _armyStatus
    end

    -- 如果是移动行军,而且处于战斗,从旧目标的站位中退出
    if oldTargetIndex and oldTargetIndex > 0 and ArmyLogic:checkArmyWalkStatus( status )
    and ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) and not isFollowUp and not _noWarning then
        MSM.AttackAroundPosMgr[oldTargetIndex].post.delAttacker( oldTargetIndex, _objectIndex )
        -- 清空自己的周围站位
        --MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
    end

    -- 更新部队目标信息
    ArmyLogic:updateArmyMarchTargetInfo( armyInfo.rid, armyInfo.armyIndex, armyInfo, status, _targetIndex, targetTypeInfo )

    -- 发起进攻、集结,取消护盾状态
    if marchType == Enum.MapMarchTargetType.ATTACK
    or marchType == Enum.MapMarchTargetType.RALLY then
        if targetTypeInfo then
            -- 目标是中立单位不取消护盾
            if targetTypeInfo.objectType == Enum.RoleType.ARMY or targetTypeInfo.objectType == Enum.RoleType.CITY
            or MapObjectLogic:checkIsGuildBuildObject( targetTypeInfo.objectType)
            or MapObjectLogic:checkIsHolyLandObject( targetTypeInfo.objectType ) then
                RoleLogic:removeCityShield( armyInfo.rid )
            end
        end
    end

    if marchType == Enum.MapMarchTargetType.REINFORCE then
        if targetTypeInfo then
            -- 增援部队取消护盾
            if targetTypeInfo.objectType == Enum.RoleType.ARMY then
                RoleLogic:removeCityShield( armyInfo.rid )
            end
        end
    end

    local path = { armyInfo.pos, _pos }
    local passPosInfo
    local canPass, isDefeat
    local armySoldierCount = ArmyLogic:getArmySoldierCount( armyInfo.soldiers, armyInfo.rid, armyInfo.armyIndex )
    if table.empty( armyInfo.soldiers or {} ) or _isDefeat or armySoldierCount <= 0 then
        isDefeat = true
    end
    -- 坐标修正
    path, canPass, passPosInfo = ArmyWalkLogic:fixPathPoint( _ftype, toType, path, armyRadius, targetArmyRadius, nil, armyInfo.rid, isDefeat )
    if not canPass then
        -- 非集结部队
        if not armyInfo.isRally then
            local armyObjectIndex = MSM.RoleArmyMgr[armyInfo.rid].req.getRoleArmyIndex( armyInfo.rid, armyInfo.armyIndex )
            -- 部队不在地图上
            if not armyObjectIndex then
                local fromPos = ArmyWalkLogic:getFromPos(_ftype, path, armyRadius)
                -- 加入AOI
                MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyEnter( Enum.MapLevel.ARMY, _objectIndex, fromPos, fromPos, armyInfo )
                -- 记录军队索引与对象索引关系
                MSM.RoleArmyMgr[armyInfo.rid].post.addRoleArmyIndex( armyInfo.rid, armyInfo.armyIndex, _objectIndex )
                MSM.SceneArmyMgr[_objectIndex].post.addArmyStation( _objectIndex )
            end
        else
            -- 集结部队,解散
            MSM.RallyMgr[armyInfo.guildId].req.disbandRallyArmy( armyInfo.guildId, armyInfo.rid )
        end
        return
    end
    -- 如果是追击,修正后的位置不能远离目标
    if marchType == Enum.MapMarchTargetType.FOLLOWUP then
        if ArmyWalkLogic:cacleDistance( armyInfo.pos, _pos ) < ArmyWalkLogic:cacleDistance( path[#path], _pos ) then
            return
        end

        -- 如果路径在原点,直接取原路径
        if #path == 2 and path[1] == path[2] then
            path = { armyInfo.pos, _pos }
        end
    end
    -- 如果是出城,修正后的起始点不能远离原起始坐标
    if _isEnterMove then
        -- 不能超过2个城市的距离
        if path and path[1] and ArmyWalkLogic:cacleDistance( armyInfo.pos, path[1] ) > 1800 then
            LOG_ERROR("rid(%d) fixPos far 1800, raw(%s) fix(%s)", armyInfo.rid, tostring({ armyInfo.pos, _pos }), tostring(path))
            return
        end
    end

    -- 部队状态
    local speed = armyInfo.speed
    if isDefeat then
        -- 溃败取配置时间
        speed = CFG.s_Config:Get("ArmsDefeatedSpeed")
        -- 更新部队状态(一般是在资源或者建筑中被击溃了)
        ArmyLogic:updateArmyStatus( armyInfo.rid, armyInfo.armyIndex, Enum.ArmyStatus.FAILED_MARCH )
        status = Enum.ArmyStatus.FAILED_MARCH
    end

    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( path, speed )
    if _isEnterMove then
        armyInfo.arrivalTime = arrivalTime
        armyInfo.path = path
        armyInfo.status = status
        armyInfo.pos = path[1]
        -- 加入AOI
        MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyEnter( Enum.MapLevel.ARMY, _objectIndex, path[1], path[1], armyInfo )
        -- 记录军队索引与对象索引关系
        MSM.RoleArmyMgr[armyInfo.rid].post.addRoleArmyIndex( armyInfo.rid, armyInfo.armyIndex, _objectIndex )
        -- 溃败不重新计算
        if not isDefeat then
            -- 重新获取速度,重新计算到达时间
            local armyObjectInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
            if speed ~= armyObjectInfo.speed then
                -- 速度发生了变化
                speed = armyObjectInfo.speed
                arrivalTime = ArmyLogic:cacleArrivalTime( path, speed )
                -- 重新同步到达时间
                ArmyLogic:updateArmyInfo( armyInfo.rid, armyInfo.armyIndex, { arrivalTime = arrivalTime } )
                -- 路径重新同步
                MSM.SceneArmyMgr[_objectIndex].post.updateArmyPath( _objectIndex, path, arrivalTime, os.time(), _targetIndex, status )
            end
        end
    end

    -- 增加向目标行军信息
    if ArmyLogic:checkArmyWalkStatus( status ) then
        ArmyWalkLogic:addArmyWalkTargetInfo( _targetIndex, toType, _objectIndex, marchType, arrivalTime, path )
    end
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( path, speed )
    -- 加入模拟行走
    local leftPath = table.copy(path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)
    -- 行军参数结构
    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = path[2]
    defaultArmyWalk.now = path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = marchType
    defaultArmyWalk.rid = armyInfo.rid
    defaultArmyWalk.armyIndex = armyInfo.armyIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.ARMY
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    defaultArmyWalk.passPosInfo = passPosInfo
    defaultArmyWalk.isRallyArmy = armyInfo.isRally or false
    armyWalks[_objectIndex] = defaultArmyWalk

    if not _isEnterMove then
        -- 路径同步
        MSM.SceneArmyMgr[_objectIndex].post.updateArmyPath( _objectIndex, path, arrivalTime, os.time(), _targetIndex, status, nil, armyInfo.buildArmyIndex )
    end

    -- 更新部队到达时间
    if _targetIndex and _targetIndex > 0 then
        GuildBuildLogic:updateBuildArmyArrivalTime( _targetIndex, armyInfo.rid, armyInfo.armyIndex, arrivalTime )
    end

    -- 发送攻击预警, 不向自己发起预警
    if not _noWarning then
        if toType and ( toType == Enum.RoleType.CITY or toType == Enum.RoleType.ARMY
        or MapObjectLogic:checkIsResourceObject( toType ) or MapObjectLogic:checkIsGuildBuildObject( toType )
        or MapObjectLogic:checkIsHolyLandObject( toType ) ) then
            -- 攻击、增援、加入集结才有预警
            if marchType == Enum.MapMarchTargetType.ATTACK or marchType == Enum.MapMarchTargetType.REINFORCE
            or marchType == Enum.MapMarchTargetType.RALLY or marchType == Enum.MapMarchTargetType.RALLY_ATTACK then
                local targetRids = { targetTypeInfo.rid }
                if MapObjectLogic:checkIsResourceObject( toType ) then
                    local resourceInfo = MSM.SceneResourceMgr[_targetIndex].req.getResourceInfo( _targetIndex )
                    targetRids = { resourceInfo.collectRid }
                elseif MapObjectLogic:checkIsGuildBuildObject( toType ) then
                    -- 联盟建筑,通知建筑内的所有成员
                    targetRids = MSM.SceneGuildBuildMgr[_targetIndex].req.getMemberRidsInBuild( _targetIndex )
                elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
                    -- 圣地建筑,通知建筑内的所有成员
                    targetRids = MSM.SceneHolyLandMgr[_targetIndex].req.getMemberRidsInBuild( _targetIndex )
                elseif toType == Enum.RoleType.ARMY and targetTypeInfo.isRally then
                    -- 集结部队
                    targetRids = table.indexs( targetTypeInfo.rallyArmy )
                end

                for _, targetRid in pairs(targetRids) do
                    if marchType == Enum.MapMarchTargetType.ATTACK or marchType == Enum.MapMarchTargetType.RALLY_ATTACK then
                        EarlyWarningLogic:notfiyAttack( armyInfo.rid, targetRid, arrivalTime, armyInfo.soldiers, _targetIndex, _objectIndex,
                                                        armyInfo.mainHeroId, armyInfo.mainHeroLevel, armyInfo.deputyHeroId, armyInfo.deputyHeroLevel )
                    elseif marchType == Enum.MapMarchTargetType.REINFORCE or marchType == Enum.MapMarchTargetType.RALLY then
                        EarlyWarningLogic:notifyReinforce( armyInfo.rid, targetRid, arrivalTime, armyInfo.soldiers, _targetIndex, _objectIndex,
                                                        armyInfo.mainHeroId, armyInfo.mainHeroLevel, armyInfo.deputyHeroId, armyInfo.deputyHeroLevel )
                    end
                end
            end
        end
    end

    -- 记录部队行军日志
    local roleArmyInfo = ArmyLogic:getArmy( armyInfo.rid, armyInfo.armyIndex ) or {}
    if not table.empty( roleArmyInfo ) then
        LogLogic:troopsMarch( {
            rid = armyInfo.rid, iggid = RoleLogic:getRole( armyInfo.rid, Enum.Role.iggid ), armyIndex = armyInfo.armyIndex,
            status = status, mainHeroId = roleArmyInfo.mainHeroId, deputyHeroId = roleArmyInfo.deputyHeroId,
            soldiers = roleArmyInfo.soldiers, minorSoldiers = roleArmyInfo.minorSoldiers, pos = _pos,
            objectType = toType, targetId = ArmyLogic:getArmyMarchTargetId( targetTypeInfo )
        } )
    end

    return arrivalTime
end

---@see 部队移动速度改变
function accept.changeArmySpeed( _objectIndex, _fpos, _speed )
    if armyWalks[_objectIndex] then
        -- 部队信息
        local armyInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
        local tpos
        if armyWalks[_objectIndex].path and table.size(armyWalks[_objectIndex].path) > 0 then
            local pathCount = #armyWalks[_objectIndex].path
            tpos = armyWalks[_objectIndex].path[pathCount]
        else
            tpos = armyWalks[_objectIndex].next
        end

        -- 没有目标点
        if not tpos then
            return
        end

        -- 修正路径
        local path = { _fpos, tpos }
        local targetIndex = armyWalks[_objectIndex].targetObjectIndex
        if targetIndex then
            local targetInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
            if targetInfo then
                path = { _fpos, targetInfo.pos }
                path = ArmyWalkLogic:fixPathPoint( nil, targetInfo.objectType, path, armyInfo.armyRadius, targetInfo.armyRadius, nil, armyInfo.rid )
            end
        end
        -- 计算到达时间
        local arrivalTime = ArmyLogic:cacleArrivalTime( path, _speed )
        -- 计算移动角度
        local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( path, _speed )

        -- 加入模拟行走
        local leftPath = table.copy(path, true)
        -- 移除前2个坐标点
        table.remove(leftPath, 1)
        table.remove(leftPath, 1)

        armyWalks[_objectIndex].path = leftPath
        armyWalks[_objectIndex].next = path[2]
        armyWalks[_objectIndex].now = path[1]
        armyWalks[_objectIndex].speed = { x = speedx, y = speedy }
        armyWalks[_objectIndex].angle = angle
        armyWalks[_objectIndex].arrivalTime = arrivalTime
        armyWalks[_objectIndex].rawSpeed = armyInfo.speed

        -- 通过AOI通知
        MSM.SceneArmyMgr[_objectIndex].post.updateArmyPath( _objectIndex, path, arrivalTime, os.time(), armyWalks[_objectIndex].targetObjectIndex )

        -- 如果是增援,加入集结,通知增援目标时间改变
        targetIndex = armyWalks[_objectIndex].targetObjectIndex
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH )
        or ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_JOIN_MARCH ) then
            local targetInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
            if targetInfo.objectType == Enum.RoleType.ARMY or targetInfo.objectType == Enum.RoleType.CITY then
                MSM.RallyMgr[armyInfo.guildId].post.updateReinforceArrivalTime( armyInfo.guildId, targetInfo.rid, armyInfo.rid, arrivalTime )
            end
        end

        -- 通知目标预警达到时间改变
        if targetIndex then
            EarlyWarningLogic:updateEarlyWarningTime( targetIndex, _objectIndex, arrivalTime )
        end
    end
end

---@see 更新部队路径
function accept.updateArmyMovePath( _objectIndex, _targetIndex, _path )
    if armyWalks[_objectIndex] then
        local walkInfo = armyWalks[_objectIndex]
        -- 部队信息
        local armyInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.MOVE ) then
            return
        end
        -- 计算到达时间
        local arrivalTime = ArmyLogic:cacleArrivalTime( _path, armyInfo.speed )
        -- 计算移动角度
        local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, armyInfo.speed )
        -- 加入模拟行走
        local leftPath = table.copy(_path, true)
        -- 移除前2个坐标点
        table.remove(leftPath, 1)
        table.remove(leftPath, 1)

        walkInfo.path = leftPath
        walkInfo.next = _path[2]
        walkInfo.now = _path[1]
        walkInfo.speed = { x = speedx, y = speedy }
        walkInfo.angle = angle
        walkInfo.arrivalTime = arrivalTime
        walkInfo.rawSpeed = armyInfo.speed

        -- 通过AOI通知
        MSM.SceneArmyMgr[_objectIndex].post.updateArmyPath( _objectIndex, _path, arrivalTime, os.time(), _targetIndex )

        if walkInfo.marchType == Enum.MapMarchTargetType.REINFORCE then
            local targetObjectIndex = walkInfo.targetObjectIndex
            if targetObjectIndex then
                -- 增援集结部队,刷新达到时间
                local targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
                if targetInfo then
                    if targetInfo.objectType == Enum.RoleType.ARMY and targetInfo.isRally then
                        RallyLogic:refreshReinforceArrivalTime( targetInfo.rid, targetInfo.guildId, armyInfo.rid, arrivalTime )
                    end
                end
            end
        end
    end
end

---@see 部队移动.用于位置修正
function accept.fixArmyPath( _objectIndex, _targetIndex, _path )
    -- 部队信息
    local armyInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, armyInfo.speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, armyInfo.speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = armyInfo.speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.MOVE
    defaultArmyWalk.rid = armyInfo.rid
    defaultArmyWalk.armyIndex = armyInfo.armyIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.ARMY
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 如果目标正在战斗,而且已经有目标,不转移目标
    if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) and armyInfo.targetObjectIndex > 0 then
        _targetIndex = nil
    end
    -- 同步路径
    armyInfo.status = ArmyLogic:addArmyStatus( armyInfo.status, Enum.ArmyStatus.MOVE )
    MSM.SceneArmyMgr[_objectIndex].post.updateArmyPath( _objectIndex, _path, arrivalTime, os.time(), _targetIndex, armyInfo.status )
end


---@see 怪物移动.用于位置修正
function accept.fixMonsterPath( _objectIndex, _objectType, _targetIndex, _path )
    -- 部队信息
    local monsterInfo = MSM.SceneMonsterMgr[_objectIndex].req.getMonsterInfo( _objectIndex )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, monsterInfo.speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, monsterInfo.speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = monsterInfo.speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.MOVE
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetIndex or 0
    defaultArmyWalk.objectType = _objectType
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 同步路径
    MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterPath( _objectIndex, _path, arrivalTime, os.time(), _targetIndex, Enum.ArmyStatus.MOVE, true )
end

---@see 斥候出发侦查
function response.addScouts( _rid, _objectIndex, _scoutsIndex, _path, _targetObjectIndex, _speed )
    local toType, taregetObjectInfo, targetArmyRadius
    -- 默认斥候状态
    local scoutsStatus = Enum.ArmyStatus.DISCOVER
    -- 获取目标类型
    if _targetObjectIndex then
        taregetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
        toType = taregetObjectInfo.objectType
        if toType == Enum.RoleType.ARMY then
            -- 修正部队坐标
            targetArmyRadius = taregetObjectInfo.armyRadius
        elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
            targetArmyRadius = MSM.SceneHolyLandMgr[_targetObjectIndex].req.getHolyLandRadius( _targetObjectIndex )
        end
        -- 获取斥候状态
        scoutsStatus = ScoutsLogic:getScoutStatusByTargetType( _targetObjectIndex, toType )
        if scoutsStatus == Enum.ArmyStatus.SCOUTING then
            -- 侦察破盾
            RoleLogic:removeCityShield( _rid )
        end
    end
    -- 修正坐标
    local scoutsRadiusCollide = CFG.s_Config:Get("scoutsRadiusCollide") * 100
    _path = ArmyWalkLogic:fixPathPoint( Enum.RoleType.CITY, toType, _path, scoutsRadiusCollide, targetArmyRadius, nil, _rid, true )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, _speed )
    -- 加入AOI
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.scoutsEnter( Enum.MapLevel.ARMY, _objectIndex, _path[1], _path[1],
                                    {
                                        rid = _rid,
                                        arrivalTime = arrivalTime,
                                        startTime = os.time(),
                                        speed = _speed,
                                        path = _path,
                                        targetObjectIndex = _targetObjectIndex,
                                        scoutsIndex = _scoutsIndex,
                                        scoutsStatus = scoutsStatus,
                                        objectIndex = _objectIndex
                                    }
                                )

    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, _speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)
    -- 获取目标点的迷雾列表
    local scoutView = RoleLogic:getRole( _rid, Enum.Role.scoutView )
    local allDesenFog, allDesenFogPos = DenseFogLogic:getAllDenseFog( _rid, scoutView, _path[#_path], true )

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = _speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.SCOUTS
    defaultArmyWalk.rid = _rid
    defaultArmyWalk.armyIndex = _scoutsIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetObjectIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.SCOUTS
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.allDesenFog = allDesenFog or {}
    defaultArmyWalk.allDesenFogPos = allDesenFogPos or {}
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    defaultArmyWalk.denseFogOpenFlag = DenseFogLogic:checkRoleDenseFogAllOpen( _rid )
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 更新斥候信息
    local scoutsChangeInfo = {
        scoutsIndex = _scoutsIndex,
        scoutsStatus = scoutsStatus,
        arrivalTime = arrivalTime,
        startTime = os.time(),
        scoutsPath = _path,
        scoutsTargetIndex = _targetObjectIndex or 0,
    }
    ScoutsLogic:updateScoutsInfo( _rid, _scoutsIndex, scoutsChangeInfo )
    -- 发送侦察预警
    if toType then
        EarlyWarningLogic:addScoutEarlyWarning( _rid, _objectIndex, arrivalTime, _targetObjectIndex, taregetObjectInfo )
        -- 添加斥候向目标移动
        ArmyWalkLogic:addArmyWalkTargetInfo( _targetObjectIndex, taregetObjectInfo.objectType, _objectIndex,
                                                Enum.MapMarchTargetType.SCOUTS, arrivalTime, _path )
    end
    -- 检查斥候新目标追踪处理
    ScoutFollowUpLogic:checkScoutTarget( _objectIndex, nil, _targetObjectIndex )
end

---@see 斥候迷雾内移动
function accept.scoutsDiscoverDenseFog( _rid, _objectIndex, _scoutsIndex, _path, _allDesenFog, _allDesenFogPos )
    -- 计算斥候速度(最终斥候行军速度 = 斥候行军速度 *（1000 + 斥候行军速度百分比）/1000)
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.scoutSpeed, Enum.Role.scoutSpeedMulti } )
    local speed = math.floor( roleInfo.scoutSpeed * ( 1000 + roleInfo.scoutSpeedMulti ) / 1000 )
    -- 寻路
    local fpos = _path[1]
    local checkPointPath
    _path, _, checkPointPath = ArmyWalkLogic:fixPathPoint( nil, nil, _path, nil, nil, nil, _rid, true )
    if not _path or #_path < 2 or ( _path[1] == _path[2] ) or ( checkPointPath and not table.empty( checkPointPath ) ) then
        -- 不可到达,直接开启
        DenseFogLogic:openAllDenseFog( _rid, _objectIndex, _scoutsIndex, _allDesenFog, fpos )
        return
    end
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.SCOUTS
    defaultArmyWalk.rid = _rid
    defaultArmyWalk.armyIndex = _scoutsIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.objectType = Enum.RoleType.SCOUTS
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.allDesenFog = _allDesenFog or {}
    defaultArmyWalk.allDesenFogPos = _allDesenFogPos or {}
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    defaultArmyWalk.denseFogOpenFlag = DenseFogLogic:checkRoleDenseFogAllOpen( _rid )
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 通过AOI通知
    MSM.SceneScoutsMgr[_objectIndex].post.updateScoutsPath( _objectIndex, _path, nil, arrivalTime, os.time() )
    -- 更新斥候信息
    local scoutsChangeInfo = {
        scoutsIndex = _scoutsIndex,
        arrivalTime = arrivalTime,
        startTime = os.time(),
        scoutsPath = _path
    }
    ScoutsLogic:updateScoutsInfo( _rid, _scoutsIndex, scoutsChangeInfo )
end

---@see 斥候回城
function accept.scoutsBackCity( _rid, _objectIndex, _path, _status )
    _status = _status or Enum.ArmyStatus.RETURN
    local scoutsInfo = MSM.SceneScoutsMgr[_objectIndex].req.getScoutsInfo( _objectIndex )
    if not scoutsInfo then
        return
    end
    local oldTargetIndex
    if armyWalks[_objectIndex] then
        oldTargetIndex = armyWalks[_objectIndex].targetObjectIndex
    end
    -- 修正回城终点坐标
    local scoutsRadiusCollide = CFG.s_Config:Get("scoutsRadiusCollide") * 100
    _path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.CITY, _path, scoutsRadiusCollide, nil, nil, _rid, true )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, scoutsInfo.speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, scoutsInfo.speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = scoutsInfo.speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.SCOUTS_BACK
    defaultArmyWalk.rid = _rid
    defaultArmyWalk.armyIndex = scoutsInfo.scoutsIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.objectType = Enum.RoleType.SCOUTS
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    defaultArmyWalk.denseFogOpenFlag = DenseFogLogic:checkRoleDenseFogAllOpen( _rid )
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 更新斥候信息
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local scoutsChangeInfo = {
        scoutsIndex = scoutsInfo.scoutsIndex,
        scoutsStatus = _status,
        arrivalTime = arrivalTime,
        startTime = os.time(),
        scoutsPath = _path,
        scoutsTargetIndex = cityIndex,
    }
    ScoutsLogic:updateScoutsInfo( _rid, scoutsInfo.scoutsIndex, scoutsChangeInfo )
    -- 通过AOI通知
    MSM.SceneScoutsMgr[_objectIndex].post.updateScoutsPath( _objectIndex, _path, nil, arrivalTime, os.time(), _status )
    -- 如果之前处于侦察目标,取消
    if oldTargetIndex and oldTargetIndex > 0 then
        local oldTaregetObjectInfo = MSM.MapObjectTypeMgr[oldTargetIndex].req.getObjectInfo( oldTargetIndex )
        local toType = oldTaregetObjectInfo.objectType
        if toType then
            -- 删除侦查预警
            EarlyWarningLogic:deleteScoutEarlyWarning( _objectIndex, oldTargetIndex, oldTaregetObjectInfo )
            -- 取消侦查远线
            ArmyWalkLogic:delArmyWalkTargetInfo( oldTargetIndex, toType, _objectIndex )
        end
    end

    -- 取消旧的追踪目标
    ScoutFollowUpLogic:checkScoutTarget( _objectIndex, oldTargetIndex )
end

---@see 斥候改变目标
function response.scoutsChangePos( _rid, _scoutsIndex, _path, _targetObjectIndex, _speed, _objectIndex )
    local oldTargetIndex, toType, targetArmyRadius
    if armyWalks[_objectIndex] then
        oldTargetIndex = armyWalks[_objectIndex].targetObjectIndex
    end
    -- 获取目标类型
    if _targetObjectIndex then
        local taregetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
        toType = taregetObjectInfo.objectType
        targetArmyRadius = taregetObjectInfo.armyRadius
    end
    -- 修正坐标
    _path = ArmyWalkLogic:fixPathPoint( nil, toType, _path, 0, targetArmyRadius, nil, _rid, true )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, _speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, _speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)
    -- 获取目标点的迷雾列表
    local scoutView = RoleLogic:getRole( _rid, Enum.Role.scoutView )
    local allDesenFog, allDesenFogPos = DenseFogLogic:getAllDenseFog( _rid, scoutView, _path[2], true )

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = _speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.SCOUTS
    defaultArmyWalk.rid = _rid
    defaultArmyWalk.armyIndex = _scoutsIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetObjectIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.SCOUTS
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.allDesenFog = allDesenFog or {}
    defaultArmyWalk.allDesenFogPos = allDesenFogPos or {}
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    defaultArmyWalk.denseFogOpenFlag = DenseFogLogic:checkRoleDenseFogAllOpen( _rid )
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 获取斥候状态
    local scoutsStatus = ScoutsLogic:getScoutStatusByTargetType( _targetObjectIndex, toType )
    -- 更新斥候信息
    local scoutsChangeInfo = {
        scoutsIndex = _scoutsIndex,
        scoutsStatus = scoutsStatus,
        arrivalTime = arrivalTime,
        startTime = os.time(),
        scoutsPath = _path,
        scoutsTargetIndex = _targetObjectIndex or 0,
    }
    ScoutsLogic:updateScoutsInfo( _rid, _scoutsIndex, scoutsChangeInfo )
    -- 侦察破盾
    if scoutsStatus == Enum.ArmyStatus.SCOUTING then
        RoleLogic:removeCityShield( _rid )
    end
    -- 通过AOI通知
    MSM.SceneScoutsMgr[_objectIndex].post.updateScoutsPath( _objectIndex, _path, nil, arrivalTime, os.time(), scoutsStatus )

    local oldTaregetObjectInfo, oldTargetType
    if oldTargetIndex and oldTargetIndex > 0 then
        oldTaregetObjectInfo = MSM.MapObjectTypeMgr[oldTargetIndex].req.getObjectType( oldTargetIndex )
        oldTargetType = oldTaregetObjectInfo and oldTaregetObjectInfo.objectType
    end
    -- 斥候切换侦查探索目标
    if not oldTargetIndex or oldTargetIndex <= 0 or not _targetObjectIndex or _targetObjectIndex <= 0
        or oldTargetIndex ~= _targetObjectIndex then
        -- 如果之前处于侦察目标,先取消
        if oldTargetIndex and oldTargetIndex > 0 then
            EarlyWarningLogic:deleteScoutEarlyWarning( _objectIndex, oldTargetIndex )
            -- 移除向目标行军
            ArmyWalkLogic:delArmyWalkTargetInfo( oldTargetIndex, oldTargetType, _objectIndex )
        end
        -- 发送侦察预警
        if _targetObjectIndex then
            local taregetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
            EarlyWarningLogic:addScoutEarlyWarning( _rid, _objectIndex, arrivalTime, _targetObjectIndex, taregetObjectInfo )
            -- 添加斥候向目标移动
            ArmyWalkLogic:addArmyWalkTargetInfo( _targetObjectIndex, taregetObjectInfo.objectType, _objectIndex,
                                                    Enum.MapMarchTargetType.SCOUTS, arrivalTime, _path )
        end
        -- 检查斥候新目标追踪处理
        ScoutFollowUpLogic:checkScoutTarget( _objectIndex, oldTargetIndex, _targetObjectIndex )
    elseif oldTargetIndex and oldTargetIndex > 0 and _targetObjectIndex and oldTargetIndex == _targetObjectIndex then
        -- 目标没改变,斥候跟随目标,更新缩略线
        if oldTargetType == Enum.RoleType.ARMY then
            MSM.SceneArmyMgr[_targetObjectIndex].post.updateArmyMarchPath( _targetObjectIndex, _objectIndex, _path )
        end
    end
end

---@see 中断对象移动
function response.stopObjectMove( _objectIndex )
    if armyWalks[_objectIndex] and armyWalks[_objectIndex].marchType == Enum.MapMarchTargetType.MOVE then
        -- 调整位置不能中断
        return
    end
    armyWalks[_objectIndex] = nil
end

---@see 野蛮人追击
function accept.monsterFollowUp( _objectIndex, _targetIndex, _path, _speed, _objectType )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, _speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, _speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = _speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.FOLLOWUP
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.objectType = _objectType
    defaultArmyWalk.targetObjectIndex = _targetIndex
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 同步路径
    MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterPath( _objectIndex, _path, arrivalTime, os.time(), _targetIndex, Enum.ArmyStatus.FOLLOWUP, true )
end

---@see 运输车加入地图
function response.transportEnterMap( _rid, _objectIndex, _transportIndex, _path, _targetObjectIndex, _speed )
    local toType
    -- 获取目标类型
    if _targetObjectIndex then
        local taregetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
        toType = taregetObjectInfo.objectType
    end
    -- 修正坐标
    local transportRadius = CFG.s_Config:Get( "transportRadius" )
    _path = ArmyWalkLogic:fixPathPoint( Enum.RoleType.CITY, toType, _path, transportRadius, nil, nil, _rid, true )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, _speed )
    -- 加入AOI
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.transportEnter( Enum.MapLevel.ARMY, _objectIndex, _path[1], _path[1],
                                    {
                                        rid = _rid,
                                        arrivalTime = arrivalTime,
                                        startTime = os.time(),
                                        speed = _speed,
                                        path = _path,
                                        targetObjectIndex = _targetObjectIndex,
                                        transportIndex = _transportIndex,
                                        objectIndex = _objectIndex
                                    }
                                )

    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, _speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = _speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.TRANSPORT
    defaultArmyWalk.rid = _rid
    defaultArmyWalk.armyIndex = _transportIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetObjectIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.TRANSPORT
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 更新运输车到达时间
    TransportLogic:updateTransportInfo( _rid, _transportIndex, {
                                                                arrivalTime = arrivalTime or 0,
                                                                path = _path,
                                                                objectIndex = _objectIndex,
                                                                startTime = os.time(),
                                                            }
                                    )
    return arrivalTime
end

---@see 运输车回城
function response.transportBackCity( _rid, _objectIndex, _transportIndex, _fromPos )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.pos } )
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local path = { _fromPos, roleInfo.pos }
    -- 修正回城终点坐标
    local transportRadiusCollide = CFG.s_Config:Get("transportRadiusCollide") * 100
    path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.CITY, path, transportRadiusCollide, nil, nil, _rid, true )
    local armyInfo =  MSM.SceneTransportMgr[_objectIndex].req.getTransportInfo( _objectIndex )

    local speed = armyInfo.speed

    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( path, speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( path, speed )
    -- 加入模拟行走
    local leftPath = table.copy(path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = path[2]
    defaultArmyWalk.now = path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.TRANSPORT_BACK
    defaultArmyWalk.rid = _rid
    defaultArmyWalk.armyIndex = _transportIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = cityIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.TRANSPORT
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 更新运输车到达时间
    TransportLogic:updateTransportInfo( _rid, _transportIndex, {
                                                                arrivalTime = arrivalTime or 0,
                                                                path = path,
                                                                objectIndex = _objectIndex,
                                                                startTime = os.time(),
                                                            }
                                    )
    -- 通过AOI通知
    MSM.SceneTransportMgr[_objectIndex].post.updateTransportPath( _objectIndex, path, cityIndex, arrivalTime, os.time() )
end

---@see 删除地图斥候对象
function accept.deleteScoutObject( _objectIndex, _noBackCity )
    -- 斥候回城回调
    local mapScoutInfo = MSM.SceneScoutsMgr[_objectIndex].req.getScoutsInfo( _objectIndex )
    if mapScoutInfo and not table.empty( mapScoutInfo ) then
        armyWalks[_objectIndex] = nil
        local ArmyMarchCallback = require "ArmyMarchCallback"
        ArmyMarchCallback:scoutsBackMarchCallback( mapScoutInfo.rid, mapScoutInfo.scoutsIndex, _objectIndex, nil, nil, _noBackCity )
    end
end

---@see 斥候进入地图回城
function accept.scoutEnterMapBackCity( _rid, _objectIndex, _scoutsIndex, _path, _speed, _status )
    _status = _status or Enum.ArmyStatus.RETURN
    -- 修正回城终点坐标
    local scoutsRadiusCollide = CFG.s_Config:Get("scoutsRadiusCollide") * 100
    _path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.CITY, _path, scoutsRadiusCollide, nil, nil, _rid, true )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, _speed )
    local nowTime = os.time()
    -- 加入AOI
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.scoutsEnter( Enum.MapLevel.ARMY, _objectIndex, _path[1], _path[1],
                                    {
                                        rid = _rid,
                                        arrivalTime = arrivalTime,
                                        startTime = nowTime,
                                        speed = _speed,
                                        path = _path,
                                        scoutsIndex = _scoutsIndex,
                                        scoutsStatus = _status,
                                        objectIndex = _objectIndex,
                                    }
                                )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, _speed )
    -- 加入模拟行走
    local leftPath = table.copy( _path, true )
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = _speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.SCOUTS_BACK
    defaultArmyWalk.rid = _rid
    defaultArmyWalk.armyIndex = _scoutsIndex
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.objectType = Enum.RoleType.SCOUTS
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    defaultArmyWalk.denseFogOpenFlag = DenseFogLogic:checkRoleDenseFogAllOpen( _rid )
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 更新斥候信息
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local scoutsChangeInfo = {
        scoutsIndex = _scoutsIndex,
        scoutsStatus = _status,
        arrivalTime = arrivalTime,
        startTime = os.time(),
        scoutsPath = _path,
        scoutsTargetIndex = cityIndex,
    }
    ScoutsLogic:updateScoutsInfo( _rid, _scoutsIndex, scoutsChangeInfo )
    -- 通过AOI通知
    MSM.SceneScoutsMgr[_objectIndex].post.updateScoutsPath( _objectIndex, _path, nil, arrivalTime, nowTime, _status )
end


---@see 远征地图上军队移动到指定目标
---@param _objectIndex 军队对象索引
---@param _targetIndex 目标索引.非必填
---@param _pos 位置坐标.移动到空地时填
---@param _stationStatusOp 驻扎时状态参数
function response.expeditionArmyMove( _objectIndex, _targetIndex, _pos, _armyStatus, _marchType, _ftype,
                            _isEnterMove, _isDefeat, _stationStatusOp, _armyInfo, _isFollowUp )
    -- 部队信息
    local armyInfo = _armyInfo or MSM.SceneExpeditionMgr[_objectIndex].req.getExpeditionInfo( _objectIndex )
    -- if not armyInfo or armyInfo.rid <= 0 then
    --     return
    -- end

    -- 如果之前处于移动状态,修正位置
    if armyWalks[_objectIndex] then
        local pos = ArmyWalkLogic:cacleObjectNowPos( armyWalks[_objectIndex] )
        if pos then
            armyInfo.pos = pos
            -- 更新坐标
            MSM.SceneArmyMgr[_objectIndex].post.updateArmyObjectPos( _objectIndex, pos )
        end
        armyWalks[_objectIndex] = nil
    end

    if _marchType and _marchType == Enum.MapMarchTargetType.STATION then
        -- 部队驻扎,停止模拟行走
        armyWalks[_objectIndex] = nil
        -- 更新军队状态
        if not _stationStatusOp then
            MSM.SceneExpeditionMgr[_objectIndex].post.addArmyStation( _objectIndex, armyInfo.pos  )
        else
            -- 目标消失，删除状态
            MSM.SceneExpeditionMgr[_objectIndex].req.updateArmyStatus( _objectIndex, _armyStatus, _stationStatusOp )
        end
        return
    end

    -- 默认空地移动
    local marchType = Enum.MapMarchTargetType.SPACE
    local status = Enum.ArmyStatus.SPACE_MARCH
    local targetArmyRadius, toType
    local armyRadius =  CommonCacle:getArmyRadius( armyInfo.soldiers )
    if not _targetIndex then _targetIndex = 0 end
    if _targetIndex and _targetIndex > 0 then
        -- 获取坐标
        local targetArmyInfo = MSM.SceneExpeditionMgr[_targetIndex].req.getExpeditionInfo( _targetIndex )
        _pos = targetArmyInfo.pos
        -- 进攻、跟随军队
        marchType = Enum.MapMarchTargetType.ATTACK
        status = Enum.ArmyStatus.ATTACK_MARCH
        -- 修正部队坐标
        targetArmyRadius = CommonCacle:getArmyRadius( targetArmyInfo.soldiers )
        toType = Enum.RoleType.EXPEDITION
    end

    -- 使用参数行军类型
    if _marchType then
        marchType = _marchType
    end

    -- 使用参数部队状态
    if _armyStatus then
        status = _armyStatus
    end
    -- 部队状态
    local speed = armyInfo.speed
    local path = { armyInfo.pos, _pos }
    -- 坐标修正
    local expeditionId = armyInfo.expeditionId
    local mapIndex = armyInfo.mapIndex
    local sExpedition = CFG.s_Expedition:Get(expeditionId)
    local sExpeditionBattle = CFG.s_ExpeditionBattle:Get(sExpedition.battleID)
    path = ArmyWalkLogic:fixPathPoint( _ftype, toType, path, armyRadius, targetArmyRadius, sExpeditionBattle.mapID )
    if _isEnterMove then
        armyInfo.path = path
        -- 加入AOI
        MSM.AoiMgr[mapIndex].req.expeditionObjectEnter( mapIndex, _objectIndex, path[1], path[1], armyInfo )
    end

    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( path, speed )
    -- 增加向目标行军信息
    if ArmyLogic:checkArmyWalkStatus( status ) then
        ArmyWalkLogic:addArmyWalkTargetInfo( _targetIndex, toType, _objectIndex, marchType, arrivalTime, path )
    end
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( path, speed )
    -- 加入模拟行走
    local leftPath = table.copy(path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = path[2]
    defaultArmyWalk.now = path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = marchType
    defaultArmyWalk.rid = armyInfo.rid
    defaultArmyWalk.armyIndex = armyInfo.armyIndex or 0
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.EXPEDITION
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.mapIndex = mapIndex
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 路径同步
    MSM.SceneExpeditionMgr[_objectIndex].post.updateArmyPath( _objectIndex, path, arrivalTime, os.time(), _targetIndex, status )

    return arrivalTime
end


---@see 远征对象追击
function accept.expeditionFollowUp( _objectIndex, _targetIndex, _path, _speed, mapIndex )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, _speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, _speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = _speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.FOLLOWUP
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.EXPEDITION
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.mapIndex = mapIndex
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 同步路径
    MSM.SceneExpeditionMgr[_objectIndex].post.updateExpeditionPath( _objectIndex, _path, arrivalTime, os.time(), nil, Enum.ArmyStatus.FOLLOWUP )
end


---@see 更新远征对象路径
function accept.updateExpeditionMovePath( _objectIndex, _targetIndex, _path )
    if armyWalks[_objectIndex] then
        -- 部队信息
        local armyInfo = MSM.SceneExpeditionMgr[_objectIndex].req.getExpeditionInfo( _objectIndex )
        -- 计算到达时间
        local arrivalTime = ArmyLogic:cacleArrivalTime( _path, armyInfo.speed )
        -- 计算移动角度
        local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, armyInfo.speed )
        -- 加入模拟行走
        local leftPath = table.copy(_path, true)
        -- 移除前2个坐标点
        table.remove(leftPath, 1)
        table.remove(leftPath, 1)

        armyWalks[_objectIndex].path = leftPath
        armyWalks[_objectIndex].next = _path[2]
        armyWalks[_objectIndex].now = _path[1]
        armyWalks[_objectIndex].speed = { x = speedx, y = speedy }
        armyWalks[_objectIndex].angle = angle
        armyWalks[_objectIndex].arrivalTime = arrivalTime
        armyWalks[_objectIndex].lastTick = timerCore.getmillisecond()

        -- 通过AOI通知
        MSM.SceneExpeditionMgr[_objectIndex].post.updateExpeditionPath( _objectIndex, _path, arrivalTime, os.time(), _targetIndex )
    end
end

---@see 部队移动.用于位置修正
function accept.fixExpeditionPath( _objectIndex, _targetIndex, _path )
    -- 部队信息
    local armyInfo = MSM.SceneExpeditionMgr[_objectIndex].req.getExpeditionInfo( _objectIndex )
    local expeditionId = armyInfo.expeditionId
    local sExpedition = CFG.s_Expedition:Get(expeditionId)
    local sExpeditionBattle = CFG.s_ExpeditionBattle:Get(sExpedition.battleID)
    -- 修正路径
    _path = ArmyWalkLogic:fixPathPoint( nil, nil, _path, nil, nil, sExpeditionBattle.mapID  )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( _path, armyInfo.speed )
    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( _path, armyInfo.speed )
    -- 加入模拟行走
    local leftPath = table.copy(_path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = _path[2]
    defaultArmyWalk.now = _path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = armyInfo.speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.MOVE
    defaultArmyWalk.rid = armyInfo.rid
    defaultArmyWalk.objectIndex = _objectIndex
    defaultArmyWalk.targetObjectIndex = _targetIndex or 0
    defaultArmyWalk.objectType = Enum.RoleType.EXPEDITION
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.mapIndex = armyInfo.mapIndex
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[_objectIndex] = defaultArmyWalk

    -- 同步路径
    armyInfo.status = ArmyLogic:addArmyStatus( armyInfo.status, Enum.ArmyStatus.MOVE )
    MSM.SceneExpeditionMgr[_objectIndex].post.updateExpeditionPath( _objectIndex, _path, arrivalTime, os.time(), _targetIndex, armyInfo.status )
end

---@see 补偿修正目标位置
function response.fixObjectPosWithMillisecond( _objectIndex, _noClean )
    if armyWalks[_objectIndex] then
        local pos = ArmyWalkLogic:cacleObjectNowPos( armyWalks[_objectIndex] )
        if not _noClean then
            armyWalks[_objectIndex] = nil
        else
            -- 更新最后tick时间
            armyWalks[_objectIndex].lastTick = timerCore.getmillisecond()
        end
        return pos
    end
end

---@see 更新所有地图对象的迷雾全部探索状态
function accept.updateDenseFogOpenFlag()
    for _, armyWalkInfo in pairs( armyWalks ) do
        armyWalkInfo.denseFogOpenFlag = true
    end
end

---@see 战损补偿运输车加入地图
function accept.battleLoseTransportEnterMap( _fromRid, _toRid )
    -- 修正坐标
    local fromPos = RoleLogic:getRole( _fromRid, Enum.Role.pos )
    local toPos = RoleLogic:getRole( _toRid, Enum.Role.pos )
    local path = { fromPos, toPos }
    -- 如果直线距离超过4公里,则随机一个4公里内的
    local distance = 4000
    if _fromRid == _toRid or ArmyLogic:cacleDistance( path ) > distance then
        -- 随机一个角度
        local angle = Random.Get( 0, 360 )

        local posx = math.floor( distance * math.cos( math.rad(angle) ) + toPos.x )
        local posy = math.floor( distance * math.sin( math.rad(angle) ) + toPos.y )
        fromPos = { x = posx, y = posy }
        path = { fromPos, toPos }
    end

    -- 修正路线
    if MapLogic:checkPosIdle( fromPos, 1 ) then
        local transportRadius = CFG.s_Config:Get( "transportRadius" )
        path = ArmyWalkLogic:fixPathPoint( Enum.RoleType.CITY, Enum.RoleType.CITY, path, transportRadius, nil, nil, nil, true )
    end

    -- 获取速度
    local speed = CFG.s_Config:Get( "makeupspeed" )
    -- 计算到达时间
    local arrivalTime = ArmyLogic:cacleArrivalTime( path, speed )
    local objectIndex = Common.newMapObjectIndex()
    -- 加入AOI
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.transportEnter( Enum.MapLevel.ARMY, objectIndex, path[1], path[1],
                                    {
                                        rid = _fromRid,
                                        arrivalTime = arrivalTime,
                                        startTime = os.time(),
                                        speed = speed,
                                        path = path,
                                        objectIndex = objectIndex,
                                        isBattleLose = true,
                                        isSelf = _fromRid == _toRid
                                    }
                                )

    -- 计算移动角度
    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( path, speed )
    -- 加入模拟行走
    local leftPath = table.copy(path, true)
    -- 移除前2个坐标点
    table.remove(leftPath, 1)
    table.remove(leftPath, 1)

    local defaultArmyWalk = ArmyDef:getDefaultArmyWalk()
    defaultArmyWalk.path = leftPath
    defaultArmyWalk.next = path[2]
    defaultArmyWalk.now = path[1]
    defaultArmyWalk.speed = { x = speedx, y = speedy }
    defaultArmyWalk.rawSpeed = speed
    defaultArmyWalk.angle = angle
    defaultArmyWalk.marchType = Enum.MapMarchTargetType.BATTLELOSE_TRANSPORT
    defaultArmyWalk.objectIndex = objectIndex
    defaultArmyWalk.objectType = Enum.RoleType.TRANSPORT
    defaultArmyWalk.arrivalTime = arrivalTime
    defaultArmyWalk.lastTick = timerCore.getmillisecond()
    armyWalks[objectIndex] = defaultArmyWalk

    -- 发送预警信息
    if _fromRid ~= _toRid then
        local fromObjectIndex = RoleLogic:getRoleCityIndex( _fromRid )
        EarlyWarningLogic:notifyTransport( _fromRid, _toRid, arrivalTime, { transportStatus = Enum.TransportStatus.BATTLELOSE }, objectIndex, fromObjectIndex )
    end
    return arrivalTime
end