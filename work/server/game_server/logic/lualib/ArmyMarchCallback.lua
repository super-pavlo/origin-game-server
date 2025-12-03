--[[
 * @file : ArmyMarchCallback.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-01-21 10:56:17
 * @Last Modified time: 2020-01-21 10:56:17
 * @department : Arabic Studio
 * @brief : 军队行军回调
 * Copyright(C) 2019 IGG, All rights reserved
]]

local BattleCreate = require "BattleCreate"
local ArmyLogic = require "ArmyLogic"
local MapObjectLogic = require "MapObjectLogic"
local ScoutsLogic = require "ScoutsLogic"
local RoleLogic = require "RoleLogic"
local MapLogic = require "MapLogic"
local TransportLogic = require "TransportLogic"
local EmailLogic = require "EmailLogic"
local GuildTerritoryLogic = require "GuildTerritoryLogic"
local LogLogic = require "LogLogic"

local ArmyMarchCallback = {}

---@see 空地行军回调
function ArmyMarchCallback:spaceMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    -- 设置为驻扎
    local setStatus = Enum.ArmyStatus.STATIONING
    -- 通知AOI
    if _objectType == Enum.RoleType.ARMY then
        MSM.SceneArmyMgr[_objectIndex].req.updateArmyStatus( _objectIndex, setStatus, Enum.ArmyStatusOp.ADD )
    elseif _objectType == Enum.RoleType.EXPEDITION then
        MSM.SceneExpeditionMgr[_objectIndex].req.updateArmyStatus( _objectIndex, setStatus, Enum.ArmyStatusOp.ADD )
    end
end

---@see 攻击行军回调
function ArmyMarchCallback:attackMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    -- 获取目标类型
    local defenseInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
    if not defenseInfo then
        -- 目标不存在了,直接回城
        MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        LOG_ERROR("attackMarchCallback not found targetObjectIndex(%d)", _targetObjectIndex)
        return
    end

    -- 判断是否是同一联盟
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    local targetGuildId = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectGuildId( _targetObjectIndex )
    if guildId > 0 then
        -- 不能攻击同盟的对象，直接返回
        if guildId == targetGuildId then
            -- 回城
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
            LOG_ERROR("attackMarchCallback same guild targetObjectIndex(%d)", _targetObjectIndex)
            return
        end

        if ( MapObjectLogic:checkIsAttackGuildBuildObject( defenseInfo.objectType )
            or MapObjectLogic:checkIsHolyLandObject( defenseInfo.objectType ) )
            and not GuildTerritoryLogic:checkObjectGuildTerritory( _targetObjectIndex, guildId ) then
            -- 联盟建筑和圣地关卡要判断领土是否接壤
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
            LOG_ERROR("guild territory not link, role guild(%d) targetObjectIndex(%d)", guildId, _targetObjectIndex)
            return
        end
    else
        -- 角色不在联盟中，不能攻击联盟建筑和圣地关卡建筑
        if MapObjectLogic:checkIsAttackGuildBuildObject( defenseInfo.objectType )
            or MapObjectLogic:checkIsHolyLandObject( defenseInfo.objectType ) then
            -- 回城
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
            LOG_ERROR("role not in guild, can't attack guild build or holyLand targetObjectIndex(%d)", _targetObjectIndex)
            return
        end
    end

    -- 创建战斗
    if not BattleCreate:beginBattleByStatus( _objectIndex, _targetObjectIndex ) then
        LOG_ERROR("attackMarchCallback createBattle fail, rid(%d) objectIndex(%d)", _rid, _objectIndex)
        -- 重新获取目标所属联盟ID
        targetGuildId = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectGuildId( _targetObjectIndex )
        if MapObjectLogic:checkIsHolyLandObject( defenseInfo.objectType ) and targetGuildId == guildId then
            -- 圣地被占领
            local mapArmyInfo = MSM.SceneArmyMgr[_objectIndex].req.getArmyInfo( _objectIndex )
            MSM.GuildMgr[guildId].req.reinforceHolyLand( guildId, _rid, _armyIndex, mapArmyInfo, _targetObjectIndex )
        else
            -- 创建战斗失败,回城行军
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        end
    else
        -- 修改攻击目标
        BattleCreate:changeAttackTarget( _objectIndex, Enum.RoleType.ARMY, _targetObjectIndex )
    end
end

