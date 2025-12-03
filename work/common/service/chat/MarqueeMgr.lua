--[[
 * @file : MarqueeMgr.lua
 * @type : snax single service
 * @author : linfeng 九   零 一 起 玩 w w w . 9 0 1 7  5 . co m
 * @created : 2020-05-29 10:11:34
 * @Last Modified time: 2020-05-29 10:11:34
 * @department : Arabic Studio
 * @brief : 跑马灯公告管理服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local Timer = require "Timer"

---@see 初始化
function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
end

---@see 发送跑马灯
local function sendMarqueeImpl( _content, _toGameId, _sendInterval, _endTime )
    local onlineRids = SM.OnlineMgr.req.getAllOnlineRidWithGameId()
    local languages = {
        cn = {}, en = {}, arb = {}, tr = {}
    }
    for rid, gameId in pairs(onlineRids) do
        if not _toGameId or gameId == _toGameId then
            if gameId == Enum.GameID.ANDROID_EN or gameId == Enum.GameID.IOS_EN then
                --  英文
                table.insert( languages.en, rid )
            elseif gameId == Enum.GameID.ANDROID_ARB or gameId == Enum.GameID.IOS_ARB then
                -- 阿语
                table.insert( languages.arb, rid )
            elseif gameId == Enum.GameID.ANDROID_TUR or gameId == Enum.GameID.IOS_TUR then
                -- 土耳其
                table.insert( languages.tr, rid )
            elseif gameId == Enum.GameID.ANDROID_CN or gameId == Enum.GameID.IOS_CN then
                -- 中文
                table.insert( languages.cn, rid )
            end
        end
    end

    local RoleChatLogic = require "RoleChatLogic"
    if not table.empty(languages.cn) and _content.cn then
        RoleChatLogic:sendMarquee( nil, nil, _content.cn, languages.cn )
    end

    if not table.empty(languages.en) and _content.en then
        RoleChatLogic:sendMarquee( nil, nil, _content.en, languages.en )
    end

    if not table.empty(languages.arb) and _content.arb then
        RoleChatLogic:sendMarquee( nil, nil, _content.arb, languages.arb )
    end

    if not table.empty(languages.tr) and _content.tr then
        RoleChatLogic:sendMarquee( nil, nil, _content.tr, languages.tr )
    end

    if _sendInterval then
        if not _endTime or ( os.time() + _sendInterval <= _endTime ) then
            Timer.runAfter( _sendInterval * 100, sendMarqueeImpl, _content, _toGameId, _sendInterval, _endTime )
        end
    end
end

---@see 转发跑马灯.一般由后台发送来
function accept.notifyMarquee( _content, _toGameId, _beginTime, _endTime, _sendInterval )
    if not _beginTime then
        -- 马上发送一次
        sendMarqueeImpl( _content, _toGameId, _sendInterval, _endTime )
    else
        -- 若干时间后发送
        Timer.runAt( _beginTime, sendMarqueeImpl, _content, _toGameId, _sendInterval, _endTime )
    end
end

---@see 发送建立联盟跑马灯
function accept.sendCreateGuildMarquee( _roleName, _abbreviationName )
    local RoleChatLogic = require "RoleChatLogic"
    -- 获取在线的rids
    local allRids = SM.OnlineMgr.req.getAllOnlineRid()
    RoleChatLogic:sendMarquee( 500806, { _roleName, _abbreviationName }, nil, allRids )
end

---@see 发送首次占领圣地跑马灯
function accept.sendFirstHoldHolyLandMarquee( _abbreviationName, _holyLandId )
    local RoleChatLogic = require "RoleChatLogic"
    -- 获取在线的rids
    local allRids = SM.OnlineMgr.req.getAllOnlineRid()
    RoleChatLogic:sendMarquee( 500804, { _abbreviationName, _holyLandId }, nil, allRids )
end

---@see 发送非首次占领圣地跑马灯
function accept.sendHoldHolyLandMarquee( _abbreviationName, _rawAbbreviationName, _holyLandId )
    local RoleChatLogic = require "RoleChatLogic"
    -- 获取在线的rids
    local allRids = SM.OnlineMgr.req.getAllOnlineRid()
    RoleChatLogic:sendMarquee( 500805, { _abbreviationName, _rawAbbreviationName, _holyLandId }, nil, allRids )
end