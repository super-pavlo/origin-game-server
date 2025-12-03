--[[
* @file : LogDefine.lua
* @type : lualib
* @author : linfeng
* @created : Tue Nov 21 2017 14:42:05 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 日志相关定义
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local _IsDaemon = skynet.getenv("daemon")
-- LOG路径
local logPath = skynet.getenv("logpath")
local eventLogPath = skynet.getenv("eventlogpath")

-- Log Define, level = (0-199)
-- 系统级日志
local EnumLogDef = const {
	E_LOG_DEBUG 				= 			{ name = "Debug", 			level = 0 },
	E_LOG_WARNING 				= 			{ name = "Warning", 		level = 1 },
	E_LOG_INFO					=			{ name = "Info", 			level = 2 },
	E_LOG_ERROR					=			{ name = "Error", 			level = 3 },
	E_LOG_FATAL					=			{ name = "Fatal", 			level = 4 },

	-- skynet的log信息
	E_LOG_SKYNET				=			{ name = "Skynet", 			level = 5 },
	E_LOG_DB					=			{ name = "Db", 				level = 6 },

	-- 行为日志定义
	E_LOG_ROLE_LOGIN			=			{ name = "RoleLogin",		level = 10 },				-- 角色登陆
	E_LOG_ROLE_LOGOUT			=			{ name = "RoleLogout",		level = 11 },				-- 角色登出
	E_LOG_SERVER_ONLINE			=			{ name = "ServerOnline",	level = 12 },				-- 服务器在线
	E_LOG_ROLE_CREATE			=			{ name = "RoleCreate",		level = 13 },				-- 角色创角
	E_LOG_BUILD_CREATE			=			{ name = "Build",			level = 14 },				-- 建筑创建
	E_LOG_ARMS_CHANGE			=			{ name = "Troops", 			level = 15 },				-- 士兵增减
	E_LOG_GUIDE					=			{ name = "Guide", 			level = 16 },				-- 新手引导
	E_LOG_TASK					=			{ name = "Task", 			level = 17 },				-- 任务
	E_LOG_CURRENCY				=			{ name = "Currency", 		level = 18 },				-- 货币增减
	E_LOG_ITEM					=			{ name = "Item", 			level = 19 },				-- 道具增减
	E_LOG_CREATE_CLICK			=			{ name = "CreateClick",		level = 20 },				-- 创建角色操作日志
	E_LOG_GUIDE_DIALOG			=			{ name = "GuideDialog",		level = 21 },				-- 新手剧情日志
	E_LOG_FUNC_GUIDE			=			{ name = "GuideEx",			level = 22 },				-- 功能引导日志
	E_LOG_ROLE_ARMY				=			{ name = "RoleArmyNew",		level = 23 },				-- 玩家部队创建解散日志
	E_LOG_ROLE_GUILD			=			{ name = "RoleAlliance",	level = 24 },				-- 联盟日志
	E_LOG_ROLE_STRONG_HOLD		=			{ name = "RoleStrongHold",	level = 25 },				-- 奇观建筑占领相关日志
	E_LOG_ROLE_ACTIVITYINFERNAL	=			{ name = "RoleActivityInfernal",	level = 26 },		-- 地狱活动日志
	E_LOG_ROLE_ACTIVITYDAYSTYPE =			{ name = "RoleActivityDaysType",	level = 27 },		-- 征服之始日志
	E_LOG_ROLE_EVOLUTION        =			{ name = "RoleEvolution",	level = 28 },				-- 服务器纪念碑日志
	E_LOG_ROLE_NEWACTIVITYDAYSTYPE	=		{ name = "RoleActivityCreate",	level = 29 },			-- 创角活动日志
	E_LOG_ROLE_SCOUT			=			{ name = "RoleDenseFog",	level = 30 },				-- 斥候探索日志
	E_LOG_ROLE_PLAYERRECHARGE   =			{ name = "RolePlayerRecharge",	level = 31 },			-- 玩家充值日志
	E_LOG_GUILD_BUILD		    =			{ name = "AllianceBuilding",level = 32 },				-- 联盟建筑基础日志
	E_LOG_GUILD_BUILD_TROOP		=			{ name = "AllianceBuildingTroops",  level = 33 },		-- 联盟建筑建造部队加入/离开日志
	E_LOG_TROOPS_MARCH			=			{ name = "TroopsMarch",		level = 34 },				-- 部队行军日志
}

-- 日志颜色定义
local COLOR = const {
	[EnumLogDef.E_LOG_ERROR.level] 			=		{ "\x1B[31m", "\x1B[0m" },
	[EnumLogDef.E_LOG_INFO.level] 			=		{ "\x1B[32m", "\x1B[0m" },
	[EnumLogDef.E_LOG_WARNING.level] 		=		{ "\x1B[33m", "\x1B[0m" },
	[EnumLogDef.E_LOG_DEBUG.level] 			=		{ "\x1B[34m", "\x1B[0m" },
	[EnumLogDef.E_LOG_DB.level] 			=		{ "\x1B[35m", "\x1B[0m" },
	[EnumLogDef.E_LOG_FATAL.level] 			=		{ "\x1B[36m", "\x1B[0m" },
	[EnumLogDef.E_LOG_SKYNET.level] 		=		{ "\x1B[36m", "\x1B[0m" },
}

local function showStdoutColor( level, msg )
	if level == EnumLogDef.E_LOG_DEBUG.level then return end
	local showMsg = COLOR[level][1] .. msg .. COLOR[level][2]
	skynet.error( showMsg )
end

---@see 系统相关日志写入
local function LOG_SYS( loginfo, fmt, level, ... )
	local ret, msg = xpcall(string.format, debug.traceback, fmt, ...)
	if not ret then
		LOG_ERROR(msg)
		return
	end
	local info = debug.getinfo(level)
	if info then
		msg = string.format("%s [%s:%d] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"),
			info.short_src, info.currentline, loginfo.name, msg)
		if not _IsDaemon then showStdoutColor( loginfo.level, msg ) end
	end

	loginfo.msg = msg
	loginfo.dir = logPath
	loginfo.basename = true
	loginfo.rolltype = 1 --按天滚动
	SM.SysLog.post.log(loginfo) --loginfo = { name = "", level = x, msg = "", dir = "", basename = true, rolltype = 1}
end

---@see 运营统计数据相关日志写入
local function LOG_STATISTICS( loginfo, fmt, ... )
	local ret, msg = xpcall(string.format, debug.traceback, fmt, ...)
	if not ret then
		LOG_ERROR(msg)
		return
	end
	loginfo.msg = msg
	loginfo.dir = eventLogPath
	loginfo.basename = false
	loginfo.rolltype = 0 --按小时滚动
	loginfo.isStatistics = true
	SM.SysLog.post.log(loginfo) --loginfo = { name = "", level = x, msg = "", dir = "", basename = false, rolltype = 0}
end

----------------------部分LOG实例-----------------------
function LOG_DEBUG( fmt, ... )
	if Enum.DebugMode then
		LOG_SYS(EnumLogDef.E_LOG_DEBUG, fmt, 3, ...)
	end
end

function LOG_WARNING( fmt, ... )
	LOG_SYS(EnumLogDef.E_LOG_WARNING, fmt, 3, ...)
end

function LOG_INFO( fmt, ... )
	LOG_SYS(EnumLogDef.E_LOG_INFO, fmt, 3, ...)
end

function LOG_ERROR( fmt, ... )
	LOG_SYS(EnumLogDef.E_LOG_ERROR, fmt, 3, ...)
end

function LOG_FATAL( fmt, ... )
	LOG_SYS(EnumLogDef.E_LOG_FATAL, fmt, 3, ...)
end

function LOG_SKYNET( fmt, ... )
	LOG_SYS(EnumLogDef.E_LOG_SKYNET, fmt, 4, ...)
end

function LOG_DB( fmt, ... )
	LOG_SYS(EnumLogDef.E_LOG_DB, fmt, 3, ...)
end

function LOG_ROLE_CREATE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_CREATE, fmt, ...)
end

