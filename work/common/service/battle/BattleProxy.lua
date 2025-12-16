--[[
* @file : BattleProxy.lua
* @type : snax single service
* @author : linfeng
* @created : Wed Nov 22 2017 11:12:08 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 战斗代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local sprotoloader = require "sprotoloader"
local crypt = require "skynet.crypt"
local socketdriver = require "skynet.socketdriver"
local BattleCallback = require "BattleCallback"
local MapObjectLogic = require "MapObjectLogic"
local BattleCreate = require "BattleCreate"
local ArmyWalkLogic = require "ArmyWalkLogic"
local ArmyLogic = require "ArmyLogic"
local RoleLogic = require "RoleLogic"
local queue = require "skynet.queue"
local CommonCacle = require "CommonCacle"

local syncLock = {}

---@see 消息推送函数
local _S2C_Push

function init(index)
    snax.enablecluster()
    cluster.register(SERVICE_NAME .. index)

    local _C2S_Request = sprotoloader.load(Enum.SPROTO_SLOT.RPC):host "package"
    _S2C_Push = _C2S_Request:attach(sprotoloader.load(Enum.SPROTO_SLOT.RPC))
end

function response.Init()
    -- body
end

---@see 消息打包
local function msgPack( name, tb )
	local ret, error = pcall(_S2C_Push, name, tb)
	if not ret then
		LOG_ERROR("SceneMgr msgPack name(%s) error:%s", name, error)
	else
		return error
	end
end

---@see 推送到客户端
local function pushToClient( _fd, _secret, _msgName, _msgValue )
    if _fd > 0 then
        local msg = msgPack( _msgName, _msgValue )
        if not msg then
            LOG_ERROR("pushToClient error, name(%s) value(%s)", _msgName, tostring(_msgValue))
            return
        end
        local pushMsg = { content = { { networkMessage = msg } } }
        -- push to client now
        local pushClientMsg = crypt.desencode( _secret, msgPack( "GateMessage", pushMsg ) )
        pushClientMsg = string.pack( ">s2", pushClientMsg .. string.pack(">I4", 1, 0) .. string.pack(">B", 0) )
        socketdriver.send( _fd, pushClientMsg )
        --[[
        pushClientMsg, allPackSize = Common.SplitPackage(pushClientMsg)
        for msgIndex, subMsg in pairs(pushClientMsg) do
            msg = string.pack(">s2", msg .. string.pack(">B", msgIndex) .. string.pack(">B", allPackSize))
            socketdriver.send( sceneRoleFd[_watcherId].fd, subMsg )
        end
        ]]
    end
end

---@see 发送战斗伤害信息
---@param _battleIndex integer
---@param _battleDamageInfos table<integer,battleDamageClass>
function response.brocastBattleDamage( _battleIndex, _battleDamageInfos, _notifyObjectType, _notifyObjectIndex )
    local rids
    if _notifyObjectType == Enum.RoleType.ARMY then
        -- 获取军队、野蛮人、野蛮人城寨对象范围内的角色
        local monsterSceneMgrObj = Common.getSceneMgr(Enum.MapLevel.ARMY)
        rids = monsterSceneMgrObj.req.getRidsByObjectIndex( _notifyObjectIndex )
    elseif _notifyObjectType == Enum.RoleType.EXPEDITION then
        -- 远征对象九  零 一  起 玩 w w w . 9 0  1 7 5 . co m
        local objectInfo = MSM.SceneExpeditionMgr[_notifyObjectIndex].req.getExpeditionInfo(_notifyObjectIndex)
        if objectInfo then
            local expeditionSceneMgrObj = Common.getSceneMgr(objectInfo.mapIndex)
            rids = expeditionSceneMgrObj.req.getRidsByObjectIndex( _notifyObjectIndex )
        end
    end


    if not table.empty( rids ) then
        for _, roleInfo in pairs(rids) do
            pushToClient( roleInfo.fd, roleInfo.secret, "Battle_BattleDamageInfo", { battleDamageInfo = _battleDamageInfos } )
        end
    end
end

---@see 同步对象目标改变.战斗中
function accept.syncObjectTargetObjectIndex( _objectIndex, _objectType, _targetObjectIndex, _targetObjectType )
    if _objectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_objectIndex].post.updateArmyTargetObjectIndex( _objectIndex, _targetObjectIndex, true )
        -- 添加到目标站位中
        if _targetObjectIndex and _targetObjectIndex > 0 then
            BattleCreate:addToAttackAroundPos( _objectIndex, _objectIndex, _targetObjectIndex, _targetObjectType )
        end
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterTargetObjectIndex( _objectIndex, _targetObjectIndex )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        MSM.SceneExpeditionMgr[_objectIndex].post.updateExpeditionTargetObjectIndex( _objectIndex, _targetObjectIndex, true )
    end

    -- 重新调整周围攻击者的站位
    MSM.AttackAroundPosMgr[_objectIndex].post.recacleAroundPos( _objectIndex )
end

---@see 同步对象剩余部队血量和怒气
function response.syncObjectArmyCountAndSp( _objectIndex, _objectType, _objectRid, _armyCount, _soldierHurt, _sp, _rallySoldierHurt, _isRally )
    if not syncLock[_objectIndex] then
        syncLock[_objectIndex] = { lock = queue() }
    end

    -- 同步血量和SP
    if _objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.SceneArmyMgr[_objectIndex].post.updateArmyCountAndSp( _objectIndex, _armyCount, _sp )
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 怪物
        MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterCountAndSp( _objectIndex, _armyCount, _sp )
    elseif _objectType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城寨
        MSM.SceneMonsterCityMgr[_objectIndex].post.updateMonsterCityCountAndSp( _objectIndex, _armyCount, _sp )
    elseif _objectType == Enum.RoleType.CITY then
        -- 城市
        MSM.SceneCityMgr[_objectIndex].post.updateCityCountAndSp( _objectIndex, _armyCount, _sp )
    elseif MapObjectLogic:checkIsResourceObject( _objectType ) then
        -- 资源点
        MSM.SceneResourceMgr[_objectIndex].post.updateResourceCountAndSp( _objectIndex, _armyCount, _sp )
    elseif MapObjectLogic:checkIsGuildBuildObject( _objectType ) then
        -- 联盟建筑
        MSM.SceneGuildBuildMgr[_objectIndex].post.updateGuildBuildCountAndSp( _objectIndex, _armyCount, _sp )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.SceneExpeditionMgr[_objectIndex].post.updateExpeditionCountAndSp( _objectIndex, _armyCount, _sp )
    elseif MapObjectLogic:checkIsHolyLandObject( _objectType ) then
        -- 圣地建筑
        MSM.SceneHolyLandMgr[_objectIndex].post.updateHolyLandCountAndSp( _objectIndex, _armyCount, _sp )
    end

    -- 二者都为nil,说明是治疗技能触发的,不计算伤兵
    if _soldierHurt or _rallySoldierHurt then
        return syncLock[_objectIndex].lock( function ()
            return BattleCallback:dispatchSoldier( _objectRid, _objectType, _objectIndex, _soldierHurt, _rallySoldierHurt, _isRally )
        end)
    end
end

---@see 同步部队治疗.发生在城市防守方以及对盟友治疗时
function accept.syncBattleHeal( _objectIndex, _rid, _objectType, _healSoldiers, _rallySoldierHeal, _armyIndex, _isRally )
    -- 处理轻伤治疗
    BattleCallback:dispatchHealSoldier( _objectIndex, _rid, _objectType, _healSoldiers, _rallySoldierHeal, _armyIndex, _isRally )
end

---@see 对象退出战斗
---@param _exitArg defaultExitBattleArgClass
function accept.notifyObjectExitBattle( _, _exitArg )
    if not syncLock[_exitArg.objectIndex] then
        syncLock[_exitArg.objectIndex] = { lock = queue() }
    end

    syncLock[_exitArg.objectIndex].lock( function ()
        BattleCallback:dispatchObjectExitBattle( _exitArg )
    end )

    if syncLock[_exitArg.objectIndex] then
        syncLock[_exitArg.objectIndex] = nil
    end
end

---@see 对象退出战斗
---@param _exitArg defaultExitBattleArgClass
function response.notifyObjectExitBattle( _, _exitArg )
    if not syncLock[_exitArg.objectIndex] then
        syncLock[_exitArg.objectIndex] = { lock = queue() }
    end

    syncLock[_exitArg.objectIndex].lock( function ()
        BattleCallback:dispatchObjectExitBattle( _exitArg )
    end )

    if syncLock[_exitArg.objectIndex] then
        syncLock[_exitArg.objectIndex] = nil
    end
end

---@see 对象退出战斗并解散.发生在关闭服务器时
---@param _exitArg defaultExitBattleArgClass
function response.notifyObjectExitBattleAndBack( _, _exitArg )
    if not syncLock[_exitArg.objectIndex] then
        syncLock[_exitArg.objectIndex] = { lock = queue() }
    end

    syncLock[_exitArg.objectIndex].lock( function ()
        _exitArg.disband = true
        BattleCallback:dispatchObjectExitBattle( _exitArg )
    end )

    if syncLock[_exitArg.objectIndex] then
        syncLock[_exitArg.objectIndex] = nil
    end
end

---@see 更新对象攻击数量.用于夹击
function accept.syncObjectBeAttackCount( _objectIndex, _objectType, _attackCout )
    if _objectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_objectIndex].post.syncAttackCount( _objectIndex, _attackCout )
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        MSM.SceneMonsterMgr[_objectIndex].post.syncAttackCount( _objectIndex, _attackCout )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        MSM.SceneExpeditionMgr[_objectIndex].post.syncAttackCount( _objectIndex, _attackCout )
    end
