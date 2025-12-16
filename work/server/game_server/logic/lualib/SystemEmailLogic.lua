--[[
 * @file : SystemEmailLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-28 14:00:15
 * @Last Modified time: 2020-05-28 14:00:15
 * @department : Arabic Studio
 * @brief : 系统邮件逻辑
 * Copyright(C) 2019 IGG, All rights reserved
]]

local SystemEmailLogic = {}

---@see 判断系统邮件是否过期
function SystemEmailLogic:checkEmailTimeout( _allEmailInfo )
    local now = os.time()
    local expiredEmails = {}
    for emailIndex, emailInfo in pairs(_allEmailInfo) do
        if emailInfo.expiredTime <= now then
            table.insert( expiredEmails, emailIndex )
        end
    end

    for _, emailIndex in pairs(expiredEmails) do
        LOG_INFO("delete systemmail mainIndex(%d)", emailIndex)
        SM.c_systemmail.req.Delete( emailIndex )
        _allEmailInfo[emailIndex] = nil
    end
end

return SystemEmailLogic