function LOG_ROLE_LOGIN( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_LOGIN, fmt, ...)
end

function LOG_ROLE_LOGOUT( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_LOGOUT, fmt, ...)
end

function LOG_SERVER_ONLINE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_SERVER_ONLINE, fmt, ...)
end

function LOG_BUILD_CREATE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_BUILD_CREATE, fmt, ...)
end

function LOG_ARMY_CHANGE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ARMS_CHANGE, fmt, ...)
end

function LOG_GUIDE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_GUIDE, fmt, ...)
end

function LOG_TASK( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_TASK, fmt, ...)
end

function LOG_CURRENCY( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_CURRENCY, fmt, ...)
end

function LOG_ITEM( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ITEM, fmt, ...)
end

function LOG_CREATE_CLICK( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_CREATE_CLICK, fmt, ...)
end

function LOG_GUIDE_DIALOG( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_GUIDE_DIALOG, fmt, ...)
end

function LOG_FUNC_GUIDE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_FUNC_GUIDE, fmt, ...)
end

function LOG_ROLE_ARMY( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_ARMY, fmt, ...)
end

function LOG_ROLE_ACTIVITYINFERNAL( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_ACTIVITYINFERNAL, fmt, ...)
end

function LOG_ROLE_ACTIVITYDAYSTYPE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_ACTIVITYDAYSTYPE, fmt, ...)
end

function LOG_ROLE_NEWACTIVITYDAYSTYPE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_NEWACTIVITYDAYSTYPE, fmt, ...)
end

function LOG_ROLE_EVOLUTION( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_EVOLUTION, fmt, ...)
end

function LOG_ROLE_GUILD( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_GUILD, fmt, ...)
end

function LOG_ROLE_STRONG_HOLD( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_STRONG_HOLD, fmt, ...)
end

function LOG_ROLE_SCOUT( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_SCOUT, fmt, ...)
end

function LOG_ROLE_PLAYER_RECHARGE( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_ROLE_PLAYERRECHARGE, fmt, ...)
end

function LOG_GUILD_BUILD( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_GUILD_BUILD, fmt, ...)
end

function LOG_GUILD_BUILD_TROOP( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_GUILD_BUILD_TROOP, fmt, ...)
end

function LOG_TROOPS_MARCH( fmt, ... )
	LOG_STATISTICS(EnumLogDef.E_LOG_TROOPS_MARCH, fmt, ...)
end