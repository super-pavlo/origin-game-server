--[[
* @file : MapScoutsLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Fri May 22 2020 11:48:41 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 斥候侦查逻辑处理
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local MapObjectLogic = require "MapObjectLogic"
local MapLogic = require "MapLogic"
local GuildLogic = require "GuildLogic"
local BuildingLogic = require "BuildingLogic"
local Random = require "Random"
local HeroLogic = require "HeroLogic"
local ArmyLogic = require "ArmyLogic"
local EmailLogic = require "EmailLogic"
local Timer = require "Timer"
local GuildBuildLogic = require "GuildBuildLogic"
local TaskLogic = require "TaskLogic"
local ScoutsLogic = require "ScoutsLogic"
local LogLogic = require "LogLogic"

local MapScoutsLogic = {}

---@see 检查对象是否可以侦查
function MapScoutsLogic:checkScoutTargetInfo( _rid, _targetIndex )
    -- 侦查对象信息
    local targetInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectType( _targetIndex )
    if not targetInfo or table.empty( targetInfo ) then
        LOG_ERROR("rid(%d) checkScoutTargetInfo, targetIndex(%d) not exist", _rid, _targetIndex)
        return nil, ErrorCode.SCOUTS_TARGET_NOT_EXIST
    end

    local targetPos, scoutCampId, currencyType1, warCrazy, logType
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.level, Enum.Role.guildId, Enum.Role.iggid } )
    if targetInfo.objectType == Enum.RoleType.CAVE then
        -- 探索山洞, 检查山洞是否已被探索
        local resourceInfo = MSM.SceneResourceMgr[_targetIndex].req.getResourceInfo( _targetIndex )
        -- 是否已经探索过
        if RoleLogic:checkVillageCave( _rid, resourceInfo.resourcePointId ) then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, targetIndex(%d) resourcePointId(%d) already scout", _rid, _targetIndex, resourceInfo.resourcePointId)
            return nil, ErrorCode.MAP_CAVE_ALREADY_SCOUT
        end
        targetPos = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectPos( _targetIndex )
        logType = Enum.LogType.SCOUT_CAVE
    elseif targetInfo.objectType == Enum.RoleType.CITY then
        -- 侦查城市
        local cityInfo = MSM.SceneCityMgr[_targetIndex].req.getCityInfo( _targetIndex )
        local targetRoleInfo = RoleLogic:getRole( cityInfo.rid, { Enum.Role.level, Enum.Role.guildId } )
        -- 保护状态
        if RoleLogic:checkShield( cityInfo.rid ) then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, targetRid(%d) shield", _rid, cityInfo.rid)
            return nil, ErrorCode.SCOUTS_CITY_SHIELD
        end
        -- 是否同盟
        if roleInfo.guildId > 0 and roleInfo.guildId == targetRoleInfo.guildId then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, can't scout guild member", _rid)
            return nil, ErrorCode.SCOUTS_SAME_GUILDID
        end
        -- 目标城市超过角色等级10级，无法侦查
        local detectedLv = CFG.s_Config:Get( "detectedLv" ) or 10
        if roleInfo.level + detectedLv < targetRoleInfo.level then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, cityLevel(%d) too high", _rid, targetRoleInfo.level)
            return nil, ErrorCode.SCOUTS_TARGET_LEVEL_TOO_HIGH
        end

        targetPos = cityInfo.pos
        scoutCampId = targetRoleInfo.level
        currencyType1 = true
        warCrazy = true
        local name = RoleLogic:getRole( cityInfo.rid, Enum.Role.name )
        SM.PushMgr.post.sendPush( { pushRid = cityInfo.rid, pushType = Enum.PushType.SCOUT, args = { arg1 = name, arg2 = RoleLogic:getRole( _rid, Enum.Role.name ) } })
        logType = Enum.LogType.SCOUT_CITY
    elseif targetInfo.objectType == Enum.RoleType.ARMY then
        -- 侦查部队、集结部队
        local armyInfo = MSM.SceneArmyMgr[_targetIndex].req.getArmyInfo( _targetIndex )
        -- 目标城市超过角色等级10级，无法侦查
        local targetRoleInfo = RoleLogic:getRole( armyInfo.rid, { Enum.Role.level, Enum.Role.guildId } )
        -- 是否同盟
        if roleInfo.guildId > 0 and roleInfo.guildId == targetRoleInfo.guildId then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, can't scout guild member army", _rid)
            return nil, ErrorCode.SCOUTS_SAME_GUILDID
        end
        -- 是否同盟
        local detectedLv = CFG.s_Config:Get( "detectedLv" ) or 10
        if roleInfo.level + detectedLv < targetRoleInfo.level then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, cityLevel(%d) too high", _rid, targetRoleInfo.level)
            return nil, ErrorCode.SCOUTS_TARGET_LEVEL_TOO_HIGH
        end

        targetPos = armyInfo.pos
        scoutCampId = targetRoleInfo.level
        currencyType1 = true
        warCrazy = true
        logType = Enum.LogType.SCOUT_ARMY
    elseif MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
        -- 侦查采集点
        local resourceInfo = MSM.SceneResourceMgr[_targetIndex].req.getResourceInfo( _targetIndex )
        -- 资源点内是否有部队
        if not resourceInfo.collectRid or resourceInfo.collectRid <= 0 then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, not army collect resourceIndex(%d)", _rid, _targetIndex)
            return nil, ErrorCode.SCOUTS_RESOURCE_NOT_ARMY
        end
        local targetRoleInfo = RoleLogic:getRole( resourceInfo.collectRid, { Enum.Role.level, Enum.Role.guildId } )
        -- 目标城市超过角色等级10级，无法侦查
        local detectedLv = CFG.s_Config:Get( "detectedLv" ) or 10
        if roleInfo.level + detectedLv < targetRoleInfo.level then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, cityLevel(%d) too high", _rid, targetRoleInfo.level)
            return nil, ErrorCode.SCOUTS_TARGET_LEVEL_TOO_HIGH
        end
        -- 是否同盟
        if roleInfo.guildId > 0 and roleInfo.guildId == targetRoleInfo.guildId then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, can't scout guild member army", _rid)
            return nil, ErrorCode.SCOUTS_SAME_GUILDID
        end

        targetPos = resourceInfo.pos
        scoutCampId = targetRoleInfo.level
        currencyType1 = true
        warCrazy = true
        logType = Enum.LogType.SCOUT_ARMY
    elseif MapObjectLogic:checkIsAttackGuildBuildObject( targetInfo.objectType ) then
        -- 侦查联盟建筑
        local guildBuild = MSM.SceneGuildBuildMgr[_targetIndex].req.getGuildBuildInfo( _targetIndex )
        -- 是否同盟
        if roleInfo.guildId > 0 and roleInfo.guildId == guildBuild.guildId then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, can't scout guild build", _rid)
            return nil, ErrorCode.SCOUTS_SAME_GUILDID
        end

        targetPos = guildBuild.pos
        scoutCampId = roleInfo.level
        warCrazy = true
        logType = Enum.LogType.SCOUT_GUILD_BUILD
    elseif targetInfo.objectType == Enum.RoleType.CHECKPOINT or targetInfo.objectType == Enum.RoleType.RELIC then
        -- 侦查关卡、圣地
        local holyLand = MSM.SceneHolyLandMgr[_targetIndex].req.getHolyLandInfo( _targetIndex )
        -- 未开放、初始保期和保护期无法被侦查
        if holyLand.holyLandStatus == Enum.HolyLandStatus.LOCK
            or holyLand.holyLandStatus == Enum.HolyLandStatus.INIT_PROTECT
            or holyLand.holyLandStatus == Enum.HolyLandStatus.PROTECT then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, targetIndex(%d) can't scouted", _rid, _targetIndex)
            return nil, ErrorCode.SCOUTS_HOLYLAND_CANT_SCOUT
        end
        -- 是否同盟
        if roleInfo.guildId > 0 and roleInfo.guildId == ( holyLand.guildId or 0 ) then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, can't scout guild holyland", _rid)
            return nil, ErrorCode.SCOUTS_SAME_GUILDID
        end

        targetPos = holyLand.pos
        scoutCampId = roleInfo.level
        warCrazy = true
        logType = Enum.LogType.SCOUT_HOLYLAND
    else
        LOG_ERROR("rid(%d) checkScoutTargetInfo, not support scout objectType(%d)", _rid, targetInfo.objectType)
        return nil, ErrorCode.SCOUTS_NOT_SUPPORT_SCOUT_TYPE
    end

    -- 需要消耗的资源是否足够
    if scoutCampId then
        local type, num
        local sBuildingScoutcamp = CFG.s_BuildingScoutcamp:Get( scoutCampId )
        if currencyType1 then
            type = sBuildingScoutcamp.costCurrencyType1
            num = sBuildingScoutcamp.number1
        else
            type = sBuildingScoutcamp.costCurrencyType2
            num = sBuildingScoutcamp.number2
        end
        if not RoleLogic:checkRoleCurrency( _rid, type, num ) then
            LOG_ERROR("rid(%d) checkScoutTargetInfo, role currency not enough", _rid)
            return nil, ErrorCode.SCOUTS_CURRENCY_NOT_ENOUGH
        end
        -- 扣除资源
        RoleLogic:addRoleCurrency( _rid, type, - num, nil, Enum.LogType.SCOUT_COST_CURRENCY )
    end

    -- 添加战争狂热状态
    if warCrazy and roleInfo.level >= CFG.s_Config:Get( "activationWarFare" ) then
        RoleLogic:addWarCrazy( _rid )
    end

    -- 增加角色侦查次数
    TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.SCOUT_NUM, Enum.TaskArgDefault, 1 )
    -- 记录斥候日志
    LogLogic:roleScout( {
        logType = logType, iggid = roleInfo.iggid, logType2 = targetPos.x, logType3 = targetPos.y, rid = _rid
    } )

    return targetPos
