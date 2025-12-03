--[[
* @file : LoginMysqlAgent.lua
* @type : service
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : login mysql db client 的代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"

local mysqlClient

local function initMysqlConn()
	local function on_connect(db)
		db:query("set charset utf8")
		--mysql 5.7+
		db:query("set sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'")
	end

	local opts = {
		host = skynet.getenv("loginmysqlip"),
		port = tonumber(skynet.getenv("loginmysqlport")),
		database = skynet.getenv("loginmysqldb"),
		user = skynet.getenv("loginmysqluser"),
		password = skynet.getenv("loginmysqlpwd"),
		max_packet_size = 1024 * 1024 * 64, --max 64Mb
		on_connect = on_connect
	}

	if mysqlClient then mysqlClient.disconnect() end

	mysqlClient = assert(mysql.connect(opts),"connect to login mysql fail:"..tostring(opts))
end

function init()
	initMysqlConn()
end

function exit()
	mysqlClient.disconnect()
end

---@see 执行mysql查询
function response.query( ... )
	local ok,ret = pcall(mysqlClient.query, mysqlClient, ...)
	if not ok then
		-- retry,if disconnect, will auto reconnect at socketchannel in last query
		ret = mysqlClient:query(...)
	end
	return ret
end