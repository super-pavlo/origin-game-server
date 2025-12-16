--[[
* @file : CommonMultiEntity.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 14:11:47 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 多行 common 类型数据的实现
* Copyright(C) 2017 IGG, All rights reserved
]]

require "Entity"
local EntityImpl = require "EntityImpl"

-- CommonMultiEntity
CommonMultiEntity = class(Entity)

function CommonMultiEntity:ctor()
end

function CommonMultiEntity:Init()
    local ret = assert(EntityImpl:getEntityCfg(Enum.TableType.COMMON, self.tbname))
    self.key = ret.key
    self.value = ret.value
    self.attr = ret.attr
    self.mainIndex = ret.mainIndex
    self.db = ret.db
    self.center = ret.center
    self.commTable = true
    self.nojson = ret.nojson
    self.alljson = ret.alljson
    self:initRemoteNode()
end

function CommonMultiEntity:dtor()
end

-- 加载整张表数据
function CommonMultiEntity:Load()
    if self.remoteNode then return end
    local rs = EntityImpl:loadCommon( self.tbname, nil, self.remoteNode )
    if rs then
        if not self.recordset then self.recordset = {} end
        for pid, decodeRow in pairs(rs) do
            self.recordset[pid] = decodeRow[self.attr] or decodeRow     -- 更新内存
        end
    end
end

-- 卸载整张表数据
function CommonMultiEntity:UnLoad()
    self.recordset = {}
end

--row为k,v形式table, row.id自动生成
function CommonMultiEntity:Add( pid, indexId, row )
    if self.remoteNode then
        --同步到remoteNode
        local ret = Common.rpcCall(self.remoteNode, self.tbname, "Add", pid, indexId, row)
        if ret == indexId then
            return indexId
        end
    else
        if pid and self.recordset[pid] and self.recordset[pid][indexId] then return end -- 记录已经存在，返回
        -- at self node
        if not self.recordset[pid] then
            -- add
            self.recordset[pid] = {}
            self.recordset[pid][indexId] = row
            EntityImpl:addCommon( self.tbname, pid, { [self.attr] = self.recordset[pid] }, self.nojson, self.alljson )
        else
            -- update
            assert( self.recordset[pid][indexId] == nil )
            self.recordset[pid][indexId] = row
            EntityImpl:updateCommon( self.tbname, pid, { [self.attr] = self.recordset[pid] }, self.nojson, self.alljson )
        end
        return indexId
    end
end

-- row中包含pk字段,row为k,v形式table
-- 从内存中删除，并同步到redis
function CommonMultiEntity:Delete( pid, indexId )
    if not pid then
		LOG_ERROR("Delete RoleMultiEntity,row not [%s] field,%s",self.key,tostring(pid))
		return false
    end

    -- 实际删除数据
    if self.remoteNode then
        return Common.rpcCall( self.remoteNode, self.tbname, "Delete", pid, indexId )
    else
        local delAll = true
        if indexId and self.recordset[pid] then -- 仅删除某个子项
            if not self.recordset[pid][indexId] then
                return false
            end
            self.recordset[pid][indexId] = nil
            delAll = false
        end
        assert(self.recordset[pid])
        local ret
        if delAll then
            ret = EntityImpl:delCommon( self.tbname, pid )
        else
            ret = EntityImpl:updateCommon( self.tbname, pid, { [self.attr] = self.recordset[pid] }, self.nojson, self.alljson )
        end
        if ret and delAll then
            self.recordset[pid] = nil
        end
        return true
    end
end

function CommonMultiEntity:Update(pid, indexId, row)
    local ret
    if self.remoteNode then
        if not row[self.mainIndex] then row[self.mainIndex] = indexId end
		row = EntityImpl:unserializeSproto( self.tbname,
                EntityImpl:serializeSproto( self.tbname, { [self.attr] = { [indexId] = row } }, true ) )[self.attr][indexId]
        return Common.rpcCall( self.remoteNode, self.tbname, "Update", pid, indexId, row )
    else
        local updateRecordSet = self.recordset[pid]
        if not updateRecordSet[indexId] then
            LOG_WARNING("tbname(%s) update pid(%s) indexId(%s) not exits", self.tbname, tostring(pid), tostring(indexId))
            return
        else
            for name, value in pairs(row) do
                if not updateRecordSet[indexId][name] then
                    LOG_WARNING("%s Update key(%s) subkey(%s) set new not found field(%s)", self.tbname, tostring(pid), tostring(indexId), name)
                end
                updateRecordSet[indexId][name] = value
            end
        end
        -- 更新
        ret = EntityImpl:updateCommon( self.tbname, pid, { [self.attr] = updateRecordSet }, self.nojson, self.alljson )
        -- 更新内存self.recordset
        if ret then
            self.recordset[pid] = updateRecordSet
        end
        return true
    end
end

function CommonMultiEntity:Get(pid, indexId, field)
    if not pid then return self:GetAll() end
    local record = self.recordset[pid]
    if not record then
        if not self.remoteNode then
            record = EntityImpl:loadCommon( self.tbname, pid )
            if record and record[self.attr] then record = record[self.attr] end
        else
            return Common.rpcCall( self.remoteNode, self.tbname, "Get", pid, indexId, field )
        end
    end

    if record then
        return self:getMultiEntityValue( record, indexId, field )
    end
end

function CommonMultiEntity:Set(pid, indexId, field, value)
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
	return self:Update(pid, indexId, record)
end
