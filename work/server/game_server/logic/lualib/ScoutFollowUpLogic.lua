--[[
* @file : ScoutFollowUpLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Sat May 23 2020 18:23:52 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 斥候追踪逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local ArmyLogic = require "ArmyLogic"
local MapObjectLogic = require "MapObjectLogic"
local GuildLogic = require "GuildLogic"

local ScoutFollowUpLogic = {}

---@see 斥候追踪逻辑
function ScoutFollowUpLogic:dispatchScoutFollowUp( _scoutFollowUpInfos, _mapScoutsInfos )
    local lastPos, targetObjectIndex, scoutInfo, path, armyInfo, targetObjectInfo
    for scoutObjectIndex, followInfo in pairs( _scoutFollowUpInfos ) do
        lastPos = nil
        scoutInfo = _mapScoutsInfos[scoutObjectIndex]
        if scoutInfo then
            if scoutInfo.scoutTarget.targetType == Enum.ScoutTargetType.RALLY_ARMY then
                targetObjectIndex = followInfo.targetObjectIndex
                lastPos = MSM.SceneArmyMgr[targetObjectIndex].req.getArmyPos( targetObjectIndex )
            else
                armyInfo = ArmyLogic:getArmy( followInfo.rid, followInfo.armyIndex, { Enum.Army.status, Enum.Army.targetArg } )
                if armyInfo and armyInfo.status and not ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.FAILED_MARCH ) then
                    targetObjectIndex = MSM.RoleArmyMgr[followInfo.rid].req.getRoleArmyIndex( followInfo.rid, followInfo.armyIndex )
                    if targetObjectIndex then
                        lastPos = MSM.SceneArmyMgr[targetObjectIndex].req.getArmyPos( targetObjectIndex )
                    else
                        -- 检查部队是否在资源点中
                        if ArmyLogic:checkArmyStatus( armyInfo.status, Enum.ArmyStatus.COLLECTING ) then
                            targetObjectIndex = armyInfo.targetArg.targetObjectIndex
                            if targetObjectIndex and targetObjectIndex > 0 then
                                targetObjectInfo = MSM.MapObjectTypeMgr[targetObjectIndex].req.getObjectType( targetObjectIndex )
                                -- 部队在野外资源田中采集，获取野外资源田坐标
                                if MapObjectLogic:checkIsResourceObject( targetObjectInfo.objectType ) then
                                    lastPos = MSM.SceneResourceMgr[targetObjectIndex].req.getResourcePos( targetObjectIndex )
                                end
                            end
                        end
                    end
                end
            end

            if lastPos and ( lastPos.x ~= followInfo.lastPos.x or lastPos.y ~= followInfo.lastPos.y ) then
                -- 改变目标点
                local fromPos = MSM.MapMarchMgr[scoutObjectIndex].req.fixObjectPosWithMillisecond( scoutObjectIndex, true ) or scoutInfo.pos
                path = { fromPos, lastPos }
                -- 更新斥候目标点坐标
                MSM.MapMarchMgr[scoutObjectIndex].req.scoutsChangePos( scoutInfo.rid, scoutInfo.scoutsIndex, path, targetObjectIndex, scoutInfo.speed, scoutObjectIndex )
                followInfo.lastPos = lastPos
            end
        else
            _scoutFollowUpInfos[scoutObjectIndex] = nil
        end
    end
end

---@see 斥候新旧目标追踪处理
function ScoutFollowUpLogic:checkScoutTarget( _objectIndex, _oldTargetIndex, _newTargetIndex )
    if _oldTargetIndex and _oldTargetIndex > 0 then
        -- 旧的目标
        MSM.SceneScoutsMgr[_objectIndex].req.deleteScoutFollowTarget( _objectIndex )
    end

    if _newTargetIndex and _newTargetIndex > 0 then
        -- 新的目标
        local scoutTarget
        local taregetObjectInfo = MSM.MapObjectTypeMgr[_newTargetIndex].req.getObjectType( _newTargetIndex ) or {}
        local toType = taregetObjectInfo.objectType
        if toType == Enum.RoleType.ARMY then
            -- 侦查部队
            local armyInfo = MSM.SceneArmyMgr[_newTargetIndex].req.getArmyInfo( _newTargetIndex )
            if armyInfo.isRally then
                -- 侦查集结部队
                scoutTarget = { targetType = Enum.ScoutTargetType.RALLY_ARMY, rid = armyInfo.rid, armyIndex = armyInfo.armyIndex }
                MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, _newTargetIndex, armyInfo.rid, armyInfo.armyIndex, armyInfo.pos, scoutTarget )
            else
                -- 侦查角色部队
                scoutTarget = { targetType = Enum.ScoutTargetType.ROLE_ARMY, rid = armyInfo.rid, armyIndex = armyInfo.armyIndex }
                MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, _newTargetIndex, armyInfo.rid, armyInfo.armyIndex, armyInfo.pos, scoutTarget )
            end
        elseif toType == Enum.RoleType.CITY then
            -- 侦查城市
            local cityInfo = MSM.SceneCityMgr[_newTargetIndex].req.getCityInfo( _newTargetIndex )
            scoutTarget = { targetType = Enum.ScoutTargetType.CITY, pos = { x = cityInfo.pos.x, y = cityInfo.pos.y } }
            MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, nil, nil, nil, nil, scoutTarget )
        elseif MapObjectLogic:checkIsResourceObject( toType ) then
            -- 侦查资源点中的部队
            local resourceInfo = MSM.SceneResourceMgr[_newTargetIndex].req.getResourceInfo( _newTargetIndex )
            scoutTarget = { targetType = Enum.ScoutTargetType.RESOURCE, rid = resourceInfo.collectRid, armyIndex = resourceInfo.armyIndex }
            -- 侦查角色部队
            MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, _newTargetIndex, resourceInfo.collectRid, resourceInfo.armyIndex, resourceInfo.pos, scoutTarget )
        elseif MapObjectLogic:checkIsAttackGuildBuildObject( toType ) then
            -- 侦查联盟建筑
            local guildBuild = MSM.SceneGuildBuildMgr[_newTargetIndex].req.getGuildBuildInfo( _newTargetIndex )
            local guildInfo = GuildLogic:getGuild( guildBuild.guildId, { Enum.Guild.signs, Enum.Guild.abbreviationName } )
            scoutTarget = { targetType = Enum.ScoutTargetType.GUILD_BUILD }
            scoutTarget.signs = guildInfo.signs
            scoutTarget.abbreviationName = guildInfo.abbreviationName
            scoutTarget.pos = { x = guildBuild.pos.x, y = guildBuild.pos.y }
            scoutTarget.objectType = guildBuild.objectType
            scoutTarget.guildId = guildBuild.guildId

            MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, nil, nil, nil, nil, scoutTarget )
        elseif toType == Enum.RoleType.CHECKPOINT then
            -- 侦查关卡
            scoutTarget = { targetType = Enum.ScoutTargetType.CHECKPOINT }
            MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, nil, nil, nil, nil, scoutTarget )
        elseif toType == Enum.RoleType.RELIC then
            -- 侦查圣地
            scoutTarget = { targetType = Enum.ScoutTargetType.RELIC }
            MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, nil, nil, nil, nil, scoutTarget )
        elseif toType == Enum.RoleType.CAVE then
            -- 探索山洞
            scoutTarget = { targetType = Enum.ScoutTargetType.CAVE }
            MSM.SceneScoutsMgr[_objectIndex].post.addScoutFollowTarget( _objectIndex, nil, nil, nil, nil, scoutTarget )
        end
    end
end

return ScoutFollowUpLogic