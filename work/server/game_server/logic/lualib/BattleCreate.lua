--[[
 * @file : BattleCreate.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-01-21 13:27:40
 * @Last Modified time: 2020-01-21 13:27:40
 * @department : Arabic Studio
 * @brief : 创建战斗逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local skynet = require "skynet"
local RoleLogic = require "RoleLogic"
local RoleCacle = require "RoleCacle"
local ArmyLogic = require "ArmyLogic"
local MapObjectLogic = require "MapObjectLogic"
local MonsterCityLogic = require "MonsterCityLogic"
local GuildLogic = require "GuildLogic"
local CommonCacle = require "CommonCacle"

local BattleCreate = {}

---@see 获取战斗服务器
function BattleCreate:getBattleServerNode( _index )
    local battleSvrName = "battle"
    local fuzzy = true
    if skynet.getenv("selfbattlenode") then -- 取自己同服务ID的战斗服务器
        battleSvrName = battleSvrName .. skynet.getenv("serverid")
        fuzzy = false
    end
    local battleServerInfo = Common.getClusterNodeByName(battleSvrName, fuzzy)
    if battleServerInfo then
        if not fuzzy then
            return battleServerInfo
        else
            return battleServerInfo[_index % #battleServerInfo + 1]
        end
	end
end

---@see 更新对象状态
function BattleCreate:updateObjectStatus( _objectIndex, _objectType, _isAdd )
    local op = Enum.ArmyStatusOp.DEL
    if _isAdd then
        op = Enum.ArmyStatusOp.ADD
    end

    local status = Enum.ArmyStatus.BATTLEING
    if _objectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_objectIndex].req.updateArmyStatus( _objectIndex, status, op )
    elseif _objectType == Enum.RoleType.MONSTER
    or _objectType == Enum.RoleType.GUARD_HOLY_LAND
    or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
    or _objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        MSM.SceneMonsterMgr[_objectIndex].req.updateMonsterStatus( _objectIndex, status, op )
    elseif _objectType == Enum.RoleType.CITY then
        MSM.SceneCityMgr[_objectIndex].req.updateCityStatus( _objectIndex, status, op )
    elseif MapObjectLogic:checkIsResourceObject( _objectType ) then
        MSM.SceneResourceMgr[_objectIndex].req.updateResourceStatus( _objectIndex, status, op )
    elseif _objectType == Enum.RoleType.MONSTER_CITY then
        MSM.SceneMonsterCityMgr[_objectIndex].req.updateMonsterCityStatus( _objectIndex, status, op )
    elseif MapObjectLogic:checkIsGuildBuildObject( _objectType ) then
        MSM.SceneGuildBuildMgr[_objectIndex].req.updateGuildBuildStatus( _objectIndex, status, op )
    elseif MapObjectLogic:checkIsHolyLandObject( _objectType ) then
        MSM.SceneHolyLandMgr[_objectIndex].req.updateHolyLandStatus( _objectIndex, status, op )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        MSM.SceneExpeditionMgr[_objectIndex].req.updateArmyStatus( _objectIndex, status, op )
    end
end

---@see 获取军队战斗属性信息
function BattleCreate:getArmyBattleInfo( _objectInfo )
    -- 对象属性
    _objectInfo.objectAttr = RoleCacle:getRoleBattleAttr( _objectInfo.rid )
    -- 部队战斗力
    local roleInfo = RoleLogic:getRole( _objectInfo.rid )
    _objectInfo.power = RoleCacle:cacleArmyPower( roleInfo )
    -- 部队数量
    _objectInfo.armyCount = ArmyLogic:getArmySoldierCount( _objectInfo.soldiers )
    -- 如果是集结部队,获取集结部队士兵信息
    _objectInfo.rallySoldiers = ArmyLogic:getArmySoldiersDetailFromObject( _objectInfo )
    -- 获取集结部队各主将信息
    _objectInfo.rallyHeros = ArmyLogic:getArmyHerosDetailFromObject( _objectInfo )
    -- 获取城市坐标
    _objectInfo.objectCityPos = RoleLogic:getRole( _objectInfo.rid, Enum.Role.pos )

    return _objectInfo
end

---@see 获取野蛮人战斗属性信息
function BattleCreate:getMonsterBattleInfo( _objectInfo )
    return _objectInfo
end

---@see 获取野蛮人城寨战斗属性信息
function BattleCreate:getMonsterCityBattleInfo( _objectInfo )
    return _objectInfo
end

---@see 获取城市战斗属性信息
function BattleCreate:getCityBattleInfo( _objectInfo )
    -- 计算城市部队属性
    return ArmyLogic:getCityDefenseArmyInfo( _objectInfo )
end

---@see 获取资源点战斗属性信息
function BattleCreate:getResourceBattleInfo( _objectInfo, _attackRid )
    -- 资源,判断资源内是否还有部队
    if not _attackRid then
        _attackRid = 0
    end
    local ret, armyInfo = ArmyLogic:checkAttacKResourceArmy( _attackRid, _objectInfo.objectIndex )
    if ret then
        table.mergeEx( _objectInfo, armyInfo )
        return _objectInfo
    end
end

---@see 获取联盟建筑战斗属性信息
function BattleCreate:getGuildBuildInfoForBattle( _objectInfo, _attackRid )
    local guildGarrisonArmy, guildBuildInfo = MSM.SceneGuildBuildMgr[_objectInfo.objectIndex].req.getGarrisonArmy( _objectInfo.objectIndex )
    if not guildGarrisonArmy then
        local GuildBuildLogic = require "GuildBuildLogic"
        local guildBuildType = GuildBuildLogic:objectTypeToBuildType( _objectInfo.objectType )
        local emailId = CFG.s_AllianceBuildingType:Get( guildBuildType, "buildDefenselessMail" ) or 0
        if emailId > 0 then
            -- 发送联盟建筑被攻击邮件
            local members = GuildLogic:getGuild( guildBuildInfo.guildId, Enum.Guild.members ) or {}
            local attackRoleInfo = RoleLogic:getRole( _attackRid, { Enum.Role.name, Enum.Role.headId, Enum.Role.headFrameID, Enum.Role.guildId } )
            local guildAbbName
            if attackRoleInfo.guildId > 0 then
                guildAbbName = GuildLogic:getGuild( attackRoleInfo.guildId, Enum.Guild.abbreviationName )
            end
            local posArg = string.format( "%d,%d", _objectInfo.pos.x, _objectInfo.pos.y )
            local emailOtherInfo = {
                subTitleContents = { guildBuildType },
                emailContents = { guildBuildType, posArg, posArg },
                guildEmail = {
                    roleName = attackRoleInfo.name,
                    roleHeadId = attackRoleInfo.headId,
                    roleHeadFrameId = attackRoleInfo.headFrameID,
                    guildAbbName = guildAbbName,
                }
            }
            -- 非阻塞发送联盟邮件
            MSM.GuildMgr[guildBuildInfo.guildId].post.sendGuildEmail( guildBuildInfo.guildId, members, emailId, emailOtherInfo )
        end
        -- 没有人驻守,直接燃烧
        MSM.GuildMgr[guildBuildInfo.guildId].post.burnGuildBuild( guildBuildInfo.guildId, guildBuildInfo.buildIndex, _attackRid )
        return
    end
    -- 部队战斗力
    local roleInfo = RoleLogic:getRole( guildGarrisonArmy.garrisonLeader )
    _objectInfo.power = RoleCacle:cacleArmyPower( roleInfo )
    -- 部队数量
    _objectInfo.armyCount = ArmyLogic:getArmySoldierCount( guildGarrisonArmy.soldiers )
    -- 合并属性
    table.mergeEx( _objectInfo, guildGarrisonArmy )
    return _objectInfo
end

---@see 获取圣地建筑战斗属性信息
function BattleCreate:getHolyLandInfo( _objectInfo, _attackRid )
    -- 重新设置对象类型
    _objectInfo.objectType = MapObjectLogic:getRealHolyLandType( _objectInfo.strongHoldId, _objectInfo.holyLandStatus )
    -- 获取圣地中的部队
    local garrisonArmy = MSM.SceneHolyLandMgr[_objectInfo.objectIndex].req.getGarrisonArmy( _objectInfo.objectIndex )
    if not garrisonArmy then
        -- 直接占领
        local attackGuildId = RoleLogic:getRole( _attackRid, Enum.Role.guildId ) or 0
        if attackGuildId > 0 then
            local HolyLandLogic = require "HolyLandLogic"
            -- 圣地关卡中及增援中的部队退出
            local mapHolyLandInfo = MSM.SceneHolyLandMgr[_objectInfo.objectIndex].req.getHolyLandInfo( _objectInfo.objectIndex )
            HolyLandLogic:guildHolyLandArmyExit( mapHolyLandInfo.strongHoldId, _objectInfo.objectIndex, nil, mapHolyLandInfo )
            MSM.GuildMgr[attackGuildId].req.occupyHolyLand( attackGuildId, _objectInfo.strongHoldId )
        end
        return
    end
    -- 合并属性
    table.mergeEx( _objectInfo, garrisonArmy )
    return _objectInfo
end

---@see 获取远征对象战斗属性
function BattleCreate:getExpedition( _objectInfo )
    if _objectInfo.rid and _objectInfo.rid > 0 then
        return self:getArmyBattleInfo( _objectInfo )
    end
    return _objectInfo
end

---@see 获取对象战斗属性信息
function BattleCreate:getObjectBattleInfo( _objectIndex, _attackRid )
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    if not objectInfo then
        LOG_ERROR("getObjectBattleInfo objectIndex(%d) not found", _objectIndex)
        return
    end

    if objectInfo.objectType == Enum.RoleType.ARMY then
        -- 部队
        return self:getArmyBattleInfo( objectInfo )
    elseif objectInfo.objectType == Enum.RoleType.MONSTER
    or objectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
    or objectInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
    or objectInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 野蛮人、圣地守护者、召唤怪物
        return self:getMonsterBattleInfo( objectInfo )
    elseif objectInfo.objectType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城寨
        return self:getMonsterCityBattleInfo( objectInfo )
    elseif objectInfo.objectType == Enum.RoleType.CITY then
        -- 城市
        return self:getCityBattleInfo( objectInfo )
    elseif MapObjectLogic:checkIsResourceObject( objectInfo.objectType ) then
        -- 资源点
        return self:getResourceBattleInfo( objectInfo, _attackRid )
    elseif MapObjectLogic:checkIsAttackGuildBuildObject( objectInfo.objectType ) then
        -- 联盟建筑
        return self:getGuildBuildInfoForBattle( objectInfo, _attackRid )
    elseif MapObjectLogic:checkIsHolyLandObject( objectInfo.objectType ) then
        -- 圣地建筑
        return self:getHolyLandInfo( objectInfo, _attackRid )
    elseif objectInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        return self:getExpedition( objectInfo )
    end

    LOG_ERROR("getObjectBattleInfo objectIndex(%d) not found, objectType(%d)", _objectIndex, objectInfo.objectType)
end

---@see 创建战斗
function BattleCreate:createBattle( _attackIndex, _defenseIndex )
    -- 获取攻击对象属性
    local attackInfo = self:getObjectBattleInfo( _attackIndex )
    -- 获取被攻击对象属性
    local defenseInfo = self:getObjectBattleInfo( _defenseIndex, attackInfo.rid )
    if not attackInfo or not defenseInfo then
        LOG_ERROR("createBattle fail, not found attackInfo or defenseInfo")
        return false
    end
    -- 如果对象时城市,而且处于护盾状态,不能攻击
    if defenseInfo.objectType == Enum.RoleType.CITY then
        if RoleLogic:checkShield( defenseInfo.rid ) then
            LOG_ERROR("createBattle fail, defenseInfo rid(%d) is in shield status", defenseInfo.rid)
            return false
        end
    end

    -- 攻击对象索引
    attackInfo.attackTargetIndex = _defenseIndex
    if attackInfo.objectType == Enum.RoleType.ARMY then
        -- 同步攻击对象
        if not ArmyLogic:checkArmyWalkStatus( attackInfo.status ) then
            MSM.SceneArmyMgr[_attackIndex].post.updateArmyTargetObjectIndex( _attackIndex, _defenseIndex )
        end
    elseif attackInfo.objectType == Enum.RoleType.MONSTER
    or attackInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
    or attackInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
    or attackInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 同步攻击对象
        MSM.SceneMonsterMgr[_attackIndex].post.updateMonsterTargetObjectIndex( _attackIndex, _defenseIndex )
    elseif attackInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.SceneExpeditionMgr[_attackIndex].post.updateExpeditionTargetObjectIndex( _attackIndex, _defenseIndex )
    end

    -- 攻击对象索引
    defenseInfo.attackTargetIndex = _attackIndex
    if defenseInfo.objectType == Enum.RoleType.ARMY then
        -- 同步攻击对象
        if not ArmyLogic:checkArmyWalkStatus( defenseInfo.status ) then
            MSM.SceneArmyMgr[_defenseIndex].post.updateArmyTargetObjectIndex( _defenseIndex, _attackIndex )
        end
    elseif defenseInfo.objectType == Enum.RoleType.MONSTER
    or defenseInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
    or defenseInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
    or defenseInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 同步攻击对象
        MSM.SceneMonsterMgr[_defenseIndex].post.updateMonsterTargetObjectIndex( _defenseIndex, _attackIndex )
    elseif defenseInfo.objectType == Enum.RoleType.CITY then
        -- 同步城市最大怒气
        MSM.SceneCityMgr[_defenseIndex].post.syncCityMaxSp( _defenseIndex, defenseInfo.maxSp )
    elseif attackInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.SceneExpeditionMgr[_defenseIndex].post.updateExpeditionTargetObjectIndex( _defenseIndex, _attackIndex )
    end

    -- 更新对象状态
    self:updateObjectStatus( _attackIndex, attackInfo.objectType, true )
    self:updateObjectStatus( _defenseIndex, defenseInfo.objectType, true )
    -- 创建战斗
    local battleNode = self:getBattleServerNode( _attackIndex )
    local battleIndex = Common.rpcMultiCall( battleNode, "BattleLoop", "CreateBattle", _attackIndex, Common.getSelfNodeName(),
                                            {
                                                [_attackIndex] = attackInfo,
                                                [_defenseIndex] = defenseInfo
                                            }
                                        )
    if battleIndex then
        -- 创建成功
        self:onCreateBattleSuccess( battleNode, battleIndex, attackInfo, defenseInfo, attackInfo.objectType, defenseInfo.objectType )
        return true
    else
        -- 更新对象状态
        self:updateObjectStatus( _attackIndex, attackInfo.objectType )
        self:updateObjectStatus( _defenseIndex, defenseInfo.objectType )
        LOG_ERROR("createBattle fail, attackIndex(%d), defenseIndex(%d)", _attackIndex, _defenseIndex)
        return false
    end
end

---@see 加入战斗
function BattleCreate:joinBattle( _objectIndex, _targetIndex )
    local ret
    -- 加入战斗
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _targetIndex )
    if battleIndex then
        local targetInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
        local attackRid = targetInfo.rid
        if MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
            attackRid = targetInfo.collectRid
        end
        local objectInfo = self:getObjectBattleInfo( _objectIndex, attackRid )
        local battleNode = self:getBattleServerNode( battleIndex )
        ret = Common.rpcMultiCall( battleNode, "BattleLoop", "JoinBattle", battleIndex, _objectIndex, objectInfo, _targetIndex )
        if ret then
            self:onJoinBattleSuccess( _objectIndex, objectInfo.objectType, _targetIndex, targetInfo.objectType, battleIndex, battleNode )
        end
    end

    return ret
end

---@see 判断开始战斗时距离是否过近
function BattleCreate:checkTooNearOnBattle( _attackInfo, _defenseInfo )
    if ArmyLogic:checkArmyWalkStatus( _defenseInfo.status ) then
        return -- 目标正在移动,不调整
    end
    local distance = math.sqrt( (_attackInfo.pos.x - _defenseInfo.pos.x ) ^ 2 + ( _attackInfo.pos.y - _defenseInfo.pos.y ) ^ 2 )
    local armyRadius = CommonCacle:getArmyRadius( _attackInfo.soldiers, _attackInfo.isRally )
    local targetSoldiers, targetRaidus
    if _defenseInfo.objectType == Enum.RoleType.ARMY then
        -- 部队实时计算
        targetSoldiers = ArmyLogic:getArmySoldiersFromObject( _defenseInfo )
        targetRaidus = CommonCacle:getArmyRadius( targetSoldiers, _defenseInfo.isRally )
    elseif _defenseInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        targetSoldiers = _defenseInfo.soldiers
        targetRaidus = CommonCacle:getArmyRadius( targetSoldiers )
    else
        targetRaidus = _defenseInfo.armyRadius
    end
    -- 攻击距离(2个对象的半径距离)
    local attackRange = armyRadius + targetRaidus
    if distance < ( attackRange * 0.99 ) then
        -- 获取防御方8个可以行走的位置,取最近的位置
        local fixPos = ArmyLogic:getObjectPos_8_Near( _defenseInfo.pos, targetRaidus, _attackInfo.pos )
        if fixPos then
            -- 攻击方调整位置
            if _attackInfo.objectType == Enum.RoleType.ARMY then
                MSM.MapMarchMgr[_attackInfo.objectIndex].post.fixArmyPath( _attackInfo.objectIndex, _defenseInfo.objectIndex,
                                                                    { _attackInfo.pos, fixPos } )
            elseif _attackInfo.objectType == Enum.RoleType.EXPEDITION then
                MSM.MapMarchMgr[_attackInfo.objectIndex].post.fixExpeditionPath( _attackInfo.objectIndex, _defenseInfo.objectIndex,
                                                                    { _attackInfo.pos, fixPos } )
            end
        end
    end
end

---@see 添加到对象的站位中
function BattleCreate:addToAttackAroundPos( _attackIndex, _attackType, _defenseIndex, _defenseType )
    MSM.AttackAroundPosMgr[_defenseIndex].post.addAttacker( _defenseIndex, _attackIndex, _attackType )
    MSM.AttackAroundPosMgr[_attackIndex].post.addAttacker( _attackIndex, _defenseIndex, _defenseType )
end

---@see 创建战斗成功处理
function BattleCreate:onCreateBattleSuccess( _battleNode, _battleIndex, _attackInfo, _defenseInfo, _attackType, _defenseType )
    -- 加入战斗索引
    local objectInfos = {
        { objectIndex = _attackInfo.objectIndex, objectType = _attackInfo.objectType },
        { objectIndex = _defenseInfo.objectIndex, objectType = _defenseInfo.objectType }
    }
    SM.BattleIndexReg.req.addObjectBattleIndex( objectInfos, _battleIndex, _battleNode )
    if _attackInfo.objectType == Enum.RoleType.ARMY then
        if _attackInfo.isRally then
            -- 删除集结队伍中所有部队的行动力
            for rallyRid, rallyArmyIndex in pairs( _attackInfo.rallyArmy or {} ) do
                -- 删除预扣除的活动力
                ArmyLogic:setArmy( rallyRid, rallyArmyIndex, { [Enum.Army.preCostActionForce] = 0 } )
                -- 通知客户端预扣除行动力
                ArmyLogic:syncArmy( rallyRid, rallyArmyIndex, { [Enum.Army.preCostActionForce] = 0 }, true )
            end
        else
            -- 删除预扣除的活动力
            ArmyLogic:setArmy( _attackInfo.rid, _attackInfo.armyIndex, { [Enum.Army.preCostActionForce] = 0 } )
            -- 通知客户端预扣除行动力
            ArmyLogic:syncArmy( _attackInfo.rid, _attackInfo.armyIndex, { [Enum.Army.preCostActionForce] = 0 }, true )
        end
    end

    -- 增加攻击对象信息到对象场景
    self:addToAttackAroundPos( _attackInfo.objectIndex, _attackType, _defenseInfo.objectIndex, _defenseType )

    if _attackType  == Enum.RoleType.ARMY then
        -- 增加部队战斗统计
        RoleLogic:addBattleNum( _attackInfo.rid )
        -- 更新最后战斗角色名字
    end

    if _defenseType == Enum.RoleType.CITY then
        -- 城市,同步当前部队数量
        MSM.SceneCityMgr[_defenseInfo.objectIndex].post.updateCityArmyCountMax( _defenseInfo.objectIndex, _defenseInfo.armyCount )
        -- 增加部队战斗统计
        RoleLogic:addBattleNum( _defenseInfo.rid )
    elseif _defenseType == Enum.RoleType.ARMY then
        -- 增加部队战斗统计
        RoleLogic:addBattleNum( _defenseInfo.rid )
        -- 如果部队正在采集符文，取消部队采集状态
        if ArmyLogic:checkArmyStatus( _defenseInfo.status, Enum.ArmyStatus.COLLECTING_NO_DELETE ) and _defenseInfo.targetObjectIndex > 0 then
            MSM.RuneMgr[_defenseInfo.targetObjectIndex].post.cancelCollectRune( _defenseInfo.rid, _defenseInfo.armyIndex, _defenseInfo.targetObjectIndex )
        end
        -- 如果是集结部队,通知追击
        if _defenseInfo.isRally then
            MSM.SceneArmyMgr[_attackInfo.objectIndex].post.armyFollowUp( _attackInfo.objectIndex, _defenseInfo.objectIndex, Enum.RoleType.ARMY )
        end
    elseif _defenseType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城寨
        local service = MonsterCityLogic:getMonsterCityServiceByIndex( _defenseInfo.objectIndex )
        MSM.MonsterCityMgr[service].post.addAttackArmyNum( _defenseInfo.objectIndex )
    end

    -- 如果双方距离过近,拉开距离(进攻方调整),如果对方正在移动,不调整
    self:checkTooNearOnBattle( _attackInfo, _defenseInfo )

    -- 更新最后战斗角色名字
    if _attackInfo.rid and _attackInfo.rid > 0 and _defenseInfo.rid and _defenseInfo.rid > 0 then
        RoleLogic:setRole( _attackInfo.rid, Enum.Role.lastBattlePvPRoleName, RoleLogic:getRole( _defenseInfo.rid, Enum.Role.name ) )
        RoleLogic:setRole( _defenseInfo.rid, Enum.Role.lastBattlePvPRoleName, RoleLogic:getRole( _attackInfo.rid, Enum.Role.name ) )
    end
end

---@see 加入战斗成功处理
function BattleCreate:onJoinBattleSuccess( _objectIndex, _objectType, _targetIndex, _targetObjectType, _battleIndex, _battleNode )
    -- 更新对象状态
    self:updateObjectStatus( _objectIndex, _objectType, true )
    -- 同步攻击对象
    if _objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.SceneArmyMgr[_objectIndex].post.updateArmyTargetObjectIndex( _objectIndex, _targetIndex )
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND
        or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        -- 野蛮人、圣地守护者、召唤怪物
        MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterTargetObjectIndex( _objectIndex, _targetIndex )
        elseif _objectType == Enum.RoleType.EXPEDITION then
            -- 远征对象
        MSM.SceneExpeditionMgr[_objectIndex].post.updateExpeditionTargetObjectIndex( _objectIndex, _targetIndex )
    end

    local targetInfo = MSM.MapObjectTypeMgr[_targetIndex].req.getObjectInfo( _targetIndex )
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )

    -- 这时候是野蛮人加入战斗
    if _targetObjectType == Enum.RoleType.ARMY then
        if targetInfo then
            if targetInfo.isRally then
                -- 删除集结队伍中所有部队的行动力
                for rallyRid, rallyArmyIndex in pairs( targetInfo.rallyArmy or {} ) do
                    -- 删除预扣除的活动力
                    ArmyLogic:setArmy( rallyRid, rallyArmyIndex, { [Enum.Army.preCostActionForce] = 0 } )
                    -- 通知客户端预扣除行动力
                    ArmyLogic:syncArmy( rallyRid, rallyArmyIndex, { [Enum.Army.preCostActionForce] = 0 }, true )
                end
            else
                -- 删除预扣除的活动力
                ArmyLogic:setArmy( targetInfo.rid, targetInfo.armyIndex, { [Enum.Army.preCostActionForce] = 0 } )
                -- 通知客户端预扣除行动力
                ArmyLogic:syncArmy( targetInfo.rid, targetInfo.armyIndex, { [Enum.Army.preCostActionForce] = 0 }, true )
            end
        end
    end

    -- 这时候是部队加入战斗
    if _objectType == Enum.RoleType.ARMY then
        if objectInfo then
            if objectInfo.isRally then
                -- 删除集结队伍中所有部队的行动力
                for rallyRid, rallyArmyIndex in pairs( objectInfo.rallyArmy or {} ) do
                    -- 删除预扣除的活动力
                    ArmyLogic:setArmy( rallyRid, rallyArmyIndex, { [Enum.Army.preCostActionForce] = 0 } )
                    -- 通知客户端预扣除行动力
                    ArmyLogic:syncArmy( rallyRid, rallyArmyIndex, { [Enum.Army.preCostActionForce] = 0 }, true )
                end
            else
                -- 删除预扣除的活动力
                ArmyLogic:setArmy( objectInfo.rid, objectInfo.armyIndex, { [Enum.Army.preCostActionForce] = 0 } )
                -- 通知客户端预扣除行动力
                ArmyLogic:syncArmy( objectInfo.rid, objectInfo.armyIndex, { [Enum.Army.preCostActionForce] = 0 }, true )
            end
        end
    end

    -- 加入战斗索引
    local objectInfos = {
        { objectIndex = _objectIndex, objectType = _objectType }
    }
    SM.BattleIndexReg.req.addObjectBattleIndex( objectInfos, _battleIndex, _battleNode )

    -- 同步攻击对象
    if _objectType == Enum.RoleType.ARMY or _objectType == Enum.RoleType.MONSTER
    or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.EXPEDITION
    or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
        if _objectType == Enum.RoleType.ARMY then
            RoleLogic:addBattleNum( objectInfo.rid )
        end

        -- 方位增加攻击者
        self:addToAttackAroundPos( _objectIndex, _objectType, _targetIndex, _targetObjectType )
    end

    -- 如果双方距离过近,拉开距离(进攻方调整)
    self:checkTooNearOnBattle( objectInfo, targetInfo )
