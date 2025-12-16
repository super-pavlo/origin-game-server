--[[
 * @file : SceneMonsterCityMgr.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2020-05-12 11:59:36
 * @Last Modified time: 2020-05-12 11:59:36
 * @department : Arabic Studio
 * @brief : 地图野蛮人城寨管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local MonsterLogic = require "MonsterLogic"
local HeroLogic = require "HeroLogic"
local ArmyLogic = require "ArmyLogic"
local ArmyDef = require "ArmyDef"

---@see 地图野蛮人城寨信息
---@class defaultMapMonsterCityInfoClass
local defaultMapMonsterCityInfo = {
    pos                         =                   {},             -- 城市坐标
    level                       =                   0,              -- 城市等级
    monsterId                   =                   0,              -- 怪物ID
    status                      =                   0,              -- 城市状态
    armyCountMax                =                   0,              -- 城市部队数量上限
    armyCount                   =                   0,              -- 当前部队数量
    maxSp                       =                   0,              -- 最大怒气
    sp                          =                   0,              -- 当前怒气
    mainHeroId                  =                   0,              -- 主将ID
    deputyHeroId                =                   0,              -- 副将ID
    mainHeroSkills              =                   {},             -- 主将技能
    deputyHeroSkills            =                   {},             -- 副将技能
    soldiers                    =                   0,              -- 部队士兵
    skills                      =                   {},             -- 技能
    battleBuff                  =                   {},             -- 战斗buff
    refreshTime                 =                   0,              -- 野蛮人城寨刷新时间
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    armyRadius                  =                   0,              -- 半径
    staticId                    =                   0,              -- 静态对象ID
}

---@type table<int, defaultMapMonsterCityInfoClass>
local mapMonsterCityInfos = {}
---@type table<int, table>
local armyWalkToInfo = {}

---@see 增加野蛮人城寨对象
function response.addMonsterCityObject( _objectIndex, _monsterCityInfo, _pos )
    -- 初始化野蛮人城寨战斗阵容
    local monsterId = _monsterCityInfo.monsterId
    local armyCount, soldiers = MonsterLogic:cacleMonsterArmyCount( monsterId )
    _pos.x = math.floor( _pos.x )
    _pos.y = math.floor( _pos.y )
    local sMonsterInfo = CFG.s_Monster:Get(monsterId)
    local skills, mainHeroSkills, deputyHeroSkills, monsterMainHeroId, monsterDeputyHeroId = HeroLogic:getMonsterAllHeroSkills( monsterId )

    local mapMonsterCityInfo = const( table.copy( defaultMapMonsterCityInfo, true ) )
    mapMonsterCityInfo.pos = _pos
    mapMonsterCityInfo.monsterId = monsterId
    mapMonsterCityInfo.soldiers = soldiers
    mapMonsterCityInfo.armyCount = armyCount
    mapMonsterCityInfo.armyCountMax = armyCount
    mapMonsterCityInfo.mainHeroId = monsterMainHeroId
    mapMonsterCityInfo.deputyHeroId = monsterDeputyHeroId
    mapMonsterCityInfo.skills = skills
    mapMonsterCityInfo.mainHeroSkills = mainHeroSkills
    mapMonsterCityInfo.deputyHeroSkills = deputyHeroSkills
    mapMonsterCityInfo.sp = 0
    mapMonsterCityInfo.maxSp = ArmyLogic:cacleArmyMaxSp( skills )
    mapMonsterCityInfo.level = sMonsterInfo.level
    mapMonsterCityInfo.refreshTime = _monsterCityInfo.refreshTime
    mapMonsterCityInfo.armyRadius = CFG.s_Config:Get("resourceGatherRadius") * 100
    mapMonsterCityInfo.staticId = monsterId
    mapMonsterCityInfos[_objectIndex] = mapMonsterCityInfo
end

---@see 删除野蛮人城寨对象
function accept.deleteMonsterCityObject( _objectIndex )
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

    mapMonsterCityInfos[_objectIndex] = nil
    MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
end

---@see 获取野蛮人城寨信息
function response.getMonsterCityInfo( _objectIndex )
    return mapMonsterCityInfos[_objectIndex]
end

---@see 获取野蛮人城寨位置
function response.getMonsterCityPos( _objectIndex )
    if mapMonsterCityInfos[_objectIndex] then
        return mapMonsterCityInfos[_objectIndex].pos
    end
end

---@see 获取野蛮人城寨状态
function response.getMonsterCityStatus( _objectIndex )
    if mapMonsterCityInfos[_objectIndex] then
        return mapMonsterCityInfos[_objectIndex].status
    end
end

---@see 更新怪物士兵信息
function accept.updateMonsterCitySoldier( _objectIndex, _subSoldiers )
    if mapMonsterCityInfos[_objectIndex] then
        for soldierId, soldierInfo in pairs(_subSoldiers) do
            if mapMonsterCityInfos[_objectIndex].soldiers[soldierId] then
                mapMonsterCityInfos[_objectIndex].soldiers[soldierId].num = mapMonsterCityInfos[_objectIndex].soldiers[soldierId].num - soldierInfo.num
                if mapMonsterCityInfos[_objectIndex].soldiers[soldierId].num < 0 then
                    mapMonsterCityInfos[_objectIndex].soldiers[soldierId].num = 0
                end
            end
        end
    end
end

---@see 更新野蛮人城寨状态
function response.updateMonsterCityStatus( _objectIndex, _status, _statusOp )
    if mapMonsterCityInfos[_objectIndex] then
        local oldStatus = mapMonsterCityInfos[_objectIndex].status
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
        mapMonsterCityInfos[_objectIndex].status = _status

        local battleBuff
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING ) then
            mapMonsterCityInfos[_objectIndex].battleBuff = {}
            battleBuff = {}
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = _status, battleBuff = battleBuff } )
    end
