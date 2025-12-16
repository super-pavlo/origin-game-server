--[[
* @file : ExpeditionLogic.lua
* @type : lualib
* @author : chenlei
* @created : Wed Dec 16 2020 18:16:21 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 远征相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]
local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local ItemLogic = require "ItemLogic"
local BattleCreate = require "BattleCreate"
local RankLogic = require "RankLogic"
local ArmyLogic = require "ArmyLogic"
local CommonCacle = require "CommonCacle"
local ArmyWalkLogic = require "ArmyWalkLogic"
local ArmyMarchLogic = require "ArmyMarchLogic"
local Random = require "Random"

local ExpeditionLogic = {}

---@see 计算星级
function ExpeditionLogic:cancleStar( _rid, _condition, _extraArg )
    local type = _condition[1]
    local num = _condition[2]
    if Enum.ExpeditionStarType.TIME == type then
        local expeditionTime = RoleLogic:getRole( _rid, Enum.Role.expeditionTime )
        if os.time() - expeditionTime <= num then
            return 1
        end
    elseif Enum.ExpeditionStarType.DEAD_RATE == type then
        local beforeSoldierSum = 0
        for _, armyInfo in pairs( _extraArg.beforeArmyInfos ) do
            for _, soldierInfo in pairs( armyInfo.soldiers ) do
                beforeSoldierSum = beforeSoldierSum + soldierInfo.num
            end
        end
        local soldierSum = 0
        for _, armyInfo in pairs( _extraArg.armyInfos ) do
            -- for _, soldierInfo in pairs( armyInfo.soldiers ) do
            --     soldierSum = soldierSum + soldierInfo.num
            -- end
            soldierSum = soldierSum + armyInfo.armyCount
        end
        if soldierSum/beforeSoldierSum * 100 // 1 >= 100 - num then
            return 1
        end
    elseif Enum.ExpeditionStarType.HERO_DEAD == type then
        if table.size(_extraArg.beforeArmyInfos ) - table.size(_extraArg.armyInfos ) <= num then
            return 1
        end
    end
    return 0
end

---@see 远征回调
function ExpeditionLogic:expedtionCallBack( _rid, _extraArg, _win )
    local id = RoleLogic:getRole( _rid, Enum.Role.expeditionId )
    if _win ==  Enum.ExpeditionBattleResult.WIN and id > 0 then
        local starResult = {}
        local star = 1
        local expeditionInfo = RoleLogic:getRole( _rid, Enum.Role.expeditionInfo )
        local updateFlag
        local sExpedition = CFG.s_Expedition:Get(id)
        local rewardInfo = {}
        local firstReward = false
        table.insert( starResult, 1 )
        -- 星级结算
        for i = 2, 3 do
            local str = string.format( "starCondition%d", i )
            local result = self:cancleStar( _rid, sExpedition[str], _extraArg )
            table.insert( starResult, result )
            star = star + result
        end
        if expeditionInfo[id] then
            if expeditionInfo[id].star < star and expeditionInfo[id].star < 3 then
                local begin = 1
                if expeditionInfo[id].rewar then
                    begin = expeditionInfo[id].star + 1
                end
                for i=begin, star do
                    local reawrd = ItemLogic:getItemPackage( _rid, sExpedition["reward"..i] )
                    table.insert( rewardInfo, reawrd )
                end
                expeditionInfo[id].star = star
                expeditionInfo[id].reward = true
                updateFlag = true
            end
        else
            expeditionInfo[id] = { id = id, star = star, reward = true, finishTime = os.time() }
            for i=1,star do
                local reawrd = ItemLogic:getItemPackage( _rid, sExpedition["reward"..i] )
                table.insert( rewardInfo, reawrd )
            end
            ItemLogic:getItemPackage( _rid, sExpedition.firstReward )
            firstReward = true
            updateFlag = true
        end
        if updateFlag then
            local syncInfo = {}
            syncInfo[id] = expeditionInfo[id]
            -- 更新记录
            RoleLogic:setRole( _rid, { [Enum.Role.expeditionInfo] = expeditionInfo } )
            -- 通知客户端
            RoleSync:syncSelf( _rid, { [Enum.Role.expeditionInfo] = syncInfo }, true, true )
        end
        Common.syncMsg( _rid, "Expedition_BattleInfo",  { win = _win, id = id , star = star, rewardInfo = rewardInfo,
                        firstReward = firstReward, starResult = starResult } )
        -- 更新排行版
        RankLogic:update( _rid, Enum.RankType.EXPEDITION, sExpedition.level, nil, star )
        local maxId = 0
        sExpedition = CFG.s_Expedition:Get()
        for _, info in pairs(expeditionInfo) do
            if sExpedition[info.id] and sExpedition[info.id].level > maxId then
                maxId = sExpedition[info.id].level
            end
        end
        if maxId > 0 then
            MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.EXPEDITION_LEVEL, maxId, nil, nil, true )
        end
    elseif id > 0 then
        Common.syncMsg( _rid, "Expedition_BattleInfo",  { win = _win, id = id } )
    end
