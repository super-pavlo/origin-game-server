--[[
* @file : Gamed.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 17:24:30 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : game_server 的网关管理
* Copyright(C) 2017 IGG, All rights reserved
]]

local GameGate = require "GameGate"
local skynet = require "skynet"
local snax = require "skynet.snax"

local server = {}
local username_map = {}
local uid_agent = {}
local internal_id = 0
local agent_id = 0
local servername
local agents = {}
local maxAgent
local perClientInAgent = 100 -- 100 client per agent
local connectIp = skynet.getenv("connectip")
local connectRealIp = skynet.getenv("connectrealip")
local connectPort = skynet.getenv("port")

local function allocAgent()
	maxAgent = assert(tonumber(skynet.getenv("maxclient")) or 10000) / perClientInAgent
	for _ = 1 , maxAgent do
		table.insert(agents, assert(snax.newservice("Agent")))
	end
end

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
function server.login_handler( _, uid, secret, iggid )
	local username
	local subid
	local agent

	internal_id = internal_id + 1 -- don't use internal_id directly
	subid = internal_id
	username = GameGate.username(uid, subid, servername)
	if uid_agent[uid] then
		agent = uid_agent[uid]
	else
		agent_id = agent_id + 1
		agent = assert(agents[agent_id % maxAgent + 1], "not found valid agent")
		uid_agent[uid] = agent
	end

	-- trash subid (no used)
	agent.req.login( skynet.self(), uid, subid, secret, username, iggid )
	local u = {
		username = username,
		agent = agent,
		uid = uid,
		subid = subid,
	}
	assert(username_map[username] == nil)
	username_map[username] = u
	GameGate.login( username, secret )

	-- you should return unique subid
	return subid, connectIp, connectPort, connectRealIp
end

-- call by self (when recv first auth)
function server.auth_handler( username, fd, addr )
	local u = username_map[username]
	if u then
		u.agent.req.auth( u.uid, fd, addr, username )
	end
end

-- call by agent
function server.logout_handler(_, username, _uid, _allLogout)
	local u = username_map[username]
	if u then
		GameGate.logout(username)
		username_map[username] = nil
	end

	if _allLogout then
		uid_agent[_uid] = nil
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
function server.register_handler(name)
	servername = name
	allocAgent()
end

-- call by web
function server.clean_handler()
	for _,agent in pairs(agents) do
		agent.req.cleanAgent()
	end
end

skynet.register(SERVICE_NAME)

GameGate.start(server)