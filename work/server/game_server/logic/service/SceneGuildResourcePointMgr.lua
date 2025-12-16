--[[
* @file : SceneGuildResourcePointMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu May 28 2020 16:11:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图联盟资源点管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

---@see 地图联盟资源点信息
---@class defaultMapGuildResourcePointInfoClass
local defaultMapGuildResourcePointInfo = {
    guildAbbName                =                   "",             -- 联盟简称
    guildId                     =                   0,              -- 联盟ID
    objectType                  =                   0,              -- 地图对象类型
    pos                         =                   {},             -- 坐标
    armyMarchInfo               =                   {},             -- 目标行军信息
}

---@type table<int, defaultMapGuildResourcePointInfoClass>
local mapGuildResourcePointInfos = {}

---@see 增加联盟资源点对象
function response.addGuildResourcePointObject( _objectIndex, _resourcePointInfo )
    local mapGuildResourcePointInfo = const( table.copy( defaultMapGuildResourcePointInfo, true ) )
    mapGuildResourcePointInfo.guildAbbName = _resourcePointInfo.guildAbbName or ""
    mapGuildResourcePointInfo.guildId = _resourcePointInfo.guildId or 0
    mapGuildResourcePointInfo.objectType = _resourcePointInfo.objectType
    mapGuildResourcePointInfo.pos = _resourcePointInfo.pos

    mapGuildResourcePointInfos[_objectIndex] = mapGuildResourcePointInfo

    if mapGuildResourcePointInfo.guildId > 0 then
        MSM.GuildResourcePointIndexMgr[mapGuildResourcePointInfo.guildId].req.addGuildResourcePointIndex( mapGuildResourcePointInfo.guildId, _objectIndex )
    end
end

---@see 获取联盟资源点对象信息
function response.getGuildResourcePointObject( _objectIndex )
    return mapGuildResourcePointInfos[_objectIndex]
end

---@see 获取联盟建筑坐标
function response.getGuildResourcePointPos( _objectIndex )
    if mapGuildResourcePointInfos[_objectIndex] then
        return mapGuildResourcePointInfos[_objectIndex].pos
    end
end

---@see 更新地图联盟资源点信息
function accept.updateGuildResourcePointInfo( _objectIndex, _updateResourcePointInfo )
    if mapGuildResourcePointInfos[_objectIndex] then
        local guildId = mapGuildResourcePointInfos[_objectIndex].guildId
        local newGuildId = _updateResourcePointInfo.guildId or 0
        if guildId <= 0 and newGuildId > 0 then
            -- 联盟资源点首次占用
            MSM.GuildResourcePointIndexMgr[newGuildId].req.addGuildResourcePointIndex( newGuildId, _objectIndex )
        elseif guildId > 0 and newGuildId <= 0 then
            -- 联盟资源点释放
            MSM.GuildResourcePointIndexMgr[guildId].post.deleteGuildResourcePointIndex( guildId, _objectIndex )
        elseif guildId > 0 and newGuildId > 0 and guildId ~= newGuildId then
            -- 联盟资源点被其他联盟占有
            MSM.GuildResourcePointIndexMgr[guildId].post.deleteGuildResourcePointIndex( guildId, _objectIndex )
            MSM.GuildResourcePointIndexMgr[newGuildId].req.addGuildResourcePointIndex( newGuildId, _objectIndex )
        end

        table.mergeEx( mapGuildResourcePointInfos[_objectIndex], _updateResourcePointInfo )
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        sceneObject.post.syncObjectInfo( _objectIndex, _updateResourcePointInfo )
    end
end

---@see 更新地图联盟资源点信息
function accept.updateGuildAbbName( _objectIndex, _guildAbbName )
    if mapGuildResourcePointInfos[_objectIndex] then
        mapGuildResourcePointInfos[_objectIndex].guildAbbName = _guildAbbName
        -- 通过AOI通知
        local sceneObject = Common.getSceneMgr( Enum.MapLevel.GUILD )
        sceneObject.post.syncObjectInfo( _objectIndex, { guildAbbName = _guildAbbName } )
    end
end