end

---@see 快速领取奖励
function ExpeditionLogic:oneKeyAward( _rid )
    local expeditionInfo = RoleLogic:getRole( _rid, Enum.Role.expeditionInfo )
    local syncInfo = {}
    local rewardInfo = {}
    local syncRoleInfo = {}
    local synItemInfo = {}
    for id, info in pairs(expeditionInfo) do
        if not info.reward and info.star >= 3 then
            local sExpedition = CFG.s_Expedition:Get(id)
            for i=1, info.star do
                local reward = ItemLogic:getItemPackage( _rid, sExpedition["reward"..i], true )
                local syncRole, synItem = ItemLogic:giveReward( _rid, reward, sExpedition["reward"..i], true )
                table.mergeEx( syncRoleInfo, syncRole or {} )
                if not table.empty( synItem or {} ) then
                    for itemIndex, item in pairs(synItem) do
                        if synItemInfo[itemIndex] then
                            synItemInfo[itemIndex].overlay = item.overlay
                        else
                            synItemInfo[itemIndex] = item
                        end
                    end
                end
                ItemLogic:mergeReward( rewardInfo, reward )
            end
            info.reward = true
            syncInfo[id] = info
        end
    end
    -- 角色变化信息合并推送
    if not table.empty( syncRoleInfo ) then
        RoleSync:syncSelf( _rid, syncRoleInfo, true )
    end
    -- 道具变化信息合并推送
    if not table.empty( synItemInfo ) then
        ItemLogic:syncItem( _rid, nil, synItemInfo, true )
    end
    -- 更新记录
    RoleLogic:setRole( _rid, { [Enum.Role.expeditionInfo] = expeditionInfo } )
    -- 通知客户端
    RoleSync:syncSelf( _rid, { [Enum.Role.expeditionInfo] = syncInfo }, true, true )
    return { rewardInfo = rewardInfo }
end

---@see 领取章节奖励
function ExpeditionLogic:awardChapterReward( _rid, _id )
    local expeditionInfo = RoleLogic:getRole( _rid, Enum.Role.expeditionInfo )
    if not expeditionInfo[_id] or expeditionInfo[_id].reward then
        return
    end
    local sExpedition = CFG.s_Expedition:Get(_id)
    local rewardInfo = {}
    local syncInfo = {}
    for i=1, expeditionInfo[_id].star do
        ItemLogic:mergeReward( rewardInfo, ItemLogic:getItemPackage( _rid, sExpedition["reward"..i] ))
    end
    expeditionInfo[_id].reward = true
    syncInfo[_id] = expeditionInfo[_id]
     -- 更新记录
    RoleLogic:setRole( _rid, { [Enum.Role.expeditionInfo] = expeditionInfo } )
    -- 通知客户端
    RoleSync:syncSelf( _rid, { [Enum.Role.expeditionInfo] = syncInfo }, true, true )
    return { rewardInfo = rewardInfo, id = _id }
