--[[
* @file : RoleProxy.lua
* @type : snax single service
* @author : dingyuchao 九  零  一 起 玩 w w w . 9 0  1 7 5 . co m
* @created : Fri Apr 10 2020 19:48:32 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色信息获取代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local EntityImpl = require "EntityImpl"

---@see 初始化
function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

---@see 获取角色信息
function response.queryRoles( _index, _indexLimit )
    local allRoles = {}
    _index = _index or 0
	_indexLimit = _indexLimit or 2000

	local cmd = string.format( "select * from d_role limit %d,%d", _index, _indexLimit )
	local sqlRet = Common.mysqlExecute( cmd )
	if #sqlRet <= 0 then return allRoles end

	local decodeRow
	for _, row in pairs(sqlRet) do
		assert(table.size(row) >= 2, "mysql table(d_role) schema must be key-value")
		decodeRow = EntityImpl:unserializeSproto( "d_role", row.value )
		allRoles[tonumber(row.rid)] = {
			guildId = decodeRow.guildId,
			name = decodeRow.name,
		}
	end

    return allRoles
end