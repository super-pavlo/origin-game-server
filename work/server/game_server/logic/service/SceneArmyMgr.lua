--[[
* @file : SceneArmyMgr.lua
* @type : snax multi service
* @author : linfeng
* @created : Thu May 03 2018 11:29:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图军队管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local BattleCreate = require "BattleCreate"
local RoleLogic = require "RoleLogic"
local ArmyWalkLogic = require "ArmyWalkLogic"
local Timer = require "Timer"
local ArmyFollowUpLogic = require "ArmyFollowUpLogic"
local GuildLogic = require "GuildLogic"
local HeroLogic = require "HeroLogic"
local ArmyDef = require "ArmyDef"
local BattleAttrLogic = require "BattleAttrLogic"
local CommonCacle = require "CommonCacle"
local EarlyWarningLogic = require "EarlyWarningLogic"
local LogLogic = require "LogLogic"

---@see 地图军队信息
---@class defaultMapArmyInfoClass
local defaultMapArmyInfo = {
    rid                         =                   0,              -- 角色rid
    armyName                    =                   "",             -- 角色名称
    armyIndex                   =                   0,              -- 部队索引
    objectType                  =                   0,              -- 对象类型
    mainHeroId                  =                   0,              -- 主将ID
    deputyHeroId                =                   0,              -- 副将ID
    mainHeroLevel               =                   0,              -- 主将等级
    deputyHeroLevel             =                   0,              -- 副将等级
    mainHeroSkills              =                   {},             -- 主将技能
    deputyHeroSkills            =                   {},             -- 副将技能
    soldiers                    =                   {},             -- 部队士兵(获取得时候才填充)
    resourceLoads               =                   0,              -- 资源负载信息
    collectResource             =                   0,              -- 军队当前正在采集的资源信息
    status                      =                   0,              -- 军队状态(Enum.ArmyStatus)
    attackInfo                  =                   {},             -- 进攻信息
    pos                         =                   {},             -- 军队坐标
    speed                       =                   0,              -- 移动速度
    arrivalTime                 =                   0,              -- 军队达到时间
    startTime                   =                   0,              -- 军队出发时间
    targetObjectIndex           =                   0,              -- 目标索引
    targetObjectType            =                   0,              -- 目标类型
    armyCount                   =                   0,              -- 军队部队数量
    armyRadius                  =                   0,              -- 军队半径
    angle                       =                   0,              -- 目标角度
    path                        =                   {},             -- 移动路径
    attackCount                 =                   0,              -- 攻击方数量
    guildAbbName                =                   "",             -- 联盟简称
    guildId                     =                   0,              -- 联盟ID
    skills                      =                   {},             -- 技能
    battleBuff                  =                   {},             -- 战斗buff
    sp                          =                   0,              -- 怒气
    maxSp                       =                   0,              -- 最大怒气
    food                        =                   0,              -- 掠夺的粮食
    wood                        =                   0,              -- 掠夺的木材
    stone                       =                   0,              -- 掠夺的石头
    gold                        =                   0,              -- 掠夺的金币
    armyLoadAtPlunder           =                   0,              -- 掠夺时的部队负载
    armyCountMax                =                   0,              -- 部队数量上限
    ---@type table<int, int>
    rallyArmy                   =                   {},             -- 集结部队信息
    isRally                     =                   false,          -- 是否是集结部队
    rallySoldierMax             =                   0,              -- 历史集结最大数量
    collectRuneTime             =                   0,              -- 军队开始采集符文时间
    guildFlagSigns              =                   {},             -- 联盟旗帜标志
    armyMarchInfo               =                   {},             -- 向目标行军的部队信息
    cityLevel                   =                   0,              -- 角色市政厅等级
    buildArmyIndex              =                   0,              -- 在建筑中的部队索引
    isInGuildTerritory          =                   false,          -- 是否在联盟领地内
    guildTerritoryBuff          =                   {},             -- 联盟领地buff
    talentAttr                  =                   {},             -- 天赋属性
    equipAttr                   =                   {},             -- 装备属性
}

---@type table<int, defaultMapArmyInfoClass>
local mapArmyInfos = {}
---@type table<int, int>
local mapArmyFollowInfos = {}
---@type table<int, table<int,table>>
local armyWalkToInfo = {}

function init()
    -- 每秒检测下追击
    Timer.runEvery( 100, ArmyFollowUpLogic.dispatchArmyFollowUp, ArmyFollowUpLogic, mapArmyFollowInfos, mapArmyInfos )
    -- 每秒检测下buff
    Timer.runEvery( 100, ArmyLogic.checkArmyBuff, ArmyLogic, mapArmyInfos )
end

---@see 增加军队对象
function response.addArmyObject( _objectIndex, _armyInfo, _pos )
    _pos.x = math.floor( _pos.x )
    _pos.y = math.floor( _pos.y )
    _armyInfo.pos = _pos
    local roleInfo = RoleLogic:getRole( _armyInfo.rid, { Enum.Role.name, Enum.Role.guildId, Enum.Role.level } )
    -- 技能
    local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( _armyInfo.rid, _armyInfo.mainHeroId, _armyInfo.deputyHeroId )
    -- 是否是集结部队
    local isRally = false
    if _armyInfo.rallyArmy and not table.empty( _armyInfo.rallyArmy ) then
        isRally = true
    end
    -- 联盟简称
    local guildAbbName
    local guildFlagSigns = {}
    if roleInfo.guildId and roleInfo.guildId > 0 then
        local guildInfo = GuildLogic:getGuild( roleInfo.guildId, { Enum.Guild.abbreviationName, Enum.Guild.signs } )
        if guildInfo then
            guildAbbName = guildInfo.abbreviationName
            if isRally then
                guildFlagSigns = guildInfo.signs
            end
        end
    end

    local defaultArmyInfo = const( table.copy( defaultMapArmyInfo, true ) )
    defaultArmyInfo.pos = _pos
    defaultArmyInfo.rid = _armyInfo.rid
    defaultArmyInfo.objectType = Enum.RoleType.ARMY
    defaultArmyInfo.armyIndex = assert(_armyInfo.armyIndex)
    defaultArmyInfo.mainHeroId = _armyInfo.mainHeroId or 0
    defaultArmyInfo.mainHeroLevel = _armyInfo.mainHeroLevel or 0
    defaultArmyInfo.deputyHeroId = _armyInfo.deputyHeroId or 0
    defaultArmyInfo.deputyHeroLevel = _armyInfo.deputyHeroLevel or 0
    defaultArmyInfo.resourceLoads = _armyInfo.resourceLoads
    defaultArmyInfo.collectResource = _armyInfo.collectResource
    defaultArmyInfo.status = _armyInfo.status
    defaultArmyInfo.attackInfo = _armyInfo.attackInfo
    defaultArmyInfo.speed = _armyInfo.speed
    defaultArmyInfo.path = _armyInfo.path
    defaultArmyInfo.arrivalTime = _armyInfo.arrivalTime or 0
    defaultArmyInfo.targetObjectIndex = _armyInfo.targetObjectIndex or 0
    defaultArmyInfo.armyName = roleInfo.name
    defaultArmyInfo.startTime = _armyInfo.startTime or os.time()
    defaultArmyInfo.isRally = isRally
    defaultArmyInfo.angle = 0
    defaultArmyInfo.guildAbbName = guildAbbName or ""
    defaultArmyInfo.skills = skills or {}
    defaultArmyInfo.mainHeroSkills = mainHeroSkills or {}
    defaultArmyInfo.deputyHeroSkills = deputyHeroSkills or {}
    defaultArmyInfo.sp = 0
    defaultArmyInfo.maxSp = ArmyLogic:cacleArmyMaxSp( skills ) or 0
    defaultArmyInfo.food = _armyInfo.food or 0
    defaultArmyInfo.wood = _armyInfo.wood or 0
    defaultArmyInfo.stone = _armyInfo.stone or 0
    defaultArmyInfo.gold = _armyInfo.gold or 0
    defaultArmyInfo.armyLoadAtPlunder = 0
    defaultArmyInfo.rallyArmy = _armyInfo.rallyArmy
    defaultArmyInfo.guildId = roleInfo.guildId
    defaultArmyInfo.guildFlagSigns = guildFlagSigns
    defaultArmyInfo.cityLevel = roleInfo.level
    defaultArmyInfo.buildArmyIndex = _armyInfo.buildArmyIndex or 0
    defaultArmyInfo.battleBuff = _armyInfo.battleBuff or {}
    defaultArmyInfo.talentAttr = HeroLogic:getHeroTalentAttr( defaultArmyInfo.rid, defaultArmyInfo.mainHeroId ).battleAttr
    defaultArmyInfo.equipAttr = HeroLogic:getHeroEquipAttr( defaultArmyInfo.rid, defaultArmyInfo.mainHeroId ).battleAttr

    -- 过滤已经过期的buff
    for index, buffInfo in pairs(defaultArmyInfo.battleBuff) do
        if buffInfo.turn and buffInfo.turn > 0 then
            if buffInfo.turn + buffInfo.time <= os.time() then
                defaultArmyInfo.battleBuff[index] = nil
            end
        end
    end

    -- 目标对象类型
    if _armyInfo.targetObjectIndex and _armyInfo.targetObjectIndex > 0 then
        local targetInfo = MSM.MapObjectTypeMgr[_armyInfo.targetObjectIndex].req.getObjectType( _armyInfo.targetObjectIndex )
        if targetInfo then
            defaultArmyInfo.targetObjectType = targetInfo.objectType
        end
    end

    -- 部队数量
    local soldiers = ArmyLogic:getArmySoldiersFromObject( defaultArmyInfo )
    local armyCount = ArmyLogic:getArmySoldierCount( soldiers )
    defaultArmyInfo.armyCount = armyCount
    defaultArmyInfo.armyCountMax = armyCount
    if not _armyInfo.armyCountMax then
        _armyInfo.armyCountMax = 0
    end
    if defaultArmyInfo.armyCountMax < _armyInfo.armyCountMax then
        defaultArmyInfo.armyCountMax = _armyInfo.armyCountMax
    end
    defaultArmyInfo.rallySoldierMax = armyCount
    defaultArmyInfo.armyRadius = CommonCacle:getArmyRadius( soldiers, isRally )

    mapArmyInfos[_objectIndex] = defaultArmyInfo

    local syncInfo = {
        arrivalTime = _armyInfo.arrivalTime or 0,
        path = _armyInfo.path,
        objectIndex = _armyInfo.objectIndex,
        startTime = mapArmyInfos[_objectIndex].startTime,
        isInRally = isRally,
        status = _armyInfo.status
    }

    -- 集结部队,更新队员
    if isRally then
        for rallyRid, rallyArmyIndex in pairs(mapArmyInfos[_objectIndex].rallyArmy) do
            if rallyRid ~= _armyInfo.rid then
                syncInfo.armyIndex = rallyArmyIndex
                ArmyLogic:updateArmyInfo( rallyRid, rallyArmyIndex, syncInfo )
            end
        end
    else
        ArmyLogic:updateArmyInfo( _armyInfo.rid, _armyInfo.armyIndex, syncInfo )
    end

    -- 判断是否出建筑
    if _armyInfo.outBuild then
        ArmyLogic:triggerSkillOnLeaveBuild( _objectIndex, defaultArmyInfo )
    end

    -- 获取联盟领地BUFF影响
    local isInGuildTerritory, buffIds
    if roleInfo.guildId > 0 then
        isInGuildTerritory, buffIds = MSM.GuildTerritoryMgr[roleInfo.guildId].req.checkGuildTerritoryPos( roleInfo.guildId, _armyInfo.pos )
        if isInGuildTerritory then
            -- 在联盟领地内
            ArmyLogic:addBuffToArmy( _objectIndex, defaultArmyInfo, buffIds, nil, true )
            -- 领地buff
            mapArmyInfos[_objectIndex].guildTerritoryBuff = buffIds
            mapArmyInfos[_objectIndex].isInGuildTerritory = isInGuildTerritory
        end
    end

    -- 计算buff对部队移动速度的影响
    --ArmyLogic:reCacleArmySpeed( _objectIndex, defaultArmyInfo, nil, nil, isInGuildTerritory )
end

---@see 更新军队坐标
function accept.updateArmyObjectPos( _objectIndex, _pos )
    if mapArmyInfos[_objectIndex] then
        _pos.x = math.floor( _pos.x )
        _pos.y = math.floor( _pos.y )
        local armyObjectInfo = mapArmyInfos[_objectIndex]
        armyObjectInfo.pos = _pos

        -- 如果处于战斗,更新坐标
        if ArmyLogic:checkArmyStatus( armyObjectInfo.status, Enum.ArmyStatus.BATTLEING ) then
            local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
            if battleIndex then
                -- 通知对象更新坐标
                local battleNode = BattleCreate:getBattleServerNode( battleIndex )
                Common.rpcMultiSend( battleNode, "BattleLoop", "updateObjectPos", battleIndex, _objectIndex, _pos, armyObjectInfo.angle )
            end
        end

        if armyWalkToInfo[_objectIndex] then
            if ArmyLogic:checkArmyStatus( armyObjectInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
                -- 溃败了,停下
                local mapArmyInfo, armyStatus
                for armyObjectIndex in pairs( armyWalkToInfo[_objectIndex] ) do
                    mapArmyInfo = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyInfo( armyObjectIndex )
                    if mapArmyInfo then
                        armyStatus = ArmyLogic:getArmy( mapArmyInfo.rid, mapArmyInfo.armyIndex, Enum.Army.status )
                        if armyStatus and ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.ATTACK_MARCH ) then
                            MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, nil, nil, nil, Enum.MapMarchTargetType.STATION )
                        end
                    end
                    -- 删除预警
                    EarlyWarningLogic:deleteEarlyWarning( mapArmyInfos[_objectIndex].rid, armyObjectIndex, _objectIndex )
                end
                armyWalkToInfo[_objectIndex] = nil
            else
                -- 如果有目标向军队行军,更新坐标
                for moveObjectIndex in pairs(armyWalkToInfo[_objectIndex]) do
                    local armyInfo = MSM.MapObjectTypeMgr[moveObjectIndex].req.getObjectInfo( moveObjectIndex )
                    if armyInfo then
                        if armyInfo.objectType == Enum.RoleType.ARMY and armyInfo.targetObjectIndex == _objectIndex then
                            -- 修正坐标
                            local fPos = armyInfo.pos
                            local fixPos = MSM.MapMarchMgr[moveObjectIndex].req.fixObjectPosWithMillisecond( moveObjectIndex, true )
                            if fixPos then
                                fPos = fixPos
                            end
                            local path = { fPos, _pos }
                            -- 修正坐标
                            local soldiers = ArmyLogic:getArmy( armyInfo.rid, armyInfo.armyIndex, Enum.Army.soldiers )
                            local moveRadius = CommonCacle:getArmyRadius( soldiers )
                            local targetRadius = armyObjectInfo.armyRadius
                            path = ArmyWalkLogic:fixPathPoint( nil, Enum.RoleType.ARMY, path, moveRadius, targetRadius, nil, armyInfo.rid )
                            -- 修正后的位置不能远离目标
                            if ArmyWalkLogic:cacleDistance( fPos, _pos ) > ArmyWalkLogic:cacleDistance( path[#path], _pos ) then
                                -- 更新部队路径
                                MSM.MapMarchMgr[moveObjectIndex].post.updateArmyMovePath( moveObjectIndex, _objectIndex, path )
                                -- 更新缩略线路径
                                if mapArmyInfos[_objectIndex] and mapArmyInfos[_objectIndex].armyMarchInfo[moveObjectIndex] then
                                    mapArmyInfos[_objectIndex].armyMarchInfo[moveObjectIndex].path = path
                                    -- 通过AOI通知
                                    local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
                                    sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [moveObjectIndex] = mapArmyInfos[_objectIndex].armyMarchInfo[moveObjectIndex] } } )
                                end
                            end
                        end
                    else
                        -- 部队不存在了
                        armyWalkToInfo[_objectIndex][moveObjectIndex] = nil
                    end
                end
            end
        end

        -- 获取联盟领地BUFF影响
        local guildId = armyObjectInfo.guildId
        if guildId > 0 then
            local isInGuildTerritory, buffIds = MSM.GuildTerritoryMgr[guildId].req.checkGuildTerritoryPos( guildId, _pos )
            if isInGuildTerritory ~= armyObjectInfo.isInGuildTerritory then
                if isInGuildTerritory then
                    -- 进联盟领地
                    ArmyLogic:addBuffToArmy( _objectIndex, armyObjectInfo, buffIds )
                    -- 领地buff
                    armyObjectInfo.guildTerritoryBuff = buffIds
                else
                    -- 出联盟领地
                    ArmyLogic:delBuffFromArmy( _objectIndex, armyObjectInfo, armyObjectInfo.guildTerritoryBuff )
                    -- 领地buff
                    armyObjectInfo.guildTerritoryBuff = {}
                end

                armyObjectInfo.isInGuildTerritory = isInGuildTerritory or false
            end
        end
    end
