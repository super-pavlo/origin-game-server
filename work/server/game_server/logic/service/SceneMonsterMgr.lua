--[[
* @file : SceneMonsterMgr.lua
* @type : snax multi service
* @author : linfeng
* @created : Thu May 03 2018 11:29:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图怪物管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local MonsterPartolLogic = require "MonsterPartolLogic"
local MonsterLogic = require "MonsterLogic"
local Timer = require "Timer"
local Random = require "Random"
local ArmyWalkLogic = require "ArmyWalkLogic"
local MonsterFollowUpLogic = require "MonsterFollowUpLogic"
local HeroLogic = require "HeroLogic"
local ArmyLogic = require "ArmyLogic"
local ArmyDef = require "ArmyDef"
local BattleCreate = require "BattleCreate"
local RoleLogic = require "RoleLogic"

---@see 地图怪物信息
---@class defaultMapMonsterInfoClass
local defaultMapMonsterInfo = {
    initPos                     =                   {},             -- 怪物初始坐标
    pos                         =                   {},             -- 怪物坐标
    next                        =                   {},             -- 怪物巡逻下一个坐标
    speed                       =                   {},             -- 移动速度
    monsterId                   =                   0,              -- 怪物ID
    refreshTime                 =                   0,              -- 刷新时间
    status                      =                   0,              -- 怪物状态(Enum.ArmyStatus)
    armyCount                   =                   0,              -- 部队数量
    armyCountMax                =                   0,              -- 部队数量上限
    soldiers                    =                   0,              -- 部队士兵
    targetObjectIndex           =                   0,              -- 对象目标索引
    nextPartolTime              =                   0,              -- 下次巡逻时间
    mainHeroId                  =                   0,              -- 主将ID
    deputyHeroId                =                   0,              -- 副将ID
    angle                       =                   0,              -- 目标角度
    arrivalTime                 =                   0,              -- 怪物达到时间
    startTime                   =                   0,              -- 怪物出发时间
    path                        =                   {},             -- 移动路径
    attackCount                 =                   0,              -- 攻击方数量
    followUpDistance            =                   0,              -- 追击范围
    skills                      =                   {},             -- 技能
    battleBuff                  =                   {},             -- 战斗buff
    sp                          =                   0,              -- 怒气
    maxSp                       =                   0,              -- 最大怒气
    armyRadius                  =                   0,              -- 野蛮人半径
    isGuardHolyLand             =                   false,          -- 是否是圣地守护者
    mainHeroSkills              =                   {},             -- 怪物主将技能
    deputyHeroSkills            =                   {},             -- 怪物副将技能
    movePath                    =                   {},             -- 野蛮人巡逻移动路径
    moveSpeed                   =                   {},             -- 野蛮人巡逻速度
    holyLandId                  =                   0,              -- 圣地ID
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    holyLandMonsterId           =                   0,              -- 圣地守护者怪物ID
    staticId                    =                   0,              -- 静态对象ID
    objectAttr                  =                   {},             -- 怪物属性
    roleWatchRef                =                   0,              -- 角色关注数量
    objectType                  =                   0,              -- 怪物类型
}

---@type table<int, defaultMapMonsterInfoClass>
local mapMonsterInfos = {}
---@type table<int, table>
local armyWalkToInfo = {}
---@type table<int, int>
local monsterLastUpdatePos = {}
---@type table<int, int>
local mapMonsterFollowInfos = {}

function init()
    -- 每秒处理巡逻
    Timer.runEvery( 100, MonsterPartolLogic.dispatchMonsterPartol, MonsterPartolLogic, mapMonsterInfos )
    -- 每秒处理巡逻移动
    Timer.runEvery( 100, MonsterPartolLogic.updateMonsterPartolPos, MonsterPartolLogic, mapMonsterInfos, monsterLastUpdatePos, armyWalkToInfo )
    -- 每秒检测下追击
    Timer.runEvery( 100, MonsterFollowUpLogic.dispatchMonsterFollowUp, MonsterFollowUpLogic, mapMonsterFollowInfos, mapMonsterInfos )
end

---@see 增加怪物对象
function response.addMonsterObject( _objectIndex, _monsterInfo, _pos )
    -- 初始化怪物战斗阵容
    local monsterId = _monsterInfo.monsterId
    local armyCount, soldiers = MonsterLogic:cacleMonsterArmyCount( monsterId )
    _pos.x = math.floor( _pos.x )
    _pos.y = math.floor( _pos.y )
    local sMonsterInfo = CFG.s_Monster:Get(monsterId)
    local cdMin = math.floor( sMonsterInfo.patrolTimeCD / 1000 )
    local cdMax = math.floor( sMonsterInfo.patrolTimeCdMax / 1000 )
    local skills, mainHeroSkills, deputyHeroSkills, monsterMainHeroId, monsterDeputyHeroId = HeroLogic:getMonsterAllHeroSkills( monsterId )

    -- 初始化怪物结构
    ---@type defaultMapMonsterInfoClass
    local initMapMonsterInfo = const( table.copy( defaultMapMonsterInfo ) )
    initMapMonsterInfo.initPos = _pos
    initMapMonsterInfo.pos = _pos
    initMapMonsterInfo.monsterId = monsterId
    initMapMonsterInfo.refreshTime = _monsterInfo.refreshTime
    initMapMonsterInfo.status = Enum.ArmyStatus.ARMY_STANBY
    initMapMonsterInfo.soldiers = soldiers
    initMapMonsterInfo.armyCount = armyCount
    initMapMonsterInfo.armyCountMax = armyCount
    initMapMonsterInfo.targetObjectIndex = 0
    initMapMonsterInfo.speed = sMonsterInfo.patrolSpeed
    initMapMonsterInfo.nextPartolTime = os.time() + Random.Get(cdMin, cdMax)
    initMapMonsterInfo.mainHeroId = monsterMainHeroId
    initMapMonsterInfo.deputyHeroId = monsterDeputyHeroId
    initMapMonsterInfo.angle = 0
    initMapMonsterInfo.followUpDistance = sMonsterInfo.battleFollowDistance
    initMapMonsterInfo.skills = skills
    initMapMonsterInfo.mainHeroSkills = mainHeroSkills
    initMapMonsterInfo.deputyHeroSkills = deputyHeroSkills
    initMapMonsterInfo.sp = 0
    initMapMonsterInfo.maxSp = ArmyLogic:cacleArmyMaxSp( skills )
    initMapMonsterInfo.armyRadius = CFG.s_Monster:Get( monsterId, "radius" ) * Enum.MapPosMultiple
    initMapMonsterInfo.holyLandId = _monsterInfo.holyLandId
    initMapMonsterInfo.isGuardHolyLand = ( _monsterInfo.holyLandId ~= nil )
    initMapMonsterInfo.holyLandMonsterId = monsterId
    initMapMonsterInfo.staticId = monsterId
    initMapMonsterInfo.objectAttr = MonsterLogic:getMonsterAttr( monsterId )
    initMapMonsterInfo.objectType = _monsterInfo.objectType or 0

    mapMonsterInfos[_objectIndex] = initMapMonsterInfo
end

---@see 删除怪物对象
function accept.deleteMonsterObject( _objectIndex )
    if armyWalkToInfo[_objectIndex] then
        local mapArmyInfo, armyStatus
        -- 向该目标行军的部队驻扎原地
        for armyObjectIndex in pairs( armyWalkToInfo[_objectIndex] ) do
            mapArmyInfo = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyInfo( armyObjectIndex )
            if mapArmyInfo then
                armyStatus = ArmyLogic:getArmy( mapArmyInfo.rid, mapArmyInfo.armyIndex, Enum.Army.status )
                if armyStatus and ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.ATTACK_MARCH ) then
                    -- 如果有勾选驻扎
                    local situStation = RoleLogic:getRole( mapArmyInfo.rid, Enum.Role.situStation )
                    if situStation then
                        MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, nil, nil, nil, Enum.MapMarchTargetType.STATION )
                    else
                        -- 回城
                        MSM.MapMarchMgr[armyObjectIndex].req.marchBackCity( mapArmyInfo.rid, armyObjectIndex )
                    end
                end
            end
        end
    end
    mapMonsterInfos[_objectIndex] = nil
    mapMonsterFollowInfos[_objectIndex] = nil
    monsterLastUpdatePos[_objectIndex] = nil
    armyWalkToInfo[_objectIndex] = nil

    MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
