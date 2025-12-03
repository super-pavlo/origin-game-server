--[[
* @file : AutoTestMain.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Mar 15 2018 10:56:20 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 模拟客户端请求,用于协议功能自动测试
* Copyright(C) 2017 IGG, All rights reserved
]]

local string = string
local table = table

local rawprint = print
require "LuaExt"
print = function (...)
	rawprint(...)
end

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"
require "logic.ClientBattleLogic"
require "logic.ClientLoginLogic"
require "logic.ClientRoleLogic"
require "logic.ClientSystemLogic"
require "logic.ClientNpcLogic"
require "logic.ClientChatLogic"
require "logic.ClientItemLogic"
require "logic.ClientPetLogic"
require "logic.ClientPMLogic"
require "logic.ClientWalkLogic"
require "logic.ClientMapLogic"
require "logic.ClientGuildLogic"
require "logic.ClientTaskLogic"
require "logic.ClientFriendLogic"
require "logic.ClientTeamLogic"
require "logic.ClientPartnerLogic"
require "logic.ClientFairyLogic"
require "logic.ClientRankLogic"
require "logic.ClientAnswerLogic"
require "logic.ClientActivityLogic"
require "logic.ClientEmailLogic"
require "logic.ClientExamLogic"
require "logic.ClientShopCurrencyLogic"
require "logic.ClientChatGroupLogic"

function ClientLogic:help(  )
	local info =
[[
	"Usage":lua Main.lua cmd [args] ...
		help 					this help
		exit					exit console
		login 					token:gamenode:loginRid
		auth 					token:gamenode:loginRid closefd
		synctime				token:gamenode:loginRid
		serverlist				token:gamenode:loginRid language
		reauth 					token:gamenode:loginRid
		repeatauth 				token:gamenode:loginRid
		rolelist				token:gamenode:loginRid
		rolecreate				token:gamenode:loginRid name job sroleId
		rolelogin				token:gamenode:loginRid loginRid
		battlecreate			token:gamenode:loginRid
		rolecmd					cmdtype cmdarg cmdtarget
		petcmd					cmdtype cmdarg cmdtarget
		npcinteract				token:gamenode:loginRid npcId scriptId data
		sendmsg					token:gamenode:loginRid type content [torid]
		itemuse					token:gamenode:loginRid itemIndex itemScriptId itemNum data
		refinekernel			token:gamenode:loginRid itemIndex1:itemNum1|itemIndex2:itemNum2|itemIndex3:itemNum3
		repairequip				token:gamenode:loginRid itemIndex isSpecialRepair
		restoreequip			token:gamenode:loginRid itemIndex
		rolepointadd			token:gamenode:loginRid vitality magic strength stamina agile
		unlockpointaddlist		token:gamenode:loginRid
		usepointaddinfo			token:gamenode:loginRid pointAddInfoId
		skilllevelup			token:gamenode:loginRid skillId
		forgeequip				token:gamenode:loginRid itemId fortifyForge
		modifypointadd			token:gamenode:loginRid petIndex vitality magic strength stamina agile
		modifybattlepet			token:gamenode:loginRid petIndex
		modifypetname			token:gamenode:loginRid petIndex name
		petrelease				token:gamenode:loginRid petIndex
		retripet				token:gamenode:loginRid petIndex1|petIndex2|...
		studypetskill			token:gamenode:loginRid petIndex itemIndex
		provepetskill			token:gamenode:loginRid petIndex skillId
		proveskillreplace		token:gamenode:loginRid petIndex itemIndex
		cancleskillprove		token:gamenode:loginRid petIndex
		peteatkernel			token:gamenode:loginRid petIndex kernelIndex itemIndex
		deepenkernelmemory		token:gamenode:loginRid petIndex kernelIndex
		distillkernelmemory		token:gamenode:loginRid petIndex kernelIndex
		petculture				token:gamenode:loginRid petIndex itemIndex itemNum data
		roleWalk				token:gamenode:loginRid path
]]
	rawprint(info)
end

function ClientLogic:exit()
	os.exit()
end

local AutoTestMain = {}

function AutoTestMain:Run( _connectFlag, _cmd, _args )
	ClientCommon:InitEnv()

	local mode = not _connectFlag
	local f = ClientLogic[_cmd]
	if f then
		local ok,err = pcall(f, ClientLogic, mode, table.unpack(_args))
		if not ok then error(err) end
	else
		ClientLogic:help()
		ClientLogic:exit()
	end
end

return AutoTestMain