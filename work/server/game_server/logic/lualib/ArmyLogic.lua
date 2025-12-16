--[[
* @file : ArmyLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Mon Dec 30 2019 11:02:43 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 军队相关逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local ArmyTrainLogic = require "ArmyTrainLogic"
local HeroLogic = require "HeroLogic"
local ArmyDef = require "ArmyDef"
local RoleCacle = require "RoleCacle"
local MapObjectLogic = require "MapObjectLogic"
local MapLogic = require "MapLogic"
local Random = require "Random"
local CommonCacle = require "CommonCacle"
local LogLogic = require "LogLogic"
local SoldierLogic = require "SoldierLogic"
local timeCore = require "timer.core"

local ArmyLogic = {}

---@see 获取部队信息
---@return table<int, defaultArmyAttrClass>|defaultArmyAttrClass
function ArmyLogic:getArmy( _rid, _armyIndex, _fields )
    return MSM.d_army[_rid].req.Get( _rid, _armyIndex, _fields )
end

---@see 更新部队指定数据
function ArmyLogic:setArmy( _rid, _armyIndex, _fields, _data )
    if not _armyIndex then
        LOG_ERROR("setArmy rid(%s) armyIndex is null, stack:%s", tostring(_rid), debug.traceback())
        return
    end
    return MSM.d_army[_rid].req.Set( _rid, _armyIndex, _fields, _data )
end

---@see 同步部队属性
function ArmyLogic:syncArmy( _rid, _armyIndex, _field, _haskv, _block )
    local armyInfo
    local syncInfo = {}
    if not _haskv then
        if type( _armyIndex ) == "table" then
            -- 同步多个部队
            for _, armyIndex in pairs( _armyIndex ) do
                armyInfo = self:getArmy( _rid, armyIndex )
                armyInfo.armyIndex = armyIndex
                syncInfo[armyIndex] = armyInfo
            end
        else
            armyInfo = self:armyInfo( _rid, _armyIndex )
            armyInfo.armyIndex = _armyIndex
            syncInfo[_armyIndex] = armyInfo
        end
    else
        if _armyIndex then
            local syncField = table.copy( _field, true )
            syncField.armyIndex = _armyIndex
            syncInfo[_armyIndex] = syncField
        else
            syncInfo = _field
        end
    end
    -- 同步
    Common.syncMsg( _rid, "Army_ArmyList",  { armyInfo = syncInfo }, _block )
end

---@see 推送所有部队信息
function ArmyLogic:pushAllArmy( _rid )
    local allArmy = self:getArmy( _rid ) or {}
    local syncArmyInfos = {}
    for armyIndex, armyInfo in pairs( allArmy ) do
        if armyInfo then
            syncArmyInfos[armyIndex] = {
                armyIndex = armyIndex,
                mainHeroId = armyInfo.mainHeroId,
                deputyHeroId = armyInfo.deputyHeroId,
                soldiers = armyInfo.soldiers,
                resourceLoads = armyInfo.resourceLoads,
                status = armyInfo.status,
                collectResource = armyInfo.collectResource,
                preCostActionForce = armyInfo.preCostActionForce,
                arrivalTime = armyInfo.arrivalTime,
                path = armyInfo.path,
                targetType = armyInfo.targetType,
                targetArg = armyInfo.targetArg,
                minorSoldiers = armyInfo.minorSoldiers,
                startTime = armyInfo.startTime,
                objectIndex = armyInfo.objectIndex,
                killMonsterReduceVit = armyInfo.killMonsterReduceVit
            }
        end
    end

    -- 同步
    Common.syncMsg( _rid, "Army_ArmyList",  { armyInfo = syncArmyInfos } )
end

---@see 获取空闲部队索引
function ArmyLogic:getFreeArmyIndex( _rid )
    return MSM.ArmyDisbandMgr[_rid].req.getNewArmyIndex( _rid )
end

---@see 获取部队容量上限
function ArmyLogic:getArmySoldierLimit( _rid, _mainHeroId, _deputyHeroId )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.troopsCapacity, Enum.Role.troopsCapacityMulti } )
    local sHero = CFG.s_Hero:Get( _mainHeroId )
    local mainHeroInfo = HeroLogic:getHero( _rid, _mainHeroId )
    local heroLevelId = sHero.rare * 10000 + mainHeroInfo.level
    local sHeroLevel = CFG.s_HeroLevel:Get( heroLevelId )
    local troopsCapacityMulti = roleInfo.troopsCapacityMulti or 0

    -- 统帅技能天赋影响
    if _mainHeroId and _mainHeroId > 0 then
        troopsCapacityMulti = troopsCapacityMulti + HeroLogic:getHeroAttr( _rid, _mainHeroId, Enum.Role.troopsCapacityMulti )
    end
    if _deputyHeroId and _deputyHeroId > 0 then
        troopsCapacityMulti = troopsCapacityMulti + HeroLogic:getHeroAttr( _rid, _deputyHeroId, Enum.Role.troopsCapacityMulti, true )
    end

    local soldierLimit = ( ( roleInfo.troopsCapacity or 0 ) + sHeroLevel.soldiers ) * ( 1000 + troopsCapacityMulti ) / 1000
    return soldierLimit
end

---@see 创建军队
function ArmyLogic:createArmy( _rid, _mainHeroId, _deputyHeroId, _soldiers, _preCostActionForce, _targetType, _targetArg, _status, _armyIndex )
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.soldiers, Enum.Role.level, Enum.Role.troopsDispatchNumber,
        Enum.Role.troopsCapacity, Enum.Role.troopsCapacityMulti, Enum.Role.iggid
    } )

    local TransportLogic = require "TransportLogic"
    if not TransportLogic:checkTroopNum( _rid ) then
        LOG_ERROR("rid(%d) createArmy, troop full", _rid)
        return nil, nil, ErrorCode.ROLE_TROOP_FULL
    end

    -- 角色是否已拥有主将
    if not HeroLogic:checkHeroExist( _rid, _mainHeroId ) then
        LOG_ERROR("rid(%d) createArmy, mainHeroId(%d) not exist", _rid, _mainHeroId)
        return nil, nil, ErrorCode.ROLE_HERO_NOT_EXIST
    end

    -- 角色是否已拥有副将
    if not HeroLogic:checkHeroExist( _rid, _deputyHeroId ) then
        LOG_ERROR("rid(%d) createArmy, deputyHeroId(%d) not exist", _rid, _deputyHeroId)
        return nil, nil, ErrorCode.ROLE_HERO_NOT_EXIST
    end

    -- 主将、副将是否处于待命状态
    if not HeroLogic:checkHeroIdle( _rid, { _mainHeroId, _deputyHeroId } ) then
        LOG_ERROR("rid(%d) createArmy, mainHeroId(%d) not wait status", _rid, _mainHeroId)
        return nil, nil, ErrorCode.ROLE_HERO_NOT_WAIT_STATUS
    end

    -- 选择副将，主将是否已达三星
    local mainHeroInfo = HeroLogic:getHero( _rid, _mainHeroId )
    if _deputyHeroId and _deputyHeroId > 0 and mainHeroInfo.star < 3 then
        LOG_ERROR("rid(%d) createArmy, mainHeroId(%d) star(%d) not enough", _rid, _mainHeroId, mainHeroInfo.star)
        return nil, nil, ErrorCode.ROLE_HERO_STAR_NOT_ENOUGH
    end

    local soldierSum = 0
    local newSoldiers = {}
    for _, soldierInfo in pairs( _soldiers ) do
        if not roleInfo.soldiers[soldierInfo.id] or roleInfo.soldiers[soldierInfo.id].num < soldierInfo.num then
            LOG_ERROR("rid(%d) createArmy, soldier type(%d) level(%d) not enough", _rid, soldierInfo.type, soldierInfo.level)
            return nil, nil, ErrorCode.ROLE_SOLDIER_NOT_ENOUGH
        end
        soldierSum = soldierSum + soldierInfo.num
        if soldierInfo.num > 0 then
            newSoldiers[soldierInfo.id] = soldierInfo
        end
    end

    -- 选择兵种数量是否大于0
    if soldierSum <= 0 then
        LOG_ERROR("rid(%d) createArmy, role not select soldier", _rid)
        return nil, nil, ErrorCode.ROLE_NOT_SELECT_SOLDIER
    end

    local troopsCapacity = self:getArmySoldierLimit( _rid, _mainHeroId, _deputyHeroId )
    -- 士兵总数是否小于部队容量
    if soldierSum > troopsCapacity then
        LOG_ERROR("rid(%d) createArmy, soldier(%d) too much", _rid, soldierSum)
        return nil, nil, ErrorCode.ROLE_SOLDIER_TOO_MUCH
    end

    local armyIndex = _armyIndex or self:getFreeArmyIndex( _rid, roleInfo.troopsDispatchNumber )
    local mainHeroLevel, deputyHeroLevel
    mainHeroLevel = HeroLogic:getHero( _rid, _mainHeroId, Enum.Hero.level )
    if _deputyHeroId and _deputyHeroId > 0 then
        deputyHeroLevel = HeroLogic:getHero( _rid, _deputyHeroId, Enum.Hero.level )
    end

    -- 设置部队信息
    local armyInfo = ArmyDef:getDefaultArmyAttr()
    armyInfo.armyIndex = armyIndex
    armyInfo.mainHeroId = _mainHeroId
    armyInfo.deputyHeroId = _deputyHeroId
    armyInfo.soldiers = newSoldiers
    armyInfo.preCostActionForce = _preCostActionForce or 0
    armyInfo.targetType = _targetType
    armyInfo.status = _status
    armyInfo.targetArg = _targetArg or {}
    armyInfo.mainHeroLevel = mainHeroLevel
    armyInfo.deputyHeroLevel = deputyHeroLevel
    armyInfo.isInRally = ( _status == Enum.ArmyStatus.RALLY_WAIT )
    armyInfo.armyCountMax = soldierSum

    if armyInfo.isInRally then
        -- 发起集结
        if _targetArg and _targetArg.targetObjectIndex then
            table.mergeEx( armyInfo.targetArg, self:getArmyRallyMarchTargetArg( _targetArg.targetObjectIndex ) )
        end
    end

    -- 预扣除角色行动力
    if _preCostActionForce and _preCostActionForce > 0 then
        RoleLogic:addActionForce( _rid, - _preCostActionForce, nil, Enum.LogType.ATTACK_COST_ACTION )
    end

    -- 添加部队信息
    local ret = MSM.d_army[_rid].req.Add( _rid, armyIndex, armyInfo )
    if not ret then
        LOG_ERROR("createArmy, add record to d_army fail, rid(%d) armyIndex(%d)", _rid, armyIndex)
        return
    end

    local soldiers = roleInfo.soldiers
    -- 计算剩余士兵信息
    for _, soldierInfo in pairs( newSoldiers ) do
        if soldiers[soldierInfo.id] then
            soldiers[soldierInfo.id].num = soldiers[soldierInfo.id].num - soldierInfo.num
        end
    end

    -- 减少士兵数量
    SoldierLogic:subSoldier( _rid, _soldiers )
    -- 通知客户端部队信息
    self:syncArmy( _rid, armyIndex, armyInfo, true )
    -- 士兵减少处理
    ArmyLogic:subSoldierCallback( _rid, newSoldiers )

    -- 驻防修改
    local BuildingLogic = require "BuildingLogic"
    BuildingLogic:changeDefendHero( _rid )

    LogLogic:roleArmyChange( {
        logType = Enum.LogType.CREATE_ARMY, iggid = roleInfo.iggid, soldiers = newSoldiers,
        mainHeroId = _mainHeroId or 0, deputyHeroId = _deputyHeroId or 0, rid = _rid, armyIndex = armyIndex
    } )

    return armyIndex, armyInfo
end

---@see 更新军队状态
function ArmyLogic:updateArmyStatus( _rid, _armyIndex, _status, _noSync, _block )
    self:setArmy( _rid, _armyIndex, { [Enum.Army.status] = _status } )
    if not _noSync then
        -- 通知客户端
        self:syncArmy( _rid, _armyIndex, { [Enum.Army.status] = _status }, true, _block )
    end
