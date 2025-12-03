--[[
* @file : SysLog.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 16:34:44 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 日志写入服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table

local logger = require "log.core"
local thread_co --日志写入协程
local log_info = {} --待写入文件的日志信息
local logType
local logNode

--日志落地文件协程
local function logWorker()
	local sleep_interval = 1
	while true do
		if log_info[1] ~= nil then
			for _,log in pairs(log_info) do
				logger.write(log.level, log.name, log.msg, log.dir, log.basename, log.rolltype)
			end
			log_info = {}
			sleep_interval = 1
		else
			sleep_interval = sleep_interval + 1
		end

		skynet.sleep(sleep_interval)
	end
end

function accept.log( msg )
	if msg.isStatistics and logType == 2 then
		-- 运营日志,写入到MYSQL
		Common.rpcSend( logNode, "LogProxy", "Log", msg.level, msg.name, msg.msg )
		return
	end
	table.insert(log_info, msg)
	skynet.wakeup(thread_co) --唤醒协程
end

function response.Init( selfNodeName )
	logger.init(0,0,0,selfNodeName)
	thread_co = assert(skynet.fork(logWorker),"SysLog fork logWorker fail")
	logType = tonumber(skynet.getenv("logtype")) or 1
	logNode = "log" .. skynet.getenv("lognode")
end

function exit()
	skynet.wakeup(thread_co)
	logger.exit()
end