end

---@see 退出战斗
function BattleCreate:exitBattle( _objectIndex, _block, _leaderArmyNoEnter )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = self:getBattleServerNode( battleIndex )
        if _block then
            if Common.timeoutRun( 3, Common.rpcMultiCall, battleNode, "BattleLoop", "objectExitBattle", battleIndex, _objectIndex, _leaderArmyNoEnter ) then
                LOG_ERROR("_objectIndex(%d) rpcMultiCall battleNode(%s) objectExitBattle block timeout in 3s", _objectIndex, battleNode)
            end
        else
            Common.rpcMultiSend( battleNode, "BattleLoop", "objectExitBattle", battleIndex, _objectIndex )
        end
    end
end

---@see 合并战斗
function BattleCreate:mergeBattle( _objectIndex, _mergeIndex )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    local mergeBattleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _mergeIndex )
    if mergeBattleIndex ~= battleIndex then
        -- 不能合并同一场战斗
        if battleIndex and mergeBattleIndex then
            local battleNode = self:getBattleServerNode( battleIndex )
            return Common.rpcMultiCall( battleNode, "BattleLoop", "mergeBattle", mergeBattleIndex, battleIndex, _objectIndex, _mergeIndex )
        end
    else
        -- 本身就处于同一场战斗中,不需要合并
        return true
    end