---@see 增援行军回调
function ArmyMarchCallback:reinforceMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    -- 获取目标类型
    local targetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
    if not targetObjectInfo then
        -- 目标不存在了,直接回城
        MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        return
    end

    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    if guildId <= 0 then
        return
    end

    -- 判断和目标是否同一联盟
    local targetGuildId = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectGuildId( _targetObjectIndex )
    if guildId ~= targetGuildId then
        return
    end

    if MapObjectLogic:checkIsGuildBuildObject( targetObjectInfo.objectType ) then
        -- 增援联盟建筑
        local targetInfo = MSM.SceneGuildBuildMgr[_targetObjectIndex].req.getGuildBuildInfo( _targetObjectIndex )
        -- 部队到达联盟建筑回调处理
        if not MSM.GuildMgr[guildId].req.arriveGuildBuild( guildId, targetInfo.buildIndex,
                                                            _rid, _armyIndex, _objectIndex, _targetObjectIndex ) then
            -- 增援失败,回城
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        end
    elseif targetObjectInfo.objectType == Enum.RoleType.ARMY then
        -- 增援部队,通知集结服务
        if not MSM.RallyMgr[targetGuildId].req.reinforceArrivalCallback( targetObjectInfo.rid, _rid, _armyIndex, _objectIndex ) then
            -- 增援失败,回城
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        else
            -- 增援成功,通知目标部队
            MSM.SceneArmyMgr[_targetObjectIndex].post.reinforceAddToRally( _targetObjectIndex, _rid, _armyIndex )
            -- 删除地图上的对象
            MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
            -- 移除军队索引信息
            MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, _armyIndex )
        end
    elseif targetObjectInfo.objectType == Enum.RoleType.CITY then
        if MSM.CityReinforceMgr[targetObjectInfo.rid].req.cityReinforceArrivalCallback( targetObjectInfo.rid, _rid, _armyIndex, _objectIndex ) then
            -- 删除地图上的对象
            MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
            -- 移除军队索引信息
            MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, _armyIndex )
        else
            -- 增援失败,回城
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        end
    elseif MapObjectLogic:checkIsHolyLandObject( targetObjectInfo.objectType ) then
        -- 增援圣地关卡
        if not MSM.GuildMgr[guildId].req.arriveHolyLand( guildId, _rid, _armyIndex, _objectIndex, _targetObjectIndex ) then
            -- 增援失败,回城
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        end
    end
end

---@see 加入集结行军回调
function ArmyMarchCallback:rallyMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    -- 集结的目标一定是城市
    local cityInfo = MSM.SceneCityMgr[_targetObjectIndex].req.getCityInfo( _targetObjectIndex )
    if not cityInfo then
        -- 不存在,回城
        MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        return
    end

    -- 通知集结服务,部队已达到
    MSM.RallyMgr[cityInfo.guildId].post.armyRallyArrival( cityInfo.guildId, cityInfo.rid, _rid )
    -- 删除地图上的对象
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
    -- 移除军队索引信息
    MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, _armyIndex )
end

---@see 集结攻击行军回调
function ArmyMarchCallback:rallyAttackCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    -- 通知集结部队达到目标
    local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
    MSM.RallyMgr[guildId].post.rallyTeamArrival( guildId, _rid )

    -- 不能攻击本联盟的建筑或部队等
    local targetGuildId = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectGuildId( _targetObjectIndex )
    if guildId == targetGuildId then
        MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rid )
        return
    end

    -- 目标是否还存在
    local targetInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectInfo( _targetObjectIndex )
    if not targetInfo then
        -- 目标不存在,解散集结
        MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rid )
        return
    end

    if not BattleCreate:beginBattleByStatus( _objectIndex, _targetObjectIndex ) then
        -- 创建战斗失败,解散集结
        MSM.RallyMgr[guildId].req.disbandRallyArmy( guildId, _rid )
        return
    else
        -- 集结部队攻击目标修改
        MSM.SceneArmyMgr[_objectType].post.updateArmyTargetObjectIndex( _objectIndex, _targetObjectIndex )
    end

    -- 修改为集结战斗状态
    MSM.SceneArmyMgr[_objectIndex].req.updateArmyStatus( _objectIndex, Enum.ArmyStatus.RALLY_BATTLE, Enum.ArmyStatusOp.ADD )
end