end

---@see 更新军队信息
function ArmyLogic:updateArmyInfo( _rid, _armyIndex, _changeArmyInfo, _noSync )
    self:setArmy( _rid, _armyIndex, _changeArmyInfo )
    if not _noSync then
        -- 通知客户端
        self:syncArmy( _rid, _armyIndex, _changeArmyInfo, true )
    end
end

---@see 军队采集活动进度设置
function ArmyLogic:ActivityRoleMgr( _rid, _type, _type2, _resourceNum )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, _type, 1 )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.COLLECTION_ALL_NUM, _resourceNum )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.COLLECTION_RES_COUNT, 1 )
    MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, _type2, _resourceNum )
end

---@see 解散军队
function ArmyLogic:disbandArmy( _rid, _armyIndex, _noSync, _isReboot )
    assert(_armyIndex and _armyIndex > 0, string.format("rid(%s) armyIndex(%s) error", tostring(_rid), tostring(_armyIndex)) )
    LOG_INFO("rid(%d) disbandArmy armyIndex(%d)", _rid, _armyIndex)
    local ret, err = xpcall(MSM.ArmyDisbandMgr[_rid].req.disbandArmy, debug.traceback, _rid, _armyIndex, _noSync, _isReboot )
    if not ret then
        LOG_ERROR("disbandArmy err:%s", err)
    end
end

