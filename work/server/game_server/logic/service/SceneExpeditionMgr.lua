--[[
* @file : SceneExpeditionMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Fri May 08 2020 13:26:46 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图运输车管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"
local MonsterLogic = require "MonsterLogic"
local ArmyLogic = require "ArmyLogic"
local HeroLogic = require "HeroLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"
local MapLogic = require "MapLogic"
local ExpeditionLogic = require "ExpeditionLogic"
local Timer = require "Timer"
local ArmyMarchLogic = require "ArmyMarchLogic"
local BattleCreate = require "BattleCreate"
local Random = require "Random"
local BattleAttrLogic = require "BattleAttrLogic"
local ArmyDef = require "ArmyDef"
local CommonCacle = require "CommonCacle"

---@see 远征对象信息信息
---@class defaultMapExpeditionInfoClass
local defaultMapExpeditionInfo = {
    pos                         =                   {},             -- 坐标
    rid                         =                   0,              -- 角色rid
    armyName                    =                   "",             -- 角色名称
    arrivalTime                 =                   0,              -- 远征对象到达时间
    startTime                   =                   0,              -- 远征对象到时间
    speed                       =                   0,              -- 远征对象移动速度
    path                        =                   {},             -- 远征对象移动路径
    objectIndex                 =                   0,              -- 远征对象索引
    targetObjectIndex           =                   0,              -- 目标索引
    type                        =                   0,              -- 对象类型
    guildAbbName                =                   "",             -- 联盟简称
    guildId                     =                   0,              -- 联盟id
    mapIndex                    =                   0,              -- 虚拟地图索引
    monsterId                   =                   0,              -- 怪物id
    soldiers                    =                   {},             -- 士兵信息
    armyCount                   =                   0,              -- 士兵数量
    armyCountMax                =                   0,              -- 士兵最大数量
    sp                          =                   0,              -- 怒气
    maxSp                       =                   0,              -- 最大怒气
    skills                      =                   {},             -- 技能
    mainHeroSkills              =                   {},             -- 技能
    deputyHeroSkills            =                   {},             -- 技能
    mainHeroId                  =                   0,              -- 主将id
    mainHeroLevel               =                   0,              -- 主将等级
    deputyHeroId                =                   0,              -- 副将id
    deputyHeroLevel             =                   0,              -- 副将等级
    armyIndex                   =                   0,              -- 部队顺序
    status                      =                   0,              -- 军队状态
    angle                       =                   0,              -- 军队角度
    armyRadius                  =                   0,              -- 军队半径
    monsterIndex                =                   0,              -- 怪物索引
    battleBuff                  =                   {},             -- buff
    initPos                     =                   {},             -- 初始坐标
    followUpDistance            =                   0,              -- 追击距离
    expeditionId                =                   0,
    armyMarchInfo               =                   {},
    attackCount                 =                   0,              -- 攻击方数量
    nextPartolTime              =                   0,              -- 下次巡逻时间
    next                        =                   {},             -- 怪物巡逻下一个坐标
    movePath                    =                   {},             -- 怪物巡逻路经
    moveSpeed                   =                   {},             -- 野蛮人巡逻速度
    targetObjectType            =                   0,              -- 目标类型
    objectAttr                  =                   {},             -- 对象属性
}

---@type table<int, defaultMapTransportInfoClass>
local mapExpeditionInfos = {}
---@type table<int, int>
local mapMonsterFollowInfos = {}
---@type table<int, table>
local armyWalkToInfo = {}
---@type table<int, int>
local monsterLastUpdatePos = {}
---@type table<int, defaultMapMonsterInfoClass>
local mapMonsterInfos = {}

function init()
    -- 每秒处理巡逻
    Timer.runEvery( 100, ExpeditionLogic.dispatchMonsterPartol, ExpeditionLogic, mapMonsterInfos )
     -- 每秒处理巡逻移动
    Timer.runEvery( 100, ExpeditionLogic.updateMonsterPartolPos, ExpeditionLogic, mapMonsterInfos, monsterLastUpdatePos, armyWalkToInfo )
    -- 每两秒检测下追击
    Timer.runEvery( 100, ExpeditionLogic.dispatchMonsterFollowUp, ExpeditionLogic, mapMonsterFollowInfos, mapExpeditionInfos )
end

---@see 增加远征对象
function response.addExpeditionObject( _objectIndex, _ExpeditionInfo, _pos )
    local guildAbbName
    local roleInfo = {}
    if _ExpeditionInfo.rid and _ExpeditionInfo.rid > 0 then
        roleInfo = RoleLogic:getRole( _ExpeditionInfo.rid, { Enum.Role.name, Enum.Role.guildId } )
    end
    if roleInfo.guildId and roleInfo.guildId > 0 then
        guildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end
    local monsterId = _ExpeditionInfo.monsterId
    _pos.x = math.floor( _pos.x )
    _pos.y = math.floor( _pos.y )
    local skills, mainHeroSkills, deputyHeroSkills, monsterMainHeroId, monsterDeputyHeroId
    local armyCount, soldiers, sMonsterInfo, cdMin, cdMax
    if monsterId and monsterId > 0 then
        --local sMonsterInfo = CFG.s_Monster:Get(monsterId)
        armyCount, soldiers = MonsterLogic:cacleMonsterArmyCount( monsterId )
        skills, mainHeroSkills, deputyHeroSkills, monsterMainHeroId, monsterDeputyHeroId = HeroLogic:getMonsterAllHeroSkills( monsterId )
        sMonsterInfo = CFG.s_Monster:Get(monsterId)
        cdMin = math.floor( sMonsterInfo.patrolTimeCD / 1000 )
        cdMax = math.floor( sMonsterInfo.patrolTimeCdMax / 1000 )
    else
        soldiers = _ExpeditionInfo.soldiers
        skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( _ExpeditionInfo.rid, _ExpeditionInfo.mainHeroId, _ExpeditionInfo.deputyHeroId )
        armyCount = ArmyLogic:getArmySoldierCount( _ExpeditionInfo.soldiers )
    end

    local mapExpeditionInfo = const( table.copy( defaultMapExpeditionInfo, true ) )
    mapExpeditionInfo.pos = _pos
    mapExpeditionInfo.initPos = _pos
    mapExpeditionInfo.rid = _ExpeditionInfo.rid or 0
    mapExpeditionInfo.armyName = roleInfo.name
    mapExpeditionInfo.arrivalTime = _ExpeditionInfo.arrivalTime or 0
    mapExpeditionInfo.startTime = _ExpeditionInfo.startTime or 0
    mapExpeditionInfo.speed = _ExpeditionInfo.speed or 0
    mapExpeditionInfo.path = _ExpeditionInfo.path or {}
    mapExpeditionInfo.objectIndex = _objectIndex or 0
    mapExpeditionInfo.targetObjectIndex = _ExpeditionInfo.taregtObjectIndex or 0
    mapExpeditionInfo.guildAbbName = guildAbbName
    mapExpeditionInfo.guildId =  roleInfo.guildId
    mapExpeditionInfo.monsterId = monsterId or 0
    mapExpeditionInfo.soldiers = soldiers
    mapExpeditionInfo.armyCount = armyCount
    mapExpeditionInfo.armyCountMax = armyCount
    mapExpeditionInfo.sp = 0
    mapExpeditionInfo.maxSp = ArmyLogic:cacleArmyMaxSp( skills )
    mapExpeditionInfo.skills = skills
    mapExpeditionInfo.mainHeroSkills = mainHeroSkills
    mapExpeditionInfo.deputyHeroSkills = deputyHeroSkills
    mapExpeditionInfo.mainHeroId = _ExpeditionInfo.mainHeroId or monsterMainHeroId
    mapExpeditionInfo.mainHeroLevel = _ExpeditionInfo.mainHeroLevel
    mapExpeditionInfo.deputyHeroId = _ExpeditionInfo.deputyHeroId or monsterDeputyHeroId
    mapExpeditionInfo.deputyHeroLevel = _ExpeditionInfo.deputyHeroLevel
    mapExpeditionInfo.armyIndex = _ExpeditionInfo.armyIndex
    mapExpeditionInfo.status = _ExpeditionInfo.status
    mapExpeditionInfo.monsterIndex = _ExpeditionInfo.monsterIndex
    mapExpeditionInfo.armyRadius = _ExpeditionInfo.armyRadius
    mapExpeditionInfo.mapIndex = _ExpeditionInfo.mapIndex
    mapExpeditionInfo.expeditionId = _ExpeditionInfo.expeditionId
    mapExpeditionInfo.armyMarchInfo = {}
    mapExpeditionInfo.angle = _ExpeditionInfo.angle
    if monsterId and monsterId > 0 then
        mapExpeditionInfo.followUpDistance = sMonsterInfo.battleFollowDistance
        mapExpeditionInfo.nextPartolTime = os.time() + Random.Get(cdMin, cdMax)
        if CFG.s_Monster:Get(monsterId, "patrolRadius") > 0 then
            mapMonsterInfos[_objectIndex] = mapExpeditionInfo
        end
        mapExpeditionInfo.objectAttr = MonsterLogic:getMonsterAttr( monsterId )
    end
    mapExpeditionInfos[_objectIndex] = mapExpeditionInfo
end

---@see 删除远征对象
function response.deleteExpeditionObject( _objectIndex )
    if mapExpeditionInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            local mapArmyInfo, armyStatus
            -- 向该目标行军的部队驻扎原地
            for armyObjectIndex in pairs( armyWalkToInfo[_objectIndex] ) do
                mapArmyInfo = MSM.SceneExpeditionMgr[armyObjectIndex].req.getExpeditionInfo(armyObjectIndex)
                if mapArmyInfo then
                    armyStatus = mapArmyInfo.status
                    if armyStatus and ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.ATTACK_MARCH ) then
                        armyStatus = ArmyLogic:delArmyStatus( armyStatus, Enum.ArmyStatus.ATTACK_MARCH )
                        if armyStatus ~= 0 then
                            MSM.MapMarchMgr[armyObjectIndex].req.expeditionArmyMove( armyObjectIndex, nil, nil, Enum.ArmyStatus.ATTACK_MARCH, Enum.MapMarchTargetType.STATION, nil, nil, nil, Enum.ArmyStatusOp.DEL )
                        else
                            MSM.MapMarchMgr[armyObjectIndex].req.expeditionArmyMove( armyObjectIndex, nil, nil, Enum.ArmyStatus.STATIONING, Enum.MapMarchTargetType.STATION, nil, nil, nil, Enum.ArmyStatusOp.SET )
                        end
                    end
                end
            end
        end
        mapExpeditionInfos[_objectIndex] = nil
        mapMonsterFollowInfos[_objectIndex] = nil
        armyWalkToInfo[_objectIndex] = nil
        monsterLastUpdatePos[_objectIndex] = nil
        mapMonsterInfos[_objectIndex] = nil
        MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
    end
end

---@see 怪物返回原点
function accept.backInitPos( _objectIndex )
    -- 怪物返回原来位置
    local mapMonsterInfo = mapExpeditionInfos[_objectIndex]
    for objectIndex, t in pairs(armyWalkToInfo) do
        for moveObjectIndex in pairs(t) do
            if moveObjectIndex == _objectIndex then
                armyWalkToInfo[objectIndex][_objectIndex] = nil
            end
        end
    end
    mapMonsterFollowInfos[_objectIndex] = nil
    mapExpeditionInfos[_objectIndex].status = ArmyLogic:delArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.FOLLOWUP )

    -- 获取目标点坐标、状态
    local targetPos = mapMonsterInfo.initPos
    local armyStatus = Enum.ArmyStatus.SPACE_MARCH
    local targetObjectIndex = mapMonsterInfo.targetObjectIndex
    if targetObjectIndex and targetObjectIndex > 0 then
        MSM.SceneExpeditionMgr[targetObjectIndex].post.delArmyWalkToExpedition( targetObjectIndex, _objectIndex )
    end
    -- 处理行军
    ArmyMarchLogic:dispatchExpeditionMarch( nil, _objectIndex, nil, Enum.MapMarchTargetType.SPACE, targetPos, armyStatus, nil )
