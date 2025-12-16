--[[
* @file : ExpeditionMgr.lua
* @type : snax single service
* @author : chenlei
* @created : Thu Dec 17 2020 00:28:39 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 远征服务
* Copyright(C) 2017 IGG, All rights reserved
]]
local ArmyLogic = require "ArmyLogic"
local ExpeditionLogic = require "ExpeditionLogic"
local RoleLogic = require "RoleLogic"
local queue = require "skynet.queue"
local ArmyMarchLogic = require "ArmyMarchLogic"
local HeroLogic = require "HeroLogic"
local CommonCacle = require "CommonCacle"
local MonsterLogic = require "MonsterLogic"

local lock = {} -- { role = { lock = function } }

local expeditionMapInfo = {}

---@see 生成地图部队以及怪物
function response.createArmyAndMonster( _rid, _id, _armyInfos, _mapIndex )
    local sExpedition = CFG.s_Expedition:Get(_id)
    local sExpeditionBattle = CFG.s_ExpeditionBattle:Get(sExpedition.battleID)
    if sExpedition.type == Enum.ExpeditionBattleType.COMMON then
        for i = 1, 5 do
            local str = string.format( "monster%dID", i )
            if str ~= "" then
                local monsterId = sExpeditionBattle[str]
                if monsterId > 0 then
                    local objectIndex = Common.newMapObjectIndex()
                    local bornStr = string.format( "monster%dBornInfo", i )
                    local monsterBornInfo = sExpeditionBattle[bornStr]
                    local sMonsterInfo = CFG.s_Monster:Get(monsterId)
                    local _, soldiers = MonsterLogic:cacleMonsterArmyCount( monsterId )
                    local monsterInfo = {
                        objectPos = { x = monsterBornInfo[1] * Enum.MapPosMultiple , y = monsterBornInfo[2] * Enum.MapPosMultiple },
                        objectType = Enum.RoleType.EXPEDITION,
                        monsterId = monsterId,
                        monsterIndex = i,
                        mapIndex = _mapIndex,
                        armyRadius = CommonCacle:getArmyRadius( soldiers ),
                        speed = sMonsterInfo.patrolSpeed,
                        status = Enum.ArmyStatus.STATIONING,
                        expeditionId = _id,
                        angle = monsterBornInfo[3] * Enum.MapPosMultiple,
                    }
                    MSM.AoiMgr[_mapIndex].req.expeditionObjectEnter( _mapIndex, objectIndex, monsterInfo.objectPos,
                            monsterInfo.objectPos, monsterInfo )
                    if not expeditionMapInfo[_mapIndex] then expeditionMapInfo[_mapIndex] = {} end
                    expeditionMapInfo[_mapIndex][objectIndex] = monsterInfo
                end
            end
        end
    elseif sExpedition.type == Enum.ExpeditionBattleType.BOSS then
        local sMonsterInfo = CFG.s_Monster:Get(sExpeditionBattle.bossID)
        local objectIndex = Common.newMapObjectIndex()
        local bossBornInfo = sExpeditionBattle.bossBornInfo
        local _, soldiers = MonsterLogic:cacleMonsterArmyCount( sExpeditionBattle.bossID )
        local monsterInfo = {
            objectPos = { x = bossBornInfo[1] * Enum.MapPosMultiple , y = bossBornInfo[2] * Enum.MapPosMultiple },
            objectType = Enum.RoleType.EXPEDITION,
            monsterId = sExpeditionBattle.bossID,
            mapIndex = _mapIndex,
            monsterIndex = 1,
            armyRadius = CommonCacle:getArmyRadius( soldiers ),
            speed = sMonsterInfo.patrolSpeed,
            status = Enum.ArmyStatus.STATIONING,
            expeditionId = _id,
            angle = bossBornInfo[3] * Enum.MapPosMultiple,
        }
        MSM.AoiMgr[_mapIndex].req.expeditionObjectEnter( _mapIndex, objectIndex, monsterInfo.objectPos,
            monsterInfo.objectPos, monsterInfo )
        if not expeditionMapInfo[_mapIndex] then expeditionMapInfo[_mapIndex] = {} end
        expeditionMapInfo[_mapIndex][objectIndex] = monsterInfo
    --elseif sExpedition.type == Enum.ExpeditionType.RALLY then
    --elseif sExpedition.type == Enum.ExpeditionType.DEFEND then
    end

    -- 生成玩家队伍信息
    for i, armyInfo in pairs(_armyInfos) do
        local objectIndex = Common.newMapObjectIndex()
        local str = string.format( "playerBornInfo%d", i )
        local playerBornInfo = sExpeditionBattle[str]
        armyInfo.talentAttr = HeroLogic:getHeroTalentAttr( _rid, armyInfo.mainHeroId ).battleAttr
        armyInfo.equipAttr = HeroLogic:getHeroEquipAttr( _rid, armyInfo.mainHeroId ).battleAttr
        armyInfo.skills = HeroLogic:getRoleAllHeroSkills( _rid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
        armyInfo.rid = _rid
        local army = {
            objectPos = { x = playerBornInfo[1] * Enum.MapPosMultiple , y = playerBornInfo[2] * Enum.MapPosMultiple },
            objectType = Enum.RoleType.EXPEDITION,
            rid = _rid,
            mapIndex = _mapIndex,
            mainHeroId = armyInfo.mainHeroId,
            deputyHeroId = armyInfo.deputyHeroId,
            mainHeroLevel = armyInfo.mainHeroLevel,
            deputyHeroLevel = armyInfo.deputyHeroLevel,
            soldiers = armyInfo.soldiers,
            armyIndex = armyInfo.armyIndex,
            status = Enum.ArmyStatus.STATIONING,
            armyRadius = CommonCacle:getArmyRadius( armyInfo.soldiers ),
            speed = ArmyLogic:reCacleArmySpeed( objectIndex, armyInfo, true, armyInfo ),
            expeditionId = _id,
            angle = playerBornInfo[3] * Enum.MapPosMultiple,
        }
        MSM.AoiMgr[_mapIndex].req.expeditionObjectEnter( _mapIndex, objectIndex, army.objectPos,
            army.objectPos, army )
        if not expeditionMapInfo[_mapIndex] then expeditionMapInfo[_mapIndex] = {} end
        expeditionMapInfo[_mapIndex][objectIndex] = army
    end
    return _mapIndex
end

---@see 返回远征地图对象信息
function response.getObjectInfo( _mapIndex, _objectIndex )
    return expeditionMapInfo[_mapIndex][_objectIndex]
end

---@see 返回远征地图所有对象信息
function response.getAllObjectInfo( _mapIndex )
    return expeditionMapInfo[_mapIndex]
end

---@see 删除远征地图信息
function accept.deleteMap( _rid, _mapIndex )
    for objectIndex in pairs( expeditionMapInfo[_mapIndex] or {} ) do
        MSM.MapMarchMgr[objectIndex].req.stopObjectMove( objectIndex )
        MSM.AoiMgr[_mapIndex].req.expeditionObjectLeave( _mapIndex, objectIndex, { x = -1, y = -1 }  )
    end
    -- 角色离开aoi
    MSM.AoiMgr[_mapIndex].req.roleLeave( _mapIndex, _rid, { x = -1, y = -1 } )
    expeditionMapInfo[_mapIndex] = nil
    SM.ExpeditionAoiSpaceMgr.post.addFreeMapIndex( _mapIndex )
end

---@see 逻辑互斥锁
local function checkLock( _rid )
    if not lock[_rid] then
        lock[_rid] = { lock = queue() }
    end
end

---@see 远征战斗回调
function response.dispatchExpedition( _exitArg )

    local expeditionInfo = MSM.SceneExpeditionMgr[_exitArg.objectIndex].req.getExpeditionInfo(_exitArg.objectIndex)
    if not expeditionInfo then return end
    local mapIndex = expeditionInfo.mapIndex

    -- 检查互斥锁
    checkLock( mapIndex )

    return lock[mapIndex].lock(
        function ()
            local objectInfos = expeditionMapInfo[mapIndex]
            local objectIndexs = {}
            local beforeArmyInfos = {}
            -- 判断士兵是否死光了
            local soldierSum = 0
            for _, soldierInfo in pairs( _exitArg.soldiers ) do
                soldierSum = soldierSum + soldierInfo.num
            end
            if soldierSum <= 0 then
                MSM.SceneExpeditionMgr[_exitArg.objectIndex].req.updateArmyStatus( _exitArg.objectIndex, Enum.ArmyStatus.FAILED_MARCH )
                MSM.AoiMgr[mapIndex].req.expeditionObjectLeave( mapIndex, _exitArg.objectIndex, { x = -1, y = -1 } )
            elseif expeditionInfo.monsterId and expeditionInfo.monsterId > 0 and soldierSum > 0 then
                -- 怪物返回原来位置
                -- 获取目标点坐标、状态
                local targetPos = expeditionInfo.initPos
                local armyStatus = Enum.ArmyStatus.SPACE_MARCH
                -- 处理行军
                ArmyMarchLogic:dispatchExpeditionMarch( nil, _exitArg.objectIndex, nil, Enum.MapMarchTargetType.SPACE, targetPos, armyStatus, nil )
            end
            if _exitArg.rid and _exitArg.rid > 0 then
                for objectIndex, objectInfo in pairs(objectInfos) do
                    objectIndexs[objectIndex] = objectIndex
                    if objectInfo.rid and objectInfo.rid > 0 then
                        beforeArmyInfos[objectIndex] = objectInfo
                    end
                end
                local armyInfos, monsterInfo = ExpeditionLogic:getAllExpeditionInfo(objectIndexs)
                if table.size(armyInfos) == 0 then
                    -- 推送战斗失败协议
                    ExpeditionLogic:expedtionCallBack( _exitArg.rid, nil, Enum.ExpeditionBattleResult.FAIL )
                    -- 删除远征地图信息
                    SM.ExpeditionMgr.post.deleteMap( _exitArg.rid, mapIndex)
                    -- 删除远征定时器
                    MSM.RoleTimer[_exitArg.rid].req.deleteExpeditionTimer( _exitArg.rid )
                    -- 重置远征开始时间和地图索引
                    RoleLogic:setRole( _exitArg.rid, { [Enum.Role.mapIndex] = 0, [Enum.Role.expeditionTime] = 0, [Enum.Role.expeditionId] = 0 })
                elseif table.size(monsterInfo) == 0 then
                    _exitArg.beforeArmyInfos = beforeArmyInfos
                    _exitArg.armyInfos = armyInfos
                    -- 战斗胜利
                    ExpeditionLogic:expedtionCallBack( _exitArg.rid, _exitArg, Enum.ExpeditionBattleResult.WIN )
                    -- 删除远征地图信息
                    SM.ExpeditionMgr.post.deleteMap( _exitArg.rid, mapIndex)
                    -- 删除远征定时器
                    MSM.RoleTimer[_exitArg.rid].req.deleteExpeditionTimer( _exitArg.rid )
                    -- 重置远征开始时间和地图索引
                    RoleLogic:setRole( _exitArg.rid, { [Enum.Role.mapIndex] = 0, [Enum.Role.expeditionTime] = 0, [Enum.Role.expeditionId] = 0 })
                end
            end
        end
    )
end