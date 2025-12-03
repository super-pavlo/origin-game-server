--[[
* @file : SceneCityMgr.lua
* @type : snax multi service
* @author : linfeng
* @created : Thu May 03 2018 11:29:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图城市管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"
local BuildingLogic = require "BuildingLogic"
local ArmyLogic = require "ArmyLogic"
local EmailLogic = require "EmailLogic"
local ArmyDef = require "ArmyDef"
local RallyLogic = require "RallyLogic"

---@see 地图怪物信息
---@class defaultMapCityInfoClass
local defaultMapCityInfo = {
    pos                         =                   {},             -- 城市坐标
    rid                         =                   0,              -- 角色rid
    name                        =                   "",             -- 角色名字
    level                       =                   0,              -- 角色等级
    country                     =                   0,              -- 所属国家
    power                       =                   0,              -- 角色战斗力
    killCount                   =                   {},             -- 累计击杀
    guildAbbName                =                   "",             -- 联盟简称
    guildFullName               =                   "",             -- 联盟全称
    guildId                     =                   0,              -- 联盟ID
    beginBurnTime               =                   0,              -- 开始燃烧时间
    status                      =                   0,              -- 城市状态
    armyRadius                  =                   0,              -- 城市半径
    armyCountMax                =                   0,              -- 城市部队数量上限
    armyCount                   =                   0,              -- 当前部队数量
    maxSp                       =                   0,              -- 最大怒气
    sp                          =                   0,              -- 当前怒气
    cityBuff                    =                   {},             -- 城市buff
    headId                      =                   0,              -- 城市头像ID
    headFrameID                 =                   0,              -- 城市头像框
    mainHeroId                  =                   0,              -- 城市主将ID
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    guardTowerLevel             =                   0,              -- 警戒塔等级
    cityPosTime                 =                   0,              -- 城市在此坐标的时间
    battleBuff                  =                   {},             -- 战斗BUFF
}

---@type table<int, defaultMapCityInfoClass>
local mapCityInfos = {}
---@type table<int, table>
local armyWalkToInfo = {}

---@see 增加城市对象
function response.addCityObject( _objectIndex, _cityInfo )
    local roleInfo = RoleLogic:getRole( _cityInfo.rid, { Enum.Role.combatPower, Enum.Role.killCount, Enum.Role.level,
                            Enum.Role.guildId, Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.mainHeroId } ) or {}
    local buildInfo = BuildingLogic:getBuildingInfoByType( _cityInfo.rid, Enum.BuildingType.WALL )[1] or {}
    local guildAbbName = ""
    local guildFullName = ""
    if roleInfo.guildId and roleInfo.guildId > 0 then
        local guildInfo = GuildLogic:getGuild( roleInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.name } )
        if guildInfo then
            guildAbbName = guildInfo.abbreviationName
            guildFullName = guildInfo.name
        end
    end
    local _, buffInfo = RoleLogic:checkShield( _cityInfo.rid )
    local cityBuff = {}
    if buffInfo then
        cityBuff[buffInfo.id] = buffInfo
    end

    local mapCityInfo = const( table.copy( defaultMapCityInfo, true ) )
    mapCityInfo.rid = _cityInfo.rid
    mapCityInfo.pos = _cityInfo.pos
    mapCityInfo.name = roleInfo.name
    mapCityInfo.level = roleInfo.level
    mapCityInfo.country = _cityInfo.country
    mapCityInfo.killCount = roleInfo.killCount
    mapCityInfo.power = roleInfo.combatPower
    mapCityInfo.guildAbbName = guildAbbName
    mapCityInfo.guildFullName = guildFullName
    mapCityInfo.beginBurnTime = buildInfo.beginBurnTime or 0
    mapCityInfo.cityBuff = cityBuff or {}
    mapCityInfo.status = Enum.ArmyStatus.ARMY_STANBY
    mapCityInfo.headId = roleInfo.headId
    mapCityInfo.headFrameID = roleInfo.headFrameID
    mapCityInfo.armyRadius = CFG.s_Config:Get("cityRadius") * 100
    mapCityInfo.armyCountMax = 0
    mapCityInfo.armyCount = 0
    mapCityInfo.maxSp = 0
    mapCityInfo.sp = 0
    mapCityInfo.guildId = roleInfo.guildId
    mapCityInfo.mainHeroId = roleInfo.mainHeroId
    mapCityInfo.guardTowerLevel = BuildingLogic:getBuildingLv( _cityInfo.rid, Enum.BuildingType.GUARDTOWER )
    mapCityInfo.cityPosTime = os.time()
    mapCityInfos[_objectIndex] = mapCityInfo
end

---@see 删除城市对象
function accept.deleteCityObject( _objectIndex )
    -- 取消集结部队
    local rallyTargetInfo = SM.RallyTargetMgr.req.getRallyTargetInfo( _objectIndex )
    if rallyTargetInfo then
        local rallyTeamInfo
        for guildId, rid in pairs(rallyTargetInfo) do
            local rallyTeamObject
            -- 如果集结部队正在战斗,不取消,战斗结束会自动取消
            ---@type defaultRallyTeamClass
            rallyTeamInfo = MSM.RallyMgr[guildId].req.getRallyTeamInfo( guildId, rid )
            if rallyTeamInfo.rallyObjectIndex and rallyTeamInfo.rallyObjectIndex > 0 then
                rallyTeamObject = MSM.SceneArmyMgr[rallyTeamInfo.rallyObjectIndex].req.getArmyInfo( rallyTeamInfo.rallyObjectIndex )
            end

            -- 集结部队未出发或者不在战斗
            if not rallyTeamObject or not ArmyLogic:checkArmyStatus( rallyTeamObject.status, Enum.ArmyStatus.RALLY_BATTLE ) then
                MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, rid, false, false, rallyTeamObject == nil )
            end
        end
    end

    mapCityInfos[_objectIndex] = nil
    armyWalkToInfo[_objectIndex] = nil

    MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
