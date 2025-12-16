--[[
* @file : RoleMultiEntity.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 09:29:39 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 多行 role 类型数据表的实现
* Copyright(C) 2017 IGG, All rights reserved
]]

require "Entity"
local EntityImpl = require "EntityImpl"
-- 定义RoleMultiEntity类型
RoleMultiEntity = class(Entity)

-- 缓存的Timer
local cacheTimer
local Timer = require "Timer"

function RoleMultiEntity:Init()
	local ret = assert(EntityImpl:getEntityCfg( Enum.TableType.ROLE, self.tbname ), self.tbname)
	self.key = ret.key
	self.value = ret.value
	self.attr = ret.attr
	self.mainIndex = ret.mainIndex
	self.db = ret.db
	self.center = ret.center
	self:initRemoteNode()
	self.online = {}
	self.nojson = ret.nojson
	self.alljson = ret.alljson
	self.offlineCacheTimer = {} -- only in local
end

---@see 定时尝试保存数据到remoteNode
function RoleMultiEntity:CacheSave()
	if table.empty(self.cache) then return end
	if self:CheckRemoteNodeAlive() then
		local result
		local now = os.time()
		for rid, cacheData in pairs(self.cache) do
			if cacheData.expireTime > now then
				result = Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", rid, nil, cacheData.row, true)
				if result.ret == true then
					self.cache[rid] = nil
				else
					break
				end
			else
				self.cache[rid] = nil
			end
		end
	end
end

---@see 加载角色数据
---@param rid integer 角色rid
function RoleMultiEntity:Load( rid )
	if self.cache[rid] then -- 优先写入缓存的数据(这里一般是remote在角色Unload时不存在)
		local result = Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", rid, nil, self.cache[rid].row, true)
		if result == true then
			self.cache[rid] = nil
		else
			assert(false)
		end
	end

	if self.offlineCacheTimer[rid] then
		Timer.delete( self.offlineCacheTimer[rid] )
		self.offlineCacheTimer[rid] = nil
		-- unload first
		self:UnLoad( rid )
	end

	local row = EntityImpl:loadRole(self.tbname, rid, self.remoteNode)
	if row and not table.empty(row) then
		self.recordset[rid] = row[self.attr] or row
	end

	self.online[rid] = true

	if not self.remoteNode and self.recordset[rid] then return self.recordset[rid] end
end

---@see 全部卸载
function RoleMultiEntity:UnLoadAll()
	for rid,_ in pairs(self.recordset) do
		self:UnLoad( rid )
	end

	self.recordset = {}
	self.updateflag = {}
end

---@see 卸载角色数据
---@param rid integer 角色rid
function RoleMultiEntity:UnLoad( rid, isOfflineTimerTrigger )
	if rid == nil then
		self:UnLoadAll()
		return
	end
	if isOfflineTimerTrigger and not self.offlineCacheTimer[rid] then
		-- 角色已经真正在线,不再卸载
		return
	end
	local row = self.recordset[rid]
	if row then
		if self.remoteNode then
			row = EntityImpl:unserializeSproto( self.tbname,
								EntityImpl:serializeSproto( self.tbname, { [self.attr] = row }, true ) )[self.attr]
			--同步到dbNode
			if not self:CheckRemoteNodeAlive() then
				if not cacheTimer then
					cacheTimer = Timer.runEvery(10 * 100, self.CacheSave, self)
				end
				-- 远程不存在了,缓存数据(最多缓存30分钟)
				self.cache[rid] = { row = row, expireTime = os.time() + 1800 }
				LOG_ERROR("rid(%d) tbName(%s) UnLoad, but remoteNode(%s) offline, save to cache for max 30 min",
																			rid, self.tbname, self.remoteNode)
			else
				if self.updateflag[rid] then
					Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", rid, nil, row, true)
				end
				Common.rpcMultiCall(self.remoteNode, self.tbname, "UnLoad", rid)
			end
		else
			if self.updateflag[rid] then
				EntityImpl:updateRole( self.tbname, rid, { [self.attr] = row }, self.nojson, self.alljson )
			end
			--删除redis
			EntityImpl:delRedisImpl( self.tbname, rid )
		end

		self.recordset[rid] = nil
		self.updateflag[rid] = nil
		self.offlineCacheTimer[rid] = nil
		collectgarbage()
	end

	self.online[rid] = nil
