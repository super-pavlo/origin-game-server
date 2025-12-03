--[[
* @file : CenterConfigData.lua
* @type : snax single service
* @author : dingyuchao 九  零 一  起 玩 w w w .  9 0  1 7 5 . co m
* @created : Sat Feb 16 2019 13:00:01 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 重新初始化Center服务器静态数据结构
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local Timer = require "Timer"

---@see 重新初始化静态数据
function response.reInitConfigData()
    Timer.runAfter( 3 * 100, function ()
        snax.exit()
    end)
end