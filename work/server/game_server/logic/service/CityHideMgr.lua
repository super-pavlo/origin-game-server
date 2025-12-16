--[[
* @file : CityHideMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Wed Jul 22 2020 18:44:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 城市隐藏服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local RoleLogic = require "RoleLogic"
local CityHideLogic = require "CityHideLogic"
local GuildLogic = require "GuildLogic"

---@see 城市信息
---@class defaultCityHideInfoClass
local defaultCityHideInfo = {
    rid                         =                   0,
    lastLogoutTime              =                   0,
    level                       =                   0,
    createTime                  =                   0,
}

---@type table<int, defaultCityHideInfoClass>
local cityHides = {}

---@see 添加城市
function accept.addCity( _rid )
    local roleInfo = RoleLogic:getRole( _rid, {
        Enum.Role.lastLogoutTime, Enum.Role.level, Enum.Role.createTime, Enum.Role.guildId
    } )

    if CFG.s_CityHideData:Get( roleInfo.level ) then
        if not roleInfo.guildId or roleInfo.guildId <= 0
        or ( GuildLogic:getRoleGuildJob( roleInfo.guildId, _rid ) or 0 ) ~= Enum.GuildJob.LEADER then
            ---@type defaultCityHideInfoClass
            local cityHideInfo = const( table.copy( defaultCityHideInfo, true ) )
            cityHideInfo.rid = _rid
            cityHideInfo.lastLogoutTime = roleInfo.lastLogoutTime
            cityHideInfo.level = roleInfo.level
            cityHideInfo.createTime = roleInfo.createTime

            cityHides[_rid] = cityHideInfo
        end
    end
end

---@see 更新城市等级
function accept.updateRoleCityLevel( _rid, _level )
    if cityHides[_rid] then
        local sCityHideData = CFG.s_CityHideData:Get( _level )
        if sCityHideData then
            cityHides[_rid].level = _level
        else
            -- 超出等级，不用隐藏
            cityHides[_rid] = nil
        end
    end
end

---@see 删除城市
function response.deleteCity( _rid )
    if cityHides[_rid] then
        cityHides[_rid] = nil
    end
end

local function checkCityHide()
    -- 检查是否需要有需要隐藏的城市
    CityHideLogic:checkCityHide( cityHides )
    -- 添加下一次检查的定时器
    local hideCityFreqTime = ( CFG.s_Config:Get( "hideCityFreqTime" ) or 7 ) * 3600
    Timer.runAfter( hideCityFreqTime, checkCityHide )
end

---@see 初始化
function init()
    -- 添加定时器
    local hideCityFreqTime = ( CFG.s_Config:Get( "hideCityFreqTime" ) or 7 ) * 3600
    Timer.runAfter( hideCityFreqTime, checkCityHide )
end

function response.Init()
end

---@see PMLogic增加执行操作
function accept.cityHide()
    CityHideLogic:checkCityHide( cityHides )
end
