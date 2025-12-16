--[[
* @file : GuildResourcePointIndexMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Thu May 28 2020 16:53:03 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟资源点索引服务
* Copyright(C) 2017 IGG, All rights reserved
]]

---@see 联盟资源点索引信息
local guildResourcePointIndexs = {} -- { [guildId] = { [objectIndex] = objectIndex } }

---@see 增加联盟资源点索引信息
function response.addGuildResourcePointIndex( _guildId, _objectIndex )
    if not guildResourcePointIndexs[_guildId] then guildResourcePointIndexs[_guildId] = {} end
    guildResourcePointIndexs[_guildId][_objectIndex] = _objectIndex
end

---@see 获取联盟资源点索引信息
function response.getGuildResourcePointIndexs( _guildId )
    return guildResourcePointIndexs[_guildId]
end

---@see 删除联盟资源点索引
function accept.deleteGuildResourcePointIndex( _guildId, _objectIndex )
    if guildResourcePointIndexs[_guildId] then
        guildResourcePointIndexs[_guildId][_objectIndex] = nil
    end
end