end

---@see 更新远征对象坐标
function accept.updateExpeditionPos( _objectIndex, _pos )
    if mapExpeditionInfos[_objectIndex] then
        _pos.x = math.floor( _pos.x )
        _pos.y = math.floor( _pos.y )
        mapExpeditionInfos[_objectIndex].pos = _pos

        -- 如果处于战斗,更新坐标
        if ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
            if battleIndex then
                -- 通知对象更新坐标
                local battleNode = BattleCreate:getBattleServerNode( battleIndex )
                Common.rpcMultiSend( battleNode, "BattleLoop", "updateObjectPos", battleIndex, _objectIndex, _pos, mapExpeditionInfos[_objectIndex].angle )
            end
        end
        -- 如果有目标向军队行军,更新坐标
        if armyWalkToInfo[_objectIndex] then
            for moveObjectIndex in pairs(armyWalkToInfo[_objectIndex]) do
                local armyInfo = MSM.SceneExpeditionMgr[moveObjectIndex].req.getExpeditionInfo( moveObjectIndex )
                if armyInfo then
                    if armyInfo.targetObjectIndex == _objectIndex then
                        armyInfo.pos = MSM.MapMarchMgr[moveObjectIndex].req.fixObjectPosWithMillisecond(moveObjectIndex, true) or armyInfo.pos
                        local path = { armyInfo.pos, _pos }
                        -- 修正坐标
                        local armyRadius, monsterRadius
                        if armyInfo.rid and armyInfo.rid > 0 then
                            armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                            --monsterRadius = CFG.s_Monster:Get( mapExpeditionInfos[_objectIndex].monsterId, "radius" ) * Enum.MapPosMultiple
                            monsterRadius = CommonCacle:getArmyRadius( mapExpeditionInfos[_objectIndex].soldiers )
                        else
                            armyRadius = CommonCacle:getArmyRadius( mapExpeditionInfos[_objectIndex].soldiers )
                            --monsterRadius = CFG.s_Monster:Get( armyInfo.monsterId, "radius" ) * Enum.MapPosMultiple
                            monsterRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                        end
                        local expeditionId = armyInfo.expeditionId
                        local sExpedition = CFG.s_Expedition:Get(expeditionId)
                        local sExpeditionBattle = CFG.s_ExpeditionBattle:Get(sExpedition.battleID)
                        path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.EXPEDITION, path, armyRadius, monsterRadius, sExpeditionBattle.mapID, nil )
                        -- 更新部队路径
                        MSM.MapMarchMgr[moveObjectIndex].post.updateExpeditionMovePath( moveObjectIndex, _objectIndex, path )
                    end
                else
                    -- 部队不存在了
                    armyWalkToInfo[_objectIndex][moveObjectIndex] = nil
                end
            end
        end
    end