end

---@see 跨天重置远征领奖状态
function ExpeditionLogic:resetExpedition( _rid, _isLogin )
    local expeditionInfo = RoleLogic:getRole( _rid, Enum.Role.expeditionInfo )
    local syncInfo = {}
    for id, info in pairs(expeditionInfo) do
        if info.reward then
            info.reward = false
            syncInfo[id] = info
        end
    end
    -- 更新记录
    if not table.empty( syncInfo ) then
        RoleLogic:setRole( _rid, { [Enum.Role.expeditionInfo] = expeditionInfo } )
        -- 通知客户端
        if not _isLogin then
            RoleSync:syncSelf( _rid, { [Enum.Role.expeditionInfo] = syncInfo }, true, true )
        end
    end
end

---@see 远征退出战斗
function ExpeditionLogic:exitBattle( _rid )
    local mapIndex = RoleLogic:getRole( _rid,Enum.Role.mapIndex )
    local objectInfos = SM.ExpeditionMgr.req.getAllObjectInfo( mapIndex ) or {}
    local objectIndexs = {}
    for objectIndex in pairs(objectInfos) do
        objectIndexs[objectIndex] = objectIndex
    end
    local armyInfos, monsterInfos = ExpeditionLogic:getAllExpeditionInfo(objectIndexs)
    for _, armyInfo in pairs(armyInfos) do
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( armyInfo.objectIndex )
        if battleIndex then
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            if battleNode then
                Common.rpcMultiSend( battleNode, "BattleLoop", "objectDeleteBattleOnExpedition", battleIndex )
            end
        end
    end
    for _, monsterInfo in pairs(monsterInfos) do
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( monsterInfo.objectIndex )
        if battleIndex then
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            if battleNode then
                Common.rpcMultiSend( battleNode, "BattleLoop", "objectDeleteBattleOnExpedition", battleIndex )
            end
        end
    end
end

---@see 获取远征地图怪物对象
function ExpeditionLogic:getAllExpeditionInfo( _objectIndexs )
    local monsterInfos = {}
    local armyInfos = {}
    for objectIndex in pairs(_objectIndexs) do
        local objectInfo = MSM.SceneExpeditionMgr[objectIndex].req.getExpeditionInfo(objectIndex)
        if objectInfo then
            if objectInfo.monsterId and objectInfo.monsterId > 0 then
                monsterInfos[objectIndex] = objectInfo
            end
            if objectInfo.rid and objectInfo.rid > 0 then
                armyInfos[objectIndex] = objectInfo
            end
        end
    end
    return armyInfos, monsterInfos
end

---@see 退出远征战斗
function ExpeditionLogic:exitExpedition( _rid, _isTimeOut )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.mapIndex, Enum.Role.expeditionId } )
    local mapIndex = roleInfo.mapIndex or 0
    local expeditionId = roleInfo.expeditionId
    if mapIndex <= 0 then
        return
    end
    if _isTimeOut then
        self:expedtionCallBack( _rid, { id = expeditionId }, Enum.ExpeditionBattleResult.TIME_FAIL )
    end
    -- 重置远征开始时间和地图索引
    RoleLogic:setRole( _rid, { [Enum.Role.mapIndex] = 0, [Enum.Role.expeditionTime] = 0, [Enum.Role.expeditionId] = 0 })
    RoleSync:syncSelf( _rid, { [Enum.Role.mapIndex] = 0 }, true, true )
    -- 远征对象退出战斗
    self:exitBattle( _rid )
    -- 删除远征地图信息
    SM.ExpeditionMgr.post.deleteMap( _rid, mapIndex)
    -- 删除远征定时器
    MSM.RoleTimer[_rid].req.deleteExpeditionTimer( _rid )
    return { result = true }
end

