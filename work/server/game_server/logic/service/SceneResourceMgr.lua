--[[
* @file : SceneResourceMgr.lua
* @type : snax multi service
* @author : linfeng
* @created : Thu May 03 2018 11:29:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图资源管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"
local ArmyLogic = require "ArmyLogic"
local HospitalLogic = require "HospitalLogic"
local BattleCreate = require "BattleCreate"
local ArmyDef = require "ArmyDef"
local EarlyWarningLogic = require "EarlyWarningLogic"
local HeroLogic = require "HeroLogic"

---@see 地图资源点信息
---@class defaultMapResourceInfoClass
local defaultMapResourceInfo = {
    pos                         =                   {},             -- 资源坐标
    resourceId                  =                   {},             -- 资源信息
    resourceType                =                   0,              -- 资源类型
    collectRid                  =                   0,              -- 采集角色rid
    collectSpeed                =                   0,              -- 采集速度
    armyIndex                   =                   0,              -- 军队索引
    resourceAmount              =                   0,              -- 资源剩余
    resourcePointId             =                   0,              -- 村庄山洞ID(s_MapFixPoint表ID)
    collectTime                 =                   0,              -- 开始采集时间
    cityName                    =                   "",             -- 采集角色名称
    collectSpeeds               =                   {},             -- 军队在当前资源点的采集速度信息
    guildAbbName                =                   "",             -- 采集角色所在联盟简称
    status                      =                   0,              -- 资源状态(用于战斗)
    armyCountMax                =                   0,              -- 资源内部队数量上限
    armyCount                   =                   0,              -- 资源当前部队数量
    marchObjectIndexs           =                   {},             -- 向该目标行军的部队
    maxSp                       =                   0,              -- 资源点最大怒气
    resourceGuildAbbName        =                   0,              -- 资源点所属联盟简称
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    cityLevel                   =                   0,              -- 采集角色市政厅等级
    armyRadius                  =                   0,              -- 半径
    guildId                     =                   0,              -- 联盟ID
    mainHeroId                  =                   0,              -- 主将ID
    deputyHeroId                =                   0,              -- 副将ID
    mainHeroSkills              =                   {},             -- 主将技能
    deputyHeroSkills            =                   {},             -- 副将技能
    sp                          =                   0,              -- 当前怒气
    battleBuff                  =                   {},             -- 战斗buff
}

---@type table<int, defaultMapResourceInfoClass>
local mapResourceInfos = {}
---@type table<int, int>
local mapResourceAttackers = {}
---@type table<int, table>
local armyWalkToInfo = {}

---@see 增加地图资源对象
function response.addResourceObject( _objectIndex, _resourceInfo, _pos, _resourceType )
    local cityName = _resourceInfo.objectName or ""
    local guildAbbName, cityLevel, guildId
    if _resourceInfo.collectRid and _resourceInfo.collectRid > 0 then
        local roleInfo = RoleLogic:getRole( _resourceInfo.collectRid, { Enum.Role.name, Enum.Role.guildId, Enum.Role.level } )
        cityName = roleInfo.name
        guildId = roleInfo.guildId
        if roleInfo.guildId and roleInfo.guildId > 0 then
            guildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
        end
        cityLevel = roleInfo.level
    end

    local mapResourceInfo = const( table.copy( defaultMapResourceInfo, true ) )
    mapResourceInfo.pos = _pos
    mapResourceInfo.resourceId = _resourceInfo.resourceId
    mapResourceInfo.resourceType = _resourceType
    mapResourceInfo.collectRid = _resourceInfo.collectRid or 0
    mapResourceInfo.collectSpeed = _resourceInfo.collectSpeed or 0
    mapResourceInfo.armyIndex = _resourceInfo.armyIndex or 0
    mapResourceInfo.resourceAmount = _resourceInfo.resourceAmount
    mapResourceInfo.collectTime = _resourceInfo.collectTime or 0
    mapResourceInfo.cityName = cityName
    mapResourceInfo.resourcePointId = _resourceInfo.resourcePointId
    mapResourceInfo.collectSpeeds = _resourceInfo.collectSpeeds or {}
    mapResourceInfo.guildAbbName = guildAbbName or _resourceInfo.guildAbbName or ""
    mapResourceInfo.status = Enum.ArmyStatus.ARMY_STANBY
    mapResourceInfo.armyCountMax = 0
    mapResourceInfo.armyCount = 0
    mapResourceInfo.resourceGuildAbbName = _resourceInfo.resourceGuildAbbName or ""
    mapResourceInfo.cityLevel = cityLevel or 0
    mapResourceInfo.armyRadius = CFG.s_Config:Get("resourceGatherRadius") * 100
    mapResourceInfo.guildId = guildId or 0

    if mapResourceInfo.armyIndex > 0 then
        local armyInfo = ArmyLogic:getArmy( _resourceInfo.collectRid, mapResourceInfo.armyIndex )
        local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( _resourceInfo.collectRid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
        mapResourceInfo.mainHeroId = armyInfo.mainHeroId or 0
        mapResourceInfo.deputyHeroId = armyInfo.deputyHeroId or 0
        mapResourceInfo.mainHeroSkills = mainHeroSkills or {}
        mapResourceInfo.deputyHeroSkills = deputyHeroSkills or {}
        mapResourceInfo.maxSp = ArmyLogic:cacleArmyMaxSp( skills )
    end

    mapResourceInfos[_objectIndex] = mapResourceInfo
end

---@see 删除地图资源对象
function accept.deleteResourceObject( _objectIndex )
    if mapResourceInfos[_objectIndex] and armyWalkToInfo[_objectIndex] then
        local mapArmyInfo, armyStatus
        -- 向该目标行军的部队驻扎原地
        for armyObjectIndex in pairs( armyWalkToInfo[_objectIndex] ) do
            mapArmyInfo = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyInfo( armyObjectIndex )
            if mapArmyInfo then
                armyStatus = ArmyLogic:getArmy( mapArmyInfo.rid, mapArmyInfo.armyIndex, Enum.Army.status )
                if armyStatus and ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.COLLECT_MARCH ) then
                    MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, nil, nil, nil, Enum.MapMarchTargetType.STATION )
                end
            end
        end
    end

    mapResourceInfos[_objectIndex] = nil
    mapResourceAttackers[_objectIndex] = nil

    MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
end

---@see 更新地图资源信息
function accept.updateResourceInfo( _objectIndex, _updateResourceInfo, _isDefeat )
    if mapResourceInfos[_objectIndex] then
        local oldCollectRid = mapResourceInfos[_objectIndex].collectRid or 0
        table.mergeEx( mapResourceInfos[_objectIndex], _updateResourceInfo )
        -- 重新计算armyCountMax和armyCount
        local resourceInfo = mapResourceInfos[_objectIndex]
        if oldCollectRid <= 0 and resourceInfo.collectRid and resourceInfo.collectRid > 0 then
            -- 部队进入资源点
            local armyInfo = ArmyLogic:getArmy( resourceInfo.collectRid, resourceInfo.armyIndex )
            resourceInfo.armyCountMax = ArmyLogic:getArmySoldierCount( armyInfo.soldiers )
            resourceInfo.armyCount = resourceInfo.armyCountMax
            _updateResourceInfo.armyCountMax = resourceInfo.armyCountMax
            _updateResourceInfo.armyCount = resourceInfo.armyCount

            local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( resourceInfo.collectRid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
            mapResourceInfos[_objectIndex].mainHeroId = armyInfo.mainHeroId or 0
            mapResourceInfos[_objectIndex].deputyHeroId = armyInfo.deputyHeroId or 0
            mapResourceInfos[_objectIndex].mainHeroSkills = mainHeroSkills or {}
            mapResourceInfos[_objectIndex].deputyHeroSkills = deputyHeroSkills or {}
            mapResourceInfos[_objectIndex].maxSp = ArmyLogic:cacleArmyMaxSp( skills )
            _updateResourceInfo.mainHeroId = armyInfo.mainHeroId or 0
            _updateResourceInfo.mainHeroSkills = mainHeroSkills or {}
            _updateResourceInfo.deputyHeroSkills = deputyHeroSkills or {}
            _updateResourceInfo.maxSp = mapResourceInfos[_objectIndex].maxSp

            -- 追加预警
            if armyWalkToInfo[_objectIndex] and not table.empty(armyWalkToInfo[_objectIndex]) then
                EarlyWarningLogic:enterBuildAddWarning( resourceInfo.collectRid, _objectIndex, armyWalkToInfo[_objectIndex] )
            end
        elseif oldCollectRid > 0 and ( not resourceInfo.collectRid or resourceInfo.collectRid <= 0 ) then
            -- 部队离开资源点
            resourceInfo.armyCountMax = 0
            resourceInfo.armyCount = 0
            _updateResourceInfo.armyCountMax = 0
            _updateResourceInfo.armyCount = 0
            mapResourceInfos[_objectIndex].mainHeroId = 0
            mapResourceInfos[_objectIndex].deputyHeroId = 0
            mapResourceInfos[_objectIndex].mainHeroSkills = {}
            mapResourceInfos[_objectIndex].deputyHeroSkills = {}
            mapResourceInfos[_objectIndex].maxSp = 0
            _updateResourceInfo.mainHeroId = 0
            _updateResourceInfo.mainHeroSkills = {}
            _updateResourceInfo.deputyHeroSkills = {}
            _updateResourceInfo.maxSp = 0
            -- 检查是否有斥候侦查信息
            local armyObjectInfo
            for armyObjectIndex in pairs( armyWalkToInfo[_objectIndex] or {} ) do
                armyObjectInfo = MSM.MapObjectTypeMgr[armyObjectIndex].req.getObjectInfo( armyObjectIndex )
                if armyObjectInfo and armyObjectInfo.objectType == Enum.RoleType.SCOUTS then
                    -- 删除行军线
                    armyWalkToInfo[_objectIndex][armyObjectIndex] = nil
                    mapResourceInfos[_objectIndex].armyMarchInfo[armyObjectIndex] = nil
                    if table.empty(armyWalkToInfo[_objectIndex]) then
                        armyWalkToInfo[_objectIndex] = nil
                    end
                    -- 通过AOI通知
                    local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
                    sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [armyObjectIndex] = { objectIndex = armyObjectIndex, isDelete = true } } } )
                    if _isDefeat then
                        -- 部队溃败, 删除斥候的侦查目标
                        MSM.SceneScoutsMgr[armyObjectIndex].req.deleteScoutFollowTarget( armyObjectIndex )
                    end
                    -- 侦查斥候, 删除预警
                    EarlyWarningLogic:deleteScoutEarlyWarning( armyObjectIndex, _objectIndex, nil, { oldCollectRid } )
                end
            end
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, _updateResourceInfo )
    end
