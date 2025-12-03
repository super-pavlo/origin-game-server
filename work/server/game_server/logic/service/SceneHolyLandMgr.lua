--[[
* @file : SceneHolyLandMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu May 14 2020 09:14:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图圣地关卡管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local GuildLogic = require "GuildLogic"
local RoleLogic = require "RoleLogic"
local ArmyDef = require "ArmyDef"
local ArmyLogic = require "ArmyLogic"
local MonsterLogic = require "MonsterLogic"
local HeroLogic = require "HeroLogic"
local BattleAttrLogic = require "BattleAttrLogic"
local GuildBuildLogic = require "GuildBuildLogic"
local RoleCacle = require "RoleCacle"
local HolyLandLogic = require "HolyLandLogic"
local EarlyWarningLogic = require "EarlyWarningLogic"
local BattleCreate = require "BattleCreate"

---@see 圣地驻防信息
---@class defaultHolyLandGarrisonClass
local defaultHolyLandGarrisonInfo = {
    rid                         =                   0,              -- 角色rid
    armyCountMax                =                   0,              -- 部队最大血量
    buildArmyIndex              =                   0,              -- 建筑部队索引
    joinTime                    =                   0,              -- 加入时间
}

---@see 地图圣地信息
---@class defaultMapHolyLandInfoClass
local defaultMapHolyLandInfo = {
    pos                         =                   {},             -- 圣地坐标
    guildId                     =                   0,              -- 联盟ID
    guildAbbName                =                   "",             -- 联盟简称
    strongHoldId                =                   0,              -- s_StrongHoldData表ID
    holyLandStatus              =                   0,              -- 当前圣地、关卡状态
    holyLandFinishTime          =                   0,              -- 当前状态结束时间
    kingName                    =                   0,              -- 国王名称
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    armyRadius                  =                   0,              -- 半径
    armyCount                   =                   0,              -- 部队数量
    armyCountMax                =                   0,              -- 部队数量上限
    soldiers                    =                   0,              -- 部队士兵
    mainHeroId                  =                   0,              -- 主将ID
    deputyHeroId                =                   0,              -- 副将ID
    skills                      =                   {},             -- 技能
    battleBuff                  =                   {},             -- 战斗buff
    sp                          =                   0,              -- 怒气
    maxSp                       =                   0,              -- 最大怒气
    mainHeroSkills              =                   {},             -- 主将技能
    deputyHeroSkills            =                   {},             -- 副将技能
    holyLandType                =                   0,              -- 圣地类型
    status                      =                   0,              -- 圣地状态(用于战斗)
    focusRids                   =                   {},             -- 关注的角色列表
    ---@type table<int, table<int, defaultHolyLandGarrisonClass>>
    garrison                    =                   {},             -- 驻防信息
    garrisonLeader              =                   0,              -- 驻防队长
    garrisonArmyIndex           =                   0,              -- 驻防队伍
    staticId                    =                   0,              -- 静态对象ID
    guildFlagSigns              =                   {},             -- 联盟旗帜标识
    armyCntLimit                =                   0,              -- 最大部队数量
    holyLandBuildMonsterId      =                   0,              -- 圣地怪物ID
    objectAttr                  =                   {},             -- 怪物属性
}

---@type table<int, defaultMapHolyLandInfoClass>
local mapHolyLandInfos = {}
---@type table<int, table>
local armyWalkToInfo = {}

---@see 增加地图圣地对象
function response.addHolyLandObject( _objectIndex, _holyLandInfo, _pos )
    local guildAbbName, kingName, guildFlagSigns
    local holyLandType = CFG.s_StrongHoldData:Get( _holyLandInfo.strongHoldId, "type" )
    if _holyLandInfo.guildId and _holyLandInfo.guildId > 0 then
        local guildInfo = GuildLogic:getGuild( _holyLandInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.leaderRid, Enum.Guild.signs } )
        guildAbbName = guildInfo.abbreviationName
        guildFlagSigns = guildInfo.signs
        if holyLandType == Enum.HolyLandType.LOST_TEMPLE then
            -- 失落的神庙显示国王名称
            kingName = RoleLogic:getRole( guildInfo.leaderRid, Enum.Role.name )
        end
    end

    local strongHoldType = CFG.s_StrongHoldType:Get( holyLandType )
    local mapHolyLandInfo = const( table.copy( defaultMapHolyLandInfo, true ) )
    mapHolyLandInfo.pos = _pos
    mapHolyLandInfo.guildId = _holyLandInfo.guildId or 0
    mapHolyLandInfo.guildAbbName = guildAbbName or ""
    mapHolyLandInfo.strongHoldId = _holyLandInfo.strongHoldId
    mapHolyLandInfo.holyLandStatus = _holyLandInfo.holyLandStatus
    mapHolyLandInfo.holyLandFinishTime = _holyLandInfo.holyLandFinishTime
    mapHolyLandInfo.kingName = kingName or ""
    mapHolyLandInfo.armyRadius = strongHoldType.radius * 100
    mapHolyLandInfo.holyLandType = holyLandType
    mapHolyLandInfo.staticId = _holyLandInfo.strongHoldId
    mapHolyLandInfo.guildFlagSigns = guildFlagSigns or {}
    mapHolyLandInfo.armyCntLimit = CFG.s_StrongHoldType:Get( holyLandType, "armyCntLimit" )
    -- 如果处于初始状态,初始化怪物信息
    if _holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.PROTECT and _holyLandInfo.holyLandStatus ~= Enum.HolyLandStatus.SCRAMBLE then
        local armyCount, soldiers = MonsterLogic:cacleMonsterArmyCount( strongHoldType.initMonster )
        local skills, mainHeroSkills, deputyHeroSkills, monsterMainHeroId, monsterDeputyHeroId = HeroLogic:getMonsterAllHeroSkills( strongHoldType.initMonster )
        mapHolyLandInfo.soldiers = soldiers
        mapHolyLandInfo.armyCount = armyCount
        mapHolyLandInfo.armyCountMax = armyCount
        mapHolyLandInfo.skills = skills
        mapHolyLandInfo.mainHeroSkills = mainHeroSkills
        mapHolyLandInfo.deputyHeroSkills = deputyHeroSkills
        mapHolyLandInfo.mainHeroId = monsterMainHeroId
        mapHolyLandInfo.deputyHeroId = monsterDeputyHeroId
        mapHolyLandInfo.maxSp = ArmyLogic:cacleArmyMaxSp( skills )
        mapHolyLandInfo.holyLandBuildMonsterId = strongHoldType.initMonster
        mapHolyLandInfo.objectAttr = MonsterLogic:getMonsterAttr( strongHoldType.initMonster )
    end
    mapHolyLandInfos[_objectIndex] = mapHolyLandInfo
end

---@see 删除地图圣地对象
function accept.deleteHolyLandObject( _objectIndex )
    mapHolyLandInfos[_objectIndex] = nil
end

---@see 更新地图圣地信息
function accept.updateHolyLandInfo( _objectIndex, _updateHolyLandInfo )
    if mapHolyLandInfos[_objectIndex] then
        local oldGuildId = mapHolyLandInfos[_objectIndex].guildId
        local newGuildId = _updateHolyLandInfo.guildId or 0
        table.mergeEx( mapHolyLandInfos[_objectIndex], _updateHolyLandInfo )

        if _updateHolyLandInfo.holyLandStatus and _updateHolyLandInfo.holyLandStatus == Enum.HolyLandStatus.PROTECT
        and ArmyLogic:checkArmyStatus( mapHolyLandInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            -- 圣地进入保护期, 当前还在战斗中
            local attackers = MSM.AttackAroundPosMgr[_objectIndex].req.getAttackers( _objectIndex ) or {}
            -- 圣地退出战斗
            BattleCreate:exitBattle( _objectIndex, true )
            -- 攻击者返回城市
            local mapArmyInfo
            for _, attackerIndexs in pairs( attackers ) do
                for _, attackerIndex in pairs( attackerIndexs ) do
                    mapArmyInfo = MSM.SceneArmyMgr[attackerIndex].req.getArmyInfo( attackerIndex )
                    if mapArmyInfo.isRally then
                        -- 集结部队
                        MSM.RallyMgr[mapArmyInfo.guildId].req.disbandRallyArmy( mapArmyInfo.guildId, mapArmyInfo.rid, nil, true )
                    else
                        MSM.MapMarchMgr[attackerIndex].req.marchBackCity( mapArmyInfo.rid, attackerIndex )
                    end
                end
            end
        end

        if newGuildId > 0 and newGuildId ~= oldGuildId then
            -- 同联盟的攻击行军,修改为增援行军
            for moveObjectIndex, marchInfo in pairs( armyWalkToInfo[_objectIndex] or {} ) do
                local armyInfo = MSM.MapObjectTypeMgr[moveObjectIndex].req.getObjectInfo( moveObjectIndex )
                if armyInfo.guildId == newGuildId then
                    if marchInfo.marchType == Enum.MapMarchTargetType.ATTACK then
                        -- 攻击行军,转成增援
                        MSM.MapMarchMgr[moveObjectIndex].req.armyMove(moveObjectIndex, _objectIndex, armyWalkToInfo[_objectIndex].pos,
                                Enum.ArmyStatus.REINFORCE_MARCH, Enum.MapMarchTargetType.REINFORCE, nil, nil, nil, nil, armyInfo)
                    elseif marchInfo.marchType == Enum.MapMarchTargetType.RALLY_ATTACK then
                        -- 集结攻击,解散集结
                        MSM.RallyMgr[armyInfo.guildId].req.disbandRallyArmy( armyInfo.guildId, armyInfo.rid )
                    end
                end
            end
        end

        -- 常规保护、争夺中,移除怪物ID
        if _updateHolyLandInfo.holyLandStatus == Enum.HolyLandStatus.PROTECT
        or _updateHolyLandInfo.holyLandStatus == Enum.HolyLandStatus.SCRAMBLE then
            mapHolyLandInfos[_objectIndex].holyLandBuildMonsterId = 0
        end

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        sceneObject.post.syncObjectInfo( _objectIndex, _updateHolyLandInfo )
    end
end

---@see 获取地图圣地信息
function response.getHolyLandInfo( _objectIndex )
    return mapHolyLandInfos[_objectIndex]
end

---@see 获取地图圣地坐标
function response.getHolyLandPos( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        return mapHolyLandInfos[_objectIndex].pos
    end
end

---@see 获取地图圣地坐标
function response.getHolyLandRadius( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        return mapHolyLandInfos[_objectIndex].armyRadius
    end
end

---@see 增加军队向圣地行军
function accept.addArmyWalkToHolyLand( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapHolyLandInfos[_objectIndex] then
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
        mapHolyLandInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除军队向圣地行军
function accept.delArmyWalkToHolyLand( _objectIndex, _armyObjectIndex )
    if mapHolyLandInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapHolyLandInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
        end
    end
end

---@see 更新向目标行军的目标联盟
function accept.updateArmyWalkObjectGuildId( _objectIndex, _armyObjectIndex, _guildId )
    if mapHolyLandInfos[_objectIndex] and mapHolyLandInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapHolyLandInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapHolyLandInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end

---@see 获取地图圣地状态
function response.getHolyLandStatus( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        return mapHolyLandInfos[_objectIndex].holyLandStatus
    end
end

---@see 更新圣地状态
function response.updateHolyLandStatus( _objectIndex, _status, _statusOp )
    if mapHolyLandInfos[_objectIndex] then
        local oldStatus = mapHolyLandInfos[_objectIndex].status
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
        mapHolyLandInfos[_objectIndex].status = _status

        local battleBuff
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING ) then
            mapHolyLandInfos[_objectIndex].battleBuff = {}
            battleBuff = {}
        end

        local battleStatus = Enum.ArmyStatus.BATTLEING
        if ArmyLogic:checkArmyStatus( oldStatus, battleStatus ) and not ArmyLogic:checkArmyStatus( _status, battleStatus )
            and mapHolyLandInfos[_objectIndex].holyLandStatus ~= Enum.HolyLandStatus.PROTECT
            and mapHolyLandInfos[_objectIndex].holyLandStatus ~= Enum.HolyLandStatus.SCRAMBLE then
            -- 圣地退出战斗时还是初始怪物驻防
            local _, soldiers = MonsterLogic:cacleMonsterArmyCount( mapHolyLandInfos[_objectIndex].holyLandBuildMonsterId )
            mapHolyLandInfos[_objectIndex].soldiers = soldiers
        end

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = _status, battleBuff = battleBuff } )
    end
end

---@see 更新圣地部队数量
function accept.updateHolyLandCountAndSp( _objectIndex, _armyCount, _sp )
    if mapHolyLandInfos[_objectIndex] then
        mapHolyLandInfos[_objectIndex].armyCount = _armyCount
        mapHolyLandInfos[_objectIndex].sp = _sp
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 添加圣地关注角色ID
function accept.addFocusRid( _objectIndex, _rid )
    if mapHolyLandInfos[_objectIndex] then
        mapHolyLandInfos[_objectIndex].focusRids[_rid] = true

        local focusBuildObject = RoleLogic:getRole( _rid, Enum.Role.focusBuildObject ) or {}
        focusBuildObject[_objectIndex] = Enum.RoleBuildFocusType.HOLY_LAND
        RoleLogic:setRole( _rid, { [Enum.Role.focusBuildObject] = focusBuildObject } )
    end
end

---@see 删除关注圣地的角色ID
function accept.deleteFocusRid( _objectIndex, _rid, _deleteRole )
    if mapHolyLandInfos[_objectIndex] then
        mapHolyLandInfos[_objectIndex].focusRids[_rid] = nil

        if not _deleteRole then
            local focusBuildObject = RoleLogic:getRole( _rid, Enum.Role.focusBuildObject ) or {}
            focusBuildObject[_objectIndex] = nil
            RoleLogic:setRole( _rid, { [Enum.Role.focusBuildObject] = focusBuildObject } )
        end

        -- 通知角色删除圣地关卡中的部队
        local indexs = {}
        local reinforces = HolyLandLogic:getHolyLand( mapHolyLandInfos[_objectIndex].strongHoldId, Enum.HolyLand.reinforces ) or {}
        for buildArmyIndex in pairs( reinforces ) do
            table.insert( indexs, buildArmyIndex )
        end
        if not table.empty( indexs ) then
            HolyLandLogic:syncHolyLandArmy( _objectIndex, nil, nil, indexs, { [_rid] = _rid } )
        end
    end
end

---@see 获取所有关注的角色ID
function response.getFocusRids( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        return mapHolyLandInfos[_objectIndex].focusRids
    end
end

---@see 角色强制迁城.从圣地撤防
function accept.disbanArmyOnForceMoveCity( _objectIndex, _rid )
    if mapHolyLandInfos[_objectIndex] then
        local garrison = mapHolyLandInfos[_objectIndex].garrison
        if garrison[_rid] then
            for armyIndex in pairs(garrison[_rid]) do
                -- 如果目标在战斗,通知战斗服务器士兵减少
                if ArmyLogic:checkArmyStatus( mapHolyLandInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
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
            if not garrison[_rid] and _rid == mapHolyLandInfos[_objectIndex].garrisonLeader then
                local leaderRid, garrisonArmyIndex = GuildBuildLogic:selectGarrisonLeader( garrison )
                if leaderRid and leaderRid ~= mapHolyLandInfos[_objectIndex].garrisonLeader then
                    GuildBuildLogic:syncInfoOnChangeLeader( mapHolyLandInfos[_objectIndex], _objectIndex, leaderRid, garrisonArmyIndex )
                else
                    HolyLandLogic:syncHolyLandArmy( _objectIndex, nil, 0 )
                    mapHolyLandInfos[_objectIndex].garrisonLeader = 0
                    mapHolyLandInfos[_objectIndex].garrisonArmyIndex = 0
                end
            end

            for attackObjectIndex in pairs(armyWalkToInfo) do
                -- 取消预警
                EarlyWarningLogic:deleteEarlyWarning( _rid, attackObjectIndex, _objectIndex )
            end
        end
    end
end

---@see 添加圣地关卡驻防信息
function accept.addGarrisonArmy( _objectIndex, _rid, _armyIndex, _buildArmyIndex )
    if mapHolyLandInfos[_objectIndex] then
        local garrison = mapHolyLandInfos[_objectIndex].garrison
        local isSetLeader = table.empty(garrison)
        if garrison[_rid] and garrison[_rid][_armyIndex] then
            LOG_ERROR("addGarrisonArmy rid(%d) armyIndex(%d) had garrison this guild build", _rid, _armyIndex)
            return
        end
        ---@type defaultHolyLandGarrisonClass
        local defaultGarrisonInfo = const( table.copy( defaultHolyLandGarrisonInfo, true ) )
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

        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        if isSetLeader then
            -- 设置驻防队长
            mapHolyLandInfos[_objectIndex].garrisonLeader = _rid
            -- 设置驻防队伍
            mapHolyLandInfos[_objectIndex].garrisonArmyIndex = _armyIndex
            -- 计算技能和怒气
            local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( _rid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
            mapHolyLandInfos[_objectIndex].skills = skills or {}
            mapHolyLandInfos[_objectIndex].mainHeroSkills = mainHeroSkills or {}
            mapHolyLandInfos[_objectIndex].deputyHeroSkills = deputyHeroSkills or {}
            mapHolyLandInfos[_objectIndex].mainHeroId = armyInfo.mainHeroId or 0
            mapHolyLandInfos[_objectIndex].deputyHeroId = armyInfo.deputyHeroId or 0
            local maxSp = ArmyLogic:cacleArmyMaxSp( skills )
            mapHolyLandInfos[_objectIndex].maxSp = maxSp
            -- 通过AOI通知
            sceneObject.post.syncObjectInfo( _objectIndex, {
                                                                maxSp = maxSp,
                                                                mainHeroId = armyInfo.mainHeroId,
                                                                mainHeroSkills = mapHolyLandInfos[_objectIndex].mainHeroSkills,
                                                                deputyHeroSkills = mapHolyLandInfos[_objectIndex].deputyHeroSkills
                                                            }
                                        )
            -- 通知客户端驻防队长信息
            HolyLandLogic:updateHolyLandLeader( mapHolyLandInfos[_objectIndex], _objectIndex, _rid, _armyIndex )
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
        mapHolyLandInfos[_objectIndex].armyCountMax = armyCountMax
        mapHolyLandInfos[_objectIndex].armyCount = armyCount
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCountMax = armyCountMax, armyCount = armyCount } )

        -- 如果部队正在战斗,通知战斗服务器士兵加入
        if ArmyLogic:checkArmyStatus( mapHolyLandInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
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

---@see 移除圣地关卡驻防信息
function accept.delGarrisonArmy( _objectIndex, _rid, _armyIndex )
    if mapHolyLandInfos[_objectIndex] then
        local garrison = mapHolyLandInfos[_objectIndex].garrison
        if garrison[_rid] and garrison[_rid][_armyIndex] then
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
            -- 重新计算最大血量
            local armyCountMax = 0
            for _, subArmyInfo in pairs(garrison) do
                for _, garrisonInfo in pairs(subArmyInfo) do
                    armyCountMax = armyCountMax + garrisonInfo.armyCountMax
                end
            end
            -- 同步最大血量
            mapHolyLandInfos[_objectIndex].armyCountMax = armyCountMax
            sceneObject.post.syncObjectInfo( _objectIndex, { armyCountMax = armyCountMax } )

            garrison[_rid][_armyIndex] = nil
            -- 重新选择队长
            if mapHolyLandInfos[_objectIndex].garrisonLeader == _rid and mapHolyLandInfos[_objectIndex].garrisonArmyIndex == _armyIndex then
                local leaderRid, garrisonArmyIndex = GuildBuildLogic:selectGarrisonLeader( garrison )
                if leaderRid then
                    GuildBuildLogic:syncInfoOnChangeLeader( mapHolyLandInfos[_objectIndex], _objectIndex, leaderRid, garrisonArmyIndex )
                else
                    HolyLandLogic:syncHolyLandArmy( _objectIndex, nil, 0 )
                    mapHolyLandInfos[_objectIndex].garrisonLeader = 0
                    mapHolyLandInfos[_objectIndex].garrisonArmyIndex = 0
                end
            end

            -- 如果部队正在战斗,通知战斗服务器士兵减少
            if ArmyLogic:checkArmyStatus( mapHolyLandInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
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

---@see 获取圣地中的驻守部队.用于战斗
function response.getGarrisonArmy( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        if mapHolyLandInfos[_objectIndex].holyLandStatus == Enum.HolyLandStatus.INIT_SCRAMBLE then
            -- 初始野怪
            return {
                        soldiers = mapHolyLandInfos[_objectIndex].soldiers,
                        mainHeroId = mapHolyLandInfos[_objectIndex].mainHeroId,
                        deputyHeroId = mapHolyLandInfos[_objectIndex].deputyHeroId,
                        skills = mapHolyLandInfos[_objectIndex].skills,
                        maxSp = mapHolyLandInfos[_objectIndex].maxSp,
                        rallySoldiers = { [0] = { [0] = mapHolyLandInfos[_objectIndex].soldiers } },
                        objectAttr = mapHolyLandInfos[_objectIndex].objectAttr,
                        isCheckPointMonster = true
            }
        elseif mapHolyLandInfos[_objectIndex].holyLandStatus == Enum.HolyLandStatus.SCRAMBLE then
            local garrisonLeader = mapHolyLandInfos[_objectIndex].garrisonLeader
            local garrisonArmyIndex = mapHolyLandInfos[_objectIndex].garrisonArmyIndex
            if not garrisonLeader or garrisonLeader <= 0 then
                return
            end
            local garrison = mapHolyLandInfos[_objectIndex].garrison
            local soldiers = {}
            local rallyHeros = {}
            local rallySoldiers = {}
            local garrisonArmyInfo
            for garrisonRid, armyInfo in pairs(garrison) do
                for garrisonArmy in pairs(armyInfo) do
                    garrisonArmyInfo = ArmyLogic:getArmy( garrisonRid, garrisonArmy, { Enum.Army.mainHeroId, Enum.Army.deputyHeroId, Enum.Army.mainHeroLevel, Enum.Army.deputyHeroLevel, Enum.Army.soldiers } )
                if garrisonArmyInfo then
                    if not rallySoldiers[garrisonRid] then
                        rallySoldiers[garrisonRid] = {}
                    end
                    rallySoldiers[garrisonRid][garrisonArmy] = garrisonArmyInfo.soldiers
                    for soldierId, soldierInfo in pairs(garrisonArmyInfo.soldiers) do
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
            return {
                        garrisonLeader = garrisonLeader,
                        soldiers = soldiers,
                        rallyHeros = rallyHeros,
                        mainHeroId = leaderArmyInfo.mainHeroId,
                        mainHeroLevel = leaderArmyInfo.mainHeroLevel,
                        deputyHeroId = leaderArmyInfo.deputyHeroId,
                        deputyHeroLevel = leaderArmyInfo.deputyHeroLevel,
                        objectAttr = RoleCacle:getRoleBattleAttr( garrisonLeader ),
                        skills = mapHolyLandInfos[_objectIndex].skills,
                        maxSp = mapHolyLandInfos[_objectIndex].maxSp,
                        rallySoldiers = rallySoldiers,
                        staticId = mapHolyLandInfos[_objectIndex].staticId,
                        rallyLeader = garrisonLeader,
                        talentAttr = HeroLogic:getHeroTalentAttr( garrisonLeader, leaderArmyInfo.mainHeroId ).battleAttr,
                        equipAttr = HeroLogic:getHeroEquipAttr( garrisonLeader, leaderArmyInfo.mainHeroId ).battleAttr,
            }
        end
    end
end

---@see 目标退出联盟.部队从圣地撤防
function accept.onExitGuildDisarm( _objectIndex, _rid, _armyIndex )
    if mapHolyLandInfos[_objectIndex] then
        local garrison = mapHolyLandInfos[_objectIndex].garrison
        if garrison[_rid][_armyIndex] then
            -- 如果目标在战斗,通知战斗服务器士兵减少
            if ArmyLogic:checkArmyStatus( mapHolyLandInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
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
            if not garrison[_rid] and _rid == mapHolyLandInfos[_objectIndex].garrisonLeader then
                local leaderRid, garrisonArmyIndex = GuildBuildLogic:selectGarrisonLeader( garrison )
                if leaderRid and leaderRid ~= mapHolyLandInfos[_objectIndex].garrisonLeader then
                    GuildBuildLogic:syncInfoOnChangeLeader( mapHolyLandInfos[_objectIndex], _objectIndex, leaderRid, garrisonArmyIndex )
                else
                    HolyLandLogic:syncHolyLandArmy( _objectIndex, nil, 0 )
                    mapHolyLandInfos[_objectIndex].garrisonLeader = 0
                    mapHolyLandInfos[_objectIndex].garrisonArmyIndex = 0
                end
            end

            -- 取消预警
            EarlyWarningLogic:leaveBuildDelWarning( _rid, _objectIndex, armyWalkToInfo[_objectIndex] )
        end
    end
end

---@see 驻守失败.部队全部回城
function response.garrisonDefeat( _objectIndex, _attackRid )
    if mapHolyLandInfos[_objectIndex] then
        if mapHolyLandInfos[_objectIndex].garrisonLeader and mapHolyLandInfos[_objectIndex].garrisonLeader > 0 then
            -- 圣地部队退出
            HolyLandLogic:guildHolyLandArmyExit( mapHolyLandInfos[_objectIndex].strongHoldId, _objectIndex, true, mapHolyLandInfos[_objectIndex] )

            for garrisonRid in pairs(mapHolyLandInfos[_objectIndex].garrison) do
                -- 取消预警
                EarlyWarningLogic:leaveBuildDelWarning( garrisonRid, _objectIndex, armyWalkToInfo[_objectIndex] )
            end
        end

        mapHolyLandInfos[_objectIndex].garrison = {}
        mapHolyLandInfos[_objectIndex].garrisonArmyIndex = 0
        mapHolyLandInfos[_objectIndex].garrisonLeader = 0
        mapHolyLandInfos[_objectIndex].mainHeroId = 0
        mapHolyLandInfos[_objectIndex].deputyHeroId = 0
        mapHolyLandInfos[_objectIndex].mainHeroSkills = {}
        mapHolyLandInfos[_objectIndex].deputyHeroSkills = {}
        mapHolyLandInfos[_objectIndex].skills = {}
        mapHolyLandInfos[_objectIndex].armyCountMax = 0
        mapHolyLandInfos[_objectIndex].maxSp = 0

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        sceneObject.post.syncObjectInfo( _objectIndex, { maxSp = 0, mainHeroId = 0, armyCountMax = 0 } )

        local attackGuildId = RoleLogic:getRole( _attackRid, Enum.Role.guildId ) or 0
        if attackGuildId > 0 then
            MSM.GuildMgr[attackGuildId].req.occupyHolyLand( attackGuildId, mapHolyLandInfos[_objectIndex].strongHoldId )
        end
        mapHolyLandInfos[_objectIndex].focusRids = {}
    end
end

---@see 获取圣地驻守队长信息
function response.getGarrisonLeader( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        return mapHolyLandInfos[_objectIndex].garrisonLeader, mapHolyLandInfos[_objectIndex].garrisonArmyIndex
    end
end

---@see 获取建筑内的成员rids
function response.getMemberRidsInBuild( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        return table.indexs( mapHolyLandInfos[_objectIndex].garrison )
    end
end

---@see 清空圣地关卡驻守信息.联盟解散
function response.cleanGarrisonOnDisbandGuild( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        -- 圣地部队退出
        HolyLandLogic:guildHolyLandArmyExit( mapHolyLandInfos[_objectIndex].strongHoldId, _objectIndex, nil, mapHolyLandInfos[_objectIndex] )

        for garrisonRid in pairs(mapHolyLandInfos[_objectIndex].garrison) do
            for attackObjectIndex in pairs(armyWalkToInfo) do
                -- 取消预警
                EarlyWarningLogic:deleteEarlyWarning( garrisonRid, attackObjectIndex, _objectIndex )
            end
        end

        mapHolyLandInfos[_objectIndex].garrison = {}
        mapHolyLandInfos[_objectIndex].garrisonArmyIndex = 0
        mapHolyLandInfos[_objectIndex].garrisonLeader = 0
        mapHolyLandInfos[_objectIndex].mainHeroId = 0
        mapHolyLandInfos[_objectIndex].deputyHeroId = 0
        mapHolyLandInfos[_objectIndex].mainHeroSkills = {}
        mapHolyLandInfos[_objectIndex].deputyHeroSkills = {}
        mapHolyLandInfos[_objectIndex].skills = {}
        mapHolyLandInfos[_objectIndex].armyCountMax = 0
    end
end

---@see 更新圣地初始怪物士兵信息
function accept.updateHolyLandMonsterSoldiers( _objectIndex, _soldierHurts )
    if mapHolyLandInfos[_objectIndex] then
        local soldiers = mapHolyLandInfos[_objectIndex].soldiers or {}
        for soldierId, hurtInfo in pairs( _soldierHurts or {} ) do
            if soldiers[soldierId] then
                soldiers[soldierId].num = soldiers[soldierId].num - ( hurtInfo.hardHurt or 0 ) - ( hurtInfo.die or 0 ) - ( hurtInfo.minor or 0 )
            end
        end
    end
end

---@see PMLogic重置圣地关卡属性到初始争夺中
function response.resetHolyLand( _objectIndex )
    if mapHolyLandInfos[_objectIndex] then
        -- 退出战斗
        if ArmyLogic:checkArmyStatus( mapHolyLandInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            BattleCreate:exitBattle( _objectIndex, true )
        end
        -- 圣地部队退出
        HolyLandLogic:guildHolyLandArmyExit( mapHolyLandInfos[_objectIndex].strongHoldId, _objectIndex, nil, mapHolyLandInfos[_objectIndex] )

        for garrisonRid in pairs(mapHolyLandInfos[_objectIndex].garrison) do
            for attackObjectIndex in pairs(armyWalkToInfo) do
                -- 取消预警
                EarlyWarningLogic:deleteEarlyWarning( garrisonRid, attackObjectIndex, _objectIndex )
            end
        end

        local holyLandType = CFG.s_StrongHoldData:Get( mapHolyLandInfos[_objectIndex].strongHoldId, "type" )
        local strongHoldType = CFG.s_StrongHoldType:Get( holyLandType )
        local armyCount, soldiers = MonsterLogic:cacleMonsterArmyCount( strongHoldType.initMonster )
        local skills, mainHeroSkills, deputyHeroSkills, monsterMainHeroId, monsterDeputyHeroId = HeroLogic:getMonsterAllHeroSkills( strongHoldType.initMonster )
        mapHolyLandInfos[_objectIndex].soldiers = soldiers
        mapHolyLandInfos[_objectIndex].armyCount = armyCount
        mapHolyLandInfos[_objectIndex].armyCountMax = armyCount
        mapHolyLandInfos[_objectIndex].skills = skills
        mapHolyLandInfos[_objectIndex].mainHeroSkills = mainHeroSkills
        mapHolyLandInfos[_objectIndex].deputyHeroSkills = deputyHeroSkills
        mapHolyLandInfos[_objectIndex].mainHeroId = monsterMainHeroId
        mapHolyLandInfos[_objectIndex].deputyHeroId = monsterDeputyHeroId
        mapHolyLandInfos[_objectIndex].maxSp = ArmyLogic:cacleArmyMaxSp( skills )
        mapHolyLandInfos[_objectIndex].holyLandBuildMonsterId = strongHoldType.initMonster
        mapHolyLandInfos[_objectIndex].objectAttr = MonsterLogic:getMonsterAttr( strongHoldType.initMonster )
        mapHolyLandInfos[_objectIndex].garrison = {}
        mapHolyLandInfos[_objectIndex].garrisonArmyIndex = 0
        mapHolyLandInfos[_objectIndex].garrisonLeader = 0
    end
end

---@see 同步对象战斗buff
function accept.syncHolyLandBattleBuff( _objectIndex, _battleBuff )
    if mapHolyLandInfos[_objectIndex] then
        mapHolyLandInfos[_objectIndex].battleBuff = _battleBuff
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.PREVIEW )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end