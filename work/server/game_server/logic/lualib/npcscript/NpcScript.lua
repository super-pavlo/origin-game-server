--[[
* @file : NpcScript.lua
* @type : lua lib
* @author : linfeng
* @created : Fri Dec 15 2017 11:07:50 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 执行 NPC Script 入口
* Copyright(C) 2017 IGG, All rights reserved
]]

local NpcScript = {}

---@see 执行NPC相关指令
---@param _rid integer 角色id
---@param _funcarg table 函数参数表,{ function_name, function_arg }
---@param _postArg any 客户端传递上来的参数
function NpcScript:Do( _rid, _funcarg, _postArg, _dynamicNpcId )
    local funcname = _funcarg.func
    local funcarg = _funcarg.parm

    if funcname then
        local f = self[funcname]
        if f then
            return f( self, _rid, funcarg, _postArg, _dynamicNpcId )
        else
            LOG_ERROR("not found funcname(%s)", funcname)
        end
    else
        LOG_ERROR("not _funcname at NpcScript Do!")
    end
end

return NpcScript