--[[
* @file : MonumentMgr.lua
* @type : snax single service
* @author : chenlei
* @created : Fri May 01 2020 02:24:24 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 纪念碑服务
* Copyright(C) 2017 IGG, All rights reserved
]]
local snax = require "skynet.snax"
local Timer = require "Timer"
local MonumentLogic = require "MonumentLogic"
local step
--- 纪念碑定时器
local monumentMgr = {}
--- 纪念碑修正定时器
local monumentFixTimer = {}

function response.Init()
    local cMonument = SM.c_monument.req.Get() or {}
    local finishTime
    if table.size( cMonument ) > 0 then
        local min
        for _, info in pairs(cMonument) do
            if info.finishTime then
                if not min or info.id > min then
                    min = info.id
                    finishTime = info.finishTime
                end
            end
        end
        if min then
            snax.self().post.SetStep(min)
            snax.self().req.addMonumentTimer(finishTime)
            snax.self().req.addFixTiemr(min)
        end
        return
    end
    local sEvolutionMileStone = CFG.s_EvolutionMileStone:Get()
    for _, info in pairs(sEvolutionMileStone) do
        local monument = {}
        monument.id = info.order
        if info.order == 1 then
            local openTime = os.date('*t', Common.getSelfNodeOpenTime())
            local dayTime = { year = openTime.year, month = openTime.month, day = openTime.day, hour = CFG.s_Config:Get("systemDayTime") or 0, min = 0, sec = 0 }
            openTime = os.time(dayTime)
            monument.finishTime = openTime + info.expireTime
            finishTime = monument.finishTime
        end
        monument.count = 0
        monument.guildList = {}
        SM.c_monument.req.Add( monument.id, monument )
    end
    snax.self().post.SetStep(1)
    snax.self().req.addMonumentTimer(finishTime)
    snax.self().req.addFixTiemr(1)
end

function response.addFixTiemr( _step )
    local sOldEvolutionMileStone = CFG.s_EvolutionMileStone:Get(_step)
    if not sOldEvolutionMileStone or not sOldEvolutionMileStone.adjustRuleId or sOldEvolutionMileStone.adjustRuleId <= 0 then
        return
    end
    local fixTime = CFG.s_ZeroEmpty:Get( Enum.ZeroEmptyType.FIX_TIME )[sOldEvolutionMileStone.adjustRuleId]
    local beginTime
    if _step > 1 then
        beginTime = SM.c_monument.req.Get(_step - 1).finishTime
    else
        local openTime = os.date('*t', Common.getSelfNodeOpenTime())
	    local dayTime = { year = openTime.year, month = openTime.month, day = openTime.day, hour = CFG.s_Config:Get("systemDayTime") or 0, min = 0, sec = 0 }
        beginTime = os.time(dayTime)
    end
    local time = os.time() - beginTime
    local config
    -- 寻找最接近的修正时间
    for _, info in pairs (fixTime) do
        if time < info.checkTime and ( not config or config.checkTime > info.checkTime ) then
            config = info
        end
    end
    if monumentFixTimer[1] then
        Timer.delete( monumentFixTimer[1] )
    end
    if config then
        monumentFixTimer[1] = Timer.runAt( beginTime + config.checkTime, MonumentLogic.fixData, MonumentLogic, config.ID )
    end
end

function response.deleteFixTiemr()
    if monumentFixTimer[1] then
        Timer.delete( monumentFixTimer[1] )
    end
end

function accept.SetStep( _step )
    step = _step
end

function response.GetStep()
    return step
end

---@see 增加定时器
function response.addMonumentTimer( _interval )
    if monumentMgr[1] then
        Timer.delete( monumentMgr[1] )
    end
    monumentMgr[1] = Timer.runAt( _interval, MonumentLogic.monumentEnd, MonumentLogic )
end
