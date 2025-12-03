--[[
 * @file : ArmyWalkLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2019-12-24 16:52:16
 * @Last Modified time: 2019-12-24 16:52:16
 * @department : Arabic Studio
 * @brief : 军队行走模拟
 * Copyright(C) 2019 IGG, All rights reserved
]]

local math = math
local table = table

local ArmyMarchCallback = require "ArmyMarchCallback"
local MapObjectLogic = require "MapObjectLogic"
local RoleLogic = require "RoleLogic"
local Random = require "Random"
local MapProvinceLogic = require "MapProvinceLogic"
local timeCore = require "timer.core"
local sharedata = require "skynet.sharedata"
local ArmyLogic = require "ArmyLogic"

local ArmyWalkLogic = {}

---@see 行军完毕回调处理
function ArmyWalkLogic:marchCallback( _marchType, _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    LOG_INFO("rid(%s) armyIndex(%s) marchType(%s) marchCallback", tostring(_rid), tostring(_armyIndex), tostring(_marchType))
    local collectAttackers
    -- 部分行军到达了,要先退战斗
    if _marchType == Enum.MapMarchTargetType.REINFORCE or _marchType == Enum.MapMarchTargetType.RALLY
    or _marchType == Enum.MapMarchTargetType.COLLECT or _marchType == Enum.MapMarchTargetType.RETREAT then
        -- 如果正在战斗,通知战斗服务器退出战斗
        local armyInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
        if not armyInfo then
            return
        end
        -- 记录下之前攻击者,如果是采集,要转向攻击资源点
        if _marchType == Enum.MapMarchTargetType.COLLECT then
            collectAttackers = MSM.AttackAroundPosMgr[_objectIndex].req.getAttackerIndexs( _objectIndex )
            -- 正在向部队行军的也要加入
            local walkAttackers = MSM.SceneArmyMgr[_objectIndex].req.getArmyWalkToArmy( _objectIndex )
            if walkAttackers then
                table.merge( collectAttackers, walkAttackers )
            end
        end

        -- 退出战斗
        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
            local BattleCreate = require "BattleCreate"
            BattleCreate:exitBattle( _objectIndex, true )
        end
    end

    -- 清除部队行军状态
    if _objectType then
        if _marchType ~= Enum.MapMarchTargetType.TRANSPORT and _marchType ~= Enum.MapMarchTargetType.TRANSPORT_BACK
            and _marchType ~= Enum.MapMarchTargetType.SCOUTS and _marchType ~= Enum.MapMarchTargetType.SCOUTS_BACK then
            local ret, err = xpcall(self.cancleArmyMoveStatus, debug.traceback, self, _objectIndex, _objectType, _marchType, _targetObjectIndex )
            if not ret then
                LOG_ERROR("cancleArmyMoveStatus err:%s", err)
            end
        end
    end

    -- 判断加入站位
    if _marchType == Enum.MapMarchTargetType.FOLLOWUP or _marchType == Enum.MapMarchTargetType.MOVE then
        self:checkAddAttacker( _objectIndex, _objectType, _targetObjectIndex )
    end

    if _targetObjectIndex and _targetObjectIndex > 0 then
        -- 移除向目标行军
        local targetInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
        if targetInfo then
            self:delArmyWalkTargetInfo( _targetObjectIndex, targetInfo.objectType, _objectIndex )
        end
    end

    -- 路径信息清除
    if _objectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_objectIndex].req.setPathEmpty( _objectIndex )
    elseif _objectType == Enum.RoleType.SCOUTS then
        MSM.SceneScoutsMgr[_objectIndex].req.setPathEmpty( _objectIndex )
    end

    LOG_INFO("rid(%s) armyIndex(%s) marchType(%s) begin dispatch callback", tostring(_rid), tostring(_armyIndex), tostring(_marchType))
    if _marchType == Enum.MapMarchTargetType.SPACE then
        -- 空地
        ArmyMarchCallback:spaceMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    elseif _marchType == Enum.MapMarchTargetType.ATTACK then
        -- 攻击
        ArmyMarchCallback:attackMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    elseif _marchType == Enum.MapMarchTargetType.REINFORCE then
        -- 增援
        ArmyMarchCallback:reinforceMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    elseif _marchType == Enum.MapMarchTargetType.RALLY then
        -- 集结
        ArmyMarchCallback:rallyMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    elseif _marchType == Enum.MapMarchTargetType.COLLECT then
        -- 采集
        ArmyMarchCallback:collectMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos, collectAttackers )
    elseif _marchType == Enum.MapMarchTargetType.RETREAT then
        -- 撤退
        ArmyMarchCallback:retreatMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    elseif _marchType == Enum.MapMarchTargetType.SCOUTS then
        -- 侦查
        ArmyMarchCallback:scoutsMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    elseif _marchType == Enum.MapMarchTargetType.SCOUTS_BACK then
        -- 斥候回城
        ArmyMarchCallback:scoutsBackMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    elseif _marchType == Enum.MapMarchTargetType.FOLLOWUP then
        -- 追击
        ArmyMarchCallback:followUpMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    elseif _marchType == Enum.MapMarchTargetType.MOVE then
        -- 移动
        ArmyMarchCallback:moveMarchCallback( _rid, _armyIndex, _objectIndex, _objectType )
    elseif _marchType == Enum.MapMarchTargetType.TRANSPORT then
        -- 资源援助
        ArmyMarchCallback:transportCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    elseif _marchType == Enum.MapMarchTargetType.TRANSPORT_BACK then
        -- 资源援助返回
        ArmyMarchCallback:marchBackCity( _rid, _armyIndex, _objectIndex, _objectType )
    elseif _marchType == Enum.MapMarchTargetType.RALLY_ATTACK then
        -- 集结攻击
        ArmyMarchCallback:rallyAttackCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    elseif _marchType == Enum.MapMarchTargetType.BATTLELOSE_TRANSPORT then
        -- 战损资源
        ArmyMarchCallback:battleLoseTransportCallback( _rid, _armyIndex, _objectIndex )
    end
end

