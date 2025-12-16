--[[
 * @file : Rally.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-05-07 14:14:11
 * @Last Modified time: 2020-05-07 14:14:11
 * @department : Arabic Studio
 * @brief : 集结协议处理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local BuildingLogic = require "BuildingLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local HeroLogic = require "HeroLogic"
local ArmyLogic = require "ArmyLogic"
local RepatriationLogic = require "RepatriationLogic"
local MapObjectLogic = require "MapObjectLogic"
local ArmyMarchLogic = require "ArmyMarchLogic"

---@see 发起集结
function response.LaunchRally( msg )
    local rid = msg.rid
    local mainHeroId = msg.mainHeroId
    local deputyHeroId = msg.deputyHeroId
    local soldiers = msg.soldiers
    local targetIndex = msg.targetIndex
    local rallyTimes = msg.rallyTimes

    -- 参数判断
    if not targetIndex or not mainHeroId or not soldiers then
        return nil, ErrorCode.RALLY_ARG_ERROR
    end

    -- 判断玩家是否加入了联盟
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.guildId, Enum.Role.level, Enum.Role.pos,
                                                Enum.Role.actionForce, Enum.Role.soldiers, Enum.Role.massTroopsCapacity,
                                                Enum.Role.massTroopsCapacityMulti } )

    -- 判断玩家市政厅等级
    local attackCityLevel = CFG.s_Config:Get("attackCityLevel")
    if roleInfo.guildId <= 0 and roleInfo.level < attackCityLevel then
        LOG_ERROR("rid(%d) LaunchRally no guild and level(%d) < attackCityLevel(%d) ", rid, roleInfo.level, attackCityLevel)
        return nil, ErrorCode.RALLY_ROLE_LEVEL_LESS
    end

    -- 判断是否拥有城堡建筑
    if table.empty( BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.CASTLE ) ) then
        LOG_ERROR("rid(%d) LaunchRally not castle build ", rid)
        return nil, ErrorCode.RALLY_NO_CASTLE_BUILD
    end

    -- 判断被集结目标
    local needActionFore
    local targetObjectInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
    if not targetObjectInfo then
        return nil, ErrorCode.RALLY_TARGET_NOT_FOUND
    end

    -- 判断路径是否连通
    local path = { roleInfo.pos, targetObjectInfo.pos }
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100
    if not ArmyWalkLogic:fixPathPoint( Enum.RoleType.CITY, targetObjectInfo.objectType, path, cityRadius, targetObjectInfo.armyRadius, nil, rid, nil, true ) then
        LOG_ERROR("rid(%d) LaunchRally path not found to targetIndex(%d)", rid, targetIndex)
        return nil, ErrorCode.RALLY_NO_PATH_TO_TARGET
    end

    if targetObjectInfo.objectType == Enum.RoleType.CITY then
        -- 集结玩家城市,判断目标市政厅等级
        local targetRoleInfo = RoleLogic:getRole( targetObjectInfo.rid, { Enum.Role.level, Enum.Role.pos, Enum.Role.guildId } )
        local rallyCityMinLevel = CFG.s_Config:Get("rallyCityMinLevel")
        if targetRoleInfo.level < rallyCityMinLevel and targetRoleInfo.guildId <= 0 then
            LOG_ERROR("rid(%d) LaunchRally targetCityLevel(%d) < rallyCityMinLevel(%d)", rid, targetRoleInfo.level, rallyCityMinLevel)
            return nil, ErrorCode.RALLY_TARGET_LEVEL_LESS
        end
        -- 判断是否有护盾
        if RoleLogic:checkShield( targetObjectInfo.rid ) then
            LOG_ERROR("rid(%d) LaunchRally targetRid(%d) has shield", rid, targetObjectInfo.rid)
            return nil, ErrorCode.RALLY_TARGET_IN_SHIELD
        end
    elseif MapObjectLogic:checkIsGuildBuildObject( targetObjectInfo.objectType ) then
        -- 联盟建筑,判断目标是否与联盟领地接壤
        if not GuildTerritoryLogic:checkObjectGuildTerritory( targetIndex, roleInfo.guildId ) then
            LOG_ERROR("rid(%d) LaunchRally checkObjectGuildTerritory with guild fail", rid)
            return nil, ErrorCode.RALLY_TARGET_NOT_BORDER
        end
    elseif targetObjectInfo.objectType == Enum.RoleType.CHECKPOINT or targetObjectInfo.objectType == Enum.RoleType.RELIC then
        -- 关卡、圣物,判断目标是否与联盟领地接壤
        if not GuildTerritoryLogic:checkObjectGuildTerritory( targetIndex, roleInfo.guildId ) then
            LOG_ERROR("rid(%d) LaunchRally checkObjectGuildTerritory with CheckPoint or Relic fail", rid)
            return nil, ErrorCode.RALLY_TARGET_NOT_BORDER
        end
        -- 判断是否有在保护期内
        local holyLandStatus = MSM.SceneHolyLandMgr[targetIndex].req.getHolyLandStatus( targetIndex )
        if holyLandStatus == Enum.HolyLandStatus.INIT_PROTECT or holyLandStatus == Enum.HolyLandStatus.LOCK
            or holyLandStatus == Enum.HolyLandStatus.PROTECT then
            LOG_ERROR("rid(%d) LaunchRally CheckPoint or Relic in lock or protect status", rid)
            return nil, ErrorCode.RALLY_HOLYLAND_PROTECT_STATUS
        end
    elseif targetObjectInfo.objectType == Enum.RoleType.MONSTER_CITY then
        -- 判断行动力是否足够
        local costActionFore = CFG.s_Monster:Get( targetObjectInfo.monsterId, "rallyAP" )
        if roleInfo.actionForce < costActionFore then
            LOG_ERROR("rid(%d) LaunchRally actionForce(%d) < rallyAP(%d)", rid, roleInfo.actionForce, costActionFore)
            return nil, ErrorCode.RALLY_ACTION_FORCE_NO_ENOUGH
        end
        needActionFore = costActionFore
    elseif targetObjectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND then
        -- 圣地守护者不能被集结
        LOG_ERROR("rid(%d) LaunchRally to guardHolyLand", rid)
        return nil, ErrorCode.MAP_CANNOT_RALLY_HOLY_LAND
    elseif targetObjectInfo.objectType == Enum.RoleType.ARMY then
        -- 集结部队,不能是同联盟
        if targetObjectInfo.guildId == roleInfo.guildId then
            return nil, ErrorCode.RALLY_SAME_GUILD
        end
    elseif targetObjectInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 召唤怪物
        local sMonster = CFG.s_Monster:Get( targetObjectInfo.monsterId )
        -- 行动力是否足够
        if sMonster.rallyAP > 0 and roleInfo.actionForce < sMonster.rallyAP then
            LOG_ERROR("rid(%d) LaunchRally error, actionForce(%d) < rallyAP(%d)", rid, roleInfo.actionForce, sMonster.rallyAP)
            return nil, ErrorCode.RALLY_ACTION_FORCE_NO_ENOUGH
        end
        needActionFore = sMonster.rallyAP
    else
        -- 无效的集结目标
        LOG_ERROR("rid(%d) LaunchRally error, invalid objectType(%d)", rid, targetObjectInfo.objectType)
        return nil, ErrorCode.RALLY_INVALID_TARGET
    end

    -- 不能是同联盟目标
    local targetGuildId = MSM.MapObjectTypeMgr[targetIndex].req.getObjectGuildId( targetIndex )
    if targetGuildId and roleInfo.guildId == targetGuildId then
        LOG_ERROR("rid(%d) LaunchRally error, same guilId", rid)
        return nil, ErrorCode.RALLY_SAME_GUILD
    end

    -- 判断是否有足够的士兵
    local soldierSum = 0
    for _, soldierInfo in pairs( soldiers ) do
        if not roleInfo.soldiers[soldierInfo.id] or roleInfo.soldiers[soldierInfo.id].num < soldierInfo.num then
            LOG_ERROR("rid(%d) LaunchRally, soldier type(%d) level(%d) not enough", rid, soldierInfo.type, soldierInfo.level)
            return nil, ErrorCode.ROLE_SOLDIER_NOT_ENOUGH
        end
        soldierSum = soldierSum + soldierInfo.num
    end

    -- 选择兵种数量是否大于0
    if soldierSum <= 0 then
        LOG_ERROR("rid(%d) LaunchRally, role not select soldier", rid)
        return nil, ErrorCode.ROLE_NOT_SELECT_SOLDIER
    end

    -- 判断主将
    if not HeroLogic:checkHeroExist( rid, mainHeroId ) then
        LOG_ERROR("rid(%d) LaunchRally, mainHeroId(%d) not exist", rid, mainHeroId)
        return nil, ErrorCode.ROLE_HERO_NOT_EXIST
    end
    -- 判断副将
    if not HeroLogic:checkHeroExist( rid, deputyHeroId ) then
        LOG_ERROR("rid(%d) LaunchRally, deputyHeroId(%d) not exist", rid, deputyHeroId)
        return nil, ErrorCode.ROLE_HERO_NOT_EXIST
    end

    local massTroopsCapacity = roleInfo.massTroopsCapacity
    local massTroopsCapacityMulti = roleInfo.massTroopsCapacityMulti
    -- 统帅技能天赋影响
    if mainHeroId and mainHeroId > 0 then
        massTroopsCapacity = massTroopsCapacity + HeroLogic:getHeroAttr( rid, mainHeroId, Enum.Role.massTroopsCapacity )
        massTroopsCapacityMulti = massTroopsCapacityMulti + HeroLogic:getHeroAttr( rid, mainHeroId, Enum.Role.massTroopsCapacityMulti )
    end
    if deputyHeroId and deputyHeroId > 0 then
        massTroopsCapacity = massTroopsCapacity + HeroLogic:getHeroAttr( rid, deputyHeroId, Enum.Role.massTroopsCapacity, true )
        massTroopsCapacityMulti = massTroopsCapacityMulti + HeroLogic:getHeroAttr( rid, deputyHeroId, Enum.Role.massTroopsCapacityMulti, true )
    end
    -- 是否超过集结容量
    local maxMassTroopsCapacity = math.floor( massTroopsCapacity * ( 1 + massTroopsCapacityMulti / 1000 ) )
    if soldierSum > maxMassTroopsCapacity then
        LOG_ERROR("rid(%d) LaunchRally, over maxMassTroopsCapacity(%d)", rid, maxMassTroopsCapacity)
        return nil, ErrorCode.RALLY_OVER_MAX_MASS_TROOPS
    end

    -- 主将、副将是否处于待命状态
    if not HeroLogic:checkHeroIdle( rid, { mainHeroId, deputyHeroId } ) then
        LOG_ERROR("rid(%d) LaunchRally, mainHeroId(%d) not wait status", rid, mainHeroId)
        return nil, ErrorCode.ROLE_HERO_NOT_WAIT_STATUS
    end

    -- 获取集结准备时间
    local sRallyTimes = CFG.s_RallyTimes:Get(Enum.RallyType.NORMAL)
    if not sRallyTimes then
        LOG_ERROR("rid(%d) LaunchRally, invalid rallyTimes with normal", rid)
        return nil, ErrorCode.RALLY_INVALID_READY_TIME
    end

    -- 扣除统帅减免行动力
    if needActionFore then
        needActionFore = HeroLogic:subHeroVitality( rid, nil, mainHeroId, deputyHeroId, needActionFore )
    end

    -- 创建集结队伍
    local targetType = targetObjectInfo.objectType
    local rallyRet, rallyError = MSM.RallyMgr[roleInfo.guildId].req.newRallyTeam( rid, roleInfo.guildId, mainHeroId, deputyHeroId,
                                                                soldiers, targetIndex, targetType,
                                                                sRallyTimes["rallyTime" .. rallyTimes], needActionFore, rallyTimes )
    if rallyRet then
        -- 目标是部队、城市、联盟建筑、圣地,触发战争狂热
        if targetType == Enum.RoleType.ARMY or targetType == Enum.RoleType.CITY
        or MapObjectLogic:checkIsGuildBuildObject( targetType) or MapObjectLogic:checkIsHolyLandObject( targetType ) then
            -- 触发战争狂热
            RoleLogic:addWarCrazy( rid )
        end
    else
        return nil, rallyError
    end
