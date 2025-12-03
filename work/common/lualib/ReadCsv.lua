--[[
* @file : ReadCsv.lua
* @type : lualib
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 读取 csv 配置文件
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local ReadCsv = {}
local ConfigPath = skynet.getenv("configpath")
local FileSuffix = '.csv'
local FileSeparate = ','
local StringSeparate = "|"

---@see 读取某个csv文件内容并解析
-- param@_fileName : 文件名称(不含路径)
-- return : table
function ReadCsv:resolve( _fileName )
    -- 读取文件内容
    local filePath = string.format("%s/%s%s",ConfigPath, _fileName, FileSuffix)
    local f = io.open(filePath, "r")
    if f == nil then assert(false, string.format( "not exist csv file:%s", filePath)) end
    -- 解析文件内容
    -- 第一行为字段名
    local columnNames = f:read("l")
    columnNames = string.trim(columnNames, '\r')
    columnNames = string.split(columnNames, FileSeparate)
    -- 移除 BOM 头
    if string.byte(columnNames[1],1) == 0xef
        and string.byte(columnNames[1],2) == 0xbb
        and string.byte(columnNames[1],3) == 0xbf then
            columnNames[1] = columnNames[1]:sub(4)
    end

    --第二行为数据类型,第三行为注释
    f:read("l")
    f:read("l")
    --之后为数据
    local fileData = {}
    local lineData
    local lineRecord
    local key
    local lineIndex = 1

    for line in f:lines("l") do
        lineRecord = {}
        line = string.trim(line, '\r')
        lineData = string.split(line, FileSeparate, true)
        assert(#lineData == #columnNames,
                string.format("%s%s column not match data size at line(%d), lineData(%d),columnNames(%d), data(%s)",
                _fileName, FileSuffix, lineIndex, #lineData, #columnNames, tostring(lineData)))
        key = lineData[1] -- 默认第一个字段为key
        key = string.trim(key, "\"")
        key = tonumber(key) or key
        for index,name in pairs(columnNames) do
            name = string.trim(name, "\"")
            lineData[index] = string.trim(lineData[index], "\"")
            lineData[index] = tonumber(lineData[index]) or lineData[index]
            if type(lineData[index]) == "string" and lineData[index]:find(StringSeparate) then
                lineData[index] = string.split(lineData[index], StringSeparate, true)
            end
            lineRecord[name] = lineData[index]
        end
        -- 设置为const
        lineRecord = const(lineRecord)
        fileData[key] = lineRecord
        lineIndex = lineIndex + 1
    end
    f:close()
    return fileData
end

return ReadCsv