end

---@see 通知对象开始追击
function accept.notifyBeginFollowUp( _objectIndex, _objectType, _followObjectIndexs )
    for followObjectIndex, followObjectType in pairs(_followObjectIndexs) do
        ArmyWalkLogic:notifyBeginFollowUp( followObjectIndex, followObjectType, _objectIndex, _objectType )
    end
end

---@see 通知对象停止追击
function accept.notifyEndFollowUp( _objectIndex, _objectType )
    ArmyWalkLogic:notifyEndFollowUp( _objectIndex, _objectType )
end

---@see 同步对象战斗buff
function accept.syncObjectBattleBuff( _objectIndex, _objectType, _battleBuff )
    if _objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.SceneArmyMgr[_objectIndex].post.syncArmyBattleBuff( _objectIndex, _battleBuff )
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 野蛮人、圣地守护者、召唤怪物
        MSM.SceneMonsterMgr[_objectIndex].post.syncMonsterBattleBuff( _objectIndex, _battleBuff )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.SceneExpeditionMgr[_objectIndex].post.syncExpeditionBattleBuff( _objectIndex, _battleBuff )
    elseif _objectType == Enum.RoleType.CITY then
        -- 城市
        MSM.SceneCityMgr[_objectIndex].post.syncCityBattleBuff( _objectIndex, _battleBuff )
    elseif _objectType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城寨
        MSM.SceneMonsterCityMgr[_objectIndex].post.syncMonsterCityBattleBuff( _objectIndex, _battleBuff )
    elseif MapObjectLogic:checkIsResourceObject( _objectType ) then
        -- 资源点
        MSM.SceneResourceMgr[_objectIndex].post.syncResourceBattleBuff( _objectIndex, _battleBuff )
    elseif MapObjectLogic:checkIsGuildBuildObject( _objectType ) then
        -- 联盟建筑
        MSM.SceneGuildBuildMgr[_objectIndex].post.syncGuildBuildBattleBuff( _objectIndex, _battleBuff )
    elseif MapObjectLogic:checkIsHolyLandObject( _objectType ) then
        -- 圣地
        MSM.SceneHolyLandMgr[_objectIndex].post.syncHolyLandBattleBuff( _objectIndex, _battleBuff )
    end