end

---@see 删除军队对象
function accept.deleteArmyObject( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        local armyInfo = mapArmyInfos[_objectIndex]
        local now = os.time()
        for _, buffInfo in pairs(mapArmyInfos[_objectIndex].battleBuff) do
            buffInfo.time = now
        end
        ArmyLogic:updateArmyInfo( armyInfo.rid, armyInfo.armyIndex, { battleBuff = mapArmyInfos[_objectIndex].battleBuff }, true )

        -- 向该目标行军的部队驻扎原地
        if armyWalkToInfo[_objectIndex] then
            local mapArmyInfo, armyStatus
            for armyObjectIndex in pairs( armyWalkToInfo[_objectIndex] ) do
                mapArmyInfo = MSM.SceneArmyMgr[armyObjectIndex].req.getArmyInfo( armyObjectIndex )
                if mapArmyInfo then
                    armyStatus = ArmyLogic:getArmy( mapArmyInfo.rid, mapArmyInfo.armyIndex, Enum.Army.status )
                    if armyStatus and ArmyLogic:checkArmyStatus( armyStatus, Enum.ArmyStatus.ATTACK_MARCH ) then
                        MSM.MapMarchMgr[armyObjectIndex].req.armyMove( armyObjectIndex, nil, nil, nil, Enum.MapMarchTargetType.STATION )
                    end
                end
                -- 删除预警
                EarlyWarningLogic:deleteEarlyWarning( armyInfo.rid, armyObjectIndex, _objectIndex )
            end
        end

        mapArmyInfos[_objectIndex] = nil
        armyWalkToInfo[_objectIndex] = nil
        MSM.AttackAroundPosMgr[_objectIndex].post.deleteAllRoundPos( _objectIndex )
    end
end

---@see 获取军队信息
function response.getArmyInfo( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].soldiers = ArmyLogic:getArmySoldiersFromObject( mapArmyInfos[_objectIndex] )
        return mapArmyInfos[_objectIndex]
    end
end

---@see 获取军队坐标
function response.getArmyPos( _objectIndex, _checkFail )
    if mapArmyInfos[_objectIndex] then
        if not _checkFail then
            return mapArmyInfos[_objectIndex].pos
        else
            return mapArmyInfos[_objectIndex].pos, ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.FAILED_MARCH )
        end
    end