end

---@see 加入集群
function response.JoinRally( msg )
    local rid = msg.rid
    local mainHeroId = msg.mainHeroId
    local deputyHeroId = msg.deputyHeroId
    local soldiers = msg.soldiers
    local joinRid = msg.joinRid
    local armyIndex = msg.armyIndex

    -- 参数判断
    if not joinRid then
        return nil, ErrorCode.RALLY_ARG_ERROR
    end

    -- 不能加入自己的集结
    if rid == joinRid or joinRid <= 0 then
        return nil, ErrorCode.RALLY_JOIN_SELF
    end

    -- 判断士兵是否正常
    if soldiers then
        for _, soldierInfo in pairs(soldiers) do
            if soldierInfo.num <= 0 then
                return nil, ErrorCode.RALLY_ARG_ERROR
            end
        end
    end

    -- 判断是否加入了联盟
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not guildId or guildId <= 0 then
        return nil, ErrorCode.RALLY_JOIN_NO_GUILD
    end

    local joinRoleInfo = RoleLogic:getRole( joinRid, { Enum.Role.guildId, Enum.Role.massTroopsCapacity,
                                                        Enum.Role.massTroopsCapacityMulti, Enum.Role.pos } )
    -- 判断和目标是否同一联盟
    if joinRoleInfo.guildId <= 0 or guildId ~= joinRoleInfo.guildId then
        return nil, ErrorCode.RALLY_JOIN_NOT_SAME_GUILD
    end

    local fpos = RoleLogic:getRole( rid, Enum.Role.pos )
    local ftype
    local soldierSum
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100
    if armyIndex and armyIndex > 0 then
        -- 判断加入的部队是否处于战斗状态
        local armyInfo = ArmyLogic:getArmy( rid, armyIndex )
        if armyInfo.isInRally then
            return nil, ErrorCode.RALLY_ARMY_CANNOT_JOIN
        end

        -- 是否处于溃败状态
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
            LOG_ERROR("rid(%d) JoinRally, armyIndex(%d) in failed status", rid, armyIndex)
            return nil, ErrorCode.MAP_ARMY_FAILED_STATUS
        end

        -- 部队行军加入集结
        soldierSum = ArmyLogic:getArmySoldierCount( armyInfo.soldiers )
        -- 获取部队信息
        fpos, ftype = ArmyMarchLogic:getArmyPos( rid, armyInfo )
    else
        armyIndex = nil
        -- 参数检查
        if not mainHeroId or mainHeroId <= 0 or table.empty( soldiers or {} ) then
            LOG_ERROR("rid(%d) JoinRally, no mainHeroId(%s) or no soldiers(%s) arg", rid, tostring(mainHeroId), tostring(soldiers))
            return nil, ErrorCode.RALLY_ARG_ERROR
        end

        -- 判断主将
        if not HeroLogic:checkHeroExist( rid, mainHeroId ) then
            LOG_ERROR("rid(%d) JoinRally, mainHeroId(%d) not exist", rid, mainHeroId)
            return nil, ErrorCode.ROLE_HERO_NOT_EXIST
        end
        -- 判断副将
        if not HeroLogic:checkHeroExist( rid, deputyHeroId ) then
            LOG_ERROR("rid(%d) JoinRally, deputyHeroId(%d) not exist", rid, deputyHeroId)
            return nil, ErrorCode.ROLE_HERO_NOT_EXIST
        end

        -- 主将、副将是否处于待命状态
        if not HeroLogic:checkHeroIdle( rid, { mainHeroId, deputyHeroId } ) then
            LOG_ERROR("rid(%d) JoinRally, mainHeroId(%d) not wait status", rid, mainHeroId)
            return nil, ErrorCode.ROLE_HERO_NOT_WAIT_STATUS
        end

        soldierSum = ArmyLogic:getArmySoldierCount( soldiers )
    end

    -- 判断目的地是否可达
    local path = { fpos, joinRoleInfo.pos }
    if not ArmyWalkLogic:fixPathPoint( ftype, Enum.RoleType.CITY, path, cityRadius, cityRadius, nil, rid, nil, true ) then
        return nil, ErrorCode.RALLY_PATH_NOT_FOUND
    end

    -- 加入集结
    local joinRet, joinError = MSM.RallyMgr[joinRoleInfo.guildId].req.joinRallyTeam( joinRoleInfo.guildId, joinRid, rid, armyIndex, mainHeroId, deputyHeroId, soldiers, soldierSum )
    if not joinRet then
        return nil, joinError
    end