end

---@see 获取地图资源信息
function response.getResourceInfo( _objectIndex )
    if mapResourceInfos[_objectIndex] then
        return mapResourceInfos[_objectIndex]
    end
end

---@see 获取地图资源状态
function response.getResourceStatus( _objectIndex )
    if mapResourceInfos[_objectIndex] then
        return mapResourceInfos[_objectIndex].status
    end
end

---@see 获取地图资源坐标
function response.getResourcePos( _objectIndex )
    if mapResourceInfos[_objectIndex] then
        return mapResourceInfos[_objectIndex].pos
    end
end

---@see 更新资源点战斗状态
function response.updateResourceStatus( _objectIndex, _status, _statusOp )
    if mapResourceInfos[_objectIndex] then
        local oldStatus = mapResourceInfos[_objectIndex].status
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
        mapResourceInfos[_objectIndex].status = _status

        local battleBuff
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING ) then
            mapResourceInfos[_objectIndex].battleBuff = {}
            battleBuff = {}
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = _status, battleBuff = battleBuff } )
    end
end

---@see 更新资源点部队数量
function accept.updateResourceCountAndSp( _objectIndex, _armyCount, _sp )
    if mapResourceInfos[_objectIndex] then
        mapResourceInfos[_objectIndex].armyCount = _armyCount
        mapResourceInfos[_objectIndex].sp = _sp
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 更新资源点内部队伤亡信息
function response.updateResourceSoldier( _objectIndex, _hurt, _die )
    if mapResourceInfos[_objectIndex] then
        local resourceInfo = mapResourceInfos[_objectIndex]
        if resourceInfo.collectRid and resourceInfo.collectRid > 0 then
            local armyInfo = ArmyLogic:getArmy( resourceInfo.collectRid, resourceInfo.armyIndex )

            -- 扣除重伤士兵
            for soldierId, soldierInfo in pairs(_hurt) do
                if armyInfo.soldiers[soldierId] then
                    if armyInfo.soldiers[soldierId].num - soldierInfo.num < 0 then
                        soldierInfo.num = armyInfo.soldiers[soldierId].num
                    end
                    armyInfo.soldiers[soldierId].num = armyInfo.soldiers[soldierId].num - soldierInfo.num
                    if armyInfo.soldiers[soldierId].num < 0 then
                        armyInfo.soldiers[soldierId].num = 0
                    end
                end
            end

            -- 扣除死亡士兵
            for soldierId, soldierInfo in pairs(_die) do
                if armyInfo.soldiers[soldierId] then
                    if armyInfo.soldiers[soldierId].num - soldierInfo.num < 0 then
                        soldierInfo.num = armyInfo.soldiers[soldierId].num
                    end
                    armyInfo.soldiers[soldierId].num = armyInfo.soldiers[soldierId].num - soldierInfo.num
                    if armyInfo.soldiers[soldierId].num < 0 then
                        armyInfo.soldiers[soldierId].num = 0
                    end
                end
            end

            -- 重新set
            ArmyLogic:setArmy( resourceInfo.collectRid, resourceInfo.armyIndex, armyInfo )
            ArmyLogic:syncArmy( resourceInfo.collectRid, resourceInfo.armyIndex, armyInfo, true )

            -- 重伤的回医院
            local soldierDieInfo = HospitalLogic:addToHospital( resourceInfo.collectRid, _hurt )

            local hospitalDieInfo = {}
            hospitalDieInfo[resourceInfo.collectRid] = {}
            hospitalDieInfo[resourceInfo.collectRid][ resourceInfo.armyIndex] = soldierDieInfo.dead or {}
            -- 计算角色当前战力
            RoleLogic:cacleSyncHistoryPower( resourceInfo.collectRid )
            return hospitalDieInfo
        end
    end
