--[[
* @file : ClientCommon.lua
* @type : lua lib
* @author : linfeng
* @created : Thu Jan 04 2018 14:05:22 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端脚本公共逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local crypt = require "client.crypt"
local sprotoloader = require "sprotoloader"
local socket = require "clientcore"
local sprotoparser = require "sprotoparser"
local zlib = require "zlib"

local ClientCommon = {}

ClientCommon._C2S_Request = nil
ClientCommon._S2C_Push = nil
local G_Session = 0
local loginState = false
local G_Encrypt
local G_username
local G_fd

local ServerMsg = {}
local G_lastProtocolName
local G_lastSession

function ClientCommon:InitEnv()
	--init sproto protocol slot
    -- local filename = "../../../common/protocol/Protocol.sproto"
	-- sprotoloader.register(filename, 0)

	local filename = "../../../common/protocol/Protocol.sproto"
	local f = io.open(filename, "r")
	local commonSprotoBlock = assert(f:read("*a"), "read commonsproto fail,path:" .. filename)
	f:close()
	filename = "../../../common/protocol/Common.sproto"
	f = io.open(filename, "r")
	local dbSprotoBlock = assert(f:read("*a"), "read cssproto fail,path:" .. filename)
    f:close()

    local allSproto = commonSprotoBlock .. dbSprotoBlock

    sprotoloader.save(sprotoparser.parse(allSproto), 0)

	ClientCommon._S2C_Push = sprotoloader.load(0):host "package"
	ClientCommon._C2S_Request = ClientCommon.c2sRequest
	-- ClientCommon._C2S_Request = ClientCommon._S2C_Push:attach(sprotoloader.load(0))
end

function ClientCommon.c2sRequest( protocolName, args, session )
	if protocolName ~= "GateMessage" then
		G_lastProtocolName = protocolName
		G_lastSession = session
	end
	return ClientCommon._S2C_Push:attach(sprotoloader.load(0))( protocolName, args, session )
end

function ClientCommon:getProtocolSession()
	return G_lastProtocolName, G_lastSession
end

function ClientCommon.CHECK( condition, func )
	if not condition then
		if func and type(func) == "function" then func() end
        error("CHECK Fail!")
    else
        return condition
	end
end

function ClientCommon:setFd( fd )
    G_fd = fd
end

function ClientCommon:getFd( )
    return G_fd
end

function ClientCommon:closeFd()
	if G_fd then
		socket.close(G_fd)
		G_fd = nil
	end
end

function ClientCommon:stopLoop()
	socket.stoploop()
end

function ClientCommon:setUsername( username )
    G_username = username
end

function ClientCommon:getUsername()
    return G_username
end

function ClientCommon:setEncrypt( encrypt )
    G_Encrypt = encrypt
end

function ClientCommon:setLoginStatus( status )
    loginState = status
end

function ClientCommon:MakeSprotoPack( msg )
	local req = {  }
	req.content = {}
	table.insert(req.content, { networkMessage = msg } )
	return crypt.desencode( G_Encrypt, self._C2S_Request("GateMessage", req, 0) )
end

function ClientCommon:sendpack(fd, msg, login, nosession)
	if login then
		msg = msg
		return socket.send(fd, msg)
	else
		local package
		if not nosession then
			G_Session = G_Session + 1
			msg = msg..string.pack('>I4', G_Session)
		end
		package = string.pack('>s2', msg)
		return socket.send(fd, package)
	end
end

function ClientCommon:unpack( data, cb, nosession )
	if not nosession then
		local compressFlag = tonumber(string.sub(data, -1))
		data = data:sub(1, -6)
		if compressFlag == 1 then
			local zlibDeCompress = zlib.inflate()
			data = zlibDeCompress(data)
		end
	end
	if data:len() <= 0 then return end
	data = crypt.desdecode(G_Encrypt,data)
	local _,_,pb = self._S2C_Push:dispatch(data)
	local reqType, reqName, ret
	local protocolName, sessionId = self:getProtocolSession()
	if pb.content then
		for _,v in pairs(pb.content) do
			if v.networkMessage then
				reqType,reqName,ret = self._S2C_Push:dispatch(v.networkMessage)
				print("server msg:" .. reqType ..":" .. reqName .. ":" .. tostring(ret))
				if reqType == "RESPONSE" and sessionId and sessionId == tonumber( reqName ) then
					table.insert( ServerMsg, { reqName = protocolName, msgInfo = ret } )
				else
					table.insert( ServerMsg, { reqName = reqName, msgInfo = ret } )
				end
				if cb then cb( reqType, reqName, ret ) end
			end

			if v.error then
				print(v.error)
				return false, v.error.errorCode
			end
		end
	end

	return true
end

function ClientCommon.loop_recv_callback( pack )
	ClientCommon:unpack( pack )
end

function ClientCommon.clearServerMsg()
	ServerMsg = {}
end

function ClientCommon.getServerMsg()
	return ServerMsg
end

function ClientCommon:make_randomkey( )
	local clikey = crypt.randomkey()
	return crypt.base64encode(crypt.dhexchange(clikey)), clikey
end

function ClientCommon:make_crypt_token( token, gameNode )
	return crypt.base64encode(crypt.desencode(G_Encrypt,token .. ":::::" .. (gameNode or "game1")))
end

local index = 0
function ClientCommon:make_auth( username )
	index = index + 1
	local handshake = string.format("%s:%d",username,index)
	local encrypt = crypt.hmac64(crypt.hashkey(handshake),G_Encrypt)
	local hmac = crypt.base64encode(encrypt)
	return string.format("%s:%s",handshake,hmac)
end

return ClientCommon