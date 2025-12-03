--[[
* @file : SceneScoutsMgr.lua
* @type : snax multi service
* @author : linfeng
* @created : Thu May 03 2018 11:29:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图斥候管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local ScoutsLogic = require "ScoutsLogic"
local GuildLogic = require "GuildLogic"
local Timer = require "Timer"
local ScoutFollowUpLogic = require "ScoutFollowUpLogic"

---@see 地图斥候信息
---@class defaultMapScoutsInfoClass
local defaultMapScoutsInfo = {
    pos                         =                   {},             -- 斥候坐标
    rid                         =                   0,              -- 角色rid
    armyName                    =                   "",             -- 角色名称
    arrivalTime                 =                   0,              -- 斥候到达时间
    startTime                   =                   0,              -- 斥候达到时间
    speed                       =                   0,              -- 斥候移动速度
    path                        =                   {},             -- 斥候移动路径
    scoutsIndex                 =                   0,              -- 斥候索引
    status                      =                   0,              -- 斥候状态
    guildAbbName                =                   "",             -- 角色所在联盟简称
    taregtObjectIndex           =                   0,              -- 增加斥候目标
    scoutTarget                 =                   {},             -- 斥候侦查目标信息
    guildId                     =                   0,              -- 联盟id
}

---@type table<int, defaultMapScoutsInfoClass>
local mapScoutsInfos = {}

---@type table<int, table<string, int>>
local mapScoutFollowInfos = {}

function init()
    -- 每秒检测斥候追踪
    Timer.runEvery( 100, ScoutFollowUpLogic.dispatchScoutFollowUp, ScoutFollowUpLogic, mapScoutFollowInfos, mapScoutsInfos )
end

---@see 增加斥候对象
function response.addScoutsObject( _objectIndex, _scoutsInfo, _pos )
    local guildAbbName
    local roleInfo = RoleLogic:getRole( _scoutsInfo.rid, { Enum.Role.name, Enum.Role.guildId } )
    if roleInfo.guildId and roleInfo.guildId > 0 then
        guildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end

    local mapScoutsInfo = const( table.copy( defaultMapScoutsInfo, true ) )
    mapScoutsInfo.pos = _pos
    mapScoutsInfo.rid = _scoutsInfo.rid
    mapScoutsInfo.speed = _scoutsInfo.speed
    mapScoutsInfo.arrivalTime = _scoutsInfo.arrivalTime
    mapScoutsInfo.path = _scoutsInfo.path
    mapScoutsInfo.scoutsIndex = _scoutsInfo.scoutsIndex
    mapScoutsInfo.status = _scoutsInfo.scoutsStatus
    mapScoutsInfo.armyName = roleInfo.name
    mapScoutsInfo.startTime = _scoutsInfo.startTime or os.time()
    mapScoutsInfo.guildAbbName = guildAbbName or ""
    mapScoutsInfo.scoutTarget = {}
    mapScoutsInfo.guildId = roleInfo.guildId
    mapScoutsInfos[_objectIndex] = mapScoutsInfo

    -- 增加斥候对象索引
    ScoutsLogic:addObjectIndexToScouts( _scoutsInfo.rid, _scoutsInfo.scoutsIndex, _objectIndex )
end

---@see 删除斥候对象
function accept.deleteScoutsObject( _objectIndex )
    if mapScoutsInfos[_objectIndex] then
        local scoutsInfo = mapScoutsInfos[_objectIndex]
        ScoutsLogic:syncScouts( scoutsInfo.rid, {
                                            scoutsQueue = {
                                                            [scoutsInfo.scoutsIndex] = {
                                                                                            scoutsIndex = scoutsInfo.scoutsIndex,
                                                                                            objectIndex = 0
                                                                                        }
                                                        }
                                            }
                            )
        mapScoutsInfos[_objectIndex] = nil
    end
end

---@see 更新斥候对象信息
function accept.updateScoutsSoldier( _objectIndex, _die, _minor )

end

---@see 更新斥候坐标
function accept.updateScoutsPos( _objectIndex, _pos )
    if mapScoutsInfos[_objectIndex] then
        _pos.x = math.floor( _pos.x )
        _pos.y = math.floor( _pos.y )
        mapScoutsInfos[_objectIndex].pos = _pos
    end
end

---@see 获取斥候坐标
function response.getScoutsPos( _objectIndex )
    if mapScoutsInfos[_objectIndex] then
        return mapScoutsInfos[_objectIndex].pos
    end
end

---@see 获取斥候信息
function response.getScoutsInfo( _objectIndex )
    return mapScoutsInfos[_objectIndex]
end

---@see 更新斥候行军路径
function accept.updateScoutsPath( _objectIndex, _path, _targetObjectIndex, _arrivalTime, _startTime, _status )
    if mapScoutsInfos[_objectIndex] then
        -- 更新目标
        mapScoutsInfos[_objectIndex].taregtObjectIndex = _targetObjectIndex or 0
        mapScoutsInfos[_objectIndex].arrivalTime = _arrivalTime
        mapScoutsInfos[_objectIndex].startTime = _startTime
        mapScoutsInfos[_objectIndex].path = _path
        if _status then
            mapScoutsInfos[_objectIndex].status = _status
        end
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = _path, arrivalTime = _arrivalTime, startTime = _startTime, status = mapScoutsInfos[_objectIndex].status } )
    end
end

---@see 更新斥候状态
function accept.updateScoutsStatus( _objectIndex, _status )
    if mapScoutsInfos[_objectIndex] then
        mapScoutsInfos[_objectIndex].status = _status
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { status = _status } )
    end
end

---@see 同步对象联盟简称
function accept.syncGuildAbbName( _objectIndex, _guildAbbName )
    if mapScoutsInfos[_objectIndex] then
        mapScoutsInfos[_objectIndex].guildAbbName = _guildAbbName

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildAbbName = _guildAbbName } )
    end
end

---@see 同步对象军队名称
function accept.syncArmyName( _objectIndex, _name )
    if mapScoutsInfos[_objectIndex] then
        mapScoutsInfos[_objectIndex].armyName = _name

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyName = _name } )
    end
end

---@see 增加斥候追踪对象
function accept.addScoutFollowTarget( _objectIndex, _targetObjectIndex, _rid, _armyIndex, _lastPos, _scoutTarget )
    if _targetObjectIndex then
        mapScoutFollowInfos[_objectIndex] = {
            targetObjectIndex = _targetObjectIndex,
            rid = _rid,
            armyIndex = _armyIndex,
        }
        if _lastPos then
            mapScoutFollowInfos[_objectIndex].lastPos = { x = _lastPos.x, y = _lastPos.y }
        end
    end

    if _scoutTarget then
        mapScoutsInfos[_objectIndex].scoutTarget = _scoutTarget
    end
end

---@see 删除斥候追踪对象
function response.deleteScoutFollowTarget( _objectIndex )
    mapScoutFollowInfos[_objectIndex] = nil
    mapScoutsInfos[_objectIndex].scoutTarget = {}
end

---@see 删除斥候追踪
function accept.deleteScoutFollow( _objectIndex )
    mapScoutFollowInfos[_objectIndex] = nil
end

---@see 斥候路径置空
function response.setPathEmpty( _objectIndex )
    if mapScoutsInfos[_objectIndex] then
        mapScoutsInfos[_objectIndex].path = {}
        -- 更新armyInfo的path
        ScoutsLogic:updateScountsPath( mapScoutsInfos[_objectIndex].rid, mapScoutsInfos[_objectIndex].scoutsIndex, {} )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = {} } )
    end
end