---@see 采集行军回调
function ArmyMarchCallback:collectMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos, _collectAttackers )
    local targetObjectInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
    if not targetObjectInfo then
        return
    end
    if MapObjectLogic:checkIsResourceObject( targetObjectInfo.objectType ) then
        -- 野外资源田采集
        if ArmyLogic:checkAttacKResourceArmy( _rid, _targetObjectIndex, true ) then
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
            return
        end
        --[[
        -- 如果资源内有非友方部队,则改为攻击
        if ArmyLogic:checkAttacKResourceArmy( _rid, _targetObjectIndex ) then
            -- 标记部队攻击资源
            MSM.SceneResourceMgr[_targetObjectIndex].post.armyAttackResource( _targetObjectIndex, _objectIndex )
            -- 攻击资源点
            self:attackMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
            return
        end
        ]]
        -- 开始采集
        local ResourceLogic = require "ResourceLogic"
        if ResourceLogic:resourceCollect( _rid, _armyIndex, _targetObjectIndex ) then
            -- 转向攻击资源点
            if _collectAttackers then
                local attackInfo
                for _, attackIndex in pairs(_collectAttackers) do
                    -- 攻击者的目标是自己,才处理
                    attackInfo = MSM.MapObjectTypeMgr[attackIndex].req.getObjectInfo( attackIndex )
                    if attackInfo.targetObjectIndex == _objectIndex and not ArmyLogic:checkArmyStatus( attackInfo.status, Enum.ArmyStatus.STATIONING ) then
                        -- 攻击者改变目标
                        MSM.MapMarchMgr[attackIndex].req.armyMove( attackIndex, _targetObjectIndex, nil, nil, Enum.MapMarchTargetType.ATTACK )
                    end
                end
            end
        end
    elseif MapObjectLogic:checkIsGuildResourceCenterObject( targetObjectInfo.objectType ) then
        local guildBuild = MSM.SceneGuildBuildMgr[_targetObjectIndex].req.getGuildBuildInfo( _targetObjectIndex )
        -- 联盟资源中心采集
        local guildId = RoleLogic:getRole( _rid, Enum.Role.guildId )
        if guildId ~= guildBuild.guildId then
            -- 角色不属于此联盟，直接返回城市
            MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
        else
            -- 部队到达联盟建筑回调处理
            if not MSM.GuildMgr[guildId].req.arriveGuildBuild( guildId, guildBuild.buildIndex, _rid,
                                                        _armyIndex, _objectIndex, _targetObjectIndex ) then
                -- 增援失败回城
                MSM.MapMarchMgr[_objectIndex].req.marchBackCity( _rid, _objectIndex )
            end
        end
    elseif targetObjectInfo.objectType == Enum.RoleType.RUNE then
        -- 采集符文
        MSM.RuneMgr[_targetObjectIndex].post.roleStartCollectRune( _rid, _armyIndex, _targetObjectIndex )
    end
end

---@see 撤退行军回调
function ArmyMarchCallback:retreatMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex )
    LOG_INFO("rid(%s) armyIndex(%s) _objectIndex(%s) retreatMarchCallback", tostring(_rid), tostring(_armyIndex), tostring(_objectIndex))
    -- 部队掠夺资源增加到角色身上
    MSM.SceneArmyMgr[_objectIndex].req.addResourceFromArmy( _objectIndex )
    -- 删除地图上的对象
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.armyLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
    -- 移除军队索引信息
    MSM.RoleArmyMgr[_rid].post.deleteRoleArmyIndex( _rid, _armyIndex )
    -- 解散军队
    ArmyLogic:disbandArmy( _rid, _armyIndex )
end

---@see 侦查行军回调
function ArmyMarchCallback:scoutsMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    if _targetObjectIndex and _targetObjectIndex > 0 then
        local MapScoutsLogic = require "MapScoutsLogic"
        MSM.SceneScoutsMgr[_objectIndex].post.deleteScoutFollow( _objectIndex )
        MapScoutsLogic:mapScoutMarchCallBack( _rid, _objectIndex, _targetObjectIndex, _pos )
    else
        -- 开始探索迷雾
        ScoutsLogic:discoverDenseFog( _rid, _objectIndex, _armyIndex, _pos )
    end
end

