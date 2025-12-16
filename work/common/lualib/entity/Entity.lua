--[[
* @file : Entity.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 11:11:05 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 数据结构基类
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local queue = require "skynet.queue"

-- 定义Entity类型
Entity = class()

function Entity:ctor()
    self.recordset = {} -- 存放记录集
    setmetatable(self.recordset, {__mode = "k"}) --key弱表
    self.tbname = "" -- 表名
    self.key = "" -- 主键
    self.indexkey = "" -- 索引
	self.updateflag = {} --更新标记
	self.node = skynet.getenv("clusternode")
	self.cache = {}
	self.multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM --默认DEFUALT_SNAX_SERVICE_NUM个子服务
	self.atomic = {}
end

function Entity:lock( id )
	if not self.atomic[id] then
		self.atomic[id] = queue()
	end
	return self.atomic[id]
end

function Entity:initRemoteNode()
	local dbNode = sharedata.query( Enum.Share.DBNODE ).name
	local centerNode = sharedata.query( Enum.Share.CENTERNODE ).name

	-- 不存在既要连接db 又要连接center 的节点
	assert( self.db == nil or self.center == nil )

	-- self.db = true 表示需要连接db
	if self.db then
		self.remoteNode = dbNode
	elseif self.center then
		self.remoteNode = centerNode
	end
end

function Entity:newId()
	if self.remoteNode then
		if self.commTable then
			return Common.rpcCall( self.remoteNode, self.tbname, "NewId")
		else
			return Common.rpcCall( self.remoteNode, self.tbname .. self:getRemoteIndex(1), "NewId")
		end
	else
		return Common.redisExecute( { "incr", string.format("%s:%s", self.tbname, self.key) } )
	end
end

function Entity:getRemoteIndex( index )
	return index % self.multiSnaxNum
end

---@see 检查远程节点是否存活
function Entity:CheckRemoteNodeAlive()
	return Common.checkNodeAlive( self.remoteNode, "Rpc" )
end

function Entity:getMultiEntityValue( row, indexId, field )
	local record = {}
	if row then
		if indexId == nil then return row end

		if type(indexId) == "table" then
			for _,index in pairs(indexId) do
				if row[index] then
					record[index] = {}
					if type(field) == "table" then
						for _,name in pairs(field) do
							record[index][name] = row[index][name]
						end
					else
						if field then
							record[index][field] = row[index][field]
						else
							record[index] = row[index]
						end
					end
				end
			end
		else
			if type(field) == "table" then
				for _,name in pairs(field) do
					if row[indexId] then
						record[name] = row[indexId][name]
					end
				end
			else
				if row[indexId] then
					if field then
						record = row[indexId][field]
					else
						record = row[indexId]
					end
				else
					if field then
						record = nil
					else
						record = {}
					end
				end
			end
		end

		return record
	end
end

function Entity:getSingleEntityValue( row, field )
	local record = {}
	if row and Common.isTable(row) then
		if field == nil then return row end
		if type(field) == "table" then
			for _,name in pairs(field) do
				record[name] = row[name]
			end
		else
			record = row[field]
		end
		return record
	end
end

function Entity:GetAll()
    return self.recordset
end

function Entity:dtor()

end

local M = {}
local entities = {} -- 保存实体对象

-- 工厂方法，获取具体对象，name为表名
function M.Get(name)
    if entities[name] then
        return entities[name]
    end

    local ent = require(name)
    entities[name] = ent
    return ent
end

return M
