--[[
* @file : ClientGuildLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Thu Apr 09 2020 14:41:47 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端联盟相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

function ClientLogic:createguild( mode, token, rid, name, abbreviationName, notice, needExamine, languageId, signs )
    local fd = self:rolelogin( mode, token, rid )
    local signList = string.split( signs, "-" )
    if needExamine == "true" then
        needExamine = true
    else
        needExamine = false
    end
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:CreateGuild( ClientCommon._C2S_Request, name, abbreviationName, notice, needExamine, languageId, signList ) ) )
end

function ClientLogic:CreateGuild( _C2S_Request, name, abbreviationName, notice, needExamine, languageId, signs )
    return _C2S_Request( "Guild_CreateGuild", {
        name = name, abbreviationName = abbreviationName, notice = notice,
        needExamine = needExamine, languageId = languageId, signs = signs
    }, 100 )
end

function ClientLogic:applyjoinguild( mode, token, rid, guildId )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ApplyJoinGuild( ClientCommon._C2S_Request, guildId ) ) )
end

function ClientLogic:ApplyJoinGuild( _C2S_Request, guildId )
    return _C2S_Request( "Guild_ApplyJoinGuild", { guildId = guildId }, 100 )
end

function ClientLogic:searchguild( mode, token, rid, type, keyName )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:SearchGuild( ClientCommon._C2S_Request, type, keyName ) ) )
end

function ClientLogic:SearchGuild( _C2S_Request, type, keyName )
    return _C2S_Request( "Guild_SearchGuild", { type = type, keyName = keyName }, 100 )
end

function ClientLogic:getguildinfo( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetGuildInfo( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetGuildInfo( _C2S_Request )
    return _C2S_Request( "Guild_GetGuildInfo", {}, 100 )
end

function ClientLogic:checkguildname( mode, token, rid, type, value )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:CheckGuildName( ClientCommon._C2S_Request, type, value ) ) )
end

function ClientLogic:CheckGuildName( _C2S_Request, type, value )
    return _C2S_Request( "Guild_CheckGuildName", { type = type, value = value }, 100 )
end

function ClientLogic:getrecomendguild( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetRecomendGuild( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetRecomendGuild( _C2S_Request )
    return _C2S_Request( "Guild_GetRecomendGuild", {}, 100 )
end

function ClientLogic:getguildapplys( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetGuildApplys( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetGuildApplys( _C2S_Request )
    return _C2S_Request( "Guild_GetGuildApplys", {}, 100 )
end

function ClientLogic:examineguildapply( mode, token, rid, applyRid, result )
    local fd = self:rolelogin( mode, token, rid )

    if result == "true" then
        result = true
    else
        result = false
    end

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ExamineGuildApply( ClientCommon._C2S_Request, applyRid, result ) ) )
end

function ClientLogic:ExamineGuildApply( _C2S_Request, applyRid, result )
    return _C2S_Request( "Guild_ExamineGuildApply", { applyRid = applyRid, result = result }, 100 )
end

function ClientLogic:getrecomendrole( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetRecomendRole( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetRecomendRole( _C2S_Request )
    return _C2S_Request( "Guild_GetRecomendRole", {}, 100 )
end

function ClientLogic:sendrequesthelp( mode, token, rid, requestType, queueIndex )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:SendRequestHelp( ClientCommon._C2S_Request, requestType, queueIndex ) ) )
end

function ClientLogic:SendRequestHelp( _C2S_Request, requestType, queueIndex )
    return _C2S_Request( "Guild_SendRequestHelp", { requestType = requestType, queueIndex = queueIndex }, 100 )
end

function ClientLogic:getguildrequesthelps( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetGuildRequestHelps( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetGuildRequestHelps( _C2S_Request )
    return _C2S_Request( "Guild_GetGuildRequestHelps", { }, 100 )
end

function ClientLogic:helpguildmembers( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:HelpGuildMembers( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:HelpGuildMembers( _C2S_Request )
    return _C2S_Request( "Guild_HelpGuildMembers", { }, 100 )
end

function ClientLogic:createguildbuild( mode, token, rid, type, xPoint, yPoint )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:CreateGuildBuild( ClientCommon._C2S_Request, type, xPoint, yPoint ) ) )
end

function ClientLogic:CreateGuildBuild( _C2S_Request, type, xPoint, yPoint )
    return _C2S_Request( "Guild_CreateGuildBuild", { type = type, pos = { x = xPoint, y = yPoint } }, 100 )
end

function ClientLogic:getotherguildInfo( mode, token, rid, guildId )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetOtherGuildInfo( ClientCommon._C2S_Request, guildId ) ) )
end

function ClientLogic:GetOtherGuildInfo( _C2S_Request, guildId )
    return _C2S_Request( "Guild_GetOtherGuildInfo", { guildId = guildId }, 100 )
end

function ClientLogic:getotherguildmembers( mode, token, rid, guildId )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetOtherGuildMembers( ClientCommon._C2S_Request, guildId ) ) )
end

function ClientLogic:GetOtherGuildMembers( _C2S_Request, guildId )
    return _C2S_Request( "Guild_GetOtherGuildMembers", { guildId = guildId }, 100 )
end

function ClientLogic:getguildmessageboard( mode, token, rid, guildId, messageIndex, type )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetGuildMessageBoard( ClientCommon._C2S_Request, guildId, messageIndex, type ) ) )
end

function ClientLogic:GetGuildMessageBoard( _C2S_Request, guildId, messageIndex, type )
    return _C2S_Request( "Guild_GetGuildMessageBoard", { guildId = guildId, messageIndex = messageIndex, type = type }, 100 )
end

function ClientLogic:recommendtechnology( mode, token, rid, technologyType )
    local fd = self:rolelogin( mode, token, rid )

    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RecommendTechnology( ClientCommon._C2S_Request, technologyType ) ) )
end

function ClientLogic:RecommendTechnology( _C2S_Request, technologyType )
    return _C2S_Request( "Guild_RecommendTechnology", { technologyType = technologyType }, 100 )
end

-- lua Main.lua guild_ShopStock w0 60000000 201010010 3
function ClientLogic:guild_ShopStock( mode, token, rid, idItemType, nCount )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Guild_ShopStock( ClientCommon._C2S_Request, idItemType, nCount ) ) )
end

function ClientLogic:Guild_ShopStock( _C2S_Request, idItemType, nCount )
    return _C2S_Request( "Guild_ShopStock", { idItemType = idItemType, nCount = nCount }, 100 )
end

-- lua Main.lua guild_ShopBuy w0 60000000 201010010 1
function ClientLogic:guild_ShopBuy( mode, token, rid, idItemType, nCount )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Guild_ShopBuy( ClientCommon._C2S_Request, idItemType, nCount ) ) )
end

function ClientLogic:Guild_ShopBuy( _C2S_Request, idItemType, nCount )
    return _C2S_Request( "Guild_ShopBuy", { idItemType = idItemType, nCount = nCount }, 100 )
end

-- lua Main.lua guild_ShopQuery w0 60000000
function ClientLogic:guild_ShopQuery( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Guild_ShopQuery( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:Guild_ShopQuery( _C2S_Request )
    return _C2S_Request( "Guild_ShopQuery", { }, 100 )
end