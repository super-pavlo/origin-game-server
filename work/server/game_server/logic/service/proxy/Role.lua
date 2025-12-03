--[[
* @file : Role.lua
* @type : snax multi service
* @author : linfeng
* @created : Thu Nov 23 2017 11:31:13 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local squeue = require "skynet.queue"
local snax = require "skynet.snax"
local skynet = require "skynet"
local RoleLogic = require "RoleLogic"
local LogLogic = require "LogLogic"
local Random = require "Random"
local HeroLogic = require "HeroLogic"
local ArmyTrainLogic = require "ArmyTrainLogic"
local RoleSync = require "RoleSync"
local ArmyLogic = require "ArmyLogic"
local BuildingLogic = require "BuildingLogic"
local HospitalLogic = require "HospitalLogic"
local ItemLogic = require "ItemLogic"
local TaskLogic = require "TaskLogic"
local ScoutsLogic = require "ScoutsLogic"
local GuildLogic = require "GuildLogic"
local EmailLogic = require "EmailLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local RechargeLogic = require "RechargeLogic"
local MonumentLogic = require "MonumentLogic"
local DenseFogLogic = require "DenseFogLogic"
local TransportLogic = require "TransportLogic"
local RallyLogic = require "RallyLogic"
local EarlyWarningLogic = require "EarlyWarningLogic"
local GuildTechnologyLogic = require "GuildTechnologyLogic"
local MapObjectLogic = require "MapObjectLogic"
local CityReinforceLogic = require "CityReinforceLogic"
local RoleCacle = require "RoleCacle"
local GuildGiftLogic = require "GuildGiftLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local RoleChatLogic = require "RoleChatLogic"
local timercore = require "timer.core"
local ArmyWalkLogic = require "ArmyWalkLogic"
local MapLogic = require "MapLogic"
local CityHideLogic = require "CityHideLogic"
local MapMarkerLogic = require "MapMarkerLogic"
local SoldierLogic = require "SoldierLogic"
local BattleLosePowerLogic = require "BattleLosePowerLogic"
local LoginLock = {}

---@see 获取角色列表
function response.GetRoleList( msg )
    local uid = msg.uid
    local iggid = msg.iggid

    -- 从登陆服务器获取
    local allLoginds = Common.getClusterNodeByName("login", true)
    local roleInfos, ban = Common.rpcMultiCall(allLoginds[Random.Get(1, #allLoginds)], "RoleQuery", "QueryRoleList", uid, iggid)
    if ban then
        -- 已被封号
        return nil, ErrorCode.ROLE_BAN
    else
        return { roleInfos = roleInfos }
    end
end

---@see 创建角色
function response.CreateRole( msg )
    local uid = msg.uid
    local iggid = msg.iggid
    local country = msg.country
    local version = msg.version
    local languageId = msg.languageId or Enum.LanguageType.ENGLISH

    -- 参数检查
    if not country then
        LOG_ERROR("uid(%d) RoleCreate, no country", uid)
        return nil, ErrorCode.ROLE_ARG_ERROR
    end

    -- 判断角色是否已经创建满
    local allLoginds = Common.getClusterNodeByName("login", true)
    if not Common.rpcMultiCall(allLoginds[Random.Get(1, #allLoginds)], "RoleQuery", "CheckRoleMax", uid, Common.getSelfNodeName()) then
        LOG_ERROR("createRole, role is max, iggid(%s)", iggid)
        return nil, ErrorCode.ROLE_CREATE_MAX
    end

    -- 国家是否存在
    local sCivilization = CFG.s_Civilization:Get( country )
    if not sCivilization or table.empty( sCivilization ) then
        LOG_ERROR("uid(%d) RoleCreate, country(%d) error", uid, country)
        return nil, ErrorCode.ROLE_ARG_ERROR
    end

    --创建角色时,rid不存在,从第一个服务获取rid
    local rid = MSM.d_role[0].req.NewId()
    -- 随机该区域内的空闲坐标
    local pos, setObstracleRef = MapLogic:randomCityIdlePos( rid, uid, nil, nil, true )
    if not pos then
        pos = MapLogic:randomCityIdlePos( rid, uid, nil, nil, nil, true )
        LOG_ERROR("uid(%d) CreateRole, createRole not found pos, set to center!", uid)
    end

    -- 创建角色
    local ret = RoleLogic:createRole( uid, rid, pos, country, iggid, version, languageId )
    -- 移除阻挡
    if setObstracleRef then
        SM.NavMeshObstracleMgr.post.delObstracleByRef( setObstracleRef )
    end
    if not ret then
        LOG_ERROR("uid(%d) CreateRole, createRole fail!", uid)
        -- 移除阻挡
        return nil, ErrorCode.ROLE_CREATE_FAIL
    end

    -- 创建角色数量+1
    Common.redisExecute({ "incr", "gameRoleCount_" .. Common.getSelfNodeName()})

    return { rid = rid }
end

---@see 角色登陆
function response.RoleLogin( msg )
    assert(msg.rid and msg.uid)
    if not LoginLock[msg.uid] then
        LoginLock[msg.uid] = squeue()
    end

    return LoginLock[msg.uid](
        function ()
            local iggid = msg.iggid
            local uid = msg.uid
            local rid = msg.rid
            local ip = msg.ip
            local phone = msg.phone
            local area = msg.area
            local language = msg.language
            local platform = msg.platform
            local version = msg.version
            local gameId = msg.gameId or 0

            -- 判断是否已经有角色
            local exist = RoleLogic:getRole( rid, { Enum.Role.iggid, Enum.Role.rid } )
            if not exist or table.empty(exist) or exist.iggid ~= iggid then
                LOG_ERROR("check role exist fail iggid(%s) rid(%d)", iggid, rid)
                return nil, ErrorCode.ROLE_NOT_EXIST
            end

            -- 通知Agent登陆
            local reportArg = { ip = ip, gameId = gameId, phone = phone, area = area, language = language, platform = platform, version = version }
            local agent = snax.bind(msg.agentHandle, msg.agentName)
            local keeprole, chatSubId, chatServerIp, chatServerRealIp, chatServerPort, chatServerName
                    = agent.req.onRolelogin( uid, rid, msg.username, reportArg )
            if keeprole == nil then
                return { result = false }
            end

            -- 推送建筑数据
            BuildingLogic:syncBuilding( rid, nil, nil, nil, true )
            -- 推送统帅信息
            HeroLogic:pushAllHero( rid )
            -- 推送道具信息
            ItemLogic:syncItem( rid )
            -- 推送斥候信息
            ScoutsLogic:syncScouts( rid )
            -- 推送部队信息
            ArmyLogic:pushAllArmy( rid )
            -- 推送任务信息
            TaskLogic:pushAllTask( rid )
            -- 推送联盟信息
            GuildLogic:pushGuild( rid )
            -- 推送联盟申请信息
            GuildLogic:syncApply( rid )
            -- 推送联盟成员信息
            GuildLogic:pushGuildMembers( rid )
            -- 推送联盟仓库信息
            GuildLogic:pushGuildDepot( rid )
            -- 推送联盟求助信息
            GuildLogic:pushGuildRequestHelps( rid )
            -- 推送联盟建筑信息
            GuildBuildLogic:pushGuildBuilds( rid )
            -- 推送地图领土信息
            GuildTerritoryLogic:pushMapTerritories( rid )
            -- 推送联盟领土线条信息
            GuildTerritoryLogic:pushMapTerritoryLines( rid )
            -- 推送运输车信息
            TransportLogic:pushAllTransport( rid )
            -- 推送联盟战争信息
            RallyLogic:pushGuildRallyInfo( rid )
            -- 检查是否需要发送耐久为0迁城通知
            RoleLogic:checkWallMoveCityNotify( rid )
            -- 推送预警信息
            EarlyWarningLogic:pushEarlyWarning( rid )
            -- 推送联盟圣地信息
            GuildLogic:pushHolyLands( rid )
            -- 推送联盟科技信息
            GuildTechnologyLogic:pushGuildTechnology( rid )
            -- 推送联盟礼物信息
            GuildGiftLogic:pushGuildGifts( rid )
            -- 推送纪念碑信息
            MonumentLogic:pushMonument( rid )
            -- 检查是否推送神秘商店通知
            RoleLogic:checkStoreNotice( rid )
            -- 推送联盟书签信息
            MapMarkerLogic:pushGuildMarkers( rid )
            -- 判断是否触发战损补偿
            BattleLosePowerLogic:checkRoleBattleLosePower( rid )
            -- 进入AOI
            RoleLogic:roleEnterAoi( rid, keeprole,  msg.fd, msg.secret )

            -- 如果时代存在变化，将变化值设为false
            local isChangeAge = RoleLogic:getRole( rid, Enum.Role.isChangeAge )
            if isChangeAge then
                RoleLogic:setRole( rid, { [Enum.Role.isChangeAge] = false } )
            end

            local timezone = tonumber(skynet.getenv("timezone"))
            return {
                        result = true,
                        timezone = timezone,
                        chatSubId = chatSubId,
                        chatServerIp = chatServerIp,
                        chatServerRealIp = chatServerRealIp,
                        chatServerPort = chatServerPort,
                        chatServerName = chatServerName,
                        openTime = Common.getSelfNodeOpenTime()
            }
        end
    )
end

---@see 创建军队
function response.CreateArmy( msg )
    local rid = msg.rid
    local mainHeroId = msg.mainHeroId
    local deputyHeroId = msg.deputyHeroId
    local soldiers = msg.soldiers
    local targetType = msg.targetType
    local targetArg = msg.targetArg
    local isSituStation = msg.isSituStation

    -- 参数检查
    if not mainHeroId or mainHeroId <= 0 or not soldiers or not targetType then
        LOG_ERROR("rid(%d) CreateArmy, no mainHeroId or no soldiers or no targetType arg", rid)
        return nil, ErrorCode.ROLE_ARG_ERROR
    end

    local roleInfo = RoleLogic:getRole( rid, {
        Enum.Role.level, Enum.Role.pos, Enum.Role.technologies, Enum.Role.barbarianLevel,
        Enum.Role.troopsDispatchNumber, Enum.Role.guildId, Enum.Role.situStation
    } )
    local targetInfo, armyStatus
    local targetIndex = targetArg.targetObjectIndex
    -- 若行军目标若不为空地，目标是否还存在
    if targetType ~= Enum.MapMarchTargetType.SPACE then
        if not targetArg or not targetIndex then
            LOG_ERROR("rid(%d) CreateArmy, no targetObjectIndex arg", rid)
            return nil, ErrorCode.ROLE_ARG_ERROR
        end

        targetInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
        if not targetInfo or table.empty( targetInfo ) then
            LOG_ERROR("rid(%d) CreateArmy, targetObjectIndex(%d) not exist", rid, targetIndex)
            return nil, ErrorCode.ROLE_MARCH_TARGET_NOT_EXIST
        end

        -- 野蛮人城寨只能集结攻击
        if targetInfo.objectType == Enum.RoleType.MONSTER_CITY then
            return nil, ErrorCode.MAP_MONSTER_CITY_ONLY_RALLY
        end

        -- 不能攻击自己或者联盟成员
        if targetInfo.objectType == Enum.RoleType.ARMY then
            -- 不能攻击自己
            if targetInfo.rid == rid then
                return nil, ErrorCode.MAP_CANNOT_ATTACK_SELF
            end

            if roleInfo.guildId > 0 then
                -- 同联盟,无法攻击
                if roleInfo.guildId == RoleLogic:getRole( targetInfo.rid, Enum.Role.guildId ) then
                    return nil, ErrorCode.MAP_CANNOT_ATTACK_SELF
                end
            end

            -- 不能攻击溃败的部队
            if ArmyLogic:checkArmyStatus( targetInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
                return nil, ErrorCode.MAP_ATTACK_FAIL_ARMY
            end
        end
        targetArg.pos = nil
    else
        if not targetArg or not targetArg.pos then
            LOG_ERROR("rid(%d) CreateArmy, no pos arg", rid)
            return nil, ErrorCode.ROLE_ARG_ERROR
        end
        armyStatus = Enum.ArmyStatus.SPACE_MARCH
        targetArg.targetObjectIndex = nil
        targetIndex = nil
        targetInfo = { pos = targetArg.pos }
    end

    -- 默认空地坐标
    local preCostActionForce, scienceReq, addSituStation
    local roleSituStation = roleInfo.situStation
    -- 采集,取目标坐标
    if targetType == Enum.MapMarchTargetType.COLLECT then
        if MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
            -- 野外资源田
            -- 该资源点是否正在被采集中
            if targetInfo.collectRid and targetInfo.collectRid > 0 then
                LOG_ERROR("rid(%d) CreateArmy, other role(%d) collect this resouceId(%d)", rid, targetInfo.collectRid, targetInfo.resourceId)
                return nil, ErrorCode.ROLE_OTHER_COLLECT_RESOURCE
            end

            scienceReq = CFG.s_ResourceGatherType:Get( targetInfo.resourceId, "scienceReq" )
        elseif MapObjectLogic:checkIsGuildResourceCenterObject( targetInfo.objectType ) then
            -- 联盟资源中心
            if targetInfo.guildId ~= roleInfo.guildId then
                LOG_ERROR("rid(%d) March, resource center not self guild", rid)
                return nil, ErrorCode.ROLE_COLLECT_CENTER_NOT_SELF_GUILD
            end

            -- 角色等级是否满足采集条件
            if roleInfo.level < CFG.s_Config:Get( "allianceResourcePointReqLevel" ) then
                LOG_ERROR("rid(%d) March, role level not enough", rid)
                return nil, ErrorCode.GUILD_CREATE_BUILD_LEVEL_ERROR
            end

            -- 是否已有角色部队在采集
            local buildInfo = GuildBuildLogic:getGuildBuild( targetInfo.guildId, targetInfo.buildIndex )
            for _, reinforce in pairs( buildInfo.reinforces or {} ) do
                if reinforce.rid == rid then
                    LOG_ERROR("rid(%d) March, role already collect in resource center", rid)
                    return nil, ErrorCode.ROLE_COLLECT_CENTER_ONE_ARMY
                end
            end

            scienceReq = CFG.s_AllianceBuildingType:Get( buildInfo.type, "scienceReq" )
        elseif targetInfo.objectType == Enum.RoleType.RUNE then
            -- 部队完成采集后是否驻扎在原地
            if isSituStation then
                addSituStation = true
                roleSituStation = true
            else
                roleSituStation = false
            end
        else
            LOG_ERROR("rid(%d) CreateArmy, targetObjectIndex(%d) objectType(%d) error", rid, targetIndex, targetInfo.objectType)
            return nil, ErrorCode.MAP_OBJECT_CANT_COLLECT
        end

        -- 所需科技是否学习
        if scienceReq and scienceReq > 0 and not roleInfo.technologies[scienceReq] then
            LOG_ERROR("rid(%d) CreateArmy, not study technology(%d)", rid, scienceReq)
            return nil, ErrorCode.ROLE_RESOURCE_NO_TECHNOLOGY
        end

        armyStatus = Enum.ArmyStatus.COLLECT_MARCH
    elseif targetType == Enum.MapMarchTargetType.ATTACK then
        -- 行军目标为进攻对象且需要消耗行动力，玩家当前剩余行动力值大等于所需的消耗
        if targetInfo.objectType == Enum.RoleType.MONSTER then
            -- 是否需要消耗行动力
            local sMonster = CFG.s_Monster:Get( targetInfo.monsterId )
            if sMonster.type == Enum.MonsterType.BARBARIAN then
                -- 野蛮人
                -- 检测当前野蛮人等级是否>已挑战最高野蛮人等级+1
                if sMonster.level > ( roleInfo.barbarianLevel or 0 ) + 1 then
                    LOG_ERROR("rid(%d) CreateArmy, monsterid(%d) level too high", rid, targetInfo.monsterId)
                    return nil, ErrorCode.MAP_MONSTER_LEVEL_TOO_HIGH
                end
            end

            if sMonster.costAP and sMonster.costAP > 0 then
                if not RoleLogic:checkActionForce( rid, sMonster.costAP ) then
                    LOG_ERROR("rid(%d) CreateArmy, role action force not enough", rid)
                    return nil, ErrorCode.ROLE_ACTION_NOT_ENOUGH
                end

                preCostActionForce = sMonster.costAP
            end

            -- 部队完成攻击后是否驻扎在原地
            if isSituStation then
                addSituStation = true
                roleSituStation = true
            else
                roleSituStation = false
            end
        elseif targetInfo.objectType == Enum.RoleType.CITY then
            -- 判断等级是否满足
            if RoleLogic:getRole( rid, Enum.Role.level ) < CFG.s_Config:Get("attackCityLevel") then
                return nil, ErrorCode.MAP_ATTACK_CITY_LEVEL_ERROR
            end
            -- 是否是同盟玩家
            if roleInfo.guildId > 0 and roleInfo.guildId == RoleLogic:getRole( targetInfo.rid, Enum.Role.guildId ) then
                return nil, ErrorCode.MAP_ATTACK_GUILD_MEMBER
            end
            -- 判断目标是否处于护盾内
            if RoleLogic:checkShield( targetInfo.rid ) then
                -- 发送邮件
                local guildAndRoleName = RoleLogic:getGuildNameAndRoleName( targetInfo.rid )
                local emailArg = { guildAndRoleName }
                EmailLogic:sendEmail( targetInfo.rid, 110000, { subTitleContents = emailArg, emailContents = emailArg } )
                return nil, ErrorCode.MAP_ATTACK_SHILED
            end
        elseif MapObjectLogic:checkIsAttackGuildBuildObject( targetInfo.objectType ) then
            -- 联盟建筑,判断目标是否与联盟领地接壤
            if not GuildTerritoryLogic:checkObjectGuildTerritory( targetIndex, roleInfo.guildId ) then
                LOG_ERROR("rid(%d) CreateArmy checkObjectGuildTerritory with guild fail", rid)
                return nil, ErrorCode.RALLY_TARGET_NOT_BORDER
            end
        elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
            -- 圣地建筑,判断目标是否与联盟领地接壤
            if not GuildTerritoryLogic:checkObjectGuildTerritory( targetIndex, roleInfo.guildId ) then
                LOG_ERROR("rid(%d) CreateArmy checkObjectGuildTerritory with holyland fail", rid)
                return nil, ErrorCode.RALLY_TARGET_NOT_BORDER
            end
            -- 判断是否有在保护期内
            local holyLandStatus = targetInfo.holyLandStatus
            if holyLandStatus == Enum.HolyLandStatus.INIT_PROTECT or holyLandStatus == Enum.HolyLandStatus.LOCK
                or holyLandStatus == Enum.HolyLandStatus.PROTECT then
                LOG_ERROR("rid(%d) CreateArmy CheckPoint or Relic in lock or protect status", rid)
                return nil, ErrorCode.RALLY_HOLYLAND_PROTECT_STATUS
            end
        elseif targetInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND then
            -- 部队完成守护者攻击后是否驻扎在原地
            if isSituStation then
                addSituStation = true
                roleSituStation = true
            else
                roleSituStation = false
            end
        elseif MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
            -- 攻击资源田
            if not targetInfo.collectRid or targetInfo.collectRid <= 0 then
                LOG_ERROR("rid(%d) CreateArmy, targetIndex(%d) not army", rid, targetIndex)
                return nil, ErrorCode.MAP_RESOURCE_ATTACK_NOT_ARMY
            end

            -- 攻击的不能是自己的部队
            if targetInfo.collectRid == rid or ( roleInfo.guildId > 0 and roleInfo.guildId == targetInfo.guildId ) then
                LOG_ERROR("rid(%d) CreateArmy, can't attack self army", rid, targetIndex)
                return nil, ErrorCode.MAP_CANNOT_ATTACK_SELF
            end

            -- 异常导致资源点中实际无部队
            local targetArmyInfo = ArmyLogic:getArmy( targetInfo.collectRid, targetInfo.armyIndex )
            if not targetArmyInfo or table.empty( targetArmyInfo ) or not targetArmyInfo.targetArg
                or targetArmyInfo.targetArg.targetObjectIndex ~= targetIndex then
                LOG_ERROR("rid(%d) CreateArmy, targetIndex(%d) not army", rid, targetIndex)
                return nil, ErrorCode.MAP_RESOURCE_ATTACK_NOT_ARMY
            end
        elseif targetInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
            -- 召唤怪物
            local sMonster = CFG.s_Monster:Get( targetInfo.monsterId )
            -- 是否需要消耗行动力
            if sMonster.costAP and sMonster.costAP > 0 then
                if not RoleLogic:checkActionForce( rid, sMonster.costAP ) then
                    LOG_ERROR("rid(%d) CreateArmy, role action force not enough", rid)
                    return nil, ErrorCode.ROLE_ACTION_NOT_ENOUGH
                end

                preCostActionForce = sMonster.costAP
            end
        end
        armyStatus = Enum.ArmyStatus.ATTACK_MARCH
    elseif targetType ~= Enum.MapMarchTargetType.SPACE then
        -- 行军类型错误
        LOG_ERROR("rid(%d) CreateArmy, targetType(%d) arg", rid, targetType or 0)
        return nil, ErrorCode.ROLE_ARG_ERROR
    end

    -- 判断目标是否可到达
    local navPath = { roleInfo.pos, targetInfo.pos }
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100
    if not ArmyWalkLogic:fixPathPoint( Enum.RoleType.CITY, targetInfo.objectType, navPath, cityRadius, targetInfo.armyRadius, nil, rid, nil, true ) then
        return nil, ErrorCode.MAP_MARCH_PATH_NOT_FOUND
    end

    -- 扣除统帅减免行动力
    if preCostActionForce then
        preCostActionForce = HeroLogic:subHeroVitality( rid, nil, mainHeroId, deputyHeroId, preCostActionForce )
    end

    if addSituStation then
        armyStatus = ArmyLogic:addArmyStatus( armyStatus, Enum.ArmyStatus.STATIONING )
    end
    -- 创建军队
    local armyIndex, armyInfo, error
    armyIndex, armyInfo, error = ArmyLogic:createArmy( rid, mainHeroId, deputyHeroId, soldiers, preCostActionForce,
                                                        targetType, targetArg, armyStatus )
    if not armyIndex then
        return nil, error or ErrorCode.RALLY_CREATE_ARMY_FAIL
    end

    -- 生成一个新的对象ID
    local objectIndex = Common.newMapObjectIndex()
    -- 行军部队加入地图
    MSM.MapMarchMgr[objectIndex].req.armyEnterMap( rid, objectIndex, armyInfo, navPath, targetType, targetIndex, true )

    -- 增加玩家累计派遣部队总次数
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.DISPATCH_ARMY, Enum.TaskArgDefault, 1 )

    -- 更新角色部队驻扎属性
    if roleInfo.situStation ~= roleSituStation then
        -- 更新原地驻扎状态
        RoleLogic:setRole( rid, Enum.Role.situStation, roleSituStation )
        -- 通知客户端
        RoleSync:syncSelf( rid, { [Enum.Role.situStation] = roleSituStation }, true )
    end

    return { armyIndex = armyIndex }
end

---@see 训练士兵包括晋升
function response.TrainArmy( msg )
    local rid = msg.rid
    local buildingIndex = msg.buildingIndex
    local type = msg.type
    local level = msg.level
    local isUpdate = msg.isUpdate
    local trainNum = msg.trainNum
    local immediately = msg.immediately
    local armyQueueIndex = msg.armyQueueIndex
    local guide = msg.guide
    -- 判断所属建筑是否在升级
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.buildQueue, Enum.Role.infantryTrainNumber, Enum.Role.cavalryTrainNumber,
                                            Enum.Role.bowmenTrainNumber, Enum.Role.siegeCarTrainNumber,
                                            Enum.Role.itemAddTroopsCapacity, Enum.Role.itemAddTroopsCapacityCount } )
    local buildQueue = roleInfo.buildQueue
    for _, queue in pairs( buildQueue or {}) do
        if queue.buildingIndex == buildingIndex and queue.finishTime > os.time() then
            LOG_ERROR("rid(%d) TrainArmy fail, this building(%d) updating", rid, buildingIndex)
            return nil, ErrorCode.ROLE_ARMY_BUILDING_UPDATE
        end
    end
    -- 判断所属训练队列是否在训练
    if not immediately and not armyQueueIndex then
        local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue ) or {}
        if armyQueue[type] and armyQueue[type].finishTime and armyQueue[type].finishTime > os.time() then
            LOG_ERROR("rid(%d) TrainArmy fail, this army(%d) is training", rid, type)
            return nil, ErrorCode.ROLE_ARMY_IN_TRAINING
        end
    end
    -- 当前训练的兵种是否处于开启状态
    if not immediately and not RoleLogic:unlockArmy( rid, type, level ) then
        LOG_ERROR("rid(%d) TrainArmy fail, this army(%d) is lock", rid, type)
        return nil, ErrorCode.ROLE_ARMY_LOCK
    end
    -- 如果是晋升判断当前对应兵种待机状态数量是否充足
    if not immediately and isUpdate == Enum.ArmyUpdate.YES and not RoleLogic:checkSoldier( rid, type, level, trainNum ) then
        LOG_ERROR("rid(%d) TrainArmy fail, this army(%d) not enough", rid, type)
        return nil, ErrorCode.ROLE_ARMY_NOT_ENOUGH
    end
    if not immediately and isUpdate == Enum.ArmyUpdate.YES and level ==  ArmyTrainLogic:getArmyMaxLv( rid, type ) then
        LOG_ERROR("rid(%d) TrainArmy fail, this army(%d) level same", rid, type)
        return nil, ErrorCode.ROLE_ARMY_LEVEL_SAME
    end
    -- 判断数量是否大于上限
    local maxNum = 0
    if type == Enum.ArmyType.INFANTRY then
        maxNum = roleInfo.infantryTrainNumber or 0
    elseif type == Enum.ArmyType.CAVALRY then
        maxNum = roleInfo.cavalryTrainNumber or 0
    elseif type == Enum.ArmyType.ARCHER then
        maxNum = roleInfo.bowmenTrainNumber or 0
    elseif type == Enum.ArmyType.SIEGE_UNIT then
        maxNum = roleInfo.siegeCarTrainNumber or 0
    end

    -- 预备部队增加训练数量
    maxNum = maxNum + roleInfo.itemAddTroopsCapacity

    if type and trainNum > maxNum then
        LOG_ERROR("rid(%d) TrainArmy fail, trainNum error", rid)
        return nil, ErrorCode.ROLE_ARMY_TRAIN_NUM_ERROR
    end

    if immediately then
        local args = {}
        args.rid = rid
        args.type = type
        args.level = level
        args.trainNum = trainNum
        args.isUpdate = isUpdate
        args.armyQueueIndex = armyQueueIndex
        args.buildingIndex = buildingIndex
        if armyQueueIndex then
            local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue ) or {}
            if not armyQueue[armyQueueIndex] or armyQueue[armyQueueIndex].finishTime <= os.time() then
                LOG_ERROR("rid(%d) TrainArmy fail, this army(%d) level same", rid, armyQueueIndex)
                return nil, ErrorCode.ROLE_ARMY_TRAIN_FINISH
            end
        end
        return MSM.RoleQueueMgr[rid].req.immediatelyComplete( args )
    end
    local config
    if isUpdate == Enum.ArmyUpdate.YES then
        config = ArmyTrainLogic:getArmsConfig( rid, type, ArmyTrainLogic:getArmyMaxLv( rid, type ) )
    else
        config = ArmyTrainLogic:getArmsConfig( rid, type, level )
    end
    local totalFood
    local totalWood
    local totalStone
    local totalGlod
    if config.needFood then
        totalFood = config.needFood * trainNum
    end
    if config.needWood then
        totalWood = config.needWood * trainNum
    end
    if config.needStone then
        totalStone = config.needStone * trainNum
    end
    if config.needGlod then
        totalGlod = config.needGlod * trainNum
    end
    if isUpdate == Enum.ArmyUpdate.YES then
        config = ArmyTrainLogic:getArmsConfig( rid, type, level )
        if config.needFood then
            totalFood = totalFood - config.needFood * trainNum
        end
        if config.needWood then
            totalWood = totalWood - config.needWood * trainNum
        end
        if config.needStone then
            totalStone = totalStone - config.needStone * trainNum
        end
        if config.needGlod then
            totalGlod = totalGlod - config.needGlod * trainNum
        end
    end

    if totalFood and totalFood > 0 then
        if not RoleLogic:checkFood( rid, totalFood ) then
            LOG_ERROR("rid(%d) TrainArmy error, food not enough", rid)
            return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
        end
    end
    if totalWood and totalWood > 0 then
        if not RoleLogic:checkWood( rid, totalWood ) then
            LOG_ERROR("rid(%d) TrainArmy error, wood not enough", rid)
            return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
        end
    end
    if totalStone and totalStone > 0 then
        if not RoleLogic:checkStone( rid, totalStone ) then
            LOG_ERROR("rid(%d) TrainArmy error, stone not enough", rid)
            return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
        end
    end
    if totalGlod and totalGlod > 0 then
        if not RoleLogic:checkGold( rid, totalGlod ) then
            LOG_ERROR("rid(%d) TrainArmy error, coin not enough", rid)
            return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
        end
    end
    return ArmyTrainLogic:trainArmy( rid, type, level, trainNum, isUpdate, buildingIndex, guide )
end

---@see 训练完成领取士兵
function response.AwardArmy( msg )
    local rid = msg.rid
    local type = msg.type
    local guide = msg.guide
    local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue )
    if not guide and armyQueue[type].finishTime > os.time() then
        LOG_ERROR("rid(%d) awardArmy fail, this army(%d) train not end", rid, type)
        return nil, ErrorCode.ROLE_ARMY_TRAIN_NOT_END
    end
    return ArmyTrainLogic:awardArmy( rid, type )
end

---@see 训练终止
function response.TrainEnd( msg )
    local rid = msg.rid
    local type = msg.type
    local buildingIndex = msg.buildingIndex
    local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue )
    local queue = armyQueue[type]
    if queue.finishTime > -1 then
        --计算消耗了多少资源
        local config = ArmyTrainLogic:getArmsConfig( rid, type, queue.newArmyLevel )
        local totalFood = 0
        local totalWood = 0
        local totalStone = 0
        local totalGlod = 0
        if config.needFood and config.needFood > 0 then
            totalFood = config.needFood * queue.armyNum
        end
        if config.needWood and config.needWood > 0 then
            totalWood = config.needWood * queue.armyNum
        end
        if config.needStone and config.needStone > 0 then
            totalStone = config.needStone * queue.armyNum
        end
        if config.needGlod and config.needGlod > 0 then
            totalGlod = config.needGlod * queue.armyNum
        end
        local logType = Enum.LogType.TRAIN_STOP_GAIN_CURRENCY
        if queue.oldArmyLevel and queue.oldArmyLevel > 0 then
            logType = Enum.LogType.UPGRADE_SOLDIER_STOP_GAIN_DENAR
            config = ArmyTrainLogic:getArmsConfig( rid, type, queue.oldArmyLevel )
            if config.needFood and config.needFood > 0 then
                totalFood =  totalFood - config.needFood * queue.armyNum
            end
            if config.needWood and config.needWood > 0 then
                totalWood =  totalWood - config.needWood * queue.armyNum
            end
            if config.needStone and config.needStone > 0 then
                totalStone = totalStone - config.needStone * queue.armyNum
            end
            if config.needGlod and config.needGlod > 0 then
                totalGlod = totalGlod - config.needGlod * queue.armyNum
            end
        end
        totalFood = math.tointeger(totalFood * CFG.s_Config:Get("trainingTerminate")/ 1000 // 1)
        totalWood = math.tointeger(totalWood * CFG.s_Config:Get("trainingTerminate")/ 1000 // 1)
        totalStone =  math.tointeger(totalStone * CFG.s_Config:Get("trainingTerminate")/ 1000 // 1)
        totalGlod =  math.tointeger(totalGlod * CFG.s_Config:Get("trainingTerminate")/ 1000 // 1)
        if totalFood and totalFood > 0 then
            RoleLogic:addFood( rid, totalFood, nil, logType )
        end
        if totalWood and totalWood > 0 then
            RoleLogic:addWood( rid, totalWood, nil, logType )
        end
        if totalStone and totalStone > 0 then
            RoleLogic:addStone( rid, totalStone, nil, logType )
        end
        if totalGlod and totalGlod > 0 then
            RoleLogic:addGold( rid, totalGlod, nil, logType )
        end
        if queue.oldArmyLevel and queue.oldArmyLevel > 0 then
            ArmyTrainLogic:addSoldiers( rid, type, queue.oldArmyLevel, queue.armyNum, nil, nil, true )
        end
        queue.oldArmyLevel = 0
        queue.newArmyLevel = 0
        queue.armyNum = 0
        MSM.RoleTimer[rid].req.deleteTrainTimer( rid, queue.timerId )
        queue.timerId = -1
        queue.beginTime = 0
        queue.finishTime = -1
        queue.beginTime = 0
        queue.armyType = 0
        RoleLogic:setRole( rid, { [Enum.Role.armyQueue] = armyQueue } )
        RoleSync:syncSelf( rid, { [Enum.Role.armyQueue] = { [queue.queueIndex] = queue } }, true)
        return { buildingIndex = buildingIndex }
    end
end

---@see 获取城内建筑信息
function response.GetBuildInfo( msg )
    -- 根据客户端上传的version，过滤出需要增加发送的建筑信息
    -- 每个建筑都有自己的version,只同步 > 客户端的version的建筑信息
    -- 建筑的version会一直递增
    local version = msg.version
    local ownerRid = msg.ownerRid
    return BuildingLogic:getBuildingInfo( ownerRid, version )
end

---@see 解散士兵
function response.DisbandArmy( msg )
    local rid = msg.rid
    local type = msg.type
    local level = msg.level
    local num = msg.num
    if not RoleLogic:checkSoldier( rid, type, level, num ) then
        LOG_ERROR("rid(%d) DisbandArmy fail, this army(%d) not enough", rid, type)
        return nil, ErrorCode.ROLE_ARMY_NOT_ENOUGH
    end
    return ArmyTrainLogic:disbandArmy( rid, type, level, num )
end

---@see 使用宝石购买资源
function response.BuyResource( msg )
    local rid = msg.rid
    local itemId = msg.itemId
    local itemNum = msg.itemNum

    -- 参数检查
    if not itemId or not itemNum then
        LOG_ERROR("rid(%d) BuyResource, no itemId or no itemNum arg", rid)
        return nil, ErrorCode.ROLE_ARG_ERROR
    end

    local sItem = CFG.s_Item:Get( itemId )
    if not sItem or table.empty( sItem ) then
        LOG_ERROR("rid(%d) BuyResource, s_item no itemId(%d) cfg", rid, itemId)
        return nil, ErrorCode.CFG_ERROR
    end

    -- 是否可以购买
    if not sItem.shortcutPrice or sItem.shortcutPrice <= 0 then
        LOG_ERROR("rid(%d) BuyResource, can't buy itemId(%d)", rid, itemId)
        return nil, ErrorCode.ROLE_RSS_CANT_BUY
    end

    -- 宝石是否足够
    if not RoleLogic:checkDenar( rid, sItem.shortcutPrice * itemNum ) then
        LOG_ERROR("rid(%d) BuyResource, role denar not enough", rid)
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end

    -- 扣除宝石
    local updateTask = true
    RoleLogic:addDenar( rid, - sItem.shortcutPrice * itemNum, nil, Enum.LogType.RESOURCE_CHANGE_COST_DENAR )
    local currencyLogType = Enum.LogType.RESOURCE_CHANGE_GAIN_CURRENCY
    -- 获得资源
    if sItem.subType == Enum.ItemSubType.GOLD then
        -- 增加金币
        RoleLogic:addGold( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.STONE then
        -- 增加石料
        RoleLogic:addStone( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.WOOD then
        -- 增加木材
        RoleLogic:addWood( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.GRAIN then
        -- 增加粮食
        RoleLogic:addFood( rid, sItem.data1 * itemNum, nil, currencyLogType )
    elseif sItem.subType == Enum.ItemSubType.VIP then
        -- 增加VIP
        RoleLogic:addVip( rid, sItem.data1 * itemNum, nil, currencyLogType )
    else
        -- 增加道具
        ItemLogic:addItem( {
            rid = rid,
            itemId = itemId,
            itemNum = itemNum,
            eventType = Enum.LogType.SPECIAL_ITEM_SUPPLY
        } )
        updateTask = false
    end

    if updateTask then
        -- 更新道具使用任务进度
        TaskLogic:updateItemUseTaskSchedule( rid, nil, itemNum, sItem )
    end

    return { itemId = itemId, itemNum = itemNum }
end

---@see 治疗伤兵
function response.Treatment( msg )
    local rid = msg.rid
    local soldiers = msg.soldiers
    local immediately = msg.immediately
    local treatmentQueueIndex = msg.treatmentQueueIndex
    -- 判断数量是否大于医院容量
    -- 判断医院是否都在升级中
    if not immediately then
        local total = 0
        for _, v in pairs(soldiers) do
            total = total + v.num
        end
        local hospitals = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.HOSPITAL ) or {}
        local maxNum = 0
        local hospitalSpaceMulti = RoleLogic:getRole( rid, "hospitalSpaceMulti" ) or 0
        for _, hospital in pairs(hospitals) do
            maxNum = maxNum + CFG.s_BuildingHospital:Get(hospital.level, "armyCnt")
        end
        maxNum = maxNum * ( 1 + hospitalSpaceMulti / 1000) // 1
        if total > maxNum then
            LOG_ERROR("rid(%d) Treatment error, hospital cnt not enough", rid)
            return nil, ErrorCode.ROLE_HOSPITAL_NOT_ENOUGH
        end
        local treatmentQueue = RoleLogic:getRole( rid, Enum.Role.treatmentQueue ) or {}
        if treatmentQueue and not table.empty(treatmentQueue) and treatmentQueue.finishTime > 0  then
            LOG_ERROR("rid(%d) Treatment fail, technology is researching", rid)
            return nil, ErrorCode.ROLE_TREATMENT_NOT_FINISH
        end
        local count = 0
        local buildQueue = RoleLogic:getRole( rid, Enum.Role.buildQueue ) or {}
        for _, v in pairs( hospitals ) do
            for _, queue in pairs( buildQueue ) do
                if queue.buildingIndex == v.buildingIndex and queue.finishTime > 0 then
                    count = count + 1
                end
            end
        end
        if count >= table.size(hospitals) then
            LOG_ERROR("rid(%d) Treatment error, all hospital updating", rid)
            return nil, ErrorCode.ROLE_HOSPITAL_UPDATE
        end
    elseif immediately then
        local args = {}
        args.soldiers = soldiers
        args.rid = rid
        args.treatmentQueueIndex = treatmentQueueIndex
        return MSM.RoleQueueMgr[rid].req.immediatelyComplete( args )
    end
    -- 判断资源是否充足
    local costFood = 0
    local costWood = 0
    local costStone = 0
    local costGold = 0
    for _, v in pairs(soldiers) do
        local config = CFG.s_Arms:Get(v.id)
        if config.woundedFood then
            costFood = costFood + config.woundedFood * v.num
        end
        if config.woundedWood then
            costWood = costWood + config.woundedWood * v.num
        end
        if config.woundedStone then
            costStone = costStone + config.woundedStone * v.num
        end
        if config.woundedGold then
            costGold = costGold + config.woundedGold * v.num
        end
    end
    if costFood > 0 then
        if not RoleLogic:checkFood( rid, costFood ) then
            LOG_ERROR("rid(%d) Treatment error, food not enough", rid)
            return nil, ErrorCode.ROLE_FOOD_NOT_ENOUGH
        end
    end
    if costWood > 0 then
        if not RoleLogic:checkWood( rid, costWood ) then
            LOG_ERROR("rid(%d) Treatment error, wood not enough", rid)
            return nil, ErrorCode.ROLE_WOOD_NOT_ENOUGH
        end
    end
    if costStone > 0 then
        if not RoleLogic:checkStone( rid, costStone ) then
            LOG_ERROR("rid(%d) Treatment error, stone not enough", rid)
            return nil, ErrorCode.ROLE_STONE_NOT_ENOUGH
        end
    end
    if costGold > 0 then
        if not RoleLogic:checkGold( rid, costGold ) then
            LOG_ERROR("rid(%d) Treatment error, coin not enough", rid)
            return nil, ErrorCode.ROLE_GOLD_NOT_ENOUGH
        end
    end
    return HospitalLogic:treatment( rid, soldiers )
end

---@see 伤兵领取
function response.AwardTreatment(msg)
    local rid = msg.rid
    local treatmentQueue = RoleLogic:getRole( rid, Enum.Role.treatmentQueue ) or {}
    if treatmentQueue.finishTime > os.time() then
        LOG_ERROR("rid(%d) AwardTreatment error, treatment not finish", rid)
        return nil, ErrorCode.ROLE_TREATMENT_NOT_FINISH
    end
    if table.empty(treatmentQueue.treatmentSoldiers) then
        LOG_ERROR("rid(%d) AwardTreatment error, not treatmentSoldiers ", rid)
        return nil, ErrorCode.ROLE_TREATMENT_NOT_SOLDIER
    end
    return HospitalLogic:awardTreatment( rid )
end

---@see 加速功能
function response.SpeedUp(msg)
    local rid = msg.rid
    local queueIndex = msg.queueIndex
    local type = msg.type
    local itemId = msg.itemId
    local itemNum = msg.itemNum
    local costDenar = msg.costDenar
    -- 判断道具是否充足
    if not costDenar and not ItemLogic:checkItemEnough( rid, itemId, itemNum ) then
        LOG_ERROR("rid(%d) SpeedUp error, itemId(%d) not enough ", rid, itemId )
        return nil, ErrorCode.ROLE_SPEED_ITEM_NOT_ENOUGH
    end

    -- 判断加速类型和加速队列是否相同
    local sitemInfo = CFG.s_Item:Get(itemId)
    if sitemInfo.subType ~= Enum.ItemSpeedType.COMMON and sitemInfo.subType ~= type then
        LOG_ERROR("rid(%d) SpeedUp error, itemId(%d) type error ", rid, itemId)
        return nil, ErrorCode.ROLE_SPEED_ITEM_TYPE_ERROR
    end

    -- 判断宝石是否充足
    if costDenar and not RoleLogic:checkDenar( rid, sitemInfo.shortcutPrice ) then
        LOG_ERROR("rid(%d) SpeedUp error, role denar not enough ", rid)
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end

    if type == Enum.ItemSpeedType.BUILDING then
        local buildQueue = RoleLogic:getRole( rid, Enum.Role.buildQueue ) or {}
        if buildQueue[queueIndex].finishTime < 0 then
            LOG_ERROR("rid(%d) SpeedUp error, this queue is finish ", rid)
            return nil, ErrorCode.ROLE_SPEED_QUENE_FINISH
        end
    elseif type == Enum.ItemSpeedType.TRINA then
        local armyQueue = RoleLogic:getRole( rid, Enum.Role.armyQueue ) or {}
        if armyQueue[queueIndex].finishTime <= os.time() then
            LOG_ERROR("rid(%d) SpeedUp error, this queue is finish ", rid)
            return nil, ErrorCode.ROLE_SPEED_QUENE_FINISH
        end
    elseif type == Enum.ItemSpeedType.TECHNOLOGY then
        local technologyQueue = RoleLogic:getRole( rid, Enum.Role.technologyQueue ) or {}
        if technologyQueue.finishTime <= os.time() then
            LOG_ERROR("rid(%d) SpeedUp error, this queue is finish ", rid)
            return nil, ErrorCode.ROLE_SPEED_QUENE_FINISH
        end
    elseif type == Enum.ItemSpeedType.TREATMENT then
        local treatmentQueue = RoleLogic:getRole( rid, Enum.Role.treatmentQueue ) or {}
        if treatmentQueue.finishTime <= os.time() then
            LOG_ERROR("rid(%d) SpeedUp error, this queue is finish ", rid)
            return nil, ErrorCode.ROLE_SPEED_QUENE_FINISH
        end
    end
    local sec
    if costDenar and sitemInfo.shortcutPrice and sitemInfo.shortcutPrice > 0 then
        RoleLogic:addDenar( rid, - sitemInfo.shortcutPrice, nil, Enum.LogType.SPEED_UP_COST_DENAR )
        sec = sitemInfo.data1
    else
        ItemLogic:delItemById( rid, itemId, itemNum, nil, Enum.LogType.SEPPE_COST_ITEM )
        sec = sitemInfo.data1 * itemNum
    end
    local finishTime
    if type == Enum.ItemSpeedType.BUILDING then
        finishTime = MSM.RoleQueueMgr[rid].req.buildSpeedUp( rid, queueIndex, sec )
    elseif type == Enum.ItemSpeedType.TRINA then
        finishTime = ArmyTrainLogic:speedUp( rid, queueIndex, sec )
    elseif type == Enum.ItemSpeedType.TECHNOLOGY then
        finishTime = MSM.RoleQueueMgr[rid].req.technologySpeedUp( rid, sec )
    elseif type == Enum.ItemSpeedType.TREATMENT then
        finishTime = MSM.RoleQueueMgr[rid].req.hospitalSpeedUp( rid, sec )
    end
    return { finishTime = finishTime }
end

---@see 心跳
function response.Heart( msg )
    local rid = msg.rid
    if rid then
        MSM.RoleHeartMgr[rid].post.updateRoleHeart( rid, msg.serverTime )
    end

    return { clientTime = msg.clientTime, serverTime = timercore.getmillisecond() }
end

---@see 新手引导步骤更新
function response.NoviceGuideStep( msg )
    local rid = msg.rid
    local noviceGuideStep = msg.noviceGuideStep
    local noviceGuideDetailStep = msg.noviceGuideDetailStep
    local guideId = msg.guideId
    if not guideId then
        if not noviceGuideStep or not noviceGuideDetailStep then
            LOG_ERROR("rid(%d) NoviceGuideStep error, not found noviceGuideStep or noviceGuideDetailStep arg", rid)
            return nil, ErrorCode.ROLE_ARG_ERROR
        end

        local oldNoviceGuideStep = RoleLogic:getRole( rid, Enum.Role.noviceGuideStep )
        RoleLogic:setRole( rid, Enum.Role.noviceGuideStep, noviceGuideStep )

        -- 本次完成的是否是攻击野蛮人引导
        local guideHeroStage = CFG.s_Config:Get( "guideHeroStage" ) or 7
        if not RoleLogic:checkGuideFinish( oldNoviceGuideStep, guideHeroStage )
            and RoleLogic:checkGuideFinish( noviceGuideStep, guideHeroStage ) then
            -- 完成攻击野蛮人引导后，获得神射手统帅
            local guideHero = CFG.s_Config:Get( "guideHero" ) or 0
            if guideHero > 0 then
                HeroLogic:addHero( rid, guideHero )
            end
        end

        -- 完成引导斥候直接返回城市
        local maxGuideStage = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.MAX_GUIDE_STAGE )
        if not RoleLogic:checkGuideFinish( oldNoviceGuideStep, maxGuideStage )
            and RoleLogic:checkGuideFinish( noviceGuideStep, maxGuideStage ) then
            ScoutsLogic:checkScoutsOnForceMoveCity( rid )
        end

        -- 判断是否进入AOI
        local guideHideMapObject = CFG.s_Config:Get("guideHideMapObject")
        if oldNoviceGuideStep < guideHideMapObject and noviceGuideStep >= guideHideMapObject then
            local roleInfo = RoleLogic:getRole( rid, { Enum.Role.pos, Enum.Role.fd, Enum.Role.secret } )
            SM.MapLevelMgr.req.roleEnterMapLevel( rid, roleInfo.pos, roleInfo.fd, roleInfo.secret )
        end
    else
        -- 记录日志
        LogLogic:roleGuide( { rid = rid, iggid = msg.iggid, guideId = guideId or 0 } )
    end
end

---@see 新手引导额外字段更新
function response.NoviceGuideStepEx( msg )
    local rid = msg.rid
    local noviceGuideStepEx = msg.noviceGuideStepEx
    local guideId = msg.guideId
    RoleLogic:setRole( rid, Enum.Role.noviceGuideStepEx, noviceGuideStepEx )
    -- 记录日志
    LogLogic:funcGuide( { iggid = msg.iggid, rid = rid, guideId = guideId } )
end

---@see 修改原地驻扎状态
function response.ModifySituStation( msg )
    local rid = msg.rid

    local situStation = RoleLogic:getRole( rid, Enum.Role.situStation ) or false
    situStation = not situStation
    -- 更新原地驻扎状态
    RoleLogic:setRole( rid, Enum.Role.situStation, situStation )
    -- 通知客户端
    RoleSync:syncSelf( rid, { [Enum.Role.situStation] = situStation }, true )
end

---@see 客户端上报设备状态
function response.ReportSelf( msg )
    local rid = msg.rid
    if not rid then
        return
    end
    RoleLogic:setRole( rid, {
        [Enum.Role.quality] = msg.quality or "",
        [Enum.Role.memory] = msg.memory or "",
        [Enum.Role.fps] = msg.fps or 0,
        [Enum.Role.network] = msg.network or "",
        [Enum.Role.power] = msg.power or 0,
        [Enum.Role.chargeStatus] = msg.chargeStatus or 0,
        [Enum.Role.volume] = msg.volume or 0,
    } )
end

---@see 角色创角操作日志
function response.CreateClick( msg )
    if msg.operateId then
        LogLogic:createClick( { iggid = msg.iggid, operateId = msg.operateId } )
    end
end

---@see 新手剧情日志
function response.GuideDialog( msg )
    if msg.plotId then
        LogLogic:guideDialog( { iggid = msg.iggid, rid = msg.rid, plotId = msg.plotId } )
    end
end

---@see 角色改名
function response.ModifyName( msg )
    local rid = msg.rid
    local name = msg.name
    -- 修改名字为空
    if not name or name == "" then
        LOG_ERROR("rid(%d) ModifyName error, name is null", rid)
        return nil, ErrorCode.ROLE_NAME_NULL
    end
    local sConfig = CFG.s_Config:Get()

    -- 名称长度判断
    local strLen = utf8.len( name )
    if sConfig.playerNameLimit[1] > strLen or sConfig.playerNameLimit[2] < strLen then
        LOG_ERROR("rid(%d) ModifyName, name(%s) length error", rid, name)
        return nil, ErrorCode.ROLE_NAME_LENGTH_ERROR
    end

    -- 名称是否有效
    if not RoleLogic:checkBlockName( name ) then
        LOG_ERROR("rid(%d) ModifyName, name(%s) invalid", rid, name)
        return nil, ErrorCode.ROLE_NAME_INVALID
    end

    -- 名称是否只包括数字
    if RoleLogic:checkNameOnlyNum( name ) then
        LOG_ERROR("rid(%d) ModifyName, name(%s) can not use only num", rid, name)
        return nil, ErrorCode.ROLE_NAME_ONLY_NUM
    end

    -- 判断名称是否与原来相同
    if name == RoleLogic:getRole( rid, Enum.Role.name ) then
        LOG_ERROR("rid(%d) ModifyName, name(%s) same to old name", rid, name)
        return nil, ErrorCode.ROLE_NAME_SAME_OLD_NAME
    end

    -- 判断名字是否被占用
    if SM.GuildNameProxy.req.checkRoleNameRepeat( name ) then
        LOG_ERROR("rid(%d) ModifyName, name(%s) repeat", rid, name)
        return nil, ErrorCode.ROLE_NAME_REPEAT
    end

    -- 判断道具以及代币是否充足
    if not ItemLogic:checkItemEnough( rid, sConfig.playerNameCostItem, 1) and not RoleLogic:checkDenar( rid, sConfig.playerNameCostDenar ) then
        LOG_ERROR("rid(%d) ModifyName, item(%d) and denar not enough", rid, sConfig.playerNameCostItem)
        return nil, ErrorCode.ROLE_NAME_ITEM_DENAR_NOT_ENOUGH
    end

    return RoleLogic:modify( rid, name )
end

---@see 模糊匹配昵称查询角色信息
function response.QueryRoleByParam( msg )
    local rid = msg.rid
    local param = msg.param

    local rids
    local roles = {}
    local fields = {
        Enum.Role.rid, Enum.Role.name, Enum.Role.headId, Enum.Role.combatPower,
        Enum.Role.killCount, Enum.Role.level, Enum.Role.country, Enum.Role.headFrameID,
        Enum.Role.guildId
    }
    local roleInfo
    local guildId = RoleLogic:getRole( rid, Enum.Role.guildId )
    if not param or #param < 1 then
        -- 角色是否在联盟中
        if not guildId or guildId <= 0 then
            LOG_ERROR("rid(%d) QueryRoleByParam, role not in guild", rid)
            return nil, ErrorCode.GUILD_NOT_IN_GUILD
        end
        rids = SM.RoleRecommendMgr.req.getRecommendRids()
        for _, roleId in pairs( rids or {} ) do
            roleInfo = RoleLogic:getRole( tonumber( roleId ), fields )
            if roleInfo then
                roleInfo.guildInvite = GuildLogic:checkGuildInvite( guildId, roleId )
                table.insert( roles, roleInfo )
            end
        end
    else
        rids = MSM.RoleNameMgr[rid].req.getRoleByParam( param )
        for _, roleId in pairs( rids or {} ) do
            roleId = tonumber( roleId )
            roleInfo = RoleLogic:getRole( roleId, fields )
            if guildId and guildId > 0 then
                roleInfo.guildInvite = GuildLogic:checkGuildInvite( guildId, roleId )
            end
            if roleInfo.guildId > 0 then
                roleInfo.guildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
            end
            if roleInfo then
                table.insert( roles, roleInfo )
            end
        end
    end

    return { roles = roles }
end

---@see 增加城市buff
function response.AddBuff( msg )
    local rid = msg.rid
    local buffId = msg.buffId
    local itemId = msg.itemId
    local sCityBuff = CFG.s_CityBuff:Get(buffId)
    if sCityBuff.item == 0 then
        LOG_ERROR("rid(%d) AddBuff, can use item or denar add buff", rid)
        return nil, ErrorCode.ROLE_BUFF_NOT_USE_ITEM
    end
    local sitem = CFG.s_Item:Get(sCityBuff.item)
    if itemId and sCityBuff.item and not ItemLogic:checkItemEnough( rid, sCityBuff.item, 1) then
        LOG_ERROR("rid(%d) AddBuff, item not enough", rid)
        return nil, ErrorCode.ROLE_BUFF_ITEM_NOT_ENOUGH
    end
    if ( not itemId or itemId == 0 ) and not RoleLogic:checkDenar( rid, sitem.shortcutPrice) then
        LOG_ERROR("rid(%d) AddBuff, denar not enough", rid)
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end
    if sCityBuff.type == Enum.RoleCityBuff.SHIELD and RoleLogic:checkWarCarzy( rid ) then
        LOG_ERROR("rid(%d) AddBuff, war carzy can not use shield", rid)
        return nil, ErrorCode.ROLE_BUFF_WAR
    end
    return RoleLogic:addRoleCityBuff( rid, buffId, itemId )
end

---@see 设置角色头像头像框
function response.SetRoleHead( msg )
    local rid = msg.rid
    local id = msg.id
    local sPlayerHead = CFG.s_PlayerHead:Get(id)
    local roleInfo = RoleLogic:getRole( rid )
    local roleChangeInfo = {}
    local changeHead
    local changeHeadFrameID
    -- 头像
    if sPlayerHead.group == Enum.RoleHeadType.HEAD then
        if sPlayerHead.get == Enum.RoleHeadGetWay.NO_SYSTEM then
            -- 判断是否存在
            if not table.exist(roleInfo.headList, id) then
                LOG_ERROR("rid(%d) setRoleHead, head not exist", rid)
                return nil, ErrorCode.ROLE_HEAD_NO_EXIST
            end
        end
        roleChangeInfo[Enum.Role.headId] = id
        changeHead = id
    else
        if sPlayerHead.get == Enum.RoleHeadGetWay.NO_SYSTEM then
            -- 判断是否存在
            if not table.exist(roleInfo.headFrameList, id) then
                LOG_ERROR("rid(%d) AddBuff, head frame not exist", rid)
                return nil, ErrorCode.ROLE_HEAD_FRAME_NO_EXIST
            end
        end
        roleChangeInfo[Enum.Role.headFrameID] = id
        changeHeadFrameID = id
    end
    RoleLogic:setRole( rid, roleChangeInfo )
    RoleSync:syncSelf( rid, roleChangeInfo,true, true )
    -- 角色在联盟中更新联盟修改标识
    if roleInfo.guildId and roleInfo.guildId > 0 then
        MSM.GuildIndexMgr[roleInfo.guildId].post.addMemberIndex( roleInfo.guildId, rid )
        GuildLogic:updateRoleRequestIndexs( rid )
    end
    local cityIndex = RoleLogic:getRoleCityIndex( rid )
    if changeHead then
        MSM.SceneCityMgr[cityIndex].post.updateHeadId( cityIndex, id )
    elseif changeHeadFrameID then
        MSM.SceneCityMgr[cityIndex].post.updateHeadFrameID( cityIndex, id )
    end
    RoleChatLogic:syncRoleInfoToChatServer( rid )
    -- 更新设置头像次数
    TaskLogic:addTaskStatisticsSum( rid, Enum.TaskType.MODIFY_HEADID, Enum.TaskArgDefault, 1 )
    -- 更新联盟建筑或圣地关卡中的部队头像或头像框ID
    ArmyLogic:updateArmyInfoOnRoleInfoChange( rid, changeHead, changeHeadFrameID )
    -- 集结部队头像更新
    RallyLogic:syncRallyRoleInfo( rid, nil, changeHead, changeHeadFrameID )

    return {result = true}
end

---@see 领取vip每日点数
function response.GetVipPoint( msg )
    local rid = msg.rid
    -- 判断今日是否领取过了
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.vipExpFlag, Enum.Role.continuousLoginDay, Enum.Role.vip } )
    if roleInfo.vipExpFlag then
        LOG_ERROR("rid(%d) GetVipPoint, today have awarded", rid)
        return nil, ErrorCode.ROLE_VIP_AWARDED
    end
    local sVipDayPoint = CFG.s_VipDayPoint:Get()
    local maxPoint = 0
    for _, vipDayPoint in pairs(sVipDayPoint) do
        if roleInfo.continuousLoginDay >= vipDayPoint.day and vipDayPoint.point >= maxPoint then
            maxPoint = vipDayPoint.point
        end
    end
    RoleLogic:addVip( rid, maxPoint, nil, Enum.LogType.DAY_FREE_GAIN_VIP )
    roleInfo.vipExpFlag = true
    RoleLogic:setRole( rid, { [Enum.Role.vipExpFlag] = true } )
    RoleSync:syncSelf( rid, { [Enum.Role.vipExpFlag] = true }, true )
end

---@see 领取vip
function response.GetVipFreeBox( msg )
    local rid = msg.rid
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.vip, Enum.Role.vipFreeBox } )
    if roleInfo.vipFreeBox then
        LOG_ERROR("rid(%d) GetVipFreeBox, today have awarded", rid)
        return nil, ErrorCode.ROLE_VIP_AWARDED
    end
    local level = RoleLogic:getVipLv( roleInfo.vip )
    local sVip = CFG.s_Vip:Get(level)
    RoleLogic:setRole( rid, { [Enum.Role.vipFreeBox] = true } )
    RoleSync:syncSelf( rid, { [Enum.Role.vipFreeBox] = true }, true )
    local rewardInfo = ItemLogic:getItemPackage( rid, sVip.freeBox )
    return { rewardInfo = rewardInfo }
end

---@see 查询角色信息
function response.GetRoleInfo(msg)
    local queryRid = msg.queryRid
    local fields = {
        Enum.Role.rid, Enum.Role.name, Enum.Role.headId, Enum.Role.combatPower,
        Enum.Role.killCount, Enum.Role.level, Enum.Role.country, Enum.Role.headFrameID,
        Enum.Role.roleStatistics, Enum.Role.guildId, Enum.Role.historyPower
    }
    local gameNode = RoleLogic:getRoleGameNode( queryRid )
    local roleInfo = Common.rpcMultiCall( gameNode, "d_role", "Get", queryRid, fields ) or {}
    if not roleInfo then
        return {}
    end

    if roleInfo.guildId > 0 then
        local guildInfo = Common.rpcCall( gameNode, "c_guild", "Get", roleInfo.guildId, { Enum.Guild.name, Enum.Guild.abbreviationName } )
        roleInfo.guildName = guildInfo.name
        roleInfo.guildAbbName = guildInfo.abbreviationName
    end

    return { roleInfo = roleInfo }
end

---@see 领取每日特惠免费宝箱
function response.GetFreeDaily( msg )
    local rid = msg.rid
    local freeDaily = RoleLogic:getRole( rid, Enum.Role.freeDaily )
    if freeDaily then
        LOG_ERROR("rid(%d) GetFreeDaily, today have awarded", rid)
        return nil, ErrorCode.ROLE_DAILY_FREE_AWARDED
    end
    return RechargeLogic:getFreeDaily( rid )
end

---@see 获取纪念碑信息
function response.GetMonument( msg )
    local rid = msg.rid
    return MonumentLogic:getMonument( rid )
end

---@see 获取纪念碑奖励
function response.GetMonumentReward( msg )
    local rid = msg.rid
    local id = msg.id
    -- 判断是否能领奖
    local sEvolutionMileStone = CFG.s_EvolutionMileStone:Get()[id]
    local cMonument = SM.c_monument.req.Get(id)
    local monumentBuilding = BuildingLogic:getBuildingInfoByType( rid, Enum.BuildingType.MONUMENT )[1]
    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.monumentInfo, Enum.Role.denseFogOpenFlag, Enum.Role.denseFogOpenTime } )
    local monumentInfo = roleInfo.monumentInfo
    if not monumentBuilding or table.empty(monumentBuilding) then
        LOG_ERROR("rid(%d) GetMonumentReward, can't reward Monument Reward", rid)
        return nil, ErrorCode.ROLE_CAN_NOT_MONUMENT_REWARD
    end
    if sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE or
        sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.ALLIANCE_RANK then
        if not monumentInfo[id] or not monumentInfo[id].canReward then
            LOG_ERROR("rid(%d) GetMonumentReward, can't reward Monument Reward", rid)
            return nil, ErrorCode.ROLE_CAN_NOT_MONUMENT_REWARD
        end
    elseif sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.SERVER then
        if cMonument.count < sEvolutionMileStone.require then
            LOG_ERROR("rid(%d) GetMonumentReward, can't reward Monument Reward", rid)
            return nil, ErrorCode.ROLE_CAN_NOT_MONUMENT_REWARD
        end
    elseif sEvolutionMileStone.getRewardType == Enum.MonumentRewardObject.PERSON then
        -- 先检查角色是否已经全部手动探索完
        DenseFogLogic:checkDenseFogOnRoleLogin( rid )
        if not RoleLogic:getRole( rid, Enum.Role.denseFogOpenFlag ) or roleInfo.denseFogOpenTime >= cMonument.finishTime then
            LOG_ERROR("rid(%d) GetMonumentReward, can't reward Monument Reward", rid)
            return nil, ErrorCode.ROLE_CAN_NOT_MONUMENT_REWARD
        end
    end
    -- 判断是否领过
    if monumentInfo[id] and monumentInfo[id].reward then
        LOG_ERROR("rid(%d) GetMonumentReward, can't reward Monument Reward", rid)
        return nil, ErrorCode.ROLE_AWARDED_MONUMENT
    end
    return MonumentLogic:getMonumentReward( rid, id )
end

---@see 更换文明
function response.ChangeCivilization( msg )
    local rid = msg.rid
    local civilizationId = msg.civilizationId
    local useItem = msg.useItem

    local itemId = CFG.s_Config:Get("civilizationAlterItem")
    -- 判断道具是否充足
    if useItem and not ItemLogic:checkItemEnough( rid, itemId, 1 ) then
        LOG_ERROR("rid(%d) ChangeCivilization, item not enough", rid)
        return nil, ErrorCode.ITEM_NOT_ENOUGH
    end
    local sitem = CFG.s_Item:Get(itemId)
    -- 使用宝石判断宝石是否充足
    if not useItem and not RoleLogic:checkDenar( rid, sitem.shopPrice ) then
        LOG_ERROR("rid(%d) ChangeCivilization, item not enough", rid)
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end
    -- 判断城市是否处于战斗状态
    local objectIndex = RoleLogic:getRoleCityIndex( rid )

    -- 判断部队是否在野外
    if table.size(ArmyLogic:getArmy( rid )) > 0 then
        LOG_ERROR("rid(%d) ChangeCivilization, city in battleing", rid)
        return nil, ErrorCode.ROLE_CIVIL_ARMY_IN_FIELD
    end

    -- 如果城市正在被攻击,无法转换文明
    local cityInfo = MSM.SceneCityMgr[objectIndex].req.getCityInfo( objectIndex )
    if ArmyLogic:checkArmyStatus( cityInfo.status, Enum.ArmyStatus.BATTLEING ) then
        LOG_ERROR("rid(%d) ChangeCivilization, city in battleing", rid)
        return nil, ErrorCode.ROLE_CIVIL_IN_BATTLE
    end
    -- 判断训练队列是否空闲
    local roleInfo = RoleLogic:getRole( rid )
    for _, armyInfo in pairs(roleInfo.armyQueue) do
        if armyInfo.armyType and armyInfo.armyType > 0 then
            LOG_ERROR("rid(%d) ChangeCivilization, city in battleing", rid)
            return nil, ErrorCode.ROLE_CIVIL_ARMY_QUEUE_NOT_FREE
        end
    end
    -- 判断训练部队是否空闲
    if not table.empty( roleInfo.seriousInjured ) then
        LOG_ERROR("rid(%d) ChangeCivilization, city in battleing", rid)
        return nil, ErrorCode.ROLE_CIVIL_HOSPITAL_NOT_FREE
    end
    if useItem then
        ItemLogic:delItemById( rid, itemId, 1, nil, Enum.LogType.CHANGE_CIVIL_COST_ITEM )
    else
        RoleLogic:addDenar( rid, -sitem.shopPrice, nil, Enum.LogType.CHANGE_CIVIL_COST_CURRENCY )
    end
    -- 特色兵种转换
    local oldCivilization = CFG.s_Civilization:Get(roleInfo.country)
    local newCivilization = CFG.s_Civilization:Get(civilizationId)
    -- 新增的士兵
    local addSoldierInfo = {}
    -- 减少的士兵
    local subSoldierInfo = {}

    -- 判断原有特色兵种
    for _, id in pairs(oldCivilization.featureArms) do
        if roleInfo.soldiers[id] then
            local config = ArmyTrainLogic:getArmsConfig( rid, roleInfo.soldiers[id].type, roleInfo.soldiers[id].level, nil, civilizationId )
            -- 添加新兵种
            if not addSoldierInfo[config.ID] then
                addSoldierInfo[config.ID] = { id = config.ID, num = 0, minor = 0 }
            end
            addSoldierInfo[config.ID].num = addSoldierInfo[config.ID].num + roleInfo.soldiers[id].num

            -- 删除旧兵种
            if not subSoldierInfo[id] then
                subSoldierInfo[id] = { id = id, num = 0, minor = 0 }
            end
            subSoldierInfo[id].num = subSoldierInfo[id].num + roleInfo.soldiers[id].num
        end
    end

    -- 旧文明的普通兵种 转化为 新文明的特色兵种
    for _, id in pairs(newCivilization.featureArms) do
        repeat
        local dictNewSpecialArms = CFG.s_Arms:Get(id)
        if not dictNewSpecialArms then break end

        local dictOldNormalArms = ArmyTrainLogic:getArmsConfig( rid, dictNewSpecialArms.armsType, dictNewSpecialArms.armsLv, nil, roleInfo.country )
        if not dictOldNormalArms then break end

        -- 玩家没有对应的旧文明兵种 continue
        if not roleInfo.soldiers[dictOldNormalArms.ID] then break end

        -- 删除旧文明普通兵种
        if not subSoldierInfo[dictOldNormalArms.ID] then
            subSoldierInfo[dictOldNormalArms.ID] = { id = dictOldNormalArms.ID, num = 0, minor = 0 }
        end
        subSoldierInfo[dictOldNormalArms.ID].num = subSoldierInfo[dictOldNormalArms.ID].num + roleInfo.soldiers[dictOldNormalArms.ID].num

        -- 添加新文明特色兵种
        if not addSoldierInfo[id] then
            addSoldierInfo[id] = { id = id, num = 0, minor = 0 }
        end
        addSoldierInfo[id].num = addSoldierInfo[id].num + roleInfo.soldiers[dictOldNormalArms.ID].num

        until true
    end

    local newHistorySoldiers = {}
    -- 判断原有特色兵种(历史兵种)
    for _, id in pairs(oldCivilization.featureArms) do
        if roleInfo.historySoldiers[id] then
            local config = ArmyTrainLogic:getArmsConfig( rid, roleInfo.historySoldiers[id].type, roleInfo.historySoldiers[id].level, nil, civilizationId )
            local new = table.copy(roleInfo.historySoldiers[id], true)
            new.id = config.ID
            newHistorySoldiers[config.ID] = new
            roleInfo.historySoldiers[id] = nil
        end
    end

    -- 新增特色兵种处理(历史兵种)
    for _, id in pairs(newCivilization.featureArms) do
        local sArms = CFG.s_Arms:Get(id)
        for soldierId, soldier in pairs(roleInfo.historySoldiers) do
            if soldier.type == sArms.armsType and soldier.level == sArms.armsLv then
                local new = table.copy(soldier)
                new.id = id
                newHistorySoldiers[id] = new
                roleInfo.historySoldiers[soldierId] = nil
            end
        end
    end
    for id, soldier in pairs(roleInfo.historySoldiers) do
        newHistorySoldiers[id] = soldier
    end

    local oldRoleInfo = table.copy( roleInfo, true )
    -- 扣除旧文明属性加成
    RoleCacle:reduceCivilizationAttr( roleInfo )
    RoleLogic:updateRoleChangeInfo( rid, oldRoleInfo, roleInfo )
    -- 改变成新文明
    roleInfo.country = civilizationId
    roleInfo.historySoldiers = newHistorySoldiers
    -- 计算新文明加成
    RoleCacle:cacleCivilizationAttr( roleInfo )
    RoleLogic:setRole( rid, { [Enum.Role.country] = civilizationId, [Enum.Role.historySoldiers] = newHistorySoldiers } )
    -- 同步客户端
    RoleSync:syncSelf( rid, { [Enum.Role.country] = civilizationId, [Enum.Role.historySoldiers] = newHistorySoldiers }, true )
    -- 增加士兵
    SoldierLogic:addSoldier( rid, addSoldierInfo )
    -- 减少士兵
    SoldierLogic:subSoldier( rid, subSoldierInfo )

    -- 通知aoi 城市文明变化
    MSM.SceneCityMgr[objectIndex].post.syncCityCountry( objectIndex, civilizationId )
    -- 检查角色相关属性信息是否变化
    RoleCacle:checkRoleAttrChange( rid, oldRoleInfo, roleInfo )

    return { result = true }
end

---@see 使用宝石购买行动力
function response.BuyActionForce( msg )
    local rid = msg.rid
    local buyActionForceCount = RoleLogic:getRole( rid, Enum.Role.buyActionForceCount )
    local denarChangeEnery1 = CFG.s_Config:Get("denarChangeEnery1")
    local denar
    if buyActionForceCount >= table.size(denarChangeEnery1) then
        denar = denarChangeEnery1[table.size(denarChangeEnery1)]
    else
        denar = denarChangeEnery1[buyActionForceCount + 1]
    end
    if not RoleLogic:checkDenar( rid, denar ) then
        LOG_ERROR("rid(%d) BuyActionForce, denar not enough", rid)
        return nil, ErrorCode.ROLE_DENAR_NOT_ENOUGH
    end
    RoleLogic:addDenar( rid, -denar, nil, Enum.LogType.BUY_ACTION_FORCE_COST_CURRENCY)
    RoleLogic:addActionForce( rid, CFG.s_Config:Get("denarChangeEnery2"), nil, Enum.LogType.BUY_ACTION_FORCE_GAIN_CURRENCY )
    RoleLogic:setRole( rid, { [Enum.Role.buyActionForceCount] = buyActionForceCount + 1 } )
    RoleSync:syncSelf( rid, { [Enum.Role.buyActionForceCount] = buyActionForceCount + 1} , true, true )
    return { result = true }
end

---@see 屏蔽预警信息
function response.ShiledEarlyWarning( msg )
    local rid = msg.rid
    local earlyWarningIndex = msg.earlyWarningIndex

    -- 参数判断
    if not earlyWarningIndex then
        return nil, ErrorCode.ROLE_ARG_ERROR
    end

    MSM.EarlyWarningMgr[rid].post.shiledEarlyWarning( rid, earlyWarningIndex )
end

---@see 获取城市增援记录
function response.GetCityReinforceRecord( msg )
    local rid = msg.rid
    local reinforceRecord = RoleLogic:getRole( rid, Enum.Role.reinforceRecord )
    return { reinforceRecord = reinforceRecord }
end

---@see 获取其他城市增援信息
function response.GetCityReinforceInfo( msg )
    local rid = msg.rid
    local targetRid = msg.targetRid
    local reinforces = RoleLogic:getRole( targetRid, Enum.Role.reinforces )

    -- 过滤是自己的
    local reinforceArmyInfo = {}
    for reinforceRid, reinforceInfo in pairs(reinforces) do
        if rid == reinforceRid then
            table.insert( reinforceArmyInfo, reinforceInfo )
        end
    end

    -- 获取联盟中心当前容量
    local armyCountMax = CityReinforceLogic:getMaxCityReinforce( targetRid )
    local armyCount = RoleLogic:getAllianceCenterReinforceCount( targetRid )

    return { reinforceArmyInfo = reinforceArmyInfo, armyCount = armyCount, armyCountMax = armyCountMax }
end

---@see 点击好评
function response.SetPraise( msg )
    local rid = msg.rid
    RoleLogic:setRole( rid, Enum.Role.praiseFlag, true )
    -- 同步
    RoleSync:syncSelf( rid, { [Enum.Role.praiseFlag] = true }, true )
end

---@see 推送修改
function response.SettingPush( msg )
    local rid = msg.rid
    local id = msg.id
    local pushSetting = RoleLogic:getRole( rid, Enum.Role.pushSetting )
    if pushSetting[id].open == Enum.PushOpen.OPEN then
        pushSetting[id].open = Enum.PushOpen.CLOSE
    else
        pushSetting[id].open = Enum.PushOpen.OPEN
    end
    RoleLogic:setRole( rid, Enum.Role.pushSetting, pushSetting )
    -- 同步
    RoleSync:syncSelf( rid, { [Enum.Role.pushSetting] = { [id] = pushSetting[id] } }, true )
end

---@see 查询名字信息
function response.QueryRoleName( msg )
    local ret, info = SM.GuildNameProxy.req.checkRoleNameRepeat( msg.name )

    local res = { name = msg.name, rid = 0 }

    if not ret then
        return res
    end

    res.rid = info.rid
    res.gameNode = info.gameNode

    local roleBrief = RoleLogic:getGameRole(res.rid, { Enum.Role.rid, Enum.Role.name, Enum.Role.headId,
                                                        Enum.Role.headFrameID, Enum.Role.level, Enum.Role.guildId })
    if not roleBrief then
        return res
    end

    res.headId = roleBrief.headId
    res.headFrameID = roleBrief.headFrameID
    if roleBrief.guildId ~= 0 then
        res.guildAbbr = GuildLogic:getGuild( roleBrief.guildId, Enum.Guild.abbreviationName )
    end

    return res
end

---@see 更新广告埋点
function response.UpdateEventTrancking( msg )
    local rid = msg.rid
    local eventTrancking = msg.eventTrancking

    RoleLogic:setRole( rid, Enum.Role.eventTrancking, eventTrancking )
end

---@see 迁服移民
function response.Immigrate( msg )
    local rid = msg.rid
    local targetGameNode = msg.targetGameNode

    -- 目标服务器是否在线
    if not Common.checkNodeExist( targetGameNode ) then
        return nil, ErrorCode.ROLE_IMMIGRATE_GAMENODE_NOT_FOUND
    end

    -- 不能是本服务器
    if targetGameNode == Common.getSelfNodeName() then
        return nil, ErrorCode.ROLE_IMMIGRATE_GAMENODE_NOT_FOUND
    end

    local roleInfo = RoleLogic:getRole( rid, { Enum.Role.iggid, Enum.Role.guildId, Enum.Role.uid } )
    local cityIndex = RoleLogic:getRoleCityIndex( rid )
    local cityStatus = MSM.MapObjectTypeMgr[cityIndex].req.getObjectStatus( cityIndex )
    if ArmyLogic:checkArmyStatus( cityStatus, Enum.ArmyStatus.BATTLEING ) then
        -- 退出战斗
        local BattleCreate = require "BattleCreate"
        BattleCreate:exitBattle( cityIndex, true )
    end

    -- 城市从地图退出
    CityHideLogic:hideCity( rid )

    -- 清理活动数据
    RoleLogic:setRole( rid, Enum.Role.activity, {} )

    --TODO:清理排行榜数据

    -- 清理联盟
    if roleInfo.guildId > 0 then
        local leaderRid = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.leaderRid )
        if leaderRid == rid then
            -- 解散联盟
            GuildLogic:disbandGuild( roleInfo.guildId )
        else
            -- 退出联盟
            GuildLogic:exitGuild( roleInfo.guildId, rid )
        end
    end

    -- 更新角色数据
    RoleLogic:saveRoleData( rid )

    -- 通知目标服务器角色移民
    local newRid = Common.rpcMultiCall( targetGameNode, "RoleImmigrateMgr", "immigrateFromOtherServer",
                                rid, roleInfo.uid, roleInfo.iggid, Common.getSelfNodeName(), Common.getDbNode() )
    if newRid then
        -- 清理本服务器的角色数据
        local userNames, agents = Common.getUserNameAndAgentByRid( rid )
        if not table.empty(agents) then
            RoleSync:syncKick( rid, Enum.SystemKick.IMMIGRATE_KICK )
            agents[1].req.kickAgent( userNames[1], true )
            LOG_INFO("rid(%d) username(%s) Immigrate, kickAgent", rid, userNames[1])
        end
        local EntityLoad = require "EntityLoad"
        EntityLoad.deleteRole( rid )
        -- 创建角色数量-1
        Common.redisExecute({ "decr", "gameRoleCount_" .. Common.getSelfNodeName()})
        return { newRid = newRid }
    else
        LOG_ERROR("rid(%d) RoleImmigrateMgr fail", rid)
        return { }
    end
