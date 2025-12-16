--[[
* @file : Agent.lua
* @type : snax multi service
* @author : linfeng
* @created : Fri May 11 2018 14:23:03 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 聊天服务器客户端代理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local string = string
local table = table
local queue = require "skynet.queue"
local socketdriver = require "skynet.socketdriver"
local Timer = require "Timer"
local sprotoloader = require "sprotoloader"
local crypt = require "skynet.crypt"
--local zlib = require "zlib"

local _C2S_Request
local _S2C_Push
local AgentNames = {} -- { username = { } }
local AgentRidUseNames = {}
local ChannelSystemRids = {}
--------------------部分常量定义----------------------
local _LogOutInterval 							 	-- afk 到 logout 的间隔
local _AuthInterval 		= 	10 * 100 			-- connect 到 auth 的间隔
local _PushInterval 		= 	10					-- push msg 时间间隔
-----------------------------------------------------

---@see 反解压数据
-- param : msg,原始socket数据
-- return : 解密后的数据
local function msgUnpack( msg )
	local len = string.unpack('<d', msg)
	msg = msg:sub(9)
	local username = msg:sub(1,len)
	msg = msg:sub(len+1)
	local _rawMsg = crypt.desdecode(AgentNames[username].secret, msg)
	local _,name,sprotoMsg, sprotoResponser = _C2S_Request:dispatch(_rawMsg)
	return name, sprotoMsg, sprotoResponser, username
end

---@see 消息打包
local function msgPack( name, tb )
	return _S2C_Push( name, tb)
end

---@see 合并推送消息并清空队列
-- param : resp,推送消息索引
-- return : resp
local function MegerPushMsg( username, resp )
	for _,pushmsg in pairs(AgentNames[username].pushlist) do
		table.insert( resp.content, { networkMessage = pushmsg } )
	end

	AgentNames[username].pushlist = {}
	return resp
end

---@see 插入pushmsg
-- param : pushlist,需要推送的消息, pushlist = { name = xxx, msg = xxx }
-- return : nil
local function SetPushMsg( username, msg )
	if AgentNames[username].pushlist == nil then
		AgentNames[username].pushlist = {}
	end

	table.insert( AgentNames[username].pushlist, msg )
end

---@see 定时推送同步消息.处理业务时会自动在结束时合并推送
local function PushMsgTimerWorker( username )
	-- 登陆成功、不处理协议状态
	if AgentNames[username] and AgentNames[username].state == Enum.LoginState.OK
		and AgentNames[username].busy == false then
		if not table.empty(AgentNames[username].pushlist) then
			local pushMsg = { content = {} }
			for _,msg in pairs(AgentNames[username].pushlist) do
				table.insert( pushMsg.content, { networkMessage = msg } )
			end

			-- push to client now
			pushMsg = crypt.desencode( AgentNames[username].secret, msgPack( "GateMessage", pushMsg ) )
			--[[
			local compressFlag = 0
			if pushMsg:len() > Enum.CompressMinSize then
				-- compress
				local zlibCompress = zlib.deflate()
				pushMsg = zlibCompress(pushMsg, "finish")
				compressFlag = 1
			end
			pushMsg = string.pack( ">s2", pushMsg .. string.pack(">I4", 1, 0) .. string.pack(">B", compressFlag) )
			]]
			pushMsg = string.pack( ">s2", pushMsg .. string.pack(">I4", 1, 0) .. string.pack(">B", 0) )
			socketdriver.send( AgentNames[username].fd, pushMsg )
			--[[
			pushMsg, allPackSize = Common.SplitPackage( pushMsg )
			for msgIndex, msg in pairs(pushMsg) do
				msg = string.pack(">s2", msg .. string.pack(">B", msgIndex) .. string.pack(">B", allPackSize))
				socketdriver.send( AgentNames[username].fd, msg )
			end
			]]
			AgentNames[username].pushlist = {}
		end
	end
end

---@see 拓展请求信息
local function ExternReqmsg( subMsg, roleInfo, username )
	subMsg.roleInfo = roleInfo
	subMsg.username = username
	subMsg.agentHandle = skynet.self()
	subMsg.agentName = SERVICE_NAME
end

---@see 解析网络包数据
-- param : rawMsg,原始已解密数据
-- return : 返回包
local function msgDispatch( protomsg, protoResponser, username )
	if AgentNames[username].state ~= Enum.LoginState.OK then return end
	local rid = AgentNames[username].roleInfo.rid
	local roleInfo = AgentNames[username].roleInfo
	AgentNames[username].busy = true
	local resp = { content = {} }
	local _subName,_subMsg,_subResponser
	for _,rawMsg in pairs(protomsg.content) do
		_, _subName, _subMsg, _subResponser = _C2S_Request:dispatch(rawMsg.networkMessage)
		LOG_DEBUG("recv rid(%s) req:%s-%s", tostring(roleInfo.rid), _subName, tostring(_subMsg))
		ExternReqmsg(_subMsg, roleInfo, username) --添加一些必要的参数,供逻辑部分使用
		local service,method = _subName:match("([^_]*)_(.*)")
		local ok,responsermsg,errno,errmsg = pcall( MSM[service][rid].req[method], _subMsg )
		if not AgentNames[username] or AgentNames[username].state ~= Enum.LoginState.OK then	--离线
			LOG_INFO("rid(%d) offline,won't response message(%s)", roleInfo.rid, _subName)
			return
		else --正常状态
			resp = MegerPushMsg( username, resp ) --检查是否有推送的消息
			local thisResp = {}
			if not ok then
				errno = ErrorCode.SERVER_DUMP
				errmsg = "server logic dump"
			end
			if errno then
				thisResp.error = {}
				thisResp.error.errorCode = errno
				thisResp.error.errorMessage = errmsg
			else
				if responsermsg then
					if _subResponser then --有消息需要response
						LOG_DEBUG("resp client:%s-%s", _subName, tostring(responsermsg))
						thisResp.networkMessage = _subResponser(responsermsg)
					end
				end
			end

			if not table.empty(thisResp) then
				table.insert(resp.content, thisResp)
			end
		end
	end
	AgentNames[username].busy = false
	--返回到gate框架
	if #resp.content > 0 then
		return crypt.desencode(AgentNames[username].secret, protoResponser(resp))
	end
end

---@see 清理定时器
local function ClearTimer( username )
	if AgentNames[username] then
		if AgentNames[username].afkTimer then
			Timer.delete(AgentNames[username].afkTimer)
		end

		if AgentNames[username].loginTimer then
			Timer.delete(AgentNames[username].loginTimer)
		end

		if AgentNames[username].pushTimer then
			Timer.delete(AgentNames[username].pushTimer)
		end
	end
end

------------------------------------- request ------------------------------------------------
--call by gated
function response.login( source, roleInfo, subid, secret, username )
	assert(AgentNames[username] == nil)
	AgentNames[username] = {
							roleInfo = roleInfo,
							subid = subid,
							secret = secret,
							state = Enum.LoginState.PRELOGIN,
							afkTimer = nil,
							loginTimer = nil,
							pushTimer = nil,
							busy = false,
							pushlist = {},
							lock = queue(),
							gate = source
	}

	--must be auth in _AuthInterval second
	AgentNames[username].loginTimer = Timer.runAfter(_AuthInterval, snax.self().req.logout, source, username, roleInfo.rid)
	LOG_INFO("username(%s) rid(%d) login", username, roleInfo.rid)
end

---@see 取消订阅相关频道
local function unSubscribeSystemChannelOnLogout( _roleInfo )
    if ChannelSystemRids[_roleInfo.rid] then
        for _,channel in pairs(ChannelSystemRids[_roleInfo.rid]) do
            -- 离开频道对象
            MSM.ChatChannelEntity[channel].req.leaveChannelEntity( _roleInfo.gameNode, channel, _roleInfo.rid )
        end
	end

	-- 删除 ChatChannel 中的数据
	if ChannelSystemRids[_roleInfo.rid] then
		MSM.ChatChannel[_roleInfo.rid].req.delRoleSystemChannel( _roleInfo.rid, ChannelSystemRids[_roleInfo.rid] )
		ChannelSystemRids[_roleInfo.rid] = nil
	end
end

-- call by gated
function response.afk( _, fd, username )
	--logout after _LogOutInterval second
	local agentUserName = AgentNames[username]
	if agentUserName and agentUserName.fd == fd then
		local rid = agentUserName.roleInfo.rid
		-- wait until not busy
		while true do
			if not AgentNames[username] then break end
			if AgentNames[username].busy == true then skynet.sleep(1) else break end
		end
		LOG_INFO("username(%s) rid(%d) afk", username, rid )

		-- 同一个session连接才移除相关数据,否则可能已经login-auth了
		if AgentRidUseNames[rid] == username then
			agentUserName.afkTimer = Timer.runAfter(_LogOutInterval, snax.self().req.logout, username)
			agentUserName.state = Enum.LoginState.AFK
			-- 离开相关频道
			unSubscribeSystemChannelOnLogout( agentUserName.roleInfo )
		else
			AgentNames[username] = nil
			skynet.call(agentUserName.gate, "lua", "logout", username)
			-- del rid-agent info from AgentMgr
			MSM.AgentMgr[rid].req.delRid( rid )
		end
	end
end

-- call by self
function response.logout( username )
	local agentUserName = AgentNames[username]

	if agentUserName then
		ClearTimer(username)
		local rid = agentUserName.roleInfo.rid

		-- del rid-agent info from AgentMgr
		MSM.AgentMgr[rid].req.delRid( rid )

		-- 通知 Gamed 登出
		LOG_DEBUG("close username(%s) rid(%s) fd(%d)", username, tostring(rid), agentUserName.fd or -1)
		skynet.call(agentUserName.gate, "lua", "logout", username, rid)
		-- del from AgentNames
		AgentNames[username] = nil
		AgentRidUseNames[rid] = nil

		-- 清理聊天相关数据
		MSM.ChatChannel[rid].req.onRoleLogout( rid )

		return true
	else
		return false
	end
end

---@see 序列化推送信息并加入队列
local function addPushMsg( username, name, pushmsg )
	local msg = msgPack(name, pushmsg)
	LOG_DEBUG("push rid(%d), name(%s), value(%s), afterPack size(%d)",
			AgentNames[username].roleInfo.rid, name, tostring(pushmsg), msg:len())
	SetPushMsg( username, msg )
end

---@see 推送一条消息
function accept.push( username, name, pushmsg )
	if AgentNames[username] then
		if AgentNames[username].state ~= Enum.LoginState.OK then
			LOG_DEBUG("push to afk role(%d) msgname(%s)", AgentNames[username].roleInfo.rid, name)
			return
		end
		addPushMsg( username, name, pushmsg )
	else
		LOG_WARNING("push msg, username(%s) invalid, msgname(%s)", username, name)
	end
end

---@see 订阅相关的系统频道.世界.组队招募.地图.系统.职业等
local function subscribeSystemChannelOnLogin( _roleInfo )
    -- 获取对应节点的频道ID(在游服启动时就已注册创建)
    local channels = SM.ChatMgr.req.getAllChannelsByNode( _roleInfo.gameNode, _roleInfo.job, _roleInfo.map,
                                                        _roleInfo.guildId, _roleInfo.teamIndex )

    ChannelSystemRids[_roleInfo.rid] = {}
    for channelType,channelId in pairs(channels) do
        -- 绑定频道
        ChannelSystemRids[_roleInfo.rid][channelType] = channelId
        -- 加入频道对象
        MSM.ChatChannelEntity[channelId].req.joinChannelEntity( _roleInfo.gameNode, channelId, _roleInfo.rid, _roleInfo.gameId )
	end

	-- 更新到ChatChannel
	MSM.ChatChannel[_roleInfo.rid].req.addRoleSystemChannel( _roleInfo.rid, ChannelSystemRids[_roleInfo.rid] )
end

-- call by gated
function response.auth( roleInfo, fd, username )
	local agentUserName = AgentNames[username]
	if not agentUserName then
		return
	end

	if (agentUserName.state ~= Enum.LoginState.AFK and agentUserName.state ~= Enum.LoginState.PRELOGIN) then
		LOG_ERROR("auth error, uid(%d) is not [afk] or [prelogin] state, may be half open status", roleInfo.rid)
		-- close old socket, may be into fin_wait2 status
		if agentUserName.fd and agentUserName.fd > 0 then
			socketdriver.shutdown(agentUserName.fd)
		end
		agentUserName.fd = fd
	end

	ClearTimer(agentUserName)
	LOG_INFO("username(%s) rid(%d) auth", username, roleInfo.rid )

	if agentUserName.state == Enum.LoginState.AFK then
		LOG_INFO("account(%s) rid(%d) reauth", agentUserName.account, roleInfo.rid)
		-- remove afktimer
		Timer.delete(agentUserName.afkTimer)
		-- update rid-agent to AgentMgr service
		MSM.AgentMgr[roleInfo.rid].req.updateUserName( roleInfo.rid, username )
	else
		-- add rid-agent to AgentMgr service
		MSM.AgentMgr[roleInfo.rid].req.addRid( roleInfo.rid, username, skynet.self() )
	end

	agentUserName.state = Enum.LoginState.OK
	agentUserName.fd = fd
	agentUserName.pushlist = {}

	-- init AgentRidUseNames
	AgentRidUseNames[roleInfo.rid] = username

	-- init push timer
	agentUserName.pushTimer = Timer.runEvery( _PushInterval ,PushMsgTimerWorker, username)

	-- 初始化频道
	subscribeSystemChannelOnLogin( roleInfo )

	-- 同步保存的聊天消息
	SM.ChatSave.post.syncChatInfo( roleInfo )
end

---@see 更新角色属性
function accept.updateRoleInfo( _username, _roleInfo )
	if AgentNames[_username] then
		AgentNames[_username].roleInfo = _roleInfo
		-- for name,value in pairs(_roleInfo) do
		-- 	AgentNames[_username].roleInfo[name] = value
		-- end
	end
end

---@see 获取角色属性
function response.getRoleInfo( _rid )
	if AgentRidUseNames[_rid] then
		if AgentNames[AgentRidUseNames[_rid]] then
			return AgentNames[AgentRidUseNames[_rid]].roleInfo
		end
	end
end

function init()
	-- client protocol
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		unpack = skynet.tostring,
		dispatch = function (_, _, msg)
			local _, sprotoMsg, sprotoResponser, username = msgUnpack(msg)
			-- same uid request dispatch in queue
			skynet.ret(AgentNames[username].lock(msgDispatch, sprotoMsg, sprotoResponser, username ))
		end
	}

	_LogOutInterval = Enum.AFK_INTERVAL * 100

	-- slot Enum.SPROTO_SLOT.RPC set at Main.lua initLogicLuaService
	_C2S_Request = sprotoloader.load(Enum.SPROTO_SLOT.RPC):host "package"
	_S2C_Push = _C2S_Request:attach(sprotoloader.load(Enum.SPROTO_SLOT.RPC)) 
end
--------------------------------------------------------------------------------------------