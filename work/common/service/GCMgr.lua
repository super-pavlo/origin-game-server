--[[
 * @file : GCMgr.lua
 * @type : snax single service
 * @author : linfeng
 * @created : 2019-01-17 15:26:34
 * @Last Modified time: 2019-01-17 15:26:34
 * @department : Arabic Studio
 * @brief : GC内存管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Timer = require "Timer"
local timerId

function response.Init()
    --- 每小时清理一次lua内存
    timerId = Timer.runEveryHour( Common.gcAllServiceLuaMem )
end

function exit()
    Timer.delete( timerId )
end