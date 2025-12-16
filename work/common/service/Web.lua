--[[
* @file : Web.lua
* @type : service
* @author : linfeng 九  零  一 起 玩 w w w . 9 0  1 7 5 . co m
* @created : Thu Nov 23 2017 13:56:35 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : web 服务,负责响应 web 请求
* Copyright(C) 2017 IGG, All rights reserved
]]

local socket = require "skynet.socket"
local skynet = require "skynet"

function response.Init()
	local port = tonumber(skynet.getenv("webport")) or 0
	if port <= 0 then return end
	local agentCount = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
	local balance = 1
	local id = socket.listen("0.0.0.0", port)
	LOG_SKYNET("Listen Web Port On: %d",port)
	socket.start(id , function(sid, addr)
		LOG_DEBUG(string.format("Web svr --> %s connected, pass it to agent :%d", addr, balance))
		MSM.WebAgent[balance].post.WebCmd( sid )
		balance = balance + 1
		if balance > agentCount then
			balance = 1
		end
	end)

	-- init web proxy
	SM.WebProxy.req.Init()
end