end

---@see 更新资源点内的轻伤信息
function accept.syncSoldierMinor( _objectIndex, _minors )
    if mapResourceInfos[_objectIndex] then
        local resourceInfo = mapResourceInfos[_objectIndex]
        if resourceInfo.collectRid and resourceInfo.collectRid > 0 then
            local armyInfo = ArmyLogic:getArmy( resourceInfo.collectRid, resourceInfo.armyIndex )
            for soldierId, minorNum in pairs(_minors) do
                if armyInfo.soldiers[soldierId] then
                    if armyInfo.soldiers[soldierId].num - minorNum < 0 then
                        minorNum = armyInfo.soldiers[soldierId].num
                    end
                    armyInfo.soldiers[soldierId].num = armyInfo.soldiers[soldierId].num - minorNum
                    if armyInfo.soldiers[soldierId].num <= 0 then
                        armyInfo.soldiers[soldierId].num = 0
                    end
                    if not armyInfo.minorSoldiers[soldierId] then
                        armyInfo.minorSoldiers[soldierId] = {
                            id = soldierId, type = armyInfo.soldiers[soldierId].type, level = armyInfo.soldiers[soldierId].level, num = minorNum
                        }
                    else
                        armyInfo.minorSoldiers[soldierId].num = armyInfo.minorSoldiers[soldierId].num + minorNum
                    end
                end
            end

            -- 重新set
            ArmyLogic:setArmy( resourceInfo.collectRid, resourceInfo.armyIndex, armyInfo )
            ArmyLogic:syncArmy( resourceInfo.collectRid, resourceInfo.armyIndex, armyInfo, true )
        end
    end