---@see 角色登录处理部队信息
function ArmyLogic:checkArmyOnRoleLogin( _rid )
    local HolyLandLogic = require "HolyLandLogic"
    local GuildBuildLogic = require "GuildBuildLogic"

    local allArmy = self:getArmy( _rid ) or {}
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    local objectIndex, targetObjectIndex, targetInfo, reinforces, armyExist
    for armyIndex, armyInfo in pairs( allArmy ) do
        objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
        if not objectIndex then
            repeat
                -- 集结等待中,不能解散(这里肯定是队员,队长会有objectIndex,或者是未出发的集结队伍)
                if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_WAIT ) -- 集结等待
                or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_BATTLE ) -- 集结战斗
                or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_MARCH ) -- 集结行军
                then
                    local exsitRally = false
                    -- 如果有联盟
                    if guildId > 0 then
                        -- 如果联盟战争还存在,则不解散
                        local allRallyInfo = MSM.RallyMgr[guildId].req.getGuildRallyInfo( guildId )
                        if allRallyInfo then
                            for _, rallyInfo in pairs(allRallyInfo) do
                                -- 部队还在联盟战争中
                                if rallyInfo.rallyArmy[_rid] then
                                    exsitRally = true
                                end
                            end
                        end
                    end

                    -- 联盟战争还存在,不解散(服务器重启的时候,如果联盟战争不存在了,要解散部队)
                    if exsitRally then
                        break -- 这里会终止下面的逻辑,就不会解散队伍
                    end
                end

                -- 驻守或者采集
                if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING )
                or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                    targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex or nil
                    if targetObjectIndex then
                        targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
                        if targetInfo then
                            armyExist = false
                            if MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
                                -- 圣地关卡
                                reinforces = HolyLandLogic:getHolyLand( targetInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
                                for _, reinforce in pairs( reinforces ) do
                                    if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                                        armyExist = true
                                        break
                                    end
                                end
                            elseif MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType )
                                or MapObjectLogic:checkIsGuildResourceCenterObject( targetInfo.objectType ) then
                                -- 联盟建筑
                                reinforces = GuildBuildLogic:getGuildBuild( targetInfo.guildId, targetInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
                                for _, reinforce in pairs( reinforces ) do
                                    if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                                        armyExist = true
                                        break
                                    end
                                end
                            elseif targetInfo.objectType == Enum.RoleType.CITY then
                                -- 城市
                                if armyInfo.reinforceRid then
                                    reinforces = RoleLogic:getRole( armyInfo.reinforceRid, Enum.Role.reinforces ) or {}
                                    for reinforceRid, reinforce in pairs( reinforces ) do
                                        if reinforceRid == _rid and reinforce.armyIndex == armyIndex then
                                            armyExist = true
                                            break
                                        end
                                    end
                                end
                            else
                                armyExist = true
                            end

                            if not armyExist then
                                self:disbandArmy( _rid, armyIndex, true )
                            end
                        else
                            self:disbandArmy( _rid, armyIndex, true )
                        end
                    else
                        self:disbandArmy( _rid, armyIndex, true )
                    end
                else
                    self:disbandArmy( _rid, armyIndex, true )
                end
            until true
        end
    end
end

---@see 计算部队行军速度
function ArmyLogic:cacleArmyWalkSpeed( _rid, _armyInfo, _addSpeedAttr, _isInGuildTerritory, _isRally )
    --[[
        分别计算部队中每个兵种的行军速度，取其中最慢的那个作为部队行军速度。
        兵种行军速度 = 兵种默认行军速度 *（1000 + 部队的行军速度加成）/1000
    ]]
    local roleInfo = RoleLogic:getRole( _rid )
    if not _addSpeedAttr then
        _addSpeedAttr = {}
    end
    local slowSpeed = -1
    local soldierSpeed
    if not _armyInfo.soldiers then
        _armyInfo.soldiers = {}
    end
    for _, soldierInfo in pairs(_armyInfo.soldiers) do
        local sArms = CFG.s_Arms:Get( soldierInfo.id )
        if sArms then
            if sArms.armsType == Enum.ArmyType.INFANTRY then
                -- 步兵
                soldierSpeed = ( ( _addSpeedAttr.infantryMoveSpeed or 0 ) + sArms.speed )
                                * ( 1000 + roleInfo.infantryMoveSpeedMulti + ( _addSpeedAttr.infantryMoveSpeedMulti or 0 ) ) / 1000
            elseif sArms.armsType == Enum.ArmyType.CAVALRY then
                -- 骑兵
                soldierSpeed = ( ( _addSpeedAttr.cavalryMoveSpeed or 0 ) + sArms.speed )
                                * ( 1000 + roleInfo.cavalryMoveSpeedMulti + ( _addSpeedAttr.cavalryMoveSpeedMulti or 0 ) ) / 1000
            elseif sArms.armsType == Enum.ArmyType.ARCHER then
                -- 弓兵
                soldierSpeed = ( ( _addSpeedAttr.bowmenMoveSpeed or 0 ) + sArms.speed )
                                * ( 1000 + roleInfo.bowmenMoveSpeedMulti + ( _addSpeedAttr.bowmenMoveSpeedMulti or 0 ) ) / 1000
            elseif sArms.armsType == Enum.ArmyType.SIEGE_UNIT then
                -- 攻城器械
                soldierSpeed = ( ( _addSpeedAttr.siegeCarMoveSpeed or 0 ) + sArms.speed )
                                * ( 1000 + roleInfo.siegeCarMoveSpeedMulti + ( _addSpeedAttr.siegeCarMoveSpeedMulti or 0 ) ) / 1000
            else
                soldierSpeed = sArms.speed
            end

            if slowSpeed == -1 or slowSpeed > soldierSpeed then
                slowSpeed = soldierSpeed
            end
        end
    end

    if slowSpeed == -1 then
        slowSpeed = 1
    end

    -- 计算部队行军速度加成
    local marchSpeedMulti = roleInfo.marchSpeedMulti + ( _addSpeedAttr.marchSpeedMulti or 0 )
    -- 联盟领地移动速度加成
    local allTerrMoveSpeedMulti = 0
    if _isInGuildTerritory then
        allTerrMoveSpeedMulti = roleInfo.allTerrMoveSpeedMulti + ( _addSpeedAttr.allTerrMoveSpeedMulti or 0 )
    end

    -- 如果是集结部队
    local rallyMoveSpeedMulti = 0
    if _isRally then
        rallyMoveSpeedMulti = roleInfo.rallyMoveSpeedMulti + _addSpeedAttr.rallyMoveSpeedMulti
    end

    return math.floor( math.max( slowSpeed * 0.1, slowSpeed * ( 1 + ( marchSpeedMulti + allTerrMoveSpeedMulti + rallyMoveSpeedMulti ) / 1000 ) ) )
end

---@see 军队士兵ID转换
function ArmyLogic:transSoldierId( _rid, _soldiers )
    local soldiers = {}
    for _, soldierInfo in pairs(_soldiers) do
        local soldierId = ArmyTrainLogic:getArmsConfig( _rid, soldierInfo.type, soldierInfo.level ).ID
        soldierInfo.id = soldierId
        soldiers[soldierId] = soldierInfo
    end
    return soldiers
end

---@see 计算到达时间
function ArmyLogic:cacleArrivalTime( _path, _speed )
    local distance
    local now = timeCore.getmillisecond() / 1000
    local time = now
    for i = 1, #_path do
        if _path[i] and _path[i+1] then
            distance = math.sqrt( (_path[i].x - _path[i+1].x ) ^ 2 + ( _path[i].y - _path[i+1].y ) ^ 2 )
            time = time + distance / _speed
        end
    end
    local arrivalTime = math.ceil( time )
    return arrivalTime
end

---@see 计算到达时间
function ArmyLogic:cacleDistance( _path )
    local distance
    for i = 1, #_path do
        if _path[i+1] then
            distance = math.sqrt( (_path[i].x - _path[i+1].x ) ^ 2 + ( _path[i].y - _path[i+1].y ) ^ 2 )
        end
    end
    return distance
end

---@see 计算部队数量
function ArmyLogic:getArmySoldierCount( _soldiers, _rid, _armyIndex )
    local allArmyCount = 0
    if not _soldiers and _rid and _armyIndex then
        _soldiers = self:getArmy( _rid, _armyIndex, Enum.Army.soldiers )
    end
    if not _soldiers or table.empty(_soldiers) then
        return 0
    end
    for _, soldierInfo in pairs(_soldiers) do
        allArmyCount = allArmyCount + soldierInfo.num
    end
    return allArmyCount
end

---@see 判断军队是否处于行军状态
function ArmyLogic:checkArmyWalkStatus( _status )
    if self:checkArmyStatus( _status, Enum.ArmyStatus.SPACE_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.ATTACK_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.COLLECT_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.REINFORCE_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.RALLY_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.RALLY_JOIN_MARCH )
    or self:checkArmyStatus( _status, Enum.ArmyStatus.RETREAT_MARCH ) then
        return true
    end
end

---@see 通知地图上的军队退出战斗
function ArmyLogic:notifyArmyExitBattle()
    local sharedata = require "skynet.sharedata"
    local serverNum = sharedata.query( Enum.Share.MultiSnaxNum ).num
    for i = 1, serverNum do
        MSM.SceneArmyMgr[i].req.notifyArmyBattleExitAndBackCity()
    end
end

---@see 根据行军目标类型获取军队行军状态
function ArmyLogic:getArmyStatusByTargetType( _targetType )
    if _targetType == Enum.MapMarchTargetType.COLLECT then
        -- 资源采集
        return Enum.ArmyStatus.COLLECT_MARCH
    elseif _targetType == Enum.MapMarchTargetType.ATTACK then
        -- 进攻行军
        return Enum.ArmyStatus.ATTACK_MARCH
    elseif _targetType == Enum.MapMarchTargetType.REINFORCE then
        -- 增援行军
        return Enum.ArmyStatus.REINFORCE_MARCH
    elseif _targetType == Enum.MapMarchTargetType.RALLY then
        -- 集结行军
        return Enum.ArmyStatus.RALLY_JOIN_MARCH
    elseif _targetType == Enum.MapMarchTargetType.RALLY_ATTACK then
        -- 集结攻击行军
        return Enum.ArmyStatus.RALLY_MARCH
    elseif _targetType == Enum.MapMarchTargetType.RETREAT then
        -- 撤退行军
        return Enum.ArmyStatus.RETREAT_MARCH
    elseif _targetType == Enum.MapMarchTargetType.SPACE then
        -- 空地行军
        return Enum.ArmyStatus.SPACE_MARCH
    end
end

---@see 判断统帅是否处于待命状态
function ArmyLogic:checkHeroStatue( _rid, _heroId )
    local allArmy = self:getArmy( _rid ) or {}
    for _, armyInfo in pairs( allArmy ) do
        if armyInfo.mainHeroId == _heroId or ( armyInfo.deputyHeroId and armyInfo.deputyHeroId == _heroId ) then
            return false
        end
    end
    return true
end

---@see 判断部队是否有指定状态
function ArmyLogic:checkArmyStatus( _armyStatus, _checkStatus )
    if not _armyStatus then
        return
    end
    return ( _armyStatus & _checkStatus ) ~= 0
end

---@see 移除部队指定状态
function ArmyLogic:delArmyStatus( _armyStatus, _removeStatus )
    if not _armyStatus then
        return
    end
    return _armyStatus & (~_removeStatus)
end

---@see 添加部队指定状态
function ArmyLogic:addArmyStatus( _armyStatus, _addStatus )
    if not _armyStatus then
        return
    end
    return _armyStatus | _addStatus
end

---@see 士兵增加处理回调
function ArmyLogic:addSoldierCallback( _rid, _soldiers, _isArmyBack )
    -- 如果处于守城战,通知战斗服务器士兵加入战斗
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local cityInfo = MSM.SceneCityMgr[cityIndex].req.getCityInfo( cityIndex )
    if cityInfo then
        if self:checkArmyStatus( cityInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 处于战斗中,通知战斗服务器
            local BattleAttrLogic = require "BattleAttrLogic"
            BattleAttrLogic:notifyBattleAddSoldier( cityIndex, _soldiers, _rid, 0 )
            local armyCount = ArmyLogic:getArmySoldierCount( _soldiers )
            BattleAttrLogic:reinforceJoinBattle( cityIndex, _rid, 0, armyCount, not _isArmyBack, _isArmyBack )
        end
    end
end

---@see 士兵减少处理回调
function ArmyLogic:subSoldierCallback( _rid, _soldiers )
    -- 如果处于守城战,通知战斗服务器士兵脱离战斗
    local cityIndex = RoleLogic:getRoleCityIndex( _rid )
    local cityInfo = MSM.SceneCityMgr[cityIndex].req.getCityInfo( cityIndex )
    if cityInfo then
        if self:checkArmyStatus( cityInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 处于战斗中,通知战斗服务器
            local BattleAttrLogic = require "BattleAttrLogic"
            BattleAttrLogic:notifyBattleSubSoldier( cityIndex, _soldiers, nil, _rid, 0 )
        end
    end
end

---@see 计算部队最大怒气
function ArmyLogic:cacleArmyMaxSp( _skills )
    local maxSp = 0
    for _, skillInfo in pairs(_skills) do
        local sSkillInfo = CFG.s_HeroSkill:Get( skillInfo.skillId )
        if sSkillInfo and sSkillInfo.skillBattleID then
            for _, skilldBattleId in pairs( sSkillInfo.skillBattleID ) do
                local sSkillBattleInfo = CFG.s_SkillBattle:Get( skilldBattleId * 100 + skillInfo.skillLevel )
                if sSkillBattleInfo and sSkillBattleInfo.autoActive and sSkillBattleInfo.autoActive == Enum.SkillTrigger.ANGER_MORE then
                    if maxSp < sSkillBattleInfo.autoActiveParm then
                        maxSp = sSkillBattleInfo.autoActiveParm
                    end
                end
            end
        end
    end
    return maxSp
end

---@see 计算部队负载
function ArmyLogic:cacleArmyCapacity( _rid, _soldiers )
    local troopsSpaceMulti = RoleLogic:getRole( _rid, Enum.Role.troopsSpaceMulti ) or 0
    local sArms
    local resourceLoad = 0
    for soldierId, soldierInfo in pairs(_soldiers) do
        -- 兵种的最终运载量 = 兵种基础运载 * (1 + 运载百分比属性加成/1000)
        sArms = CFG.s_Arms:Get( soldierId )
        resourceLoad = resourceLoad + math.floor( sArms.capacity * soldierInfo.num * ( 1 + troopsSpaceMulti / 1000 ) )
    end
    return resourceLoad
end

---@see 获取目标周围的8个位置
function ArmyLogic:getObjectPos_8_Near( _pos, _radius, _fromPos )
    local allPos = {}
    for aroundPos = 1, 8 do
        table.insert( allPos, self:cacleAroudPosXY_8( _pos, aroundPos, _radius ) )
    end

    local retPos
    for _, fixPos in pairs(allPos) do
        -- 过滤可以走的位置
        if MapLogic:checkPosIdle( _pos, 0 ) then
            if not retPos then
                retPos = fixPos
            else
                local distanceNew = math.sqrt( (_fromPos.x - fixPos.x ) ^ 2 + ( _fromPos.y - fixPos.y ) ^ 2 )
                local distanceOld = math.sqrt( (_fromPos.x - retPos.x ) ^ 2 + ( _fromPos.y - retPos.y ) ^ 2 )
                if distanceNew < distanceOld then
                    retPos = fixPos
                end
            end
        end
    end

    return retPos
end

---@see 计算目标位置处于指定坐标的方位1to8
---@param _pos integer 目标位置
---@param _targetPos integer 指定位置
function ArmyLogic:caclePosAround_8( _pos, _targetPos )
    -- 计算目标与指定坐标的角度
    local ArmyWalkLogic = require "ArmyWalkLogic"
    local angle = ArmyWalkLogic:cacleAnagle( _targetPos, _pos )
    if angle < 0 then
        angle = 360 + angle
    end
    -- 按45°划分方位
    local aroundPos = math.floor( angle / 45 + 1 )
    if aroundPos > 8 then
        aroundPos = 8
    end
    return aroundPos
end

---@see 根据半径计算目标方位的位置
function ArmyLogic:cacleAroudPosXY_8( _pos, _aroundPos, _radius )
    local angle = ( _aroundPos - 1 ) * 45
    if angle > 180 then
        angle = angle - 360
    end
    local xoffset = _radius * math.cos( math.rad(angle) )
    local yoffset = _radius * math.sin( math.rad(angle) )
    return { x = math.floor( _pos.x + xoffset ), y = math.floor( _pos.y + yoffset ) }
end

---@see 计算目标位置处于指定坐标的方位1to12
---@param _pos integer 目标位置
---@param _targetPos integer 指定位置
function ArmyLogic:caclePosAround_12( _pos, _targetPos )
    -- 计算目标与指定坐标的角度
    local ArmyWalkLogic = require "ArmyWalkLogic"
    local angle = ArmyWalkLogic:cacleAnagle( _targetPos, _pos )
    if angle < 0 then
        angle = 360 + angle
    end
    -- 按30°划分方位
    local aroundPos = math.floor( angle / 30 + 1 )
    if aroundPos > 12 then
        aroundPos = 12
    end
    return aroundPos
end

---@see 计算目标位置处于指定坐标的方位1to6
---@param _pos integer 目标位置
---@param _targetPos integer 指定位置
function ArmyLogic:caclePosAround_6( _pos, _targetPos, _strongHoldId )
    -- 计算目标与指定坐标的角度
    local ArmyWalkLogic = require "ArmyWalkLogic"
    local angle = ArmyWalkLogic:cacleAnagle( _targetPos, _pos )
    local rawAngle = angle
    if angle < 0 then
        angle = 360 + angle
    end

    local standAroundPos = { 1, 2, 3, 4, 5 ,6, 7, 8 }
    local posTo = CFG.s_StrongHoldData:Get( _strongHoldId, "posTo" )
    if not posTo then
        return 3, standAroundPos
    end
    -- 按45°划分方位
    local aroundPos = math.floor( angle / 45 + 1 )
    if aroundPos > 8 then
        aroundPos = 8
    end

    if posTo == 180 then
        -- 1和5无效
        if aroundPos == 1 then
            if rawAngle > 0 then
                aroundPos = 2
            else
                aroundPos = 8
            end
        elseif aroundPos == 5 then
            if rawAngle > 0 then
                aroundPos = 4
            else
                aroundPos = 6
            end
        end
        if aroundPos > 0 and aroundPos < 4 then
            -- 上方
            standAroundPos = { nil, 2, 3, 4 }
        else
            -- 下方
            standAroundPos = { nil, nil, nil, nil, nil, 6, 7, 8 }
        end
    elseif posTo == 135 then
        -- 2和6无效
        if aroundPos == 2 then
            if rawAngle > 0 then
                aroundPos = 3
            else
                aroundPos = 1
            end
        elseif aroundPos == 6 then
            if rawAngle > 0 then
                aroundPos = 5
            else
                aroundPos = 7
            end
        end
        if aroundPos > 2 and aroundPos < 6 then
            -- 上方
            standAroundPos = { nil, nil, 3, 4, 5 }
        else
            -- 下方
            standAroundPos = { 1, nil, nil, nil, nil, nil, 7, 8 }
        end
    end
    return aroundPos, standAroundPos
end

---@see 根据半径计算目标方位的位置
function ArmyLogic:cacleAroudPosXY_12( _pos, _aroundPos, _radius )
    local angle = ( _aroundPos - 1 ) * 30
    if angle > 180 then
        angle = angle - 360
    end
    local xoffset = _radius * math.cos( math.rad(angle) )
    local yoffset = _radius * math.sin( math.rad(angle) )
    return { x = math.floor( _pos.x + xoffset ), y = math.floor( _pos.y + yoffset ) }
end

---@see 检查部队是否存在
function ArmyLogic:checkArmyExist( _rid, _armyIndex )
    local mainHeroId = self:getArmy( _rid, _armyIndex, Enum.Army.mainHeroId ) or 0
    return mainHeroId > 0
end

---@see 退出联盟时检查是否有在联盟建筑内的部队
function ArmyLogic:checkArmyOnExitGuild( _rid )
    local GuildBuildLogic = require "GuildBuildLogic"
    local BattleCreate = require "BattleCreate"

    local nowTime = os.time()
    local allArmy = self:getArmy( _rid ) or {}
    -- 撤退
    local targetType = Enum.MapMarchTargetType.RETREAT
    -- 回城坐标
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.pos, Enum.Role.iggid } ) or {}
    local cityPos = roleInfo.pos or {}
    -- 城堡地图索引
    local cityObjectIndex = RoleLogic:getRoleCityIndex( _rid )
    local targetObjectInfo, reinforces, reinforceIndex, buildType, allianceCoinReward
    local startTime, guildId, buildIndex, marchArgs, targetObjectIndex, armyObjectIndex, guildBuildTimerFlag
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100
    for armyIndex, armyInfo in pairs( allArmy ) do
        guildBuildTimerFlag = false
        targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex or 0
        if targetObjectIndex > 0 then
            targetObjectInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
            if targetObjectInfo then
                if MapObjectLogic:checkIsGuildBuildObject( targetObjectInfo.objectType ) then
                    -- 角色目标是联盟建筑
                    guildId = targetObjectInfo.guildId
                    buildIndex = targetObjectInfo.buildIndex
                    reinforces = GuildBuildLogic:getGuildBuild( guildId, buildIndex, Enum.GuildBuild.reinforces ) or {}
                    for index, reinforce in pairs( reinforces ) do
                        if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                            reinforceIndex = index
                            startTime = reinforce.startTime
                            reinforces[index] = nil
                            break
                        end
                    end
                    if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH )
                    or ( self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECT_MARCH ) ) then
                        -- 增援行军中或者向联盟资源中心行军中, 返回城内
                        armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
                        MSM.MapMarchMgr[armyObjectIndex].req.marchBackCity( _rid, armyObjectIndex )
                    elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
                        -- 驻守在建筑中
                        if targetObjectInfo.guildBuildStatus == Enum.GuildBuildStatus.BUILDING then
                            -- 正在建造中
                            buildType = GuildBuildLogic:objectTypeToBuildType( targetObjectInfo.objectType )
                            allianceCoinReward = CFG.s_AllianceBuildingType:Get( buildType, "allianceCoinReward" )
                            if allianceCoinReward > 0 then
                                local addGuildBuildPoint = math.floor( allianceCoinReward / 3600 * ( nowTime - startTime ) )
                                if addGuildBuildPoint > 0 then
                                    self:setArmy( _rid, armyIndex, { [Enum.Army.guildBuildPoint] = ( armyInfo.guildBuildPoint or 0 ) + addGuildBuildPoint } )
                                end
                            end
                            guildBuildTimerFlag = true
                            -- 部队离开建造中的联盟建筑
                            LogLogic:guildBuildTroops( {
                                logType = Enum.LogType.ARMY_LEAVE_GUILD_BUILD, iggid = roleInfo.iggid, guildId = guildId,
                                buildIndex = buildIndex, buildType = targetObjectInfo.staticId, rid = _rid, mainHeroId = armyInfo.mainHeroId,
                                deputyHeroId = armyInfo.deputyHeroId, buildTime = nowTime - startTime, soldiers = armyInfo.soldiers
                            } )
                        end
                        -- 驻守中,从建筑退出
                        MSM.SceneGuildBuildMgr[targetObjectIndex].post.onExitGuildDisarm( targetObjectIndex, _rid, armyIndex )
                        self:armyEnterMap( _rid, armyIndex, armyInfo, targetObjectInfo.objectType, Enum.RoleType.CITY,
                                        targetObjectInfo.pos, cityPos, cityObjectIndex, targetType )
                    elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                        -- 联盟资源中心采集中
                        marchArgs = {
                            targetObjectIndex = cityObjectIndex,
                            targetPos = cityPos,
                            targetType = targetType
                        }
                        MSM.GuildTimerMgr[guildId].req.resetResourceCenterTimer( guildId, buildIndex, nil, Enum.GuildResourceCenterReset.MEMBER_LEAVE, _rid, marchArgs )
                        reinforceIndex = nil
                    elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
                        -- 攻击联盟建筑中
                        armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
                        -- 退出战斗
                        BattleCreate:exitBattle( armyObjectIndex, true )
                        -- 返回城市
                        MSM.MapMarchMgr[armyObjectIndex].req.marchBackCity( _rid, armyObjectIndex )
                    end

                    if reinforceIndex then
                        GuildBuildLogic:setGuildBuild( targetObjectInfo.guildId, targetObjectInfo.buildIndex, { [Enum.GuildBuild.reinforces] = reinforces } )
                        -- 推送联盟建筑部队信息到关注角色中
                        GuildBuildLogic:syncGuildBuildArmy( targetObjectIndex, nil, nil, { reinforceIndex } )
                        if guildBuildTimerFlag then
                            -- 重置建造中的联盟建筑定时器
                            MSM.GuildTimerMgr[guildId].req.resetGuildBuildTimer( guildId, buildIndex )
                        end
                    end
                elseif MapObjectLogic:checkIsHolyLandObject( targetObjectInfo.objectType ) then
                    -- 圣地关卡
                    if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH ) then
                        -- 增援行军中
                        self:checkArmyOldTarget( _rid, armyIndex, armyInfo )
                        -- 回城
                        armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
                        MSM.MapMarchMgr[armyObjectIndex].req.marchBackCity( _rid, armyObjectIndex )
                    elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
                        -- 驻守中
                        self:checkArmyOldTarget( _rid, armyIndex, armyInfo )
                        -- 从圣地驻防中退出
                        MSM.SceneHolyLandMgr[targetObjectIndex].post.onExitGuildDisarm( targetObjectIndex, _rid, armyIndex )
                        -- 部队回城
                        self:armyEnterMap( _rid, armyIndex, armyInfo, targetObjectInfo.objectType, Enum.RoleType.CITY,
                                        targetObjectInfo.pos, cityPos, cityObjectIndex, targetType, targetObjectInfo.armyRadius, cityRadius )
                    elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
                        -- 攻击圣地关卡中
                        armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
                        if armyObjectIndex then
                            -- 退出战斗
                            BattleCreate:exitBattle( armyObjectIndex, true )
                            -- 返回城市
                            MSM.MapMarchMgr[armyObjectIndex].req.marchBackCity( _rid, armyObjectIndex )
                        end
                    end
                end
            end
        end
    end
