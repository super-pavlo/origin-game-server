--[[
* @file : ClientLogin.lua
* @type : lua lib
* @author : linfeng
* @created : Thu Jan 04 2018 14:13:15 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端登陆相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local socket = require "clientcore"
local crypt = require "client.crypt"
local ClientCommon = require "logic.ClientCommon"
local CHECK = ClientCommon.CHECK

local loginip = "10.0.3.117"
local loginport = 10000

function ClientLogic:login( _, token )
	CHECK(token, self.help)
	ClientCommon:setLoginStatus( false )
	local lfd = assert(socket.connect(loginip,loginport))
	local ret = socket.recvline(lfd)
	print("recv challenge code:"..ret)
	local challenge = crypt.base64decode(ret)

	local enkey, clientkey = ClientCommon:make_randomkey()
	ClientCommon:sendpack(lfd, enkey .. "\n", true)
	ret = socket.recvline(lfd)
	print(ret)
	local svrkey = crypt.base64decode(ret)
	print("recv server key:"..svrkey)

	local clisecret = crypt.dhsecret(svrkey,clientkey)
	ClientCommon:setEncrypt( clisecret )
	local encryptChallenge = crypt.hmac64(challenge,clisecret)
	ClientCommon:sendpack(lfd,crypt.base64encode(encryptChallenge) .. "\n", true)
	local tokenInfo = string.split(token, ":")
	ClientCommon:sendpack(lfd,ClientCommon:make_crypt_token(tokenInfo[1], tokenInfo[2]) .. "\n", true)
	ret = socket.recvline(lfd)
	print("recv challenge result:"..ret)
	if not ret:find("200") then
		print("challenge fail:"..ret)
		socket.close(lfd)
		return
	end

	local username = crypt.base64decode(ret:sub(5,#ret))
	-- base64(iggid)@base64(subid)#base64(connectip) base64(connectport)@base64(connectRealIp)@base64(hadRole)
	local iggid, subid, connectip, connectport, connectRealIp, servername, uid = username:match "([^@]*)@(.*)@(.*)@(.*)@(.*)@(.*)@(.*)"
	connectip = crypt.base64decode(connectip)
	connectport = crypt.base64decode(connectport)
	print(crypt.base64decode(iggid), crypt.base64decode(subid), connectip, connectport,
			crypt.base64decode(connectRealIp), crypt.base64decode(servername))

    socket.close(lfd)
	ClientCommon:setLoginStatus( true )
	return string.format("%s@%s#%s", uid, servername, subid),connectip,connectport
end


function ClientLogic:auth( mode, token, close)
	local lastfd = ClientCommon:getFd()
	if mode and lastfd then return lastfd, true end
	CHECK(token, self.help)
	local username,connectip,connectport = self:login(mode, token)
	if username == nil then
		return
    end
	ClientCommon:setUsername( username )
	local gfd = assert(socket.connect(connectip, tonumber(connectport)))
	ClientCommon:sendpack( gfd, ClientCommon:make_auth(username), nil, true)
	local ret  = false
	socket.recvpack(gfd, function ( pack )
		if pack:find("200") then
			ret = true
			print("auth ok")

			-- begin recv protocol pack
			-- socket.loop(gfd, ClientCommon.loop_recv_callback)
		else
			print("auth fail:" .. pack)
		end
	end)

	if close == nil and not mode then
		socket.close(gfd)
	else
		ClientCommon:setFd( gfd )
	end

	return gfd, ret, connectip, tonumber(connectport)
end


function ClientLogic:reauth( mode, token, keep )
	CHECK(token, self.help)
	local _,ret,connectip,connectport = self:auth( mode, token )
	if not ret then
		print("first auth error")
		return
	end
	print("reauth after 3s...")
	socket.usleep(1000000 * 3)

	local gfd = assert(socket.connect(connectip, tonumber(connectport)))
	ClientCommon:sendpack( gfd,ClientCommon:make_auth(ClientCommon:getUsername()), nil, true )
	socket.recvpack(gfd, function ( pack )
		if pack:find("200") then
			print("auth ok")
		else
			print("auth fail")
		end
	end)

	if not keep then
		socket.close(gfd)
	end
end

function ClientLogic:authChat( fd, rid )
	while true do
        local data = socket.recv(fd)
		if data then
			ClientCommon:unpack(data)
			local serverMsg = ClientCommon.getServerMsg()
			for _, msg in pairs( serverMsg ) do
				if msg.reqName == "Role_RoleLogin" and msg.msgInfo.chatServerIp then
					local chatFd = assert(socket.connect(msg.msgInfo.chatServerIp, tonumber(msg.msgInfo.chatServerPort)))
					local username = string.format( "%s@%s#%s", crypt.base64encode(tostring(rid)),
							crypt.base64encode(tostring(msg.msgInfo.chatServerName)),
							crypt.base64encode(tostring(msg.msgInfo.chatSubId)) )
					-- ClientCommon:sendpack( chatFd, ClientCommon:make_auth(username), nil, true )
					ClientCommon:sendpack( chatFd, ClientCommon:make_auth(username), nil, true )
					socket.recv(chatFd, 10)
					return chatFd
				end
			end
        end
	end

	-- local gfd = assert(socket.connect("10.0.3.117", 12000))
	-- ClientCommon:sendpack( gfd, "chatTest" )
end