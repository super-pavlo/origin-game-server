--[[
* @file : PkIdMgr.lua
* @type : snax single service
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 主键生成管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local Timer = require "Timer"
local defaultPid, defaultPidName
local defaultPetId, defaultPetIdName
local defaultItemId, defaultItemIdName
local defaultSystemMailId, defaultSystemMailIdName
local defaultChatUniqueIndexId, defaultChatUniqueIndexIdName

local function savePKId()
    -- redis 的 get 指令为原子性
    local pkidkey = Common.redisExecute( { "get", "pkidkey" } )
    SM.c_pkid.req.Set( defaultPidName, "pkid", pkidkey )

    local petkey = Common.redisExecute( { "get", "petkey" } )
    SM.c_pkid.req.Set( defaultPetIdName, "pkid", petkey )

    local itemkey = Common.redisExecute( { "get", "itemkey" } )
    SM.c_pkid.req.Set( defaultItemIdName, "pkid", itemkey )

    local systemmailkey = Common.redisExecute( { "get", "systemmailkey" } )
    SM.c_pkid.req.Set( defaultSystemMailIdName, "pkid", systemmailkey )

    local chatUniqueIndexkey = Common.redisExecute( { "get", "chatUniqueIndexkey" } )
    SM.c_pkid.req.Set( defaultChatUniqueIndexIdName, "pkid", chatUniqueIndexkey )

    if Common.getSelfNodeName():find("game") then
        -- 保存角色数量
        local serverNode = Common.getSelfNodeName()
        local gameRoleCountKey = "gameRoleCount_" .. serverNode
        local gameRoleCount = Common.redisExecute( { "get", gameRoleCountKey } )
        SM.c_pkid.req.Set( gameRoleCountKey, "pkid", gameRoleCount )
    end
end

function init()
    local nodeName = Common.getSelfNodeName()
    defaultPid = (tonumber(skynet.getenv("serverid")) or 1) * 10000000
    defaultPidName = nodeName .. "_pId"
    defaultPetId = (tonumber(skynet.getenv("serverid")) or 1) * 1000000000000
    defaultPetIdName = nodeName .. "_petId"
    defaultItemId = (tonumber(skynet.getenv("serverid")) or 1) * 1000000000000
    defaultItemIdName = nodeName .. "_itemId"
    defaultSystemMailId = (tonumber(skynet.getenv("serverid")) or 1) * 1000000000000
    defaultSystemMailIdName = nodeName .. "_systemMailId"
    defaultChatUniqueIndexId = (tonumber(skynet.getenv("serverid")) or 1) * 100000000000000
    defaultChatUniqueIndexIdName = nodeName .. "_ChatUniqueIndexId"
end

local function initPkId( _name, _value, _rediskey )
    local t = SM.c_pkid.req.Get(_name)
    local pkid
    if not t or table.size(t) <= 0 then
        SM.c_pkid.req.Add( _name, { pkid = _value } )
        pkid = _value
    else
        pkid = t.pkid
    end

    Common.redisExecute( { "set", _rediskey, pkid } )
end

function response.Init()
    initPkId(defaultPidName, defaultPid, "pkidkey")
    initPkId(defaultPetIdName, defaultPetId, "petkey")
    initPkId(defaultItemIdName, defaultItemId, "itemkey")
    initPkId(defaultSystemMailIdName, defaultSystemMailId, "systemmailkey")
    initPkId(defaultChatUniqueIndexIdName, defaultChatUniqueIndexId, "chatUniqueIndexkey")

    if Common.getSelfNodeName():find("game") then
        local serverNode = Common.getSelfNodeName()
        local gameRoleCountKey = "gameRoleCount_" .. serverNode
        initPkId(gameRoleCountKey, 0, gameRoleCountKey)
    end

    -- 5秒保存一次
    Timer.runEvery( 100 * 5, savePKId )
end

---@see 获取默认defaultPid
function response.getDefaultPkId()
    return defaultPid
end

---@see 申请一个新的pkid
function response.newPkId()
    -- 利用 redis incr 命令的原子性,获取pkidkey
    return Common.redisExecute( { "incr", "pkidkey" } )
end