--[[
* @file : Agent.lua
* @type : service
* @author : linfeng 九  零 一 起 玩 w w w . 9 0 1 7 5 . co m
* @created : Wed Nov 22 2017 12:07:59 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 玩家代理服务,多个玩家共享一个服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
--local zlib = require "zlib"
local string = string
local table = table
local queue = require "skynet.queue"
local socketdriver = require "skynet.socketdriver"
local Timer = require "Timer"
local sprotoloader = require "sprotoloader"
local crypt = require "skynet.crypt"
local RoleLogic = require "RoleLogic"
local RoleChatLogic = require "RoleChatLogic"

local _C2S_Request
local _S2C_Push
local AgentUids = {}
local AgentNames = {} -- { username = { } }
local AgentMode

--------------------部分常量定义----------------------
local _LogOutInterval 							 	-- afk 到 logout 的间隔
local _AuthInterval 		= 	10 * 100 			-- connect 到 auth 的间隔
local _PushInterval 		= 	10					-- push msg 时间间隔
-----------------------------------------------------

---@see 反解压数据
---@param msg string 原始socket数据
---@return string 解密后的数据
local function msgUnpack( msg )
	local len = string.unpack('<d', msg)
	msg = msg:sub(9)
	local username = msg:sub(1,len)
	msg = msg:sub(len+1)
	local _rawMsg = crypt.desdecode(AgentNames[username].secret, msg)
	local _, _, sprotoMsg, _sprotoResponser = _C2S_Request:dispatch(_rawMsg)
	return sprotoMsg, _sprotoResponser, username
end

---@see 消息打包
local function msgPack( name, tb )
	local ret, error = pcall(_S2C_Push, name, tb)
	if not ret then
		LOG_ERROR("msgPack name(%s) error:%s", name, error)
	else
		return error
	end
end

---@see 合并推送消息并清空队列
---@param resp table 推送消息索引
---@return table
local function MegerPushMsg( username, resp )
	for _,pushmsg in pairs(AgentNames[username].pushlist) do
		table.insert( resp.content, { networkMessage = pushmsg } )
	end
	AgentNames[username].pushlist = {}
	return resp
end

---@see 插入pushmsg
---@param  pushlist table 需要推送的消息, pushlist = { name = xxx, msg = xxx }
local function SetPushMsg( username, msg )
	if AgentNames[username].pushlist == nil then
		AgentNames[username].pushlist = {}
	end

	table.insert( AgentNames[username].pushlist, msg )
end

---@see 定时推送同步消息.处理业务时会自动在结束时合并推送
local function PushMsgTimerWorker( username, sendNow )
	-- 登陆成功、不处理协议状态
	if AgentNames[username] and AgentNames[username].state == Enum.LoginState.OK
		and ( AgentNames[username].busy == false or sendNow ) then
		if not table.empty(AgentNames[username].pushlist) then
			local pushMsg = { content = {} }
			for _,msg in pairs(AgentNames[username].pushlist) do
				table.insert( pushMsg.content, { networkMessage = msg } )
			end
			-- push to client now
			local pushClientMsg = crypt.desencode( AgentNames[username].secret, msgPack( "GateMessage", pushMsg ) )
			--[[
			local compressFlag = 0
			if pushClientMsg:len() > Enum.CompressMinSize then
				-- compress
				local zlibCompress = zlib.deflate()
				pushClientMsg = zlibCompress(pushClientMsg, "finish")
				compressFlag = 1
			end
			pushClientMsg = string.pack( ">s2", pushClientMsg .. string.pack(">I4", 1, 0) .. string.pack(">B", compressFlag) )
			LOG_WARNING("username(%s) iggid(%s) len:%d byte:%s", username, AgentNames[username].iggid, pushClientMsg:len(), crypt.base64encode(pushClientMsg))
			]]
			pushClientMsg = string.pack( ">s2", pushClientMsg .. string.pack(">I4", 1, 0) .. string.pack(">B", 0) )
			socketdriver.send( AgentNames[username].fd, pushClientMsg )
			--[[
			pushClientMsg, allPackSize = Common.SplitPackage(pushClientMsg)
			for msgIndex, msg in pairs(pushClientMsg) do
				msg = string.pack(">s2", msg .. string.pack(">B", msgIndex) .. string.pack(">B", allPackSize))
				socketdriver.send( AgentNames[username].fd, msg )
			end
			]]
			AgentNames[username].pushlist = {}
		end
	end
end

---@see 拓展请求信息
local function ExternReqmsg( subMsg, uid, username, subid, iggid, fd, rid, secret )
	subMsg.uid = uid
	subMsg.subid = subid
	subMsg.username = username
	subMsg.agentHandle = skynet.self()
	subMsg.agentName = SERVICE_NAME
	subMsg.iggid = iggid
	subMsg.secret = secret
	subMsg.fd = fd
	if rid then
		subMsg.rid = rid
	end
end


---@see 解析网络包数据
---@param rawMsg table 原始已解密数据
---@return 返回包
local function msgDispatch( protomsg, protoResponser, username )
	if not AgentNames[username] or AgentNames[username].state ~= Enum.LoginState.OK then
		LOG_ERROR("msgDispatch from username(%s) status error", username)
		return
	end
	local uid = Common.getUSidByUserName(username)
	local subid = AgentNames[username].subid
	local rid = AgentNames[username].rid
	local iggid = AgentNames[username].iggid
	local fd = AgentNames[username].fd
	local secret = AgentNames[username].secret
	AgentNames[username].busy = true
	local resp = { content = {} }
	local _subName,_subMsg,_subResponser
	for _,rawMsg in pairs(protomsg.content) do
		_, _subName, _subMsg, _subResponser = _C2S_Request:dispatch(rawMsg.networkMessage)
		LOG_DEBUG("recv iggid(%s) rid(%s) req:%s-%s", iggid, tostring(rid), _subName, tostring(_subMsg))
		ExternReqmsg(_subMsg, uid, username, subid, iggid, fd, rid, secret) --添加一些必要的参数,供逻辑部分使用
		local service,method = _subName:match("([^_]*)_(.*)")
		local ok,responsermsg,errno,errmsg = pcall( MSM[service][uid].req[method], _subMsg )
		if not AgentNames[username] or AgentNames[username].state ~= Enum.LoginState.OK then	--离线
			LOG_INFO("iggid(%s) rid(%s) offline,won't response message(%s)", iggid, tostring(rid), _subName)
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
				LOG_INFO("resp iggid(%s) rid(%s) client req(%s) errno(%d)", iggid, tostring(rid), _subName, errno)
			else
				if responsermsg then
					if _subResponser then --有消息需要response
						LOG_DEBUG("resp client iggid(%s) rid(%s):%s-%s", iggid, tostring(rid), _subName, tostring(responsermsg))
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
		local ret = protoResponser(resp)
		return crypt.desencode( AgentNames[username].secret, ret )
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
---@see call.by.gated
function response.login( source, uid, subid, secret, username, iggid )
	if AgentMode == Enum.AgentMode.CLOSE then error("agent is close, login request invalid") end -- 直接抛出异常,让loginserver auth fail

	assert(AgentNames[username] == nil)
	AgentNames[username] = {
							uid = uid,
							subid = subid,
							secret = secret,
							state = Enum.LoginState.PRELOGIN,
							afkTimer = nil,
							loginTimer = nil,
							pushTimer = nil,
							busy = false,
							pushlist = {},
							lock = queue(),
							gate = source,
							iggid =  iggid,
	}

	-- must be auth in _AuthInterval second
	AgentNames[username].loginTimer = Timer.runAfter(_AuthInterval, snax.self().req.logout, username)
	LOG_INFO("username(%s) iggid(%s) uid(%d) login", username, iggid, uid)
end

---@see call.by.gated
function response.auth( uid, fd, ip, username )
	local agentUserName = AgentNames[username]
	if not agentUserName then return end
	-- set fd
	agentUserName.fd = fd
	agentUserName.ip = ip

	if agentUserName.state == Enum.LoginState.AFK or agentUserName.state == Enum.LoginState.PRELOGIN then
		ClearTimer(username)
		LOG_INFO("username(%s) iggid(%s) fd(%d) uid(%d) rid(%s) auth", username, agentUserName.iggid,fd,  uid, tostring(agentUserName.rid))

		if agentUserName.state == Enum.LoginState.AFK then
			LOG_INFO("iggid(%s) uid(%d) rid(%s) reauth", agentUserName.iggid, uid, tostring(agentUserName.rid))
			-- remove afktimer
			Timer.delete(agentUserName.afkTimer)
		end

		-- init push timer
		agentUserName.pushTimer = Timer.runEvery( _PushInterval ,PushMsgTimerWorker, username)
	end

	if agentUserName.loginTimer then
		Timer.delete(agentUserName.loginTimer)
		agentUserName.loginTimer = nil
	end

	agentUserName.state = Enum.LoginState.OK
end

-- call by gated
function response.afk( _, _fd, _username, _forceAfk, _onlyClean )
	--logout after _LogOutInterval second
	local agentUserName = AgentNames[_username]
	if agentUserName and agentUserName.fd == _fd and agentUserName.state == Enum.LoginState.OK then
		-- wait until not busy
		if not _forceAfk then
			local timeout = os.time() + 2 --2s超时
			while timeout > os.time() do
				if not AgentNames[_username] then break end
				if AgentNames[_username].busy == true then skynet.sleep(1) else break end
			end
		end

		-- 延迟logout
		agentUserName.afkTimer = Timer.runAfter(_LogOutInterval, snax.self().req.logout, _username)
		agentUserName.state = Enum.LoginState.AFK
		local uid = agentUserName.uid
		LOG_INFO("username(%s) iggid(%s) uid(%d) rid(%s) afk", _username, agentUserName.iggid, uid, tostring(agentUserName.rid))
		if agentUserName.online and not _onlyClean then
			-- 角色在线才afk
			RoleLogic:onRoleAfk( agentUserName.iggid, uid, agentUserName.rid )
		end
		agentUserName.online = false
	end
end

-- call by self
function response.logout( username, keeprole, force, onlyClean )
	local agnetUserName = AgentNames[username]

	if agnetUserName then
		ClearTimer(username)
		local uid = agnetUserName.uid
		local rid = agnetUserName.rid
		--加载了角色信息,才需要卸载. 当keeprole为true时,说明为被顶号,不需要卸载
		if not keeprole then
			if rid then
				RoleLogic:onRoleLogout( rid )
				LOG_INFO("username(%s) iggid(%s) uid(%d) rid(%s) logout,clean roleInfo", username, agnetUserName.iggid, uid, tostring(rid))
			end
		end

		-- del rid-agent info from AgentMgr
		if rid then
			MSM.AgentMgr[rid].req.delRid( rid, username )
		end

		-- logout uid
		if AgentUids[uid] then
			if rid then
				AgentUids[uid][rid] = nil
				LOG_INFO("iggid(%s) uid(%d) rid(%s) logout, remove AgentUids info", agnetUserName.iggid, uid, tostring(rid))
			end
			if table.empty(AgentUids[uid]) then
				AgentUids[uid] = nil
			end
		end

		-- 强制登出的时候才关闭socket、移除username
		if not force then
			-- 通知 Gamed 登出
			LOG_INFO("close username(%s) uid(%d) rid(%s) fd(%d)", username, uid, tostring(rid), agnetUserName.fd or -1)
			local isCleanUidAgent = AgentUids[uid] == nil and not keeprole
			skynet.call(agnetUserName.gate, "lua", "logout", username, uid, isCleanUidAgent)
		end

		-- del from AgentNames
		AgentNames[username] = nil

		return true
	else
		return false
	end
end

---@see 序列化推送信息并加入队列
local function addPushMsg( username, name, pushmsg, notLog )
	local msg = msgPack(name, pushmsg)
	if not msg then
		LOG_ERROR("iggid(%s) uid(%d) rid(%s) name(%s) value(%s), addPushMsg error",
				AgentNames[username].iggid, AgentNames[username].uid, tostring(AgentNames[username].rid), name, tostring(pushmsg))
		return
	end
	if not notLog then
		LOG_DEBUG("push iggid(%s) uid(%d) rid(%s) name(%s) value(%s), afterPack size(%d)",
					AgentNames[username].iggid, AgentNames[username].uid, tostring(AgentNames[username].rid), name, tostring(pushmsg), msg:len())
	end
	SetPushMsg( username, msg )
end

---@see 推送一条消息.阻塞版本
function response.push( username, name, pushmsg, sendNow, notLog, cache, skipOnline )
	if AgentNames[username] and ( skipOnline or AgentNames[username].online ) then
		if AgentNames[username].state ~= Enum.LoginState.OK then
			if not cache then
				return
			end
		end
		addPushMsg( username, name, pushmsg, notLog )
		if sendNow then
			PushMsgTimerWorker( username, true )
		end
	end
end

---@see 推送一条消息.非阻塞版本
function accept.push( username, name, pushmsg, notLog, cache, skipOnline )
	if AgentNames[username] and ( skipOnline or AgentNames[username].online ) then
		if AgentNames[username].state ~= Enum.LoginState.OK then
			if not cache then
				return
			end
		end
		addPushMsg( username, name, pushmsg, notLog )
	end
end

---@see 通知角色被踢出
local function notifyKick( _username, _reason )
	-- push to client now
	if AgentNames[_username] and AgentNames[_username].fd then
		local pushMsg = { content = { { networkMessage = msgPack( "System_KickConnect",  { reason = _reason } ) } } }
		pushMsg = crypt.desencode( AgentNames[_username].secret, msgPack( "GateMessage", pushMsg ) )
		pushMsg = string.pack( ">s2", pushMsg .. string.pack(">I4", 1, 0) .. string.pack(">B", 0) )
		socketdriver.send( AgentNames[_username].fd, pushMsg )
	end
end

---@see 角色登陆
function response.onRolelogin( uid, rid, _username, _reportArg )
	local agentUserName = assert(AgentNames[_username])
	if agentUserName.state == Enum.LoginState.OK then
		-- 角色已在线,需要踢掉,但是不卸载role数据
		local keeprole = false
		if AgentUids[uid] and AgentUids[uid][rid] then
			local oldUserName = AgentUids[uid][rid].username
			if oldUserName then
				local force = oldUserName == _username
				LOG_INFO("kick uid(%d) rid(%s), role repeat login, force(%s), oldUserName(%s)", uid, tostring(rid), tostring(force), oldUserName)
				keeprole = rid == AgentNames[oldUserName].rid
				-- 通知原连接踢出角色
				if oldUserName ~= _username then
					if AgentNames[oldUserName] and AgentNames[oldUserName].state == Enum.LoginState.OK then
						if AgentNames[oldUserName].online then -- 角色在线才踢出
							RoleLogic:onRoleAfk( agentUserName.iggid, uid, rid )
							notifyKick( oldUserName, Enum.SystemKick.REPLACE )
						end
					end
					LOG_INFO("iggid(%s) uid(%d) rid(%d) kick old logout", agentUserName.iggid, uid, rid)
					snax.self().req.logout( oldUserName, keeprole, force )
				end
			end
		end

		-- add rid-agent to AgentMgr service
		MSM.AgentMgr[rid].req.addRid( rid, _username, skynet.self() )

		-- 角色登陆
		if not RoleLogic:onRoleLogin( agentUserName.iggid, uid, rid, _username, keeprole, agentUserName.secret,
					agentUserName.iggid, agentUserName.fd, skynet.self(), SERVICE_NAME, _reportArg ) then
			snax.self().req.kickAgent( _username )
			LOG_INFO("iggid(%s) uid(%d) rid(%d) onRoleLogin error logout", agentUserName.iggid, uid, rid)
			snax.self().req.logout( _username )
			return -- 禁止登陆
		end

		-- 赋予新的角色username
		if not AgentUids[uid] then
			AgentUids[uid] = { [rid] = { username = _username, rid = rid } }
		else
			AgentUids[uid][rid] = { username = _username, rid = rid }
		end

		-- 更新角色rid
		agentUserName.rid = rid

		-- 推送角色数据
		RoleLogic:pushRole( uid, rid, true )

		-- 标记角色在线
		agentUserName.online = true

		-- 通知聊天服务器,此角色即将登陆
		local chatSubId, chatServerIp, chatServerRealIp, chatServerPort, chatServerName = RoleChatLogic:notifyChatServerLogin( rid, agentUserName.secret )
		return keeprole, chatSubId, chatServerIp, chatServerRealIp, chatServerPort, chatServerName
	end
end

---@see 踢出角色
function response.kickAgent( _username, _islogout, _onlyClean )
	if AgentNames[_username] and AgentNames[_username].fd then
		LOG_INFO("kickAgent username(%s) fd(%d) uid(%s)", _username, AgentNames[_username].fd, AgentNames[_username].uid)
		snax.self().req.afk( nil, AgentNames[_username].fd, _username, true, _onlyClean )
		if _islogout then
			LOG_INFO("iggid(%s) uid(%d) rid(%d) kickAgent logout", AgentNames[_username].iggid, AgentNames[_username].uid, AgentNames[_username].rid)
			snax.self().req.logout( _username, nil, nil, true, _onlyClean )
		end
	end
end

---@see 清理Agent并拒绝服务
function response.cleanAgent()
	-- 断开所有socket
	for username, userInfo in pairs(AgentNames) do
		notifyKick( username, Enum.SystemKick.SERVER_CLOSE )
		snax.self().req.afk( nil, userInfo.fd, username, true )
		LOG_INFO("iggid(%s) uid(%d) rid(%s) cleanAgent logout", userInfo.iggid, userInfo.uid, tostring(userInfo.rid))
		snax.self().req.logout( username )
	end
	AgentNames = {}
	AgentUids = {}
	AgentMode = Enum.AgentMode.CLOSE
end

function init()
	-- client protocol
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		unpack = skynet.tostring,
		dispatch = function (_, _, msg)
			local sprotoMsg, sprotoResponser, username = msgUnpack(msg)
			-- same uid request dispatch in queue
			skynet.ret(AgentNames[username].lock( msgDispatch, sprotoMsg, sprotoResponser, username ))
		end
	}

	_LogOutInterval = Enum.AFK_INTERVAL * 100

	-- slot Enum.SPROTO_SLOT.RPC set at Main.lua initLogicLuaService
	_C2S_Request = sprotoloader.load(Enum.SPROTO_SLOT.RPC):host "package"
	_S2C_Push = _C2S_Request:attach(sprotoloader.load(Enum.SPROTO_SLOT.RPC))
	-- default open mode
	AgentMode = Enum.AgentMode.OPEN
end
--------------------------------------------------------------------------------------------