end

---@see 获取城市坐标
function response.getCityPos( _objectIndex )
    if mapCityInfos[_objectIndex] then
        return mapCityInfos[_objectIndex].pos
    end
end

---@see 获取城市状态
function response.getCityStatus( _objectIndex )
    if mapCityInfos[_objectIndex] then
        return mapCityInfos[_objectIndex].status
    end
end

---@see 更新城市信息
function accept.updateCityInfo( _objectIndex, _cityInfo )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex] = _cityInfo
    end
end

---@see 更新城市坐标
function response.updateCityPos( _objectIndex, _pos )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].pos = _pos
        mapCityInfos[_objectIndex].cityPosTime = os.time()
    end
end

---@see 更新城市等级
function accept.updateCityLevel( _objectIndex, _level )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].level = _level
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { cityLevel = _level } )
    end
end

---@see 获取城市信息
function response.getCityInfo( _objectIndex )
    return mapCityInfos[_objectIndex]
end

---@see 更新城市战斗力.角色战斗力
function accept.updateCityPower( _objectIndex, _power )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].power = _power
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { objectPower = _power } )
    end
end

---@see 更新角色击杀
function accept.updateCityKillCount( _rid, _objectIndex, _killCount )
    if mapCityInfos[_objectIndex] then
        -- 更新到角色属性中
        RoleLogic:setRole( _rid, Enum.Role.killCount, _killCount )
        mapCityInfos[_objectIndex].killCount = _killCount
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { killCount = _killCount } )
    end
end

---@see 更新城市联盟
function response.syncGuildId( _objectIndex, _guildId )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].guildId = _guildId
        if _guildId and _guildId > 0 then
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.abbreviationName, Enum.Guild.name } )
            mapCityInfos[_objectIndex].guildAbbName = guildInfo.abbreviationName
            mapCityInfos[_objectIndex].guildFullName = guildInfo.name
        else
            mapCityInfos[_objectIndex].guildAbbName = ""
            mapCityInfos[_objectIndex].guildFullName = ""
        end

        -- 同步联盟信息
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, {
                                                            guildId = _guildId,
                                                            guildAbbName = mapCityInfos[_objectIndex].guildAbbName,
                                                            guildFullName = mapCityInfos[_objectIndex].guildFullName
         } )
    end
end

---@see 更新联盟简称
function accept.syncGuildAbbName( _objectIndex, _guildAbbName )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].guildAbbName = _guildAbbName

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildAbbName = _guildAbbName } )
    end
end

---@see 更新城市名称
function accept.updateCityName( _objectIndex, _name )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].name = _name

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { cityName = _name } )
    end