end

---@see 获取远征对象坐标
function response.getExpeditionPos( _objectIndex )
    if mapExpeditionInfos[_objectIndex] then
        return mapExpeditionInfos[_objectIndex].pos
    end
end

---@see 获取远征对象信息
function response.getExpeditionInfo( _objectIndex )
    return mapExpeditionInfos[_objectIndex]
end

---@see 获取远征地图索引
function response.getExpeditionMapIndex( _objectIndex )
    return mapExpeditionInfos[_objectIndex].mapIndex
end

---@see 同步对象联盟简称
function accept.syncGuildAbbName( _objectIndex, _guildAbbName )
    if mapExpeditionInfos[_objectIndex] then
        mapExpeditionInfos[_objectIndex].guildAbbName = _guildAbbName

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildAbbName = _guildAbbName } )
    end
end

---@see 同步对象军队名称
function accept.syncArmyName( _objectIndex, _name )
    if mapExpeditionInfos[_objectIndex] then
        mapExpeditionInfos[_objectIndex].armyName = _name

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyName = _name } )
    end
end

---@see 添加军队驻扎状态
function accept.addArmyStation( _objectIndex, _newPos )
    if mapExpeditionInfos[_objectIndex] then
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        if _newPos then
            mapExpeditionInfos[_objectIndex].pos = _newPos
        end
        if ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            -- 移除所有的移动状态
            mapExpeditionInfos[_objectIndex].status = ArmyLogic:removeMoveStatus( mapExpeditionInfos[_objectIndex].status )
            -- 添加驻扎
            mapExpeditionInfos[_objectIndex].status = ArmyLogic:addArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.STATIONING )
            -- 同步战斗服务器状态
            BattleAttrLogic:syncObjectStatus( _objectIndex, mapExpeditionInfos[_objectIndex].status )
            -- 通知目标回头攻击目标
            BattleCreate:removeObjectStopAttack( _objectIndex )
        else
            mapExpeditionInfos[_objectIndex].status = Enum.ArmyStatus.STATIONING
            mapExpeditionInfos[_objectIndex].path = {} -- 驻扎,移除路径
            mapExpeditionInfos[_objectIndex].targetObjectIndex = 0
            -- 通过AOI通知
            sceneObject.post.syncObjectInfo( _objectIndex, { path = {} } )
        end
        -- 通知客户端军队状态改变
        --ArmyLogic:updateArmyStatus( mapExpeditionInfos[_objectIndex].rid, mapExpeditionInfos[_objectIndex].armyIndex, mapExpeditionInfos[_objectIndex].status )
        -- 通过AOI通知
        -- 取消追击
        if mapMonsterFollowInfos[_objectIndex] then
            mapMonsterFollowInfos[_objectIndex] = nil
        end

        -- 修正位置
        local pos = MSM.MapMarchMgr[_objectIndex].req.fixObjectPosWithMillisecond( _objectIndex )
        if pos then
            mapExpeditionInfos[_objectIndex].pos = pos
        end
        -- 通过AOI通知
        sceneObject.post.syncObjectInfo( _objectIndex, {
                                                            status = mapExpeditionInfos[_objectIndex].status,
                                                            pos = mapExpeditionInfos[_objectIndex].pos,
                                                            targetObjectIndex = mapExpeditionInfos[_objectIndex].targetObjectIndex
                                                        } )
    end