---@see 远征行军完毕处理回调
function ArmyWalkLogic:expeditionMarchCallback( _marchType, _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    -- 清除部队行军状态
    self:cancleArmyMoveStatus( _objectIndex, _objectType, _marchType, _targetObjectIndex )

    -- 路径信息清除
    MSM.SceneExpeditionMgr[_objectIndex].req.setPathEmpty( _objectIndex )

    if _marchType == Enum.MapMarchTargetType.SPACE then
        ArmyMarchCallback:spaceMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    elseif _marchType == Enum.MapMarchTargetType.ATTACK then
        ArmyMarchCallback:attackExpeditionMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    end
end

---@see 执行一个对象的行走
---@param walkInfo defaultArmyWalkClass
function ArmyWalkLogic:armyWalkOne( _armyWalks, objectIndex, walkInfo )
    local isReach, moveLastTick
    local lastTick = timeCore.getmillisecond()
    local movePercent = ( lastTick - walkInfo.lastTick ) / 1000
    walkInfo.now, isReach, moveLastTick = self:cacleNowPos( walkInfo.now, walkInfo.next, walkInfo.speed, walkInfo.arrivalTime, movePercent, lastTick )
    walkInfo.lastTick = moveLastTick
    -- 更新AOI
    if walkInfo.objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.armyUpdate( Enum.MapLevel.ARMY, objectIndex, walkInfo.now, walkInfo.now )
    elseif walkInfo.objectType == Enum.RoleType.SCOUTS then
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.scoutsUpdate( Enum.MapLevel.ARMY, objectIndex, walkInfo.now, walkInfo.now )
        -- 斥候迷雾探索
        if not walkInfo.denseFogOpenFlag then
            _, walkInfo.allDesenFog = MSM.DenseFogMgr[objectIndex].req.scoutsMove( walkInfo.rid, walkInfo.now, walkInfo.allDesenFog, walkInfo.objectIndex, walkInfo.armyIndex )
        end
    elseif walkInfo.objectType == Enum.RoleType.MONSTER then
        -- 怪物更新坐标
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.monsterUpdate( Enum.MapLevel.ARMY, objectIndex, walkInfo.now, walkInfo.now )
    elseif walkInfo.objectType == Enum.RoleType.GUARD_HOLY_LAND then
        -- 圣地守护者更新坐标
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.guardHolyLandUpdate( Enum.MapLevel.ARMY, objectIndex, walkInfo.now, walkInfo.now )
    elseif walkInfo.objectType == Enum.RoleType.TRANSPORT then
        -- 运输车
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.transportUpdate( Enum.MapLevel.ARMY, objectIndex, walkInfo.now, walkInfo.now )
    elseif walkInfo.objectType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.AoiMgr[walkInfo.mapIndex].post.expeditionObjectUpdate( walkInfo.mapIndex, objectIndex, walkInfo.now, walkInfo.now )
    elseif walkInfo.objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER or walkInfo.objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 召唤怪物
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.summonMonsterUpdate( Enum.MapLevel.ARMY, objectIndex, walkInfo.now, walkInfo.now, walkInfo.objectType )
    end
    -- 判断是否已经达到目标点
    if isReach then
        if walkInfo.passPosInfo[walkInfo.now.x] and walkInfo.passPosInfo[walkInfo.now.x][walkInfo.now.y] then
            local levelPass = sharedata.query( Enum.Share.LevelPass )
            local passId = walkInfo.passPosInfo[walkInfo.now.x][walkInfo.now.y]
            local guildId = RoleLogic:getRole( walkInfo.rid, Enum.Role.guildId )

            if guildId == 0 or levelPass[passId].guildId ~= guildId then
                -- 关卡已经不属于行军对象
                if not walkInfo.isRallyArmy then
                    -- 非集结部队
                    MSM.SceneArmyMgr[objectIndex].post.addArmyStation( objectIndex )
                elseif walkInfo.isRallyArmy then
                    -- 集结部队,解散
                    MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, walkInfo.rid )
                end
                if walkInfo.marchType ~= Enum.MapMarchTargetType.RETREAT then
                    return
                end
            end
        end
        if table.empty(walkInfo.path) then -- 全部行走完毕
            -- 移除队列
            _armyWalks[objectIndex] = nil
            -- 调用回调
            local ret, err
            if walkInfo.objectType ~= Enum.RoleType.EXPEDITION then
                ret, err = xpcall(self.marchCallback, debug.traceback, self, walkInfo.marchType, walkInfo.rid, walkInfo.armyIndex,
                                    objectIndex, walkInfo.objectType, walkInfo.targetObjectIndex, walkInfo.now )
                if not ret then
                    LOG_ERROR("marchCallback err:%s", err)
                end
             else
                ret, err = xpcall(self.expeditionMarchCallback, debug.traceback, self, walkInfo.marchType, walkInfo.rid, walkInfo.armyIndex,
                                    objectIndex, walkInfo.objectType, walkInfo.targetObjectIndex, walkInfo.now )
                if not ret then
                    LOG_ERROR("marchCallback err:%s", err)
                end
            end
        else
            -- 还有下一个目标点
            walkInfo.next = table.remove(walkInfo.path, 1)
            -- 重新计算角度
            walkInfo.angle, walkInfo.speed.x, walkInfo.speed.y = self:cacleSpeed( { walkInfo.now, walkInfo.next }, walkInfo.rawSpeed )
        end
    end
end

---@see 模拟行走.由MapMarchTimer调用
---@param _armyWalks table<int, defaultArmyWalkClass>
function ArmyWalkLogic:armyWalk( _armyWalks )
    local ret, err
    for objectIndex, walkInfo in pairs(_armyWalks) do
        ret, err = xpcall( self.armyWalkOne, debug.traceback, self, _armyWalks, objectIndex, walkInfo )
        if not ret then
            LOG_ERROR("armyWalk err:%s", err)
        end
    end
end

---@see 计算目标当前位置
---@param walkInfo defaultArmyWalkClass
function ArmyWalkLogic:cacleObjectNowPos( walkInfo )
    local delayMillisecod = timeCore.getmillisecond() - walkInfo.lastTick
    if walkInfo.rid > 0 then
        local ttl = ( RoleLogic:getRole( walkInfo.rid, Enum.Role.ttl ) or 0 )
        -- 取ttl延迟
        delayMillisecod = delayMillisecod + ttl
    end

    local movePercent = delayMillisecod / 1000
    return ArmyWalkLogic:cacleNowPos( walkInfo.now, walkInfo.next, walkInfo.speed, walkInfo.arrivalTime, movePercent )
end

