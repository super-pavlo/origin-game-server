--[[
* @file : UserSingleEntity.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 09:25:40 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 单行 user 数据类型的实现
* Copyright(C) 2017 IGG, All rights reserved
]]

require "Entity"
local EntityImpl = require "EntityImpl"
-- 定义UserSingleEntity类型
UserSingleEntity = class(Entity)

function UserSingleEntity:ctor()

end

function UserSingleEntity:dtor()

end

function UserSingleEntity:Init()
	local ret = assert(EntityImpl:getEntityCfg( Enum.TableType.USER, self.tbname ))
	self.key = ret.key
	self.value = ret.value
	self.db = ret.db
	self.center = ret.center
	self.nojson = ret.nojson
	self:initRemoteNode()
end

-- 加载玩家数据
function UserSingleEntity:Load( uid )
	if not self.recordset[uid] then
		local row = EntityImpl:loadUser( self.tbname, uid, self.remoteNode )
		if row and not table.empty(row) then
			self.recordset[uid] = row
		end
	end

	-- return to caller
	if not self.remoteNode and self.recordset[uid] then return self.recordset[uid] end
end

-- 全部卸载
function UserSingleEntity:UnLoadAll()
	for uid,_ in pairs(self.recordset) do
		self:UnLoad( uid )
	end

	self.recordset = {}
	self.updateflag = {}
end

-- 卸载玩家数据
function UserSingleEntity:UnLoad( uid )
	if uid == nil then self:UnLoadAll() return end
	local row = self.recordset[uid]
	if row then
		if self.remoteNode then
			--同步到dbNode
			if self.updateflag[uid] then
				row = EntityImpl:unserializeSproto( self.tbname, EntityImpl:serializeSproto( self.tbname, row, true ) )
				Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", uid, row)
			end
			Common.rpcMultiCall(self.remoteNode, self.tbname, "UnLoad", uid)
		else
			if self.updateflag[uid] then
				EntityImpl:updateUser( self.tbname, uid, row, self.nojson )
			end
			--删除redis
			EntityImpl:delRedisImpl( self.tbname, uid )
		end

		self.recordset[uid] = nil
	else
		LOG_WARNING("UnLoad invalid uid:%d at table(%s), not Load in mem", uid, self.tbname)
	end
end

-- row中包含self.key字段,row为k,v形式table
function UserSingleEntity:Add( uid, row )
	uid = uid or row[self.key]
	if uid and self.recordset[uid] then
		LOG_ERROR("Add UserSingleEntity Error,Exists,%s",tostring(row))
		return false --记录已经存在，返回
	end

	if self.remoteNode then
		--同步到dbNode
		local ret = Common.rpcMultiCall(self.remoteNode, self.tbname, "Add", uid, row)
		if ret.res then
			self.recordset[ret.uid] = ret.row
		end
		return ret.uid
	else
		uid = uid or self:newId()
		local res = EntityImpl:addUser(self.tbname, uid, row, self.nojson )
		if res then
			self.recordset[uid] = row
		end
		return { res = res, uid = uid, row = row }
	end
end

-- row中包含[self.indexkey]字段,row为k,v形式table
function UserSingleEntity:Delete( uid )
	if not uid or self.recordset[uid] == nil then
		LOG_ERROR("Delete UserSingleEntity,row not [%s] field,%s",self.key,tostring(uid))
		return false
	end

	--实际删除数据
	local ret
	if self.remoteNode then
		ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Delete", uid)
	else
		ret = EntityImpl:delUser( self.tbname, uid )
	end
	if ret then self.recordset[uid] = nil end

	return true
end

-- row中包含[self.indexkey]字段,row为k,v形式table
function UserSingleEntity:Update( uid, row, saveFlag )
	local updateOffline = false
	if not uid then
		assert(false,self.key.." Not Exists")
	end
	if not self.recordset[uid] then
		updateOffline = true
	end

	local ret = true
	local newRecordSet = self.recordset[uid]
	if updateOffline and self.remoteNode then --离线玩家数据更新到DB
		row = EntityImpl:unserializeSproto( self.tbname, EntityImpl:serializeSproto( self.tbname, row, true ) )
		ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Update", uid, row )
	else
		-- 位于DB
		if not self.remoteNode then
			if updateOffline then
				-- DB没数据,加载更新
				newRecordSet = EntityImpl:loadUser( self.tbname, uid )
			end
		end

		for name, value in pairs(row) do
			newRecordSet[name] = value
		end

		if not self.remoteNode then
			ret = EntityImpl:updateUser( self.tbname, uid, newRecordSet, self.nojson )
		end
	end

	--在线仅更新内存,待UnLoad的时候再更新到db
	if ret and not updateOffline then
		self.recordset[uid] = newRecordSet
		if saveFlag then
			-- 立即保存,一般为远程 Save 调用
			ret = EntityImpl:updateUser( self.tbname, uid, newRecordSet, self.nojson )
		else
			self.updateflag[uid] = true
		end
	end

	return ret
end

function UserSingleEntity:Get(uid, field)
	if not uid then return self:GetAll() end
	local record = self.recordset[uid]

	--memory not exist,offline user, load from redis or mysql(mongo) or dbserver
	if not record then
		record = EntityImpl:loadUser( self.tbname, uid, self.remoteNode )
	end
	if record then
		return self:getSingleEntityValue(record, field)
	end
end

function UserSingleEntity:Set(uid, field, value)
	local record = {}
	if type(field) == "table" then
		record = field
	else
		record[field] = value
	end
	return self:Update(uid, record)
end

function UserSingleEntity:NewId( uid )
	return self:newId( uid )
end

function UserSingleEntity:Save( uid, noSave )
	local row = self.recordset[uid]
	if self.remoteNode and self.updateflag[uid] and row then
		--同步到dbNode
		row = EntityImpl:unserializeSproto( self.tbname, EntityImpl:serializeSproto( self.tbname, row, true ) )
		local saveFlag = true
		if noSave then saveFlag = false end
		Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", uid, row, saveFlag)
	end
end