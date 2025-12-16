--[[
* @file : RedisAgent.lua
* @type : service
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : redis db client 的代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]


local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local redis = require "skynet.db.redis"

local doCount = 0
local redisInstance

function init( index )
	local port = tonumber(skynet.getenv("redisport")) + ( index - 1 )
	--connect to redis
	local conf = {
		host = skynet.getenv("redisip"),
		port = port,
		auth = skynet.getenv("redisauth"),
		db = tonumber(skynet.getenv("redisdb")) or 0
	}

	redisInstance = redis.connect(conf)
	if not redisInstance then
		assert( false, tostring(conf) )
		skynet.abort()
	end
	redisInstance:flushdb()
end

function exit()
	if redisInstance then redisInstance:disconnect() end
end

function response.Do( cmd, pipeline )
	local ok,ret
	local resp = {}
	if pipeline then
		local pipeCmd = {}
		assert(type(cmd) == "table", tostring(cmd))
		for _, v in ipairs(cmd) do
			assert(type(v) == "table", tostring(cmd))
			table.insert(pipeCmd, v)
		end

		ok,ret = pcall(redisInstance.pipeline, redisInstance, pipeCmd, resp ) --offer a {} for result
		if not ok then
			-- retry,if disconnect, will auto reconnect at socketchannel in last query
			ret = redisInstance:pipeline( pipeCmd, resp )
		end
	else
		local redisCmd = cmd[1]
		table.remove(cmd,1)
		ok,ret = pcall(redisInstance[redisCmd], redisInstance, table.unpack(cmd))
		if not ok then
			-- retry,if disconnect, will auto reconnect at socketchannel in last query
			ret = redisInstance[redisCmd](redisInstance, table.unpack(cmd))
		end
		ret = tonumber(ret) or ret
	end

	doCount = doCount + 1
	if doCount >= 1000 then
		-- gc self
		collectgarbage()
		doCount = 0
	end
	return ret,resp
end

---@see 缓存一个脚本
function response.scriptLoad( script )
	return redisInstance:script( "LOAD", script )
end