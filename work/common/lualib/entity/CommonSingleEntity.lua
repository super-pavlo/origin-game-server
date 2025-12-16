--[[
* @file : CommonSingleEntity.lua
* @type : lualib
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 单行 common 类型数据的实现
* Copyright(C) 2017 IGG, All rights reserved
]]

require "Entity"
local EntityImpl = require "EntityImpl"

-- CommonSingleEntity
CommonSingleEntity = class(Entity)

function CommonSingleEntity:ctor()
end

function CommonSingleEntity:Init()
    local ret = assert(EntityImpl:getEntityCfg(Enum.TableType.COMMON, self.tbname), self.tbname)
    self.key = ret.key
    self.value = ret.value
    self.db = ret.db
    self.center = ret.center
    self.commTable = true
    self.nojson = ret.nojson
    self.alljson = ret.alljson
    self:initRemoteNode()
end

function CommonSingleEntity:dtor()

end

-- 加载整张表数据
function CommonSingleEntity:Load()
    if self.remoteNode then return end
    local rs = EntityImpl:loadCommon( self.tbname, nil, self.remoteNode )
    if rs then
        self.recordset = rs --更新内存
    end
end

-- 卸载整张表数据
function CommonSingleEntity:UnLoad()
    self.recordset = {}
end

--row为k,v形式table, row.id自动生成
function CommonSingleEntity:Add( pid, row )
    pid = pid or row[self.key]
    if pid and self.recordset[pid] then
        LOG_ERROR("CommonSingleEntity tbname(%s) Add exist pid(%s)", self.tbname, tostring(pid))
        return
    end -- 记录已经存在，返回
    if self.remoteNode then
		--同步到remoteNode
        local ret = Common.rpcCall(self.remoteNode, self.tbname, "Add", pid, row )
        if ret then
            return ret.pid
        end
	else
        if not pid then
            pid = self:newId()
            row[self.key] = pid
        end
        local res = EntityImpl:addCommon( self.tbname, pid, row, self.nojson, self.alljson )
        if res then
            self.recordset[pid] = row
        end
        return { res = res, pid = pid, row = row }
    end
end

-- row中包含pk字段,row为k,v形式table
-- 从内存中删除，并同步到redis
function CommonSingleEntity:Delete( pid )
    if not pid or ( not self.remoteNode and self.recordset[pid] == nil ) then
		LOG_ERROR("Delete CommonSingleEntity(%s),row not [%s] field,%s", self.tbname, self.key, tostring(pid))
		return false
	end

	--实际删除数据
	local ret
	if self.remoteNode then
		ret = Common.rpcCall( self.remoteNode, self.tbname, "Delete", pid)
	else
        ret = EntityImpl:delCommon( self.tbname, pid )
        if ret then
            self.recordset[pid] = nil
        end
	end

    return ret
end

---@see 删除全部数据
function CommonSingleEntity:DeleteAll()
    local ret
	if self.remoteNode then
		ret = Common.rpcCall( self.remoteNode, self.tbname, "DeleteAll", 0)
	else
        ret = EntityImpl:delCommon( self.tbname )
        if ret then
            self.recordset = {}
        end
	end

    return ret
end


-- row中包含pk字段,row为k,v形式table
function CommonSingleEntity:Update(pid, row, lockFlag)
    if not self.recordset[pid] and not self.remoteNode then
        return --记录不存在，返回
    end

    local ret, lockValue, oldValue
    if self.remoteNode then
        -- 更新到 remoteNode
        -- 利用序列化过滤不落地的数据
        row = EntityImpl:unserializeSproto( self.tbname, EntityImpl:serializeSproto( self.tbname, row, true ) )
        ret = Common.rpcCall( self.remoteNode, self.tbname, "Update", pid, row, lockFlag )
    else
        local updateRecordSet = self.recordset[pid]
        if lockFlag then
            for name, value in pairs(row) do
                if not updateRecordSet[name] then
                    LOG_WARNING("%s Update key(%s) set new not found field(%s)", self.tbname, tostring(pid), name)
                end
                oldValue = updateRecordSet[name]
                updateRecordSet[name] = updateRecordSet[name] + value
                lockValue = updateRecordSet[name]
            end
        else
            for name, value in pairs(row) do
                if not updateRecordSet[name] then
                    LOG_WARNING("%s Update key(%s) set new not found field(%s)", self.tbname, tostring(pid), name)
                end
                updateRecordSet[name] = value
            end
        end
        --更新,并更新内存self.recordset
        ret = EntityImpl:updateCommon( self.tbname, pid, updateRecordSet, self.nojson, self.alljson )
        -- 更新内存
        if ret then
            self.recordset[pid] = updateRecordSet
        end
    end

    if self.remoteNode and ret then
        return ret.result, ret.lockValue, ret.oldValue
    else
        return { result = ret, lockValue = lockValue, oldValue = oldValue }
    end
end

function CommonSingleEntity:Get( pid, field )
    local record
    if pid and self.recordset[pid] then
        record = self.recordset[pid]
    elseif not pid and not table.empty(self.recordset) then
        record = self.recordset
    end

    if not record then
        if not self.remoteNode then
            record = EntityImpl:loadCommon( self.tbname, pid )
        else
            return Common.rpcCall( self.remoteNode, self.tbname, "Get", pid, field )
        end
    end

    if record then
        return self:getSingleEntityValue( record, field )
    end
end

function CommonSingleEntity:Set(pid, field, value, lockFlag)
    local record = {}
	if type(field) == "table" then
		record = field
	else
		record[field] = value
	end

    return self:Update(pid, record, lockFlag)
end

function CommonSingleEntity:NewId()
	return self:newId()
end