end

---@see 获取目标扇形区域内的目标
function response.getObjectIndexsInRange( _objectIndex, _objectType, _objectPos, _radius,
                                        _angle, _topAngle, _bottomAngle, _targetObjectIndexs )
    local allObjectInfos = {}
    if _objectType == Enum.RoleType.ARMY then
        allObjectInfos = Common.getSceneMgr( Enum.MapLevel.ARMY ).req.getMapObjectAreaRangeObjects( _objectIndex )
        if not allObjectInfos then
            return {}
        end
    end

    local retAllObjectInfos = {}
    local targetObjectInfo
    for targetObjectIndex, targetInfo in pairs(allObjectInfos) do
        repeat
            local distance = math.sqrt( (_objectPos.x - targetInfo.pos.x ) ^ 2 + ( _objectPos.y - targetInfo.pos.y ) ^ 2 )
            -- 获取目标的部队信息
            targetObjectInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
            if not targetObjectInfo then
                break
            end

            -- 溃败的部队过滤掉
            if ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.FAILED_MARCH )
            or ArmyLogic:getArmySoldierCount( targetObjectInfo.soldiers or {} ) <= 0 then
                break
            end

            -- 要扣除对方半径
            local soldiers = {}
            if targetObjectInfo.objectType == Enum.RoleType.ARMY then
                soldiers = ArmyLogic:getArmySoldiersFromObject( targetObjectInfo )
            elseif targetObjectInfo.objectType == Enum.RoleType.MONSTER or targetObjectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
                or targetObjectInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
                soldiers = targetObjectInfo.soldiers
            end

            distance = distance - CommonCacle:getArmyRadius( soldiers, targetObjectInfo.isRally )

            -- 是否在半径内
            if distance > _radius then
                break
            end

            -- 区域圆内,判断与底边夹角
            local angleDiff = ArmyWalkLogic:transAngle( ArmyWalkLogic:cacleAnagle( _objectPos, targetInfo.pos ) )
            if angleDiff >= _topAngle and angleDiff <= _bottomAngle then
                -- 在扇形区域中
                if not table.exist( _targetObjectIndexs, targetObjectIndex) then
                    if not ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.BATTLEING ) then
                        -- 过滤已经选中的
                        table.insert( retAllObjectInfos, {
                                                            objectIndex = targetObjectIndex,
                                                            objectType = targetInfo.objectType,
                                                            armyIndex = targetObjectInfo.armyIndex or 0,
                                                            guildId = targetObjectInfo.guildId,
                                                            soldiers = soldiers,
                                                            rid = targetObjectInfo.rid or 0,
                                                            pos = targetInfo.pos,
                                                            armyRadius = targetObjectInfo.armyRadius or 0,
                                                            isRally = targetObjectInfo.isRally or false
                                                        }
                                    )
                    end
                end
            end
        until true
    end

    return retAllObjectInfos