---@see 计算当前所在位置
---@param _from table 当前位置
---@param _to table 目标位置
---@param _speed interge 移动速度
function ArmyWalkLogic:cacleNowPos( _from, _to, _speed, _arrivalTime, _movePercent, _lastTick )
    local nextX, nextY, isReach

    if not _movePercent or ( _movePercent >= 0.99 and _movePercent < 1 ) then
        _movePercent = 1
    end

    -- 下个X坐标
    if _speed.x > 0 then
        nextX = _from.x + math.ceil( _speed.x * _movePercent )
    else
        nextX = _from.x + math.floor( _speed.x * _movePercent )
    end
    -- 下个Y坐标
    if _speed.y > 0 then
        nextY = _from.y + math.ceil( _speed.y * _movePercent )
    else
        nextY = _from.y + math.floor( _speed.y * _movePercent )
    end

    -- 判断是否达到
    local isXReach, isYReach
    if ( _speed.x > 0 and nextX >= _to.x )
    or ( _speed.x < 0 and nextX <= _to.x ) then
        isXReach = true
    end

    if ( _speed.y > 0 and nextY >= _to.y )
    or ( _speed.y < 0 and nextY <= _to.y ) then
        isYReach = true
    end

    -- 超时也算达到
    if ( isXReach and isYReach ) or os.time() >= _arrivalTime then
        isReach = true -- 已达到目标点
        nextY = _to.y
        nextX = _to.x
    end

    -- 判断是否移动到目标点的时间,小于movePercent
    if _lastTick then
        local absX = math.abs(_from.x - _to.x )
        if absX > 0 and absX < math.abs(_speed.x * _movePercent) then
            -- 要补偿剩余时间
            _lastTick = _lastTick - ( 1 - ( absX / math.abs(_speed.x) ) ) * _movePercent
        else
            local absY = math.abs(_from.y - _to.y )
            if absY > 0 and absY < math.abs(_speed.y * _movePercent) then
                -- 要补偿剩余时间
                _lastTick = _lastTick - ( 1 - ( absY / math.abs(_speed.y) ) ) * _movePercent
            end
        end
    end

    -- 返回坐标
    return { x = nextX, y = nextY }, isReach, _lastTick
end

---@see 两点计算角度
function ArmyWalkLogic:cacleAnagle( _from, _to )
    return math.atan(_to.y - _from.y, _to.x - _from.x) * ( 180 / math.pi )
end

---@see 角度转为正值
function ArmyWalkLogic:transAngle( _angle )
    if _angle < 0 then
        _angle = _angle + 360
    end
    return _angle
end

---@see 两点计算距离
function ArmyWalkLogic:cacleDistance( _from, _to )
    return math.sqrt( (_from.x - _to.x ) ^ 2 + ( _from.y - _to.y ) ^ 2 )
end

---@see 计算移动速度XY向量
function ArmyWalkLogic:cacleSpeed( _path, _speed )
    local angle = self:cacleAnagle( _path[1], _path[2] )
    local speedx
    if _path[1].x == _path[2].x then
        speedx = 0
    else
        speedx = _speed * math.cos( math.rad(angle) )
    end
    local speedy
    if _path[1].y == _path[2].y then
        speedy = 0
    else
        speedy = _speed * math.sin( math.rad(angle) )
    end
    return angle, speedx, speedy
end

---@see 获取起始坐标
function ArmyWalkLogic:getFromPos( _fromType, _path, _armyRadius)
    local GuildBuildLogic = require "GuildBuildLogic"
    local path = table.copy(_path, true)
    if _fromType then
        if _fromType == Enum.RoleType.CITY then
            -- 从城市出发
            path[1] = self:cacleOutCityPos( path[1], path[2], _armyRadius )
        elseif MapObjectLogic:checkIsResourceObject( _fromType ) or _fromType == Enum.RoleType.VILLAGE or _fromType == Enum.RoleType.CAVE then
            -- 石头,农田,木材,金矿,钻石矿,村庄,山洞 出发
            path[1] = self:cacleFromResourcePos( path[1], path[2] )
        elseif MapObjectLogic:checkIsGuildBuildObject( _fromType ) then
            -- 联盟建筑
            path[1] = self:cacleFromGuildBuildPos( GuildBuildLogic:objectTypeToBuildType( _fromType ), path[1], path[2] )
        elseif MapObjectLogic:checkIsHolyLandObject( _fromType ) then
            -- 圣地建筑
            path[1] = self:cacleFromHolyLandPos( path[1], path[2], _armyRadius )
        end
    end
    return path[1]
end

