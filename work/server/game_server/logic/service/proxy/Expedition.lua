--[[
* @file : Expedition.lua
* @type : snax multi service
* @author : chenlei
* @created : Wed Dec 16 2020 21:31:39 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 远征相关协议代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local HeroLogic = require "HeroLogic"
local ArmyDef = require "ArmyDef"
local ExpeditionLogic = require "ExpeditionLogic"
local ArmyMarchLogic = require "ArmyMarchLogic"
local RoleSync = require "RoleSync"
local MapLogic = require "MapLogic"

---@see 发起远征挑战
function response.ExpeditionChallenge(msg)
    local rid = msg.rid
    local id = msg.id
    local troops = msg.troops

    -- 判断远征系统是否开启
    if not RoleLogic:checkSystemOpen( rid, Enum.SystemId.EXPEDITION ) then
        LOG_ERROR("rid(%d) ExpeditionChallenge, system not open", rid)
        return nil, ErrorCode.EXPEDITION_NO_OPEN
    end
    local roleInfo = RoleLogic:getRole( rid, {
        Enum.Role.historySoldiers, Enum.Role.level,
        Enum.Role.troopsCapacity, Enum.Role.troopsCapacityMulti, Enum.Role.expeditionInfo
    } )
    local sExpedition = CFG.s_Expedition:Get(id)

    -- 判断前置关卡是否通关
    if sExpedition.level > 1 then
        --local expedition = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.EXPEDITION )
        --local level = sExpedition.level - 1
        local preId = sExpedition.frontNumber
        if not roleInfo.expeditionInfo[preId] then
            LOG_ERROR("rid(%d) ExpeditionChallenge, pre level not pass", rid)
            return nil, ErrorCode.EXPEDITION_PRE_LEVEL_NOT_PASS
        end
    end

    -- 判断部队数量是否小于1
    if table.size(troops) < 1 then
        LOG_ERROR("rid(%d) ExpeditionChallenge, troops num must more then 1 ", rid)
        return nil, ErrorCode.EXPEDITION_TROOPS_NUM_LESS
    end

    -- 判断部队数量是否超出配置值
    if table.size(troops) > sExpedition.troopsNumber then
        LOG_ERROR("rid(%d) ExpeditionChallenge, troops full", rid)
        return nil, ErrorCode.EXPEDITION_TROOPS_FULL
    end
    -- 如果在远征中就直接返回
    local mapIndex = RoleLogic:getRole( rid, Enum.Role.mapIndex )

    if mapIndex > 0 then
        LOG_ERROR("rid(%d) ExpeditionChallenge, have start", rid)
        return nil, ErrorCode.EXPEDITION_STARTING
    end

    local heroId = {}
    local soldiers = {}
    for i = 1, table.size(troops) do
        local troopInfo = troops[i]
        local soldierSum = 0
        -- 判断统帅是否重复
        if heroId[troopInfo.mainHeroId] or heroId[troopInfo.deputyHeroId] then
            LOG_ERROR("rid(%d) ExpeditionChallenge, hero not free", rid)
            return nil, ErrorCode.EXPEDITION_HERO_NOT_FREE
        end
        -- 选择副将，主将是否已达三星
        local mainHeroInfo = HeroLogic:getHero( rid, troopInfo.mainHeroId )
        if troopInfo.deputyHeroId and troopInfo.deputyHeroId > 0 and mainHeroInfo.star < 3 then
            LOG_ERROR("rid(%d) ExpeditionChallenge, mainHeroId(%d) star(%d) not enough", rid, troopInfo.mainHeroId, mainHeroInfo.star)
            return nil, ErrorCode.EXPEDITION_HERO_STAR_NOT_ENOUGH
        end

        for _, soldierInfo in pairs( troopInfo.soldiers ) do
            -- 士兵是否充足
            if not roleInfo.historySoldiers[soldierInfo.id] or roleInfo.historySoldiers[soldierInfo.id].num < soldierInfo.num then
                LOG_ERROR("rid(%d) ExpeditionChallenge, soldier type(%d) level(%d) not enough", rid, soldierInfo.type, soldierInfo.level)
                return nil, ErrorCode.EXPEDITION_SOLDIER_NOT_ENOUGH
            end
            if not soldiers[soldierInfo.id] then soldiers[soldierInfo.id] = { id = soldierInfo.id, num = 0 } end
            soldiers[soldierInfo.id].num = soldiers[soldierInfo.id].num + soldierInfo.num
            soldierSum = soldierSum + soldierInfo.num
        end

        local sHero = CFG.s_Hero:Get( troopInfo.mainHeroId )
        -- 士兵总数是否小于部队容量
        local heroLevelId = sHero.rare * 10000 + mainHeroInfo.level
        local sHeroLevel = CFG.s_HeroLevel:Get( heroLevelId )
        local troopsCapacityMulti = roleInfo.troopsCapacityMulti or 0

        -- 统帅技能天赋影响
        if troopInfo.mainHeroId and troopInfo.mainHeroId > 0 then
            troopsCapacityMulti = troopsCapacityMulti + HeroLogic:getHeroAttr( rid, troopInfo.mainHeroId, Enum.Role.troopsCapacityMulti )
        end
        if troopInfo.deputyHeroId and troopInfo.deputyHeroId > 0 then
            troopsCapacityMulti = troopsCapacityMulti + HeroLogic:getHeroAttr( rid, troopInfo.deputyHeroId, Enum.Role.troopsCapacityMulti, true )
        end

        local troopsCapacity = ( ( roleInfo.troopsCapacity or 0 ) + sHeroLevel.soldiers ) * ( 1000 + troopsCapacityMulti ) / 1000
        if i == 1 and sExpedition.type == Enum.ExpeditionBattleType.DEFEND then
            troopsCapacity = CFG.s_ExpeditionBattle:Get(sExpedition.battleID, "playerCityMaxNumber")
        end
        if soldierSum > troopsCapacity then
            LOG_ERROR("rid(%d) ExpeditionChallenge, soldier(%d) too much", rid, soldierSum)
            return nil, ErrorCode.EXPEDITION_SOLDIER_TOO_MUCH
        end
    end

    -- 判断总士兵数目是否充足
    for _, soldierInfo in pairs( soldiers ) do
        -- 士兵是否充足
        if not roleInfo.historySoldiers[soldierInfo.id] or roleInfo.historySoldiers[soldierInfo.id].num < soldierInfo.num then
            LOG_ERROR("rid(%d) ExpeditionChallenge, soldier type(%d) level(%d) not enough", rid, soldierInfo.type, soldierInfo.level)
            return nil, ErrorCode.EXPEDITION_SOLDIER_NOT_ENOUGH
        end
    end

    local armyInfos = {}
    for i = 1, table.size(troops) do
        local troopInfo = troops[i]
        -- 设置部队信息
        local armyIndex = troopInfo.armyIndex or 1
        armyInfos[armyIndex] = ArmyDef:getDefaultArmyAttr()
        armyInfos[armyIndex].armyIndex = troopInfo.armyIndex
        armyInfos[armyIndex].mainHeroId = troopInfo.mainHeroId
        armyInfos[armyIndex].deputyHeroId = troopInfo.deputyHeroId

        local mainHeroLevel, deputyHeroLevel
        mainHeroLevel = HeroLogic:getHero( rid, troopInfo.mainHeroId, Enum.Hero.level )
        if troopInfo.deputyHeroId and troopInfo.deputyHeroId > 0 then
            deputyHeroLevel = HeroLogic:getHero( rid, troopInfo.deputyHeroId, Enum.Hero.level )
        end

        armyInfos[armyIndex].mainHeroLevel = mainHeroLevel
        armyInfos[armyIndex].deputyHeroLevel = deputyHeroLevel

        if armyIndex == 1 and sExpedition.type == Enum.ExpeditionBattleType.RALLY then
            for _, soldierInfo in pairs( troopInfo.soldiers ) do
                soldierInfo.num = soldierInfo.num * 6
            end
        end
        for key, soldierInfo in pairs(troopInfo.soldiers) do
            if soldierInfo.num <= 0 then
                troopInfo.soldiers[key] = nil
            end
        end

        armyInfos[armyIndex].soldiers = troopInfo.soldiers
    end
    local initialCamera = CFG.s_ExpeditionBattle:Get( sExpedition.battleID, "initialCamera" )
    local posX = initialCamera[1] * Enum.MapPosMultiple
    local posY = initialCamera[2]* Enum.MapPosMultiple
    mapIndex = SM.ExpeditionAoiSpaceMgr.req.getFreeMapIndex()
    -- 怪物生成，部队生成逻辑
    SM.ExpeditionMgr.req.createArmyAndMonster( rid, id, armyInfos, mapIndex )
    RoleLogic:setRole( rid, { [Enum.Role.mapIndex] = mapIndex, [Enum.Role.expeditionTime] = os.time(), [Enum.Role.expeditionId] = id } )
    RoleSync:syncSelf( rid, { [Enum.Role.mapIndex] = mapIndex }, true, true )
    -- 角色进入远征地图aoi
    local pos = { x = posX, y = posY }
    roleInfo = RoleLogic:getRole( rid, { Enum.Role.fd, Enum.Role.secret })
    MSM.AoiMgr[mapIndex].req.roleEnter( mapIndex, rid, pos, pos, roleInfo.fd, roleInfo.secret )
    local endTime = os.time() + sExpedition.times
    -- 添加定时器
    MSM.RoleTimer[rid].req.addExpeditionTimer( rid, endTime )
    return { id = id, endTime = endTime }
end

---@see 快速领取远征奖励
function response.OneKeyAward( msg )
    local rid = msg.rid
    local id = msg.id
    if id and id > 0 then
        return ExpeditionLogic:awardChapterReward( rid, id )
    end
    return ExpeditionLogic:oneKeyAward( rid )
end

---@see 退出远征
function response.Exit( msg )
    local rid = msg.rid
    local mapIndex = RoleLogic:getRole( rid, Enum.Role.mapIndex )
    if mapIndex == 0 then
        return nil
    end
    return ExpeditionLogic:exitExpedition( rid )
end

---@see 远征行军
function response.March( msg )
    local rid = msg.rid
    local objectIndex = msg.objectIndex
    local targetArg = msg.targetArg
    local targetType = msg.targetType

    local objectIndexs = msg.objectIndexs

    -- 兼容老版本客户端处理
    if not objectIndexs or table.empty( objectIndexs ) then
        if objectIndex then
            objectIndexs = { objectIndex }
        end
    end

    local armyList = {}
    local fixLen
    for i, index in pairs( objectIndexs ) do
        armyList[index] = {}
        local armyInfo = MSM.SceneExpeditionMgr[index].req.getExpeditionInfo( index )
        -- 判断军队是否存在
        if not armyInfo or armyInfo.rid <= 0 then
            LOG_ERROR("rid(%d) March, objectIndex(%d) not exist", rid, index)
            return nil, ErrorCode.EXPEDITION_ARMY_NOT_EXIST
        end

        -- 目标是否还存在
        local targetInfo, checkError = ArmyMarchLogic:checkMarchTargetExist( rid, targetArg, targetType, armyInfo )
        if not targetInfo and checkError then
            return nil, checkError
        end

        local roleInfo = RoleLogic:getRole( rid )
        armyList[index].pos = armyInfo.pos
        armyList[index].armyRadius = armyInfo.armyRadius
        -- 获取目标点坐标、状态
        if i == 1 and targetType == Enum.MapMarchTargetType.SPACE then
            -- 向空地行军的第一支部队是否在部队的半径范围内
            -- 在半径范围内，其他部队与第一支部队目标为同一个坐标
            -- 不在半径范围内，其他部队按照第一支部队的半径修正目标坐标
            if not MapLogic:checkRadius( armyList[index].pos, targetArg.pos, armyList[index].armyRadius ) then
                fixLen = armyList[index].armyRadius
            end
        end
        local targetPosInfo
        if i == 1 then
            targetPosInfo = ArmyMarchLogic:getTargetPos( rid, targetType, targetArg, targetInfo, roleInfo, armyInfo, nil, true )
        else
            targetPosInfo = ArmyMarchLogic:getTargetPos( rid, targetType, targetArg, targetInfo, roleInfo,
                    armyInfo, nil, true, fixLen, armyList[index].pos )
        end
        if not targetPosInfo.targetPos then
            return nil, targetPosInfo.armyStatus
        end
        armyList[index].targetPosInfo = targetPosInfo
    end
    for _, index in pairs( objectIndexs ) do
        -- 处理行军
        local targetPosInfo = armyList[index].targetPosInfo
        ArmyMarchLogic:dispatchExpeditionMarch( rid, index, targetArg, targetType, targetPosInfo.targetPos, targetPosInfo.armyStatus, targetPosInfo.targetObjectIndex )
    end
end