end

---@see 通知对象进入战斗
function response.notifyObjectEnterBattle( _battleIndex, _objectIndex, _objectType, _attackIndex, _inAttackRange )
    -- 如果对象已经在战斗中,不处理
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    if ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.BATTLEING ) then
        return
    end

    if _objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.SceneArmyMgr[_objectIndex].req.updateArmyStatus( _objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.ADD )
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        -- 野蛮人和圣地守护者、召唤怪物
        MSM.SceneMonsterMgr[_objectIndex].req.updateMonsterStatus( _objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.ADD )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.SceneExpeditionMgr[_objectIndex].req.updateArmyStatus( _objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.ADD )
    end

    if _inAttackRange then
        -- 对象加入战斗
        BattleCreate:joinBattle( _objectIndex, _attackIndex )
    else
        -- 添加battleIndex
        local objectInfos = {
            { objectIndex = _objectIndex, objectType = _objectType }
        }
        local battleNode = BattleCreate:getBattleServerNode( _battleIndex )
        SM.BattleIndexReg.req.addObjectBattleIndex( objectInfos, _battleIndex, battleNode, true )
    end
end

---@see 通知对象退出战斗
function accept.notifyObjectLeaveBattle( _objectIndex, _objectType )
    if _objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.SceneArmyMgr[_objectIndex].req.updateArmyStatus( _objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        -- 野蛮人和圣地守护者、召唤怪物
        MSM.SceneMonsterMgr[_objectIndex].req.updateMonsterStatus( _objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        MSM.SceneExpeditionMgr[_objectIndex].req.updateArmyStatus( _objectIndex, Enum.ArmyStatus.BATTLEING, Enum.ArmyStatusOp.DEL )
    end
end

---@see 获取城市可掠夺量
function response.getCitPlunderResource( _rid )
    return RoleLogic:getRole( _rid, {
        Enum.Role.level, Enum.Role.food, Enum.Role.wood, Enum.Role.stone, Enum.Role.gold
    } )
end

---@see 给目标发送战报
---@param _exitArg defaultExitBattleArgClass
function accept.sendBattleReport( _, _exitArg )
    pcall( BattleCallback.dispatchBattleReport, BattleCallback, _exitArg )
end

---@see 改变目标战斗索引
function accept.changeBattleIndex( _newBattleIndex, _objectIndexs )
    SM.BattleIndexReg.req.updateObjectBattleIndex( _objectIndexs, _newBattleIndex )
end

---@see 同步站位
function accept.syncAroundAttacker( _objectIndex, _allAttackers )
    for attackIndex, attackType in pairs(_allAttackers) do
        MSM.AttackAroundPosMgr[_objectIndex].post.addAttacker( _objectIndex,  attackIndex, attackType )
    end
end

---@see 增加对象BUFF
function accept.addObjectBuff( _objectIndex, _objectType, _buffId )
    if _objectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_objectType].post.addArmyBattleBuff( _objectIndex, _buffId )
    end
end