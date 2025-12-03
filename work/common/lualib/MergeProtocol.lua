--[[
 * @file : MergeProtocol.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-07-01 15:21:10
 * @Last Modified time: 2020-07-01 15:21:10
 * @department : Arabic Studio
 * @brief : 合并协议
 * Copyright(C) 2019 IGG, All rights reserved
]]

local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"

local MergeProtocol = {}

---@see 注册CS协议
function MergeProtocol:regCSSproto()
    local f = io.open(Enum.COMMON_SPROTO_PATH, "r")
	local commonSprotoBlock = assert(f:read("*a"), "read commonsproto fail,path:" .. Enum.COMMON_SPROTO_PATH)
	f:close()
	f = io.open(Enum.PROTOCOL_PATH, "r")
	local dbSprotoBlock = assert(f:read("*a"), "read cssproto fail,path:" .. Enum.PROTOCOL_PATH)
    f:close()

    local allSproto = commonSprotoBlock .. dbSprotoBlock

    sprotoloader.save(sprotoparser.parse(allSproto), Enum.SPROTO_SLOT.RPC)
end

---@see 获取DB协议
function MergeProtocol:getDBSproto()
    local f = io.open(Enum.COMMON_SPROTO_PATH, "r")
	local commonSprotoBlock = assert(f:read("*a"), "read commonsproto fail,path:" .. Enum.COMMON_SPROTO_PATH)
	f:close()
	f = io.open(Enum.DB_SPROTO_PATH, "r")
	local dbSprotoBlock = assert(f:read("*a"), "read dbsproto fail,path:" .. Enum.DB_SPROTO_PATH)
    f:close()

    return commonSprotoBlock .. dbSprotoBlock
end

return MergeProtocol