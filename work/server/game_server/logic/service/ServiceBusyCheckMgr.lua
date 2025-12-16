--[[
* @file : ServiceBusyCheckMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Tue Oct 27 2020 16:13:17 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 服务是否忙碌检查服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local busyServices = {}

function accept.addBusyService( _type )
    if not busyServices[_type] then
        busyServices[_type] = 1
    else
        busyServices[_type] = busyServices[_type] + 1
    end
end

function accept.subBusyService( _type )
    if busyServices[_type] then
        busyServices[_type] = busyServices[_type] - 1
        if busyServices[_type] <= 0 then
            busyServices[_type] = nil
        end
    end
end

---@see 检查是否有忙碌服务
function response.checkServiceBusy()
    for type, count in pairs( busyServices ) do
        if count and count > 0 then
            LOG_INFO("service type(%d) count(%d) busy", type, count)
            return true
        end
    end
end
