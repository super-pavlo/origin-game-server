--[[
* @file : LogHook.lua
* @type : service
* @author : linfeng九  零 一 起 玩 w w w . 9 0 1 7 5 . co m
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 拦截 skynet.error 的输出到 SysLog 中
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    dispatch = function(_, address, msg)
        LOG_SKYNET("%x: %s", address, msg)
    end
}

skynet.start(function()
    skynet.register ".logger"
end)