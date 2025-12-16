--[[
 * @file : ArmyMarchLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-04-30 15:32:47
 * @Last Modified time: 2020-04-30 15:32:47
 * @department : Arabic Studio
 * @brief : 部队行军相关逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local ArmyMarchLogic = {}

local RoleLogic = require "RoleLogic"
local EmailLogic = require "EmailLogic"
local ArmyLogic = require "ArmyLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local MapObjectLogic = require "MapObjectLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local ResourceLogic = require "ResourceLogic"
local MapLogic = require "MapLogic"
local CityReinforceLogic = require "CityReinforceLogic"
local HeroLogic = require "HeroLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"

---@see 判断是否需要返还行动力
function ArmyMarchLogic:checkReturnActionForce( _rid, _roleInfo, _armyInfo, _armyChangeInfo )
    if _armyInfo.preCostActionForce and _armyInfo.preCostActionForce > 0 then
        local backActionForce = _armyInfo.preCostActionForce
        local actionForceLimit = RoleLogic:getActionForceLimit( _rid )
        if _roleInfo.actionForce >= actionForceLimit then
            backActionForce = 0
        elseif _roleInfo.actionForce + backActionForce > actionForceLimit then
            backActionForce = actionForceLimit - _roleInfo.actionForce
        end
        RoleLogic:addActionForce( _rid, backActionForce, nil, Enum.LogType.CANCEL_ATTACK_GAIN_ACTION )
        -- 发送邮件
        local vitalityReturnEmail = CFG.s_Config:Get( "vitalityReturnEmail" )
        if vitalityReturnEmail and vitalityReturnEmail > 0 then
            EmailLogic:sendEmail( _rid, vitalityReturnEmail, {
                acitonForceReturn = backActionForce,
                subType = Enum.EmailSubType.ACTIONFORE_RETURN,
            } )
        end
        if _armyChangeInfo then
            _armyChangeInfo.preCostActionForce = 0
        end
    end
end

---@see 判断行军目标是否存在
function ArmyMarchLogic:checkMarchTargetExist( _rid, _targetArg, _marchType, _armyIndexs )
    local targetInfo
    if _marchType ~= Enum.MapMarchTargetType.SPACE then
        if _marchType == Enum.MapMarchTargetType.RETREAT then
            -- 撤退
            local cityIndex = RoleLogic:getRoleCityIndex( _rid )
            targetInfo = MSM.MapObjectTypeMgr[cityIndex].req.getObjectInfo( cityIndex )
            _targetArg = {}
        elseif _marchType == Enum.MapMarchTargetType.STATION then
            -- 驻扎
            _targetArg = {}
        elseif _marchType == Enum.MapMarchTargetType.ATTACK or _marchType == Enum.MapMarchTargetType.COLLECT then
            -- 攻击、采集行军
            if not _targetArg or not _targetArg.targetObjectIndex then
                LOG_ERROR("rid(%d) March error, no targetObjectIndex arg", _rid)
                return nil, ErrorCode.ROLE_ARG_ERROR
            end
            targetInfo = MSM.MapObjectTypeMgr[_targetArg.targetObjectIndex].req.getObjectInfo( _targetArg.targetObjectIndex )
            if not targetInfo or table.empty( targetInfo ) then
                LOG_ERROR("rid(%d) March error, targetObjectIndex(%d) not exist", _rid, _targetArg.targetObjectIndex)
                return nil, ErrorCode.ROLE_MARCH_TARGET_NOT_EXIST
            end

            if _marchType == Enum.MapMarchTargetType.ATTACK then
                -- 不能攻击自己或者联盟成员
                if targetInfo.objectType == Enum.RoleType.ARMY then
                    -- 不能攻击自己
                    if targetInfo.rid == _rid then
                        LOG_ERROR("rid(%d) March error, can't attack self army", _rid)
                        return nil, ErrorCode.MAP_CANNOT_ATTACK_SELF
                    end

                    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
                    if guildId > 0 then
                        -- 同联盟,无法攻击
                        if guildId == RoleLogic:getRole( targetInfo.rid, Enum.Role.guildId ) then
                            LOG_ERROR("rid(%d) March error, can't attack guild member(%d) army", _rid, targetInfo.rid)
                            return nil, ErrorCode.MAP_CANNOT_ATTACK_SELF
                        end
                    end

                    -- 不能攻击溃败的部队
                    if ArmyLogic:checkArmyStatus( targetInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
                        LOG_ERROR("rid(%d) March error, can't attack failed army", _rid)
                        return nil, ErrorCode.MAP_ATTACK_FAIL_ARMY
                    end
                elseif targetInfo.objectType == Enum.RoleType.MONSTER_CITY then
                    -- 野蛮人城寨只能集结攻击
                    LOG_ERROR("rid(%d) March error, can't attack monster city", _rid)
                    return nil, ErrorCode.MAP_MONSTER_CITY_ONLY_RALLY
                end
            else
                -- 采集行军
                if not MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) and #_armyIndexs > 1 then
                    LOG_ERROR("rid(%d) March error, objectType(%d) can't multi army", _rid, targetInfo.objectType)
                    return nil, ErrorCode.MAP_MULTI_ARMY_SAME_TARGET
                end
            end
        else
            LOG_ERROR("rid(%d) March error, no support marchType(%d) arg", _rid, _marchType)
            return nil, ErrorCode.ROLE_ARG_ERROR
        end
        if _targetArg then
            -- 过滤客户端垃圾数据
            _targetArg.pos = nil
        end
    else
        if _targetArg then
            -- 过滤客户端垃圾数据
            _targetArg.targetObjectIndex = nil
        end
    end

    return targetInfo
end

---@see 获取空地坐标和状态
function ArmyMarchLogic:getSpacePosAndStatus( _targetArg, _fixLen, _curPos )
    if not _fixLen or _fixLen <= 0 then
        -- 第一支部队空地行军不需要修正坐标
        return _targetArg.pos, Enum.ArmyStatus.SPACE_MARCH
    else
        -- 计算出角度
        local angle = ArmyWalkLogic:cacleAnagle( _targetArg.pos, _curPos )
        local toPos = {
            x = _targetArg.pos.x + math.ceil( _fixLen * math.cos( math.rad( angle ) ) ),
            y = _targetArg.pos.y + math.ceil( _fixLen * math.sin( math.rad( angle ) ) ),
        }

        return toPos, Enum.ArmyStatus.SPACE_MARCH
    end
end

---@see 获取攻击行军的坐标和状态
function ArmyMarchLogic:getAttackPosAndStatus( _rid, _targetArg, _targetInfo, _roleInfo, _isSituStation, _armyInfo )
    local needActiveForce = 0
    local targetPos
    local roleSituStation = _roleInfo.situStation
    local armyStatus = Enum.ArmyStatus.ATTACK_MARCH
    local roleGuildId
    if _rid and _rid > 0 then
        roleGuildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    end
    local targetIndex = _targetArg.targetObjectIndex
    if _targetInfo.objectType == Enum.RoleType.MONSTER then
        -- 怪物
        local sMonster = CFG.s_Monster:Get( _targetInfo.monsterId )
        needActiveForce = sMonster.costAP

        if sMonster.type == Enum.MonsterType.BARBARIAN then
            -- 野蛮人, 检测当前野蛮人等级是否 > 已挑战最高野蛮人等级 + 1
            if sMonster.level > ( _roleInfo.barbarianLevel or 0 ) + 1 then
                LOG_ERROR("rid(%d) March, monsterid(%d) level too high", _rid, _targetInfo.monsterId)
                return nil, ErrorCode.MAP_MONSTER_LEVEL_TOO_HIGH
            end
        end
        targetPos = _targetInfo.pos
        if _isSituStation then
            armyStatus = ArmyLogic:addArmyStatus( armyStatus, Enum.ArmyStatus.STATIONING )
            roleSituStation = true
        else
            roleSituStation = false
        end
    elseif _targetInfo.objectType == Enum.RoleType.CITY then
        -- 判断等级是否满足
        if RoleLogic:getRole( _rid, Enum.Role.level ) < CFG.s_Config:Get("attackCityLevel") then
            return nil, ErrorCode.MAP_ATTACK_CITY_LEVEL_ERROR
        end
        -- 是否是同盟玩家
        if roleGuildId > 0 and roleGuildId == RoleLogic:getRole( _targetInfo.rid, Enum.Role.guildId ) then
            return nil, ErrorCode.MAP_ATTACK_GUILD_MEMBER
        end
        -- 判断目标是否处于护盾内
        if RoleLogic:checkShield( _targetInfo.rid ) then
            -- 发送邮件
            local guildAndRoleName = RoleLogic:getGuildNameAndRoleName( _targetInfo.rid )
            local emailArg = { guildAndRoleName }
            EmailLogic:sendEmail( _rid, 110000, { subTitleContents = emailArg, emailContents = emailArg } )
            return nil, ErrorCode.MAP_ATTACK_SHILED
        end
        -- 城市
        targetPos = RoleLogic:getRole( _targetInfo.rid, Enum.Role.pos )
    elseif _targetInfo.objectType == Enum.RoleType.ARMY then
        -- 不可攻击自己的军队
        if _targetInfo.rid == _rid then
            return nil, ErrorCode.MAP_CANNOT_ATTACK_SELF
        end
        -- 是否是同盟玩家
        if roleGuildId > 0 and roleGuildId == RoleLogic:getRole( _targetInfo.rid, Enum.Role.guildId ) then
            return nil, ErrorCode.MAP_ATTACK_GUILD_MEMBER
        end
        -- 军队
        targetPos = _targetInfo.pos
    elseif MapObjectLogic:checkIsAttackGuildBuildObject( _targetInfo.objectType ) then
        -- 联盟建筑,判断目标是否与联盟领地接壤
        if not GuildTerritoryLogic:checkObjectGuildTerritory( targetIndex, roleGuildId ) then
            LOG_ERROR("rid(%d) March checkObjectGuildTerritory with guild fail", _rid)
            return nil, ErrorCode.RALLY_TARGET_NOT_BORDER
        end
        targetPos = _targetInfo.pos
    elseif MapObjectLogic:checkIsResourceObject( _targetInfo.objectType ) then
        -- 进攻资源点
        if not ArmyLogic:checkAttacKResourceArmy( _rid, targetIndex ) then
            -- 资源点内无部队,无法进攻
            return nil, ErrorCode.MAP_RESOURCE_NO_ARMY
        end
        targetPos = _targetInfo.pos
    elseif _targetInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND then
        -- 圣地守护者
        targetPos = _targetInfo.pos
        if _isSituStation then
            armyStatus = ArmyLogic:addArmyStatus( armyStatus, Enum.ArmyStatus.STATIONING )
            roleSituStation = true
        else
            roleSituStation = false
        end
    elseif MapObjectLogic:checkIsHolyLandObject( _targetInfo.objectType ) then
        -- 圣地建筑,判断目标是否与联盟领地接壤
        if not GuildTerritoryLogic:checkObjectGuildTerritory( targetIndex, roleGuildId ) then
            LOG_ERROR("rid(%d) March checkObjectGuildTerritory with holyland fail", _rid)
            return nil, ErrorCode.RALLY_TARGET_NOT_BORDER
        end
        -- 判断是否有在保护期内
        local holyLandStatus = _targetInfo.holyLandStatus
        if holyLandStatus == Enum.HolyLandStatus.INIT_PROTECT or holyLandStatus == Enum.HolyLandStatus.LOCK
            or holyLandStatus == Enum.HolyLandStatus.PROTECT then
            LOG_ERROR("rid(%d) March CheckPoint or Relic in lock or protect status", _rid)
            return nil, ErrorCode.RALLY_HOLYLAND_PROTECT_STATUS
        end

        targetPos = _targetInfo.pos
    elseif _targetInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        if _armyInfo.rid and _armyInfo.rid > 0 and _targetInfo.rid and _targetInfo.rid <= 0 then
            targetPos = MSM.SceneExpeditionMgr[targetIndex].req.getExpeditionPos( targetIndex )
        elseif _armyInfo.rid and _armyInfo.rid <= 0 and _targetInfo.rid and _targetInfo.rid > 0  then
            targetPos = MSM.SceneExpeditionMgr[targetIndex].req.getExpeditionPos( targetIndex )
        else
            return nil, ErrorCode.EXPEDITION_ATTACK_SELF_ARMY
        end
    elseif _targetInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        -- 召唤怪物
        local sMonster = CFG.s_Monster:Get( _targetInfo.monsterId )
        needActiveForce = sMonster.costAP
        targetPos = _targetInfo.pos
        if _isSituStation then
            armyStatus = ArmyLogic:addArmyStatus( armyStatus, Enum.ArmyStatus.STATIONING )
            roleSituStation = true
        else
            roleSituStation = false
        end
    else
        return nil, ErrorCode.MAP_INVALID_ATTACK_TARGET
    end

    -- 扣除统帅减免行动力
    if needActiveForce > 0 and _rid then
        needActiveForce = HeroLogic:subHeroVitality( _rid, _armyInfo, nil, nil, needActiveForce )
    end

    -- 扣除野蛮人扫荡效果行动力减免
    if needActiveForce > 0 and _rid then
        needActiveForce = ArmyLogic:cacleKillMonsterReduceVit( _rid, _armyInfo.armyIndex, needActiveForce )
    end

    return targetPos, armyStatus, roleSituStation, targetIndex, needActiveForce
end

---@see 获取采集行军坐标和状态
function ArmyMarchLogic:getCollectPosAndStatus( _rid, _targetArg, _roleInfo, _isSituStation, _armyInfo )
    local targetInfo = MSM.MapObjectTypeMgr[_targetArg.targetObjectIndex].req.getObjectInfo( _targetArg.targetObjectIndex )
    local pos, scienceReq
    local armyStatus = Enum.ArmyStatus.COLLECT_MARCH
    local roleSituStation = _roleInfo.situStation
    if MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
        if targetInfo.collectRid and targetInfo.collectRid > 0 then
            if targetInfo.collectRid == _rid then
                -- 部队当前已在采集该采集对象
                LOG_ERROR("rid(%d) March, role collect this resource targetObjectIndex(%d)", _rid, _targetArg.targetObjectIndex)
                return nil, ErrorCode.MAP_COLLECT_THIS_RESOURCE
            else
                -- 被其他人采集中
                LOG_ERROR("rid(%d) March, other role(%d) collect this resouceId(%d)", _rid, targetInfo.collectRid, targetInfo.resourceId)
                return nil, ErrorCode.ROLE_OTHER_COLLECT_RESOURCE
            end
        end

        -- 角色负载是否已满
        local sResourceGatherType = CFG.s_ResourceGatherType:Get( targetInfo.resourceId )
        local leftLoad = ResourceLogic:getArmyLoad( _rid, _armyInfo.armyIndex, _armyInfo ) - ResourceLogic:getArmyUseLoad( _rid, _armyInfo.armyIndex, _armyInfo )
        if ResourceLogic:loadToResourceCount( sResourceGatherType.type, leftLoad ) < 1 then
            LOG_ERROR("rid(%d) March, role army load full", _rid)
            return nil, ErrorCode.ROLE_ARMY_LOAD_FULL
        end

        scienceReq = sResourceGatherType.scienceReq
        pos = targetInfo.pos
    elseif targetInfo.objectType >= Enum.RoleType.GUILD_FOOD_CENTER and targetInfo.objectType <= Enum.RoleType.GUILD_GOLD_CENTER then
        -- 联盟资源中心
        if targetInfo.guildId ~= _roleInfo.guildId then
            LOG_ERROR("rid(%d) March, resource center not self guild", _rid)
            return nil, ErrorCode.ROLE_COLLECT_CENTER_NOT_SELF_GUILD
        end

        -- 角色等级是否满足采集条件
        if _roleInfo.level < CFG.s_Config:Get( "allianceResourcePointReqLevel" ) then
            LOG_ERROR("rid(%d) March, role level not enough", _rid)
            return nil, ErrorCode.GUILD_CREATE_BUILD_LEVEL_ERROR
        end

        -- 是否已有角色部队在采集
        local buildInfo = GuildBuildLogic:getGuildBuild( targetInfo.guildId, targetInfo.buildIndex )
        for _, reinforce in pairs( buildInfo.reinforces or {} ) do
            if reinforce.rid == _rid then
                LOG_ERROR("rid(%d) March, role already collect in resource center", _rid)
                return nil, ErrorCode.ROLE_COLLECT_CENTER_ONE_ARMY
            end
        end

        -- 角色负载是否已满
        local leftLoad = ResourceLogic:getArmyLoad( _rid, _armyInfo.armyIndex, _armyInfo ) - ResourceLogic:getArmyUseLoad( _rid, _armyInfo.armyIndex, _armyInfo )
        local resourceType = GuildBuildLogic:resourceBuildTypeToResourceType( buildInfo.type )
        if ResourceLogic:loadToResourceCount( resourceType, leftLoad ) < 1 then
            LOG_ERROR("rid(%d) March, role army load full", _rid)
            return nil, ErrorCode.ROLE_ARMY_LOAD_FULL
        end

        scienceReq = CFG.s_AllianceBuildingType:Get( buildInfo.type, "scienceReq" )
        pos = buildInfo.pos
    elseif targetInfo.objectType == Enum.RoleType.RUNE then
        pos = targetInfo.pos
        if _isSituStation then
            armyStatus = ArmyLogic:addArmyStatus( armyStatus, Enum.ArmyStatus.STATIONING )
            roleSituStation = true
        else
            roleSituStation = false
        end
    end

    -- 所需科技是否学习
    if scienceReq and scienceReq > 0 and not _roleInfo.technologies[scienceReq] then
        LOG_ERROR("rid(%d) March, not study technology(%d)", _rid, scienceReq)
        return nil, ErrorCode.ROLE_RESOURCE_NO_TECHNOLOGY
    end

    -- 未找到坐标返回错误码
    if not pos then
        armyStatus = ErrorCode.MAP_OBJECT_CANT_COLLECT
    end

    return pos, armyStatus, roleSituStation, _targetArg.targetObjectIndex
end

---@see 获取撤退行军坐标和状态
function ArmyMarchLogic:getRetreatPosAndStatus( _rid, _roleInfo )
    local targetObjectIndex = RoleLogic:getRoleCityIndex( _rid )
    return _roleInfo.pos, Enum.ArmyStatus.RETREAT_MARCH, targetObjectIndex
end

---@see 获取驻扎坐标和状态
function ArmyMarchLogic:getStationPosAndStatus( _rid, _armyIndex, _armyInfo, _expedition )
    local pos
    if _expedition then
        return _armyInfo.pos, Enum.ArmyStatus.STATIONING
    else
        local objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyIndex )
        if objectIndex then
            pos = MSM.SceneArmyMgr[objectIndex].req.getArmyPos( objectIndex )
            -- 判断是否处于不可行走区域内
            if not SM.NavMeshMapMgr.req.checkPosIdle( pos, 0.1 ) then
                return nil, ErrorCode.MAP_STATION_OBSTRACLE
            end
        end
    end
    return pos, Enum.ArmyStatus.STATIONING
end

---@see 获取目标点坐标
function ArmyMarchLogic:getTargetPos( _rid, _targetType, _targetArg, _targetInfo,
            _roleInfo, _armyInfo, _isSituStation, _expedition, _fixLen, _curPos )
    local targetPos, armyStatus, targetObjectIndex, needActiveForce
    local roleSituStation = _roleInfo.situStation
    if _targetType == Enum.MapMarchTargetType.SPACE then
        -- 向空地行军
        targetPos, armyStatus = self:getSpacePosAndStatus( _targetArg, _fixLen, _curPos )
    elseif _targetType == Enum.MapMarchTargetType.ATTACK then
        -- 进攻行军
        targetPos, armyStatus, roleSituStation, targetObjectIndex, needActiveForce = self:getAttackPosAndStatus( _rid, _targetArg, _targetInfo, _roleInfo, _isSituStation, _armyInfo )
    elseif _targetType == Enum.MapMarchTargetType.COLLECT then
        -- 采集行军, 采集对象是否存在
        targetPos, armyStatus, roleSituStation, targetObjectIndex = self:getCollectPosAndStatus( _rid, _targetArg, _roleInfo, _isSituStation, _armyInfo )
    elseif _targetType == Enum.MapMarchTargetType.RETREAT then
        -- 撤退行军
        targetPos, armyStatus, targetObjectIndex = self:getRetreatPosAndStatus( _rid, _roleInfo )
    elseif _targetType == Enum.MapMarchTargetType.STATION then
        -- 驻扎
        targetPos, armyStatus = self:getStationPosAndStatus( _rid, _armyInfo.armyIndex, _armyInfo, _expedition )
    end

    return {
        targetPos = targetPos,
        armyStatus = armyStatus,
        targetObjectIndex = targetObjectIndex,
        roleSituStation = roleSituStation,
        needActiveForce = needActiveForce
    }
end

---@see 获取部队起始点
function ArmyMarchLogic:getArmyPos( _rid, _armyInfo )
    local fromPos
    local armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyInfo.armyIndex )
    local ftype, fromArmyRadius
    if armyObjectIndex then
        fromPos = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyPos(armyObjectIndex)
    else
        fromPos = _armyInfo.targetArg and _armyInfo.targetArg.pos
        local targetObjectIndex = _armyInfo.targetArg and _armyInfo.targetArg.targetObjectIndex
        if targetObjectIndex then
            local targetTypeInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
            if targetTypeInfo then
                ftype = targetTypeInfo.objectType
                fromArmyRadius = targetTypeInfo.armyRadius
            end
        end
        -- 未找到部队坐标，取城市坐标，避免部队无法正常操作
        if not fromPos then
            fromPos = RoleLogic:getRole( _rid, Enum.Role.pos )
            ftype = Enum.RoleType.CITY
        end
    end
    return fromPos, ftype, fromArmyRadius