end


---@see 更新军队状态
function response.updateArmyStatus( _objectIndex, _status, _statusOp )
    if mapExpeditionInfos[_objectIndex] then
        local armyInfo = mapExpeditionInfos[_objectIndex]
        local oldStatus = armyInfo.status
        -- 过滤状态
        armyInfo.status = ArmyLogic:grepObjectStatus( _objectIndex, armyInfo, _status, _statusOp )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( armyInfo.mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = armyInfo.status, pos = armyInfo.pos, targetObjectIndex = armyInfo.targetObjectIndex } )
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 战斗变非战斗,移除buff
            armyInfo.battleBuff = {}
            sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = {} } )
        end
    end
end

---@see 更新怪物士兵信息
function accept.updateSoldier( _objectIndex, _subSoldiers, _sync )
    if mapExpeditionInfos[_objectIndex] then
        local armyCount = mapExpeditionInfos[_objectIndex].armyCount
        for soldierId, soldierInfo in pairs(_subSoldiers) do
            if mapExpeditionInfos[_objectIndex].soldiers[soldierId] then
                mapExpeditionInfos[_objectIndex].soldiers[soldierId].num = mapExpeditionInfos[_objectIndex].soldiers[soldierId].num - soldierInfo.num
                if mapExpeditionInfos[_objectIndex].soldiers[soldierId].num < 0 then
                    mapExpeditionInfos[_objectIndex].soldiers[soldierId].num = 0
                end
            end
        end
        mapExpeditionInfos[_objectIndex].armyCount = ArmyLogic:getArmySoldierCount( mapExpeditionInfos[_objectIndex].soldiers )
        if _sync then
        -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = armyCount, soldiers = mapExpeditionInfos[_objectIndex].soldiers } )
        end
    end
