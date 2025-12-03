--[[
* @file : ReadConfig.lua
* @type : snax single service
* @author : linfeng
* @created : Fri Feb 09 2018 14:44:34 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 读取配置文件
* Copyright(C) 2017 IGG, All rights reserved
]]

local Configs

local function readConfig()
    local f = io.open("./common/config/gen/Configs.data", "r")
    if not f then return end
    local func, error = load(f:read("a"))
    if not func then
        LOG_ERROR("readConfig error(%s)", error)
        assert(false)
    end
    Configs = nil
    Configs = func()
    f:close()
    collectgarbage()
end

local function getConfigByName( _name )
    -- _之后的第一个字符大写
    local newName = _name:sub(3)

    if _name == "s_Config" then
        return assert(Configs[newName][1], newName)
    else
        return assert(Configs[newName], newName)
    end
end

function init()
    -- 加载配置
    readConfig()
end

---@see 重载
function response.reLoad()
    -- 加载配置
    readConfig()
end

---@see 清理数据
function response.clean()
    Configs = nil
    collectgarbage()
end

---@see 获取指定配置
function response.getConfig( _name )
    return getConfigByName( _name )
end