end

---@see 判断是否可以攻击资源内的部队
function ArmyLogic:checkAttacKResourceArmy( _rid, _targetObjectIndex, _onlyCheckArmy )
    local resourceInfo = MSM.SceneResourceMgr[_targetObjectIndex].req.getResourceInfo( _targetObjectIndex )
    if _onlyCheckArmy then
        if resourceInfo.armyIndex and resourceInfo.armyIndex > 0 then
            return true
        else
            return false
        end
    end

    -- 资源内是否有部队
    if not resourceInfo.armyIndex or resourceInfo.armyIndex <= 0 then
        return false
    end

    if _rid and _rid > 0 then
        -- 资源内是否是自己的部队
        if resourceInfo.collectRid == _rid then
            LOG_ERROR("checkAttacKResourceArmy attack self army, rid(%d) objectIndex(%d)", _rid, _targetObjectIndex)
            return false
        end

        -- 资源内是否是同联盟的部队
        local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId ) or 0
        if guildId > 0 then
            if guildId == RoleLogic:getRole( resourceInfo.collectRid, Enum.Role.guildId ) then
                LOG_ERROR("checkAttacKResourceArmy attack self guild, rid(%d) objectIndex(%d)", _rid, _targetObjectIndex)
                -- 同联盟无法攻击
                return false
            end
        end
    end

    -- 获取部队信息
    local armyInfo = self:getResourceArmyInfo( resourceInfo.collectRid, resourceInfo.armyIndex, resourceInfo.pos )
    armyInfo.status = resourceInfo.status
    return true, armyInfo
end

