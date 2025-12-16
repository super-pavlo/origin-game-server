--[[
* @file : MongoAgent.lua
* @type : service
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : mongo db client 的代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]


local mongo = require "skynet.db.mongo"

local mongoClient

function init( conf )
	mongoClient = assert(mongo.client(conf),"connect to mongodb fail:"..tostring(conf))
end

function exit()
	mongoClient.disconnect()
end