end

---@see 遣返集结部队
function response.RepatriationRally( msg )
    local rid = msg.rid
    local repatriationRid = msg.repatriationRid

    -- 参数判断
    if not repatriationRid then
        return nil, ErrorCode.RALLY_ARG_ERROR
    end

    -- 不能遣返自己的部队
    if rid == repatriationRid then
        return nil, ErrorCode.RALLY_REPARTRIATION_SELF
    end

    -- 遣返部队
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    local repatriationRet, repatriationError = MSM.RallyMgr[guildId].req.repatriationRallyArmy( rid, repatriationRid )
    if not repatriationRet then
        return nil, repatriationError
    end
end

---@see 解散集结部队
function response.DisbandRally( msg )
    local rid = msg.rid

    -- 解散集结部队
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    local disbandRet, disbandError = MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, rid )
    if not disbandRet then
        return nil, disbandError
    end
end

---@see 增援部队
function response.ReinforceRally( msg )
    local rid = msg.rid
    local reinforceObjectIndex = msg.reinforceObjectIndex
    local mainHeroId = msg.mainHeroId
    local deputyHeroId = msg.deputyHeroId
    local soldiers = msg.soldiers
    local armyIndex = msg.armyIndex
    local armyIndexs = msg.armyIndexs

    -- 参数判断
    if not reinforceObjectIndex then
        return nil, ErrorCode.RALLY_ARG_ERROR
    end

    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if guildId <= 0 then
        return nil, ErrorCode.RALLY_NOT_SAME_GUILD
    end

    -- 判断和目标是否同一联盟
    local targetGuildId = MSM.MapObjectTypeMgr[reinforceObjectIndex].req.getObjectGuildId( reinforceObjectIndex )
    if guildId ~= targetGuildId then
        return nil, ErrorCode.RALLY_NOT_SAME_GUILD
    end

    -- 获取增援的对象类型
    local targetObjectInfo = MSM.MapObjectTypeMgr[reinforceObjectIndex].req.getObjectInfo( reinforceObjectIndex )
    if not targetObjectInfo then
        return nil, ErrorCode.RALLY_REINFORCE_TARGET_NO_EXIST
    end

    -- 兼容老版本客户端处理
    if ( not armyIndexs or table.empty( armyIndexs ) ) and armyIndex and armyIndex > 0 then
        armyIndexs = { armyIndex }
    end

    local armySize = table.size( armyIndexs or {} )
    local objectType = targetObjectInfo.objectType
    -- 多部队只可以增援联盟建筑和圣地关卡
    if armySize > 1 then
        if objectType == Enum.RoleType.ARMY then
            -- 只能派出一支部队加入集结部队
            LOG_ERROR("rid(%d) ReinforceRally error, armyIndexs(%s) can't multi army reinforce rally", rid, tostring(armyIndexs))
            return nil, ErrorCode.RALLY_CANT_MULTI_REINFORCE_ARMY
        elseif objectType == Enum.RoleType.CITY then
            -- 只能派出一支部队增援同一盟友
            LOG_ERROR("rid(%d) ReinforceRally error, armyIndexs(%s) can't multi army reinforce city", rid, tostring(armyIndexs))
            return nil, ErrorCode.RALLY_CANT_MULTI_REINFORCE_CITY
        elseif MapObjectLogic:checkIsGuildResourceCenterObject( objectType ) then
            -- 联盟资源中心只能派一支部队
            LOG_ERROR("rid(%d) ReinforceRally error, armyIndexs(%s) can't multi army reinforce guild resource center", rid, tostring(armyIndexs))
            return nil, ErrorCode.RALLY_CANT_MULTI_SAME_OBJECT
        elseif MapObjectLogic:checkIsAttackGuildBuildObject( objectType ) and targetObjectInfo.guildBuildStatus == Enum.GuildBuildStatus.BUILDING then
            -- 建造中的联盟要塞或者旗帜只能派一支部队增援
            LOG_ERROR("rid(%d) ReinforceRally error, armyIndexs(%s) can't multi army reinforce building guild build", rid, tostring(armyIndexs))
            return nil, ErrorCode.RALLY_CANT_MULTI_SAME_OBJECT
        end
    end

    local reinforceArmys = {}
    local armyInfo, oldTargetIndex
    local reinforceArmyCount = 0
    local cityPos = RoleLogic:getRole( rid, Enum.Role.pos )
    if armySize > 0 then
        -- 已经创建的部队
        local newArmyIndexs = {}
        local armys = ArmyLogic:getArmy( rid ) or {}
        for _, index in pairs( armyIndexs ) do
            armyInfo = armys[index]
            if not armyInfo then
                LOG_ERROR("rid(%d) ReinforceRally error, armyIndex(%d) not exist", rid, index)
                return nil, ErrorCode.MAP_ARMY_NOT_EXIST
            end

            -- 集结驻防的部队无法操作
            if armyInfo.isInRally then
                LOG_ERROR("rid(%d) ReinforceRally error, armyIndex(%d) rally army", rid, index)
                return nil, ErrorCode.MAP_OPERATE_RALLY_ARMY
            end

            -- 是否处于溃败状态
            if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
                LOG_ERROR("rid(%d) ReinforceRally, armyIndex(%d) in failed status", rid, armyIndex)
                return nil, ErrorCode.MAP_ARMY_FAILED_STATUS
            end

            oldTargetIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex or nil
            if not oldTargetIndex or oldTargetIndex ~= reinforceObjectIndex then
                reinforceArmys[index] = {}
                reinforceArmys[index].armyInfo = armyInfo
                reinforceArmyCount = reinforceArmyCount + ArmyLogic:getArmySoldierCount( armyInfo.soldiers or {} )
                reinforceArmys[index].fpos, reinforceArmys[index].fromType, reinforceArmys[index].fromArmyRadius = ArmyMarchLogic:getArmyPos( rid, armyInfo )
                table.insert( newArmyIndexs, index )
            end
        end
        -- 无行军部队
        armyIndexs = newArmyIndexs
        if table.size( reinforceArmys ) <= 0 then
            return nil, ErrorCode.RALLY_ARG_ERROR
        end
    else
        -- 参数检查
        if not mainHeroId or mainHeroId <= 0 or table.empty( soldiers or {} ) then
            LOG_ERROR("rid(%d) ReinforceRally, no mainHeroId(%s) or no soldiers(%s) arg", rid, tostring(mainHeroId), tostring(soldiers))
            return nil, ErrorCode.RALLY_ARG_ERROR
        end

        -- 未创建的部队
        reinforceArmyCount = ArmyLogic:getArmySoldierCount( soldiers )
    end

    local needActionFore
    local reinforceRid = targetObjectInfo.rid
    local armyStatus = Enum.ArmyStatus.REINFORCE_MARCH
    local marchType = Enum.MapMarchTargetType.REINFORCE
    local targetObjectPos = MSM.MapObjectTypeMgr[reinforceObjectIndex].req.getObjectPos( reinforceObjectIndex )
    if objectType == Enum.RoleType.ARMY then
        -- 增援部队,判断目标是不是集结部队
        if not MSM.SceneArmyMgr[reinforceObjectIndex].req.checkIsRallyArmy( reinforceObjectIndex ) then
            return nil, ErrorCode.RALLY_REINFORCE_NOT_RALLY_ARMY
        end
        -- 判断集结目标是否是野蛮人城寨
        local rallyTargetType, rallyTargetIndex = MSM.RallyMgr[guildId].req.getRallyTargetType( reinforceRid )
        if rallyTargetType == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨
            local monsterCityInfo = MSM.SceneMonsterCityMgr[rallyTargetIndex].req.getMonsterCityInfo( rallyTargetIndex )
            needActionFore = CFG.s_Monster:Get( monsterCityInfo.monsterId, "rallyAP" )
        elseif rallyTargetType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 召唤怪物
            local monsterInfo = MSM.SceneMonsterMgr[rallyTargetIndex].req.getMonsterInfo( rallyTargetIndex )
            needActionFore = CFG.s_Monster:Get( monsterInfo.monsterId, "rallyAP" )
        end
        if needActionFore then
            -- 天赋减少行动力
            armyInfo = nil
            if armySize > 0 then
                armyInfo = reinforceArmys[armyIndexs[1]].armyInfo
            end
            needActionFore = HeroLogic:subHeroVitality( rid, armyInfo, mainHeroId, deputyHeroId, needActionFore )
            if armySize > 0 then
                -- 野蛮人扫荡效果减少行动力
                needActionFore = ArmyLogic:cacleKillMonsterReduceVit( rid, armyIndexs[1], needActionFore )
            end
        end
    elseif objectType == Enum.RoleType.CITY then
        -- 判断目标是否有联盟中心
        if BuildingLogic:getBuildingLv( reinforceRid, Enum.BuildingType.ALLIANCE_CENTER ) <= 0 then
            return nil, ErrorCode.RALLY_NOT_ALLIANCE_CENTER
        end
        -- 增援城市,判断是否已经增援过,城市只能增援一只队伍,并且城市增援是否已满
        local ret = MSM.CityReinforceMgr[reinforceRid].req.isReinforceCityOrFull( reinforceRid, rid, reinforceArmyCount )
        if not ret then
            if ret == nil then
                return nil, ErrorCode.RALLY_REINFORCE_CITY_FAIL_ARMY_FULL
            else
                return nil, ErrorCode.RALLY_REINFORCE_CITY_HAD_REINFORCE
            end
        end
    elseif MapObjectLogic:checkIsGuildResourceCenterObject( objectType ) then
        -- 资源中心采集行军
        local guildBuildStatus = MSM.SceneGuildBuildMgr[reinforceObjectIndex].req.getGuildBuildStatus( reinforceObjectIndex )
        if guildBuildStatus == Enum.GuildBuildStatus.NORMAL then
            armyStatus = Enum.ArmyStatus.COLLECT_MARCH
            marchType = Enum.MapMarchTargetType.COLLECT
        end
    elseif MapObjectLogic:checkIsHolyLandObject( objectType ) then
        -- 增援圣地关卡
        local holyLandInfo = MSM.SceneHolyLandMgr[reinforceObjectIndex].req.getHolyLandInfo( reinforceObjectIndex )
        if guildId ~= holyLandInfo.guildId then
            return nil, ErrorCode.RALLY_NOT_GUILD_HOLY_LAND
        end
    end

    -- 判断目的地是否可达
    local path
    if armySize > 0 then
        for index, reinforceArmy in pairs( reinforceArmys ) do
            path = { reinforceArmy.fpos, targetObjectPos }
            if not ArmyWalkLogic:fixPathPoint( reinforceArmy.fromType, objectType, path, reinforceArmy.fromArmyRadius, targetObjectInfo.armyRadius, nil, rid, nil, true ) then
                LOG_ERROR("rid(%d) ReinforceRally error, armyIndex(%d) path(%s) not found", rid, index, tostring(path))
                return nil, ErrorCode.MAP_MARCH_PATH_NOT_FOUND
            end
        end
    else
        path = { cityPos, targetObjectPos }
        if not ArmyWalkLogic:fixPathPoint( Enum.RoleType.CITY, objectType, path, CFG.s_Config:Get("cityRadius") * 100,
                    targetObjectInfo.armyRadius, nil, rid, nil, true ) then
            return nil, ErrorCode.MAP_MARCH_PATH_NOT_FOUND
        end
    end

    -- 体力判断
    if needActionFore and needActionFore > 0 then
        local actionForce = RoleLogic:getRole( rid, Enum.Role.actionForce )
        if actionForce < needActionFore then
            LOG_ERROR("rid(%d) ReinforceRally actionForce(%d) < rallyAP(%d)", rid, actionForce, needActionFore)
            return nil, ErrorCode.RALLY_ACTION_FORCE_NO_ENOUGH
        end
    end

    local isNewArmy
    if armySize <= 0 then
        -- 预创建部队
        local error
        armyIndex, armyInfo, error = ArmyLogic:createArmy( rid, mainHeroId, deputyHeroId, soldiers, needActionFore,
                                                    marchType, { targetObjectIndex = reinforceObjectIndex }, armyStatus )
        if not armyIndex then
            return nil, error or ErrorCode.RALLY_CREATE_ARMY_FAIL
        end
        armyIndexs = { armyIndex }
        reinforceArmys[armyIndex] = {}
        reinforceArmys[armyIndex].armyInfo = armyInfo
        reinforceArmys[armyIndex].fromType = Enum.RoleType.CITY
        reinforceArmys[armyIndex].fromArmyRadius = CFG.s_Config:Get("cityRadius") * 100
        isNewArmy = true
    else
        -- 扣除行动力
        if needActionFore and needActionFore > 0 then
            -- 删除预扣除的活动力
            ArmyLogic:setArmy( rid, armyIndexs[1], { [Enum.Army.preCostActionForce] = needActionFore } )
            -- 通知客户端预扣除行动力
            ArmyLogic:syncArmy( rid, armyIndexs[1], { [Enum.Army.preCostActionForce] = needActionFore }, true )
            -- 预扣除角色行动力
            RoleLogic:addActionForce( rid, - needActionFore, nil, Enum.LogType.ATTACK_COST_ACTION )
        end

        -- 取消部队符文采集
        armyInfo = reinforceArmys[armyIndexs[1]].armyInfo
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING_NO_DELETE ) then
            local targetArg = armyInfo.targetArg or {}
            if targetArg.targetObjectIndex and targetArg.targetObjectIndex > 0 then
                MSM.RuneMgr[targetArg.targetObjectIndex].post.cancelCollectRune( rid, armyIndexs[1], targetArg.targetObjectIndex )
            end
        end
    end

    -- 判断增援的对象
    if MapObjectLogic:checkIsGuildBuildObject( objectType ) then
        -- 增援建造联盟建筑
        local ret, error = MSM.GuildMgr[guildId].req.reinforceGuildBuild( guildId, rid, reinforceObjectIndex, reinforceArmys )
        if not ret then
            if isNewArmy then
                -- 解散预创建的部队
                ArmyLogic:disbandArmy( rid, armyIndex )
            end
            return nil, error
        end
    elseif objectType == Enum.RoleType.ARMY then
        -- 增援集结部队
        armyIndex = armyIndexs[1]
        armyInfo = reinforceArmys[armyIndex].armyInfo
        local reinforceRet, reinforceError = MSM.RallyMgr[guildId].req.reinforceTarget( reinforceRid, rid, armyIndex, armyInfo,
                                                        reinforceObjectIndex, objectType, reinforceArmys[armyIndex].fromType )
        if not reinforceRet then
            if isNewArmy then
                -- 解散预创建的部队
                ArmyLogic:disbandArmy( rid, armyIndex )
            end
            return nil, reinforceError
        end
    elseif objectType == Enum.RoleType.CITY then
        -- 增援城市
        armyIndex = armyIndexs[1]
        local ret, error = MSM.CityReinforceMgr[reinforceRid].req.addCityReinforce( reinforceRid, rid, armyIndex, reinforceObjectIndex )
        if not ret then
            if isNewArmy then
                -- 解散预创建的部队
                ArmyLogic:disbandArmy( rid, armyIndex )
            end
            return nil, error
        end
    elseif MapObjectLogic:checkIsHolyLandObject( objectType ) then
        -- 增援圣地关卡
        local ret, error = MSM.GuildMgr[guildId].req.reinforceHolyLand( guildId, rid, reinforceObjectIndex, reinforceArmys )
        if not ret then
            if isNewArmy then
                -- 解散预创建的部队
                ArmyLogic:disbandArmy( rid, armyIndex )
            end
            return nil, error
        end
    end
end

---@see 遣返增援的部队
function response.RepatriationReinforce( msg )
    local rid = msg.rid
    local repatriationRid = msg.repatriationRid
    local fromObjectIndex = msg.fromObjectIndex
    local isSelfBack = msg.isSelfBack

    -- 获取遣返的目标类型
    local ret, error
    local fromObjectInfo = MSM.MapObjectTypeMgr[fromObjectIndex].req.getObjectType( fromObjectIndex )
    if fromObjectInfo.objectType == Enum.RoleType.CITY then
        -- 从城市遣返
        if isSelfBack then
            ret, error = RepatriationLogic:repatriationFromCity( repatriationRid, rid, true, true )
        else
            ret, error = RepatriationLogic:repatriationFromCity( rid, repatriationRid )
        end
    else
        -- 无效的目标类型
        ret, error = nil, ErrorCode.RALLY_REPATRIATION_REINFORCE_FAIL
    end

    return ret, error
end