---@see 跨省寻路
function ArmyWalkLogic:province( _path, _passLv, _sProvince, _mapName, _passPosInfo )
    local beginPos = _path[1]
    local newPath = {}
    local endPos
    local nextPos
    for _, passId in pairs( _passLv ) do
        local sStrongHoldData = CFG.s_StrongHoldData:Get(passId)
        if sStrongHoldData.province1 == _sProvince then
            endPos = { x = sStrongHoldData.posX1 , y = sStrongHoldData.posY1 }
            nextPos = { x = sStrongHoldData.posX2 , y = sStrongHoldData.posY2 }
            _sProvince = sStrongHoldData.province2
        elseif sStrongHoldData.province2 == _sProvince then
            endPos = { x = sStrongHoldData.posX2 , y = sStrongHoldData.posY2 }
            nextPos = { x = sStrongHoldData.posX1 , y = sStrongHoldData.posY1 }
            _sProvince = sStrongHoldData.province1
        end
        if not table.empty(newPath) then
            table.remove( newPath )
        end
        table.merge( newPath, self:findPath( beginPos, endPos, _mapName) or {} )
        if not _passPosInfo[endPos.x] then _passPosInfo[endPos.x] = {} end
        _passPosInfo[endPos.x][endPos.y] = passId
        table.insert(newPath, nextPos)
        beginPos = newPath[#newPath]
    end
    if not table.empty(newPath) then
        table.remove( newPath )
    end
    table.merge( newPath, self:findPath( beginPos, _path[#_path], _mapName) or {} )
    return newPath
end

---@see 根据起始和目标类型以及路径.修正路径的开始和结束点
function ArmyWalkLogic:fixPathPoint( _fromType, _toType, _path, _armyRadius, _targetArmyRadius,
                                    _mapName, _rid, _isDefeat, _onlyCheckPass )
    local GuildBuildLogic = require "GuildBuildLogic"
    _armyRadius = _armyRadius or 0
    _targetArmyRadius = _targetArmyRadius or 0
    local path = table.copy(_path, true)
    local pathCount = #path
    -- 修正出发点
    if _fromType then
        if _fromType == Enum.RoleType.CITY then
            -- 从城市出发
            path[1] = self:cacleOutCityPos( path[1], path[2], _armyRadius )
        elseif MapObjectLogic:checkIsResourceObject( _fromType ) or _fromType == Enum.RoleType.VILLAGE or _fromType == Enum.RoleType.CAVE then
            -- 石头,农田,木材,金矿,钻石矿,村庄,山洞 出发
            path[1] = self:cacleFromResourcePos( path[1], path[2] )
        elseif MapObjectLogic:checkIsGuildBuildObject( _fromType ) then
            -- 联盟建筑
            path[1] = self:cacleFromGuildBuildPos( GuildBuildLogic:objectTypeToBuildType( _fromType ), path[1], path[2] )
        elseif MapObjectLogic:checkIsHolyLandObject( _fromType ) and not MapObjectLogic:checkIsCheckPoint( _fromType )  then
            -- 圣地建筑
            path[1] = self:cacleFromHolyLandPos( path[1], path[2], _armyRadius )
        end
    else
        if not self:findPath( path[1], path[1], _mapName ) then
            local radius = CFG.s_Config:Get("cityRadius") * 100 + _armyRadius
            local fixPos = self:getObjectPos_8_Near( path[1], radius, path[#path] )
            if fixPos then
                path[1] = fixPos
            end
        end
    end

    -- 修正到达点
    if _toType then
        if not _armyRadius then
            _armyRadius = 0
        end

        local fromProvince = MapProvinceLogic:getPosInProvince( path[1] )
        local toProvince = MapProvinceLogic:getPosInProvince( path[#path] )

        -- 部队或者野蛮人,先寻路一次
        if _toType == Enum.RoleType.ARMY or _toType == Enum.RoleType.MONSTER or _toType == Enum.RoleType.GUARD_HOLY_LAND
            or _toType == Enum.RoleType.EXPEDITION or _toType == Enum.RoleType.SUMMON_SINGLE_MONSTER
            or _toType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            if fromProvince == toProvince then
                -- 先寻路一次
                path = self:findPath( path[1], path[#path], _mapName )
                if path then
                    pathCount = #path
                else
                    -- 没寻到路,直接取原点
                    path = { _path[1], _path[1] }
                end
            elseif fromProvince ~= toProvince and not _mapName then
                if _rid then -- rid为nil时,不是部队,不判断关卡
                    local passLv = MSM.CheckPointAStarMgr[_rid].req.findPath( _rid, path[1], path[#path], _isDefeat )
                    if passLv then
                        path = ArmyWalkLogic:province( path, passLv, fromProvince, _mapName, {} )
                        if path then
                            pathCount = #path
                        else
                            -- 没寻到路,直接取原点
                            path = { _path[1], _path[1] }
                        end
                    end
                end
            end
        end
        if _toType == Enum.RoleType.CITY then
            -- 到达城市
            path[pathCount] = self:cacleBackCityPos( path[pathCount-1], path[pathCount], _armyRadius )
        elseif MapObjectLogic:checkIsResourceCaveObject( _toType ) then
            -- 到达石头,农田,木材,金矿,钻石矿,村庄,山洞
            path[pathCount] = self:cacleResourcePos( path[pathCount-1], path[pathCount], _armyRadius )
        elseif _toType == Enum.RoleType.MONSTER or _toType == Enum.RoleType.GUARD_HOLY_LAND or _toType == Enum.RoleType.SUMMON_SINGLE_MONSTER
            or _toType == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 到达野蛮人、圣地守护者、召唤怪物
            path[pathCount] = self:cacleMonsterPos( path[pathCount-1], path[pathCount], _armyRadius, _targetArmyRadius )
        elseif _toType == Enum.RoleType.MONSTER_CITY then
            -- 达到野蛮人城市
            path[pathCount] = self:cacleResourcePos( path[pathCount-1], path[pathCount], _armyRadius )
        elseif _toType == Enum.RoleType.ARMY then
            -- 到达部队
            local oldPathEnd = path[pathCount]
            path[pathCount] = self:cacleArmyPos( path[pathCount-1], path[pathCount], _armyRadius, _targetArmyRadius )
            -- 不同省份跨关卡才判断
            if fromProvince ~= toProvince and not _mapName then
                local MapLogic = require "MapLogic"
                if not MapLogic:checkPosIdle( path[pathCount], 0 ) then
                    path[pathCount] = oldPathEnd
                end
            end
        elseif MapObjectLogic:checkIsGuildBuildObject( _toType ) then
            -- 联盟建筑
            path[pathCount] = self:cacleToGuildBuildPos( GuildBuildLogic:objectTypeToBuildType( _toType ), path[pathCount-1], path[pathCount], _armyRadius )
        elseif _toType == Enum.RoleType.RUNE then
            -- 符文
            path[pathCount] = self:cacleToRunePos( path[pathCount-1], path[pathCount], _targetArmyRadius, _armyRadius )
        elseif _toType == Enum.RoleType.EXPEDITION then
            -- 远征对象
            path[pathCount] = self:cacleExpditionPos( path[pathCount-1], path[pathCount], _armyRadius, _targetArmyRadius )
        elseif MapObjectLogic:checkIsHolyLandObject( _toType ) and not MapObjectLogic:checkIsCheckPoint( _toType ) then
            -- 圣地建筑
            path[pathCount] = self:cacleToHolyLandPos( path[pathCount-1], path[pathCount], _armyRadius, _targetArmyRadius )
        end
    end
    -- 关卡寻路
    if MapObjectLogic:checkIsCheckPoint( _toType ) and MapObjectLogic:checkIsCheckPoint( _fromType ) then
        local holdPos = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HOLD_POS )
        local ePointInfo = holdPos[path[pathCount].x][path[pathCount].y]
        local sPointInfo = holdPos[path[1].x][path[1].y]
        if ePointInfo.province1 == sPointInfo.province1 then
            path[1] = { x = sPointInfo.posX1, y = sPointInfo.posY1 }
            path[pathCount] = { x = ePointInfo.posX1, y = ePointInfo.posY1 }
        elseif ePointInfo.province1 == sPointInfo.province2 then
            path[1] = { x = sPointInfo.posX2, y = sPointInfo.posY2 }
            path[pathCount] = { x = ePointInfo.posX1, y = ePointInfo.posY1 }
        elseif ePointInfo.province2 == sPointInfo.province1 then
            path[1] = { x = sPointInfo.posX1, y = sPointInfo.posY1 }
            path[pathCount] = { x = ePointInfo.posX2, y = ePointInfo.posY2 }
        elseif ePointInfo.province2 == sPointInfo.province2 then
            path[1] = { x = sPointInfo.posX2, y = sPointInfo.posY2 }
            path[pathCount] = { x = ePointInfo.posX2, y = ePointInfo.posY2 }
        else
            local sPos, ePos
            local distance
            local list = {}
            table.insert( list, { sProvince = sPointInfo.province1, sPos = { x = sPointInfo.posX1, y = sPointInfo.posY1 }, ePos = { x = ePointInfo.posX1, y = ePointInfo.posY1 } } )
            table.insert( list, { sProvince = sPointInfo.province1, sPos = { x = sPointInfo.posX1, y = sPointInfo.posY1 }, ePos = { x = ePointInfo.posX2, y = ePointInfo.posY2 } } )
            table.insert( list, { sProvince = sPointInfo.province2, sPos = { x = sPointInfo.posX2, y = sPointInfo.posY2 }, ePos = { x = ePointInfo.posX1, y = ePointInfo.posY1 } } )
            table.insert( list, { sProvince = sPointInfo.province2, sPos = { x = sPointInfo.posX2, y = sPointInfo.posY2 }, ePos = { x = ePointInfo.posX2, y = ePointInfo.posY2 } } )
            for _, posInfo in pairs( list ) do
                local passLv = MSM.CheckPointAStarMgr[_rid].req.findPath( _rid, posInfo.sPos, posInfo.ePos, _isDefeat )
                if passLv then
                    local newPath = { posInfo.sPos, posInfo.ePos }
                    newPath = ArmyWalkLogic:province( newPath, passLv, posInfo.sProvince, _mapName, {} )
                    local newDistance = ArmyLogic:cacleDistance( newPath )
                    if not distance or newDistance < distance then
                        distance = newDistance
                        sPos = posInfo.sPos
                        ePos = posInfo.ePos
                    end
                end
            end
            if sPos and ePos then
                path[1] = sPos
                path[pathCount] = ePos
            end
        end
    elseif MapObjectLogic:checkIsCheckPoint( _toType ) then
        -- 如果终点是关卡
        local holdPos = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HOLD_POS )
        -- 取出该关卡两端的点
        local checkPointInfo = holdPos[path[pathCount].x][path[pathCount].y]
        -- 判断两头寻路哪个距离短
        local sProvince = MapProvinceLogic:getPosInProvince( path[1] )
        if sProvince ~= checkPointInfo.province1 and sProvince ~= checkPointInfo.province2 then
            local ePos
            local distance
            local list = {}
            table.insert( list, { ePos = { x = checkPointInfo.posX1, y = checkPointInfo.posY1 } } )
            table.insert( list, { ePos = { x = checkPointInfo.posX2, y = checkPointInfo.posY2 } } )
            for _, posInfo in pairs( list ) do
                local passLv = MSM.CheckPointAStarMgr[_rid].req.findPath( _rid, path[1], posInfo.ePos, _isDefeat )
                if passLv then
                    local newPath = { path[1], posInfo.ePos }
                    newPath = ArmyWalkLogic:province( newPath, passLv, sProvince, _mapName, {} )
                    local newDistance = ArmyLogic:cacleDistance( newPath )
                    if not distance or newDistance < distance then
                        distance = newDistance
                        ePos = posInfo.ePos
                    end
                end
            end
            if ePos then
                path[pathCount] = ePos
            end
        elseif sProvince == checkPointInfo.province1 then
            path[pathCount] = { x = checkPointInfo.posX1, y = checkPointInfo.posY1 }
        elseif sProvince == checkPointInfo.province2 then
            path[pathCount] = { x = checkPointInfo.posX2, y = checkPointInfo.posY2 }
        end
    elseif MapObjectLogic:checkIsCheckPoint( _fromType ) then
        -- 如果起点是关卡
        local holdPos = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.HOLD_POS )
        if holdPos[path[1].x] and holdPos[path[1].x][path[1].y] then
            -- 取出该关卡两端的点
            local checkPointInfo = holdPos[path[1].x][path[1].y]
            -- 判断两头寻路哪个距离短
            local eProvince = MapProvinceLogic:getPosInProvince( path[pathCount] )
            if eProvince ~= checkPointInfo.province1 and eProvince ~= checkPointInfo.province2 then
                local sPos
                local distance
                local list = {}
                table.insert( list, { sProvince = checkPointInfo.province1, sPos = { x = checkPointInfo.posX1, y = checkPointInfo.posY1 } } )
                table.insert( list, { sProvince = checkPointInfo.province2, sPos = { x = checkPointInfo.posX2, y = checkPointInfo.posY2 } } )
                for _, posInfo in pairs( list ) do
                    local passLv = MSM.CheckPointAStarMgr[_rid].req.findPath( _rid, posInfo.sPos, path[pathCount], _isDefeat )
                    if passLv then
                        local newPath = { posInfo.sPos, path[pathCount] }
                        newPath = ArmyWalkLogic:province( newPath, passLv, posInfo.sProvince, _mapName, {} )
                        local newDistance = ArmyLogic:cacleDistance( newPath )
                        if not distance or newDistance < distance then
                            distance = newDistance
                            sPos = posInfo.sPos
                        end
                    end
                end
                if sPos then
                    path[1] = sPos
                end
            elseif eProvince == checkPointInfo.province1 then
                path[1] = { x = checkPointInfo.posX1, y = checkPointInfo.posY1 }
            elseif eProvince == checkPointInfo.province2 then
                path[1] = { x = checkPointInfo.posX2, y = checkPointInfo.posY2 }
            end
        end
    end

    local sProvince = MapProvinceLogic:getPosInProvince( path[1] )
    local eProvince = MapProvinceLogic:getPosInProvince( path[#path] )
    local passPosInfo = {}
    local pass = true
    if _rid and eProvince > 0 and sProvince ~= eProvince then
        local passLv = MSM.CheckPointAStarMgr[_rid].req.findPath( _rid, path[1], path[#path], _isDefeat )
        if not passLv then
            pass = false
        else
            if not _onlyCheckPass then
                path = ArmyWalkLogic:province( path, passLv, sProvince, _mapName, passPosInfo )
            end
        end
    else
        if not _onlyCheckPass then
            -- 寻路
            local fpos = path[1]
            path = self:findPath( path[1], path[#path], _mapName )
            if not path or #path < 2 then
                return { fpos, fpos }, pass, passPosInfo
            end
        end
    end
    if _onlyCheckPass then
        return pass
    else
        return path, pass, passPosInfo
    end
end

function ArmyWalkLogic:getObjectPos_8_Near( _pos, _radius, _fromPos )
    local allPos = {}
    for aroundPos = 1, 8 do
        table.insert( allPos, ArmyLogic:cacleAroudPosXY_8( _pos, aroundPos, _radius ) )
    end

    local retPos
    for _, fixPos in pairs(allPos) do
        -- 过滤可以走的位置
        if self:findPath( fixPos, fixPos) then
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

---@see 计算出城坐标
function ArmyWalkLogic:cacleOutCityPos( _from, _to, _armyRadius )
    local angle = self:cacleAnagle( _from, _to )
    -- 取小的半径
    local troopsRadiusMax = CFG.s_Config:Get("troopsRadiusMax") * 100
    if _armyRadius > troopsRadiusMax then
        _armyRadius = troopsRadiusMax
    end
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100 + _armyRadius
    local speedx = math.floor( cityRadius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( cityRadius * math.sin( math.rad(angle) ) )
    return { x = _from.x + speedx, y = _from.y + speedy }
end

---@see 计算回城坐标
function ArmyWalkLogic:cacleBackCityPos( _from, _to, _radius )
    local angle = self:cacleAnagle( _from, _to )
    local cityRadius = CFG.s_Config:Get("cityRadius") * 100 + _radius
    local speedx = math.floor( cityRadius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( cityRadius * math.sin( math.rad(angle) ) )
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    -- 如果方向不一致,直接秒回(说明距离过近)
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 计算野蛮人达到坐标
function ArmyWalkLogic:cacleMonsterPos( _from, _to, _radius, _targetRadius )
    local angle = self:cacleAnagle( _from, _to )
    -- 增加军队半径
    local speedx = math.floor( ( _radius + _targetRadius ) * math.cos( math.rad(angle) ) )
    local speedy = math.floor( ( _radius + _targetRadius ) * math.sin( math.rad(angle) ) )
    -- 如果方向不一致,直接秒到(说明距离过近)
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 计算远征达到坐标
function ArmyWalkLogic:cacleExpditionPos( _from, _to, _radius, _targetRadius )
    local angle = self:cacleAnagle( _from, _to )
    -- 增加军队半径
    local speedx = math.floor( ( _radius + _targetRadius ) * math.cos( math.rad(angle) ) )
    local speedy = math.floor( ( _radius + _targetRadius ) * math.sin( math.rad(angle) ) )
    -- 如果方向不一致,直接秒到(说明距离过近)
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 计算资源达到坐标
function ArmyWalkLogic:cacleResourcePos( _from, _to, _radius )
    local angle = self:cacleAnagle( _from, _to )
    local resourceGatherRadius = CFG.s_Config:Get("resourceGatherRadius") * 100 + _radius
    local speedx = math.floor( resourceGatherRadius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( resourceGatherRadius * math.sin( math.rad(angle) ) )
    -- 如果方向不一致,直接秒到(说明距离过近)
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 计算资源出发坐标
function ArmyWalkLogic:cacleFromResourcePos( _from, _to )
    local angle = self:cacleAnagle( _from, _to )
    local resourceGatherRadius = CFG.s_Config:Get("resourceGatherRadius") * 100
    local speedx = math.floor( resourceGatherRadius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( resourceGatherRadius * math.sin( math.rad(angle) ) )
    return { x = _from.x + speedx, y = _from.y + speedy }
end

---@see 计算野蛮人随机巡逻坐标
function ArmyWalkLogic:cacleMonsterPartolPos( _centerPos, _curPos, _partolRadius, _mapName, _isMonster )
    _partolRadius = Random.Get(1, _partolRadius)
    _partolRadius = _partolRadius * 100
    -- 从-180到180随机一个角度
    local angle = Random.Get( -180, 180 )
    local speedx = math.floor( _partolRadius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( _partolRadius * math.sin( math.rad(angle) ) )
    return self:findPath( _curPos, { x = _centerPos.x + speedx, y = _centerPos.y + speedy }, _mapName, _isMonster )
end

---@see 计算部队达到坐标
function ArmyWalkLogic:cacleArmyPos( _from, _to, _armyRadius, _targetArmyRadius )
    local angle = self:cacleAnagle( _from, _to )
    -- 增加军队半径
    _targetArmyRadius = _targetArmyRadius + _armyRadius
    local speedx = math.floor( _targetArmyRadius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( _targetArmyRadius * math.sin( math.rad(angle) ) )
    -- 如果方向不一致,直接秒到(说明距离过近)
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 计算圣地建筑到达坐标
function ArmyWalkLogic:cacleToHolyLandPos( _from, _to, _radius, _targetArmyRadius )
    local angle = self:cacleAnagle( _from, _to )
    _targetArmyRadius = _targetArmyRadius + _radius
    local speedx = math.floor( _targetArmyRadius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( _targetArmyRadius * math.sin( math.rad(angle) ) )
    -- 如果方向不一致,直接秒回(说明距离过近)
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 计算寻路路径
function ArmyWalkLogic:findPath( _from, _to, _mapName, _isMonster )
    local path
    if not _mapName then
        if not _isMonster then
            path = SM.NavMeshMapMgr.req.findPath( _from, _to )
        else
            -- 怪物寻路,用放置阻挡的地图
            path = SM.NavMeshObstracleMgr.req.findMonsterPartolPath( _from, _to )
        end
    else
        path = SM.PVENavMeshMapMgr.req.findPath( _mapName, _from, _to )
    end
    --[[
    LOG_INFO("ArmyWalkLogic findPath _from(%s) _to(%s) _mapName(%s) _isMonster(%s), path(%s) traceback(%s)",
        tostring(_from), tostring(_to), tostring(_mapName), tostring(_isMonster), tostring(path), debug.traceback())
    ]]
    return path
end

---@see 判断目标点是否可达到
function ArmyWalkLogic:checkPointArrival( _from, _to )
    return SM.NavMeshMapMgr.req.checkPointArrival( _from, _to )
end

---@see 计算联盟建筑到达坐标
function ArmyWalkLogic:cacleToGuildBuildPos( _type, _from, _to, _armyRadius )
    local angle = self:cacleAnagle( _from, _to )
    local radius = CFG.s_AllianceBuildingType:Get( _type, "radius" ) * 100 + _armyRadius
    local speedx = math.floor( radius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( radius * math.sin( math.rad(angle) ) )
    -- 如果方向不一致,直接秒到(说明距离过近)
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 计算联盟建筑出发坐标
function ArmyWalkLogic:cacleFromGuildBuildPos( _type, _from, _to )
    local angle = self:cacleAnagle( _from, _to )
    local radius = CFG.s_AllianceBuildingType:Get( _type, "radius" ) * 100
    local speedx = math.floor( radius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( radius * math.sin( math.rad(angle) ) )
    return { x = _from.x + speedx, y = _from.y + speedy }
end

---@see 计算圣地建筑出发坐标
function ArmyWalkLogic:cacleFromHolyLandPos( _from, _to, _buildRadius )
    local angle = self:cacleAnagle( _from, _to )
    local radiusCollide = _buildRadius
    local speedx = math.floor( radiusCollide * math.cos( math.rad(angle) ) )
    local speedy = math.floor( radiusCollide * math.sin( math.rad(angle) ) )
    return { x = _from.x + speedx, y = _from.y + speedy }
end

---@see 计算符文到达坐标
function ArmyWalkLogic:cacleToRunePos( _from, _to, _runeRadius, _targetArmyRadius )
    local angle = self:cacleAnagle( _from, _to )
    local radius = _runeRadius + ( _targetArmyRadius or 0 )
    local speedx = math.floor( radius * math.cos( math.rad(angle) ) )
    local speedy = math.floor( radius * math.sin( math.rad(angle) ) )
    -- 如果方向不一致,直接秒到(说明距离过近)
    local pos = { x = _to.x - speedx, y = _to.y - speedy }
    local newAngle = self:cacleAnagle( _from, pos )
    if math.abs(self:transAngle(newAngle) - self:transAngle(angle)) > 90 then
        return { x = _from.x, y = _from.y }
    else
        return pos
    end
end

---@see 增加向目标行军信息
function ArmyWalkLogic:addArmyWalkTargetInfo( _targetIndex, _targetType, _objectIndex, _marchType, _arrivalTime, _path )
    if _targetType == Enum.RoleType.CITY then
        -- 增加向城市行军
        MSM.SceneCityMgr[_targetIndex].post.addArmyMoveToCity( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
        if _marchType and ( _marchType == Enum.MapMarchTargetType.ATTACK or _marchType == Enum.MapMarchTargetType.RALLY_ATTACK ) then
            local cityInfo = MSM.SceneCityMgr[_targetIndex].req.getCityInfo( _targetIndex )
            local name = RoleLogic:getRole( cityInfo.rid, Enum.Role.name )
            local armyInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo(_objectIndex)
            SM.PushMgr.post.sendPush( { pushRid = cityInfo.rid, pushType = Enum.PushType.CITY_ATTACK, args = { arg1 = name, arg2 = armyInfo.armyName } })
        end
    elseif _targetType == Enum.RoleType.ARMY then
        -- 增加向部队行军
        MSM.SceneArmyMgr[_targetIndex].post.addArmyWalkToArmy( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    elseif _targetType == Enum.RoleType.MONSTER or _targetType == Enum.RoleType.GUARD_HOLY_LAND or _targetType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _targetType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 增加向野蛮人怪物行军
        MSM.SceneMonsterMgr[_targetIndex].post.addArmyWalkToMonster( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    elseif _targetType == Enum.RoleType.RUNE then
        -- 增加向符文行军
        MSM.SceneRuneMgr[_targetIndex].post.addArmyWalkToRune( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    elseif MapObjectLogic:checkIsResourceObject( _targetType ) then
        -- 增加向资源行军
        MSM.SceneResourceMgr[_targetIndex].post.addArmyWalkToResource( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    elseif MapObjectLogic:checkIsGuildBuildObject( _targetType ) then
        -- 增加部队向联盟建筑行军
        MSM.SceneGuildBuildMgr[_targetIndex].post.addArmyWalkToGuildBuild( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    elseif MapObjectLogic:checkIsHolyLandObject( _targetType ) then
        -- 增加向关卡、圣地行军
        MSM.SceneHolyLandMgr[_targetIndex].post.addArmyWalkToHolyLand( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    elseif _targetType == Enum.RoleType.MONSTER_CITY then
        -- 增加向野蛮人怪物行军
        MSM.SceneMonsterCityMgr[_targetIndex].post.addArmyWalkToMonsterCity( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    elseif _targetType == Enum.RoleType.EXPEDITION then
        -- 远征对象
        MSM.SceneExpeditionMgr[_targetIndex].post.addArmyWalkToExpedition( _targetIndex, _objectIndex, _marchType, _arrivalTime, _path )
    end
end

---@see 移除向目标行军信息
function ArmyWalkLogic:delArmyWalkTargetInfo( _targetIndex, _targetType, _objectIndex )
    if _targetType == Enum.RoleType.CITY then
        -- 删除向城市行军
        MSM.SceneCityMgr[_targetIndex].post.delArmyMoveToCity( _targetIndex, _objectIndex )
    elseif _targetType == Enum.RoleType.ARMY then
        -- 删除向部队行军
        MSM.SceneArmyMgr[_targetIndex].post.delArmyWalkToArmy( _targetIndex, _objectIndex )
    elseif _targetType == Enum.RoleType.MONSTER or _targetType == Enum.RoleType.GUARD_HOLY_LAND or _targetType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _targetType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 删除向野蛮人怪物行军
        MSM.SceneMonsterMgr[_targetIndex].post.delArmyWalkToMonster( _targetIndex, _objectIndex )
    elseif _targetType == Enum.RoleType.RUNE then
        -- 删除向符文行军
        MSM.SceneRuneMgr[_targetIndex].post.delArmyWalkToRune( _targetIndex, _objectIndex )
    elseif MapObjectLogic:checkIsResourceObject( _targetType ) then
        -- 删除向资源行军
        MSM.SceneResourceMgr[_targetIndex].post.delArmyWalkToResource( _targetIndex, _objectIndex )
    elseif MapObjectLogic:checkIsGuildBuildObject( _targetType ) then
        -- 删除增加部队向联盟建筑行军
        MSM.SceneGuildBuildMgr[_targetIndex].post.delArmyWalkToGuildBuild( _targetIndex, _objectIndex )
    elseif MapObjectLogic:checkIsHolyLandObject( _targetType ) then
        -- 删除向关卡、圣地行军
        MSM.SceneHolyLandMgr[_targetIndex].post.delArmyWalkToHolyLand( _targetIndex, _objectIndex )
    elseif _targetType == Enum.RoleType.MONSTER_CITY then
        -- 删除向野蛮人怪物行军
        MSM.SceneMonsterCityMgr[_targetIndex].post.delArmyWalkToMonsterCity( _targetIndex, _objectIndex )
    elseif _targetType == Enum.RoleType.EXPEDITION then
        -- 删除向远征对象行军
        MSM.SceneExpeditionMgr[_targetIndex].post.delArmyWalkToExpedition( _targetIndex, _objectIndex )
    end
end

---@see 根据部队状态.判断是否加入对方的站位
function ArmyWalkLogic:checkAddAttacker( _objectIndex, _objectType, _targetObjectIndex )
    local objectInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    local targetInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
    if not objectInfo or not targetInfo then
        return
    end
    -- 双方处于战斗
    if ArmyLogic:checkArmyStatus( objectInfo.status, Enum.ArmyStatus.BATTLEING )
    and ArmyLogic:checkArmyStatus( targetInfo.status, Enum.ArmyStatus.BATTLEING ) then
        -- 加入站位
        if not ArmyLogic:checkArmyWalkStatus( objectInfo.status ) then
            MSM.AttackAroundPosMgr[_targetObjectIndex].post.addAttacker( _targetObjectIndex,  _objectIndex, _objectType )
        end
        if not ArmyLogic:checkArmyWalkStatus( targetInfo.status ) then
            MSM.AttackAroundPosMgr[_objectIndex].post.addAttacker( _objectIndex, _targetObjectIndex, targetInfo.objectType )
        end
    end
end

---@see 根据行军类型取消部队状态
function ArmyWalkLogic:cancleArmyMoveStatus( _objectIndex, _objectType, _marchType, _targetObjectIndex )
    local armyInfo = MSM.MapObjectTypeMgr[_objectIndex].req.getObjectInfo( _objectIndex )
    if not armyInfo then
        return
    end
    local targetInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
    local targetStatus
    if targetInfo then
        targetStatus = targetInfo.status
    end
    -- 移除移动状态
    armyInfo.status = ArmyLogic:removeMoveStatus( armyInfo.status, targetStatus )

    if _objectType == Enum.RoleType.EXPEDITION then
        -- 更新远征部队状态
        MSM.SceneExpeditionMgr[_objectIndex].req.updateArmyStatus( _objectIndex, armyInfo.status )
    elseif _objectType == Enum.RoleType.ARMY then
        -- 更新部队状态
        MSM.SceneArmyMgr[_objectIndex].req.updateArmyStatus( _objectIndex, armyInfo.status )
        if not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
            -- 部队移除targetObjectIndex
            MSM.SceneArmyMgr[_objectIndex].post.updateArmyTargetObjectIndex( _objectIndex, 0 )
        end
        local targetArg
        if not armyInfo.isRally then
            targetArg = ArmyLogic:getArmy( armyInfo.rid, armyInfo.armyIndex, Enum.Army.targetArg ) or {}
            targetArg.pos = armyInfo.pos
            ArmyLogic:updateArmyInfo( armyInfo.rid, armyInfo.armyIndex, { [Enum.Army.targetArg] = targetArg } )
        else
            for armyRid, armyIndex in pairs( armyInfo.rallyArmy ) do
                targetArg = ArmyLogic:getArmy( armyRid, armyIndex, Enum.Army.targetArg ) or {}
                targetArg.pos = armyInfo.pos
                ArmyLogic:updateArmyInfo( armyRid, armyIndex, { [Enum.Army.targetArg] = targetArg } )
            end
        end
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 更新野蛮人、圣地守护者状态、召唤怪物
        MSM.SceneMonsterMgr[_objectIndex].req.updateMonsterStatus( _objectIndex, armyInfo.status )
    end

    -- 如果处于战斗状态,通知战斗服务器可以开始攻击(攻击行军、追击不改变目标)
    if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.BATTLEING ) then
        if not armyInfo.isRally and _marchType ~= Enum.MapMarchTargetType.ATTACK and _marchType ~= Enum.MapMarchTargetType.FOLLOWUP then
            local BattleCreate = require "BattleCreate"
            BattleCreate:removeObjectStopAttack( _objectIndex )
        end

        -- 重新调整身边攻击者的站位
        if _marchType ~= Enum.MapMarchTargetType.FOLLOWUP and _marchType ~= Enum.MapMarchTargetType.MOVE then
            MSM.AttackAroundPosMgr[_objectIndex].post.recacleAroundPos( _objectIndex )
        end
    end
end

---@see 通知目标开始追击
function ArmyWalkLogic:notifyBeginFollowUp( _followObjectIndex, _followObjectType, _objectIndex, _objectType )
    if _followObjectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_followObjectIndex].post.armyFollowUp( _followObjectIndex, _objectIndex, _objectType )
    elseif _followObjectType == Enum.RoleType.MONSTER or _followObjectType == Enum.RoleType.GUARD_HOLY_LAND or _followObjectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _followObjectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        MSM.SceneMonsterMgr[_followObjectIndex].post.monsterFollowUp( _followObjectIndex, _objectIndex, _objectType )
    elseif _followObjectType == Enum.RoleType.EXPEDITION then
        MSM.SceneExpeditionMgr[_followObjectIndex].post.expeditionFollowUp( _followObjectIndex, _objectIndex, _objectType )
    end
end

---@see 通知目标通知追击
function ArmyWalkLogic:notifyEndFollowUp( _objectIndex, _objectType )
    if _objectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_objectIndex].req.stopFollowUp( _objectIndex )
    elseif _objectType == Enum.RoleType.MONSTER or _objectType == Enum.RoleType.GUARD_HOLY_LAND or _objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or _objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        MSM.SceneMonsterMgr[_objectIndex].req.stopFollowUp( _objectIndex )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        MSM.SceneExpeditionMgr[_objectIndex].req.stopFollowUp( _objectIndex )
    end
end

---@see 更新向目标行军缩略线联盟ID
function ArmyWalkLogic:updateArmyWalkObjectGuildId( _objectIndex, _targetObjectIndex, _guildId )
    local targetInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
    if not targetInfo or not table.empty( targetInfo ) then
        return
    end
    local objectType = targetInfo.objectType
    if objectType == Enum.RoleType.ARMY then
        -- 部队
        MSM.SceneArmyMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    elseif objectType == Enum.RoleType.MONSTER or objectType == Enum.RoleType.GUARD_HOLY_LAND or objectType == Enum.RoleType.SUMMON_SINGLE_MONSTER
        or objectType == Enum.RoleType.SUMMON_RALLY_MONSTER then
        -- 野蛮人、圣地守护者、召唤怪物
        MSM.SceneMonsterMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    elseif objectType == Enum.RoleType.CITY then
        -- 城市
        MSM.SceneCityMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    elseif objectType == Enum.RoleType.MONSTER_CITY then
        -- 野蛮人城寨
        MSM.SceneMonsterCityMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    elseif MapObjectLogic:checkIsGuildBuildObject( objectType ) then
        -- 联盟建筑
        MSM.SceneGuildBuildMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    elseif MapObjectLogic:checkIsHolyLandObject( objectType ) then
        -- 圣地
        MSM.SceneHolyLandMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    elseif MapObjectLogic:checkIsResourceObject( objectType ) then
        -- 资源点
        MSM.SceneResourceMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    elseif objectType == Enum.RoleType.RUNE then
        -- 符文
        MSM.SceneRuneMgr[_targetObjectIndex].post.updateArmyWalkObjectGuildId( _targetObjectIndex, _objectIndex, _guildId )
    end
end

return ArmyWalkLogic