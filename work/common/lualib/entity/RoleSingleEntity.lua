--[[
* @file : RoleSingleEntity.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 09:26:59 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 单行 role 数据表的实现
* Copyright(C) 2017 IGG, All rights reserved
]]

require "Entity"
local EntityImpl = require "EntityImpl"
-- 定义RoleSingleEntity类型
RoleSingleEntity = class(Entity)

-- 缓存的Timer
local cacheTimer
local Timer = require "Timer"

function RoleSingleEntity:Init()
	local ret = assert(EntityImpl:getEntityCfg( Enum.TableType.ROLE, self.tbname ))
	self.key = ret.key
	self.value = ret.value
	self.db = ret.db
	self.center = ret.center
	self.nojson = ret.nojson
	self.alljson = ret.alljson
	self.online = {}
	self.offlineCacheTimer = {} -- only in local
	self:initRemoteNode()
end

---@see 定时尝试保存数据到remoteNode
function RoleSingleEntity:CacheSave()
	if table.empty(self.cache) then return end
	if self:CheckRemoteNodeAlive() then
		local result
		local now = os.time()
		for rid, cacheData in pairs(self.cache) do
			if cacheData.expireTime > now then
				result = Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", rid, cacheData.row)
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
function RoleSingleEntity:Load( rid )
	if self.cache[rid] then -- 优先写入缓存的数据(这里一般是remote在角色Unload时不存在)
		local result = Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", rid, self.cache[rid].row)
		if result.ret == true then
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

	local row = EntityImpl:loadRole( self.tbname, rid, self.remoteNode )
	if row and not table.empty(row) then
		self.recordset[rid] = row
	end

	self.online[rid] = true

	if not self.remoteNode and self.recordset[rid] then
		-- 位于 db
		return self.recordset[rid]
	end
end

---@see 全部卸载
function RoleSingleEntity:UnLoadAll()
	for rid in pairs(self.recordset) do
		self:UnLoad( rid )
	end

	self.recordset = {}
	self.updateflag = {}
end

---@see 卸载角色数据
---@param rid integer 角色rid
function RoleSingleEntity:UnLoad( rid, isOfflineTimerTrigger )
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
			-- 利用序列化过滤不落地的数据
			row = EntityImpl:unserializeSproto( self.tbname, EntityImpl:serializeSproto( self.tbname, row, true ) )
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
					Common.rpcMultiCall(self.remoteNode, self.tbname, "Update", rid, row)
				end
				-- 通知DB卸载
				Common.rpcMultiCall(self.remoteNode, self.tbname, "UnLoad", rid)
			end
		else
			if self.updateflag[rid] then
				EntityImpl:updateRole( self.tbname, rid, row, self.nojson, self.alljson )
			end
			--删除redis
			EntityImpl:delRedisImpl( self.tbname, rid )
		end

		self.recordset[rid] = nil
		self.updateflag[rid] = nil
		self.online[rid] = nil
		self.offlineCacheTimer[rid] = nil
		collectgarbage()
	end
end

---@see 添加数据
---@param rid integer 角色rid
---@param row table 角色数据
function RoleSingleEntity:Add( rid, row )
	local online = self.online[rid]
	rid = rid or row[self.key]
	if rid and self.recordset[rid] then
		LOG_ERROR("Add RoleSingleEntity Error,Exists,%s",tostring(row))
		return false --记录已经存在，返回
	end

	if self.remoteNode then
		--同步到remoteNode
		local ret = Common.rpcMultiCall(self.remoteNode, self.tbname, "Add", rid, row )
		if ret.res and online then
			self.recordset[ret.rid] = ret.row
		end
		return ret.rid
	else
		rid = rid or self:newId()
		local res = EntityImpl:addRole( self.tbname, rid, row, self.nojson, self.alljson )
		if res and online then
			self.recordset[rid] = row
		end

		return { res = res, rid = rid, row = row }
	end
end

