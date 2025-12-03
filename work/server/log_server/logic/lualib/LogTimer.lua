--[[
 * @file : LogTimer.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2019-04-01 10:13:29
 * @Last Modified time: 2019-04-01 10:13:29
 * @department : Arabic Studio
 * @brief : 日志定时逻辑文件
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Timer = require"Timer"
local LogTimer = {}

---@type function
local crossDayCallback = nil

---@see 初始化日志定时器
function LogTimer:Init( cb )
    -- 获取最后跨天时间
    local lastCrossDayId = string.format( "%s_%d", Common.getSelfNodeName(), Enum.SystemCfg.LAST_CROSS_DAY )
    local lastCrossDayTime = SM.c_system.req.Get( lastCrossDayId, "number" )
    if not lastCrossDayTime then
        SM.c_system.req.Add( lastCrossDayId, { number = os.time() } )
        self:CrossDay()
    end

    -- 重启时间过了跨天时间,补回跨天重置
    if Timer.isDiffDay( lastCrossDayTime ) then
        self:CrossDay()
    end

    -- 启动定时器
    Timer.runEveryDayHour( 0, self.CrossDay, self )

    crossDayCallback = cb
    local nowDate = Timer.GetYmd(os.time())
    crossDayCallback(nowDate)
end

---@see 跨天重建日志table
function LogTimer:CrossDay()
    local nowDate = Timer.GetYmd(os.time())
    Common.mysqlExecute(string.format("call f_new_log_table('%s')", nowDate))
    if crossDayCallback then
        crossDayCallback(nowDate)
    end
end

return LogTimer