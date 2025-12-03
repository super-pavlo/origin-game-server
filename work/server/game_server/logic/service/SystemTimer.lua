--[[
* @file : SystemTimer.lua
* @type : snax single service
* @author : linfeng
* @created : Tue Jun 26 2018 14:08:13 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 系统定时器服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local GuildLogic = require "GuildLogic"
local GuildTechnologyLogic = require "GuildTechnologyLogic"
local MapLogic = require "MapLogic"
local GuildGiftLogic = require "GuildGiftLogic"

---@see 跨周事宜
local function CrossWeek()
    -- 重置联盟跨周捐献处理
    GuildTechnologyLogic:resetGuildWeekDonate()
    -- 重置处理联盟排行榜信息
    GuildLogic:resetGuildRoleRankInfo()
    -- 重置活动信息
    SM.ActivityMgr.post.weekResetActivity()
end

---@see 跨月事宜
local function CrossMonth()

end

---@see 跨天事宜
local function CrossDay()
    local crossDayId = Enum.SystemCfg.LAST_CROSS_DAY
    local lastCrossDayTime = SM.c_system.req.Get( crossDayId, "number" )

    -- 重置联盟跨天捐献处理
    GuildTechnologyLogic:resetGuildDailyDonate()
    -- 跨天记录联盟日志
    GuildLogic:guildLog()

    -- 每周的开始
    if Timer.isDiffWeek( lastCrossDayTime ) then
        CrossWeek()
    end

    -- 跨月处理
    if Timer.isDiffMonth( lastCrossDayTime ) then
        CrossMonth()
    end

    SM.c_system.req.Set( crossDayId, "number", os.time() )
end

function response.Init()
    local crossDayId = Enum.SystemCfg.LAST_CROSS_DAY
    -- 获取最后跨天时间
    local lastCrossDayTime = SM.c_system.req.Get( crossDayId, "number" )
    if not lastCrossDayTime then
        SM.c_system.req.Add( crossDayId, { number = os.time() } )
    end

    -- 重启时间过了跨天时间,补回跨天重置
    if Timer.isDiffDay( lastCrossDayTime ) then
        CrossDay()
    end

    -- 服务器重启联盟战力刷新
    GuildLogic:refreshGuildPower()
    -- 增加联盟战力刷新定时器
    local alliancePowerRefreshTime = CFG.s_Config:Get("alliancePowerRefreshTime")
    Timer.runEvery( alliancePowerRefreshTime * 100, GuildLogic.refreshGuildPower, GuildLogic )
    -- 整点检查联盟盟主离线时间是否已达转让要求
    Timer.runEveryHour( GuildLogic.checkGuildLeaderLogoutTime, GuildLogic )
    -- 整点清楚联盟礼物中超时数据
    Timer.runEveryHour( GuildGiftLogic.checkGuildGiftTimeOut, GuildGiftLogic )

    -- 启动定时器
    Timer.runEveryDayHour( CFG.s_Config:Get("systemDayTime"), CrossDay )

    -- 定时清理已满省份信息
    Timer.runEvery( CFG.s_Config:Get("provinceFlagCleanTime") * 100, MapLogic.cleanFullProvince, MapLogic )
end