---@see 斥候回城回调
function ArmyMarchCallback:scoutsBackMarchCallback( _rid, _scoutsIndex, _objectIndex, _objectType, _targetObjectIndex, _noBackCity )
    if not _noBackCity then
        local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.scoutDenseFogFlag, Enum.Role.iggid } ) or {}
        -- 记录斥候回城日志
        local scoutInfo = ScoutsLogic:getScouts( _rid, _scoutsIndex ) or {}
        if not table.empty( scoutInfo ) then
            -- 记录斥候日志
            LogLogic:roleScout( {
                logType = Enum.LogType.SCOUT_MARCHBACK, iggid = roleInfo.iggid, rid = _rid,
                logType2 = scoutInfo.denseFogNum or 0, logType3 = os.time() - ( scoutInfo.leaveCityTime or 0 )
            } )
        end
        -- 斥候变成待命状态
        ScoutsLogic:updateScoutsInfo( _rid, _scoutsIndex, {
            scoutsIndex = _scoutsIndex, scoutsStatus = Enum.ArmyStatus.STANBY,
            scoutsTargetIndex = 0, denseFogNum = 0, leaveCityTime = 0,
        } )
        -- 增加探索次数
        local scoutDenseFogFlag = roleInfo.scoutDenseFogFlag or {}
        if table.exist( scoutDenseFogFlag, _scoutsIndex ) then
            RoleLogic:addRoleStatistics( _rid, Enum.RoleStatisticsType.SCOUT, 1 )
            table.removevalue( scoutDenseFogFlag, _scoutsIndex )
            RoleLogic:setRole( _rid, Enum.Role.scoutDenseFogFlag, scoutDenseFogFlag )
        end
    end
    -- 斥候从地图离开
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.scoutsLeave( Enum.MapLevel.ARMY, _objectIndex, { -1, -1 } )
end

---@see 追击完成回调
function ArmyMarchCallback:followUpMarchCallback( _, _, _objectIndex, _objectType, _targetObjectIndex, _pos )

end

---@see 移动完成回调
function ArmyMarchCallback:moveMarchCallback( _, _, _objectIndex, _objectType )

end

---@see 运输完成回调
function ArmyMarchCallback:transportCallback( _rid, _transportIndex, _objectIndex, _objectType, _targetObjectIndex )
    -- 判断是否当前是否是一个联盟, 不是直接回城
    local targetCityInfo = MSM.SceneCityMgr[_targetObjectIndex].req.getCityInfo( _targetObjectIndex )
    local targetGuildId = RoleLogic:getRole( targetCityInfo.rid, Enum.Role.guildId )
    local transport = TransportLogic:getTransport( _rid, _transportIndex )
    local armyInfo = MSM.SceneTransportMgr[_objectIndex].req.getTransportInfo( _objectIndex )
    if not targetGuildId or targetGuildId == 0 or RoleLogic:getRole( _rid, Enum.Role.guildId ) == 0 or targetGuildId ~= RoleLogic:getRole( _rid, Enum.Role.guildId ) then
        -- 回城
        transport.transportStatus = Enum.TransportStatus.FAIL
        transport.targetRid = _rid
        TransportLogic:setTransport( _rid, _transportIndex, transport )
        TransportLogic:syncTransport( _rid, _transportIndex, transport, true )
        MSM.MapMarchMgr[_objectIndex].req.transportBackCity( _rid, _objectIndex, _transportIndex, armyInfo.pos )
        -- 发送援助失败邮件
        local emailOtherInfo = {
            emailContents = { RoleLogic:getRole( targetCityInfo.rid, Enum.Role.name ) },
            guildEmail = {
                transportResource = {}
            }
        }
        for _, resourceInfo in pairs( transport.allResourceInfo ) do
            if resourceInfo.load > 0 then
                table.insert( emailOtherInfo.guildEmail.transportResource, { type = resourceInfo.resourceTypeId, num = resourceInfo.load } )
            end
        end
        EmailLogic:sendEmail( _rid, CFG.s_Config:Get( "transportFailEmail" ), emailOtherInfo )
        return
    end
    -- 判断是否再范围内
    local cityRadius = CFG.s_Config:Get("cityRadius")
    local transportRadiusFind = CFG.s_Config:Get("transportRadiusFind")
    local radius = (cityRadius + transportRadiusFind) * Enum.MapPosMultiple
    if not MapLogic:checkRadius( armyInfo.pos, targetCityInfo.pos, radius ) then
        -- 回城
        transport.transportStatus = Enum.TransportStatus.FAIL
        transport.targetRid = _rid
        TransportLogic:setTransport( _rid, _transportIndex, transport )
        TransportLogic:syncTransport( _rid, _transportIndex, transport, true )
        MSM.MapMarchMgr[_objectIndex].req.transportBackCity( _rid, _objectIndex, _transportIndex, armyInfo.pos )
        -- 发送援助失败邮件
        local emailOtherInfo = {
            emailContents = { RoleLogic:getRole( targetCityInfo.rid, Enum.Role.name ) },
            guildEmail = {
                transportResource = {}
            }
        }
        for _, resourceInfo in pairs( transport.allResourceInfo ) do
            if resourceInfo.load > 0 then
                table.insert( emailOtherInfo.guildEmail.transportResource, { type = resourceInfo.resourceTypeId, num = resourceInfo.load } )
            end
        end
        EmailLogic:sendEmail( _rid, CFG.s_Config:Get( "transportFailEmail" ), emailOtherInfo )
        return
    end
    transport.transportStatus = Enum.TransportStatus.SUCCESS
    transport.targetRid = _rid
    local transportSum = 0
    for _, resourceInfo in pairs (transport.transportResourceInfo) do
        if resourceInfo.resourceTypeId == Enum.CurrencyType.food then
            RoleLogic:addFood( targetCityInfo.rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_GAIN_CURRENCY )
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.wood then
            RoleLogic:addWood( targetCityInfo.rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_GAIN_CURRENCY )
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.stone then
            RoleLogic:addStone( targetCityInfo.rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_GAIN_CURRENCY )
        elseif resourceInfo.resourceTypeId == Enum.CurrencyType.gold then
            RoleLogic:addGold( targetCityInfo.rid, resourceInfo.load, nil, Enum.LogType.TRANSPORT_GAIN_CURRENCY )
        end
        transportSum = transportSum + resourceInfo.load
    end
    TransportLogic:setTransport( _rid, _transportIndex, transport )
    TransportLogic:syncTransport( _rid, _transportIndex, transport, true )
    MSM.MapMarchMgr[_objectIndex].req.transportBackCity( _rid, _objectIndex, _transportIndex, armyInfo.pos )
    -- 发送资源援助邮件
    local roleName = RoleLogic:getRole( _rid, Enum.Role.name )
    local emailOtherInfo = {
        subType = Enum.EmailSubType.RSS_HELP,
        subTitleContents = { roleName },
        guildEmail = {
            roleName = roleName,
            transportResource = {}
        }
    }
    for _, resourceInfo in pairs( transport.transportResourceInfo ) do
        if resourceInfo.load > 0 then
            table.insert( emailOtherInfo.guildEmail.transportResource, { type = resourceInfo.resourceTypeId, num = resourceInfo.load } )
        end
    end
    EmailLogic:sendEmail( targetCityInfo.rid, CFG.s_Config:Get( "transportSuccessEmail" ), emailOtherInfo )
    Common.syncMsg( _rid, "Transport_TransportSuccess",  { type = 1 } )
    Common.syncMsg( targetCityInfo.rid, "Transport_TransportSuccess",  { type = 2 } )
    if transportSum > 0 then
        MSM.GuildMgr[targetGuildId].post.updateGuildRank( targetGuildId, _rid, Enum.RankType.ALLIACEN_ROLE_RES_HELP, transportSum )
    end
    -- 角色资源援助量
    RoleLogic:addRoleStatistics( _rid, Enum.RoleStatisticsType.RESOURCE_ASSIST, transportSum )
