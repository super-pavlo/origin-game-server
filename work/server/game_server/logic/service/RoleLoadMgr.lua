--[[
* @file : RoleLoadMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Wed Sep 02 2020 19:12:09 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色信息加载服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local Timer = require "Timer"

function accept.loadRoleInfo( _index, _limit )
    local dbNode = Common.getDbNode()
    local roles = Common.rpcCall( dbNode, "RoleProxy", "queryRoles", _index, _limit ) or {}
    SM.RoleRecommendMgr.post.initRoles( roles )

    -- 服务退出
    Timer.runAfter( 3 * 100, function ()
        snax.exit()
    end)
end