end

---@see 获取军队状态
function response.getArmyStatus( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        return mapArmyInfos[_objectIndex].status
    end
end

---@see 获取军队所属联盟
function response.getArmyGuild( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        return mapArmyInfos[_objectIndex].guildId
    end
end

---@see 更新军队状态
function response.updateArmyStatus( _objectIndex, _status, _statusOp, _saveTargetObjectIndex, _logFlag )
    if mapArmyInfos[_objectIndex] then
        local armyInfo = mapArmyInfos[_objectIndex]
        local oldStatus = armyInfo.status
        local oldTargetIndex = armyInfo.targetObjectIndex
        -- 状态更新
        armyInfo.status = ArmyLogic:grepObjectStatus( _objectIndex, armyInfo, _status, _statusOp )
        if _saveTargetObjectIndex then
            armyInfo.targetObjectIndex = oldTargetIndex
        end
        local battleBuff
        if ArmyLogic:checkArmyStatus( oldStatus, Enum.ArmyStatus.BATTLEING )
        and not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 战斗变非战斗,移除buff(战斗外生效的不移除)
            local sSkillStatus
            for index, buffInfo in pairs(armyInfo.battleBuff) do
                sSkillStatus = CFG.s_SkillStatus:Get( buffInfo.buffId )
                if sSkillStatus then
                    if not sSkillStatus.battleEffectType or sSkillStatus.battleEffectType == 0 then
                        -- 不生效,移除
                        armyInfo.battleBuff[index] = nil
                    end
                end
            end
            battleBuff = armyInfo.battleBuff
            -- 计算buff对战斗外影响
            ArmyLogic:reCacleArmySpeed( _objectIndex, armyInfo, nil, nil, armyInfo.isInGuildTerritory )
        end

        -- 如果是集结部队,通知集结部队状态的改变
        if armyInfo.isRally then
            for rallyRid, armyIndex in pairs(armyInfo.rallyArmy) do
                ArmyLogic:updateArmyStatus( rallyRid, armyIndex, armyInfo.status )
            end
        else
            -- 通知客户端军队状态改变
            ArmyLogic:updateArmyStatus( armyInfo.rid, armyInfo.armyIndex, armyInfo.status )
        end

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, {
                                                            status = armyInfo.status,
                                                            pos = armyInfo.pos,
                                                            battleBuff = battleBuff,
                                                            targetObjectIndex = armyInfo.targetObjectIndex
                                                    }
                                    )
        if _logFlag then
            -- 部队驻扎日志
            local roleArmyInfo = ArmyLogic:getArmy( armyInfo.rid, armyInfo.armyIndex ) or {}
            if not table.empty( armyInfo ) then
                LogLogic:troopsMarch( {
                    rid = armyInfo.rid, iggid = RoleLogic:getRole( armyInfo.rid, Enum.Role.iggid ),
                    status = armyInfo.status, mainHeroId = roleArmyInfo.mainHeroId, deputyHeroId = roleArmyInfo.deputyHeroId,
                    soldiers = roleArmyInfo.soldiers, minorSoldiers = roleArmyInfo.minorSoldiers, armyIndex = armyInfo.armyIndex
                } )
            end
        end
    end
end

---@see 添加军队驻扎状态
function accept.addArmyStation( _objectIndex, _newPos, _logFlag )
    if mapArmyInfos[_objectIndex] then
        local oldTargetIndex = mapArmyInfos[_objectIndex].targetObjectIndex
        -- 修正位置
        if _newPos then
            mapArmyInfos[_objectIndex].pos = _newPos
        end

        if ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            -- 移除所有的移动状态
            mapArmyInfos[_objectIndex].status = ArmyLogic:removeMoveStatus( mapArmyInfos[_objectIndex].status )
            -- 添加驻扎
            mapArmyInfos[_objectIndex].status = ArmyLogic:addArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.STATIONING )
            -- 同步战斗服务器状态
            BattleAttrLogic:syncObjectStatus( _objectIndex, mapArmyInfos[_objectIndex].status )
            -- 通知目标回头攻击目标
            BattleCreate:removeObjectStopAttack( _objectIndex )
        else
            mapArmyInfos[_objectIndex].status = Enum.ArmyStatus.STATIONING
            mapArmyInfos[_objectIndex].path = {} -- 驻扎,移除路径
            mapArmyInfos[_objectIndex].targetObjectIndex = 0
            -- 更新armyInfo的path
            ArmyLogic:updateArmyInfo( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex, {
                [Enum.Army.path] = {}, [Enum.Army.targetType] = 0,
                [Enum.Army.targetArg] = { pos = mapArmyInfos[_objectIndex].pos, targetObjectIndex = 0 },
            } )
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
            sceneObject.post.syncObjectInfo( _objectIndex, { path = {} } )
        end
        -- 取消追击
        if mapArmyFollowInfos[_objectIndex] then
            mapArmyFollowInfos[_objectIndex] = nil
        end

        -- 移除向目标行军
        if oldTargetIndex > 0 then
            local oldTargetInfo = MSM.MapObjectTypeMgr[oldTargetIndex].req.getObjectType( oldTargetIndex )
            if oldTargetInfo then
                ArmyWalkLogic:delArmyWalkTargetInfo( oldTargetIndex, oldTargetInfo.objectType, _objectIndex )
            end
        end

        -- 通知客户端军队状态改变
        ArmyLogic:updateArmyStatus( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex, mapArmyInfos[_objectIndex].status )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, {
                                                            status = mapArmyInfos[_objectIndex].status,
                                                            pos = mapArmyInfos[_objectIndex].pos,
                                                            targetObjectIndex = mapArmyInfos[_objectIndex].targetObjectIndex
                                                        } )
        if _logFlag then
            local armyInfo = ArmyLogic:getArmy( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex ) or {}
            if not table.empty( armyInfo ) then
                LogLogic:troopsMarch( {
                    rid = mapArmyInfos[_objectIndex].rid, iggid = RoleLogic:getRole( mapArmyInfos[_objectIndex].rid, Enum.Role.iggid ),
                    status = mapArmyInfos[_objectIndex].status, mainHeroId = armyInfo.mainHeroId, deputyHeroId = armyInfo.deputyHeroId,
                    soldiers = armyInfo.soldiers, minorSoldiers = armyInfo.minorSoldiers, armyIndex = mapArmyInfos[_objectIndex].armyIndex
                } )
            end
        end
    end