end

---@see 运输回城回调
function ArmyMarchCallback:marchBackCity( _rid, _transportIndex, _objectIndex )
    -- 解散运输车
    TransportLogic:marchBackCity( _rid, _transportIndex )
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.transportLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
end

---@see 战损运输车到达回调
function ArmyMarchCallback:battleLoseTransportCallback( _, _, _objectIndex )
    -- 解散运输车
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.transportLeave( Enum.MapLevel.ARMY, _objectIndex, { x = -1, y = -1 } )
end

---@see 远征攻击行军回调
function ArmyMarchCallback:attackExpeditionMarchCallback( _rid, _armyIndex, _objectIndex, _objectType, _targetObjectIndex, _pos )
    -- 移除行军
    MSM.SceneExpeditionMgr[_targetObjectIndex].post.delArmyWalkToExpedition( _targetObjectIndex, _objectIndex )
    local attackInfo = MSM.SceneExpeditionMgr[_objectIndex].req.getExpeditionInfo( _objectIndex )
    if not attackInfo then
        return
    end
    -- 获取目标类型
    local defenseInfo = MSM.MapObjectTypeMgr[_targetObjectIndex].req.getObjectType( _targetObjectIndex )
    if not defenseInfo then
        return
    end

    if defenseInfo.rid and defenseInfo.rid > 0 and attackInfo.rid and attackInfo.rid > 0 then
        return
    end

    -- 创建战斗
    if not BattleCreate:beginBattleByStatus( _objectIndex, _targetObjectIndex ) then
        LOG_ERROR("attackMarchCallback createBattle fail, rid(%d) objectIndex(%d)", _rid, _objectIndex)
    end
end

return ArmyMarchCallback