end

---@see 更新怪物士兵信息
function accept.updateMonsterSoldier( _objectIndex, _subSoldiers )
    if mapMonsterInfos[_objectIndex] then
        for soldierId, soldierInfo in pairs(_subSoldiers) do
            if mapMonsterInfos[_objectIndex].soldiers[soldierId] then
                mapMonsterInfos[_objectIndex].soldiers[soldierId].num = mapMonsterInfos[_objectIndex].soldiers[soldierId].num - soldierInfo.num
                if mapMonsterInfos[_objectIndex].soldiers[soldierId].num < 0 then
                    mapMonsterInfos[_objectIndex].soldiers[soldierId].num = 0
                end
            end
        end
    end
end

---@see 更新怪物坐标
function accept.updateMonsterPos( _objectIndex, _pos )
    if mapMonsterInfos[_objectIndex] then
        _pos.x = math.floor( _pos.x )
        _pos.y = math.floor( _pos.y )
        mapMonsterInfos[_objectIndex].pos = _pos
        -- 如果处于战斗,更新坐标
        if ArmyLogic:checkArmyStatus( mapMonsterInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
            if battleIndex then
                -- 通知对象更新坐标
                local battleNode = BattleCreate:getBattleServerNode( battleIndex )
                Common.rpcMultiSend( battleNode, "BattleLoop", "updateObjectPos", battleIndex, _objectIndex, _pos, 0 )
            end
        end

        -- 坐标更新处理
        MonsterPartolLogic:updateMonsterPosImpl( _objectIndex, _pos, mapMonsterInfos[_objectIndex], monsterLastUpdatePos, armyWalkToInfo )
    end
end

---@see 获取怪物坐标
function response.getMonsterPos( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        return mapMonsterInfos[_objectIndex].pos
    end
end

---@see 获取怪物状态
function response.getMonsterStatus( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        return mapMonsterInfos[_objectIndex].status
    end
end

---@see 获取怪物信息
function response.getMonsterInfo( _objectIndex, _isAddRef )
    if mapMonsterInfos[_objectIndex] then
        if _isAddRef then
            mapMonsterInfos[_objectIndex].roleWatchRef = mapMonsterInfos[_objectIndex].roleWatchRef + 1
        end
        return mapMonsterInfos[_objectIndex]
    end
end

---@see 角色关注减一
function accept.subRoleWaterRef( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        if mapMonsterInfos[_objectIndex].roleWatchRef > 0 then
            mapMonsterInfos[_objectIndex].roleWatchRef = mapMonsterInfos[_objectIndex].roleWatchRef - 1
        end
    end
end

---@see 同步怪物路径给客户端
function accept.syncMonsterPos( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        local status = ArmyLogic:addArmyStatus( mapMonsterInfos[_objectIndex].status, Enum.ArmyStatus.MOVE )
        mapMonsterInfos[_objectIndex].status = status
        local path = { mapMonsterInfos[_objectIndex].pos, mapMonsterInfos[_objectIndex].pos }
        sceneObject.post.syncObjectInfo( _objectIndex, { path = path, status = status } )
    end
end

---@see 更新野蛮人行军路径
function accept.updateMonsterPath( _objectIndex, _path, _arrivalTime, _startTime, _targetObjectIndex, _status, _addStatus )
    if mapMonsterInfos[_objectIndex] then
        local monsterInfo = mapMonsterInfos[_objectIndex]
        -- 达到时间
        monsterInfo.arrivalTime = _arrivalTime
        monsterInfo.startTime = _startTime
        monsterInfo.path = _path

        if _addStatus then
            monsterInfo.status = ArmyLogic:addArmyStatus( monsterInfo.status, _status )
        elseif _status then
            monsterInfo.status = _status
        end
        -- 如果处于战斗状态,移除巡逻
        if ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.BATTLEING ) then
            monsterInfo.status = ArmyLogic:delArmyStatus( monsterInfo.status, Enum.ArmyStatus.PATROL )
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
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

---@see 更新怪物状态
function response.updateMonsterStatus( _objectIndex, _status, _statusOp )
    if mapMonsterInfos[_objectIndex] then
        local oldStatus = mapMonsterInfos[_objectIndex].status
        -- 状态更新
        mapMonsterInfos[_objectIndex].status = ArmyLogic:grepObjectStatus( _objectIndex, mapMonsterInfos[_objectIndex], _status, _statusOp )

        local newStatus = mapMonsterInfos[_objectIndex].status

        local battleBuff
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( newStatus, Enum.ArmyStatus.BATTLEING ) then
            -- 战斗变非战斗,移除buff
            if mapMonsterInfos[_objectIndex] then
                mapMonsterInfos[_objectIndex].battleBuff = {}
                battleBuff = {}
            end

            -- 重新计算巡逻时间
            local sMonsterInfo = CFG.s_Monster:Get(mapMonsterInfos[_objectIndex].monsterId)
            local cdMin = math.floor( sMonsterInfo.patrolTimeCD / 1000 )
            local cdMax = math.floor( sMonsterInfo.patrolTimeCdMax / 1000 )
            mapMonsterInfos[_objectIndex].nextPartolTime = os.time() + Random.Get(cdMin, cdMax)
        end

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = newStatus, battleBuff = battleBuff,
        targetObjectIndex = mapMonsterInfos[_objectIndex].targetObjectIndex, pos = mapMonsterInfos[_objectIndex].pos } )
    end
end

---@see 怪物部队数量重置
function response.resetMonsterCount( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        local monsterId = mapMonsterInfos[_objectIndex].monsterId
        if MonsterLogic:checkRecoverArmyCount( monsterId ) then
            local armyCount, soldiers = MonsterLogic:cacleMonsterArmyCount( monsterId )
            mapMonsterInfos[_objectIndex].armyCount = armyCount
            mapMonsterInfos[_objectIndex].soldiers = soldiers
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = armyCount, sp = 0 } )
        end
    end
end

---@see 更新怪物部队数量
function accept.updateMonsterCountAndSp( _objectIndex, _armyCount, _sp )
    if mapMonsterInfos[_objectIndex] then
        mapMonsterInfos[_objectIndex].armyCount = _armyCount
        mapMonsterInfos[_objectIndex].sp = _sp
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 更新怪物目标
function accept.updateMonsterTargetObjectIndex( _objectIndex, _targetObjectIndex )
    if mapMonsterInfos[_objectIndex] then
        mapMonsterInfos[_objectIndex].targetObjectIndex = _targetObjectIndex
        -- 计算面向目标角度
        local angle
        local objectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
        if objectInfo and objectInfo.objectType == Enum.RoleType.ARMY then
            local armyrInfo = MSM.SceneArmyMgr[_targetObjectIndex].req.getArmyInfo( _targetObjectIndex )
            if armyrInfo then
                angle = math.floor( ArmyWalkLogic:cacleAnagle( mapMonsterInfos[_objectIndex].pos, armyrInfo.pos ) * 100 )
                mapMonsterInfos[_objectIndex].angle = angle
            end
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { targetObjectIndex = _targetObjectIndex } )
    end
