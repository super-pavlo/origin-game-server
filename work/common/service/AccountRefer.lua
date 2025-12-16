--[[
 * @file : AccountRefer.lua
 * @type : multi snax service
 * @author : linfeng
 * @created : 2019-05-24 14:15:28
 * @Last Modified time: 2019-05-24 14:15:28
 * @department : Arabic Studio
 * @brief : 角色推荐服务器服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local socketchannel = require "skynet.socketchannel"
local sharedata = require "skynet.sharedata"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

local channel
local queryIp = "snd-ipquery.api.igg.com"
local queryPort = 10119

function init( _index )
    --[[
    -- 连接到地区查询服务器
    channel = socketchannel.channel( { host = queryIp, port = queryPort } )
    -- try connect first only once
    channel:connect(true)
    -- 初始化推荐服务器配置
    if _index == 1 then
        local recommendInfos = SM.c_recommend.req.Get()
        local ret = {}
        for _, recommendInfo in pairs(recommendInfos) do
            ret[recommendInfo.serverNode] = recommendInfo
        end
        -- 写入共享九  零 一 起 玩 w w w . 9 0 1 7 5 . co m
        sharedata.new( Enum.Share.RecommendConfig, ret )
    end
    ]]

    snax.enablecluster()
    cluster.register(SERVICE_NAME .. _index)
end

function response.Init( )

end

---@see 等待数据返回
local function waitAreaResponse( _sock )
    local clientArea = _sock:readline()
    if not clientArea then
        return true
    end

    local beginIndex = clientArea:find("CountryCode=")
    if not beginIndex then
        return true
    end
    clientArea = clientArea:sub(beginIndex + 12)
    local endIndex = clientArea:find(";")
    if not endIndex then
        return true
    end
    clientArea = clientArea:sub(1, endIndex - 1)

    return true, clientArea
end

---@see 根据IP获取所在地区
function response.getClientArea( _iggId, _realIp )
    --[[
    if not _realIp then return end
    -- 获取所在地区
    local clientArea = channel:request(_realIp .. "\n", waitAreaResponse )
    if not clientArea then
        LOG_ERROR("iggId(%s) realIp(%s) query area fail", tostring(_iggId), tostring(_realIp))
        return
    end
    return clientArea:upper()
    ]]
end

---@see 根据地区获取推荐服务器
function response.getReferGameNode( _clientArea )
    -- 匹配地区
    local recommendConfig = sharedata.query( Enum.Share.RecommendConfig )
    for serverNode, configInfo in pairs(recommendConfig) do
        if configInfo.recommendArea then
            for _, referArea in pairs(configInfo.recommendArea) do
                if _clientArea == referArea then
                    return serverNode
                end
            end
        end
    end
end

---@see 更新推荐服务器配置
function response.updateRecommendConfig( _config )
    local allRecommend = SM.c_recommend.req.Get()

    for _, configInfo in pairs(_config) do
        -- 移除旧的地区服务器
        for _, referArea in pairs(configInfo.recommendArea) do
            for gameNode, referInfo in pairs(allRecommend) do
                if table.exist( referInfo.recommendArea, referArea ) then
                    table.removevalue( referInfo.recommendArea, referArea )
                    if table.empty( referInfo.recommendArea ) then
                        -- 移除这个服务器的推荐信息
                        SM.c_recommend.req.Delete( gameNode )
                        allRecommend[gameNode] = nil
                    else
                        SM.c_recommend.req.Set( gameNode, referInfo )
                    end
                end
            end
        end

        allRecommend[configInfo.serverNode] = {
            recommendArea = configInfo.recommendArea,
            serverNode = configInfo.serverNode
        }

        local gameNodeRefer = SM.c_recommend.req.Get( configInfo.serverNode )
        if gameNodeRefer then
            gameNodeRefer.recommendArea = configInfo.recommendArea
            -- 更新
            SM.c_recommend.req.Set( configInfo.serverNode, gameNodeRefer )
        else
            -- 新增
            SM.c_recommend.req.Add( configInfo.serverNode, {
                recommendArea = configInfo.recommendArea,
                serverNode = configInfo.serverNode
            } )
        end
    end

    sharedata.update( Enum.Share.RecommendConfig, allRecommend )
    sharedata.flush()
end

---@see 获取推荐服务器配置
function response.getRecommendConfig( _serverNode )
    local recommendConfig = sharedata.query( Enum.Share.RecommendConfig )
    for serverNode, configInfo in pairs(recommendConfig) do
        if serverNode == _serverNode then
            return configInfo
        end
    end
    return {}
end