end

---@see 更新军队行军路径
function accept.updateArmyPath( _objectIndex, _path, _arrivalTime, _startTime, _targetObjectIndex, _status, _noSync )
    if mapExpeditionInfos[_objectIndex] then
        -- 更新目标
        mapExpeditionInfos[_objectIndex].targetObjectIndex = _targetObjectIndex or 0
        -- 达到时间
        mapExpeditionInfos[_objectIndex].arrivalTime = _arrivalTime
        mapExpeditionInfos[_objectIndex].startTime = _startTime
        mapExpeditionInfos[_objectIndex].path = _path

        if _status then
            if ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
                _status = ArmyLogic:addArmyStatus( _status, Enum.ArmyStatus.BATTLEING )
                -- 同步战斗服务器状态
                BattleAttrLogic:syncObjectStatus( _objectIndex, _status )
            end
            mapExpeditionInfos[_objectIndex].status = _status
        end

        -- 重新计算军队半径
        local armyRadius = CommonCacle:getArmyRadius( mapExpeditionInfos[_objectIndex].soldiers )
        mapExpeditionInfos[_objectIndex].armyRadius = armyRadius

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = _path, arrivalTime = _arrivalTime, startTime = _startTime,
                                                        armyRadius = armyRadius, status = mapExpeditionInfos[_objectIndex].status } )
        if _targetObjectIndex then
            -- 计算同目标角度
            local pathCount = #_path
            local angle = math.floor( ArmyWalkLogic:cacleAnagle( _path[pathCount-1], _path[pathCount] ) * 100 )
            mapExpeditionInfos[_objectIndex].angle = angle
            sceneObject.post.syncObjectInfo( _objectIndex, { targetObjectIndex = _targetObjectIndex } )
        end
    end
