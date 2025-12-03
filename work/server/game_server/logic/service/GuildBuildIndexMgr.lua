--[[
* @file : GuildBuildIndexMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Mon Apr 20 2020 18:53:00 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟建筑索引服务
* Copyright(C) 2017 IGG, All rights reserved
]]

---@see 联盟建筑索引信息
local guildBuildIndexs = {} -- { [guildId] = { [buildIndex] = objectIndex } }

---@see 增加联盟建筑索引信息
function response.addGuildBuildIndex( _guildId, _buildIndex, _objectIndex )
    if not guildBuildIndexs[_guildId] then guildBuildIndexs[_guildId] = {} end
    guildBuildIndexs[_guildId][_buildIndex] = _objectIndex
end

---@see 删除联盟建筑索引信息
function accept.deleteGuildBuildIndex( _guildId, _buildIndex )
    if guildBuildIndexs[_guildId] then
        guildBuildIndexs[_guildId][_buildIndex] = nil
        if table.empty( guildBuildIndexs[_guildId] ) then
            guildBuildIndexs[_guildId] = nil
        end
    end
end

---@see 获取联盟建筑索引信息
function response.getGuildBuildIndex( _guildId, _buildIndex )
    if guildBuildIndexs[_guildId] then
        return guildBuildIndexs[_guildId][_buildIndex]
    end
end

---@see 获取联盟建筑索引信息
function response.getGuildBuildIndexs( _guildId )
    return guildBuildIndexs[_guildId]
end