end

---@see 更新城市燃烧时间
function accept.updateCityBeginBurnTime( _objectIndex, _beginBurnTime )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].beginBurnTime = _beginBurnTime
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { beginBurnTime = _beginBurnTime } )
    end
end

---@see 更新城市buff保护时间
function accept.updateCityBuff( _objectIndex, _cityBuff )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].cityBuff = _cityBuff
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { cityBuff = _cityBuff } )
    end
end

---@see 添加向城市行军的对象
function accept.addArmyMoveToCity( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapCityInfos[_objectIndex] then
        if not armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex] = {}
        end
        armyWalkToInfo[_objectIndex][_armyObjectIndex] = { marchType = _marchType, arrivalTime = _arrivalTime }

        local armyInfo = MSM.MapObjectTypeMgr[_armyObjectIndex].req.getObjectInfo( _armyObjectIndex )
        local armyMarchInfo = ArmyDef:getDefaultArmyMarchInfo()
        armyMarchInfo.objectIndex = _armyObjectIndex
        armyMarchInfo.rid = armyInfo.rid
        armyMarchInfo.path = _path
        armyMarchInfo.guildId = armyInfo.guildId
        mapCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除向城市行军的对象
function accept.delArmyMoveToCity( _objectIndex, _armyObjectIndex )
    if mapCityInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
        end
    end
end

---@see 更新向目标行军的目标联盟
function accept.updateArmyWalkObjectGuildId( _objectIndex, _armyObjectIndex, _guildId )
    if mapCityInfos[_objectIndex] and mapCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end

---@see 城市迁城
function accept.cityMove( _objectIndex, _pos )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].pos = _pos
        -- 如果城市正在被攻击,退出战斗
        if ArmyLogic:checkArmyStatus( mapCityInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            RoleLogic:cityExitBattle( _objectIndex )
        end
    end

    -- 所有向目标行军的部队回城
    if armyWalkToInfo[_objectIndex] then
        for moveObjectIndex in pairs(armyWalkToInfo[_objectIndex]) do
            local armyInfo = MSM.SceneArmyMgr[moveObjectIndex].req.getArmyInfo( moveObjectIndex )
            if armyInfo then
                if armyInfo.isRally then
                    -- 集结部队解散
                    local guildId = RoleLogic:getRole( armyInfo.rid, Enum.Role.guildId )
                    MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, armyInfo.rid )
                else
                    MSM.MapMarchMgr[moveObjectIndex].req.marchBackCity( armyInfo.rid, moveObjectIndex )
                end
            end
        end
        armyWalkToInfo[_objectIndex] = nil
    end

    -- 通知增援模块
    local rid = mapCityInfos[_objectIndex].rid
    MSM.CityReinforceMgr[rid].post.backReinforceNoArrival( rid, _pos )
    -- 更新城市被集结的坐标信息
    RallyLogic:checkRoleRallyedOnMoveCity( rid, _pos )
end

---@see 更新城市状态
function response.updateCityStatus( _objectIndex, _status, _statusOp )
    if mapCityInfos[_objectIndex] then
        local oldStatus = mapCityInfos[_objectIndex].status
        if not _statusOp then
            _statusOp = Enum.ArmyStatusOp.SET
        end
        if _statusOp == Enum.ArmyStatusOp.ADD then
            -- 添加状态
            _status = ArmyLogic:addArmyStatus( oldStatus, _status )
        elseif _statusOp == Enum.ArmyStatusOp.DEL then
            -- 删除状态
            _status = ArmyLogic:delArmyStatus( oldStatus, _status )
        end
        mapCityInfos[_objectIndex].status = _status

        local battleBuff
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING ) then
            mapCityInfos[_objectIndex].battleBuff = {}
            battleBuff = {}
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = _status, battleBuff = battleBuff } )
    end
end

---@see 更新城市头像
function accept.updateHeadId( _objectIndex, _headId )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].headId = _headId

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { headId = _headId } )
    end
end

---@see 更新城市头像框
function accept.updateHeadFrameID( _objectIndex, _headFrameID )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].headFrameID = _headFrameID

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { headFrameID = _headFrameID } )
    end
end

---@see 更新联盟全称
function accept.syncGuildFullName( _objectIndex, _guildFullName )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].guildFullName = _guildFullName

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildFullName = _guildFullName } )
    end
