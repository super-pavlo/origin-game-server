--[[
 * @file : CommonLoadMgr.lua
 * @type : snax single service
 * @author : linfeng
 * @created : 2019-09-05 16:05:44
 * @Last Modified time: 2019-09-05 16:05:44
 * @department : Arabic Studio
 * @brief : 通用加载管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local EntityImpl = require "EntityImpl"

function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

---@see 加载common数据
function response.loadCommonMysqlImpl( _tbname, _beginIndex, _limit )
    return EntityImpl:loadCommonMysqlImpl( _tbname, _beginIndex, _limit )
end

---@see 获取common最大数据量
function response.getCommonCount( _tbname )
	local cmd = string.format("select count(*) as count from %s", _tbname)
	local ret = Common.mysqlExecute(cmd)
	assert(ret.badresult == nil, "execute sql fail:"..cmd..",err:"..(ret.err or ""))
	return tonumber(ret[1].count)
end

---@see 批量加载role角色城市位置
function response.loadRoleCityPos( _beginIndex )
    local ret = {}
	local index = _beginIndex or 0
	local index_limit = 1000
	local cmd

	local roleEntity = EntityImpl:getEntityCfg(Enum.TableType.ROLE, "d_role")
	while true do
		cmd = string.format("select * from %s limit %d,%d",roleEntity.name,index,index_limit)
		local sqlRet = Common.mysqlExecute(cmd)
		if #sqlRet <= 0 then break end

		for _,row in pairs(sqlRet) do
			--sproto extract
			assert(table.size(row) >= 2, "mysql table("..roleEntity.name..") schema must be key-value")
			local decodeRow = EntityImpl:unserializeSproto("d_role", row[roleEntity.value])

			--set to memory
			ret[row[roleEntity.key]] = decodeRow.pos
		end

		if #sqlRet < index_limit or _beginIndex then break end
		index = index + index_limit
	end
	return ret
end