end

---@see 移除军队驻扎状态
function accept.removeArmyStation( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].status = ArmyLogic:delArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.STATIONING )
        -- 通知客户端军队状态改变
        ArmyLogic:updateArmyStatus( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex, mapArmyInfos[_objectIndex].status )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapArmyInfos[_objectIndex].status } )
    end
end

---@see 同步部队路径给客户端
function accept.syncArmyPos( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        local status = ArmyLogic:addArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.MOVE )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = { mapArmyInfos[_objectIndex].pos, mapArmyInfos[_objectIndex].pos }, status = status } )
    end
end

---@see 部队路径置空
function response.setPathEmpty( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].path = {}
        -- 更新armyInfo的path
        ArmyLogic:updateArmyInfo( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex, { path = {} } )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = {} } )
    end
end

---@see 更新军队行军路径
function accept.updateArmyPath( _objectIndex, _path, _arrivalTime, _startTime, _targetObjectIndex, _status, _noSync, _buildArmyIndex )
    if mapArmyInfos[_objectIndex] then
        -- 更新目标
        if _targetObjectIndex then
            mapArmyInfos[_objectIndex].targetObjectIndex = _targetObjectIndex
        end
        -- 达到时间
        mapArmyInfos[_objectIndex].arrivalTime = _arrivalTime
        mapArmyInfos[_objectIndex].startTime = _startTime
        mapArmyInfos[_objectIndex].path = _path
        if _buildArmyIndex then
            mapArmyInfos[_objectIndex].buildArmyIndex = _buildArmyIndex
        end
        if _status then
            if ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
                _status = ArmyLogic:addArmyStatus( _status, Enum.ArmyStatus.BATTLEING )
                -- 同步战斗服务器状态
                BattleAttrLogic:syncObjectStatus( _objectIndex, _status )
            end
            mapArmyInfos[_objectIndex].status = _status
            -- 通知客户端军队状态改变
            ArmyLogic:updateArmyStatus( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex, _status )
        end

        -- 更新军队属性
        ArmyLogic:updateArmyInfo( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex,
                                { objectIndex = _objectIndex, arrivalTime = _arrivalTime, startTime = _startTime, path = _path, status = _status }, _noSync )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = _path, arrivalTime = _arrivalTime, startTime = _startTime,
                                            status = mapArmyInfos[_objectIndex].status } )
        if _targetObjectIndex then
            -- 计算同目标角度
            local pathCount = #_path
            local angle = math.floor( ArmyWalkLogic:cacleAnagle( _path[pathCount-1], _path[pathCount] ) * 100 )
            mapArmyInfos[_objectIndex].angle = angle
            sceneObject.post.syncObjectInfo( _objectIndex, { targetObjectIndex = _targetObjectIndex } )
            local objectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
            mapArmyInfos[_objectIndex].targetObjectType = objectInfo and objectInfo.objectType or 0
        end
    end
