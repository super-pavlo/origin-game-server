--[[
* @file : battleConfigDaa.lua
* @type : snax single service
* @author : linfeng
* @created : Thu Jan 11 2018 09:36:26 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 重载战斗服务器相关配置
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local Timer = require "Timer"

---@see 重新初始化s_MapZone数据
function response.reInitConfigData()
    -- 清除Configs.data数据
    SM.ReadConfig.req.clean()
    Timer.runAfter( 3 * 100, function ()
        snax.exit()
    end)
end