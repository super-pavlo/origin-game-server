--[[
* @file : UserMultiEntity.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 09:40:11 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 多行 user 类型数据的实现
* Copyright(C) 2017 IGG, All rights reserved
]]

require "Entity"
local EntityImpl = require "EntityImpl"
-- 定义UserMultiEntity类型
UserMultiEntity = class(Entity)

function UserMultiEntity:ctor()

end

function UserMultiEntity:dtor()

end

function UserMultiEntity:Init()
	local ret = assert(EntityImpl:getEntityCfg( Enum.TableType.USER, self.tbname ))
	self.key = ret.key
	self.value = ret.value
	self.attr = ret.attr
	self.mainIndex = ret.mainIndex
	self.db = ret.db
	self.center = ret.center
	self.nojson = ret.nojson
	self:initRemoteNode()
end

-- 加载玩家数据
function UserMultiEntity:Load( uid )
	if not self.recordset[uid] then
		local row = EntityImpl:loadUser( self.tbname, uid, self.remoteNode )
		if row and not table.empty(row) then
			self.recordset[uid] = row[self.attr] or row
		end
	end

	if not self.remoteNode and self.recordset[uid] then return self.recordset[uid] end
end


-- 全部卸载
function UserMultiEntity:UnLoadAll()
	for uid,_ in pairs(self.recordset) do
		self:UnLoad( uid )
	end

	self.recordset = {}
	self.updateflag = {}
end

-- 卸载玩家数据
function UserMultiEntity:UnLoad( uid )
	if uid == nil then self:UnLoadAll() return end
	local row = self.recordset[uid]
	if row then
		if self.remoteNode then
			if self.updateflag[uid] then
				--同步到dbNode
				row = EntityImpl:unserializeSproto( self.tbname,
									EntityImpl:serializeSproto( self.tbname, { [self.attr] = row }, true ) )[self.attr]
				Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", uid, nil, row)
			end
			Common.rpcMultiCall(self.remoteNode, self.tbname, "UnLoad", uid)
		else
			if self.updateflag[uid] then
				EntityImpl:updateUser( self.tbname, uid, { [self.attr] = row }, self.nojson )
			end
			--删除redis
			EntityImpl:delRedisImpl( self.tbname, uid )
		end

		self.recordset[uid] = nil
	else
		LOG_WARNING("UnLoad invalid uid:%d at table(%s), not Load in mem", uid, self.tbname)
	end
end

function UserMultiEntity:Add( uid, indexId, row )
	if uid and self.recordset[uid] then
		LOG_ERROR("Add UserMultiEntity Error,Exists,%s",tostring(row))
		return false --记录已经存在，返回
	end

	-- 不存在记录的时候,才插入
	if not self.recordset[uid] or table.empty(self.recordset[uid]) then
		if self.remoteNode then
			--同步到dbNode
			local ret = Common.rpcMultiCall(self.remoteNode, self.tbname, "Add", uid, indexId, row)
			if ret == indexId then
				if not self.recordset[uid] then self.recordset[uid] = {} end
				self.recordset[uid][indexId] = row
			end
		else
			-- at db node
			if not self.recordset[uid] then self.recordset[uid] = {} end
			self.recordset[uid][indexId] = row
			EntityImpl:addUser( self.tbname, uid, { [self.attr] = self.recordset[uid] }, self.nojson )
		end
	else
		-- 有记录存在,仅更新内存
		if not self.recordset[uid] then self.recordset[uid] = {} end
		self.recordset[uid][indexId] = row
		self.updateflag[uid] = true
	end

	return indexId
end

function UserMultiEntity:Delete( uid, indexId )
	if not uid then
		LOG_ERROR("Delete UserMultiEntity,row not [%s] field,%s",self.key,tostring(uid))
		return false
	end

	local delAll = false
	if indexId then --仅删除某个字段内容
		self.recordset[uid][indexId] = nil
		self.updateflag[uid] = true
	else
		delAll = true
	end

	if delAll then
		--实际删除数据
		local ret
		if self.remoteNode then
			ret = Common.rpcMultiSend( self.remoteNode, self.tbname, "Delete", uid)
		else
			ret = EntityImpl:delUser( self.tbname, uid )
		end
		if ret then self.recordset[uid] = nil end
	end

	return true
end

function UserMultiEntity:Update( uid, indexId, row, saveFlag )
	local updateOffline = false
	assert(uid and indexId, self.key.." Not Exists")
	if not self.recordset[uid] then
		updateOffline = true
	end

	local ret = true
	local newRecordSet = self.recordset[uid]
	if updateOffline and self.remoteNode then --离线玩家数据, 请求到remoteNode更新
		if not row[self.mainIndex] then row[self.mainIndex] = indexId end
		row = EntityImpl:unserializeSproto( self.tbname,
				EntityImpl:serializeSproto( self.tbname, { [self.attr] = { [indexId] = row }, true } ) )[self.attr][indexId]
		ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Update", uid, indexId, row )
	else
		-- 位于DB
		if not self.remoteNode then
			if updateOffline then
				-- DB没数据,加载更新
				newRecordSet = EntityImpl:loadUser( self.tbname, uid )[self.attr]
			end
		end
	end

	-- 更新 newRecordSet 数据
	if newRecordSet then
		if not newRecordSet[indexId] then newRecordSet[indexId] = {} end
		for name,value in pairs(row) do
			newRecordSet[indexId][name] = value
		end
	end

	-- 位于DB,直接更新
	if not self.remoteNode then
		ret = EntityImpl:updateUser( self.tbname, uid, { [self.attr] = newRecordSet }, self.nojson )
	elseif ret and not updateOffline then
		-- 在线仅更新内存,待UnLoad的时候再更新到db
		if saveFlag then
			-- 立即保存,一般为远程 Save 调用
			ret = EntityImpl:updateUser( self.tbname, uid, { [self.attr] = newRecordSet }, self.nojson )
		else
			self.updateflag[uid] = true
		end
	end
	if not updateOffline then self.recordset[uid] = newRecordSet end
	return ret
end

function UserMultiEntity:Get(uid, indexId, field)
	if not uid then return self:GetAll() end
	local record = self.recordset[uid]

	--memory not exist,offline user, load from redis or mysql(mongo)
	if not record then
		record = EntityImpl:loadUser( self.tbname, uid, self.remoteNode )
		if record and record[self.attr] then record = record[self.attr] end
	end

	if record then
		return self:getMultiEntityValue(record, indexId, field)
	end
end

function UserMultiEntity:Set(uid, indexId, field, value)
	local record
	if type(indexId) == "table" then
		record = indexId
	else
		if type(field) ~= "table" then
			record = {}
			record[field] = value
		else
			record = field
		end
	end
	return self:Update(uid, indexId, record)
end

function UserMultiEntity:NewId( uid )
	return self:newId( uid )
end

function UserMultiEntity:Save( uid, noSave )
	local row = self.recordset[uid]
	if self.remoteNode and self.updateflag[uid] and row then
		--同步到dbNode
		row = EntityImpl:unserializeSproto( self.tbname,
								EntityImpl:serializeSproto( self.tbname, { [self.attr] = row }, true ) )[self.attr]
		local saveFlag = true
		if noSave then saveFlag = false end
		Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", uid, nil, row, saveFlag)
	end
end