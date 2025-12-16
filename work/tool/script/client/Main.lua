--[[
* @file : Main.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 15:45:22 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 模拟客户端请求,用于协议功能测试
* Copyright(C) 2017 IGG, All rights reserved
]]

local svr =  "../../../common/lualib/?.lua;".."./?.lua;"
package.path = "../../../3rd/skynet/lualib/?.lua;../../../3rd/skynet/service/?.lua;"..svr
package.cpath = "../../../3rd/skynet/luaclib/?.so;../../../common/luaclib/?.so"

local string = string
local table = table

local rawprint = print
require "LuaExt"
print = function (...)
	rawprint(...)
end

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"
require "logic.ClientLoginLogic"
require "logic.ClientRoleLogic"
require "logic.ClientBuildLogic"
require "logic.ClientTechnologyLogic"
require "logic.ClientHeroLogic"
require "logic.ClientItemLogic"
require "logic.ClientHosptialLogic"
require "logic.ClientMapLogic"
require "logic.ClientShopLogic"
require "logic.ClientGuildLogic"
require "logic.ClientActivityLogic"
require "logic.ClientTransportLogic"
require "logic.ClientChatLogic"
require "logic.ClientEmailLogic"
require "logic.ClientRankLogic"

function ClientLogic:help(  )
	local info =
[[
"Usage":lua Main.lua cmd [args] ...
	help 					this help
	exit					exit console
	login 					token
	auth					token
	rolecreate				token name country
	rolelogin				token rid
	rolelist				token
	mapmarch				token x y
	mapmove					token x y
	createBuliding			token rid type x y
]]
	rawprint(info)
end

function ClientLogic:exit()
	os.exit()
end

local function reaLine()
	while true do
		local s = io.read()
		if s then
			return s
		end
	end
end

local mode = false
local function Run( ... )
	if ... == nil then
		mode = true
	end
	ClientCommon:InitEnv( mode )
	if not mode then
		local args = {...}
		local t = string.split(table.concat(args," ")," ")
		local cmd = t[1]
		local f = ClientLogic[cmd]
		if f then
			table.remove(t, 1)
			local ok,err = pcall(f, ClientLogic, mode, table.unpack(t))
			if not ok then print(err) end
		else
			print("not found cmd<".. tostring(cmd) ..">! use <help> cmd for usage!")
		end
	else
		-- 实时交互模式
		while true do
			print("please input cmd:")
			local args = reaLine()
			local t = string.split(args, " ")
			local cmd = t[1]
			local f = ClientLogic[cmd]
			if f then
				table.remove(t, 1)
				local ok,err = pcall(f, ClientLogic, mode, table.unpack(t))
				if not ok then print(err) end
			else
				print("not found cmd<".. tostring(cmd) ..">! use <help> cmd for usage!")
			end
		end
	end
end

Run( ... )

if  mode then
	while true do
		reaLine()
	end
end