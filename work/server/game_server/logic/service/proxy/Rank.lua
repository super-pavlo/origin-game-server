--[[
* @file : Rank.lua
* @type : snax multi service
* @author : chenlei
* @created : Mon Apr 20 2020 19:35:02 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 排行版协议服务
* Copyright(C) 2017 IGG, All rights reserved
]]
local RankLogic = require "RankLogic"

---@see 查询排行版
function response.QueryRank( msg )
    local rid = msg.rid
    local type = msg.type
    local num = msg.num
    return RankLogic:queryRank( rid, type, num )
end

---@see 查询每个排行版第一
function response.ShowRankFirst( msg )
    return RankLogic:showRankFirst( msg.rid, msg.type )
end