end

---@see 同步攻击者数量.用于显示夹击
function accept.syncAttackCount( _objectIndex, _attackCount )
    if mapMonsterInfos[_objectIndex] then
        mapMonsterInfos[_objectIndex].attackCount = _attackCount
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { attackCount = _attackCount } )
    end
end

---@see 增加军队向怪物行军
function accept.addArmyWalkToMonster( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapMonsterInfos[_objectIndex] then
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
        mapMonsterInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除军队向怪物行军
function accept.delArmyWalkToMonster( _objectIndex, _armyObjectIndex )
    if mapMonsterInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapMonsterInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
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
    if mapMonsterInfos[_objectIndex] and mapMonsterInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapMonsterInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapMonsterInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end

---@see 怪物追击目标
function accept.monsterFollowUp( _objectIndex, _followObjectIndex, _followObjectType )
    if mapMonsterInfos[_objectIndex] then
        mapMonsterFollowInfos[_objectIndex] = {
                                                followObjectIndex = _followObjectIndex,
                                                followObjectType = _followObjectType
                                        }
        -- 怪物添加追击状态
        mapMonsterInfos[_objectIndex].status = ArmyLogic:addArmyStatus( mapMonsterInfos[_objectIndex].status, Enum.ArmyStatus.FOLLOWUP )
        -- 同步状态
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapMonsterInfos[_objectIndex].status, pos = mapMonsterInfos[_objectIndex].pos } )
    end