end

---@see 更新军队部队血量
function accept.updateArmyCountAndSp( _objectIndex, _armyCount, _sp )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].armyCount = _armyCount
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = _armyCount, sp = _sp } )
    end
end

---@see 同步部队士兵为空
function accept.syncSoldierEmpty( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].battleBuff = {}
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { soldiers = {}, battleBuff = {} } )
    end
end

---@see 更新军队目标
function accept.updateArmyTargetObjectIndex( _objectIndex, _targetObjectIndex, _isFromBattle )
    if mapArmyInfos[_objectIndex] then
        _targetObjectIndex = _targetObjectIndex or 0
        if _targetObjectIndex == 0 and mapArmyInfos[_objectIndex].targetObjectIndex == _targetObjectIndex then
            return
        end
        mapArmyInfos[_objectIndex].targetObjectIndex = _targetObjectIndex
        -- 如果在战斗,同步给战斗服务器
        if not _isFromBattle and ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
            if battleIndex then
                local battleNode = BattleCreate:getBattleServerNode( battleIndex )
                Common.rpcMultiSend( battleNode, "BattleLoop", "changeAttackTarget", battleIndex, _objectIndex, _targetObjectIndex )
            end
        end
        -- 计算面向目标角度
        local angle, objectInfo
        if _targetObjectIndex > 0 then
            objectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
            if objectInfo then
                if objectInfo.objectType == Enum.RoleType.MONSTER or objectInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND
                    or objectInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or objectInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
                    local monsterInfo = MSM.SceneMonsterMgr[_targetObjectIndex].req.getMonsterInfo( _targetObjectIndex )
                    if monsterInfo then
                        angle = math.floor( ArmyWalkLogic:cacleAnagle( mapArmyInfos[_objectIndex].pos, monsterInfo.pos ) * 100 )
                    end
                elseif objectInfo.objectType == Enum.RoleType.ARMY then
                    local armyInfo = MSM.SceneArmyMgr[_targetObjectIndex].req.getArmyInfo( _targetObjectIndex )
                    if armyInfo then
                        angle = math.floor( ArmyWalkLogic:cacleAnagle( mapArmyInfos[_objectIndex].pos, armyInfo.pos ) * 100 )
                    end
                end
            end
        end
        mapArmyInfos[_objectIndex].angle = angle or 0
        mapArmyInfos[_objectIndex].targetObjectType = objectInfo and objectInfo.objectType or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { targetObjectIndex = _targetObjectIndex } )
    end
end

---@see 同步攻击者数量.用于显示夹击
function accept.syncAttackCount( _objectIndex, _attackCount )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].attackCount = _attackCount
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { attackCount = _attackCount } )
    end
end