end

---@see 部队进攻资源点
function accept.armyAttackResource( _objectIndex, _attackObjectIndex )
    if mapResourceInfos[_objectIndex] then
        if not mapResourceAttackers[_objectIndex] then
            mapResourceAttackers[_objectIndex] = {}
        end

        mapResourceAttackers[_objectIndex][_attackObjectIndex] = true
    end
end

---@see 部队取消攻击资源点
function accept.armyNoAttackResource( _objectIndex, _attackObjectIndex )
    if mapResourceInfos[_objectIndex] then
        if mapResourceAttackers[_objectIndex] then
            mapResourceAttackers[_objectIndex][_attackObjectIndex] = nil
            if table.empty( mapResourceAttackers[_objectIndex] ) then
                mapResourceAttackers[_objectIndex] = nil
            end
        end
    end
end

---@see 部队离开资源点
function accept.armyLeaveResource( _objectIndex, _armyObjectIndex, _isDefeat )
    -- 所有攻击的对象,改变目标,同时进行追击
    if mapResourceInfos[_objectIndex] then
        if ArmyLogic:checkArmyStatus( mapResourceInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            -- 变成非战斗
            mapResourceInfos[_objectIndex].status = Enum.ArmyStatus.ARMY_STANBY
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
            sceneObject.post.syncObjectInfo( _objectIndex, { status = Enum.ArmyStatus.ARMY_STANBY } )
            if not _isDefeat then
                -- 资源点离开战斗
                BattleCreate:exitBattle( _objectIndex, true )

                if mapResourceAttackers[_objectIndex] then
                    local resourceAttackers = table.copy( mapResourceAttackers[_objectIndex], true )
                    -- 攻击者退出战斗
                    for attackObjectIndex in pairs(resourceAttackers) do
                        BattleCreate:exitBattle( attackObjectIndex, true )
                    end
                    -- 攻击者改变目标
                    for attackObjectIndex in pairs(resourceAttackers) do
                        MSM.MapMarchMgr[attackObjectIndex].req.armyMove( attackObjectIndex, _armyObjectIndex, nil, nil, Enum.MapMarchTargetType.ATTACK )
                    end
                end
            end
        end

        for attackObjectIndex in pairs(mapResourceAttackers[_objectIndex] or {}) do
            -- 取消预警
            EarlyWarningLogic:deleteEarlyWarning( mapResourceInfos[_objectIndex].collectRid, attackObjectIndex, _objectIndex )
        end

        mapResourceAttackers[_objectIndex] = nil
    end
end

---@see 增加军队向资源点行军
function accept.addArmyWalkToResource( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapResourceInfos[_objectIndex] then
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
        mapResourceInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除军队向资源点行军
function accept.delArmyWalkToResource( _objectIndex, _armyObjectIndex )
    if mapResourceInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapResourceInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
        end
    end
end

---@see 更新向目标行军的目标联盟
function accept.updateArmyWalkObjectGuildId( _objectIndex, _armyObjectIndex, _guildId )
    if mapResourceInfos[_objectIndex] and mapResourceInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapResourceInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapResourceInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end

---@see 同步对象战斗buff
function accept.syncResourceBattleBuff( _objectIndex, _battleBuff )
    if mapResourceInfos[_objectIndex] then
        mapResourceInfos[_objectIndex].battleBuff = _battleBuff
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.RESOURCE )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end