end

---@see 改变攻击目标
function BattleCreate:changeAttackTarget( _objectIndex, _objectType, _newTargetIndex )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = self:getBattleServerNode( battleIndex )
        local ret = Common.rpcMultiSend( battleNode, "BattleLoop", "changeAttackTarget", battleIndex, _objectIndex, _newTargetIndex )
        if ret then
            -- 通知客户端目标改变
            if _objectType == Enum.RoleType.ARMY then
                -- 部队
                MSM.SceneArmyMgr[_objectIndex].post.updateArmyTargetObjectIndex( _objectIndex, _newTargetIndex )
            elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND
                or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
                -- 野蛮人、圣地守护者、召唤怪物
                MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterTargetObjectIndex( _objectIndex, _newTargetIndex )
            end
        end
        return ret
    end
end

---@see 目标开始攻击
function BattleCreate:removeObjectStopAttack( _objectIndex )
    local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
    if battleIndex then
        local battleNode = self:getBattleServerNode( battleIndex )
        return Common.rpcMultiSend( battleNode, "BattleLoop", "removeObjectStopAttack", battleIndex, _objectIndex )
    end
end

---@see 创建战斗实现
function BattleCreate:syncCreateBattle( _objectIndex, _targetObjectIndex )
    local attackInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    -- 如果攻击方溃败,不处理
    if ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.FAILED_MARCH )
    or ArmyLogic:getArmySoldierCount( attackInfo.soldiers ) <= 0 then
        LOG_ERROR("beginBattleByStatus attacker is defeat status")
        return false
    end
    local defenseInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
    if not attackInfo or not defenseInfo then
        LOG_ERROR("beginBattleByStatus not attackInfo or not defenseInfo")
        return false
    end
    if ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.FAILED_MARCH )
    or ArmyLogic:checkArmyStatus( defenseInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
        LOG_ERROR("beginBattleByStatus attack or defense in failed march")
        return false
    end

    -- 发起战斗
    if not ArmyLogic:checkArmyStatus( defenseInfo.status, Enum.ArmyStatus.BATTLEING ) then
        -- 目标不处于战斗
        if not ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 自己不处于战斗
            if not self:createBattle( _objectIndex, _targetObjectIndex ) then
                LOG_ERROR("beginBattleByStatus LockCreateBattle fail")
                return false
            end
        else
            -- 自己处于战斗
            if not self:joinBattle( _targetObjectIndex, _objectIndex ) then
                LOG_ERROR("beginBattleByStatus joinBattle fail")
                return false
            else
                -- 改变目标
                self:changeAttackTarget( _objectIndex, attackInfo.objectType, _targetObjectIndex )
            end
            -- 更新自己的攻击目标
            self:changeAttackTarget( _objectIndex, attackInfo.objectType, _targetObjectIndex )
        end
    else
        -- 目标处于战斗
        if not ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 自己不处于战斗
            if not self:joinBattle( _objectIndex, _targetObjectIndex ) then
                LOG_ERROR("beginBattleByStatus joinBattle fail")
                return false
            end
        else
            -- 如果是同一场战斗,改变攻击目标
            local selfBattleIndex, selfTmpJoin = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex, true )
            local targetBattleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _targetObjectIndex )
            if selfBattleIndex == targetBattleIndex then
                if selfTmpJoin then
                    -- 自己在战斗中处于临时对象,也加入战斗
                    if not self:joinBattle( _objectIndex, _targetObjectIndex ) then
                        LOG_ERROR("beginBattleByStatus joinBattle fail")
                        return false
                    end
                else
                    -- 改变攻击目标
                    self:changeAttackTarget( _objectIndex, attackInfo.objectType, _targetObjectIndex )
                    -- 判断攻击距离是否过近
                    self:checkTooNearOnBattle( attackInfo, defenseInfo )
                end
            else
                -- 自己也处于战斗
                if not self:mergeBattle( _objectIndex, _targetObjectIndex ) then
                    LOG_ERROR("beginBattleByStatus mergeBattle fail")
                    return false
                else
                    -- 改为战斗状态
                    self:updateObjectStatus( _objectIndex, attackInfo.objectType, true )
                    -- 同步攻击对象
                    MSM.SceneArmyMgr[_objectIndex].post.updateArmyTargetObjectIndex( _objectIndex, _targetObjectIndex )
                end
            end
        end
    end
    return true
end

---@see 根据状态发起具体的战斗操作
function BattleCreate:beginBattleByStatus( _objectIndex, _targetObjectIndex )
    return SM.BattleCreateMgr.req.LockCreateBattle( _objectIndex, _targetObjectIndex )
end

return BattleCreate