---@see 通知所有正在战斗的部队.结束战斗.并回城.行军的直接解散
function response.notifyArmyBattleExitAndBackCity()
    for objectIndex, armyInfo in pairs(mapArmyInfos) do
        if armyInfo.food > 0 or armyInfo.wood > 0 or armyInfo.stone > 0 or armyInfo.gold > 0 then
            MSM.SceneArmyMgr[objectIndex].req.addResourceFromArmy( objectIndex )
        end
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 通知战斗服务器退出战斗
            local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( objectIndex )
            if battleIndex then
                -- 对象退出战斗
                local battleNode = BattleCreate:getBattleServerNode( battleIndex )
                Common.rpcMultiCall( battleNode, "BattleLoop", "objectExitBattleOnClose", battleIndex, objectIndex )
                -- 军队直接回城
                ArmyLogic:disbandArmy( armyInfo.rid, armyInfo.armyIndex )
            end
        elseif not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECT_MARCH ) then
            -- 不处于采集,直接解散
            ArmyLogic:disbandArmy( armyInfo.rid, armyInfo.armyIndex, true )
        end
    end
end

---@see 军队追击目标
function accept.armyFollowUp( _objectIndex, _followObjectIndex, _followObjectType )
    if mapArmyInfos[_objectIndex] and not mapArmyFollowInfos[_objectIndex] then
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        -- 如果部队处于驻扎、移动指令中,不进行追击
        local status = mapArmyInfos[_objectIndex].status
        local isStation = ArmyLogic:checkArmyStatus( status, Enum.ArmyStatus.STATIONING )
        if isStation or ArmyLogic:checkArmyWalkStatus( status ) then
            return
        end

        mapArmyFollowInfos[_objectIndex] = {
                                                followObjectIndex = _followObjectIndex,
                                                followObjectType = _followObjectType
                                        }
        -- 部队添加追击状态
        mapArmyInfos[_objectIndex].status = ArmyLogic:addArmyStatus( status, Enum.ArmyStatus.FOLLOWUP )
        -- 同步状态
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapArmyInfos[_objectIndex].status } )
    end
end

---@see 停止追击
function response.stopFollowUp( _objectIndex )
    if mapArmyInfos[_objectIndex] and mapArmyFollowInfos[_objectIndex] then
        mapArmyFollowInfos[_objectIndex] = nil
        -- 停止移动
        MSM.MapMarchMgr[_objectIndex].req.stopObjectMove( _objectIndex )
        -- 移除追击状态
        local status = mapArmyInfos[_objectIndex].status
        mapArmyInfos[_objectIndex].status = ArmyLogic:delArmyStatus( status, Enum.ArmyStatus.FOLLOWUP )
        -- 同步状态
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapArmyInfos[_objectIndex].status } )
    end
end

---@see 同步对象联盟简称
function accept.syncGuildAbbName( _objectIndex, _guildAbbName, _guildId )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].guildAbbName = _guildAbbName
        if _guildId then
            mapArmyInfos[_objectIndex].guildId = _guildId
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildAbbName = _guildAbbName, guildId = _guildId } )
    end
end

---@see 同步对象名称
function accept.syncArmyName( _objectIndex, _name )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].armyName = _name

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyName = _name } )
    end
end

---@see 同步对象战斗buff
function accept.syncArmyBattleBuff( _objectIndex, _battleBuff )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].battleBuff = _battleBuff
        -- 计算buff对战斗外影响
        ArmyLogic:reCacleArmySpeed( _objectIndex, mapArmyInfos[_objectIndex], nil, nil, mapArmyInfos[_objectIndex].isInGuildTerritory )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = _battleBuff } )
    end
end

---@see 添加对象战斗buff
function accept.addArmyBattleBuff( _objectIndex, _statusId )
    if mapArmyInfos[_objectIndex] then
        table.insert( mapArmyInfos[_objectIndex].battleBuff, { buffId = _statusId, isNew = true } )
        -- 计算buff对战斗外影响
        ArmyLogic:reCacleArmySpeed( _objectIndex, mapArmyInfos[_objectIndex], nil, nil, mapArmyInfos[_objectIndex].isInGuildTerritory )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { battleBuff = mapArmyInfos[_objectIndex].battleBuff } )
        -- 这里是临时对象,不用再通知战斗服务器,会引起循环加BUFF
        --[[
        -- 如果处于战斗中,通知战斗服务器
        if ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            local battleIndex = SM.BattleIndexReg.req.getObjectBattleIndex( _objectIndex )
            if battleIndex then
                local battleNode = BattleCreate:getBattleServerNode( battleIndex )
                if battleNode then
                    Common.rpcMultiSend( battleNode, "BattleLoop", "objectAddBuff", battleIndex, _objectIndex, { _statusId } )
                end
            end
        end
        ]]
    end
end

---@see 增加向部队行军的对象
function accept.addArmyWalkToArmy( _objectIndex, _armyObjectIndex, _marchType, _arrivalTime, _path )
    if mapArmyInfos[_objectIndex] then
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
        mapArmyInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = armyMarchInfo
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = armyMarchInfo } } )
    end
end

---@see 移除向部队行军的对象
function accept.delArmyWalkToArmy( _objectIndex, _armyObjectIndex )
    if mapArmyInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            armyWalkToInfo[_objectIndex][_armyObjectIndex] = nil
            mapArmyInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] = nil
            if table.empty(armyWalkToInfo[_objectIndex]) then
                armyWalkToInfo[_objectIndex] = nil
            end
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = { objectIndex = _armyObjectIndex, isDelete = true } } } )
        end
    end
end

---@see 获取向部队行军的对象
function response.getArmyWalkToArmy( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        if armyWalkToInfo[_objectIndex] then
            return table.indexs( armyWalkToInfo[_objectIndex] )
        end
    end
end

---@see 更新目标移动缩略线
function accept.updateArmyMarchPath( _objectIndex, _moveObjectIndex, _path )
    -- 更新缩略线路径
    if mapArmyInfos[_objectIndex] and mapArmyInfos[_objectIndex].armyMarchInfo[_moveObjectIndex] then
        mapArmyInfos[_objectIndex].armyMarchInfo[_moveObjectIndex].path = _path
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_moveObjectIndex] = mapArmyInfos[_objectIndex].armyMarchInfo[_moveObjectIndex] } } )
    end
end

---@see 更新向目标行军的目标联盟
function accept.updateArmyWalkObjectGuildId( _objectIndex, _armyObjectIndex, _guildId )
    if mapArmyInfos[_objectIndex] and mapArmyInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] then
        mapArmyInfos[_objectIndex].armyMarchInfo[_armyObjectIndex].guildId = _guildId or 0
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyMarchInfos = { [_armyObjectIndex] = mapArmyInfos[_objectIndex].armyMarchInfo[_armyObjectIndex] } } )
    end