end

---@see 更新城市最大怒气
function accept.syncCityMaxSp( _objectIndex, _maxSp )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].maxSp = _maxSp

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { maxSp = _maxSp } )
    end
end

---@see 更新当前城内部队
function accept.updateCityArmyCountMax( _objectIndex, _armyCountMax )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].armyCountMax = _armyCountMax

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCountMax = _armyCountMax } )
    end
end

---@see 更新城市部队数量
function accept.updateCityCountAndSp( _objectIndex, _armyCount, _sp )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].armyCount = _armyCount
        mapCityInfos[_objectIndex].sp = _sp
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 更新城市文明
function accept.syncCityCountry( _objectIndex, _country )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].country = _country

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { country = _country } )
    end
end

---@see 更新城市主副将
function accept.syncCityMainHero( _objectIndex, _mainHeroId )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].mainHeroId = _mainHeroId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { mainHeroId = _mainHeroId } )
    end
end

---@see 判断是否有同盟部队在攻击自己
function accept.checkSameGuildAttacker( _objectIndex )
    if mapCityInfos[_objectIndex] then
        if mapCityInfos[_objectIndex].guildId > 0 then
            -- 判断正在攻击的对象,退出战斗
            MSM.AttackAroundPosMgr[_objectIndex].req.notifyAttackerExitBattle( _objectIndex )

            -- 判断正在行军的对象
            if armyWalkToInfo[_objectIndex] then
                local moveGuildId
                for moveIndex in pairs(armyWalkToInfo[_objectIndex]) do
                    local armyInfo = MSM.SceneArmyMgr[moveIndex].req.getArmyInfo( moveIndex )
                    if armyInfo then
                        moveGuildId = RoleLogic:getRole( armyInfo.rid, Enum.Role.guildId )
                        if moveGuildId == mapCityInfos[_objectIndex].guildId then
                            -- 回城
                            MSM.MapMarchMgr[moveIndex].req.marchBackCity( armyInfo.rid, moveIndex )
                        end
                    end
                end
            end
        end
    end
end

---@see 判断是否被同联盟的集结
function accept.checkSameGuildRally( _objectIndex )
    if mapCityInfos[_objectIndex] then
        local guildId = mapCityInfos[_objectIndex].guildId
        if guildId > 0 then
            local rallyRids = SM.RallyTargetMgr.req.checkTargetIsRallyed( guildId, _objectIndex )
            if rallyRids and not table.empty(rallyRids) then
                local rallyGuildId
                for _, rallyRid in pairs(rallyRids) do
                    rallyGuildId = RoleLogic:getRole( rallyRid, Enum.Role.guildId )
                    if rallyGuildId == guildId then
                        -- 不能集结同联盟,解散
                        MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, rallyRid )
                    end
                end
            end
        end
    end
end

---@see 开启护盾.判断城市正在被攻击.和被攻击行军
function accept.onCityShieldBuff( _objectIndex )
    if mapCityInfos[_objectIndex] then
        -- 判断正在攻击的对象
        local name = RoleLogic:getRole( mapCityInfos[_objectIndex].rid, Enum.Role.name )
        MSM.AttackAroundPosMgr[_objectIndex].req.notifyAttackerExitBattle( _objectIndex, true, { name }, true )

        local guildAndRoleName = RoleLogic:getGuildNameAndRoleName( mapCityInfos[_objectIndex].rid )
        local emailArg = { guildAndRoleName }

        -- 判断正在行军的对象
        if armyWalkToInfo[_objectIndex] then
            for moveIndex in pairs(armyWalkToInfo[_objectIndex]) do
                local armyInfo = MSM.SceneArmyMgr[moveIndex].req.getArmyInfo( moveIndex )
                -- 回城
                MSM.MapMarchMgr[moveIndex].req.marchBackCity( armyInfo.rid, moveIndex )
                -- 发送邮件
                EmailLogic:sendEmail( armyInfo.rid, 110000, { subTitleContents = emailArg, emailContents = emailArg } )
            end
        end
    end
end

---@see 同步对象战斗buff
function accept.syncCityBattleBuff( _objectIndex, _battleBuff )
    if mapCityInfos[_objectIndex] then
        mapCityInfos[_objectIndex].battleBuff = _battleBuff
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.CITY )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end