end

---@see 根据追踪术等级整理部队数量
function MapScoutsLogic:getCityArmyCount( _roleInfo, _targetRoleInfo, _soldiers )
    local armyInfo = {}
    local soldiers = _soldiers or _targetRoleInfo.soldiers or {}
    local sConfig = CFG.s_Config:Get()
    local multi = 1
    -- 疑兵, 士兵数翻倍
    if RoleLogic:checkSusPect( _targetRoleInfo.rid ) then
        multi = 2
    end
    -- 追踪术
    local followTechnologyLevel = _roleInfo.technologies[sConfig.scoutStudy1] and _roleInfo.technologies[sConfig.scoutStudy1].level or 0
    -- 伪装术
    local pretendTechnologyLevel = _roleInfo.technologies[sConfig.scoutStudy2] and _roleInfo.technologies[sConfig.scoutStudy2].level or 0
    if followTechnologyLevel < 2 then
        armyInfo.armySumType = Enum.ScoutArmyType.NO_DETAIL
    elseif followTechnologyLevel < 3 then
        armyInfo.armySumType = Enum.ScoutArmyType.NO_ICON
        local soldierSum = 0
        for _, soldierInfo in pairs( soldiers ) do
            soldierSum = soldierSum + soldierInfo.num
        end
        soldierSum = soldierSum * multi
        local rate = Random.GetRange( -30, 30, 1 )[1]
        armyInfo.armySum = math.max( 100, math.floor( soldierSum * ( 100 + rate ) / 10000 // 1 * 100 ) )
    elseif followTechnologyLevel <= 4 then
        armyInfo.armySumType = Enum.ScoutArmyType.ICON
        -- 士兵信息
        local rate, soldierNum
        armyInfo.armySum = 0
        armyInfo.soldiers = {}
        for _, soldierInfo in pairs( soldiers ) do
            if soldierInfo.num > 0 then
                rate = Random.GetRange( -30, 30, 1 )[1]
                soldierNum = math.max( 100, math.floor( soldierInfo.num * multi * ( 100 + rate ) / 10000 // 1 * 100 ) )
                table.insert( armyInfo.soldiers, {
                    id = soldierInfo.id,
                    type = soldierInfo.type,
                    level = soldierInfo.level,
                    num = soldierNum,
                } )
                armyInfo.armySum = armyInfo.armySum + soldierNum
            end
        end
    else
        armyInfo.armySumType = Enum.ScoutArmyType.REAL_NUM
        armyInfo.armySum = 0
        armyInfo.soldiers = {}
        -- 士兵信息
        for _, soldierInfo in pairs( soldiers ) do
            if soldierInfo.num > 0 then
                table.insert( armyInfo.soldiers, {
                    id = soldierInfo.id,
                    type = soldierInfo.type,
                    level = soldierInfo.level,
                    num = soldierInfo.num * multi,
                } )
                armyInfo.armySum = armyInfo.armySum + soldierInfo.num * multi
            end
        end
    end
    -- 统帅信息
    if pretendTechnologyLevel < 1 then
        if _targetRoleInfo.mainHeroId and _targetRoleInfo.mainHeroId > 0 then
            armyInfo.mainHero = { heroId = _targetRoleInfo.mainHeroId }
        end
        if _targetRoleInfo.deputyHeroId and _targetRoleInfo.deputyHeroId > 0 then
            armyInfo.deputyHero = { heroId = _targetRoleInfo.deputyHeroId }
        end
    else
        if _targetRoleInfo.mainHeroId and _targetRoleInfo.mainHeroId > 0 then
            armyInfo.mainHero = HeroLogic:getHero( _targetRoleInfo.rid, _targetRoleInfo.mainHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
        end
        if _targetRoleInfo.deputyHeroId and _targetRoleInfo.deputyHeroId > 0 then
            armyInfo.deputyHero = HeroLogic:getHero( _targetRoleInfo.rid, _targetRoleInfo.deputyHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
        end
    end

    return armyInfo
end

---@see 根据追踪术等级整理部队数量
function MapScoutsLogic:getArmyCount( _roleInfo, _targetRoleInfo, _armyInfo )
    local armyInfo = {}
    local soldiers = _armyInfo.soldiers or {}
    local sConfig = CFG.s_Config:Get()
    -- 追踪术
    local followTechnologyLevel = _roleInfo.technologies[sConfig.scoutStudy1] and _roleInfo.technologies[sConfig.scoutStudy1].level or 0
    -- 伪装术
    local pretendTechnologyLevel = _roleInfo.technologies[sConfig.scoutStudy2] and _roleInfo.technologies[sConfig.scoutStudy2].level or 0
    if followTechnologyLevel < 2 then
        armyInfo.armySumType = Enum.ScoutArmyType.NO_DETAIL
    elseif followTechnologyLevel < 3 then
        armyInfo.armySumType = Enum.ScoutArmyType.NO_ICON
        local soldierSum = 0
        for _, soldierInfo in pairs( soldiers ) do
            soldierSum = soldierSum + soldierInfo.num
        end
        local rate = Random.GetRange( -30, 30, 1 )[1]
        armyInfo.armySum = math.max( 100, math.floor( soldierSum * ( 100 + rate ) / 10000 // 1 * 100 ) )
    elseif followTechnologyLevel <= 4 then
        armyInfo.armySumType = Enum.ScoutArmyType.ICON
        -- 士兵信息
        armyInfo.armySum = 0
        armyInfo.soldiers = {}
        local rate, soldierNum
        for _, soldierInfo in pairs( soldiers ) do
            if soldierInfo.num > 0 then
                rate = Random.GetRange( -30, 30, 1 )[1]
                soldierNum = math.max( 100, math.floor( soldierInfo.num * ( 100 + rate ) / 10000 // 1 * 100 ) )
                table.insert( armyInfo.soldiers, {
                    id = soldierInfo.id,
                    type = soldierInfo.type,
                    level = soldierInfo.level,
                    num = soldierNum,
                } )
                armyInfo.armySum = armyInfo.armySum + soldierNum
            end
        end
    else
        armyInfo.armySumType = Enum.ScoutArmyType.REAL_NUM
        armyInfo.armySum = 0
        -- 士兵信息
        armyInfo.soldiers = {}
        for _, soldierInfo in pairs( soldiers ) do
            if soldierInfo.num > 0 then
                table.insert( armyInfo.soldiers, {
                    id = soldierInfo.id,
                    type = soldierInfo.type,
                    level = soldierInfo.level,
                    num = soldierInfo.num,
                } )
                armyInfo.armySum = armyInfo.armySum + soldierInfo.num
            end
        end
    end
    -- 统帅信息
    if pretendTechnologyLevel < 1 then
        if _armyInfo.mainHeroId and _armyInfo.mainHeroId > 0 then
            armyInfo.mainHero = { heroId = _armyInfo.mainHeroId }
        end
        if _armyInfo.deputyHeroId and _armyInfo.deputyHeroId > 0 then
            armyInfo.deputyHero = { heroId = _armyInfo.deputyHeroId }
        end
    else
        if _armyInfo.mainHeroId and _armyInfo.mainHeroId > 0 then
            armyInfo.mainHero = HeroLogic:getHero( _targetRoleInfo.rid, _armyInfo.mainHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
        end
        if _armyInfo.deputyHeroId and _armyInfo.deputyHeroId > 0 then
            armyInfo.deputyHero = HeroLogic:getHero( _targetRoleInfo.rid, _armyInfo.deputyHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
        end
    end

    return armyInfo
end

---@see 获取城市援军信息
function MapScoutsLogic:getCityReinforceArmys( _roleInfo, _targetRoleInfo )
    local reinforceInfo = {}
    local multi = 1
    if RoleLogic:checkSusPect( _targetRoleInfo.rid ) then
        multi = 2
    end
    local soldiers = {}
    local rate, soldierNum
    local scoutStudy2 = CFG.s_Config:Get( "scoutStudy2" )
    local scoutStudy2Level = _roleInfo.technologies[scoutStudy2] and _roleInfo.technologies[scoutStudy2].level or 0
    if scoutStudy2Level < 2 then
        reinforceInfo.reinforceArmySumType = Enum.ScoutReinforceType.NO_DETAIL
    elseif scoutStudy2Level < 4 then
        -- 大概数量
        reinforceInfo.reinforceArmySumType = Enum.ScoutReinforceType.ICON
        for _, reinforce in pairs( _targetRoleInfo.reinforces or {} ) do
            for _, soldierInfo in pairs( reinforce.soldiers ) do
                if soldierInfo.num > 0 then
                    rate = Random.GetRange( -30, 30, 1 )[1]
                    soldierNum = math.max( 100, math.floor( soldierInfo.num * multi * ( 100 + rate ) / 10000 // 1 * 100 ) )
                    if not soldiers[soldierInfo.id] then
                        soldiers[soldierInfo.id] = {
                            id = soldierInfo.id,
                            type = soldierInfo.type,
                            level = soldierInfo.level,
                            num = soldierNum,
                        }
                    else
                        soldiers[soldierInfo.id].num = soldiers[soldierInfo.id].num + soldierNum
                    end
                end
            end
        end
    else
        -- 准确数量
        reinforceInfo.reinforceArmySumType = Enum.ScoutReinforceType.REAL_NUM
        for _, reinforce in pairs( _targetRoleInfo.reinforces or {} ) do
            for _, soldierInfo in pairs( reinforce.soldiers ) do
                if soldierInfo.num > 0 then
                    soldierNum = soldierInfo.num * multi
                    if not soldiers[soldierInfo.id] then
                        soldiers[soldierInfo.id] = {
                            id = soldierInfo.id,
                            type = soldierInfo.type,
                            level = soldierInfo.level,
                            num = soldierNum,
                        }
                    else
                        soldiers[soldierInfo.id].num = soldiers[soldierInfo.id].num + soldierNum
                    end
                end
            end
        end
    end

    reinforceInfo.reinforceSoldiers = {}
    table.merge( reinforceInfo.reinforceSoldiers, soldiers )

    return reinforceInfo
end

---@see 获取集结部队信息
function MapScoutsLogic:getCityRallyArmy( _roleInfo, _targetRoleInfo )
    local rallyArmys = {}
    local scoutStudy2 = CFG.s_Config:Get( "scoutStudy2" )
    local multi = 1
    if RoleLogic:checkSusPect( _targetRoleInfo.rid ) then
        multi = 2
    end
    -- 伪装术
    local pretendTechnologyLevel = _roleInfo.technologies[scoutStudy2] and _roleInfo.technologies[scoutStudy2].level or 0
    if pretendTechnologyLevel > 2 then
        if _targetRoleInfo.guildId > 0 then
            local rallyTeam = MSM.RallyMgr[_targetRoleInfo.guildId].req.getRallyTeamInfo( _targetRoleInfo.guildId, _targetRoleInfo.rid )
            if rallyTeam and not table.empty( rallyTeam ) and ( not rallyTeam.rallyObjectIndex or rallyTeam.rallyObjectIndex <= 0 ) then
                -- 集结部队信息还未出发
                local soldiers = {}
                local rallyWaitArmyInfo = rallyTeam.rallyWaitArmyInfo or {}
                for rallyRid, rallyArmyIndex in pairs( rallyTeam.rallyArmy ) do
                    if not rallyWaitArmyInfo[rallyRid] then
                        local armyInfoSoldiers = ArmyLogic:getArmy( rallyRid, rallyArmyIndex, Enum.Army.soldiers )
                        for _, soldierInfo in pairs( armyInfoSoldiers ) do
                            if not soldiers[soldierInfo.id] then
                                soldiers[soldierInfo.id] = {
                                    id = soldierInfo.id,
                                    type = soldierInfo.type,
                                    level = soldierInfo.level,
                                    num = soldierInfo.num,
                                }
                            else
                                soldiers[soldierInfo.id].num = soldiers[soldierInfo.id].num + soldierInfo.num
                            end
                        end
                    end
                end
                -- 士兵信息
                local rate, soldierNum
                rallyArmys.rallySoldiers = {}
                for _, soldierInfo in pairs( soldiers ) do
                    if soldierInfo.num > 0 then
                        if pretendTechnologyLevel < 5 then
                            rate = Random.GetRange( -30, 30, 1 )[1]
                            soldierNum = math.max( 100, math.floor( soldierInfo.num * multi * ( 100 + rate ) / 10000 // 1 * 100 ) )
                        else
                            soldierNum = soldierInfo.num * multi
                        end
                        table.insert( rallyArmys.rallySoldiers, {
                            id = soldierInfo.id,
                            type = soldierInfo.type,
                            level = soldierInfo.level,
                            num = soldierNum,
                        } )
                    end
                end
                if pretendTechnologyLevel < 5 then
                    rallyArmys.rallyArmySumType = Enum.ScoutCityRallyType.ICON
                else
                    rallyArmys.rallyArmySumType = Enum.ScoutCityRallyType.REAL_NUM
                end
                -- 统帅信息
                rallyArmys.rallyMainHero = HeroLogic:getHero( _targetRoleInfo.rid, rallyTeam.rallyMainHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
                if rallyTeam.rallyDeputyHeroId and rallyTeam.rallyDeputyHeroId > 0 then
                    rallyArmys.rallyDeputyHero = HeroLogic:getHero( _targetRoleInfo.rid, rallyTeam.rallyDeputyHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
                end
            else
                -- 城里无正在集结的部队
                rallyArmys.rallyArmySumType = Enum.ScoutCityRallyType.NO_RALLY
            end
        else
            -- 城里无正在集结的部队
            rallyArmys.rallyArmySumType = Enum.ScoutCityRallyType.NO_RALLY
        end
    end

    return rallyArmys
end

---@see 获取警戒塔信息
function MapScoutsLogic:getGuardTowerInfo( _roleInfo, _targetRoleInfo )
    -- 追踪术
    local scoutStudy1 = CFG.s_Config:Get( "scoutStudy1" )
    local followTechnologyLevel = _roleInfo.technologies[scoutStudy1] and _roleInfo.technologies[scoutStudy1].level or 0
    if followTechnologyLevel >= 4 then
        local buildInfo = BuildingLogic:getBuildingInfoByType( _targetRoleInfo.rid, Enum.BuildingType.GUARDTOWER )[1]
        local warningTowerHpMax = CFG.s_BuildingGuardTower:Get( buildInfo.level, "warningTowerHpMax" )
        local ageInfo = BuildingLogic:checkAge( _targetRoleInfo.rid )

        return {
            guardTowerLevel = buildInfo.level,
            guardTowerHp = _targetRoleInfo.guardTowerHp,
            guardTowerHpLimit = warningTowerHpMax,
            roleAge = ageInfo.age
        }
    end

    return {}
end

---@see 获取城市侦查报告
function MapScoutsLogic:getCityScoutReport( _rid, _scoutInfo, _targetObjectIndex )
    local emailId, emailOtherInfo, scoutdEmailId, scoutdEmailOtherInfo, guildAbbName, scoutFlag, scoutGuildAbbName
    local targetCityInfo = MSM.SceneCityMgr[_targetObjectIndex].req.getCityInfo( _targetObjectIndex )
    local sConfig = CFG.s_Config:Get()
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.level, Enum.Role.technologies, Enum.Role.guildId, Enum.Role.name,
        Enum.Role.headId, Enum.Role.headFrameID
    } )
    local targetRoleInfo = RoleLogic:getRole( targetCityInfo.rid, {
        Enum.Role.level, Enum.Role.guildId, Enum.Role.name, Enum.Role.headId,
        Enum.Role.headFrameID, Enum.Role.pos, Enum.Role.mainHeroId, Enum.Role.deputyHeroId,
        Enum.Role.soldiers, Enum.Role.rid, Enum.Role.reinforces, Enum.Role.guardTowerHp
    } )

    if targetRoleInfo.guildId > 0 then
        guildAbbName = GuildLogic:getGuild( targetRoleInfo.guildId, Enum.Guild.abbreviationName )
    end
    if roleInfo.guildId > 0 then
        scoutGuildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end
    local content = string.format( "%s,%s", guildAbbName or "", targetRoleInfo.name )
    if not MapLogic:checkRadius( _scoutInfo.scoutTarget.pos, targetCityInfo.pos, sConfig.scoutsRadiusCollide * 100 ) then
        -- 不在半径范围内
        emailId = 200102
        emailOtherInfo = {
            scoutReport = {
                guildAbbName = guildAbbName,
                pos = _scoutInfo.scoutTarget.pos,
                scoutRole = {
                    name = targetRoleInfo.name,
                    headId = targetRoleInfo.headId,
                    headFrameID = targetRoleInfo.headFrameID,
                },
            },
            subTitleContents = { content },
            emailContents = { content },
        }
    elseif roleInfo.level + sConfig.detectedLv < targetRoleInfo.level
        or ( roleInfo.guildId > 0 and roleInfo.guildId == targetRoleInfo.guildId ) then
        -- 侦查失败
        emailId = 200120
        emailOtherInfo = {
            scoutReport = {
                guildAbbName = guildAbbName,
                scoutRole = {
                    name = targetRoleInfo.name,
                    headId = targetRoleInfo.headId,
                    headFrameID = targetRoleInfo.headFrameID,
                },
                pos = targetRoleInfo.pos,
                subTitleContents = { content },
            },
            subTitleContents = { content },
        }
    elseif RoleLogic:checkShield( targetCityInfo.rid ) then
        -- 保护状态
        emailId = 200103
        emailOtherInfo = {
            scoutReport = {
                scoutRole = {
                    name = targetRoleInfo.name,
                    headId = targetRoleInfo.headId,
                    headFrameID = targetRoleInfo.headFrameID,
                },
                pos = targetRoleInfo.pos,
                guildAbbName = guildAbbName,
            },
            subTitleContents = { content },
            emailContents = { content },
        }
        -- 被侦查邮件
        scoutdEmailId = 200113
        scoutdEmailOtherInfo = {
            scoutReport = {
                scoutRole = {
                    rid = _rid,
                    name = roleInfo.name,
                    headId = roleInfo.headId,
                    headFrameID = roleInfo.headFrameID,
                },
                pos = _scoutInfo.scoutTarget.pos,
                guildAbbName = scoutGuildAbbName,
            },
            subTitleContents = { string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name ) },
        }
    elseif RoleLogic:checkAntiScout( targetCityInfo.rid ) then
        -- 反侦察状态
        emailId = 200101
        emailOtherInfo = {
            scoutReport = {
                guildAbbName = guildAbbName,
                scoutRole = {
                    name = targetRoleInfo.name,
                    headId = targetRoleInfo.headId,
                    headFrameID = targetRoleInfo.headFrameID,
                },
                pos = targetRoleInfo.pos,
            },
            subTitleContents = { content },
            emailContents = { content },
        }

        scoutdEmailId = 200114
        scoutdEmailOtherInfo = {
            scoutReport = {
                scoutRole = {
                    rid = _rid,
                    name = roleInfo.name,
                    headId = roleInfo.headId,
                    headFrameID = roleInfo.headFrameID,
                },
                pos = _scoutInfo.scoutTarget.pos,
                guildAbbName = scoutGuildAbbName,
            },
            subTitleContents = { string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name ) },
        }
    else
        -- 侦查成功后的报告
        emailId = 200100
        emailOtherInfo = {
            scoutReport = {
                guildAbbName = guildAbbName,
                scoutRole = {
                    name = targetRoleInfo.name,
                    headId = targetRoleInfo.headId,
                    headFrameID = targetRoleInfo.headFrameID,
                },
                pos = targetRoleInfo.pos,
            },
            subTitleContents = { content },
            emailContents = { content },
        }

        -- 城墙耐久信息
        emailOtherInfo.scoutReport.cityWallDurable, emailOtherInfo.scoutReport.cityWallDurableLimit = BuildingLogic:getCityWallHp( targetCityInfo.rid )
        -- 可掠夺资源
        if roleInfo.technologies[sConfig.scoutStudy1] and roleInfo.technologies[sConfig.scoutStudy1].level >= 1 then
            table.mergeEx( emailOtherInfo.scoutReport, BuildingLogic:getRoleRobResource( targetCityInfo.rid ) )
            emailOtherInfo.scoutReport.robResourceType = 2
        else
            emailOtherInfo.scoutReport.robResourceType = 1
        end
        -- 城内部队数量信息
        table.mergeEx( emailOtherInfo.scoutReport, self:getCityArmyCount( roleInfo, targetRoleInfo ) )
        -- 城市增援信息
        table.mergeEx( emailOtherInfo.scoutReport, self:getCityReinforceArmys( roleInfo, targetRoleInfo ) )
        -- 城市集结信息
        table.mergeEx( emailOtherInfo.scoutReport, self:getCityRallyArmy( roleInfo, targetRoleInfo ) )
        -- 防御力信息
        table.mergeEx( emailOtherInfo.scoutReport, self:getGuardTowerInfo( roleInfo, targetRoleInfo ) )
        scoutFlag = true
        RoleLogic:addScoutDenseFogFlag( _rid, _scoutInfo.scoutsIndex )
        -- 被侦查邮件
        scoutdEmailOtherInfo = {
            scoutReport = {
                scoutRole = {
                    rid = _rid,
                    name = roleInfo.name,
                    headId = roleInfo.headId,
                    headFrameID = roleInfo.headFrameID,
                },
                pos = _scoutInfo.scoutTarget.pos,
                guildAbbName = scoutGuildAbbName,
            },
            subTitleContents = { string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name ) },
        }
        if roleInfo.level <= targetRoleInfo.level then
            scoutdEmailId = 200116
        else
            scoutdEmailId = 200115
        end
    end

    if emailOtherInfo and emailOtherInfo.scoutReport then
        emailOtherInfo.scoutReport.targetType = Enum.ScoutTargetType.CITY
    end

    if scoutdEmailOtherInfo and scoutdEmailOtherInfo.scoutReport then
        scoutdEmailOtherInfo.scoutReport.targetType = Enum.ScoutTargetType.CITY
    end

    return emailId, emailOtherInfo, targetCityInfo.rid, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag
end

---@see 获取部队侦查报告
function MapScoutsLogic:getArmyScoutReport( _rid, _scoutInfo )
    local emailId, emailOtherInfo, scoutFlag, scoutdEmailId, scoutdEmailOtherInfo
    local scoutTarget = _scoutInfo.scoutTarget or {}
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.guildId, Enum.Role.level, Enum.Role.technologies,
        Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID
    } )
    local targetRoleInfo = RoleLogic:getRole( scoutTarget.rid, {
        Enum.Role.level, Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.rid,
        Enum.Role.mainHeroId, Enum.Role.deputyHeroId,
    } )
    local detectedLv = CFG.s_Config:Get( "detectedLv" ) or 10
    local guildAbbName
    if targetRoleInfo.guildId > 0 then
        guildAbbName = GuildLogic:getGuild( targetRoleInfo.guildId, Enum.Guild.abbreviationName )
    end
    local content
    if guildAbbName then
        content = string.format( "%s,%s", guildAbbName, targetRoleInfo.name )
    else
        content = targetRoleInfo.name
    end
    -- 侦查报告信息
    emailOtherInfo = {
        scoutReport = {
            guildAbbName = guildAbbName,
            scoutRole = {
                name = targetRoleInfo.name,
                headId = targetRoleInfo.headId,
                headFrameID = targetRoleInfo.headFrameID,
            },
            targetType = Enum.ScoutTargetType.ROLE_ARMY
        },
        subTitleContents = { content }
    }
    local armyDisband, scoutSuccess, pos
    local armyObjectIndex = MSM.RoleArmyMgr[scoutTarget.rid].req.getRoleArmyIndex( scoutTarget.rid, scoutTarget.armyIndex )
    local armyInfo = ArmyLogic:getArmy( scoutTarget.rid, scoutTarget.armyIndex )
    if not armyObjectIndex then
        -- 部队不存在，检查部队是否在资源点中
        if armyInfo and not table.empty( armyInfo ) and ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            local resourceIndex = armyInfo.targetArg.targetObjectIndex
            local resourceInfo = MSM.MapObjectTypeMgr[resourceIndex].req.getObjectType( resourceIndex )
            if MapObjectLogic:checkIsResourceObject( resourceInfo.objectType ) then
                -- 资源点采集中
                emailId = 200104
                pos = MSM.SceneResourceMgr[resourceIndex].req.getResourcePos( resourceIndex )
                emailOtherInfo.scoutReport.pos = pos
                table.mergeEx( emailOtherInfo.scoutReport, self:getArmyCount( roleInfo, targetRoleInfo, armyInfo ) )
                emailOtherInfo.emailContents = { content }
                emailOtherInfo.scoutReport.targetType = Enum.ScoutTargetType.RESOURCE
                scoutFlag = true
                scoutSuccess = true
            else
                -- 不在资源点采集中
                emailId = 200109
                emailOtherInfo.scoutReport.pos = _scoutInfo.pos
                armyDisband = true
            end
        else
            -- 部队已解散或进入其他建筑
            emailId = 200109
            emailOtherInfo.scoutReport.pos = _scoutInfo.pos
            armyDisband = true
        end
    else
        if not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
            local mapArmyInfo = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyInfo( armyObjectIndex )
            -- 部队在大地图中
            emailId = 200108
            pos = mapArmyInfo.pos
            emailOtherInfo.scoutReport.pos = pos
            emailOtherInfo.subTitleContents = { content }
            emailOtherInfo.emailContents = { content }
            table.mergeEx( emailOtherInfo.scoutReport, self:getArmyCount( roleInfo, targetRoleInfo, mapArmyInfo ) )
            scoutSuccess = true
        else
            -- 部队溃败中
            emailId = 200109
            emailOtherInfo.scoutReport.pos = _scoutInfo.pos
            armyDisband = true
        end
    end

    if scoutSuccess == true then
        if roleInfo.level <= targetRoleInfo.level then
            scoutdEmailId = 200118
        else
            scoutdEmailId = 200117
        end
        local scoutGuildAbbName
        if roleInfo.guildId > 0 then
            scoutGuildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
        end
        scoutdEmailOtherInfo = {
            scoutReport = {
                scoutRole = {
                    rid = _rid,
                    name = roleInfo.name,
                    headId = roleInfo.headId,
                    headFrameID = roleInfo.headFrameID,
                },
                pos = pos,
                guildAbbName = scoutGuildAbbName,
                targetType = emailOtherInfo.scoutReport.targetType
            },
            subTitleContents = { string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name ) },
        }
    end

    -- 被侦查部队与角色是否是同一联盟 或者 被侦查者是否超过侦察者10级
    if not armyDisband and ( ( roleInfo.guildId > 0 and roleInfo.guildId == targetRoleInfo.guildId )
        or roleInfo.level + detectedLv < targetRoleInfo.level ) then
        -- 返回邮件ID
        emailId = 200120
        scoutdEmailId = nil
    end

    return emailId, emailOtherInfo, scoutTarget.rid, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag
end

---@see 获取地图集结部队信息
function MapScoutsLogic:getMapRallyArmyInfo( _roleInfo, _mapArmyInfo )
    local rallyArmys = {}
    local scoutStudy2 = CFG.s_Config:Get( "scoutStudy2" )

    -- 伪装术
    local pretendTechnologyLevel = _roleInfo.technologies[scoutStudy2] and _roleInfo.technologies[scoutStudy2].level or 0
    if pretendTechnologyLevel > 2 then
        -- 士兵信息
        rallyArmys.rallySoldiers = {}
        table.merge( rallyArmys.rallySoldiers, ArmyLogic:getArmySoldiersFromObject( _mapArmyInfo ) )

        if pretendTechnologyLevel < 5 then
            rallyArmys.rallyArmySumType = Enum.ScoutCityRallyType.ICON
        else
            rallyArmys.rallyArmySumType = Enum.ScoutCityRallyType.REAL_NUM
        end
        -- 统帅信息
        rallyArmys.rallyMainHero = HeroLogic:getHero( _mapArmyInfo.rid, _mapArmyInfo.mainHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
        if _mapArmyInfo.deputyHeroId and _mapArmyInfo.deputyHeroId > 0 then
            rallyArmys.rallyDeputyHero = HeroLogic:getHero( _mapArmyInfo.rid, _mapArmyInfo.deputyHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
        end
    end

    return rallyArmys
end

---@see 获取集结部队侦查报告
function MapScoutsLogic:getRallyArmyScoutReport( _rid, _scoutInfo, _targetObjectIndex )
    local emailId, emailOtherInfo, scoutdEmailId, scoutdEmailOtherInfo, scoutdRids
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.guildId, Enum.Role.level, Enum.Role.technologies,
        Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID
    } )
    local targetRoleInfo = RoleLogic:getRole( _scoutInfo.scoutTarget.rid, {
        Enum.Role.guildId, Enum.Role.level, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.rid,
    } )
    local mapArmyInfo = MSM.SceneArmyMgr[_targetObjectIndex].req.getArmyInfo( _targetObjectIndex )
    local guildAbbName
    if targetRoleInfo.guildId > 0 then
        guildAbbName = GuildLogic:getGuild( targetRoleInfo.guildId, Enum.Guild.abbreviationName )
    end
    local content
    if guildAbbName then
        content = string.format( "%s,%s", guildAbbName, targetRoleInfo.name )
    else
        content = targetRoleInfo.name
    end
    -- 侦查报告信息
    emailOtherInfo = {
        scoutReport = {
            guildAbbName = guildAbbName,
            scoutRole = {
                name = targetRoleInfo.name,
                headId = targetRoleInfo.headId,
                headFrameID = targetRoleInfo.headFrameID,
            },
            targetType = Enum.ScoutTargetType.RALLY_ARMY
        },
        subTitleContents = { content },
        emailContents = { content },
    }

    if not mapArmyInfo or table.empty( mapArmyInfo ) then
        -- 部队已解散
        emailId = 200107
        emailOtherInfo.scoutReport.pos = _scoutInfo.pos
    else
        -- 部队在大地图上
        emailOtherInfo.scoutReport.pos = mapArmyInfo.pos
        -- 被侦查部队与角色是否是同一联盟 或者 被侦查者是否超过侦察者10级
        local detectedLv = CFG.s_Config:Get( "detectedLv" ) or 10
        if ( roleInfo.guildId > 0 and roleInfo.guildId == targetRoleInfo.guildId )
            or roleInfo.level + detectedLv < targetRoleInfo.level then
            -- 返回邮件ID
            emailId = 200120
        else
            emailId = 200106
            table.mergeEx( emailOtherInfo.scoutReport, self:getMapRallyArmyInfo( roleInfo, mapArmyInfo ) )
            if roleInfo.level <= targetRoleInfo.level then
                scoutdEmailId = 200118
            else
                scoutdEmailId = 200117
            end
            local scoutGuildAbbName
            if roleInfo.guildId > 0 then
                scoutGuildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
            end
            scoutdEmailOtherInfo = {
                scoutReport = {
                    scoutRole = {
                        rid = _rid,
                        name = roleInfo.name,
                        headId = roleInfo.headId,
                        headFrameID = roleInfo.headFrameID,
                    },
                    pos = mapArmyInfo.pos,
                    guildAbbName = scoutGuildAbbName,
                    targetType = emailOtherInfo.scoutReport.targetType
                },
                subTitleContents = { string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name ) },
            }
            scoutdRids = {}
            for rallyRid in pairs( mapArmyInfo.rallyArmy ) do
                scoutdRids[rallyRid] = rallyRid
            end
        end
    end

    return emailId, emailOtherInfo, scoutdRids, scoutdEmailId, scoutdEmailOtherInfo
end

---@see 获取建筑中的部队信息
function MapScoutsLogic:getBuildArmyCount( _roleInfo, _targetInfo )
    local buildArmyInfo = {}
    -- 追踪术
    local scoutStudy1 = CFG.s_Config:Get( "scoutStudy1" )
    local followTechnologyLevel = _roleInfo.technologies[scoutStudy1] and _roleInfo.technologies[scoutStudy1].level or 0
    local soldiers, soldierNum, rate
    if followTechnologyLevel < 2 then
        buildArmyInfo.armySumType = Enum.ScoutArmyType.NO_DETAIL
    elseif followTechnologyLevel < 3 then
        buildArmyInfo.armySumType = Enum.ScoutArmyType.NO_ICON
        soldierNum = 0
        buildArmyInfo.armySum = 0
        for memberRid, armys in pairs( _targetInfo.garrison or {} ) do
            for index in pairs( armys ) do
                soldiers = ArmyLogic:getArmy( memberRid, index, Enum.Army.soldiers ) or {}
                for _, soldierInfo in pairs( soldiers ) do
                    soldierNum = soldierNum + soldierInfo.num
                end
            end
        end
        if soldierNum > 0 then
            rate = Random.GetRange( -30, 30, 1 )[1]
            buildArmyInfo.armySum = math.max( 100, math.floor( soldierNum * ( 100 + rate ) / 10000 // 1 * 100 ) )
        else
            buildArmyInfo.armySum = 0
        end
    elseif followTechnologyLevel <= 4 then
        buildArmyInfo.armySumType = Enum.ScoutArmyType.ICON
        buildArmyInfo.armySum = 0
        buildArmyInfo.soldiers = {}
        local soldierList = {}
        for memberRid, armys in pairs( _targetInfo.garrison or {} ) do
            for index in pairs( armys ) do
                soldiers = ArmyLogic:getArmy( memberRid, index, Enum.Army.soldiers ) or {}
                for _, soldierInfo in pairs( soldiers ) do
                    rate = Random.GetRange( -30, 30, 1 )[1]
                    soldierNum = math.max( 100, math.floor( soldierInfo.num * ( 100 + rate ) / 10000 // 1 * 100 ) )
                    if not soldierList[soldierInfo.id] then
                        soldierList[soldierInfo.id] = {
                            id = soldierInfo.id,
                            type = soldierInfo.type,
                            level = soldierInfo.level,
                            num = soldierNum,
                        }
                    else
                        soldierList[soldierInfo.id].num = soldierList[soldierInfo.id].num + soldierNum
                    end
                    buildArmyInfo.armySum = buildArmyInfo.armySum + soldierNum
                end
            end
        end
        table.merge( buildArmyInfo.soldiers, soldierList )
    else
        buildArmyInfo.armySumType = Enum.ScoutArmyType.REAL_NUM
        buildArmyInfo.armySum = 0
        buildArmyInfo.soldiers = {}
        local soldierList = {}
        for memberRid, armys in pairs( _targetInfo.garrison or {} ) do
            for index in pairs( armys ) do
                soldiers = ArmyLogic:getArmy( memberRid, index, Enum.Army.soldiers ) or {}
                for _, soldierInfo in pairs( soldiers ) do
                    if not soldierList[soldierInfo.id] then
                        soldierList[soldierInfo.id] = {
                            id = soldierInfo.id,
                            type = soldierInfo.type,
                            level = soldierInfo.level,
                            num = soldierInfo.num,
                        }
                    else
                        soldierList[soldierInfo.id].num = soldierList[soldierInfo.id].num + soldierInfo.num
                    end
                    buildArmyInfo.armySum = buildArmyInfo.armySum + soldierInfo.num
                end
            end
        end
        table.merge( buildArmyInfo.soldiers, soldierList )
    end

    -- 伪装术
    local scoutStudy2 = CFG.s_Config:Get( "scoutStudy2" )
    local pretendTechnologyLevel = _roleInfo.technologies[scoutStudy2] and _roleInfo.technologies[scoutStudy2].level or 0
    local leaderRid = _targetInfo.garrisonLeader or 0
    local leaderArmyIndex = _targetInfo.garrisonArmyIndex or 0
    -- 统帅信息
    if leaderRid > 0 and leaderArmyIndex > 0 then
        local armyInfo = ArmyLogic:getArmy( leaderRid, leaderArmyIndex, { Enum.Army.mainHeroId, Enum.Army.deputyHeroId } )
        if armyInfo and not table.empty( armyInfo ) then
            if pretendTechnologyLevel < 1 then
                if armyInfo.mainHeroId and armyInfo.mainHeroId > 0 then
                    buildArmyInfo.mainHero = { heroId = armyInfo.mainHeroId }
                end
                if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
                    buildArmyInfo.deputyHero = { heroId = armyInfo.deputyHeroId }
                end
            else
                if armyInfo.mainHeroId and armyInfo.mainHeroId > 0 then
                    buildArmyInfo.mainHero = HeroLogic:getHero( leaderRid, armyInfo.mainHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
                end
                if armyInfo.deputyHeroId and armyInfo.deputyHeroId > 0 then
                    buildArmyInfo.deputyHero = HeroLogic:getHero( leaderRid, armyInfo.deputyHeroId, { Enum.Hero.heroId, Enum.Hero.star, Enum.Hero.skills } )
                end
            end
        end
    end

    return buildArmyInfo
end

---@see 获取圣地关卡中初始怪物信息
function MapScoutsLogic:getHolyLandArmyCount( _roleInfo, _targetInfo )
    local buildArmyInfo = {}
    -- 追踪术
    local scoutStudy1 = CFG.s_Config:Get( "scoutStudy1" )
    local followTechnologyLevel = _roleInfo.technologies[scoutStudy1] and _roleInfo.technologies[scoutStudy1].level or 0
    local soldierNum, rate
    if followTechnologyLevel < 2 then
        buildArmyInfo.armySumType = Enum.ScoutArmyType.NO_DETAIL
    elseif followTechnologyLevel < 3 then
        buildArmyInfo.armySumType = Enum.ScoutArmyType.NO_ICON
        soldierNum = 0
        buildArmyInfo.armySum = 0
        for _, soldierInfo in pairs( _targetInfo.soldiers or {} ) do
            soldierNum = soldierNum + soldierInfo.num
        end
        if soldierNum > 0 then
            rate = Random.GetRange( -30, 30, 1 )[1]
            buildArmyInfo.armySum = math.max( 100, math.floor( soldierNum * ( 100 + rate ) / 10000 // 1 * 100 ) )
        else
            buildArmyInfo.armySum = 0
        end
    elseif followTechnologyLevel <= 4 then
        buildArmyInfo.armySumType = Enum.ScoutArmyType.ICON
        buildArmyInfo.armySum = 0
        buildArmyInfo.soldiers = {}
        local soldierList = {}
        for _, soldierInfo in pairs( _targetInfo.soldiers or {} ) do
            rate = Random.GetRange( -30, 30, 1 )[1]
            soldierNum = math.max( 100, math.floor( soldierInfo.num * ( 100 + rate ) / 10000 // 1 * 100 ) )
            if not soldierList[soldierInfo.id] then
                soldierList[soldierInfo.id] = {
                    id = soldierInfo.id,
                    type = soldierInfo.type,
                    level = soldierInfo.level,
                    num = soldierNum,
                }
            else
                soldierList[soldierInfo.id].num = soldierList[soldierInfo.id].num + soldierNum
            end
            buildArmyInfo.armySum = buildArmyInfo.armySum + soldierNum
        end
        table.merge( buildArmyInfo.soldiers, soldierList )
    else
        buildArmyInfo.armySumType = Enum.ScoutArmyType.REAL_NUM
        buildArmyInfo.armySum = 0
        buildArmyInfo.soldiers = {}
        local soldierList = {}
        for _, soldierInfo in pairs( _targetInfo.soldiers or {} ) do
            if not soldierList[soldierInfo.id] then
                soldierList[soldierInfo.id] = {
                    id = soldierInfo.id,
                    type = soldierInfo.type,
                    level = soldierInfo.level,
                    num = soldierInfo.num,
                }
            else
                soldierList[soldierInfo.id].num = soldierList[soldierInfo.id].num + soldierInfo.num
            end
            buildArmyInfo.armySum = buildArmyInfo.armySum + soldierInfo.num
        end
        table.merge( buildArmyInfo.soldiers, soldierList )
    end

    -- 伪装术
    local scoutStudy2 = CFG.s_Config:Get( "scoutStudy2" )
    local pretendTechnologyLevel = _roleInfo.technologies[scoutStudy2] and _roleInfo.technologies[scoutStudy2].level or 0
    if pretendTechnologyLevel < 1 then
        if _targetInfo.mainHeroId and _targetInfo.mainHeroId > 0 then
            buildArmyInfo.mainHero = { heroId = _targetInfo.mainHeroId }
        end

        if _targetInfo.deputyHeroId and _targetInfo.deputyHeroId > 0 then
            buildArmyInfo.deputyHeroId = { heroId = _targetInfo.deputyHeroId }
        end
    else
        local mainHeroStar, deputyHeroStar = HeroLogic:getMonsterStar( _targetInfo.holyLandBuildMonsterId )
        if _targetInfo.mainHeroId and _targetInfo.mainHeroId > 0 then
            buildArmyInfo.mainHero = {
                [Enum.Hero.heroId] = _targetInfo.mainHeroId,
                [Enum.Hero.skills] = _targetInfo.mainHeroSkills,
                [Enum.Hero.star] = mainHeroStar,
            }
        end
        if _targetInfo.deputyHeroId and _targetInfo.deputyHeroId > 0 then
            buildArmyInfo.deputyHero = {
                [Enum.Hero.heroId] = _targetInfo.deputyHeroId,
                [Enum.Hero.skills] = _targetInfo.deputyHeroSkills,
                [Enum.Hero.star] = deputyHeroStar,
            }
        end
    end

    return buildArmyInfo
end

---@see 获取联盟建筑侦查报告
function MapScoutsLogic:getGuildBuildScoutReport( _rid, _scoutInfo, _targetObjectIndex )
    local emailId, emailOtherInfo, scoutFlag, scoutdEmailId, scoutdEmailOtherInfo, toRids
    local guildBuild = MSM.SceneGuildBuildMgr[_targetObjectIndex].req.getGuildBuildInfo( _targetObjectIndex )
    local buildType = GuildBuildLogic:objectTypeToBuildType( _scoutInfo.scoutTarget.objectType )
    local guildId = _scoutInfo.scoutTarget.guildId
    local guildInfo = GuildLogic:getGuild( guildId, { Enum.Guild.signs, Enum.Guild.abbreviationName, Enum.Guild.members } ) or {}
    local guildAbbName = guildInfo.abbreviationName or _scoutInfo.scoutTarget.abbreviationName
    local content = string.format( "%s,%d", guildAbbName, buildType )
    emailOtherInfo = {
        scoutReport = {
            targetType = Enum.ScoutTargetType.GUILD_BUILD,
            pos = _scoutInfo.scoutTarget.pos,
            objectTypeId = buildType,
            guildAbbName = guildAbbName,
            guildFlagSigns = guildInfo.signs or _scoutInfo.scoutTarget.signs,
        },
        subTitleContents = { content }
    }
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.technologies, Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID,
    } )
    if guildBuild and not table.empty( guildBuild ) then
        -- 获取部队信息
        scoutFlag = true
        emailId = 200110
        emailOtherInfo.emailContents = { content }
        table.mergeEx( emailOtherInfo.scoutReport, self:getBuildArmyCount( roleInfo, guildBuild ) or {} )

        local scoutGuildAbbName
        if roleInfo.guildId > 0 then
            scoutGuildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
        end

        toRids = {}
        for garrisonRid in pairs( guildBuild.garrison or {} ) do
            toRids[garrisonRid] = garrisonRid
        end
        if not table.empty( toRids ) then
            scoutdEmailId = 200119
            scoutdEmailOtherInfo = {
                scoutReport = {
                    scoutRole = {
                        rid = _rid,
                        name = roleInfo.name,
                        headId = roleInfo.headId,
                        headFrameID = roleInfo.headFrameID,
                    },
                    pos = _scoutInfo.scoutTarget.pos,
                    targetType = Enum.ScoutTargetType.GUILD_BUILD,
                    guildAbbName = scoutGuildAbbName,
                    objectTypeId = buildType,
                },
                subTitleContents = { string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name ) },
            }
        else
            toRids = nil
        end
    else
        emailId = 200111
        emailOtherInfo.scoutReport.pos = nil
        emailOtherInfo.emailContents = { content }
    end

    return emailId, emailOtherInfo, toRids, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag
end

---@see 获取圣地侦查报告
function MapScoutsLogic:getRelicScoutReport( _rid, _targetObjectIndex )
    local emailId, emailOtherInfo, scoutFlag, scoutdEmailId, scoutdEmailOtherInfo, toRids
    ---@type defaultMapHolyLandInfoClass
    local holyLandInfo = MSM.SceneHolyLandMgr[_targetObjectIndex].req.getHolyLandInfo( _targetObjectIndex )
    local guildAbbName, content, guildInfo
    if holyLandInfo.guildId > 0 then
        guildInfo = GuildLogic:getGuild( holyLandInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.members } )
        guildAbbName = guildInfo.abbreviationName
    end

    content = string.format( "%s,%d", guildAbbName or "", holyLandInfo.strongHoldId )
    emailOtherInfo = {
        scoutReport = {
            targetType = Enum.ScoutTargetType.RELIC,
            pos = holyLandInfo.pos,
            objectTypeId = holyLandInfo.strongHoldId
        },
    }
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.technologies, Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID,
    } )
    if roleInfo.guildId == holyLandInfo.guildId then
        emailId = 200122
        emailOtherInfo.emailContents = { holyLandInfo.strongHoldId }
        emailOtherInfo.subTitleContents = { content }
    elseif holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.LOCK
        and holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.INIT_PROTECT
        and holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.PROTECT then
        -- 获取部队信息
        scoutFlag = true
        emailId = 200121
        emailOtherInfo.emailContents = { content }
        emailOtherInfo.subTitleContents = { content }
        if holyLandInfo.holyLandStatus == Enum.HolyLandStatus.INIT_SCRAMBLE then
            -- 初始争夺中为圣地怪物士兵信息
            table.mergeEx( emailOtherInfo.scoutReport, self:getHolyLandArmyCount( roleInfo, holyLandInfo ) )
        else
            -- 驻防角色部队士兵信息
            table.mergeEx( emailOtherInfo.scoutReport, self:getBuildArmyCount( roleInfo, holyLandInfo ) )
        end

        if holyLandInfo.guildId > 0 and not table.empty( holyLandInfo.garrison or {} ) then
            local scoutGuildAbbName
            if roleInfo.guildId > 0 then
                scoutGuildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
            end
            local scoutedContent = string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name )
            scoutdEmailId = 200123
            scoutdEmailOtherInfo = {
                scoutReport = {
                    scoutRole = {
                        rid = _rid,
                        name = roleInfo.name,
                        headId = roleInfo.headId,
                        headFrameID = roleInfo.headFrameID,
                    },
                    pos = holyLandInfo.pos,
                    targetType = Enum.ScoutTargetType.RELIC,
                    guildAbbName = scoutGuildAbbName,
                    objectTypeId = holyLandInfo.strongHoldId
                },
                subTitleContents = { scoutedContent, holyLandInfo.strongHoldId },
                emailContents = { holyLandInfo.strongHoldId, scoutedContent }
            }
            toRids = table.indexs( holyLandInfo.garrison or {} )
        end
    else
        emailId = 200112
        emailOtherInfo.emailContents = { content }
        emailOtherInfo.subTitleContents = { content }
    end

    return emailId, emailOtherInfo, toRids, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag
end

---@see 获取关卡侦查报告
function MapScoutsLogic:getCheckPointScoutReport( _rid, _targetObjectIndex )
    local emailId, emailOtherInfo, scoutFlag, scoutdEmailId, scoutdEmailOtherInfo, toRids
    ---@type defaultMapHolyLandInfoClass
    local holyLandInfo = MSM.SceneHolyLandMgr[_targetObjectIndex].req.getHolyLandInfo( _targetObjectIndex )
    local guildAbbName, content, guildInfo
    if holyLandInfo.guildId > 0 then
        guildInfo = GuildLogic:getGuild( holyLandInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.members } )
        guildAbbName = guildInfo.abbreviationName
    end

    content = string.format( "%s,%d", guildAbbName or "", holyLandInfo.strongHoldId )
    emailOtherInfo = {
        scoutReport = {
            targetType = Enum.ScoutTargetType.CHECKPOINT,
            pos = holyLandInfo.pos,
            objectTypeId = holyLandInfo.strongHoldId
        },
    }
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.technologies, Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID,
    } )
    if roleInfo.guildId == holyLandInfo.guildId then
        emailId = 200122
        emailOtherInfo.emailContents = { holyLandInfo.strongHoldId }
        emailOtherInfo.subTitleContents = { content }
    elseif holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.LOCK
        and holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.INIT_PROTECT
        and holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.PROTECT then
        -- 获取部队信息
        scoutFlag = true
        emailId = 200121
        emailOtherInfo.emailContents = { content }
        emailOtherInfo.subTitleContents = { content }
        if holyLandInfo.holyLandStatus == Enum.HolyLandStatus.INIT_SCRAMBLE then
            -- 初始争夺中为圣地怪物士兵信息
            table.mergeEx( emailOtherInfo.scoutReport, self:getHolyLandArmyCount( roleInfo, holyLandInfo ) )
        else
            -- 驻防角色部队士兵信息
            table.mergeEx( emailOtherInfo.scoutReport, self:getBuildArmyCount( roleInfo, holyLandInfo ) )
        end

        if holyLandInfo.guildId > 0 and not table.empty( holyLandInfo.garrison or {} ) then
            local scoutGuildAbbName
            if roleInfo.guildId > 0 then
                scoutGuildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
            end
            local scoutedContent = string.format( "%s,%s", scoutGuildAbbName or "", roleInfo.name )
            scoutdEmailId = 200123
            scoutdEmailOtherInfo = {
                scoutReport = {
                    scoutRole = {
                        rid = _rid,
                        name = roleInfo.name,
                        headId = roleInfo.headId,
                        headFrameID = roleInfo.headFrameID,
                    },
                    pos = holyLandInfo.pos,
                    targetType = Enum.ScoutTargetType.CHECKPOINT,
                    guildAbbName = scoutGuildAbbName,
                    objectTypeId = holyLandInfo.strongHoldId
                },
                subTitleContents = { scoutedContent, holyLandInfo.strongHoldId },
                emailContents = { holyLandInfo.strongHoldId, scoutedContent }
            }
            toRids = {}
            for garrisonRid in pairs( holyLandInfo.garrison or {} ) do
                toRids[garrisonRid] = garrisonRid
            end
        end
    else
        emailId = 200112
        emailOtherInfo.emailContents = { content }
        emailOtherInfo.subTitleContents = { content }
    end

    return emailId, emailOtherInfo, toRids, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag
end

---@see 斥候进入地图回城
function MapScoutsLogic:scoutMarchBackCity( _rid, _scoutInfo )
    -- 生成一个新的对象ID
    local objectIndex = Common.newMapObjectIndex()
    -- 斥候进入地图回城
    local path = { _scoutInfo.pos, RoleLogic:getRole( _rid, Enum.Role.pos ) }
    MSM.MapMarchMgr[objectIndex].post.scoutEnterMapBackCity( _rid, objectIndex, _scoutInfo.scoutsIndex, path, _scoutInfo.speed )
end

---@see 斥候侦查回调
function MapScoutsLogic:mapScoutMarchCallBack( _rid, _objectIndex, _targetObjectIndex, _pos )
    local scoutInfo = MSM.SceneScoutsMgr[_objectIndex].req.getScoutsInfo( _objectIndex )
    local scoutTarget = scoutInfo.scoutTarget or {}
    local scoutFlag
    if scoutTarget.targetType then
        local emailId, emailOtherInfo, scoutdEmailId, scoutdEmailOtherInfo, toRid
        if scoutTarget.targetType == Enum.ScoutTargetType.CAVE then
            -- 探索山洞
            local resourceInfo = MSM.SceneResourceMgr[_targetObjectIndex].req.getResourceInfo( _targetObjectIndex )
            RoleLogic:villageCaveScoutCallBack( _rid, resourceInfo.resourcePointId )
        elseif scoutTarget.targetType == Enum.ScoutTargetType.CITY then
            -- 侦查城市
            emailId, emailOtherInfo, toRid, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag = self:getCityScoutReport( _rid, scoutInfo, _targetObjectIndex )
        elseif scoutTarget.targetType == Enum.ScoutTargetType.ROLE_ARMY
            or scoutTarget.targetType == Enum.ScoutTargetType.RESOURCE then
            -- 侦查部队、资源点
            emailId, emailOtherInfo, toRid, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag = self:getArmyScoutReport( _rid, scoutInfo )
        elseif scoutTarget.targetType == Enum.ScoutTargetType.RALLY_ARMY then
            -- 集结部队
            emailId, emailOtherInfo, toRid, scoutdEmailId, scoutdEmailOtherInfo = self:getRallyArmyScoutReport( _rid, scoutInfo, _targetObjectIndex )
        elseif scoutTarget.targetType == Enum.ScoutTargetType.GUILD_BUILD then
            -- 联盟建筑
            emailId, emailOtherInfo, toRid, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag = self:getGuildBuildScoutReport( _rid, scoutInfo, _targetObjectIndex )
        elseif scoutTarget.targetType == Enum.ScoutTargetType.CHECKPOINT then
            -- 关卡
            emailId, emailOtherInfo, toRid, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag = self:getRelicScoutReport( _rid, _targetObjectIndex )
        elseif scoutTarget.targetType == Enum.ScoutTargetType.RELIC then
            -- 圣地
            emailId, emailOtherInfo, toRid, scoutdEmailId, scoutdEmailOtherInfo, scoutFlag = self:getCheckPointScoutReport( _rid, _targetObjectIndex )
        end

        -- 发送给侦察者邮件
        if emailId then
            EmailLogic:sendEmail( _rid, emailId, emailOtherInfo )
        end
        -- 发送给被侦察者邮件
        if scoutdEmailId and toRid then
            scoutdEmailOtherInfo.subType = Enum.EmailSubType.SCOUTED
            if not Common.isTable( toRid ) then
                toRid = { [toRid] = toRid }
            end
            -- 套用联盟服务群发邮件
            MSM.GuildMgr[_rid].post.sendGuildEmail( 0, toRid or {}, scoutdEmailId, scoutdEmailOtherInfo )
        end
    end
    if scoutFlag then
        -- 更新斥候状态
        ScoutsLogic:updateScoutsInfo( _rid, scoutInfo.scoutsIndex, { scoutsIndex = scoutInfo.scoutsIndex, scoutsStatus = Enum.ArmyStatus.SCOUTING_DELETE } )
        -- 地图删除斥候
        MSM.MapMarchMgr[_objectIndex].post.deleteScoutObject( _objectIndex, true )
        -- 等待0.5秒后，重新进入地图
        Timer.runAfter( 0.5 * 100, self.scoutMarchBackCity, self, _rid, scoutInfo )
    else
        local cityPos = RoleLogic:getRole( _rid, Enum.Role.pos )
        MSM.MapMarchMgr[_objectIndex].post.scoutsBackCity( _rid, _objectIndex, { _pos, cityPos } )
    end
end

return MapScoutsLogic