---@see 怪物追击处理
function ExpeditionLogic:dispatchMonsterFollowUp( _objectFollowUpInfos, _mapObjectInfo )
    local removeFollowUp = {}
    local returnInitPos = {}
    for objectIndex, followInfo in pairs(_objectFollowUpInfos) do
        local targetIndex = followInfo.followObjectIndex
        local targetType = followInfo.followObjectType
        local objectInfo = _mapObjectInfo[objectIndex]
        repeat
            -- 获取目标信息
            local targetObjectInfo = MSM.MapObjectTypeMgr[targetIndex].req.getObjectInfo( targetIndex )
            if not targetObjectInfo then
                break
            end
            if ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.MOVE )
            and not ArmyLogic:checkArmyWalkStatus( targetObjectInfo.status ) then
                break
            end

            local objectFail
            if targetType == Enum.RoleType.ARMY or targetType == Enum.RoleType.EXPEDITION then
                objectFail = ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.FAILED_MARCH )
            end

            -- 判断是否回头攻击自己了
            local isAttackSelf = false
            if targetObjectInfo.targetObjectIndex == objectIndex
            and ( ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.ATTACK_MARCH )
            or ArmyLogic:checkArmyStatus( targetObjectInfo.status, Enum.ArmyStatus.FOLLOWUP ) ) then
                isAttackSelf = true
            end

            if objectInfo and not objectFail and not isAttackSelf then
                -- 判断怪物是否超出了追击范围
                local armyRadius = CommonCacle:getArmyRadius( objectInfo.soldiers )
                -- 部队实时计算
                local targetInfo = MSM.SceneExpeditionMgr[targetIndex].req.getExpeditionInfo(targetIndex)
                local targetRaidus = CommonCacle:getArmyRadius( targetInfo.soldiers )
                local attackRange = armyRadius + targetRaidus + CFG.s_Config:Get("attackRange")
                local distance = math.sqrt( (objectInfo.pos.x - targetObjectInfo.pos.x ) ^ 2 + ( objectInfo.pos.y - targetObjectInfo.pos.y ) ^ 2 )
                if attackRange < distance then
                    MSM.MapMarchMgr[objectIndex].req.expeditionArmyMove( objectIndex, targetIndex, nil, Enum.ArmyStatus.FOLLOWUP, Enum.MapMarchTargetType.FOLLOWUP  )
                else
                    -- 结束追击
                    removeFollowUp[objectIndex] = true
                    -- 判断目标是否有攻击目标,没有则把目标的攻击目标设置成追击者
                    if targetObjectInfo.targetObjectIndex and targetObjectInfo.targetObjectIndex > 0 then
                        MSM.SceneExpeditionMgr[targetObjectInfo.targetObjectIndex].post.updateExpeditionTargetObjectIndex( targetObjectInfo.targetObjectIndex, objectIndex )
                    end
                end
            else
                -- 目标不存在了,取消追击
                removeFollowUp[objectIndex] = true
                returnInitPos[objectIndex] = true
            end
        until true
    end

    for removeIndex in pairs(removeFollowUp) do
        _objectFollowUpInfos[removeIndex] = nil
        -- 移除目标追击状态
        _mapObjectInfo[removeIndex].status = ArmyLogic:delArmyStatus( _mapObjectInfo[removeIndex].status, Enum.ArmyStatus.FOLLOWUP )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( _mapObjectInfo[removeIndex].mapIndex )
        sceneObject.post.syncObjectInfo( removeIndex, { status = _mapObjectInfo[removeIndex].status } )
        if returnInitPos[removeIndex] then
            -- 怪物返回原来位置
            local expedition = MSM.SceneExpeditionMgr[removeIndex].req.getExpeditionInfo( removeIndex )
            if expedition.monsterId > 0 then
                -- 获取目标点坐标、状态
                local targetPos = expedition.initPos
                local armyStatus = ArmyLogic:addArmyStatus(expedition.status, Enum.ArmyStatus.SPACE_MARCH)
                -- 处理行军
                ArmyMarchLogic:dispatchExpeditionMarch( nil, removeIndex, nil, Enum.MapMarchTargetType.SPACE, targetPos, armyStatus, nil )
            end
        end
    end