---@see 获取资源点内的部队信息
function ArmyLogic:getResourceArmyInfo( _rid, _armyIndex, _pos )
    local armyInfo = self:getArmy( _rid, _armyIndex )
    local skills = HeroLogic:getRoleAllHeroSkills( _rid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
    local roleInfo = RoleLogic:getRole( _rid )
    local objectAttr = RoleCacle:getRoleBattleAttr( _rid, roleInfo )
    return  {
        pos = _pos,
        rid = _rid,
        armyIndex = armyInfo.armyIndex,
        mainHeroId = armyInfo.mainHeroId,
        mainHeroLevel = armyInfo.mainHeroLevel,
        deputyHeroId = armyInfo.deputyHeroId,
        deputyHeroLevel = armyInfo.deputyHeroLevel,
        soldiers = armyInfo.soldiers,
        armyCount = ArmyLogic:getArmySoldierCount( armyInfo.soldiers ),
        skills = skills,
        objectAttr = objectAttr,
        power = RoleCacle:cacleArmyPower( roleInfo ),
        maxSp = self:cacleArmyMaxSp( skills ),
    }
end

---@see 获取城内的所有部队.包含增援和警戒塔
function ArmyLogic:getCityAllArmyCount( _rid, _noCacleReinforceRid )
    local roleInfo = RoleLogic:getRole( _rid )
    local ArmyCount = self:getArmySoldierCount( roleInfo.soldiers )
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = roleInfo.reinforces
    if reinforces and not table.empty( reinforces ) then
        -- 增援的部队加入守城中
        for reinforceRid, reinforceInfo in pairs(reinforces) do
            if not _noCacleReinforceRid or _noCacleReinforceRid ~= reinforceRid then
                ArmyCount = ArmyCount + self:getArmySoldierCount( reinforceInfo.soldiers )
            end
        end
    end

    -- 添加警戒塔
    local BuildingLogic = require "BuildingLogic"
    local guardTowerLevel = BuildingLogic:getBuildingLv( _rid, Enum.BuildingType.GUARDTOWER )
    if guardTowerLevel and guardTowerLevel > 0 then
        local guardTowerHp = RoleLogic:getRole( _rid, Enum.Role.guardTowerHp )
        if guardTowerHp and guardTowerHp > 0 then
            ArmyCount = ArmyCount + guardTowerHp
        end
    end

    return ArmyCount
end

---@see 获取城内守城部队信息
function ArmyLogic:getCityDefenseArmyInfo( _targetArmyInfo )
    -- 判断城墙内是否有驻守的将领
    local roleInfo = RoleLogic:getRole( _targetArmyInfo.rid )
    _targetArmyInfo.objectAttr = RoleCacle:getRoleBattleAttr( _targetArmyInfo.rid, roleInfo )
    _targetArmyInfo.mainHeroId = roleInfo.mainHeroId
    _targetArmyInfo.deputyHeroId = roleInfo.deputyHeroId
    -- 主将等级
    _targetArmyInfo.mainHeroLevel = HeroLogic:getHeroLevel( _targetArmyInfo.rid, roleInfo.mainHeroId )
    -- 副将等级
    _targetArmyInfo.deputyHeroLevel = HeroLogic:getHeroLevel( _targetArmyInfo.rid, roleInfo.deputyHeroId )
    -- 获取城内的部队
    _targetArmyInfo.soldiers = roleInfo.soldiers
    -- 城主设置为队长
    _targetArmyInfo.rallyLeader = _targetArmyInfo.rid
    -- 设置为加入集结的士兵
    _targetArmyInfo.rallySoldiers = {
        [_targetArmyInfo.rid] = { [0] = table.copy( roleInfo.soldiers, true ) }
    }
    -- 加入的将领
    _targetArmyInfo.rallyHeros = {
        [_targetArmyInfo.rid] = { [0] = {
                                            mainHeroId = roleInfo.mainHeroId,
                                            deputyHeroId = roleInfo.deputyHeroId,
                                            mainHeroLevel = _targetArmyInfo.mainHeroLevel,
                                            deputyHeroLevel = _targetArmyInfo.deputyHeroLevel,
                                        }
                            }
    }
    -- 判断是否有增援的部队
    ---@type table<int, defaultReinforceCityClass>
    local reinforces = roleInfo.reinforces
    if reinforces and not table.empty( reinforces ) then
        -- 增援的部队加入守城中
        for reinforceRid, reinforceInfo in pairs(reinforces) do
            _targetArmyInfo.rallySoldiers[reinforceRid] = {}
            _targetArmyInfo.rallySoldiers[reinforceRid][reinforceInfo.armyIndex] = reinforceInfo.soldiers
            for soldierId, soldierInfo in pairs(reinforceInfo.soldiers) do
                if not _targetArmyInfo.soldiers[soldierId] then
                    _targetArmyInfo.soldiers[soldierId] = soldierInfo
                else
                    _targetArmyInfo.soldiers[soldierId].num = _targetArmyInfo.soldiers[soldierId].num + soldierInfo.num
                end
            end

            -- 加入将领信息
            if not _targetArmyInfo.rallyHeros[reinforceRid] then
                _targetArmyInfo.rallyHeros[reinforceRid] = {}
            end

            _targetArmyInfo.rallyHeros[reinforceRid][reinforceInfo.armyIndex] = {
                mainHeroId = reinforceInfo.mainHeroId,
                deputyHeroId = reinforceInfo.deputyHeroId,
                mainHeroLevel = reinforceInfo.mainHeroLevel,
                deputyHeroLevel = reinforceInfo.deputyHeroLevel,
            }
        end
    end
    -- 添加警戒塔
    local BuildingLogic = require "BuildingLogic"
    local guardTowerLevel = BuildingLogic:getBuildingLv( _targetArmyInfo.rid, Enum.BuildingType.GUARDTOWER )
    if guardTowerLevel and guardTowerLevel > 0 then
        local guardTowerHp = RoleLogic:getRole( _targetArmyInfo.rid, Enum.Role.guardTowerHp )
        if not guardTowerHp or guardTowerHp <= 0 then
            -- 刷新燃烧时间
            BuildingLogic:startBurnWall( _targetArmyInfo.rid )
        else
            local sBuildingGuardTower = CFG.s_BuildingGuardTower:Get( guardTowerLevel )
            _targetArmyInfo.soldiers[sBuildingGuardTower.armsID] = {
                id = sBuildingGuardTower.armsID,
                type = Enum.ArmyType.GUARD_TOWER,
                level = guardTowerLevel,
                num = guardTowerHp or 1
            }
            -- 加入rallySoldiers
            _targetArmyInfo.rallySoldiers[_targetArmyInfo.rid][0][sBuildingGuardTower.armsID] = {
                id = sBuildingGuardTower.armsID,
                type = Enum.ArmyType.GUARD_TOWER,
                level = guardTowerLevel,
                num = guardTowerHp or 1
            }
        end
    end
    -- 部队数量
    _targetArmyInfo.armyCount = self:getArmySoldierCount( _targetArmyInfo.soldiers )
    _targetArmyInfo.armyCountMax = _targetArmyInfo.armyCount
    if roleInfo.mainHeroId > 0 or roleInfo.deputyHeroId > 0 then
        -- 获取统帅的天赋和装备
        _targetArmyInfo.talentAttr = HeroLogic:getHeroTalentAttr( _targetArmyInfo.rid, _targetArmyInfo.mainHeroId ).battleAttr
        _targetArmyInfo.equipAttr = HeroLogic:getHeroEquipAttr( _targetArmyInfo.rid, _targetArmyInfo.mainHeroId ).battleAttr
        -- 统帅技能
        _targetArmyInfo.skills = HeroLogic:getRoleAllHeroSkills( _targetArmyInfo.rid, _targetArmyInfo.mainHeroId, _targetArmyInfo.deputyHeroId )
    else
        _targetArmyInfo.skills = {}
    end

    -- 当前战斗力
    RoleCacle:cacleArmyPower( roleInfo )

    -- 最大怒气
    _targetArmyInfo.maxSp = self:cacleArmyMaxSp( _targetArmyInfo.skills )

    return _targetArmyInfo
end

---@see 部队从建筑中移出进入地图行军.从城里新生成也可调用
function ArmyLogic:armyEnterMap( _rid, _armyIndex, _armyInfo, _fromType, _toType, _fromPos, _toPos,
                                _targetIndex, _marchType, _armyRadius, _targetArmyRadius, _isOutCity,
                                _buildArmyIndex, _isDefeat )
    local ArmyWalkLogic = require "ArmyWalkLogic"
    local path
    if not _fromPos then
        -- 增加容错，如果外部_fromPos未传，此处强制让部队从角色城市所在位置出发
        _fromPos = RoleLogic:getRole( _rid, Enum.Role.pos )
    end
    if _isOutCity then
        path = { _fromPos, _toPos }
    else
        path = ArmyWalkLogic:fixPathPoint( _fromType, _toType, { _fromPos, _toPos }, _armyRadius or 0, _targetArmyRadius or 0, nil, _rid )
    end
    -- 更新军队行军状态
    local armyInfo = _armyInfo or self:getArmy( _rid, _armyIndex )
    armyInfo.status = self:getArmyStatusByTargetType( _marchType )
    armyInfo.buildArmyIndex = _buildArmyIndex
    armyInfo.outBuild = true
    local targetArg = armyInfo.targetArg or {}
    targetArg.targetObjectIndex = _targetIndex
    targetArg.pos = nil
    self:setArmy( _rid, armyInfo.armyIndex, { [Enum.Army.status] = armyInfo.status, [Enum.Army.targetArg] = targetArg } )
    -- 通知客户端
    self:syncArmy( _rid, armyInfo.armyIndex, { [Enum.Army.status] = armyInfo.status, [Enum.Army.targetArg] = targetArg }, true )
    -- 生成一个新的对象ID
    local objectIndex = Common.newMapObjectIndex()
    -- 行军部队加入地图
    return MSM.MapMarchMgr[objectIndex].req.armyEnterMap( _rid, objectIndex, armyInfo, path, _marchType, _targetIndex, _isOutCity, _isDefeat )
end

---@see 计算进行增援的部队数量
function ArmyLogic:cacleReinforceArmyCount( _rid )
    local allArmy = self:getArmy( _rid )
    local armyCount = 0
    for _, armyInfo in pairs(allArmy) do
        armyCount = armyCount + self:getArmySoldierCount( armyInfo.soldiers )
    end

    return armyCount
end

---@see 解散集结部队
function ArmyLogic:disbandRallyArmy( _rallyArmys )
    for rallyRid, rallyArmyIndex in pairs(_rallyArmys) do
        self:disbandArmy( rallyRid, rallyArmyIndex )
    end
end

---@see 部队从非自己城市中进入地图的处理
function ArmyLogic:checkArmyOldTarget( _rid, _armyIndex, _armyInfo, _guildLock )
    local GuildBuildLogic = require "GuildBuildLogic"
    local CityReinforceLogic = require "CityReinforceLogic"
    local HolyLandLogic = require "HolyLandLogic"

    local fromPos, fromType, serviceIndex, radius
    local nowTime = os.time()
    _armyInfo = _armyInfo or self:getArmy( _rid, _armyIndex )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.guildId, Enum.Role.iggid, Enum.Role.pos } ) or {}
    local guildId = roleInfo.guildId or 0
    local oldTargetObjectIndex = _armyInfo.targetArg and _armyInfo.targetArg.targetObjectIndex or 0
    local oldTargetInfo
    if oldTargetObjectIndex > 0 then
        oldTargetInfo = MSM.MapObjectTypeMgr[oldTargetObjectIndex].req.getObjectInfo( oldTargetObjectIndex )
    end
    if oldTargetInfo then
        if ArmyLogic:checkArmyStatus( _armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            if MapObjectLogic:checkIsResourceObject( oldTargetInfo.objectType ) then
                -- 资源点采集中
                serviceIndex = MapLogic:getObjectService( oldTargetInfo.pos )
                MSM.ResourceMgr[serviceIndex].req.callBackArmy( _rid, _armyIndex, nil, nil, true )
                fromPos = oldTargetInfo.pos
            elseif MapObjectLogic:checkIsGuildResourceCenterObject( oldTargetInfo.objectType ) then
                -- 联盟资源中心采集中
                if _guildLock then
                    -- 重置联盟资源中心定时器
                    MSM.GuildTimerMgr[guildId].req.resetResourceCenterTimer( guildId, oldTargetInfo.buildIndex, nil, Enum.GuildResourceCenterReset.MEMBER_LEAVE, _rid, nil, true )
                else
                    MSM.GuildMgr[guildId].post.guildBuildArmyMarch( guildId, oldTargetInfo.buildIndex, _rid, _armyIndex, nil, oldTargetObjectIndex, true )
                end

                fromPos = oldTargetInfo.pos
            end
        else
            if oldTargetInfo.objectType == Enum.RoleType.CITY then
                -- 增援城市
                CityReinforceLogic:cancleReinforceCity( oldTargetInfo.rid, _rid, true )
                fromPos = oldTargetInfo.pos
            elseif MapObjectLogic:checkIsGuildBuildObject( oldTargetInfo.objectType ) then
                -- 联盟建筑
                if _guildLock then
                    local guildBuild = GuildBuildLogic:getGuildBuild( guildId, oldTargetInfo.buildIndex, { Enum.GuildBuild.reinforces, Enum.GuildBuild.status, Enum.GuildBuild.type } )
                    local reinforces = guildBuild.reinforces or {}
                    local reinforceIndex, startTime
                    for index, reinforce in pairs( reinforces ) do
                        if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
                            startTime = reinforce.startTime
                            reinforceIndex = index
                            reinforces[index] = nil
                            break
                        end
                    end
                    GuildBuildLogic:setGuildBuild( guildId, oldTargetInfo.buildIndex, { [Enum.GuildBuild.reinforces] = reinforces } )
                    if guildBuild.status == Enum.GuildBuildStatus.BUILDING then
                        -- 更新角色获得的联盟个人积分
                        local armyChangeInfo = {}
                        local allianceCoinReward = CFG.s_AllianceBuildingType:Get( guildBuild.type, "allianceCoinReward" )
                        if allianceCoinReward > 0 then
                            local addGuildBuildPoint = math.floor( allianceCoinReward / 3600 * ( nowTime - startTime ) )
                            if addGuildBuildPoint > 0 then
                                armyChangeInfo.guildBuildPoint = ( _armyInfo.guildBuildPoint or 0 ) + addGuildBuildPoint
                            end
                        end
                        -- 增加参与建造时间
                        armyChangeInfo.guildBuildTime = ( _armyInfo.guildBuildTime or 0 ) + ( nowTime - startTime )
                        MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.BUILD_ALLIANCE_TIME,
                            nil, nil, nil, nil, nil, nil, nowTime - startTime )
                        self:setArmy( _rid, _armyIndex, armyChangeInfo )
                        -- 重置建造中的联盟建筑定时器
                        MSM.GuildTimerMgr[guildId].req.resetGuildBuildTimer( guildId, oldTargetInfo.buildIndex )
                        -- 更新联盟建筑索引
                        MSM.GuildIndexMgr[guildId].post.addBuildIndex( guildId, oldTargetInfo.buildIndex )
                        -- 部队离开建造中的联盟建筑
                        LogLogic:guildBuildTroops( {
                            logType = Enum.LogType.ARMY_LEAVE_GUILD_BUILD, iggid = roleInfo.iggid, guildId = guildId,
                            buildIndex = oldTargetInfo.buildIndex, buildType = guildBuild.type, rid = _rid, mainHeroId = _armyInfo.mainHeroId,
                            deputyHeroId = _armyInfo.deputyHeroId, buildTime = nowTime - startTime, soldiers = _armyInfo.soldiers
                        } )
                    end
                    -- 推送联盟建筑部队信息到关注角色中
                    GuildBuildLogic:syncGuildBuildArmy( oldTargetObjectIndex, nil, nil, { reinforceIndex } )
                    -- 联盟建筑,从建筑退出,不再驻守
                    MSM.SceneGuildBuildMgr[oldTargetObjectIndex].post.delGarrisonArmy( oldTargetObjectIndex, _rid, _armyIndex )
                else
                    MSM.GuildMgr[guildId].post.guildBuildArmyMarch( guildId, oldTargetInfo.buildIndex, _rid, _armyIndex, nil, oldTargetObjectIndex, true )
                end
                fromPos = oldTargetInfo.pos
            elseif MapObjectLogic:checkIsHolyLandObject( oldTargetInfo.objectType ) then
                -- 圣地关卡
                local reinforceIndex
                local reinforces = HolyLandLogic:getHolyLand( oldTargetInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
                for index, reinforce in pairs( reinforces ) do
                    if reinforce.rid == _rid and reinforce.armyIndex == _armyIndex then
                        reinforceIndex = index
                        reinforces[index] = nil
                        break
                    end
                end
                HolyLandLogic:setHolyLand( oldTargetInfo.strongHoldId, { [Enum.HolyLand.reinforces] = reinforces } )
                -- 推送圣地关卡部队信息到关注角色中
                HolyLandLogic:syncHolyLandArmy( oldTargetObjectIndex, nil, nil, { reinforceIndex } )
                fromPos = oldTargetInfo.pos
                -- 从圣地关卡中退出驻守
                MSM.SceneHolyLandMgr[oldTargetObjectIndex].post.delGarrisonArmy( oldTargetObjectIndex, _rid, _armyIndex )
            end
        end

        radius = oldTargetInfo.armyRadius
        fromType = oldTargetInfo.objectType
    end

    -- 未找到部队所在位置，增加容错处理，让部队从自己城市出发
    if not fromPos then
        fromPos = roleInfo.pos
        fromType = Enum.RoleType.CITY
        radius = CFG.s_Config:Get("cityRadius") * 100
        if oldTargetObjectIndex > 0 then
            LOG_ERROR("rid(%d) checkArmyOldTarget error, armyIndex(%d) targetObjectIndex(%d) not exist", _rid, _armyIndex, oldTargetObjectIndex)
        end
    end

    return fromPos, fromType, radius
end

---@see 检查部队是否正在攻击同盟
function ArmyLogic:checkArmyAttackGuildMember( _rid )
    local armyInfo = self:getArmy( _rid )
    local objectIndex
    for armyIndex in pairs(armyInfo) do
        objectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
        if objectIndex then
            MSM.SceneArmyMgr[objectIndex].post.checkArmyAttackGuildMember( objectIndex )
        end
    end
end

---@see 获取当前部队数量
---@param _objectInfo defaultMapArmyInfoClass
function ArmyLogic:getArmySoldiersFromObject( _objectInfo )
    if not _objectInfo then
        return 0
    end
    if _objectInfo.isRally then
        -- 集结部队
        local allSoldiers = {}
        local soldiers
        for rallyRid, rallyArmyIndex in pairs(_objectInfo.rallyArmy) do
            soldiers = self:getArmy( rallyRid, rallyArmyIndex, Enum.Army.soldiers )
            if soldiers then
                for soldierId, soldierInfo in pairs(soldiers) do
                    if not allSoldiers[soldierId] then
                        allSoldiers[soldierId] = soldierInfo
                    else
                        allSoldiers[soldierId].num = allSoldiers[soldierId].num + soldierInfo.num
                    end
                end
            end
        end
        return allSoldiers
    elseif _objectInfo.objectType == Enum.RoleType.EXPEDITION then
        local expeditionInfo = MSM.SceneExpeditionMgr[_objectInfo.objectIndex].req.getExpeditionInfo(_objectInfo.objectIndex) or {}
        return expeditionInfo.soldiers or {}
    else
        return self:getArmy( _objectInfo.rid, _objectInfo.armyIndex, Enum.Army.soldiers ) or {}
    end
end

---@see 获取集结部队士兵信息
---@param _objectInfo defaultMapArmyInfoClass
function ArmyLogic:getArmySoldiersDetailFromObject( _objectInfo )
    if _objectInfo.isRally then
        _objectInfo.rallyLeader = _objectInfo.rid
        _objectInfo.rallyMember = _objectInfo.rallyArmy
        -- 集结部队
        local allSoldiers = {}
        local soldiers
        for rallyRid, rallyArmyIndex in pairs(_objectInfo.rallyArmy) do
            soldiers = self:getArmy( rallyRid, rallyArmyIndex, Enum.Army.soldiers )
            if soldiers then
                if not allSoldiers[rallyRid] then
                    allSoldiers[rallyRid] = {}
                end
                allSoldiers[rallyRid][rallyArmyIndex] = soldiers
            end
        end
        return allSoldiers
    end
end

---@see 获取集结部队主将信息
---@param _objectInfo defaultMapArmyInfoClass
function ArmyLogic:getArmyHerosDetailFromObject( _objectInfo )
    if _objectInfo.isRally then
        -- 集结部队
        local heros = {}
        local armyInfo
        for rallyRid, rallyArmyIndex in pairs(_objectInfo.rallyArmy) do
            armyInfo = self:getArmy( rallyRid, rallyArmyIndex, { Enum.Army.mainHeroId, Enum.Army.deputyHeroId, Enum.Army.mainHeroLevel, Enum.Army.deputyHeroLevel } )
            if armyInfo then
                if not heros[rallyRid] then
                    heros[rallyRid] = {}
                end
                heros[rallyRid][rallyArmyIndex] = armyInfo
            end
        end
        return heros
    end
end

---@see 角色迁城检查部队是否在城外
function ArmyLogic:checkArmyOnMoveCity( _rid )
    local allArmy = self:getArmy( _rid ) or {}
    for armyIndex, armyInfo in pairs( allArmy ) do
        if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING )
        or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.SPACE_MARCH )
        or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECT_MARCH )
        or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH )
        or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_MARCH )
        or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RETREAT_MARCH )
        or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FAILED_MARCH )
        or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.ATTACK_MARCH ) then
            -- 行军中或战斗中
            LOG_ERROR("rid(%d) checkArmyOnMoveCity, armyIndex(%d) status(%d) march or battle", _rid, armyIndex, armyInfo.status)
            return nil, ErrorCode.MAP_MOVE_CITY_MARCH_BATTLE
        elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.STATIONING ) then
            -- 驻扎中
            LOG_ERROR("rid(%d) checkArmyOnMoveCity, armyIndex(%d) status(%d) station", _rid, armyIndex, armyInfo.status)
            return nil, ErrorCode.MAP_MOVE_CITY_STATION
        elseif armyInfo.isInRally then
            -- 集结中
            LOG_ERROR("rid(%d) checkArmyOnMoveCity, armyIndex(%d) is in rally", _rid, armyIndex)
            return nil, ErrorCode.MAP_MOVE_CITY_RALLY_ARMY
        elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
            -- 采集中
            LOG_ERROR("rid(%d) checkArmyOnMoveCity, armyIndex(%d) status(%d) collect resource", _rid, armyIndex, armyInfo.status)
            return nil, ErrorCode.MAP_MOVE_CITY_COLLECT
        end
    end

    return true
