--[[
* @file : GuildHolyLandMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu Jul 09 2020 20:39:17 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟圣地管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local TaskLogic = require "TaskLogic"
local GuildLogic = require "GuildLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local HolyLandLogic = require "HolyLandLogic"
local BattleCreate = require "BattleCreate"
local Random = require "Random"
local ArmyLogic = require "ArmyLogic"
local RoleLogic = require "RoleLogic"

---@class defaultGuildHolyLandInfoClass
local defaultGuildHolyLandInfo = {
    objectIndex                 =               0,                      -- 圣地关卡对象索引
    strongHoldId                =               0,                      -- 圣地关卡ID
    pos                         =               {},                     -- 圣地关卡坐标
    valid                       =               false,                  -- 联盟圣地状态
    reinforceIndex              =               0,                      -- 部队增援最大索引
}

---@see 联盟圣地信息
local guildHolyLands = {}

---@see 联盟占领圣地关卡
function response.occupyHolyLand( _guildId, _holyLandId, _pos, _valid, _territoryIds, _objectIndex, _isInit )
    -- 旗帜所在点设置为可行走点
    MSM.AStarMgr[_guildId].req.setWalkable( _guildId, _territoryIds )
    -- 更新地块信息
    MSM.GuildTerritoryMgr[_guildId].req.addGuildTerritory( _guildId, _territoryIds )
    -- 添加到联盟圣地信息中
    if not guildHolyLands[_guildId] then
        guildHolyLands[_guildId] = {}
    end
    ---@type defaultGuildHolyLandInfoClass
    local holyLandInfo = const( table.copy( defaultGuildHolyLandInfo, true ) )
    holyLandInfo.strongHoldId = _holyLandId
    holyLandInfo.pos = _pos
    holyLandInfo.valid = _valid
    holyLandInfo.objectIndex = _objectIndex
    guildHolyLands[_guildId][_holyLandId] = holyLandInfo

    if not _isInit then
        local allMembers = GuildLogic:getGuild( _guildId, Enum.Guild.members )
        -- 检查当前失效旗帜信息
        GuildBuildLogic:checkGuildInvalidFlags( _guildId )
        -- 更新联盟成员增加该圣地
        local members = GuildLogic:getAllOnlineMember( _guildId, allMembers )
        GuildLogic:syncGuildHolyLands( members, { [_holyLandId] = {
            strongHoldId = _holyLandId,
            status = Enum.GuildHolyLandStatus.NORMAL,
            pos = _pos,
        } } )
        -- 增加任务统计计数
        local holyLandType = CFG.s_StrongHoldData:Get( _holyLandId, "type" )
        local sStrongHoldType = CFG.s_StrongHoldType:Get( holyLandType )
        local taskType
        if HolyLandLogic:isCheckPointType( sStrongHoldType.group ) then
            taskType = Enum.TaskType.OCCUPY_CHECKPOINT
        elseif HolyLandLogic:isRelicType( sStrongHoldType.group ) then
            taskType = Enum.TaskType.OCCUPY_HOLYlAND
        end
        local defaultTaskArg = Enum.TaskArgDefault
        for memberRid in pairs( allMembers or {} ) do
            TaskLogic:addTaskStatisticsSum( memberRid, taskType, defaultTaskArg, 1 )
        end
        -- 联盟集结此圣地的部队直接解散
        local rallyTeams = MSM.RallyMgr[_guildId].req.getGuildRallyInfo( _guildId ) or {}
        for rallyRid, rallyTeam in pairs( rallyTeams ) do
            if rallyTeam.rallyTargetIndex == _objectIndex then
                local isdisbandRally = true
                local rallyObjectIndex = rallyTeam.rallyObjectIndex
                local rallyObjectInfo
                if rallyObjectIndex and rallyObjectIndex > 0 then
                    rallyObjectInfo = MSM.SceneArmyMgr[rallyObjectIndex].req.getArmyInfo( rallyObjectIndex )
                    if rallyObjectInfo then
                        -- 处于战斗而且不处于行军,说明正在攻击圣地,不解散,部队退出战斗会自动解散
                        if not ArmyLogic:checkArmyWalkStatus( rallyObjectInfo.status ) and ArmyLogic:checkArmyStatus( rallyObjectInfo.status, Enum.ArmyStatus.BATTLEING ) then
                            isdisbandRally = false
                        end
                    end
                end

                if isdisbandRally then
                    MSM.RallyMgr[_guildId].req.disbandRallyArmy( _guildId, rallyRid )
                end
            end
        end
    end
end

---@see 联盟删除圣地关卡
function response.deleteHolyLand( _guildId, _holyLandId, _territoryIds )
    -- 相应坐标点设为不可行走
    MSM.AStarMgr[_guildId].req.setUnwalkable( _guildId, _territoryIds )
    -- 更新地块信息
    MSM.GuildTerritoryMgr[_guildId].req.deleteGuildTerritory( _guildId, _territoryIds )
    -- 检查当前有效旗帜信息
    GuildBuildLogic:checkGuildValidFlags( _guildId )
    if guildHolyLands[_guildId] and guildHolyLands[_guildId][_holyLandId] then
        guildHolyLands[_guildId][_holyLandId] = nil
        if table.empty( guildHolyLands[_guildId] ) then
            guildHolyLands[_guildId] = nil
        end
    end
    -- 通知全联盟删除该圣地
    local members = GuildLogic:getAllOnlineMember( _guildId )
    GuildLogic:syncGuildHolyLands( members, nil, _holyLandId )
    MSM.GuildAttrMgr[_guildId].post.loseHolyLand( _guildId, _holyLandId )
end

---@see 获取联盟圣地信息
function response.getGuildHolyLand( _guildId )
    return guildHolyLands[_guildId]
end

---@see 更新圣地状态
function accept.updateGuildHolyLandValid( _guildId, _holyLands, _valid )
    if guildHolyLands[_guildId] then
        for _, holyLandId in pairs( _holyLands ) do
            if guildHolyLands[_guildId][holyLandId] then
                guildHolyLands[_guildId][holyLandId].valid = _valid
                HolyLandLogic:setHolyLand( holyLandId, { [Enum.HolyLand.valid] = _valid } )
            end
        end
    end
end

---@see 解散联盟移除圣地
function accept.deleteHolyLandsOnDisbandGuild( _guildId )
    local objectIndex
    local updateHolyLandInfo = {
        guildId = 0,
        guildAbbName = "",
        guildFlagSigns = {},
    }
    local attackers, mapArmyInfo, armyList, guildIds
    local sStrongHoldData = CFG.s_StrongHoldData:Get()
    for holyLandId, holyLand in pairs( guildHolyLands[_guildId] or {} ) do
        objectIndex = holyLand.objectIndex
        -- 神庙类型
        if sStrongHoldData[holyLandId].type == Enum.HolyLandType.LOST_TEMPLE then
            updateHolyLandInfo.kingName = ""
        else
            updateHolyLandInfo.kingName = nil
        end
        -- 更新圣地信息
        HolyLandLogic:setHolyLand( holyLandId, { [Enum.HolyLand.guildId] = 0 } )
        -- 更新aoi圣地信息
        MSM.SceneHolyLandMgr[objectIndex].post.updateHolyLandInfo( objectIndex, updateHolyLandInfo )
        -- 获取圣地被攻击角色
        attackers = MSM.AttackAroundPosMgr[objectIndex].req.getAttackers( objectIndex ) or {}
        -- 圣地关卡退出战斗
        BattleCreate:exitBattle( objectIndex, true )
        MSM.SceneHolyLandMgr[objectIndex].req.cleanGarrisonOnDisbandGuild( objectIndex )
        armyList = {}
        guildIds = {}
        for _, attackerIndexs in pairs( attackers ) do
            for _, attackerIndex in pairs( attackerIndexs ) do
                mapArmyInfo = MSM.SceneArmyMgr[attackerIndex].req.getArmyInfo( attackerIndex )
                armyList[attackerIndex] = mapArmyInfo
                if mapArmyInfo.guildId > 0 and not table.exist( guildIds, mapArmyInfo.guildId ) then
                    table.insert( guildIds, mapArmyInfo.guildId )
                end
            end
        end

        local guildIdNum = #guildIds
        if guildIdNum >= 1 then
            local occupyGuildId = Random.GetRange( 1, guildIdNum, 1 )[1]
            if MSM.GuildMgr[occupyGuildId].req.occupyHolyLand( occupyGuildId, holyLandId ) then
                -- 占领成功, 攻击部队增援到圣地中
                for _, armyInfo in pairs( armyList ) do
                    if not armyInfo.isRally and armyInfo.guildId == occupyGuildId then
                        MSM.GuildMgr[occupyGuildId].req.reinforceHolyLand( occupyGuildId, armyInfo.rid, armyInfo.armyIndex, armyInfo, objectIndex )
                    end
                end
            end
        end
    end

    guildHolyLands[_guildId] = nil
end

---@see 增援联盟圣地关卡
function response.reinforceHolyLand( _guildId, _rid, _reinforceObjectIndex, _reinforceArmys )
    -- 增援的不是自己联盟占领的圣地
    local mapHolyLandInfo = MSM.SceneHolyLandMgr[_reinforceObjectIndex].req.getHolyLandInfo( _reinforceObjectIndex ) or {}
    if not mapHolyLandInfo or table.empty( mapHolyLandInfo ) or mapHolyLandInfo.guildId ~= _guildId
        or not guildHolyLands[_guildId] or not guildHolyLands[_guildId][mapHolyLandInfo.strongHoldId] then
        return nil, ErrorCode.RALLY_NOT_GUILD_HOLY_LAND
    end

    -- 检测圣地增援人数是否已到上限
    local holyLandId = mapHolyLandInfo.strongHoldId
    local holyLandType = CFG.s_StrongHoldData:Get( holyLandId, "type" )
    local armyCntLimit = CFG.s_StrongHoldType:Get( holyLandType, "armyCntLimit" ) or 0
    local reinforces = HolyLandLogic:getHolyLand( holyLandId, Enum.HolyLand.reinforces ) or {}
    local soldierNum = 0
    for _, reinforceArmy in pairs( _reinforceArmys ) do
        soldierNum = soldierNum + ArmyLogic:getArmySoldierCount( reinforceArmy.armyInfo and reinforceArmy.armyInfo.soldiers or {} )
    end
    local alreadyReinforce = {}
    for index, reinforce in pairs( reinforces ) do
        if reinforce.rid == _rid and _reinforceArmys[reinforce.armyIndex] then
            alreadyReinforce[reinforce.armyIndex] = index
        else
            -- 其他角色部队或者该角色的之前已经增援的部队
            soldierNum = soldierNum + ArmyLogic:getArmySoldierCount( nil, reinforce.rid, reinforce.armyIndex )
        end
    end
    if soldierNum > armyCntLimit then
        LOG_ERROR("rid(%d) reinforceHolyLand error, soldierNum(%d) greater than armyCntLimit(%d)", _rid, soldierNum, armyCntLimit)
        return nil, ErrorCode.RALLY_HOLY_LAND_SOLDIER_LIMIT
    end

    if not guildHolyLands[_guildId][holyLandId].reinforceIndex or guildHolyLands[_guildId][holyLandId].reinforceIndex <= 0 then
        guildHolyLands[_guildId][holyLandId].reinforceIndex = HolyLandLogic:getHolyLandArmyMaxIndex( holyLandId ) or 1
    end

    local armyList = {}
    local reinforceIndex, arrivalTime
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.pos, Enum.Role.guildId
    } )
    for armyIndex, reinforceArmy in pairs( _reinforceArmys ) do
        if not alreadyReinforce[armyIndex] then
            -- 新增援此圣地的部队
            reinforceIndex = guildHolyLands[_guildId][holyLandId].reinforceIndex + 1
            guildHolyLands[_guildId][holyLandId].reinforceIndex = reinforceIndex
        else
            -- 该部队已增援在该建筑中
            reinforceIndex = alreadyReinforce[armyIndex]
        end

        arrivalTime = HolyLandLogic:reinforceHolyLand( _rid, armyIndex, reinforceArmy.armyInfo,
                _reinforceObjectIndex, reinforceArmy.fromType, reinforceIndex, mapHolyLandInfo )
        reinforces[reinforceIndex] = {
            reinforceIndex = reinforceIndex,
            rid = _rid,
            armyIndex = armyIndex,
        }
        armyList[reinforceIndex] = {
            buildArmyIndex = reinforceIndex,
            rid = _rid,
            armyIndex = armyIndex,
            soldiers = reinforceArmy.armyInfo.soldiers,
            status = reinforceArmy.armyInfo.status,
            arrivalTime = arrivalTime,
            mainHeroId = reinforceArmy.armyInfo.mainHeroId,
            deputyHeroId = reinforceArmy.armyInfo.deputyHeroId,
            mainHeroLevel = reinforceArmy.armyInfo.mainHeroLevel,
            deputyHeroLevel = reinforceArmy.armyInfo.deputyHeroLevel,
            roleName = roleInfo.name,
            roleHeadId = roleInfo.headId,
            roleHeadFrameId = roleInfo.headFrameID,
        }

    end
    -- 更新圣地增援信息
    HolyLandLogic:setHolyLand( holyLandId, { [Enum.HolyLand.reinforces] = reinforces } )
    -- 推送联盟圣地部队信息到关注角色中
    HolyLandLogic:syncHolyLandArmy( _reinforceObjectIndex, armyList )
    -- 如果圣地被集结了,推送到联盟战争
    local isRally = SM.RallyTargetMgr.req.checkTargetIsRallyed( roleInfo.guildId, _reinforceObjectIndex )
    if isRally then
        -- 获取公会在线成员
        local onlineMemberRids = GuildLogic:getAllOnlineMember( roleInfo.guildId )
        -- 推送给被集结公会
        local reinforceDetail = HolyLandLogic:getHolyLandReinforceInfo( _reinforceObjectIndex )
        Common.syncMsg( onlineMemberRids, "Rally_RallyBattleInfo", {
            rallyedDetail = {
                [_reinforceObjectIndex] = {
                    rallyedIndex = _reinforceObjectIndex,
                    reinforceDetail = reinforceDetail
                }
            }
        } )
    end

    return true
end

---@see 联盟简称修改更新圣地关卡名称
function accept.updateGuildAbbName( _guildId, _guildAbbName )
    local updateHolyLandInfo = { guildAbbName = _guildAbbName }
    for _, holyLand in pairs( guildHolyLands[_guildId] or {} ) do
        -- 更新aoi信息
        MSM.SceneHolyLandMgr[holyLand.objectIndex].post.updateHolyLandInfo( holyLand.objectIndex, updateHolyLandInfo )
    end
end

---@see 联盟旗帜修改更新圣地关卡
function accept.updateGuildFlagSigns( _guildId, _guildFlagSigns )
    local updateHolyLandInfo = { guildFlagSigns = _guildFlagSigns }
    for _, holyLand in pairs( guildHolyLands[_guildId] or {} ) do
        -- 更新aoi信息
        MSM.SceneHolyLandMgr[holyLand.objectIndex].post.updateHolyLandInfo( holyLand.objectIndex, updateHolyLandInfo )
    end
end