end

---@see 更新野蛮人城寨部队数量
function accept.updateMonsterCityCountAndSp( _objectIndex, _armyCount, _sp )
    if mapMonsterCityInfos[_objectIndex] then
        mapMonsterCityInfos[_objectIndex].armyCount = _armyCount
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 野蛮人城寨部队数量重置
function response.resetMonsterCityCount( _objectIndex )
    if mapMonsterCityInfos[_objectIndex] then
        local monsterId = mapMonsterCityInfos[_objectIndex].monsterId
        if MonsterLogic:checkRecoverArmyCount( monsterId ) then
            local armyCount, soldiers = MonsterLogic:cacleMonsterArmyCount( monsterId )
            mapMonsterCityInfos[_objectIndex].armyCount = armyCount
            mapMonsterCityInfos[_objectIndex].soldiers = soldiers
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = armyCount, sp = 0 } )
        end
    end
end


---@see 增加军队向怪物行军
function accept.addArmyWalkToMonsterCity( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapMonsterCityInfos[_objectIndex] then
        if not armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex] = {}
        end
        armyWalkToInfo[_objectIndex][_armyObjectIndex] = { marchType = _marchType, arrivalTime = _arrivalTime }

        local armyInfo = MSM.SceneArmyMgr[_armyObjectIndex].req.getArmyInfo( _armyObjectIndex )
        local armyMarchInfo = ArmyDef:getDefaultArmyMarchInfo()
        armyMarchInfo.objectIndex = _armyObjectIndex
        armyMarchInfo.rid = armyInfo.rid
        armyMarchInfo.path = _path
        armyMarchInfo.guildId = armyInfo.guildId
        mapMonsterCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除军队向怪物行军
function accept.delArmyWalkToMonsterCity( _objectIndex, _armyObjectIndex )
    if mapMonsterCityInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapMonsterCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
        end
    end
end

---@see 更新向目标行军的目标联盟
function accept.updateArmyWalkObjectGuildId( _objectIndex, _armyObjectIndex, _guildId )
    if mapMonsterCityInfos[_objectIndex] and mapMonsterCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapMonsterCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapMonsterCityInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end

---@see 同步对象战斗buff
function accept.syncMonsterCityBattleBuff( _objectIndex, _battleBuff )
    if mapMonsterCityInfos[_objectIndex] then
        mapMonsterCityInfos[_objectIndex].battleBuff = _battleBuff
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end