end

---@see 获取部队当前资源负载
function response.getArmyResourceLoad( _objectIndex )
    local objectInfo = mapArmyInfos[_objectIndex]
    local resourceLoad = 0
    if objectInfo then
        local soldiers = ArmyLogic:getArmySoldiersFromObject( objectInfo )
        resourceLoad = ArmyLogic:cacleArmyCapacity( objectInfo.rid, soldiers )
        -- 扣除已有掠夺的资源
        resourceLoad = resourceLoad - objectInfo.food - objectInfo.wood - objectInfo.stone - objectInfo.gold
        if resourceLoad < 0 then
            resourceLoad = 0
        end
    end

    return resourceLoad
end

---@see 更新部队当前掠夺资源
function accept.syncArmyResourceLoad( _objectIndex, _food, _wood, _stone, _gold )
    local objectInfo = mapArmyInfos[_objectIndex]
    if objectInfo then
        objectInfo.food = objectInfo.food + _food
        objectInfo.wood = objectInfo.wood + _wood
        objectInfo.stone = objectInfo.stone + _stone
        objectInfo.gold = objectInfo.gold + _gold
        local soldiers = ArmyLogic:getArmySoldiersFromObject( objectInfo )
        objectInfo.armyLoadAtPlunder = ArmyLogic:cacleArmyCapacity( objectInfo.rid, soldiers )
    end
end

---@see 部队掠夺资源更新到角色身上
function response.addResourceFromArmy( _objectIndex )
    local objectInfo = mapArmyInfos[_objectIndex]
    if objectInfo then
        local soldiers = ArmyLogic:getArmySoldiersFromObject( objectInfo )
        local armyCount = ArmyLogic:getArmySoldierCount( soldiers )
        if armyCount > 0 then
            local resourceLoad = ArmyLogic:cacleArmyCapacity( objectInfo.rid, soldiers )
            local allResource = objectInfo.food + objectInfo.wood + objectInfo.stone + objectInfo.gold
            if allResource > resourceLoad and objectInfo.armyLoadAtPlunder > 0 then
                objectInfo.food = math.floor( objectInfo.food * ( resourceLoad / objectInfo.armyLoadAtPlunder ) )
                objectInfo.wood = math.floor( objectInfo.wood * ( resourceLoad / objectInfo.armyLoadAtPlunder ) )
                objectInfo.stone = math.floor( objectInfo.stone * ( resourceLoad / objectInfo.armyLoadAtPlunder ) )
                objectInfo.gold = math.floor( objectInfo.gold * ( resourceLoad / objectInfo.armyLoadAtPlunder ) )
            end
            -- 资源增加到角色身上
            if objectInfo.food > 0 then
                RoleLogic:addFood( objectInfo.rid, objectInfo.food, nil, Enum.LogType.PVP_GET_RESOURCE )
            end
            if objectInfo.wood > 0 then
                RoleLogic:addWood( objectInfo.rid, objectInfo.wood, nil, Enum.LogType.PVP_GET_RESOURCE )
            end
            if objectInfo.stone > 0 then
                RoleLogic:addStone( objectInfo.rid, objectInfo.stone, nil, Enum.LogType.PVP_GET_RESOURCE )
            end
            if objectInfo.gold > 0 then
                RoleLogic:addGold( objectInfo.rid, objectInfo.gold, nil, Enum.LogType.PVP_GET_RESOURCE )
            end
        end
    end
end

---@see 增加移动状态
function accept.addMoveStatus( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].status = ArmyLogic:addArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.MOVE )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapArmyInfos[_objectIndex].status } )
    end
end

---@see 移除移动状态
function accept.delMoveStatus( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].status = ArmyLogic:delArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.MOVE )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = mapArmyInfos[_objectIndex].status } )
    end
end

---@see 判断目标是否是集结部队
function response.checkIsRallyArmy( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        return mapArmyInfos[_objectIndex].isRally
    end
end

---@see 增援部队加入集结部队
function accept.reinforceAddToRally( _objectIndex, _reinforceRid, _reinforceArmyIndex )
    if mapArmyInfos[_objectIndex] and mapArmyInfos[_objectIndex].isRally then
        local armyInfo = ArmyLogic:getArmy( _reinforceRid, _reinforceArmyIndex )
        -- 集结部队
        mapArmyInfos[_objectIndex].rallyArmy[_reinforceRid] = _reinforceArmyIndex
        -- 重新计算部队数量
        local allArmyCount = 0
        for rid, armyIndex in pairs(mapArmyInfos[_objectIndex].rallyArmy) do
            allArmyCount = allArmyCount + ArmyLogic:getArmySoldierCount( nil, rid, armyIndex )
        end
        mapArmyInfos[_objectIndex].armyCount = allArmyCount
        local armyCountMax = mapArmyInfos[_objectIndex].rallySoldierMax + ArmyLogic:getArmySoldierCount( armyInfo.soldiers )
        mapArmyInfos[_objectIndex].armyCountMax = armyCountMax

        -- 如果部队正在战斗,通知战斗服务器士兵加入
        if ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
            BattleAttrLogic:notifyBattleAddSoldier( _objectIndex, armyInfo.soldiers, _reinforceRid, _reinforceArmyIndex, armyInfo.mainHeroId, armyInfo.mainHeroLevel, armyInfo.deputyHeroId, armyInfo.deputyHeroLevel )
            -- 增援加入战斗
            BattleAttrLogic:reinforceJoinBattle( _objectIndex, _reinforceRid, _reinforceArmyIndex )
            if ( armyInfo.preCostActionForce or 0 ) > 0 then
                -- 增援部队有预扣除的行动力且集结队伍队长行动力已扣除
                local leaderPreCostActionForce = ArmyLogic:getArmy( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].armyIndex, Enum.Army.preCostActionForce )
                if ( leaderPreCostActionForce or 0 ) <= 0 then
                    -- 删除预扣除的活动力
                    ArmyLogic:setArmy( _reinforceRid, _reinforceArmyIndex, { [Enum.Army.preCostActionForce] = 0 } )
                    -- 通知客户端预扣除行动力
                    ArmyLogic:syncArmy( _reinforceRid, _reinforceArmyIndex, { [Enum.Army.preCostActionForce] = 0 }, true )
                end
            end
        end

        -- 同步地图最大血量
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = allArmyCount, armyCountMax = armyCountMax } )
    end