end

---@see 停止追击
function response.stopFollowUp( _objectIndex )
    if mapMonsterInfos[_objectIndex] and mapMonsterFollowInfos[_objectIndex] then
        mapMonsterFollowInfos[_objectIndex] = nil
        -- 停止移动
        MSM.MapMarchMgr[_objectIndex].req.stopObjectMove( _objectIndex )
        -- 移除追击状态
        local status = mapMonsterInfos[_objectIndex].status
        mapMonsterInfos[_objectIndex].status = ArmyLogic:delArmyStatus( status, Enum.ArmyStatus.FOLLOWUP )
        -- 同步状态
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapMonsterInfos[_objectIndex].status, pos = mapMonsterInfos[_objectIndex].pos } )
    end
end

---@see 同步对象战斗buff
function accept.syncMonsterBattleBuff( _objectIndex, _battleBuff )
    if mapMonsterInfos[_objectIndex] then
        mapMonsterInfos[_objectIndex].battleBuff = _battleBuff
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end

---@see 增加移动状态
function accept.addMoveStatus( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        mapMonsterInfos[_objectIndex].status = ArmyLogic:addArmyStatus( mapMonsterInfos[_objectIndex].status, Enum.ArmyStatus.MOVE )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        print("怪物状态->", mapMonsterInfos[_objectIndex].status)
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapMonsterInfos[_objectIndex].status, pos = mapMonsterInfos[_objectIndex].pos } )
    end
end

---@see 移除移动状态
function accept.delMoveStatus( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        mapMonsterInfos[_objectIndex].status = ArmyLogic:delArmyStatus( mapMonsterInfos[_objectIndex].status, Enum.ArmyStatus.MOVE )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        print("怪物状态->", mapMonsterInfos[_objectIndex].status)
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapMonsterInfos[_objectIndex].status, pos = mapMonsterInfos[_objectIndex].pos } )
    end
end

---@see 获取怪物初始坐标
function response.getMonsterInitPos( _objectIndex )
    if mapMonsterInfos[_objectIndex] then
        return mapMonsterInfos[_objectIndex].initPos
    end
end