end

---@see 远征怪物巡逻坐标更新
function ExpeditionLogic:updateMonsterPartolPos( _monsterInfos, _monsterLastUpdatePos, _armyWalkToInfo )
    local isReach
    for objectIndex, monsterInfo in pairs(_monsterInfos) do
        if not ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.STATIONING )
            and not ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.BATTLEING )
            and not ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.ATTACK_MARCH )
            and not ArmyLogic:checkArmyStatus( monsterInfo.status, Enum.ArmyStatus.SPACE_MARCH) then
            -- 模拟移动
            monsterInfo.pos, isReach = ArmyWalkLogic:cacleNowPos( monsterInfo.pos, monsterInfo.next, monsterInfo.moveSpeed,
                                                                    monsterInfo.arrivalTime )
            -- 坐标更新处理
            self:updateMonsterPosImpl( objectIndex, monsterInfo.pos, monsterInfo, _monsterLastUpdatePos, _armyWalkToInfo )
            if isReach then
                if table.empty(monsterInfo.movePath) then -- 全部行走完毕
                    self:monsterPartolOver( objectIndex, monsterInfo )
                else
                    -- 还有下一个目标点
                    monsterInfo.next = table.remove(monsterInfo.movePath, 1)
                    -- 重新计算角度
                    monsterInfo.angle, monsterInfo.moveSpeed.x, monsterInfo.moveSpeed.y = ArmyWalkLogic:cacleSpeed( { monsterInfo.pos, monsterInfo.next }, monsterInfo.speed )
                end
            end
        end
    end
end

---@see 远征怪物巡逻结束
---@param _monsterInfo defaultMapMonsterInfoClass
function ExpeditionLogic:monsterPartolOver( _objectIndex, _monsterInfo )

    MSM.AoiMgr[_monsterInfo.mapIndex].post.expeditionObjectUpdate( _monsterInfo.mapIndex, _objectIndex, _monsterInfo.pos, _monsterInfo.pos )

    -- 状态变为待机
    _monsterInfo.status = Enum.ArmyStatus.STATIONING
    -- 下次巡逻时间
    local monsterId = _monsterInfo.monsterId
    local cdMin = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCD") / 1000 )
    local cdMax = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCdMax") / 1000 )
    _monsterInfo.nextPartolTime = os.time() + Random.Get(cdMin,cdMax)
    -- 通过AOI通知
    local sceneObject = Common.getSceneMgr( _monsterInfo.mapIndex )
    sceneObject.post.syncObjectInfo( _objectIndex, { status = Enum.ArmyStatus.STATIONING, pos = _monsterInfo.pos } )
end

