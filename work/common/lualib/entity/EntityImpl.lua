--[[
* @file : EntityImpl.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 14:13:21 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 数据管理的统一实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local crypt = require "skynet.crypt"
local cjson = require "cjson.safe"
local string = string
local table = table
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local sharedata = require "skynet.sharedata"
local MergeProtocol = require "MergeProtocol"
local EntityImpl = {}
local cjsonSparseArray

function EntityImpl:serializeSproto( _tbName, _data, _nojson, _alljson )
	local encodeData,jsonData
	local sp = self:getSprotoShare()
	table.tointeger(_data) -- filter number, trans to integer
	encodeData = crypt.base64encode(sp:pencode(_tbName, _data))
	if not Enum.DebugMode then
		-- release不写入json
		_nojson = true
	end
	if _alljson then
		_nojson = false
	end

	if not _nojson then
		if not cjsonSparseArray then
			cjson.encode_sparse_array(true)
			cjsonSparseArray = true
		end
		local value = sp:pdecode(_tbName, crypt.base64decode(encodeData))
		jsonData = cjson.encode( value )
		jsonData = jsonData:gsub("\'","")
		jsonData = jsonData:gsub("\\","")
	else
		jsonData = cjson.encode( {} )
		jsonData = jsonData:gsub("\'","")
		jsonData = jsonData:gsub("\\","")
	end
	return encodeData,jsonData
end

function EntityImpl:unserializeSproto( _tbName, _data )
	local sp = self:getSprotoShare()
	return sp:pdecode(_tbName, crypt.base64decode(_data))
end

function EntityImpl:makeInsertFormat( value )
	local valueType = type(value)
	if valueType == "string" then
		return "insert into %s values(\"%s\", \"%s\", '%s')"
	elseif valueType == "number" then
		return "insert into %s values(%d, \"%s\", '%s')"
	else
		assert(false, "invalid type(" .. valueType .. ") for makeInsertFormat")
	end
end

function EntityImpl:makeUpdateFormat( value )
	local valueType = type(value)
	if valueType == "string" then
		return "update %s set %s = \"%s\", json = '%s' where %s = \"%s\""
	elseif valueType == "number" then
		return "update %s set %s = \"%s\", json = '%s' where %s =  %d"
	else
		assert(false, "invalid type(" .. valueType .. ") for makeUpdateFormat")
	end
end

function EntityImpl:makeSelectFormat( value )
	local valueType = type(value)
	if valueType == "string" then
		return "select * from %s where %s = \"%s\""
	elseif valueType == "number" then
		return "select * from %s where %s = %d"
	else
		assert(false, "invalid type(" .. valueType .. ") for makeSelectFormat")
	end
end

function EntityImpl:makeDeleteFormat( value )
	local valueType = type(value)
	if valueType == "string" then
		return "delete from %s where %s = \"%s\""
	elseif valueType == "number" then
		return "delete from %s where %s = %d"
	elseif valueType == "nil" then
		return "delete from %s"
	else
		assert(false, "invalid type(" .. valueType .. ") for makeDeleteFormat")
	end
end

function EntityImpl:loadCommonMysqlImpl( tbname, beginIndex, limit )
	local ret = {}
	local index = beginIndex or 0
	local index_limit = limit or 2000
	local cmd

	local commonEntity = self:getEntityCfg(Enum.TableType.COMMON, tbname)
	while true do
		cmd = string.format("select * from %s limit %d,%d",commonEntity.name, index, index_limit)
		local sqlRet = Common.mysqlExecute(cmd)
		if #sqlRet <= 0 then break end

		for _,row in pairs(sqlRet) do
			--sproto extract
			assert(table.size(row) >= 2, "mysql table("..commonEntity.name..") schema must be key-value")
			local decodeRow = self:unserializeSproto(tbname, row[commonEntity.value])

			--set to memory
			ret[row[commonEntity.key]] = decodeRow
		end

		if #sqlRet < index_limit or beginIndex then break end
		index = index + index_limit
	end
	return ret
end

function EntityImpl:loadCommonMongoImpl()
	assert(false,"not impl loadCommonMongoImpl")
end

function EntityImpl:loadCommonSingleMysqlImpl( tbname, pid )
	local commonEntity = self:getEntityCfg(Enum.TableType.COMMON, tbname)
	local cmd = string.format(self:makeSelectFormat(pid),
															commonEntity.name,
															commonEntity.key,
															pid
							)
	local sqlRet = Common.mysqlExecute(cmd)
	if #sqlRet <= 0 then return end
	sqlRet = sqlRet[1]
	--sproto extract
	assert(table.size(sqlRet) >= 2, "mysql table("..commonEntity.name..") schema must be key-value")
	return self:unserializeSproto(tbname, sqlRet[commonEntity.value])
end

function EntityImpl:loadCommonSingleMongoImpl()
	assert(false,"not impl loadCommonSingleMongoImpl")
end

function EntityImpl:getRedisImpl( tbname, pid )
	local redisRet = Common.redisExecute( { "hget", tbname, pid }, pid)
	if redisRet then
		return self:unserializeSproto(tbname, redisRet)
	end

	return nil --not data in redis, or expried, must reload from db(mysql or mongo)
end

function EntityImpl:addRedisImpl( tbname, pid, row, _nojson )
	local redisDecodeRow = self:serializeSproto(tbname, row, true)
	--set to redis
	Common.redisExecute( { "hset", tbname, pid, redisDecodeRow }, pid) --default to first redis instance
end

function EntityImpl:delRedisImpl( tbname, pid )
	Common.redisExecute( { "hdel", tbname, pid }, pid)
end

function EntityImpl:loadMysqlImpl( _tbName, _pid, _tbType )
	local objEntity = self:getEntityCfg(_tbType, _tbName)
	local cmd = string.format("select * from %s where %s = %d",
														objEntity.name,
														objEntity.key,
														_pid
						)
	local sqlRet = Common.mysqlExecute(cmd)
	if #sqlRet <= 0 then return end
	assert(#sqlRet == 1)
	sqlRet = sqlRet[1]
	-- sproto extract
	assert(table.size(sqlRet) >= 2, "mysql table("..objEntity.name..") schema must be key-value")
	local decodeRow = self:unserializeSproto(_tbName, sqlRet[objEntity.value])
	-- add to redis
	self:addRedisImpl( objEntity.name, _pid, decodeRow )
	-- set to mem
	return decodeRow
end

function EntityImpl:loadMongoImpl()
	assert(false,"not impl loadMongoImpl")
end

function EntityImpl:loadConfig( tbname )
	-- 从 Config 文件读取数据
	return SM.ReadConfig.req.getConfig( tbname )
end

function EntityImpl:loadCommon( tbname, pid, remoteNode )
	if remoteNode then
		local skynet = require "skynet"
		--默认DEFUALT_SNAX_SERVICE_NUM个子服务
		local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
		return Common.rpcCall(remoteNode, tbname .. ( pid % multiSnaxNum + 1 ), "Load", pid)
	else
		-- 从 db 获取 common 数据
		if Enum.G_DBTYPE == Enum.DbType.MYSQL then
			if pid then
				return self:loadCommonSingleMysqlImpl( tbname, pid )
			else
				return self:loadCommonMysqlImpl( tbname )
			end
		elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
			if pid then
				return self:loadCommonSingleMongoImpl( tbname, pid )
			else
				return self:loadCommonMongoImpl( tbname )
			end
		else
			assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
		end
	end
end

function EntityImpl:loadUser( tbname, pid, remoteNode )
	if remoteNode then
		local skynet = require "skynet"
		--默认DEFUALT_SNAX_SERVICE_NUM个子服务
		local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
		return Common.rpcCall(remoteNode, tbname .. ( pid % multiSnaxNum + 1 ), "Load", pid)
	else
		--尝试从redis获取数据
		local ret = self:getRedisImpl(tbname, pid)
		if not ret then
			--从db获取user数据
			if Enum.G_DBTYPE == Enum.DbType.MYSQL then
				return self:loadMysqlImpl(tbname, pid, Enum.TableType.USER)
			elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
				return self:loadMongoImpl(tbname, pid, Enum.TableType.USER)
			else
				assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
			end
		end

		return ret
	end
end

function EntityImpl:updateCommonMysql( tbname, pid, updateData, nojson, alljson )
	assert(type(updateData) == "table")
	local obj = self:getEntityCfg(Enum.TableType.COMMON, tbname)
	local encodeData, jsonData = self:serializeSproto(tbname, updateData, nojson, alljson)
	local sql
	sql = string.format(self:makeUpdateFormat(pid),obj.name,obj.value,encodeData,jsonData, obj.key,pid)

	--update obj.name by updateData's index to mysql
	local ret = Common.mysqlExecute(sql, tonumber(pid) or 0)
	--check ret
	if ret.badresult then
		LOG_DB( "updateCommon err:%s, sql:%s", ret.badresult, sql)
	end

	return ret
end

function EntityImpl:updateCommonMongo()
	assert(false,"not impl updateCommonMongo")
end

function EntityImpl:updateMysqlImpl( tbname, pid, updateData, tbtype, nojson, alljson )
	assert(type(updateData) == "table", tostring(updateData))
	local obj = self:getEntityCfg(tbtype, tbname)
	--mysql
	local sqlCmd
	local encodeData, jsonData = self:serializeSproto(tbname, updateData, nojson, alljson)
	sqlCmd = string.format(self:makeUpdateFormat(pid),obj.name,obj.value,encodeData,jsonData,obj.key,pid)

	--update to redis first with redis pipeline
	self:delRedisImpl(obj.name, pid)
	self:addRedisImpl(obj.name, pid, updateData)

	--update obj.name by updateData's index to mysql
	local ret = Common.mysqlExecute(sqlCmd, pid)
	--check ret
	if ret.badresult then
		LOG_DB( "updateUser err:%s, sql:%s", ret.badresult, sqlCmd)
		return false
	end

	return true
end

function EntityImpl:updateMongoImpl()
	assert(false,"not impl updateMongoImpl")
end

function EntityImpl:updateConfig()
	assert(false, "updateConfig is forbid")
end

function EntityImpl:updateCommon( tbname, pid, updateData, nojson, alljson )
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:updateCommonMysql(tbname, pid, updateData, nojson, alljson)
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:updateCommonMongo(tbname, pid, updateData, nojson, alljson)
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:updateUser( tbname, pid, updateData, nojson )
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:updateMysqlImpl( tbname, pid, updateData, Enum.TableType.USER, nojson )
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:updateMongoImpl( tbname, pid, updateData, Enum.TableType.USER )
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:delCommonMysql( tbname, pid)
	local obj = assert(self:getEntityCfg(Enum.TableType.COMMON, tbname))
	local sqlCmd = string.format(self:makeDeleteFormat(pid),
																obj.name,
																obj.key,
																pid
	)

	--del obj.name by dataKeys's index to mysql
	local ret = Common.mysqlExecute(sqlCmd, tonumber(pid) or 0)
	--check ret
	if ret.badresult then
		LOG_DB( "delCommon err:%s, sql:%s", ret.badresult, sqlCmd)
		return false
	end

	return true
end

function EntityImpl:delCommonMongo()
	assert(false, "not impl delCommonMongo")
end

function EntityImpl:delConfig()
	assert(false, "delConfig is forbid")
end

function EntityImpl:addConfig()
	assert(false, "addConfig is forbid")
end

function EntityImpl:addCommon( tbname, pid, dataRaw, nojson, alljson )
	assert(type(dataRaw) == "table", tostring(dataRaw))
	local obj = assert(self:getEntityCfg(Enum.TableType.COMMON,tbname))
	local sqlCmd = string.format(self:makeInsertFormat(pid), obj.name, pid, self:serializeSproto(tbname, dataRaw, nojson, alljson))
	local ret = Common.mysqlExecute(sqlCmd, tonumber(pid) or 0)
	if ret.badresult then
		LOG_DB( "addCommon err:%s, sql:%s", ret.badresult, sqlCmd)
		return false
	end

	return true
end

function EntityImpl:delCommon( tbname, pid )
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:delCommonMysql(tbname, pid)
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:delCommonMongo(tbname, pid)
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:delUser( tbname, pid )
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:delMysqlImpl(tbname, pid, Enum.TableType.USER)
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:delMongoImpl(tbname, pid, Enum.TableType.USER)
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:delMysqlImpl( tbname, pid, tbtype )
	local obj = assert(self:getEntityCfg(tbtype, tbname))
	local sqlCmd = string.format("delete from %s where %s = %d",
																obj.name,
																obj.key,
																pid
								)

	--del obj.name by dataKeys's index to mysql
	local ret = Common.mysqlExecute(sqlCmd, pid)
	--check ret
	if ret.badresult then
		LOG_DB( "delUser err:%s, sql:%s", ret.badresult, sqlCmd)
	else
		--del redis user info
		self:delRedisImpl( obj.name, pid )
	end
end

function EntityImpl:delMongoImpl()
	assert(false, "not impl delMongoImpl")
end

function EntityImpl:addMysqlImpl( _tbName, pid, dataRaw, tbtype, nojson, alljson )
	local obj = assert(self:getEntityCfg(tbtype,_tbName))
	--add to mysql
	local sqlCmd = string.format(self:makeInsertFormat(pid),obj.name, pid, self:serializeSproto(_tbName, dataRaw, nojson, alljson))
	local ret = Common.mysqlExecute(sqlCmd, pid)
	if ret.badresult then
		LOG_DB( "addUser Error:%s, sql:%s", ret.badresult, sqlCmd)
		return false
	end

	--add to redis
	self:addRedisImpl(_tbName, pid, dataRaw)
	return true
end

function EntityImpl:addMongoImpl()
	assert(false, "not impl addUserMongo")
end

function EntityImpl:addUser( tbname, pid, dataRaw, nojson )
	assert(type(dataRaw) == "table")
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:addMysqlImpl(tbname, pid, dataRaw, Enum.TableType.USER, nojson)
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:addMongoImpl(tbname, pid, dataRaw, Enum.TableType.USER, nojson)
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:addRole( tbname, pid, dataRaw, nojson, alljson )
	assert(type(dataRaw) == "table")
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:addMysqlImpl(tbname, pid, dataRaw, Enum.TableType.ROLE, nojson, alljson)
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:addMongoImpl(tbname, pid, dataRaw, Enum.TableType.ROLE, nojson, alljson)
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:loadRole( tbname, pid, remoteNode )
	if remoteNode then
		local skynet = require "skynet"
		--默认DEFUALT_SNAX_SERVICE_NUM个子服务
		local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
		return Common.rpcCall(remoteNode, tbname .. ( pid % multiSnaxNum + 1 ), "Load", pid)
	else
		--尝试从redis获取数据
		local ret = self:getRedisImpl(tbname, pid)
		if not ret then
			--从db获取user数据
			if Enum.G_DBTYPE == Enum.DbType.MYSQL then
				return self:loadMysqlImpl(tbname, pid, Enum.TableType.ROLE)
			elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
				return self:loadMongoImpl(tbname, pid, Enum.TableType.ROLE)
			else
				assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
			end
		end
		return ret
	end
end

function EntityImpl:updateRole( tbname, pid, updateData, nojson, alljson )
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:updateMysqlImpl( tbname, pid, updateData, Enum.TableType.ROLE, nojson, alljson )
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:updateMongoImpl( tbname, pid, updateData, Enum.TableType.ROLE, nojson, alljson )
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:delRole( tbname, pid )
	if Enum.G_DBTYPE == Enum.DbType.MYSQL then
		return self:delMysqlImpl(tbname, pid, Enum.TableType.ROLE)
	elseif Enum.G_DBTYPE == Enum.DbType.MONGO then
		return self:delMongoImpl(tbname, pid, Enum.TableType.ROLE)
	else
		assert(false,"invalid dbtype:" .. Enum.G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:setEntityCfg( config, common, user, role )
	local tb = {}
	tb[Enum.TableType.CONFIG] 	= 	config
	tb[Enum.TableType.COMMON] 	= 	common
	tb[Enum.TableType.USER] 	= 	user
	tb[Enum.TableType.ROLE]		=	role
	sharedata.new(Enum.Share.ENTITY_CFG, tb)
	self:recordmaxIdToRedis()

	-- init table protocol slot
	self:setSprotoShare()
end

function EntityImpl:setSprotoShare()
	local sprotoBlock = MergeProtocol:getDBSproto()
	sprotoloader.save(sprotoparser.parse(sprotoBlock), Enum.SPROTO_SLOT.DB)
end

function EntityImpl:getSprotoShare()
	return sprotoloader.load( Enum.SPROTO_SLOT.DB )
end

function EntityImpl:getEntityCfg( tbtype, tbname )
	local tb = sharedata.query(Enum.Share.ENTITY_CFG)
	if tbname and tb then
		for _,v in pairs(tb[tbtype]) do
			if v.name == tbname then
				return v
			end
		end
	else
		return tb[tbtype]
	end
end

function EntityImpl:maxIdToRedis( name, key )
	local cmd = string.format("select max(%s) as %s from %s",key,key,name)
	local ret = Common.mysqlExecute(cmd)
	assert(ret.badresult == nil, "execute sql fail:"..cmd..",err:"..(ret.err or ""))
	local id = tonumber(ret[1][key]) or (MSM.PkIdMgr[0].req.getDefaultPkId() - 1)
	cmd = { "set", string.format("%s:%s", name, key ), id }
	Common.redisExecute(cmd)
end

function EntityImpl:recordmaxIdToRedis()
	local tb = sharedata.query(Enum.Share.ENTITY_CFG)
	for tbtype,cfg in pairs(tb) do
		if tbtype ~= Enum.TableType.CONFIG then -- config 从 Configs.lua 文件读取
			for _,tbcfg in pairs(cfg) do
				self:maxIdToRedis(tbcfg.name, tbcfg.key)
			end
		end
	end
end

return EntityImpl
