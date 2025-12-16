--[[
* @file : Chatd.lua
* @type : lualib
* @author : linfeng
* @created : Fri May 11 2018 13:35:25 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天服务器网关管理
* Copyright(C) 2017 IGG, All rights reserved
]]

local ChatGate = require "ChatGate"
local skynet = require "skynet"
local snax = require "skynet.snax"

local server = {}
local username_map = {}
local rid_agent = {}
local internal_id = 0
local agent_id = 0
local agents = {}
local maxAgent
local perClientInAgent = 1000 -- 1000 client per agent
local connectIp = skynet.getenv("connectip")
local connectRealIp = skynet.getenv("connectrealip")
local connectPort = skynet.getenv("port")

local function allocAgent()
	maxAgent = assert(tonumber(skynet.getenv("maxclient")) or 100000) / perClientInAgent
	for _ = 1 , maxAgent do
		table.insert(agents, assert(snax.newservice("Agent")))
	end
end

-- game server disallow multi login, so login_handler never be reentry
-- call by game server
function server.login_handler( _, secret, roleInfo, _oldSubId )
	local username
	local subid
	local agent

	if _oldSubId then
		subid = _oldSubId
	else
		internal_id = internal_id + 1 -- don't use internal_id directly
		subid = internal_id
	end
	username = ChatGate.username(roleInfo.rid, subid, roleInfo.gameNode)
	if rid_agent[roleInfo.rid] then
		agent = rid_agent[roleInfo.rid]
	else
		agent_id = agent_id + 1
		agent = assert(agents[agent_id % maxAgent + 1], "not found valid agent")
		rid_agent[roleInfo.rid] = agent
	end

	-- trash subid (no used)
	agent.req.login( skynet.self(), roleInfo, subid, secret, username )

	local u = {
		username = username,
		agent = agent,
		roleInfo = roleInfo,
		subid = subid,
		rid = nil,
	}
	assert(username_map[username] == nil)
	username_map[username] = u
	ChatGate.login( username, secret )

	-- you should return unique subid
	return subid, connectIp, connectRealIp, connectPort, roleInfo.gameNode
end

-- call by self (when recv first auth)
function server.auth_handler( username, fd )
	local u = username_map[username]
	assert(u)
	u.agent.req.auth( u.roleInfo, fd, username )
end

-- call by agent
function server.logout_handler(_, username, _rid)
	local u = username_map[username]
	if u then
		ChatGate.logout(username)
		username_map[username] = nil
	end
	if _rid then
		rid_agent[_rid] = nil
	end
end

-- call by self (when socket disconnect)
function server.disconnect_handler(fd, username)
	local u = username_map[username]
	if u then
		u.agent.req.afk( skynet.self(), fd, username )
	end
end

-- call by self (when recv a request from client)
function server.request_handler(username, msg)
	local u = username_map[username]
	msg = string.pack('<d', username:len()) .. username .. msg
	return skynet.tostring(skynet.rawcall(u.agent.handle, "client", msg))
end

-- call by self (when gate open)
function server.register_handler()
	allocAgent()
end

-- call by web
function server.clean_handler()
	for _,agent in pairs(agents) do
		agent.req.cleanAgent()
	end
end

skynet.register(SERVICE_NAME)

ChatGate.start(server)