end

---@see 解散集结部队
function response.disbandRallyArmy( _objectIndex )
    if mapArmyInfos[_objectIndex] and mapArmyInfos[_objectIndex].isRally then
        ArmyLogic:disbandRallyArmy( mapArmyInfos[_objectIndex].rallyArmy )
    end
end

---@see 移除移动状态
function accept.syncArmyCollectRuneTime( _objectIndex, _collectRuneTime, _armyStatus )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].collectRuneTime = _collectRuneTime
        if _armyStatus then
            mapArmyInfos[_objectIndex].status = _armyStatus
        end

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { collectRuneTime = _collectRuneTime, status = _armyStatus } )
    end
end

---@see 更新部队联盟旗帜标识
function accept.syncArmyGuildFlagSigns( _objectIndex, _guildFlagSigns )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].guildFlagSigns = _guildFlagSigns
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildFlagSigns = _guildFlagSigns } )
    end
end

---@see 判断部队是否在攻击同盟
function accept.checkArmyAttackGuildMember( _objectIndex )
    if mapArmyInfos[_objectIndex] then
        -- 判断攻击对象
        local targetIndex = mapArmyInfos[_objectIndex].targetObjectIndex
        local targetGuildId = MSM.MapObjectTypeMgr[targetIndex].req.getObjectGuildId( targetIndex )
        local guildId = RoleLogic:getRole( mapArmyInfos[_objectIndex].rid, Enum.Role.guildId )
        if targetGuildId > 0 and targetGuildId == guildId then
            if ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
                -- 部队退出战斗
                BattleCreate:exitBattle( _objectIndex )
            else
                -- 回城
                MSM.MapMarchMgr[_objectIndex].req.marchBackCity( mapArmyInfos[_objectIndex].rid, _objectIndex )
            end
        end
    end
end

---@see 集结部队中的一个成员退出集结部队
function accept.rallyMemberExitTeam( _objectIndex, _exitRid )
    if mapArmyInfos[_objectIndex] and mapArmyInfos[_objectIndex].isRally then
        if mapArmyInfos[_objectIndex].rallyArmy[_exitRid] then
            -- 如果部队正在战斗,通知战斗服务器士兵减少
            if ArmyLogic:checkArmyStatus( mapArmyInfos[_objectIndex].status, Enum.ArmyStatus.BATTLEING ) then
                local armyInfo = ArmyLogic:getArmy( _exitRid, mapArmyInfos[_objectIndex].rallyArmy[_exitRid] )
                BattleAttrLogic:notifyBattleSubSoldier( _objectIndex, armyInfo.soldiers, _exitRid, _exitRid, mapArmyInfos[_objectIndex].rallyArmy[_exitRid] )
            end
            mapArmyInfos[_objectIndex].rallyArmy[_exitRid] = nil
            -- 重新计算部队数量
            local soldiers = ArmyLogic:getArmySoldiersFromObject( mapArmyInfos[_objectIndex] )
            local armyCount = ArmyLogic:getArmySoldierCount( soldiers )
            mapArmyInfos[_objectIndex].armyCount = armyCount
            -- 通过AOI通知
            local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
            sceneObject.post.syncObjectInfo( _objectIndex, { armyCount = armyCount, soldiers = soldiers } )
        end
    end
end

---@see 更新部队市政厅等级
function accept.syncArmyCityLevel( _objectIndex, _cityLevel )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].cityLevel = _cityLevel
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { cityLevel = _cityLevel } )
    end
end

---@see 更新部队统帅技能
function accept.syncHeroSkill( _objectIndex, _mainHeroId, _mainHeroLevel, _deputyHeroId, _deputyHeroLevel )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].mainHeroId = _mainHeroId or 0
        mapArmyInfos[_objectIndex].mainHeroLevel = _mainHeroLevel or 0
        mapArmyInfos[_objectIndex].deputyHeroId = _deputyHeroId or 0
        mapArmyInfos[_objectIndex].deputyHeroLevel = _deputyHeroLevel or 0

        -- 获取技能
        local skills, mainHeroSkills, deputyHeroSkills = HeroLogic:getRoleAllHeroSkills( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].mainHeroId, mapArmyInfos[_objectIndex].deputyHeroId )
        mapArmyInfos[_objectIndex].skills = skills or {}
        mapArmyInfos[_objectIndex].mainHeroSkills = mainHeroSkills or {}
        mapArmyInfos[_objectIndex].deputyHeroSkills = deputyHeroSkills or {}

        -- 获取天赋属性
        mapArmyInfos[_objectIndex].talentAttr = HeroLogic:getHeroTalentAttr( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].mainHeroId ).battleAttr
        -- 获取装备
        mapArmyInfos[_objectIndex].equipAttr = HeroLogic:getHeroEquipAttr( mapArmyInfos[_objectIndex].rid, mapArmyInfos[_objectIndex].mainHeroId ).battleAttr

        -- 同步给客户端
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { mainHeroSkills = mainHeroSkills, deputyHeroSkills = deputyHeroSkills } )
        -- 重新计算速度
        ArmyLogic:reCacleArmySpeed( _objectIndex, mapArmyInfos[_objectIndex], nil, nil, mapArmyInfos[_objectIndex].isInGuildTerritory )
    end
end

---@see 更新部队buff信息
function accept.updateArmyBuff( _objectIndex )
    local armyObjectInfo = mapArmyInfos[_objectIndex]
    if armyObjectInfo then
        local guildId = armyObjectInfo.guildId
        if guildId > 0 and armyObjectInfo.isInGuildTerritory then
            -- 部队在联盟领土上
            local _, buffIds = MSM.GuildTerritoryMgr[guildId].req.checkGuildTerritoryPos( guildId, armyObjectInfo.pos )
            -- 移除联盟领土buff
            ArmyLogic:delBuffFromArmy( _objectIndex, armyObjectInfo, armyObjectInfo.guildTerritoryBuff )
            -- 添加新的联盟领土buff
            ArmyLogic:addBuffToArmy( _objectIndex, armyObjectInfo, buffIds )
            armyObjectInfo.guildTerritoryBuff = buffIds
            armyObjectInfo.isInGuildTerritory = true
        end
    end
end

---@see 更新军队部队速度
function accept.updateArmySpeed( _objectIndex, _speed )
    if mapArmyInfos[_objectIndex] then
        mapArmyInfos[_objectIndex].speed = _speed
    end
end