end

---@see 添加数据
---@param rid integer 角色rid
---@param indexId integer 数据索引
---@param row table 角色数据
function RoleMultiEntity:Add( rid, indexId, row )
	-- 在线且不存在记录的时候,才插入
	if not self.recordset[rid] then
		local online = self.online[rid]
		if self.remoteNode then
			--同步到remoteNode
			local ret = Common.rpcMultiCall(self.remoteNode, self.tbname, "Add", rid, indexId, row)
			if ret == indexId and online then
				if not self.recordset[rid] then self.recordset[rid] = {} end
				self.recordset[rid][indexId] = row
				-- 在线得时候更新标记
				if online then
					self.updateflag[rid] = true
				end
			end
		else
			-- at remote node
			if online then
				-- 在线,又没数据,直接插入
				if not self.recordset[rid] then self.recordset[rid] = {} end
				self.recordset[rid][indexId] = row
				EntityImpl:addRole( self.tbname, rid, { [self.attr] = {} }, self.nojson, self.alljson )
				self.updateflag[rid] = true
			else
				-- 离线,先加载数据
				local record = EntityImpl:loadRole( self.tbname, rid )
				if record and not table.empty(record) then
					-- 有数据,应该是update
					assert(record[indexId] == nil)
					record[self.attr][indexId] = row
					EntityImpl:updateRole( self.tbname, rid, record, self.nojson, self.alljson )
				else
					-- 没数据,直接插入
					EntityImpl:addRole( self.tbname, rid, { [self.attr] = { [indexId] = row } }, self.nojson, self.alljson )
				end
			end
		end
	else
		-- 有记录存在,仅更新内存(一定是在线的)
		if not self.recordset[rid] then self.recordset[rid] = {} end
		self.recordset[rid][indexId] = row
		self.updateflag[rid] = true
	end

	return indexId
end

---@see 删除数据
---@param rid integer 角色rid
---@param indexId integer 数据索引
function RoleMultiEntity:Delete( rid, indexId )
	if not rid then
		LOG_ERROR("Delete RoleMultiEntity,row not [%s] field,%s",self.key,tostring(rid))
		return false
	end

	-- 离线数据,直接通知 db
	if not self.recordset[rid] then
		if self.remoteNode then
			return Common.rpcMultiCall( self.remoteNode, self.tbname, "Delete", rid, indexId )
		else
			-- 位于 db
			if indexId then
				local record = EntityImpl:loadRole( self.tbname, rid, self.remoteNode )
				if record then
					record = record[self.attr] or record
					record[indexId] = nil
					EntityImpl:updateRole( self.tbname, rid, { [self.attr] = record }, self.nojson, self.alljson )
				end
			else
				-- 全部删除
				EntityImpl:delRole( self.tbname, rid )
			end
		end
		return
	end

	-- 在线
	local delAll = true
	if indexId then --仅删除某个子项
		self.recordset[rid][indexId] = nil
		self.updateflag[rid] = true
		delAll = false
	end

	if delAll then
		--实际删除数据
		local ret
		if self.remoteNode then
			ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Delete", rid )
		else
			ret = EntityImpl:delRole( self.tbname, rid )
		end
		if ret then self.recordset[rid] = nil end
	end

	return true
end