end

---@see 角色迁城更新增援部队坐标
function ArmyLogic:checkReinforceArmyOnMoveCity( _rid, _pos )
    local armyInfo, targetArg
    local reinforces = RoleLogic:getRole( _rid, Enum.Role.reinforces ) or {}
    for reinforceRid, reinforceInfo in pairs( reinforces ) do
        armyInfo = self:getArmy( reinforceRid, reinforceInfo.armyIndex, { Enum.Army.targetArg, Enum.Army.status } )
        if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
            targetArg = armyInfo.targetArg or {}
            targetArg.pos = _pos
            self:setArmy( reinforceRid, reinforceInfo.armyIndex, { [Enum.Army.targetArg] = targetArg } )
            self:syncArmy( reinforceRid, reinforceInfo.armyIndex, { [Enum.Army.targetArg] = targetArg }, true )
        end
    end
end

---@see 更新联盟建筑和圣地关卡中部队的头像和头像框
function ArmyLogic:updateArmyInfoOnRoleInfoChange( _rid, _newHeadId, _newHeadFrameID )
    local GuildBuildLogic = require "GuildBuildLogic"
    local HolyLandLogic = require "HolyLandLogic"

    local targetObjectIndex, targetInfo, reinforces
    local armys = self:getArmy( _rid ) or {}
    for armyIndex, armyInfo in pairs( armys ) do
        targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex or 0
        if targetObjectIndex > 0 and ( self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH )
            or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) ) then
            targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
            if MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
                -- 目标是联盟建筑
                reinforces = GuildBuildLogic:getGuildBuild( targetInfo.guildId, targetInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
                for index, reinforce in pairs( reinforces ) do
                    if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                        GuildBuildLogic:syncGuildBuildArmy( targetObjectIndex, {
                            [index] = { roleHeadId = _newHeadId, roleHeadFrameId = _newHeadFrameID, buildArmyIndex = index }
                        } )
                        break
                    end
                end
            elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
                -- 目标是圣地关卡
                reinforces = HolyLandLogic:getHolyLand( targetInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
                for index, reinforce in pairs( reinforces ) do
                    if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                        HolyLandLogic:syncHolyLandArmy( targetObjectIndex, {
                            [index] = { roleHeadId = _newHeadId, roleHeadFrameId = _newHeadFrameID, buildArmyIndex = index }
                        } )
                        break
                    end
                end
            elseif targetInfo.objectType == Enum.RoleType.CITY and ( armyInfo.reinforceRid or 0 ) > 0 then
                -- 增援城市
                reinforces = RoleLogic:getRole( armyInfo.reinforceRid, Enum.Role.reinforces ) or {}
                if reinforces[_rid] then
                    if _newHeadId then
                        reinforces[_rid].headId = _newHeadId
                    end
                    if _newHeadFrameID then
                        reinforces[_rid].headFrameID = _newHeadFrameID
                    end
                    -- 更新到角色中
                    RoleLogic:setRole( armyInfo.reinforceRid, Enum.Role.reinforces, reinforces )
                    -- 通知客户端
                    RoleSync:syncSelf( armyInfo.reinforceRid, { [Enum.Role.reinforces] = reinforces }, true )
                end
            end
        end
    end
end

---@see 更新联盟建筑和圣地关卡中统帅的等级
function ArmyLogic:updateArmyInfoOnHeroInfoChange( _rid, _heroId, _heroLevel )
    local GuildBuildLogic = require "GuildBuildLogic"
    local HolyLandLogic = require "HolyLandLogic"

    local targetObjectIndex, targetInfo, reinforces, syncArmyInfo
    local armys = self:getArmy( _rid ) or {}
    for armyIndex, armyInfo in pairs( armys ) do
        if armyInfo.mainHeroId == _heroId or armyInfo.deputyHeroId == _heroId then
            targetObjectIndex = armyInfo.targetArg and armyInfo.targetArg.targetObjectIndex or 0
            if targetObjectIndex > 0 and ( self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH )
                or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) ) then
                targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
                if MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
                    -- 目标是联盟建筑
                    reinforces = GuildBuildLogic:getGuildBuild( targetInfo.guildId, targetInfo.buildIndex, Enum.GuildBuild.reinforces ) or {}
                    for index, reinforce in pairs( reinforces ) do
                        if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                            if armyInfo.mainHeroId == _heroId then
                                syncArmyInfo = {
                                    [index] = { mainHeroLevel = _heroLevel, buildArmyIndex = index }
                                }
                            else
                                syncArmyInfo = {
                                    [index] = { deputyHeroLevel = _heroLevel, buildArmyIndex = index }
                                }
                            end
                            GuildBuildLogic:syncGuildBuildArmy( targetObjectIndex, syncArmyInfo )
                            break
                        end
                    end
                elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
                    -- 目标是圣地关卡
                    reinforces = HolyLandLogic:getHolyLand( targetInfo.strongHoldId, Enum.HolyLand.reinforces ) or {}
                    for index, reinforce in pairs( reinforces ) do
                        if reinforce.rid == _rid and reinforce.armyIndex == armyIndex then
                            if armyInfo.mainHeroId == _heroId then
                                syncArmyInfo = {
                                    [index] = { mainHeroLevel = _heroLevel, buildArmyIndex = index }
                                }
                            else
                                syncArmyInfo = {
                                    [index] = { deputyHeroLevel = _heroLevel, buildArmyIndex = index }
                                }
                            end
                            HolyLandLogic:syncHolyLandArmy( targetObjectIndex, syncArmyInfo )
                            break
                        end
                    end
                end
            end

            break
        end
    end
end

