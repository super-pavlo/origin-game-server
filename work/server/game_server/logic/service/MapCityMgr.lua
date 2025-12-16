--[[
* @file : MapCityMgr.lua
* @type : snax single service
* @author : dingyuchao
* @created : Wed Oct 21 2020 13:35:41 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 地图城市服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local cityNum = 0

---@see 添加城市数量
function accept.addCityNum()
    cityNum = cityNum + 1
end

---@see 检查地图城市数量是否大于最低值
---@return true 大于最小值并扣除1个
function response.checkSubCityNum()
    local hideCityLimitNum = CFG.s_Config:Get( "hideCityLimitNum" ) or 5000
    if cityNum > hideCityLimitNum then
        cityNum = cityNum - 1
        return true
    end
end

-- 扣除地图城市数量
function accept.subCityNum()
    cityNum = cityNum - 1
end

---@see 服务器启动检查当前地图上的城市数量
---@return true 地图城市已满
function response.checkMapCityFullOnServerReboot()
    return cityNum >= ( CFG.s_Config:Get( "hideCityLimitNum" ) or 5000 )
end