end


---@see 更新军队目标
function accept.updateExpeditionTargetObjectIndex( _objectIndex, _targetObjectIndex, _isFromBattle )
    if mapExpeditionInfos[_objectIndex] then
        _targetObjectIndex = _targetObjectIndex or 0
        if _targetObjectIndex == 0 then
            return
        end
        mapExpeditionInfos[_objectIndex].targetObjectIndex = _targetObjectIndex
        -- 如果在战斗,同步给战斗服务器
        if not _isFromBattle and ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
            if battleIndex then
                local battleNode = BattleCreate:getBattleServerNode( battleIndex )
                Common.rpcMultiSend( battleNode, "BattleLoop", "changeAttackTarget", battleIndex, _objectIndex, _targetObjectIndex )
            end
        end
        -- 计算面向目标角度
        local angle, objectInfo, armyInfo
        if _targetObjectIndex > 0 then
            objectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
            if objectInfo then
                armyInfo = MSM.SceneExpeditionMgr[_targetObjectIndex].req.getExpeditionInfo( _targetObjectIndex )
                if armyInfo then
                    angle = math.floor( ArmyWalkLogic:cacleAnagle( mapExpeditionInfos[_objectIndex].pos, armyInfo.pos ) * 100 )
                end
            end
        end
        mapExpeditionInfos[_objectIndex].angle = angle or 0
        mapExpeditionInfos[_objectIndex].targetObjectType = objectInfo and objectInfo.objectType or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { targetObjectIndex = _targetObjectIndex } )
    end
end

---@see 同步攻击者数量.用于显示夹击
function accept.syncAttackCount( _objectIndex, _attackCount )
    if mapExpeditionInfos[_objectIndex] then
        mapExpeditionInfos[_objectIndex].attackCount = _attackCount
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { attackCount = _attackCount } )
    end
end

---@see 更新军队部队血量
function accept.updateExpeditionCountAndSp( _objectIndex, _armyCount, _sp )
    if mapExpeditionInfos[_objectIndex] then
        mapExpeditionInfos[_objectIndex].armyCount = _armyCount
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 同步对象战斗buff
function accept.syncExpeditionBattleBuff( _objectIndex, _battleBuff )
    if mapExpeditionInfos[_objectIndex] then
        mapExpeditionInfos[_objectIndex].battleBuff = _battleBuff
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end

---@see 部队路径置空
function response.setPathEmpty( _objectIndex )
    if mapExpeditionInfos[_objectIndex] then
        mapExpeditionInfos[_objectIndex].path = {}
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = {} } )
    end
end