---@see 强制迁城部队处理
function ArmyLogic:checkArmyOnForceMoveCity( _rid )
    local BattleCreate = require "BattleCreate"
    local RepatriationLogic = require "RepatriationLogic"
    local ArmyWalkLogic = require "ArmyWalkLogic"

    ---@type table<int, defaultArmyAttrClass>
    local allArmyInfos = self:getArmy( _rid )
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    local armyObjectIndex, targetObjectIndex, targetInfo, deleteArmy, serviceIndex

    for armyIndex, armyInfo in pairs(allArmyInfos) do
        targetObjectIndex = armyInfo.targetArg.targetObjectIndex or 0
        targetInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectInfo( targetObjectIndex )
        armyObjectIndex = MSM.RoleArmyMgr[_rid].req.getRoleArmyIndex( _rid, armyIndex )
        if armyObjectIndex then
            -- 还在地图上
            if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING )
                and not ( self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_MARCH )
                or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_BATTLE ) ) then
                -- 战斗中,退出战斗
                BattleCreate:exitBattle( armyObjectIndex, true )
            end
            deleteArmy = true
            -- 如果处于增援行军
            if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.REINFORCE_MARCH ) then
                if targetInfo.objectType == Enum.RoleType.CITY then
                    -- 增援城市,返回
                    RepatriationLogic:repatriationFromCity( targetInfo.rid, _rid, true, true )
                elseif MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
                    -- 删除向联盟建筑的增援
                    MSM.GuildMgr[targetInfo.guildId].post.guildBuildArmyMarch( targetInfo.guildId, targetInfo.buildIndex, _rid, armyIndex, nil, targetObjectIndex, true )
                elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
                    -- 删除向圣地的增援
                    MSM.GuildMgr[targetInfo.guildId].post.deleteHolyLandArmy( targetInfo.guildId, _rid, armyIndex, targetObjectIndex )
                elseif targetInfo.objectType == Enum.RoleType.ARMY then
                    -- 删除向集结部队的增援
                    MSM.RallyMgr[targetInfo.guildId].req.cacleReinforce( targetInfo.rid, _rid )
                end
            elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING_NO_DELETE ) then
                -- 符文采集中
                MSM.RuneMgr[targetObjectIndex].post.cancelCollectRune( _rid, armyIndex, targetObjectIndex )
            elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_JOIN_MARCH ) then
                -- 取消加入集结
                MSM.RallyMgr[guildId].req.repatriationRallyArmy( targetInfo.rid, _rid )
            elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_MARCH )
            or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_BATTLE ) then
                -- 集结部队,解散处理
                MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rid, nil, nil, true )
                deleteArmy = false
            end

            if targetInfo then
                ArmyWalkLogic:delArmyWalkTargetInfo( targetObjectIndex, targetInfo.objectType, armyObjectIndex )
            end

            if deleteArmy then
                -- 删除地图上的对象
                MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, armyObjectIndex, { x = -1, y = -1 } )
                -- 移除军队索引信息
                MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, armyIndex )
            end
        else
            -- 不在地图上
            if self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.GARRISONING ) then
                -- 驻守在城市、联盟建筑、圣地中
                if targetInfo.objectType == Enum.RoleType.CITY then
                    -- 驻守在玩家城市中
                    MSM.CityReinforceMgr[targetInfo.rid].post.disbanArmyOnForceMoveCity( targetInfo.rid, _rid )
                elseif MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
                    -- 驻守在联盟建筑中
                    MSM.SceneGuildBuildMgr[targetObjectIndex].post.disbanArmyOnForceMoveCity( targetObjectIndex, _rid )
                    -- 删除联盟建筑中的部队
                    MSM.GuildMgr[guildId].post.guildBuildArmyMarch( guildId, targetInfo.buildIndex, _rid, armyIndex, nil, targetObjectIndex, true )
                elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
                    -- 驻守在圣地建筑中
                    MSM.SceneHolyLandMgr[targetObjectIndex].post.disbanArmyOnForceMoveCity( targetObjectIndex, _rid )
                    -- 删除增援
                    MSM.GuildMgr[guildId].post.deleteHolyLandArmy( guildId, _rid, armyIndex, targetObjectIndex )
                end
            elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_WAIT )
            or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_MARCH )
            or self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.RALLY_BATTLE ) then
                -- 判断是队长还是队员
                if MSM.RallyMgr[guildId].req.checkIsRallyCreater( guildId, _rid ) then
                    -- 集结队长,取消集结
                    MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rid, nil, nil, true )
                else
                    -- 集结队员,退出集结
                    MSM.RallyMgr[guildId].req.forceExitRallyTeam( targetInfo.rid, _rid )
                end
            elseif self:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                if MapObjectLogic:checkIsGuildResourceCenterObject( targetInfo.objectType ) then
                    -- 联盟资源中心采集中
                    MSM.GuildMgr[guildId].post.guildBuildArmyMarch( guildId, targetInfo.buildIndex, _rid, armyIndex, nil, targetObjectIndex, true )
                elseif MapObjectLogic:checkIsResourceObject( targetInfo.objectType ) then
                    -- 资源点采集中
                    serviceIndex = MapLogic:getObjectService( targetInfo.pos )
                    MSM.ResourceMgr[serviceIndex].req.callBackArmy( _rid, armyIndex, nil, true )
                end
            end
        end

        -- 解散部队
        self:disbandArmy( _rid, armyIndex, nil, true )
    end

    -- 增援自己的部队全部回城
    MSM.CityReinforceMgr[_rid].req.returnArmyOnForceMoveCity( _rid )
end

---@see 检测部队buff
---@param _mapArmyInfos table<int, defaultMapArmyInfoClass>
function ArmyLogic:checkArmyBuff( _mapArmyInfos )
    for objectIndex, objectInfo in pairs(_mapArmyInfos) do
        if not self:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 非战斗的时候处理buff效果
            local removeBuff = false
            for index, buffInfo in pairs(objectInfo.battleBuff) do
                if buffInfo.turn and buffInfo.turn >= 0 then
                    buffInfo.turn = buffInfo.turn - 1
                    if buffInfo.turn <= 0 then
                        -- 移除buff
                        objectInfo.battleBuff[index] = nil
                        removeBuff = true
                    end
                end
            end

            if removeBuff then
                -- 同步给客户端
                local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
                sceneObject.post.syncObjectInfo( objectIndex, { battleBuff = objectInfo.battleBuff } )
                -- 计算buff对战斗外影响
                self:reCacleArmySpeed( objectIndex, objectInfo, nil, nil, objectInfo.isInGuildTerritory )
            end
        end
    end
end

---@see 重新计算buff影响部队属性
---@param _objectInfo defaultMapArmyInfoClass
function ArmyLogic:reCacleArmySpeed( _objectIndex, _objectInfo, _noWalk, _armyInfo, _isInGuildTerritory )
    local oldSpeed = _objectInfo.speed
    -- 影响速度
    local armyInfo = _armyInfo or self:getArmy( _objectInfo.rid, _objectInfo.armyIndex )
    -- 计算buff增加的移动速度
    local sSkillStatus
    local addSpeedAttr = {
        infantryMoveSpeed = 0,                  -- 步兵行军速度
        cavalryMoveSpeed = 0,                   -- 骑兵行军速度
        bowmenMoveSpeed = 0,                    -- 弓兵行军速度
        siegeCarMoveSpeed = 0,                  -- 攻城器械行军速度
        infantryMoveSpeedMulti = 0,             -- 步兵行军速度百分比
        cavalryMoveSpeedMulti = 0,              -- 骑兵行军速度百分比
        bowmenMoveSpeedMulti = 0,               -- 弓兵行军速度百分比
        siegeCarMoveSpeedMulti = 0,             -- 攻城器械行军速度百分比
        allTerrMoveSpeedMulti = 0,              -- 联盟领地移动速度加成
        rallyMoveSpeedMulti = 0,                -- 集结部队行军速度千分比
        marchSpeedMulti = 0,                    -- 部队行军速度百分比
    }

    -- 计算buff增加的属性
    if _objectInfo.battleBuff then
        for _, buffInfo in pairs(_objectInfo.battleBuff) do
            sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.buffId )
            if sSkillStatus.attrType then
                for index, attrName in pairs(sSkillStatus.attrType) do
                    if addSpeedAttr[attrName] then
                        addSpeedAttr[attrName] = addSpeedAttr[attrName] + ( sSkillStatus.attrNumber[index] or 0 )
                    end
                end
            end
        end
    end

    -- 计算天赋增加的属性
    if _objectInfo.talentAttr then
        for attrName, attrValue in pairs(_objectInfo.talentAttr) do
            if addSpeedAttr[attrName] then
                addSpeedAttr[attrName] = addSpeedAttr[attrName] + attrValue
            end
        end
    end

    -- 计算装备增加的属性
    if _objectInfo.equipAttr then
        for attrName, attrValue in pairs(_objectInfo.equipAttr) do
            if addSpeedAttr[attrName] then
                addSpeedAttr[attrName] = addSpeedAttr[attrName] + attrValue
            end
        end
    end

    -- 计算技能增加的属性
    if _objectInfo.skills then
        for _, skillInfo in pairs(_objectInfo.skills) do
            local sHeroSkillEffect = CFG.s_HeroSkillEffect:Get( skillInfo.skillId * 1000 + skillInfo.skillLevel )
            if sHeroSkillEffect then
                for index, name in pairs(sHeroSkillEffect.attrType) do
                    if addSpeedAttr[name] then
                        addSpeedAttr[name] = addSpeedAttr[name] + ( sHeroSkillEffect.attrNumber[index] or 0 )
                    end
                end
            end
        end
    end

    -- 重新计算速度
    _objectInfo.speed = self:cacleArmyWalkSpeed( _objectInfo.rid, armyInfo, addSpeedAttr, _isInGuildTerritory, _objectInfo.isRally )
    -- 速度保底
    if _objectInfo.speed <= 0 then
        _objectInfo.speed = 1
    end

    -- 如果部队正在行军,通知改变速度
    if not _noWalk then
        if oldSpeed ~= _objectInfo.speed and self:checkArmyWalkStatus( _objectInfo.status ) then
            MSM.MapMarchMgr[_objectIndex].post.changeArmySpeed( _objectIndex, _objectInfo.pos, _objectInfo.speed )
        elseif oldSpeed ~= _objectInfo.speed then
            MSM.SceneArmyMgr[_objectIndex].post.updateArmySpeed( _objectIndex, _objectInfo.speed )
        end
    end

    return _objectInfo.speed
end

---@see 获取部队集结目标行军参数
function ArmyLogic:getArmyRallyMarchTargetArg( _targetObjectIndex )
    local targetArg = {}
    local targetInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
    if targetInfo then
        targetArg.targetObjectType = targetInfo.objectType
        targetArg.targetPos = targetInfo.pos
        if targetInfo.objectType == Enum.RoleType.CITY then
            -- 集结城市
            targetArg.targetGuildName = targetInfo.guildAbbName
            targetArg.targetName = RoleLogic:getRole( targetInfo.rid, Enum.Role.name )
        -- elseif MapObjectLogic:checkIsGuildBuildObject( targetInfo.objectType ) then
            -- 集结联盟建筑
        elseif targetInfo.objectType == Enum.RoleType.MONSTER_CITY or targetInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 集结野蛮人城寨
            targetArg.targetMonsterCityId = targetInfo.monsterId
        elseif MapObjectLogic:checkIsHolyLandObject( targetInfo.objectType ) then
            -- 集结圣地关卡
            targetArg.targetHolyLandId = targetInfo.strongHoldId
        end
    end

    return targetArg
end

---@see 部队增加BUFF
function ArmyLogic:addBuffToArmy( _objectIndex, _objectInfo, _statusIds, _turn, _noCacle )
    -- 如果在战斗,通知战斗服务器
    if self:checkArmyStatus( _objectInfo.status, Enum.ArmyStatus.BATTLEING ) then
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
        if battleIndex then
            local BattleCreate = require "BattleCreate"
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            if battleNode then
                Common.rpcMultiSend( battleNode, "BattleLoop", "objectAddBuff", battleIndex, _objectIndex, _statusIds )
            end
        end
    end

    for _, statusId in pairs(_statusIds) do
        table.insert( _objectInfo.battleBuff, { buffId = statusId, turn = _turn or -1 } )
    end
    -- 重新计算速度
    self:reCacleArmySpeed( _objectIndex, _objectInfo, _noCacle, nil, _objectInfo.isInGuildTerritory )
end

---@see 部队移除BUFF
function ArmyLogic:delBuffFromArmy( _objectIndex, _objectInfo, _statusIds )
    -- 如果在战斗,通知战斗服务器
    if self:checkArmyStatus( _objectInfo.status, Enum.ArmyStatus.BATTLEING ) then
        local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
        if battleIndex then
            local BattleCreate = require "BattleCreate"
            local battleNode = BattleCreate:getBattleServerNode( battleIndex )
            if battleNode then
                Common.rpcMultiSend( battleNode, "BattleLoop", "objectRemoveBuff", battleIndex, _objectIndex, _statusIds )
            end
        end
    end

    for _, statusId in pairs(_statusIds) do
        for index, buffInfo in pairs( _objectInfo.battleBuff ) do
            if buffInfo.buffId == statusId then
                _objectInfo.battleBuff[index] = nil
                break
            end
        end
    end
    -- 重新计算速度
    self:reCacleArmySpeed( _objectIndex, _objectInfo, nil, nil, _objectInfo.isInGuildTerritory )
end

---@see 移除部队的移动状态
function ArmyLogic:removeMoveStatus( _status, _targetStatus )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.SPACE_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.ATTACK_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.COLLECT_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.REINFORCE_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.RALLY_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.RALLY_JOIN_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.RETREAT_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.FAILED_MARCH )
    _status = self:delArmyStatus( _status, Enum.ArmyStatus.MOVE )
    if _targetStatus and not self:checkArmyWalkStatus( _targetStatus ) then
        _status = self:delArmyStatus( _status, Enum.ArmyStatus.FOLLOWUP )
    end

    return _status
