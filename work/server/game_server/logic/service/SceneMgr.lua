--[[
* @file : SceneMgr.lua
* @type : snax multi service
* @author : linfeng
* @created : Thu May 03 2018 11:29:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图、副本场景服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local crypt = require "skynet.crypt"
local socketdriver = require "skynet.socketdriver"
local sprotoloader = require "sprotoloader"
local MapObjectLogic = require "MapObjectLogic"

---@see 场景内的角色数据
local sceneRoleInfos = {}
---@see 场景内的地图对象数据
local sceneObjectInfos = {}
---@see 场景内角色socket
local sceneRoleFd = {}
---@see 消息推送函数
local _S2C_Push
---@see 角色城市索引
local cityIndexInfos = {}
---@see 军队被角色关注索引
---@type table<int, table<int, boolean>>
local armyToRoles = {}
---@see 角色AOI列表索引
---@type table<int, table<int, boolean>>
local roleObjectAoiIndex = {}

---@see 初始化
function init()
    local _C2S_Request = sprotoloader.load(Enum.SPROTO_SLOT.RPC):host "package"
    _S2C_Push = _C2S_Request:attach(sprotoloader.load(Enum.SPROTO_SLOT.RPC))
end

---@see 进入场景
local function EnterScene( _rid, _roleType, _fd, _secret )
    sceneRoleInfos[_rid] = {}
    if _roleType and _roleType == Enum.RoleType.ROLE then
        sceneRoleFd[_rid] = { fd = _fd, secret = _secret }
    end
end

---@see 更新fd和secret
function response.updateRoleFdSecret( _rid, _fd, _secret )
    if not sceneRoleFd[_rid] then return end
    sceneRoleFd[_rid] = { fd = _fd, secret = _secret }
end

---@see 角色加入场景
function response.roleSceneEnter( _rid, _roleType, _fd, _secret )
    if sceneRoleInfos[_rid] ~= nil then
        sceneRoleInfos[_rid] = nil
    end
    EnterScene( _rid, _roleType, _fd, _secret )
end

---@see 角色离开场景
function response.roleSceneLeave( _rid )
    sceneRoleInfos[_rid] = nil
    sceneRoleFd[_rid] = nil

    if roleObjectAoiIndex[_rid] then
        for markerId, markerType in pairs(roleObjectAoiIndex[_rid]) do
            if armyToRoles[markerId] and armyToRoles[markerId][_rid] then
                armyToRoles[markerId][_rid] = nil
            end
            -- 移除角色关注
            if markerType == Enum.RoleType.MONSTER or markerType == Enum.RoleType.GUARD_HOLY_LAND
                or markerType == Enum.RoleType.SUMMON_SINGLE_MONSTER or markerType == Enum.RoleType.SUMMON_RALLY_MONSTER then
                MSM.SceneMonsterMgr[markerId].post.subRoleWaterRef( markerId )
            elseif MapObjectLogic:checkIsGuildBuildObject( markerType ) then
                MSM.SceneGuildBuildMgr[markerId].post.deleteFocusRid( markerId, _rid )
            elseif MapObjectLogic:checkIsHolyLandObject( markerType ) then
                MSM.SceneHolyLandMgr[markerId].post.deleteFocusRid( markerId, _rid )
            end
        end
    end

    roleObjectAoiIndex[_rid] = nil
end

---@see 地图对象加入场景
function accept.mapObjectSceneEnter( _objectIndex, _objectType )
    sceneObjectInfos[_objectIndex] = {}
end

---@see 地图对象离开场景
function accept.mapObjectSceneLeave( _objectIndex )
    sceneObjectInfos[_objectIndex] = nil
end

---@see 添加角色城市索引
function response.addRoleCityIndex( _rid, _objectIndex )
    cityIndexInfos[_rid] = _objectIndex
end

---@see 删除角色城市索引
function accept.deleteRoleCityIndex( _rid, _objectIndex )
    cityIndexInfos[_rid] = nil
end

---@see 获取角色城市索引
function response.getRoleCityIndex( _rid )
    return cityIndexInfos[_rid]
end

---@see 获取关注对象的角色索引列表
---@return table<int, boolean>
function response.getRidsByObjectIndex( _objectIndex )
    return armyToRoles[_objectIndex]
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
local function pushToClient( _watcherId, _msgName, _msgValue )
    if sceneRoleInfos[_watcherId] and sceneRoleFd[_watcherId]
    and sceneRoleFd[_watcherId].fd and sceneRoleFd[_watcherId].fd > 0 then
        local msg = msgPack( _msgName, _msgValue )
        if not msg then
            LOG_ERROR("pushToClient error, name(%s) value(%s)", _msgName, tostring(_msgValue))
            return
        end
        local pushMsg = { content = { { networkMessage = msg } } }
        -- push to client now
        local pushClientMsg = crypt.desencode( sceneRoleFd[_watcherId].secret, msgPack( "GateMessage", pushMsg ) )
        pushClientMsg = string.pack( ">s2", pushClientMsg .. string.pack(">I4", 1, 0) .. string.pack(">B", 0) )
        socketdriver.send( sceneRoleFd[_watcherId].fd, pushClientMsg )
        --[[
        pushClientMsg, allPackSize = Common.SplitPackage(pushClientMsg)
        for msgIndex, subMsg in pairs(pushClientMsg) do
            msg = string.pack(">s2", msg .. string.pack(">B", msgIndex) .. string.pack(">B", allPackSize))
            socketdriver.send( sceneRoleFd[_watcherId].fd, subMsg )
        end
        ]]
    end
end

---@see 场景内的角色移动
---@param _watcherId integer 观察者
---@param _markerId integer 被观察者
function accept.roleSceneMove( _watcherId, _markerId, _action, _nowPos, _targetPos, _rtype, _guildId )
    if _action == Enum.AOI_ACTION.DROP then -- 离开场景
        local markerType
        if roleObjectAoiIndex[_watcherId] then
            markerType = roleObjectAoiIndex[_watcherId][_markerId]
            roleObjectAoiIndex[_watcherId][_markerId] = nil
        end

        if sceneRoleInfos[_watcherId] then
            -- 移除关联关系
            if armyToRoles[_markerId] and armyToRoles[_markerId][_watcherId] then
                armyToRoles[_markerId][_watcherId] = nil
            end
            pushToClient( _watcherId, "Map_ObjectDelete", { objectId = _markerId } )
            -- 移除角色关注
            if markerType then
                if markerType == Enum.RoleType.MONSTER or markerType == Enum.RoleType.GUARD_HOLY_LAND
                    or markerType == Enum.RoleType.SUMMON_SINGLE_MONSTER or markerType == Enum.RoleType.SUMMON_RALLY_MONSTER then
                    MSM.SceneMonsterMgr[_markerId].post.subRoleWaterRef( _markerId )
                elseif MapObjectLogic:checkIsGuildBuildObject( markerType ) then
                    MSM.SceneGuildBuildMgr[_markerId].post.deleteFocusRid( _markerId, _watcherId )
                elseif MapObjectLogic:checkIsHolyLandObject( markerType ) then
                    MSM.SceneHolyLandMgr[_markerId].post.deleteFocusRid( _markerId, _watcherId )
                end
            end
        elseif sceneObjectInfos[_watcherId] then
            -- 地图对象,不下发
            sceneObjectInfos[_watcherId][_markerId] = nil
        end

        return
    elseif _action == Enum.AOI_ACTION.MOVE then -- 场景内移动
        if not sceneRoleInfos[_watcherId] and not sceneObjectInfos[_watcherId] then
            return -- 角色不在场景内,返回
        end

        if sceneObjectInfos[_watcherId] then
            -- 地图对象,不下发
            sceneObjectInfos[_watcherId][_markerId] = { pos = _nowPos, objectType = _rtype, guildId = _guildId }
            return
        end
        local objectInfo = {}
        if _rtype == Enum.RoleType.ARMY then
            -- 军队,仅发送一次
            if roleObjectAoiIndex[_watcherId] and roleObjectAoiIndex[_watcherId][_markerId] then
                return
            end
            local thisArmyInfo = MSM.SceneArmyMgr[_markerId].req.getArmyInfo( _markerId )
            if not thisArmyInfo then
                return
            end
            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPath = thisArmyInfo.path,
                roopsCapacity = thisArmyInfo.roopsCapacity,
                massTroopsCapacity = thisArmyInfo.massTroopsCapacity,
                armyLevel = thisArmyInfo.armyLevel,
                armyRid = thisArmyInfo.rid,
                armyName = thisArmyInfo.armyName,
                mainHeroId = thisArmyInfo.mainHeroId,
                deputyHeroId = thisArmyInfo.deputyHeroId,
                soldiers = thisArmyInfo.soldiers,
                objectPos = thisArmyInfo.pos,
                status = thisArmyInfo.status,
                arrivalTime = thisArmyInfo.arrivalTime,
                armyCount = thisArmyInfo.armyCount,
                armyIndex = thisArmyInfo.armyIndex,
                startTime = thisArmyInfo.startTime,
                targetObjectIndex = thisArmyInfo.targetObjectIndex,
                armyRadius = thisArmyInfo.armyRadius,
                targetAngle = math.floor( thisArmyInfo.angle ),
                attackCount = thisArmyInfo.attackCount,
                guildAbbName = thisArmyInfo.guildAbbName,
                battleBuff = thisArmyInfo.battleBuff,
                maxSp = thisArmyInfo.maxSp,
                sp = thisArmyInfo.sp,
                mainHeroSkills = thisArmyInfo.mainHeroSkills,
                deputyHeroSkills = thisArmyInfo.deputyHeroSkills,
                armyCountMax = thisArmyInfo.armyCountMax,
                guildId = thisArmyInfo.guildId,
                isRally = thisArmyInfo.isRally,
                guildFlagSigns = thisArmyInfo.guildFlagSigns,
                cityLevel = thisArmyInfo.cityLevel,
                armyMarchInfos = thisArmyInfo.armyMarchInfo,
            }
        elseif _rtype == Enum.RoleType.CITY then
            -- 城堡
            local thisCityInfo = MSM.SceneCityMgr[_markerId].req.getCityInfo( _markerId )
            if not thisCityInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisCityInfo.pos,
                cityName = thisCityInfo.name,
                cityRid = thisCityInfo.rid,
                cityLevel = thisCityInfo.level,
                cityCountry = thisCityInfo.country,
                objectPower = thisCityInfo.power,
                killCount = thisCityInfo.killCount,
                guildAbbName = thisCityInfo.guildAbbName,
                guildFullName = thisCityInfo.guildFullName,
                status = thisCityInfo.status,
                beginBurnTime = thisCityInfo.beginBurnTime,
                cityBuff = thisCityInfo.cityBuff,
                headId = thisCityInfo.headId,
                headFrameID = thisCityInfo.headFrameID,
                armyCountMax = thisCityInfo.armyCountMax,
                armyCount = thisCityInfo.armyCount,
                maxSp = thisCityInfo.maxSp,
                sp = thisCityInfo.sp,
                guildId = thisCityInfo.guildId,
                mainHeroId = thisCityInfo.mainHeroId,
                guardTowerLevel = thisCityInfo.guardTowerLevel,
                cityPosTime = thisCityInfo.cityPosTime,
                armyMarchInfos = thisCityInfo.armyMarchInfo,
                battleBuff = thisCityInfo.battleBuff,
            }
        elseif _rtype == Enum.RoleType.MONSTER or _rtype == Enum.RoleType.GUARD_HOLY_LAND
            or _rtype == Enum.RoleType.SUMMON_SINGLE_MONSTER or _rtype == Enum.RoleType.SUMMON_RALLY_MONSTER then
            -- 怪物,仅发送一次
            if roleObjectAoiIndex[_watcherId] and roleObjectAoiIndex[_watcherId][_markerId] then
                return
            end
            -- 怪物
            local thisMonsterInfo = MSM.SceneMonsterMgr[_markerId].req.getMonsterInfo( _markerId, true )
            if not thisMonsterInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                refreshTime = thisMonsterInfo.refreshTime,
                monsterId = thisMonsterInfo.monsterId,
                objectPos = thisMonsterInfo.pos,
                status = thisMonsterInfo.status,
                armyCount = thisMonsterInfo.armyCount,
                targetObjectIndex = thisMonsterInfo.targetObjectIndex,
                soldiers = thisMonsterInfo.soldiers,
                mainHeroId = thisMonsterInfo.mainHeroId,
                deputyHeroId = thisMonsterInfo.deputyHeroId,
                targetAngle = math.floor( thisMonsterInfo.angle ),
                objectPath = thisMonsterInfo.path,
                arrivalTime = thisMonsterInfo.arrivalTime,
                startTime = thisMonsterInfo.startTime,
                attackCount = thisMonsterInfo.attackCount,
                battleBuff = thisMonsterInfo.battleBuff,
                maxSp = thisMonsterInfo.maxSp,
                sp = thisMonsterInfo.sp,
                mainHeroSkills = thisMonsterInfo.mainHeroSkills,
                deputyHeroSkills = thisMonsterInfo.deputyHeroSkills,
                armyCountMax = thisMonsterInfo.armyCountMax,
                armyMarchInfos = thisMonsterInfo.armyMarchInfo,
            }
        elseif _rtype == Enum.RoleType.MONSTER_CITY then
            -- 野蛮人城寨
            local thisMonsterCityInfo = MSM.SceneMonsterCityMgr[_markerId].req.getMonsterCityInfo( _markerId )
            if not thisMonsterCityInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisMonsterCityInfo.pos,
                armyCountMax = thisMonsterCityInfo.armyCountMax,
                armyCount = thisMonsterCityInfo.armyCount,
                maxSp = thisMonsterCityInfo.maxSp,
                sp = thisMonsterCityInfo.sp,
                monsterId = thisMonsterCityInfo.monsterId,
                battleBuff = thisMonsterCityInfo.battleBuff,
                refreshTime = thisMonsterCityInfo.refreshTime,
                mainHeroId = thisMonsterCityInfo.mainHeroId,
                deputyHeroId = thisMonsterCityInfo.deputyHeroId,
                mainHeroSkills = thisMonsterCityInfo.mainHeroSkills,
                deputyHeroSkills = thisMonsterCityInfo.deputyHeroSkills,
                status = thisMonsterCityInfo.status,
                armyMarchInfos = thisMonsterCityInfo.armyMarchInfo,
            }
        elseif MapObjectLogic:checkIsResourceObject( _rtype ) then
            -- 石料、金矿、农田、木材、宝石
            local thisResourceInfo = MSM.SceneResourceMgr[_markerId].req.getResourceInfo( _markerId )
            if not thisResourceInfo then
                return
            end
            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisResourceInfo.pos,
                resourceAmount = thisResourceInfo.resourceAmount,
                resourceId = thisResourceInfo.resourceId,
                collectSpeed = thisResourceInfo.collectSpeed,
                collectRid = thisResourceInfo.collectRid,
                armyIndex = thisResourceInfo.armyIndex,
                collectTime = thisResourceInfo.collectTime,
                cityName = thisResourceInfo.cityName,
                collectSpeeds = thisResourceInfo.collectSpeeds,
                guildAbbName = thisResourceInfo.guildAbbName,
                armyCountMax = thisResourceInfo.armyCountMax,
                armyCount = thisResourceInfo.armyCount,
                resourceGuildAbbName = thisResourceInfo.resourceGuildAbbName,
                guildId = thisResourceInfo.guildId,
                cityLevel = thisResourceInfo.cityLevel,
                status = thisResourceInfo.status,
                mainHeroId = thisResourceInfo.mainHeroId,
                deputyHeroId = thisResourceInfo.deputyHeroId,
                mainHeroSkills = thisResourceInfo.mainHeroSkills,
                deputyHeroSkills = thisResourceInfo.deputyHeroSkills,
                maxSp = thisResourceInfo.maxSp,
                sp = thisResourceInfo.sp,
                armyMarchInfos = thisResourceInfo.armyMarchInfo,
                battleBuff = thisResourceInfo.battleBuff,
            }
        elseif _rtype == Enum.RoleType.SCOUTS then
            -- 斥候,仅发送一次
            if roleObjectAoiIndex[_watcherId] and roleObjectAoiIndex[_watcherId][_markerId] then
                return
            end
            -- 斥候
            local thisScoutsInfo = MSM.SceneScoutsMgr[_markerId].req.getScoutsInfo( _markerId )
            if not thisScoutsInfo then
                return
            end
            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisScoutsInfo.pos,
                objectPath = thisScoutsInfo.path,
                arrivalTime = thisScoutsInfo.arrivalTime,
                speed = thisScoutsInfo.speed,
                objectRid = thisScoutsInfo.rid,
                scoutsIndex = thisScoutsInfo.scoutsIndex,
                status = thisScoutsInfo.status,
                armyRid = thisScoutsInfo.rid,
                armyName = thisScoutsInfo.armyName,
                startTime = thisScoutsInfo.startTime,
                guildAbbName = thisScoutsInfo.guildAbbName,
                guildId = thisScoutsInfo.guildId,
                taregtObjectIndex = thisScoutsInfo.taregtObjectIndex
            }
        elseif _rtype == Enum.RoleType.VILLAGE or _rtype == Enum.RoleType.CAVE then
            -- 村庄、山洞
            local thisResourceInfo = MSM.SceneResourceMgr[_markerId].req.getResourceInfo( _markerId )
            if not thisResourceInfo then
                return
            end
            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisResourceInfo.pos,
                resourcePointId = thisResourceInfo.resourcePointId,
                armyMarchInfos = thisResourceInfo.armyMarchInfo,
            }
        elseif MapObjectLogic:checkIsGuildBuildObject( _rtype ) then
            -- 联盟建筑信息
            local thisBuildInfo = MSM.SceneGuildBuildMgr[_markerId].req.getGuildBuildInfo( _markerId )
            if not thisBuildInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisBuildInfo.pos,
                guildFullName = thisBuildInfo.guildFullName,
                guildAbbName = thisBuildInfo.guildAbbName,
                guildBuildStatus = thisBuildInfo.guildBuildStatus,
                durable = thisBuildInfo.durable,
                durableLimit = thisBuildInfo.durableLimit,
                guildId = thisBuildInfo.guildId,
                buildProgress = thisBuildInfo.buildProgress,
                buildProgressTime = thisBuildInfo.buildProgressTime,
                buildFinishTime = thisBuildInfo.buildFinishTime,
                needBuildTime = thisBuildInfo.needBuildTime,
                buildBurnSpeed = thisBuildInfo.buildBurnSpeed,
                lastOutFireTime = thisBuildInfo.lastOutFireTime,
                buildBurnTime = thisBuildInfo.buildBurnTime,
                buildDurableRecoverTime = thisBuildInfo.buildDurableRecoverTime,
                guildFlagSigns = thisBuildInfo.guildFlagSigns,
                resourceCenterDeleteTime = thisBuildInfo.resourceCenterDeleteTime,
                resourceAmount = thisBuildInfo.resourceAmount,
                collectTime = thisBuildInfo.collectTime,
                collectSpeed = thisBuildInfo.collectSpeed,
                collectRoleNum = thisBuildInfo.collectRoleNum,
                mainHeroId = thisBuildInfo.mainHeroId,
                deputyHeroId = thisBuildInfo.deputyHeroId,
                mainHeroSkills = thisBuildInfo.mainHeroSkills,
                deputyHeroSkills = thisBuildInfo.deputyHeroSkills,
                armyCountMax = thisBuildInfo.armyCountMax,
                armyCount = thisBuildInfo.armyCount,
                maxSp = thisBuildInfo.maxSp,
                sp = thisBuildInfo.sp,
                status = thisBuildInfo.status,
                armyMarchInfos = thisBuildInfo.armyMarchInfo,
                battleBuff = thisBuildInfo.battleBuff,
            }
        elseif _rtype == Enum.RoleType.TRANSPORT then
            -- 运输车信息
            if roleObjectAoiIndex[_watcherId] and roleObjectAoiIndex[_watcherId][_markerId] then
                return
            end
            local thisTransportInfo = MSM.SceneTransportMgr[_markerId].req.getTransportInfo( _markerId )
            if not thisTransportInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                armyRid = thisTransportInfo.rid,
                objectPos = thisTransportInfo.pos,
                objectPath = thisTransportInfo.path,
                arrivalTime = thisTransportInfo.arrivalTime,
                speed = thisTransportInfo.speed,
                objectRid = thisTransportInfo.rid,
                transportIndex = thisTransportInfo.transportIndex,
                armyName = thisTransportInfo.armyName,
                startTime = thisTransportInfo.startTime,
                guildAbbName = thisTransportInfo.guildAbbName,
                status = thisTransportInfo.status,
                guildId = thisTransportInfo.guildId,
                isBattleLose = thisTransportInfo.isBattleLose
            }
        elseif _rtype == Enum.RoleType.CHECKPOINT or _rtype == Enum.RoleType.RELIC then
            -- 圣地信息
            local thisHolyLandInfo = MSM.SceneHolyLandMgr[_markerId].req.getHolyLandInfo( _markerId )
            if not thisHolyLandInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisHolyLandInfo.pos,
                guildAbbName = thisHolyLandInfo.guildAbbName,
                guildId = thisHolyLandInfo.guildId,
                strongHoldId = thisHolyLandInfo.strongHoldId,
                holyLandStatus = thisHolyLandInfo.holyLandStatus,
                holyLandFinishTime = thisHolyLandInfo.holyLandFinishTime,
                kingName = thisHolyLandInfo.kingName,
                sp = thisHolyLandInfo.sp,
                maxSp = thisHolyLandInfo.maxSp,
                armyCount = thisHolyLandInfo.armyCount,
                armyCountMax = thisHolyLandInfo.armyCountMax,
                mainHeroSkills = thisHolyLandInfo.mainHeroSkills,
                deputyHeroSkills = thisHolyLandInfo.deputyHeroSkills,
                mainHeroId = thisHolyLandInfo.mainHeroId,
                deputyHeroId = thisHolyLandInfo.deputyHeroId,
                guildFlagSigns = thisHolyLandInfo.guildFlagSigns,
                status = thisHolyLandInfo.status,
                armyMarchInfos = thisHolyLandInfo.armyMarchInfo,
                battleBuff = thisHolyLandInfo.battleBuff,
            }
        elseif _rtype == Enum.RoleType.RUNE then
            -- 符文信息
            local thisRuneInfo = MSM.SceneRuneMgr[_markerId].req.getRuneInfo( _markerId )
            if not thisRuneInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisRuneInfo.pos,
                runeId = thisRuneInfo.runeId,
                runeRefreshTime = thisRuneInfo.runeRefreshTime,
                armyMarchInfos = thisRuneInfo.armyMarchInfo,
            }
        elseif MapObjectLogic:checkIsGuildResourcePointObject( _rtype ) then
            -- 联盟资源点信息
            local thisResourcePointInfo = MSM.SceneGuildResourcePointMgr[_markerId].req.getGuildResourcePointObject( _markerId )
            if not thisResourcePointInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                objectPos = thisResourcePointInfo.pos,
                guildAbbName = thisResourcePointInfo.guildAbbName,
                guildId = thisResourcePointInfo.guildId,
                armyMarchInfos = thisResourcePointInfo.armyMarchInfo,
            }
        elseif _rtype == Enum.RoleType.EXPEDITION then
            -- 远征对象
            if roleObjectAoiIndex[_watcherId] and roleObjectAoiIndex[_watcherId][_markerId] then
                MSM.SceneExpeditionMgr[_markerId].post.checkMonsterVigilance(_markerId)
                return
            end
            local thisExpeditionInfo = MSM.SceneExpeditionMgr[_markerId].req.getExpeditionInfo( _markerId )
            if not thisExpeditionInfo then
                return
            end

            objectInfo = {
                objectId = _markerId,
                objectType = _rtype,
                armyRid = thisExpeditionInfo.rid,
                objectPos = thisExpeditionInfo.pos,
                objectPath = thisExpeditionInfo.path,
                arrivalTime = thisExpeditionInfo.arrivalTime,
                speed = thisExpeditionInfo.speed,
                objectRid = thisExpeditionInfo.rid,
                armyIndex = thisExpeditionInfo.armyIndex,
                armyName = thisExpeditionInfo.armyName,
                startTime = thisExpeditionInfo.startTime,
                targetObjectIndex = thisExpeditionInfo.taregtObjectIndex,
                monsterId = thisExpeditionInfo.monsterId,
                soldiers = thisExpeditionInfo.soldiers,
                armyCount = thisExpeditionInfo.armyCount,
                armyCountMax = thisExpeditionInfo.armyCountMax,
                sp = thisExpeditionInfo.sp,
                maxSp = thisExpeditionInfo.maxSp,
                skills = thisExpeditionInfo.skills,
                mainHeroSkills = thisExpeditionInfo.mainHeroSkills,
                deputyHeroSkills = thisExpeditionInfo.deputyHeroSkills,
                mainHeroId = thisExpeditionInfo.mainHeroId,
                mainHeroLevel = thisExpeditionInfo.mainHeroLevel,
                deputyHeroId = thisExpeditionInfo.deputyHeroId,
                deputyHeroLevel = thisExpeditionInfo.deputyHeroLevel,
                monsterIndex = thisExpeditionInfo.monsterIndex,
                status = thisExpeditionInfo.status,
                targetAngle = math.floor( thisExpeditionInfo.angle ),
                battleBuff = thisExpeditionInfo.battleBuff,
                mapIndex = thisExpeditionInfo.mapIndex,
            }
            if objectInfo.armyRid and objectInfo.armyRid > 0 then
                objectInfo.armyRadius = thisExpeditionInfo.armyRadius
            end
        end

        -- 加到视野内
        if not roleObjectAoiIndex[_watcherId] then
            roleObjectAoiIndex[_watcherId] = {}
        end
        roleObjectAoiIndex[_watcherId][_markerId] = _rtype

        if not table.empty( objectInfo ) and sceneRoleInfos[_watcherId] then
            pushToClient( _watcherId, "Map_ObjectInfo", { mapObjectInfo = objectInfo } )
            if not armyToRoles[_markerId] then
                armyToRoles[_markerId] = {}
            end
            armyToRoles[_markerId][_watcherId] = sceneRoleFd[_watcherId]
        end
    end
end

---@see 获取地图对象视野内的目标
function response.getMapObjectAreaRangeObjects( _objectIndex )
    if sceneObjectInfos[_objectIndex] then
        return sceneObjectInfos[_objectIndex]
    end
end

---@see 同步对象信息
function accept.syncObjectInfo( _objectIndex, _syncInfo )
    if armyToRoles[_objectIndex] and not table.empty(armyToRoles[_objectIndex]) then
        _syncInfo.objectId = _objectIndex
        if _syncInfo.pos then
            _syncInfo.objectPos = _syncInfo.pos
            _syncInfo.pos = nil
        end
        if _syncInfo.path then
            _syncInfo.objectPath = _syncInfo.path
            _syncInfo.path = nil
        end

        for rid in pairs(armyToRoles[_objectIndex]) do
            pushToClient( rid, "Map_ObjectInfo", { mapObjectInfo = _syncInfo } )
        end
    end
end