---@see 删除数据
---@param rid integer 角色rid
function RoleSingleEntity:Delete( rid )
	if not rid then
		LOG_ERROR("Delete RoleSingleEntity,row not [%s] field,%s",self.key,tostring(rid))
		return false
	end

	--实际删除数据
	local ret
	if self.remoteNode then
		ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Delete", rid)
	else
		ret = EntityImpl:delRole( self.tbname, rid )
	end
	if ret then
		self.recordset[rid] = nil
	end

	return ret
end

---@see 更新数据
---@param rid integer 角色rid
---@param row table 角色数据
---@param lockFlag boolean 锁定更新标记
---@param saveFlag boolean 立即保存标记
function RoleSingleEntity:Update( rid, row, lockFlag, saveFlag )
	if row.rid and row.rid ~= rid then assert(false,rid .. "," .. tostring(row.rid)) end
	assert( not lockFlag or table.size(row) == 1 )
	if not rid then
		assert(false,self.key.." Not Exists")
	end
	local online = self.online[rid]

	local ret = true
	local newRecordSet = self.recordset[rid]
	local lockValue, oldValue
	if not online then --离线玩家数据更新到DB
		if self.remoteNode then
			-- 利用序列化过滤不落地的数据
			row = EntityImpl:unserializeSproto( self.tbname, EntityImpl:serializeSproto( self.tbname, row, true ) )
			ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Update", rid, row, lockFlag )
			lockValue = ret.lockValue
			oldValue = ret.oldValue
			ret = ret.ret
		else
			-- DB没数据,加载更新
			newRecordSet = EntityImpl:loadRole( self.tbname, rid )
		end
	end

	if newRecordSet then
		for name, value in pairs(row) do
			if lockFlag then
				oldValue = newRecordSet[name]
				newRecordSet[name] = newRecordSet[name] + value
				lockValue = newRecordSet[name]
				if Common.isNumber(lockValue) and lockValue < 0 then
					lockValue = 0
				end
			else
				newRecordSet[name] = value
			end
		end
	end

	if not self.remoteNode and not online then
		-- 位于DB,而且是离线数据,直接更新
		if newRecordSet then
			ret = EntityImpl:updateRole( self.tbname, rid, newRecordSet, self.nojson, self.alljson )
		end
	elseif ret and online then
		--在线仅更新内存,待UnLoad的时候再更新到db
		self.recordset[rid] = newRecordSet
		if saveFlag then
			-- 立即保存,一般为远程 Save 调用
			if self.remoteNode then
				ret = Common.rpcMultiCall( self.remoteNode, self.tbname, "Update", rid, newRecordSet )
			else
				ret = EntityImpl:updateRole( self.tbname, rid, newRecordSet, self.nojson, self.alljson )
			end
		else
			self.updateflag[rid] = true
		end
	end

	if self.remoteNode then
		-- 非DB中
		return ret, lockValue, oldValue
	else
		-- DB中
		return { ret = ret, lockValue = lockValue, oldValue = oldValue }
	end
end

---@see 获取角色数据
---@param rid integer 角色rid
---@param field any 数据字段
function RoleSingleEntity:Get( rid, field )
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
		return self:getSingleEntityValue(self.recordset[rid], field)
	end
end

---@see 设置角色数据
---@param rid integer 角色rid
---@param field any 数据字段
---@param value any 数据内容
---@param lockFlag booealn 锁定标记
function RoleSingleEntity:Set( rid, field, value, lockFlag )
	local record = {}
	if type(field) == "table" then
		record = field
	else
		record[field] = value
	end

	return self:Update( rid, record, lockFlag )
end

---@see 新建一个id
function RoleSingleEntity:NewId()
	return self:newId()
end

---@see 保存角色数据
function RoleSingleEntity:Save( rid, noSave )
	local row = self.recordset[rid]
	if self.remoteNode and self.updateflag[rid] and row then
		-- 同步到dbNode
		-- 利用序列化过滤不落地的数据
		row = EntityImpl:unserializeSproto( self.tbname, EntityImpl:serializeSproto( self.tbname, row, true ) )
		local saveFlag = true
		if noSave then saveFlag = false end
		Common.rpcMultiCall( self.remoteNode, self.tbname, "Update", rid, row, false, saveFlag )
		self.updateflag[rid] = nil
	end
end