end

---@see 过滤对象状态处理
function ArmyLogic:grepObjectStatus( _objectIndex, _objectInfo, _status, _statusOp )
    local oldStatus = _objectInfo.status
    local setStatus = _status
    if not _statusOp then
        _statusOp = Enum.ArmyStatusOp.SET
        if self:checkArmyStatus( oldStatus, Enum.ArmyStatus.STATIONING ) and _status == Enum.ArmyStatus.BATTLEING then
            -- 驻扎状态,进战斗,不移除驻扎状态
            _status = self:addArmyStatus( _status, Enum.ArmyStatus.STATIONING )
        end
    end
    if _statusOp == Enum.ArmyStatusOp.ADD then
        -- 添加状态
        _status = self:addArmyStatus( oldStatus, _status )
    elseif _statusOp == Enum.ArmyStatusOp.DEL then
        -- 删除状态
        _status = self:delArmyStatus( oldStatus, _status )
    end

    -- 不是删除战斗状态
    if setStatus ~= Enum.ArmyStatus.BATTLEING and _statusOp ~= Enum.ArmyStatusOp.DEL then
        if self:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and ( self:checkArmyWalkStatus( _status ) or self:checkArmyStatus( _status, Enum.ArmyStatus.FOLLOWUP ) ) then
            -- 移动行军、追击不移除战斗
            _status = self:addArmyStatus( _status, Enum.ArmyStatus.BATTLEING )
        end
    end

    if self:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING )
    and self:checkArmyStatus( _status, Enum.ArmyStatus.PATROL ) then
        -- 处于战斗状态和巡逻状态,移除巡逻
        _status = self:delArmyStatus( _status, Enum.ArmyStatus.PATROL )
        -- 中断巡逻
        MSM.MapMarchMgr[_objectIndex].req.stopObjectMove( _objectIndex )
    end

    -- 不处于战斗而且不处于移动,移除targetObjectIndex
    if not self:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING )
    and not self:checkArmyWalkStatus( _status ) then
        _objectInfo.targetObjectIndex = 0
    end

    if _status == 0 then
        -- 默认待机
        _status = Enum.ArmyStatus.ARMY_STANBY
    end

    if _status ~= Enum.ArmyStatus.ARMY_STANBY then
        -- 非纯待机,移除待机
        _status = self:delArmyStatus( _status, Enum.ArmyStatus.ARMY_STANBY )
    end

    -- 同步战斗服务器状态
    if self:checkArmyStatus( _status, Enum.ArmyStatus.BATTLEING ) then
        local BattleAttrLogic = require "BattleAttrLogic"
        BattleAttrLogic:syncObjectStatus( _objectIndex, _status )
    end

    return _status
end

---@see 离开建筑时.判断是否触发被动
function ArmyLogic:triggerSkillOnLeaveBuild( _objectIndex, _objectInfo )
    -- 只处理治疗和加BUFF
    local armyInfo = self:getArmy( _objectInfo.rid, _objectInfo.armyIndex )
    if not armyInfo then
        return
    end
    local skills = HeroLogic:getRoleAllHeroSkills( _objectInfo.rid, armyInfo.mainHeroId, armyInfo.deputyHeroId )
    local sSkillInfo, sSkillBattleInfo
    for _, skillInfo in pairs(skills) do
        sSkillInfo = CFG.s_HeroSkill:Get( skillInfo.skillId )
        local skillBattleID
        if skillInfo.talent then
            if type(skillInfo.skillId) ~= "table" then
                skillBattleID = { skillInfo.skillId }
            else
                skillBattleID = skillInfo.skillId
            end
        else
            -- 是否被觉醒技能强化
            skillBattleID = CommonCacle:checkIsAwakeEnhance( skillInfo.skillId, skills )
            if not skillBattleID then
                skillBattleID = sSkillInfo.skillBattleID
            end
        end
        for _, skillBattleId in pairs(skillBattleID) do
            repeat
                -- 判断是否有战斗技能数据
                if (not skillInfo.talent) and ( not sSkillInfo or not skillBattleId or skillBattleId <= 0 ) then
                    break
                end
                if skillInfo.talent then
                    sSkillBattleInfo = CFG.s_SkillBattle:Get( skillInfo.skillId * 100 + skillInfo.skillLevel )
                else
                    sSkillBattleInfo = CFG.s_SkillBattle:Get( skillBattleId * 100 + skillInfo.skillLevel )
                end
                -- 判断是否为此触发时机(离开建筑)
                if not sSkillBattleInfo or not sSkillBattleInfo.autoActive or sSkillBattleInfo.autoActive ~= Enum.SkillTrigger.LEAVE_BUILD then
                    break
                end
                -- 判断触发几率
                if Random.Get( 1, 1000 ) > sSkillBattleInfo.autoActivePro then
                    break
                end

                if sSkillBattleInfo.statusID then
                    -- 技能产生状态
                    for _, statusId in pairs(sSkillBattleInfo.statusID) do
                        if statusId and statusId > 0 then
                            -- 增加buff
                            local sSkillStatus = CFG.s_SkillStatus:Get( statusId )
                            -- 计算状态持续回合
                            local turn = sSkillStatus.boutTimes
                            if turn ~= -1 then
                                turn = sSkillStatus.boutTimes + Random.Get( 0, sSkillStatus.boutTimesWave )
                            end
                            self:addBuffToArmy( _objectIndex, _objectInfo, { statusId }, turn )
                        end
                    end
                end
            until true
        end
    end
end

---@see 增加一层野蛮人扫荡效果
function ArmyLogic:addKillMonsterReduceVit( _rid, _armyIndex )
    local killMonsterReduceVit = self:getArmy( _rid, _armyIndex, Enum.Army.killMonsterReduceVit )
    if killMonsterReduceVit and killMonsterReduceVit < CFG.s_Config:Get("vitalityReduceLevelLimit") then
        killMonsterReduceVit = killMonsterReduceVit + 1
        self:updateArmyInfo( _rid, _armyIndex, { [Enum.Army.killMonsterReduceVit] = killMonsterReduceVit } )
    end
end

---@see 计算行动力受野蛮人扫荡效果减免
function ArmyLogic:cacleKillMonsterReduceVit( _rid, _armyIndex, _needActionFore )
    if _needActionFore then
        local killMonsterReduceVit = self:getArmy( _rid, _armyIndex, Enum.Army.killMonsterReduceVit )
        if killMonsterReduceVit then
            return _needActionFore - killMonsterReduceVit * ( CFG.s_Config:Get("vitalityReduceUnit") or 0 )
        else
            return _needActionFore
        end
    end
end

---@see 更新部队行军目标信息
function ArmyLogic:updateArmyMarchTargetInfo( _rid, _armyIndex, _armyInfo, _armyStatus, _targetIndex, _targetTypeInfo )
    if _targetTypeInfo and not table.empty( _targetTypeInfo ) then
        local toType = _targetTypeInfo.objectType
        local targetArg = self:getArmy( _armyInfo.rid, _armyIndex, Enum.Army.targetArg ) or {}
        targetArg = { targetObjectIndex = _targetIndex, pos = targetArg.pos }
        targetArg.targetObjectType = toType
        if self:checkArmyStatus( _armyStatus, Enum.ArmyStatus.RALLY_JOIN_MARCH ) then
            -- 角色加入集结, 向目标城市行军中
            targetArg.targetName = _targetTypeInfo.name
            targetArg.targetGuildName = _targetTypeInfo.guildAbbName
            targetArg.targetPos = _targetTypeInfo.pos
        elseif self:checkArmyStatus( _armyStatus, Enum.ArmyStatus.REINFORCE_MARCH ) then
            -- 增援行军中
            targetArg.targetPos = _targetTypeInfo.pos
            if toType == Enum.RoleType.CITY then
                -- 增援联盟成员城市
                targetArg.targetName = _targetTypeInfo.name
                targetArg.targetGuildName = _targetTypeInfo.guildAbbName
            elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
                -- 增援圣地
                targetArg.targetHolyLandId = _targetTypeInfo.strongHoldId
            elseif MapObjectLogic:checkIsGuildBuildObject( toType ) then
                -- 增援联盟建筑
                targetArg.targetGuildBuildType = _targetTypeInfo.staticId
            elseif toType == Enum.RoleType.ARMY then
                -- 增援集结部队
                targetArg.targetName = _targetTypeInfo.armyName
                targetArg.targetGuildName = _targetTypeInfo.guildAbbName
            end
        elseif self:checkArmyStatus( _armyStatus, Enum.ArmyStatus.COLLECT_MARCH ) then
            -- 采集行军中
            targetArg.targetPos = _targetTypeInfo.pos
            if MapObjectLogic:checkIsResourceObject( toType ) then
                -- 采集野外资源田
                targetArg.targetResourceId = _targetTypeInfo.resourceId
            elseif MapObjectLogic:checkIsGuildResourceCenterObject( toType ) then
                -- 采集联盟资源中心
                targetArg.targetGuildBuildType = _targetTypeInfo.staticId
            elseif toType == Enum.RoleType.RUNE then
                -- 采集符文
                targetArg.targetMapItemType = _targetTypeInfo.runeId
            end
        elseif self:checkArmyStatus( _armyStatus, Enum.ArmyStatus.ATTACK_MARCH ) then
            -- 进攻行军中
            targetArg.targetPos = _targetTypeInfo.pos
            if toType == Enum.RoleType.MONSTER or toType == Enum.RoleType.GUARD_HOLY_LAND
                or toType == Enum.RoleType.SUMMON_SINGLE_MONSTER then
                -- 进攻野蛮人、守护者、召唤怪物
                targetArg.targetMonsterId = _targetTypeInfo.monsterId
            elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
                -- 进攻圣地关卡
                targetArg.targetHolyLandId = _targetTypeInfo.strongHoldId
            elseif MapObjectLogic:checkIsGuildBuildObject( toType ) then
                -- 进攻联盟建筑
                targetArg.targetGuildBuildType = _targetTypeInfo.staticId
            elseif toType == Enum.RoleType.ARMY then
                -- 进攻部队
                targetArg.targetName = _targetTypeInfo.armyName
                targetArg.targetGuildName = _targetTypeInfo.guildAbbName
            elseif toType == Enum.RoleType.CITY then
                -- 进攻城市
                targetArg.targetName = _targetTypeInfo.name
                targetArg.targetGuildName = _targetTypeInfo.guildAbbName
            elseif MapObjectLogic:checkIsResourceObject( toType ) then
                -- 攻击资源田
                targetArg.targetResourceId = _targetTypeInfo.resourceId
            end
        end

        -- 更新部队目标信息
        ArmyLogic:updateArmyInfo( _rid, _armyIndex, { [Enum.Army.targetArg] = targetArg } )
    end
end

---@see 获取部队行军日志目标ID
function ArmyLogic:getArmyMarchTargetId( _targetTypeInfo )
    if _targetTypeInfo and not table.empty( _targetTypeInfo ) then
        local toType = _targetTypeInfo.objectType
        if toType == Enum.RoleType.ARMY then
            return _targetTypeInfo.rid
        elseif toType == Enum.RoleType.MONSTER or toType == Enum.RoleType.GUARD_HOLY_LAND
            or toType == Enum.RoleType.SUMMON_SINGLE_MONSTER or toType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            return _targetTypeInfo.monsterId
        elseif toType == Enum.RoleType.CITY then
            return _targetTypeInfo.rid
        elseif MapObjectLogic:checkIsResourceObject( toType ) then
            return _targetTypeInfo.resourceId
        elseif MapObjectLogic:checkIsGuildBuildObject( toType ) then
            return _targetTypeInfo.staticId
        elseif toType == Enum.RoleType.RUNE then
            return _targetTypeInfo.runeId
        elseif MapObjectLogic:checkIsHolyLandObject( toType ) then
            return _targetTypeInfo.strongHoldId
        elseif toType == Enum.RoleType.MONSTER_CITY then
            return _targetTypeInfo.monsterId
        end
    end
end

return ArmyLogic