end

---@see 处理队伍行军
function ArmyMarchLogic:dispatchArmyMarch( _rid, _armyInfo, _targetArg, _targetType, _targetPos, _armyStatus,
                                            _targetObjectIndex, _armyChangeInfo, _oldTargetIndex, _roleInfo, _targetInfo )
    local oldStatus = _armyInfo.status
    -- 更新军队属性
    _armyChangeInfo.targetType = _targetType
    if _targetArg then
        _armyChangeInfo.targetArg = {
            pos = _targetArg.pos,
            targetObjectIndex = _targetArg.targetObjectIndex,
            oldTargetObjectIndex = _oldTargetIndex,
        }

        -- 如果目标是资源点,更新部队的目标资源点ID
        if _targetInfo and MapObjectLogic:checkIsResourceObject( _targetInfo.objectType ) then
            _armyChangeInfo.targetArg.targetResourceId = _targetInfo.resourceId
        end
    end

    -- 更新部队属性
    ArmyLogic:setArmy( _rid, _armyInfo.armyIndex, _armyChangeInfo )
    _armyChangeInfo.status = nil
    -- 通知客户端
    ArmyLogic:syncArmy( _rid, _armyInfo.armyIndex, _armyChangeInfo, true )

    local oldTargetInfo
    if _oldTargetIndex then
        oldTargetInfo = MSM.MapObjectTypeMgr[_oldTargetIndex].req.getObjectInfo( _oldTargetIndex )
    end

    if oldTargetInfo and MapObjectLogic:checkIsGuildBuildObject( oldTargetInfo.objectType ) and oldTargetInfo.guildId == _roleInfo.guildId then
        -- 在联盟建筑中驻守的部队行军
        local args = {
            targetType = _targetType,
            targetObjectIndex = _targetArg and _targetArg.targetObjectIndex or nil,
            targetPos = _targetPos
        }
        -- 召回，增加城市目标
        if _targetType == Enum.MapMarchTargetType.RETREAT then
            args.targetObjectIndex = _targetObjectIndex
        end
        args.armyStatus = _armyStatus
        -- 联盟建筑中的部队行军
        MSM.GuildMgr[_roleInfo.guildId].post.guildBuildArmyMarch( _roleInfo.guildId, oldTargetInfo.buildIndex, _rid,
                                                                _armyInfo.armyIndex, args, _oldTargetIndex, nil, _targetInfo )
    elseif ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.COLLECTING ) then
        -- 部队野外资源点采集中
        local resourceArgs = {
            targetType = _targetType,
            targetObjectIndex = _targetArg and _targetArg.targetObjectIndex or nil,
            targetPos = _targetPos
        }
        -- 召回，增加城市目标
        if _targetType == Enum.MapMarchTargetType.RETREAT then
            resourceArgs.targetObjectIndex = _targetObjectIndex
        end
        if oldTargetInfo then
            local serviceIndex = MapLogic:getObjectService( oldTargetInfo.pos )
            MSM.ResourceMgr[serviceIndex].req.callBackArmy( _rid, _armyInfo.armyIndex, resourceArgs )
        end
    elseif oldTargetInfo and MapObjectLogic:checkIsHolyLandObject( oldTargetInfo.objectType )
        and ( ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.REINFORCE_MARCH )
        or ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.GARRISONING ) ) then
        -- 增援联盟圣地关卡部队的处理
        local args = {
            targetType = _targetType,
            targetObjectIndex = _targetArg and _targetArg.targetObjectIndex or nil,
            targetPos = _targetPos
        }
        -- 召回，增加城市目标
        if _targetType == Enum.MapMarchTargetType.RETREAT then
            args.targetObjectIndex = _targetObjectIndex
        end
        args.armyStatus = _armyStatus
        MSM.GuildMgr[_roleInfo.guildId].req.holyLandArmyMarch( _roleInfo.guildId, _oldTargetIndex, _rid, _armyInfo.armyIndex, args, _targetInfo )
    elseif oldTargetInfo and ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.GARRISONING )
        and oldTargetInfo.objectType == Enum.RoleType.CITY then
        -- 部队在盟友城市中驻扎
        CityReinforceLogic:cancleReinforceCity( oldTargetInfo.rid, _rid, true )
        local toPos = _targetArg and _targetArg.pos
        local toType, targetArmyRadius
        if _targetInfo then
            toPos = _targetInfo.pos
            toType, targetArmyRadius = _targetInfo.objectType, _targetInfo.armyRadius
        end
        local cityRadius = CFG.s_Config:Get("cityRadius") * 100
        ArmyLogic:armyEnterMap( _rid, _armyInfo.armyIndex, _armyInfo, Enum.RoleType.CITY, toType, oldTargetInfo.pos,
                                toPos, _targetObjectIndex, _targetType, cityRadius, targetArmyRadius )
    else
        local objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, _armyInfo.armyIndex )
        if objectIndex then
            if _targetType == Enum.MapMarchTargetType.STATION then
                -- 驻扎,更新部队目标
                if _targetType == Enum.MapMarchTargetType.STATION then
                    ArmyLogic:updateArmyInfo( _rid, _armyInfo.armyIndex, { [Enum.Army.targetArg] = {} } )
                end
                MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, _targetObjectIndex, _targetPos, _armyStatus, _targetType )
            else
                -- 获取目标
                if not _targetObjectIndex and _targetArg then
                    _targetObjectIndex = _targetArg.targetObjectIndex
                end
                -- 部队移动
                if MSM.MapMarchMgr[objectIndex].req.armyMove( objectIndex, _targetObjectIndex, _targetPos, _armyStatus ) then
                    if _targetType == Enum.MapMarchTargetType.RETREAT then
                        ArmyLogic:updateArmyInfo( _rid, _armyInfo.armyIndex, { [Enum.Army.targetArg] = {} } )
                    end
                else
                    return
                end
            end
        end
    end
end

---@see 处理远征队伍行军
function ArmyMarchLogic:dispatchExpeditionMarch( _rid, _objectIndex, _targetArg, _targetType, _targetPos, _armyStatus,
                                            _targetObjectIndex )

    local objectInfo = MSM.SceneExpeditionMgr[_objectIndex].req.getExpeditionInfo( _objectIndex )
    if objectInfo then
        if _targetType == Enum.MapMarchTargetType.STATION then
            -- 驻扎
            MSM.MapMarchMgr[_objectIndex].req.expeditionArmyMove( _objectIndex, _targetObjectIndex, _targetPos, _armyStatus, _targetType )
        else
            -- 获取目标
            if not _targetObjectIndex and _targetArg then
                _targetObjectIndex = _targetArg.targetObjectIndex
            end
            -- 部队移动
            MSM.MapMarchMgr[_objectIndex].req.expeditionArmyMove( _objectIndex, _targetObjectIndex, _targetPos, _armyStatus )
        end
    end
end

return ArmyMarchLogic