---@see 更新数据
---@param rid integer 角色rid
---@param indexId integer 数据索引
---@param row table 角色数据
---@param saveFlag boolean 立即保存标记
function RoleMultiEntity:Update( rid, indexId, row, saveFlag )
	if not saveFlag and ( not rid or not indexId ) then
		LOG_ERROR("RoleMultiEntity Update, tbname(%s) rid(%s) or indexId(%s) is null", self.tbname, tostring(rid), tostring(indexId))
		return
	end
	local ret = true
	local newRecordSet = self.recordset[rid]
	local online = self.online[rid]
	if not online then --离线角色
		if self.remoteNode then -- 请求到DB更新
			if not row[self.mainIndex] then row[self.mainIndex] = indexId end
			row = EntityImpl:unserializeSproto( self.tbname,
					EntityImpl:serializeSproto( self.tbname, { [self.attr] = { [indexId] = row } }, true ) )[self.attr][indexId]
			ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Update", rid, indexId, row )
		else
			-- DB没数据,加载更新
			newRecordSet = EntityImpl:loadRole( self.tbname, rid )[self.attr]
		end
	end

	-- 更新 newRecordSet 数据
	if newRecordSet then
		if indexId then
			if not newRecordSet[indexId] then
				LOG_WARNING("%s,%d,%s,row:%s", self.tbname, indexId, tostring(newRecordSet), tostring(row))
				return
			end
			if row[self.mainIndex] then
				assert( row[self.mainIndex] == indexId, string.format( "%s,%d,%d,%s", self.tbname, rid, indexId, tostring(row) ) )
			end
			for name,value in pairs(row) do
				newRecordSet[indexId][name] = value
			end
		else
			-- 覆盖更新(其他 server UnLoad 发送过来)
			newRecordSet = row
		end
	end

	if not self.remoteNode and not online then
		-- 位于DB,而且是离线数据,直接更新
		ret = EntityImpl:updateRole( self.tbname, rid, { [self.attr] = newRecordSet }, self.nojson, self.alljson )
	elseif ret and online then
		-- 在线仅更新内存,待UnLoad的时候再更新到db
		if saveFlag then
			-- 立即保存,一般为远程 Save 调用
			if self.remoteNode then
				ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Update", rid, indexId, newRecordSet )
			else
				ret = EntityImpl:updateRole( self.tbname, rid, { [self.attr] = newRecordSet }, self.nojson, self.alljson )
			end
		else
			self.updateflag[rid] = true
		end
		self.recordset[rid] = newRecordSet
	end

	return ret
end

---@see 获取角色数据
---@param rid integer 角色rid
---@param indexId integer 数据索引
---@param field any 数据字段
function RoleMultiEntity:Get( rid, indexId, field )
	if not rid then return self:GetAll() end
	--memory not exist, offline Role, load from redis or mysql(mongo)
	if not self.recordset[rid] then
		self:Load( rid )
		if self.recordset[rid] then
			-- offline cache success
			self.offlineCacheTimer[rid] = Timer.runAfter( 300 * 100, function ()
				self:lock(rid)( self.UnLoad, self, rid, true )
			end )
		end
	end

	if self.recordset[rid] then
		return self:getMultiEntityValue(self.recordset[rid], indexId, field)
	end

	if not field then return {} end
end

---@see 设置角色数据
---@param rid integer 角色rid
---@param indexId integer 数据索引
---@param field any 数据字段
---@param value any 数据内容
function RoleMultiEntity:Set( rid, indexId, field, value )
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
	return self:Update( rid, indexId, record )
end

---@see 新建一个id
function RoleMultiEntity:NewId()
	return self:newId()
end

---@see 保存角色数据
function RoleMultiEntity:Save( rid, noSave )
	local row = self.recordset[rid]
	if self.remoteNode and self.updateflag[rid] and row then
		--同步到dbNode
		row = EntityImpl:unserializeSproto( self.tbname,
								EntityImpl:serializeSproto( self.tbname, { [self.attr] = row }, true ) )[self.attr]
		local saveFlag = true
		if noSave then saveFlag = false end
		Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", rid, nil, row, saveFlag)
		self.updateflag[rid] = nil
	end
end