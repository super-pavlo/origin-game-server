--[[
* @file : SceneGuildBuildMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon Apr 20 2020 13:16:35 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图联盟建筑管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local ArmyDef = require "ArmyDef"
local ArmyLogic = require "ArmyLogic"
local HeroLogic = require "HeroLogic"
local MapObjectLogic = require "MapObjectLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local BattleAttrLogic = require "BattleAttrLogic"
local RoleCacle = require "RoleCacle"
local BattleCreate = require "BattleCreate"
local EarlyWarningLogic = require "EarlyWarningLogic"

---@see 建筑驻防信息
---@class defaultGuildBuildGarrisonClass
local defaultGuildBuildGarrisonInfo = {
    rid                         =                   0,              -- 角色rid
    armyCountMax                =                   0,              -- 部队最大血量
    buildArmyIndex              =                   0,              -- 建筑部队索引
    joinTime                    =                   0,              -- 加入时间
}

---@see 地图联盟建筑信息
---@class defaultMapGuildBuildInfoClass
local defaultMapGuildBuildInfo = {
    guildFullName               =                   "",             -- 联盟名称
    guildAbbName                =                   "",             -- 联盟简称
    guildBuildStatus            =                   0,              -- 联盟建筑状态
    durable                     =                   0,              -- 耐久度
    durableLimit                =                   0,              -- 耐久度上限
    guildId                     =                   0,              -- 联盟ID
    buildProgress               =                   0,              -- 建造进度
    buildProgressTime           =                   0,              -- 建造进度时间
    buildFinishTime             =                   0,              -- 建造完成时间
    needBuildTime               =                   0,              -- 需要建造时间
    buildBurnSpeed              =                   0,              -- 建造燃烧速度
    lastOutFireTime             =                   0,              -- 上次灭火时间
    buildBurnTime               =                   0,              -- 建筑开始燃烧时间
    pos                         =                   {},             -- 坐标
    buildIndex                  =                   0,              -- 联盟建筑索引
    buildDurableRecoverTime     =                   0,              -- 建筑耐久恢复开始时间
    focusRids                   =                   {},             -- 关注的角色列表
    guildFlagSigns              =                   {},             -- 联盟旗帜标志
    objectType                  =                   0,              -- 地图对象类型
    resourceCenterDeleteTime    =                   0,              -- 联盟资源中心消失时间
    resourceAmount              =                   0,              -- 资源储量
    collectTime                 =                   0,              -- 开始采集时间
    collectSpeed                =                   0,              -- 采集速度，资源采集速度放大10000倍
    collectRoleNum              =                   0,              -- 采集角色数量
    status                      =                   0,              -- 建筑状态(用于战斗)
    maxSp                       =                   0,              -- 最大怒气
    sp                          =                   0,              -- 怒气
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    ---@type table<int, table<int, defaultGuildBuildGarrisonClass>>
    garrison                    =                   {},             -- 驻防信息
    garrisonLeader              =                   0,              -- 驻防队长
    garrisonArmyIndex           =                   0,              -- 驻防队伍
    mainHeroId                  =                   0,              -- 主将ID
    deputyHeroId                =                   0,              -- 副将ID
    skills                      =                   0,              -- 技能
    mainHeroSkills              =                   {},             -- 主将技能
    deputyHeroSkills            =                   {},             -- 副将技能
    armyCount                   =                   0,              -- 部队数量
    armyCountMax                =                   0,              -- 部队最大数量
    armyRadius                  =                   0,              -- 建筑半径
    staticId                    =                   0,              -- 静态对象ID
    armyCntLimit                =                   0,              -- 最大部队上限
    battleBuff                  =                   {},             -- 战斗buff
}

---@type table<int, defaultMapGuildBuildInfoClass>
local mapGuildBuildInfos = {}
---@type table<int, table>
local armyWalkToInfo = {}

---@see 增加联盟建筑对象
function response.addGuildBuildObject( _objectIndex, _buildInfo )
    local mapGuildBuildInfo = const( table.copy( defaultMapGuildBuildInfo, true ) )
    mapGuildBuildInfo.guildFullName = _buildInfo.guildFullName or ""
    mapGuildBuildInfo.guildAbbName = _buildInfo.guildAbbName or ""
    mapGuildBuildInfo.guildBuildStatus = _buildInfo.guildBuildStatus
    mapGuildBuildInfo.durable = _buildInfo.durable or 0
    mapGuildBuildInfo.durableLimit = _buildInfo.durableLimit or 0
    mapGuildBuildInfo.guildId = _buildInfo.guildId or 0
    mapGuildBuildInfo.buildProgress = _buildInfo.buildProgress or 0
    mapGuildBuildInfo.buildProgressTime = _buildInfo.buildProgressTime or 0
    mapGuildBuildInfo.buildFinishTime = _buildInfo.buildFinishTime or 0
    mapGuildBuildInfo.needBuildTime = _buildInfo.needBuildTime or 0
    mapGuildBuildInfo.buildBurnSpeed = _buildInfo.buildBurnSpeed or 0
    mapGuildBuildInfo.lastOutFireTime = _buildInfo.lastOutFireTime or 0
    mapGuildBuildInfo.buildIndex = _buildInfo.buildIndex or 0
    mapGuildBuildInfo.buildBurnTime = _buildInfo.buildBurnTime or 0
    mapGuildBuildInfo.pos = _buildInfo.pos
    mapGuildBuildInfo.buildDurableRecoverTime = _buildInfo.buildDurableRecoverTime or 0
    mapGuildBuildInfo.focusRids = {}
    mapGuildBuildInfo.guildFlagSigns = _buildInfo.guildFlagSigns or {}
    mapGuildBuildInfo.objectType = _buildInfo.objectType
    mapGuildBuildInfo.resourceCenterDeleteTime = _buildInfo.resourceCenterDeleteTime or 0
    mapGuildBuildInfo.resourceAmount = _buildInfo.resourceAmount or 0
    mapGuildBuildInfo.collectTime = _buildInfo.collectTime or 0
    mapGuildBuildInfo.collectSpeed = _buildInfo.collectSpeed or 0
    mapGuildBuildInfo.collectRoleNum = _buildInfo.collectRoleNum or 0
    local guildBuildType = GuildBuildLogic:objectTypeToBuildType( _buildInfo.objectType )
    mapGuildBuildInfo.armyRadius = CFG.s_AllianceBuildingType:Get( guildBuildType, "radius" ) * 100
    mapGuildBuildInfo.staticId = guildBuildType
    mapGuildBuildInfo.armyCntLimit = CFG.s_AllianceBuildingType:Get( guildBuildType, "armyCntLimit" )
    mapGuildBuildInfos[_objectIndex] = mapGuildBuildInfo

    MSM.GuildBuildIndexMgr[_buildInfo.guildId].req.addGuildBuildIndex( _buildInfo.guildId, _buildInfo.buildIndex, _objectIndex )
end

---@see 删除联盟建筑对象
function accept.deleteGuildBuildObject( _objectIndex )
    local buildInfo = mapGuildBuildInfos[_objectIndex]
    if buildInfo then
        if ArmyLogic:checkArmyStatus( mapGuildBuildInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            -- 部队退出战斗
            BattleCreate:exitBattle( _objectIndex, true )
        end

        MSM.GuildBuildIndexMgr[buildInfo.guildId].post.deleteGuildBuildIndex( buildInfo.guildId, buildInfo.buildIndex )
        mapGuildBuildInfos[_objectIndex] = nil
        MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
    end
end

---@see 更新地图联盟建筑信息
function accept.updateGuildBuildInfo( _objectIndex, _updateBuildInfo, _noUpdateObjectType )
    if mapGuildBuildInfos[_objectIndex] and ( not _noUpdateObjectType or not table.exist( _noUpdateObjectType, mapGuildBuildInfos[_objectIndex].objectType ) ) then
        table.mergeEx( mapGuildBuildInfos[_objectIndex], _updateBuildInfo )
        -- 通过AOI通知
        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
            or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end
        sceneObject.post.syncObjectInfo( _objectIndex, _updateBuildInfo )
    end
end

---@see 获取地图资源信息
function response.getGuildBuildInfo( _objectIndex )
    return mapGuildBuildInfos[_objectIndex]
end

---@see 获取联盟建筑坐标
function response.getGuildBuildPos( _objectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        return mapGuildBuildInfos[_objectIndex].pos
    end
end

---@see 获取联盟建筑状态
function response.getGuildBuildStatus( _objectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        return mapGuildBuildInfos[_objectIndex].status
    end
end

---@see 添加建筑关注角色ID
function accept.addFocusRid( _objectIndex, _rid )
    if mapGuildBuildInfos[_objectIndex] then
        mapGuildBuildInfos[_objectIndex].focusRids[_rid] = true

        local focusBuildObject = RoleLogic:getRole( _rid, Enum.Role.focusBuildObject ) or {}
        focusBuildObject[_objectIndex] = Enum.RoleBuildFocusType.GUILD_BUILD
        RoleLogic:setRole( _rid, { [Enum.Role.focusBuildObject] = focusBuildObject } )
    end
end

---@see 删除关注建筑的角色ID
function accept.deleteFocusRid( _objectIndex, _rid, _deleteRole )
    if mapGuildBuildInfos[_objectIndex] then
        local guildInfo = mapGuildBuildInfos[_objectIndex]
        guildInfo.focusRids[_rid] = nil

        if not _deleteRole then
            local focusBuildObject = RoleLogic:getRole( _rid, Enum.Role.focusBuildObject ) or {}
            focusBuildObject[_objectIndex] = nil
            RoleLogic:setRole( _rid, { [Enum.Role.focusBuildObject] = focusBuildObject } )
        end

        -- 通知角色删除建筑中的部队
        local indexs = {}
        local reinforces = GuildBuildLogic:getGuildBuild( guildInfo.guildId, guildInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
        for buildArmyIndex in pairs( reinforces ) do
            table.insert( indexs, buildArmyIndex )
        end
        if not table.empty( indexs ) then
            GuildBuildLogic:syncGuildBuildArmy( _objectIndex, nil, nil, indexs, { [_rid] = _rid } )
        end
    end
end

---@see 获取所有关注的角色ID
function response.getFocusRids( _objectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        return mapGuildBuildInfos[_objectIndex].focusRids
    end
end

---@see 增加军队向联盟建筑行军
function accept.addArmyWalkToGuildBuild( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapGuildBuildInfos[_objectIndex] then
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
        mapGuildBuildInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
            or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除军队向联盟建筑行军
function accept.delArmyWalkToGuildBuild( _objectIndex, _armyObjectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapGuildBuildInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
            -- 通过AOI通知
            local sceneObject
            if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
                or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
                sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
            else
                sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
            end
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
        end
    end
end

---@see 更新向目标行军的目标联盟
function accept.updateArmyWalkObjectGuildId( _objectIndex, _armyObjectIndex, _guildId )
    if mapGuildBuildInfos[_objectIndex] and mapGuildBuildInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapGuildBuildInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
            or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapGuildBuildInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end

---@see 增加联盟建筑驻防信息
function accept.addGarrisonArmy( _objectIndex, _rid, _armyIndex, _buildArmyIndex )
    if mapGuildBuildInfos[_objectIndex] then
        local garrison = mapGuildBuildInfos[_objectIndex].garrison
        local isSetLeader = table.empty(garrison)
        if garrison[_rid] and garrison[_rid][_armyIndex] then
            LOG_ERROR("addGarrisonArmy rid(%d) armyIndex(%d) had garrison this guild build", _rid, _armyIndex)
            return
        end
        ---@type defaultGuildBuildGarrisonClass
        local defaultGarrisonInfo = const( table.copy( defaultGuildBuildGarrisonInfo, true ) )
        local armyInfo = ArmyLogic:getArmy( _rid, _armyIndex )
        if not armyInfo then
            LOG_ERROR("addGarrisonArmy rid(%d) not found armyIndex(%d)", _rid, _armyIndex)
            return
        end
        defaultGarrisonInfo.rid = _rid
        defaultGarrisonInfo.armyCountMax = ArmyLogic:getArmySoldierCount( armyInfo.soldiers )
        defaultGarrisonInfo.buildArmyIndex = _buildArmyIndex or 0
        defaultGarrisonInfo.joinTime = os.time()

        if not garrison[_rid] then
            garrison[_rid] = {}
        end
        garrison[_rid][_armyIndex] = defaultGarrisonInfo

        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
            or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end

        if isSetLeader then
            -- 设置驻防队长
            mapGuildBuildInfos[_objectIndex].garrisonLeader = _rid
            -- 设置驻防队伍
            mapGuildBuildInfos[_objectIndex].garrisonArmyIndex = _armyIndex
            -- 计算技能和怒气
            local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( _rid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
            mapGuildBuildInfos[_objectIndex].skills = skills or {}
            mapGuildBuildInfos[_objectIndex].mainHeroSkills = mainHeroSkills or {}
            mapGuildBuildInfos[_objectIndex].deputyHeroSkills = deputyHeroSkills or {}
            mapGuildBuildInfos[_objectIndex].mainHeroId = armyInfo.mainHeroId or 0
            mapGuildBuildInfos[_objectIndex].deputyHeroId = armyInfo.deputyHeroId or 0
            local maxSp = ArmyLogic:cacleArmyMaxSp( skills )
            mapGuildBuildInfos[_objectIndex].maxSp = maxSp
            -- 通过AOI通知
            sceneObject.post.syncObjectInfo( _objectIndex, {
                                                                maxSp = maxSp,
                                                                mainHeroId = armyInfo.mainHeroId,
                                                                mainHeroSkills = mapGuildBuildInfos[_objectIndex].mainHeroSkills,
                                                                deputyHeroSkills = mapGuildBuildInfos[_objectIndex].deputyHeroSkills
                                                            }
                                            )
            -- 通知客户端驻防队长信息
            GuildBuildLogic:updateGuildBuildLeader( mapGuildBuildInfos[_objectIndex], _objectIndex, _rid, _armyIndex )
        end

        -- 重新计算血量
        local armyCountMax = 0
        local armyCount = 0
        for rid, subArmyInfo in pairs(garrison) do
            for armyIndex, garrisonInfo in pairs(subArmyInfo) do
                armyCountMax = armyCountMax + garrisonInfo.armyCountMax
                armyCount = armyCount + ArmyLogic:getArmySoldierCount( nil, rid, armyIndex )
            end
        end

        -- 同步血量
        mapGuildBuildInfos[_objectIndex].armyCountMax = armyCountMax
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCountMax = armyCountMax, armyCount = armyCount } )

        -- 如果部队正在战斗,通知战斗服务器士兵加入
        if ArmyLogic:checkArmyStatus( mapGuildBuildInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            BattleAttrLogic:notifyBattleAddSoldier( _objectIndex, armyInfo.soldiers, _rid, _armyIndex, armyInfo.mainHeroId, armyInfo.mainHeroLevel, armyInfo.deputyHeroId, armyInfo.deputyHeroLevel )
            -- 增援加入战斗
            BattleAttrLogic:reinforceJoinBattle( _objectIndex, _rid, _armyIndex )
        end

        -- 追加预警(如果之前没有队伍在建筑内)
        if table.size(garrison[_rid]) <= 1 then
            if armyWalkToInfo[_objectIndex] and not table.empty(armyWalkToInfo[_objectIndex]) then
                EarlyWarningLogic:enterBuildAddWarning( _rid, _objectIndex, armyWalkToInfo[_objectIndex] )
            end
        end
    end
end

---@see 移除联盟建筑驻防信息
function accept.delGarrisonArmy( _objectIndex, _rid, _armyIndex )
    if mapGuildBuildInfos[_objectIndex] then
        local garrison = mapGuildBuildInfos[_objectIndex].garrison
        if garrison[_rid] and garrison[_rid][_armyIndex] then
            local sceneObject
            if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
                or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
                sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
            else
                sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
            end

            -- 重新计算最大血量
            local armyCountMax = 0
            for _, subArmyInfo in pairs(garrison) do
                for _, garrisonInfo in pairs(subArmyInfo) do
                    armyCountMax = armyCountMax + garrisonInfo.armyCountMax
                end
            end
            -- 同步最大血量
            mapGuildBuildInfos[_objectIndex].armyCountMax = armyCountMax
            sceneObject.post.syncObjectInfo( _objectIndex, { armyCountMax = armyCountMax } )

            garrison[_rid][_armyIndex] = nil
            -- 重新选择队长
            if mapGuildBuildInfos[_objectIndex].garrisonLeader == _rid and mapGuildBuildInfos[_objectIndex].garrisonArmyIndex == _armyIndex then
                local leaderRid, garrisonArmyIndex = GuildBuildLogic:selectGarrisonLeader( garrison )
                if leaderRid then
                    GuildBuildLogic:syncInfoOnChangeLeader( mapGuildBuildInfos[_objectIndex], _objectIndex, leaderRid, garrisonArmyIndex, true )
                else
                    GuildBuildLogic:syncGuildBuildArmy( _objectIndex, nil, 0 )
                    mapGuildBuildInfos[_objectIndex].garrisonLeader = 0
                    mapGuildBuildInfos[_objectIndex].garrisonArmyIndex = 0
                end
            end

            -- 如果部队正在战斗,通知战斗服务器士兵减少
            if ArmyLogic:checkArmyStatus( mapGuildBuildInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
                local soldiers = ArmyLogic:getArmy( _rid, _armyIndex, Enum.Army.soldiers )
                if table.size(garrison[_rid]) <= 0 then
                    BattleAttrLogic:notifyBattleSubSoldier( _objectIndex, soldiers, _rid, _rid, _armyIndex )
                else
                    -- 不发战报
                    BattleAttrLogic:notifyBattleSubSoldier( _objectIndex, soldiers, nil, _rid, _armyIndex )
                end
                -- 增援离开战斗
                if ArmyLogic:getArmySoldierCount( soldiers ) > 0 then
                    BattleAttrLogic:reinforceLeaveBattle( _objectIndex, _rid, _armyIndex )
                end
            end

            if table.empty(garrison[_rid]) then
                garrison[_rid] = nil
            end

            -- 取消预警(如果角色部队都移出了)
            if not garrison[_rid] then
                EarlyWarningLogic:leaveBuildDelWarning( _rid, _objectIndex, armyWalkToInfo[_objectIndex] )
            end
        end
    end
end

---@see 获取联盟建筑中的驻守部队.用于战斗
function response.getGarrisonArmy( _objectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        local garrisonLeader = mapGuildBuildInfos[_objectIndex].garrisonLeader
        local garrisonArmyIndex = mapGuildBuildInfos[_objectIndex].garrisonArmyIndex
        if not garrisonLeader or garrisonLeader <= 0 then
            return nil, { guildId = mapGuildBuildInfos[_objectIndex].guildId, buildIndex = mapGuildBuildInfos[_objectIndex].buildIndex }
        end
        local garrison = mapGuildBuildInfos[_objectIndex].garrison
        local soldiers = {}
        local rallyHeros = {}
        local rallySoldiers = {}
        local garrisonArmyInfo
        local reserveArmy
        for garrisonRid, armyInfo in pairs(garrison) do
            for garrisonArmy in pairs(armyInfo) do
                garrisonArmyInfo = ArmyLogic:getArmy( garrisonRid, garrisonArmy, { Enum.Army.mainHeroId, Enum.Army.deputyHeroId, Enum.Army.mainHeroLevel, Enum.Army.deputyHeroLevel, Enum.Army.soldiers } )
                if garrisonArmyInfo and not table.empty( garrisonArmyInfo ) then
                    if not reserveArmy then
                        reserveArmy = { rid = garrisonRid, armyIndex = garrisonArmy, armyInfo = garrisonArmyInfo }
                    end
                    if not rallySoldiers[garrisonRid] then
                        rallySoldiers[garrisonRid] = {}
                    end
                    rallySoldiers[garrisonRid][garrisonArmy] = garrisonArmyInfo.soldiers
                    for soldierId, soldierInfo in pairs(garrisonArmyInfo.soldiers or {}) do
                        if not soldiers[soldierId] then
                            soldiers[soldierId] = table.copy( soldierInfo, true )
                        else
                            soldiers[soldierId].num = soldiers[soldierId].num + soldierInfo.num
                        end
                    end

                    -- 获取将领信息
                    if not rallyHeros[garrisonRid] then
                        rallyHeros[garrisonRid] = {}
                    end
                    rallyHeros[garrisonRid][garrisonArmy] = {
                        mainHeroId = garrisonArmyInfo.mainHeroId,
                        deputyHeroId = garrisonArmyInfo.deputyHeroId,
                        mainHeroLevel = garrisonArmyInfo.mainHeroLevel,
                        deputyHeroLevel = garrisonArmyInfo.deputyHeroLevel,
                        joinTime = garrisonArmyInfo.joinTime
                    }
                end
            end
        end

        local leaderArmyInfo = ArmyLogic:getArmy( garrisonLeader, garrisonArmyIndex )
        if not leaderArmyInfo or table.empty( leaderArmyInfo ) then
            -- 队长被解散，检查是否存在备选队长
            LOG_ERROR("guildId(%d) buildIndex(%d) garrisonLeader(%s) garrisonArmyIndex(%s) garrison(%s)",
                mapGuildBuildInfos[_objectIndex].guildId, mapGuildBuildInfos[_objectIndex].buildIndex,
                tostring(garrisonLeader), tostring(garrisonArmyIndex), tostring(garrison))
            local sceneObject
            if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
                or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
                sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
            else
                sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
            end
            if reserveArmy then
                -- 有备选队长, 备选队长升为队长
                garrisonLeader = reserveArmy.rid
                garrisonArmyIndex = reserveArmy.armyIndex
                leaderArmyInfo = reserveArmy.armyInfo
                mapGuildBuildInfos[_objectIndex].garrisonLeader = garrisonLeader
                -- 设置驻防队伍
                mapGuildBuildInfos[_objectIndex].garrisonArmyIndex = garrisonArmyIndex
                -- 计算技能和怒气
                local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( garrisonLeader, leaderArmyInfo.mainHeroId, leaderArmyInfo.deputyHeroId )
                mapGuildBuildInfos[_objectIndex].skills = skills or {}
                mapGuildBuildInfos[_objectIndex].mainHeroSkills = mainHeroSkills or {}
                mapGuildBuildInfos[_objectIndex].deputyHeroSkills = deputyHeroSkills or {}
                mapGuildBuildInfos[_objectIndex].mainHeroId = leaderArmyInfo.mainHeroId or 0
                mapGuildBuildInfos[_objectIndex].deputyHeroId = leaderArmyInfo.deputyHeroId or 0
                local maxSp = ArmyLogic:cacleArmyMaxSp( skills )
                mapGuildBuildInfos[_objectIndex].maxSp = maxSp
                -- 通过AOI通知
                sceneObject.post.syncObjectInfo( _objectIndex, {
                                                                    maxSp = maxSp,
                                                                    mainHeroId = leaderArmyInfo.mainHeroId,
                                                                    mainHeroSkills = mapGuildBuildInfos[_objectIndex].mainHeroSkills,
                                                                    deputyHeroSkills = mapGuildBuildInfos[_objectIndex].deputyHeroSkills
                                                                }
                                                )
                -- 通知客户端驻防队长信息
                GuildBuildLogic:updateGuildBuildLeader( mapGuildBuildInfos[_objectIndex], _objectIndex, garrisonLeader, garrisonArmyIndex )
            else
                -- 无备选队长，即驻防中无正常部队
                mapGuildBuildInfos[_objectIndex].garrisonLeader = 0
                mapGuildBuildInfos[_objectIndex].garrisonArmyIndex = 0
                mapGuildBuildInfos[_objectIndex].garrison = {}
                mapGuildBuildInfos[_objectIndex].skills = {}
                mapGuildBuildInfos[_objectIndex].mainHeroSkills = {}
                mapGuildBuildInfos[_objectIndex].deputyHeroSkills = {}
                mapGuildBuildInfos[_objectIndex].mainHeroId = 0
                mapGuildBuildInfos[_objectIndex].deputyHeroId = 0
                -- 通知客户端无队长
                GuildBuildLogic:syncGuildBuildArmy( _objectIndex, nil, 0 )

                return nil, { guildId = mapGuildBuildInfos[_objectIndex].guildId, buildIndex = mapGuildBuildInfos[_objectIndex].buildIndex }
            end
        end

        return {
                    garrisonLeader = garrisonLeader,
                    soldiers = soldiers,
                    rallyHeros = rallyHeros,
                    mainHeroId = leaderArmyInfo.mainHeroId,
                    mainHeroLevel = leaderArmyInfo.mainHeroLevel,
                    deputyHeroId = leaderArmyInfo.deputyHeroId,
                    deputyHeroLevel = leaderArmyInfo.deputyHeroLevel,
                    objectAttr = RoleCacle:getRoleBattleAttr( garrisonLeader ),
                    skills = mapGuildBuildInfos[_objectIndex].skills,
                    maxSp = mapGuildBuildInfos[_objectIndex].maxSp,
                    rallySoldiers = rallySoldiers,
                    staticId = mapGuildBuildInfos[_objectIndex].staticId,
                    rallyLeader = garrisonLeader,
                    talentAttr = HeroLogic:getHeroTalentAttr( garrisonLeader, leaderArmyInfo.mainHeroId ).battleAttr,
                    equipAttr = HeroLogic:getHeroEquipAttr( garrisonLeader, leaderArmyInfo.mainHeroId ).battleAttr,
                }
    end
end

---@see 更新联盟建筑状态
function response.updateGuildBuildStatus( _objectIndex, _status, _statusOp )
    if mapGuildBuildInfos[_objectIndex] then
        local oldStatus = mapGuildBuildInfos[_objectIndex].status
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

        mapGuildBuildInfos[_objectIndex].status = _status

        local battleBuff
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING ) then
            mapGuildBuildInfos[_objectIndex].battleBuff = {}
            battleBuff = {}
        end
        -- 通过AOI通知
        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
        or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end

        sceneObject.post.syncObjectInfo( _objectIndex, { status = _status, battleBuff = battleBuff } )
        -- 联盟建筑战斗状态处理
        local battleStatus = Enum.ArmyStatus.BATTLEING
        local guildId = mapGuildBuildInfos[_objectIndex].guildId
        local buildIndex = mapGuildBuildInfos[_objectIndex].buildIndex
        if not ArmyLogic:checkArmyStatus( oldStatus, battleStatus ) and ArmyLogic:checkArmyStatus( _status, battleStatus ) then
            -- 联盟建筑增加战斗状态
            MSM.GuildIndexMgr[guildId].post.addBuildIndex( guildId, buildIndex )
        elseif ArmyLogic:checkArmyStatus( oldStatus, battleStatus ) and not ArmyLogic:checkArmyStatus( _status, battleStatus ) then
            -- 联盟建筑删除战斗状态
            if mapGuildBuildInfos[_objectIndex].guildBuildStatus == Enum.GuildBuildStatus.NORMAL
                and mapGuildBuildInfos[_objectIndex].objectType == Enum.RoleType.GUILD_FLAG then
                -- 通知联盟成员删除该旗帜
                GuildBuildLogic:syncMemberDeleteBuild( guildId, buildIndex )
            else
                MSM.GuildIndexMgr[guildId].post.addBuildIndex( guildId, buildIndex )
            end
        end
    end
end

---@see 驻守失败.部队全部回城
function accept.garrisonDefeat( _objectIndex, _attackerRid )
    if mapGuildBuildInfos[_objectIndex] then
        for garrisonRid in pairs(mapGuildBuildInfos[_objectIndex].garrison) do
            for attackObjectIndex in pairs(armyWalkToInfo) do
                -- 取消预警
                EarlyWarningLogic:deleteEarlyWarning( garrisonRid, attackObjectIndex, _objectIndex )
            end
        end
        mapGuildBuildInfos[_objectIndex].garrison = {}
        mapGuildBuildInfos[_objectIndex].garrisonArmyIndex = 0
        mapGuildBuildInfos[_objectIndex].garrisonLeader = 0
        mapGuildBuildInfos[_objectIndex].mainHeroId = 0
        mapGuildBuildInfos[_objectIndex].deputyHeroId = 0
        mapGuildBuildInfos[_objectIndex].skills = {}
        mapGuildBuildInfos[_objectIndex].mainHeroSkills = {}
        mapGuildBuildInfos[_objectIndex].deputyHeroSkills = {}
        mapGuildBuildInfos[_objectIndex].armyCountMax = 0
        mapGuildBuildInfos[_objectIndex].maxSp = 0

        -- 通过AOI通知
        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
            or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end
        sceneObject.post.syncObjectInfo( _objectIndex, { maxSp = 0, mainHeroId = 0, armyCountMax = 0 } )

        -- 联盟建筑,燃烧处理
        local guildId = mapGuildBuildInfos[_objectIndex].guildId
        local buildIndex = mapGuildBuildInfos[_objectIndex].buildIndex
        MSM.GuildMgr[guildId].post.burnGuildBuild( guildId, buildIndex, _attackerRid )
    end
end

---@see 同步联盟建筑血量和怒气
function accept.updateGuildBuildCountAndSp( _objectIndex, _armyCount, _sp )
    if mapGuildBuildInfos[_objectIndex] then
        mapGuildBuildInfos[_objectIndex].armyCount = _armyCount
        mapGuildBuildInfos[_objectIndex].sp = _sp
        -- 通过AOI通知
        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
            or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 获取建筑内的成员rids
function response.getMemberRidsInBuild( _objectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        return table.indexs( mapGuildBuildInfos[_objectIndex].garrison )
    end
end

---@see 目标退出联盟.部队从建筑撤防
function accept.onExitGuildDisarm( _objectIndex, _rid, _armyIndex )
    if mapGuildBuildInfos[_objectIndex] then
        local garrison = mapGuildBuildInfos[_objectIndex].garrison
        if garrison[_rid][_armyIndex] then
            -- 如果目标在战斗,通知战斗服务器士兵减少
            if ArmyLogic:checkArmyStatus( mapGuildBuildInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
                local soldiers = ArmyLogic:getArmy( _rid, _armyIndex, Enum.Army.soldiers )
                if soldiers then
                    BattleAttrLogic:notifyBattleSubSoldier( _objectIndex, soldiers, _rid, _rid, _armyIndex )
                end
            end

            garrison[_rid][_armyIndex] = nil
            if table.empty( garrison[_rid] ) then
                garrison[_rid] = nil
            end
            -- 如果是队长,更换队长
            if not garrison[_rid] and _rid == mapGuildBuildInfos[_objectIndex].garrisonLeader then
                local leaderRid, garrisonArmyIndex = GuildBuildLogic:selectGarrisonLeader( garrison )
                if leaderRid and leaderRid ~= mapGuildBuildInfos[_objectIndex].garrisonLeader then
                    GuildBuildLogic:syncInfoOnChangeLeader( mapGuildBuildInfos[_objectIndex], _objectIndex, leaderRid, garrisonArmyIndex, true )
                else
                    GuildBuildLogic:syncGuildBuildArmy( _objectIndex, nil, 0 )
                    mapGuildBuildInfos[_objectIndex].garrisonLeader = 0
                    mapGuildBuildInfos[_objectIndex].garrisonArmyIndex = 0
                end
            end
            for attackObjectIndex in pairs(armyWalkToInfo) do
                -- 取消预警
                EarlyWarningLogic:deleteEarlyWarning( _rid, attackObjectIndex, _objectIndex )
            end
        end
    end
end

---@see 角色强制迁城.从建筑撤防
function accept.disbanArmyOnForceMoveCity( _objectIndex, _rid )
    if mapGuildBuildInfos[_objectIndex] then
        local garrison = mapGuildBuildInfos[_objectIndex].garrison
        if garrison[_rid] then
            for armyIndex in pairs(garrison[_rid]) do
                -- 如果目标在战斗,通知战斗服务器士兵减少
                if ArmyLogic:checkArmyStatus( mapGuildBuildInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
                    local soldiers = ArmyLogic:getArmy( _rid, armyIndex, Enum.Army.soldiers )
                    if soldiers then
                        BattleAttrLogic:notifyBattleSubSoldier( _objectIndex, soldiers, _rid, _rid, armyIndex )
                    end
                end

                garrison[_rid][armyIndex] = nil
                if table.empty( garrison[_rid] ) then
                    garrison[_rid] = nil
                    break
                end
            end

            -- 如果是队长,更换队长
            if not garrison[_rid] and _rid == mapGuildBuildInfos[_objectIndex].garrisonLeader then
                local leaderRid, garrisonArmyIndex = GuildBuildLogic:selectGarrisonLeader( garrison )
                if leaderRid and leaderRid ~= mapGuildBuildInfos[_objectIndex].garrisonLeader then
                    GuildBuildLogic:syncInfoOnChangeLeader( mapGuildBuildInfos[_objectIndex], _objectIndex, leaderRid, garrisonArmyIndex, true )
                else
                    GuildBuildLogic:syncGuildBuildArmy( _objectIndex, nil, 0 )
                    mapGuildBuildInfos[_objectIndex].garrisonLeader = 0
                    mapGuildBuildInfos[_objectIndex].garrisonArmyIndex = 0
                end
            end

            for attackObjectIndex in pairs(armyWalkToInfo) do
                -- 取消预警
                EarlyWarningLogic:deleteEarlyWarning( _rid, attackObjectIndex, _objectIndex )
            end
        end
    end
end

---@see 获取建筑半径
function response.getBuildRadius( _objectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        return mapGuildBuildInfos[_objectIndex].armyRadius
    end
end

---@see 获取建筑驻守队长信息
function response.getGarrisonLeader( _objectIndex )
    if mapGuildBuildInfos[_objectIndex] then
        return mapGuildBuildInfos[_objectIndex].garrisonLeader, mapGuildBuildInfos[_objectIndex].garrisonArmyIndex
    end
end

---@see 同步对象战斗buff
function accept.syncGuildBuildBattleBuff( _objectIndex, _battleBuff )
    if mapGuildBuildInfos[_objectIndex] then
        mapGuildBuildInfos[_objectIndex].battleBuff = _battleBuff
        -- 通过AOI通知
        -- 通过AOI通知
        local sceneObject
        if MapObjectLogic:checkIsGuildFortressObject( mapGuildBuildInfos[_objectIndex].objectType )
            or MapObjectLogic:checkIsGuildResourceCenterObject( mapGuildBuildInfos[_objectIndex].objectType ) then
            sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        else
            sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        end
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end