---@see 判断部队是否在怪物的警戒方位内
function accept.checkMonsterVigilance( _objectIndex )
    if not mapExpeditionInfos[_objectIndex] then return end

    local objectInfos = SM.ExpeditionMgr.req.getAllObjectInfo( mapExpeditionInfos[_objectIndex].mapIndex )
    local objectIndexs = {}
    for objectIndex in pairs(objectInfos) do
        objectIndexs[objectIndex] = objectIndex
    end
    local armyInfos, monsterInfo = ExpeditionLogic:getAllExpeditionInfo(objectIndexs)

    if mapExpeditionInfos[_objectIndex].monsterId
    and mapExpeditionInfos[_objectIndex].monsterId > 0 then
        local monsterVigilanceRange = CFG.s_Monster:Get(mapExpeditionInfos[_objectIndex].monsterId, "monsterVigilanceRange") * Enum.MapPosMultiple
        local battleFollowDistance = CFG.s_Monster:Get(mapExpeditionInfos[_objectIndex].monsterId, "battleFollowDistance")
        if not MapLogic:checkRadius( mapExpeditionInfos[_objectIndex].pos, mapExpeditionInfos[_objectIndex].initPos, battleFollowDistance ) then
            MSM.SceneExpeditionMgr[_objectIndex].post.backInitPos( _objectIndex )
        end
        if MapLogic:checkRadius( mapExpeditionInfos[_objectIndex].pos, mapExpeditionInfos[_objectIndex].initPos, monsterVigilanceRange ) then
            for _, objectInfo in pairs( armyInfos ) do
                if objectInfo.rid and objectInfo.rid > 0 then
                    -- 判断是否再范围内
                    --local armyRadius = mapExpeditionInfos[_objectIndex].armyRadius
                    local armyRadius = CommonCacle:getArmyRadius( objectInfo.soldiers )
                    local radius = armyRadius + monsterVigilanceRange
                    if MapLogic:checkRadius( objectInfo.pos, mapExpeditionInfos[_objectIndex].pos, radius ) and
                        ( not ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) and
                        not ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.ATTACK_MARCH ) and
                        not ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.SPACE_MARCH ) and
                        not ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.FOLLOWUP ) and
                        not ArmyLogic:checkArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.ARMY_STANBY ) ) then
                        --MSM.SceneExpeditionMgr[objectInfo.objectIndex].post.expeditionFollowUp( objectInfo.objectIndex, _objectIndex, Enum.RoleType.EXPEDITION )
                        -- 向部队行军
                        -- 目标是否还存在
                        local targetArg = {
                            targetObjectIndex = objectInfo.objectIndex,
                        }
                        local targetType = Enum.MapMarchTargetType.ATTACK
                        local targetInfo, checkError = ArmyMarchLogic:checkMarchTargetExist( nil, targetArg, targetType, monsterInfo[_objectIndex] )
                        if not targetInfo and checkError then
                            return nil, checkError
                        end
                        -- 获取目标点坐标、状态
                        local targetPosInfo = ArmyMarchLogic:getTargetPos( nil, targetType, targetArg, targetInfo, {}, monsterInfo[_objectIndex] )
                        if not targetPosInfo.targetPos then
                            return nil, targetPosInfo.armyStatus
                        end
                        -- 处理行军
                        ArmyMarchLogic:dispatchExpeditionMarch( nil, _objectIndex, targetArg, targetType, targetPosInfo.targetPos, targetPosInfo.armyStatus, targetPosInfo.targetObjectIndex )
                        return
                    end
                end
            end
        end
    elseif mapExpeditionInfos[_objectIndex].rid and mapExpeditionInfos[_objectIndex].rid > 0 then
        for _, objectInfo in pairs( monsterInfo ) do
            if objectInfo.monsterId and objectInfo.monsterId > 0 then
                -- 判断是否再范围内
                --local armyRadius = mapExpeditionInfos[_objectIndex].armyRadius
                local armyRadius = CommonCacle:getArmyRadius( mapExpeditionInfos[_objectIndex].soldiers )
                local monsterVigilanceRange = CFG.s_Monster:Get(objectInfo.monsterId, "monsterVigilanceRange")
                local radius = armyRadius + ( monsterVigilanceRange * Enum.MapPosMultiple)
                if MapLogic:checkRadius( objectInfo.pos, mapExpeditionInfos[_objectIndex].pos, radius ) and
                    ( not ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.BATTLEING ) and
                      not ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.ATTACK_MARCH ) and
                      not ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.SPACE_MARCH ) and
                      not ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.FOLLOWUP ) and
                      not ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.ARMY_STANBY )) then
                    --MSM.SceneExpeditionMgr[objectInfo.objectIndex].post.expeditionFollowUp( objectInfo.objectIndex, _objectIndex, Enum.RoleType.EXPEDITION )
                    -- 向部队行军
                    -- 目标是否还存在
                    local targetArg = {
                        targetObjectIndex = _objectIndex,
                    }
                    local targetType = Enum.MapMarchTargetType.ATTACK
                    local targetInfo, checkError = ArmyMarchLogic:checkMarchTargetExist( nil, targetArg, targetType, objectInfo )
                    if not targetInfo and checkError then
                        return nil, checkError
                    end
                    -- 获取目标点坐标、状态
                    local targetPosInfo = ArmyMarchLogic:getTargetPos( nil, targetType, targetArg, targetInfo, {}, objectInfo )
                    if not targetPosInfo.targetPos then
                        return nil, targetPosInfo.armyStatus
                    end
                    -- 处理行军
                    ArmyMarchLogic:dispatchExpeditionMarch( nil, objectInfo.objectIndex, targetArg, targetType,
                        targetPosInfo.targetPos, targetPosInfo.armyStatus, targetPosInfo.targetObjectIndex )
                end
            end
        end
    end
