--[[
* @file : SceneTransportMgr.lua
* @type : snax multi service
* @author : chenlei
* @created : Fri May 08 2020 13:26:46 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图运输车管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local GuildLogic = require "GuildLogic"

---@see 地图运输车信息
---@class defaultMapTransportInfoClass
local defaultMapTransportInfo = {
    pos                         =                   {},             -- 运输车坐标
    rid                         =                   0,              -- 角色rid
    armyName                    =                   "",             -- 角色名称
    arrivalTime                 =                   0,              -- 运输车到达时间
    startTime                   =                   0,              -- 运输车达到时间
    speed                       =                   0,              -- 运输车移动速度
    path                        =                   {},             -- 运输车移动路径
    transportIndex              =                   0,              -- 运输车索引
    guildAbbName                =                   "",             -- 角色所在联盟简称
    targetObjectIndex           =                   0,              -- 目标索引
    guildId                     =                   0,              -- 联盟id
    status                      =                   0,              -- 状态
    isBattleLose                =                   false,          -- 是否是战损运输
}

---@type table<int, defaultMapTransportInfoClass>
local mapTransportInfos = {}

---@see 增加运输车对象
function response.addTransportObject( _objectIndex, _transportInfo, _pos )
    local guildAbbName
    local roleInfo = RoleLogic:getRole( _transportInfo.rid, { Enum.Role.name, Enum.Role.guildId } )
    if roleInfo.guildId and roleInfo.guildId > 0 and not _transportInfo.isSelf then
        guildAbbName = GuildLogic:getGuild( roleInfo.guildId, Enum.Guild.abbreviationName )
    end

    local mapTransportInfo = const( table.copy( defaultMapTransportInfo, true ) )
    mapTransportInfo.pos = _pos
    mapTransportInfo.rid = _transportInfo.rid
    mapTransportInfo.armyName = not _transportInfo.isSelf and roleInfo.name or ""
    mapTransportInfo.arrivalTime = _transportInfo.arrivalTime
    mapTransportInfo.startTime = _transportInfo.startTime
    mapTransportInfo.speed = _transportInfo.speed
    mapTransportInfo.path = _transportInfo.path
    mapTransportInfo.transportIndex = _transportInfo.transportIndex
    mapTransportInfo.guildAbbName = guildAbbName
    mapTransportInfo.guildId = not _transportInfo.isSelf and roleInfo.guildId or 0
    mapTransportInfo.targetObjectIndex = _transportInfo.targetObjectIndex
    mapTransportInfo.status = Enum.ArmyStatus.SPACE_MARCH
    mapTransportInfo.isBattleLose = _transportInfo.isBattleLose or false
    mapTransportInfos[_objectIndex] = mapTransportInfo
end

---@see 删除运输车对象delete
function accept.deleteTransportObject( _objectIndex )
    if mapTransportInfos[_objectIndex] then
        mapTransportInfos[_objectIndex] = nil
    end
end

---@see 更新运输车坐标
function accept.updateScoutsPos( _objectIndex, _pos )
    if mapTransportInfos[_objectIndex] then
        _pos.x = math.floor( _pos.x )
        _pos.y = math.floor( _pos.y )
        mapTransportInfos[_objectIndex].pos = _pos
    end
end

---@see 获取运输车坐标
function response.getTransportPos( _objectIndex )
    if mapTransportInfos[_objectIndex] then
        return mapTransportInfos[_objectIndex].pos
    end
end

---@see 获取运输车信息
function response.getTransportInfo( _objectIndex )
    return mapTransportInfos[_objectIndex]
end

---@see 更新运输车行军路径
function accept.updateTransportPath( _objectIndex, _path, _targetObjectIndex, _arrivalTime, _startTime )
    if mapTransportInfos[_objectIndex] then
        -- 更新目标
        mapTransportInfos[_objectIndex].targetObjectIndex = _targetObjectIndex
        mapTransportInfos[_objectIndex].arrivalTime = _arrivalTime
        mapTransportInfos[_objectIndex].startTime = _startTime
        mapTransportInfos[_objectIndex].path = _path
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { path = _path, arrivalTime =  _arrivalTime, startTime = _startTime,
            status = mapTransportInfos[_objectIndex].status } )
    end
end


---@see 同步对象联盟简称
function accept.syncGuildAbbName( _objectIndex, _guildAbbName )
    if mapTransportInfos[_objectIndex] then
        mapTransportInfos[_objectIndex].guildAbbName = _guildAbbName

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildAbbName = _guildAbbName } )
    end
end

---@see 同步对象军队名称
function accept.syncArmyName( _objectIndex, _name )
    if mapTransportInfos[_objectIndex] then
        mapTransportInfos[_objectIndex].armyName = _name

        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { armyName = _name } )
    end
end

---@see 更新城市联盟
function response.syncGuildId( _objectIndex, _guildId )
    if mapTransportInfos[_objectIndex] then
        mapTransportInfos[_objectIndex].guildId = _guildId
        if _guildId and _guildId > 0 then
            local guildInfo = GuildLogic:getGuild( _guildId, { Enum.Guild.abbreviationName, Enum.Guild.name } )
            mapTransportInfos[_objectIndex].guildAbbName = guildInfo.abbreviationName
        else
            mapTransportInfos[_objectIndex].guildAbbName = ""
        end

        -- 同步联盟信息
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.ARMY )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildId = _guildId, guildAbbName = mapTransportInfos[_objectIndex].guildAbbName } )
    end
end