end

---@see 选择最后登录服务器以及角色
function response.SetLastServerAndRole( msg )
    local iggid = msg.iggid
    local selectGameNode = msg.selectGameNode
    local selectRid = msg.selectRid

    if not selectGameNode then
        return nil, ErrorCode.ROLE_SWITCH_NOT_FOUND_NODE
    end

    -- 判断目标节点是否存在
    if not Common.getClusterNodeByName( selectGameNode ) then
        return nil, ErrorCode.ROLE_SWITCH_NOT_FOUND_NODE
    end

    local allLoginNode = Common.getClusterNodeByName("login", true)
    -- 判断角色是否存在
    if selectRid then
        if not allLoginNode then
            return nil, ErrorCode.ROLE_SWITCH_NOT_FOUND_NODE
        end
        if not Common.rpcCall( allLoginNode[1], "AccountMgr", "checkGameNodeHadRole", iggid, selectGameNode, selectRid ) then
            return nil, ErrorCode.ROLE_SWITCH_NOT_FOUND_ROLE
        end
    end

    -- 通知登录服务器,修改角色最后登录的服务器和角色
    if not Common.rpcCall( allLoginNode[1], "AccountMgr", "setLastGameNode", iggid, selectGameNode, selectRid ) then
        return nil, ErrorCode.ROLE_SWITCH_NOT_FOUND_NODE
    end

    return { selectGameNode = selectGameNode, selectRid = selectRid }
end