end

---@see 更新野蛮人行军路径
function accept.updateExpeditionPath( _objectIndex, _path, _arrivalTime, _startTime, _targetObjectIndex, _status, _addStatus )
    if mapExpeditionInfos[_objectIndex] then
        local monsterInfo = mapExpeditionInfos[_objectIndex]
        -- 达到时间
        monsterInfo.arrivalTime = _arrivalTime
        monsterInfo.startTime = _startTime
        monsterInfo.path = _path
        if _status then
            monsterInfo.status = _status
        elseif _addStatus then
            monsterInfo.status = ArmyLogic:addArmyStatus( monsterInfo.status, _addStatus )
        end

        if monsterInfo.rid and monsterInfo.rid > 0 then
            -- 重新计算军队半径
            local armyRadius = CommonCacle:getArmyRadius( mapExpeditionInfos[_objectIndex].soldiers )
            mapExpeditionInfos[_objectIndex].armyRadius = armyRadius
        end

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( monsterInfo.mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = _path, arrivalTime = _arrivalTime, startTime = _startTime, status = monsterInfo.status } )
        -- 更新目标
        if _targetObjectIndex then
            monsterInfo.targetObjectIndex = _targetObjectIndex
            -- 计算同目标角度
            local pathCount = #_path
            local angle = math.floor( ArmyWalkLogic:cacleAnagle( _path[pathCount-1], _path[pathCount] ) * 100 )
            monsterInfo.angle = angle
            sceneObject.post.syncObjectInfo( _objectIndex, { targetObjectIndex = _targetObjectIndex } )
        end
    end
end

---@see 怪物追击目标
function accept.expeditionFollowUp( _objectIndex, _followObjectIndex, _followObjectType )
    if mapExpeditionInfos[_objectIndex] then
        mapMonsterFollowInfos[_objectIndex] = {
                                                followObjectIndex = _followObjectIndex,
                                                followObjectType = _followObjectType
                                        }
        -- 怪物添加追击状态
        mapExpeditionInfos[_objectIndex].status = ArmyLogic:addArmyStatus( mapExpeditionInfos[_objectIndex].status, Enum.ArmyStatus.FOLLOWUP )
        -- 同步状态
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapExpeditionInfos[_objectIndex].status, pos = mapExpeditionInfos[_objectIndex].pos } )
    end
end

---@see 停止追击
function response.stopFollowUp( _objectIndex )
    if mapExpeditionInfos[_objectIndex] and mapMonsterFollowInfos[_objectIndex] then
        mapMonsterFollowInfos[_objectIndex] = nil
        -- 停止移动
        MSM.MapMarchMgr[_objectIndex].req.stopObjectMove( _objectIndex )
        -- 移除追击状态
        local status = mapExpeditionInfos[_objectIndex].status
        mapExpeditionInfos[_objectIndex].status = ArmyLogic:delArmyStatus( status, Enum.ArmyStatus.FOLLOWUP )
        -- 同步状态
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapExpeditionInfos[_objectIndex].status, pos = mapExpeditionInfos[_objectIndex].pos } )
    end
end


---@see 增加军队向怪物行军
function accept.addArmyWalkToExpedition( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapExpeditionInfos[_objectIndex] then
        if not armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex] = {}
        end
        armyWalkToInfo[_objectIndex][_armyObjectIndex] = { marchType = _marchType, arrivalTime = _arrivalTime }
        local armyInfo = MSM.SceneExpeditionMgr[_armyObjectIndex].req.getExpeditionInfo( _armyObjectIndex)
        local armyMarchInfo = ArmyDef:getDefaultArmyMarchInfo()
        armyMarchInfo.objectIndex = _armyObjectIndex
        armyMarchInfo.rid = armyInfo.rid
        armyMarchInfo.path = _path
        armyMarchInfo.guildId = armyInfo.guildId
        mapExpeditionInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除军队向怪物行军
function accept.delArmyWalkToExpedition( _objectIndex, _armyObjectIndex )
    if mapExpeditionInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapExpeditionInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( mapExpeditionInfos[_objectIndex].mapIndex )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
        end
    end
end

---@see 获取军队状态
function response.getExpeditionStatus( _objectIndex )
    if mapExpeditionInfos[_objectIndex] then
        return mapExpeditionInfos[_objectIndex].status
    end
end