---@see 远征怪物坐标更新处理
function ExpeditionLogic:updateMonsterPosImpl( _objectIndex, _pos, _monsterInfo, _monsterLastUpdatePos, _armyWalkToInfo )
    -- 如果处于战斗,更新坐标
    if ArmyLogic:checkArmyStatus( _monsterInfo.status, Enum.ArmyStatus.BATTLEING ) then
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
        if battleIndex then
            -- 通知对象更新坐标
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            Common.rpcMultiSend( battleNode, "BattleLoop", "updateObjectPos", battleIndex, _objectIndex, _pos )
        end
    end

    local now = os.time()
    -- 每秒更新一次路径(跟随)
    if not _monsterLastUpdatePos[_objectIndex] or ( now - _monsterLastUpdatePos[_objectIndex] >= 1 ) then
        -- 如果有部队向怪物行军,更新路径
        if _armyWalkToInfo[_objectIndex] then
            for armyObjectIndex in pairs(_armyWalkToInfo[_objectIndex]) do
                local armyInfo = MSM.SceneExpeditionMgr[armyObjectIndex].req.getExpeditionInfo( armyObjectIndex )
                if armyInfo then
                    if armyInfo.targetObjectIndex == _objectIndex then
                        armyInfo.pos = MSM.MapMarchMgr[armyObjectIndex].req.fixObjectPosWithMillisecond(armyObjectIndex, true) or armyInfo.pos
                        local path = { armyInfo.pos, _pos }
                        -- 修正坐标
                        local armyRadius, monsterRadius
                        if armyInfo.rid and armyInfo.rid > 0 then
                            armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                            monsterRadius = CommonCacle:getArmyRadius( _monsterInfo.soldiers )
                            --monsterRadius = CFG.s_Monster:Get( _monsterInfo.monsterId, "radiusCollide" ) * Enum.MapPosMultiple
                        else
                            armyRadius = CommonCacle:getArmyRadius( _monsterInfo.soldiers )
                            --monsterRadius = CFG.s_Monster:Get( armyInfo.monsterId, "radiusCollide" ) * Enum.MapPosMultiple
                            monsterRadius = CommonCacle:getArmyRadius( armyInfo.soldiers )
                        end
                        path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.EXPEDITION, path, armyRadius, monsterRadius )
                        -- 更新部队路径
                        MSM.MapMarchMgr[armyObjectIndex].post.updateExpeditionMovePath( armyObjectIndex, _objectIndex, path )
                    end
                else
                    -- 部队不存在了
                    _armyWalkToInfo[_objectIndex][armyObjectIndex] = nil
                    if table.empty(_armyWalkToInfo[_objectIndex]) then
                        _armyWalkToInfo[_objectIndex] = nil
                    end
                end
            end
        end
        _monsterLastUpdatePos[_objectIndex] = now
    end
end

---@see 远征怪物巡逻处理
---@param _monsterInfos table<int, defaultMapMonsterInfoClass>
function ExpeditionLogic:dispatchMonsterPartol( _monsterInfos )
    local path
    local now = os.time()
    for objectIndex, monsterInfo in pairs(_monsterInfos) do
        if monsterInfo.nextPartolTime <= now and monsterInfo.status == Enum.ArmyStatus.STATIONING  then
            -- 待机状态,开始巡逻
            local sMonsterInfo = CFG.s_Monster:Get( monsterInfo.monsterId, { "patrolRadius" } )
            if sMonsterInfo and sMonsterInfo.patrolRadius then
                -- 计算远征怪物巡逻坐标
                path = ArmyWalkLogic:cacleMonsterPartolPos( monsterInfo.initPos, monsterInfo.pos, sMonsterInfo.patrolRadius )
                if path and table.size(path) >= 2 then
                    -- 状态变为巡逻
                    monsterInfo.path = path
                    local movePath = table.copy( path, true )
                    monsterInfo.pos = movePath[1]
                    monsterInfo.next = movePath[2]
                    table.remove( movePath, 1 )
                    table.remove( movePath, 1 )
                    monsterInfo.movePath = movePath
                    -- 计算到达时间
                    local arrivalTime = ArmyLogic:cacleArrivalTime( path, monsterInfo.speed )
                    -- 计算移动角度
                    local angle, speedx, speedy = ArmyWalkLogic:cacleSpeed( path, monsterInfo.speed )
                    monsterInfo.angle = math.floor( angle * 100 )
                    monsterInfo.moveSpeed = { x = speedx, y = speedy }
                    monsterInfo.arrivalTime = arrivalTime
                    monsterInfo.status = Enum.ArmyStatus.PATROL
                    -- 同步路径
                    MSM.SceneExpeditionMgr[objectIndex].post.updateExpeditionPath( objectIndex, path, arrivalTime, os.time(), nil, Enum.ArmyStatus.PATROL )
                else
                    -- 无路径,等待下次巡逻
                    local monsterId = monsterInfo.monsterId
                    local cdMin = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCD") / 1000 )
                    local cdMax = math.floor( CFG.s_Monster:Get(monsterId, "patrolTimeCdMax") / 1000 )
                    monsterInfo.nextPartolTime = os.time() + Random.Get(cdMin,cdMax)
                end
            end
        end
    end
end

return ExpeditionLogic