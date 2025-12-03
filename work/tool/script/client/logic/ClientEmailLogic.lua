local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"

-- lua Main.lua email_GetEmails x0 60000000
function ClientLogic:email_GetEmails ( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Email_GetEmails( ClientCommon._C2S_Request) ) )
end

function ClientLogic:Email_GetEmails( _C2S_Request )
    return _C2S_Request( "Email_GetEmails", { }, 100 )
end

-- lua Main.lua email_MsgSendPrivateEmail w15 60000019 60000011 xiaoniangao HappyChildrenDay
function ClientLogic:email_MsgSendPrivateEmail ( mode, token, rid, receivers, title, content )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Email_MsgSendPrivateEmail( ClientCommon._C2S_Request, receivers, title, content ) ) )
end

function ClientLogic:Email_MsgSendPrivateEmail( _C2S_Request, receivers, title, content )
    local tRid = string.split(receivers, '-')
    local lst = {}
    for _, rid in pairs(tRid) do
        table.insert(lst, {rid = rid, gameNode = 'game6'})
    end

    return _C2S_Request( "Email_MsgSendPrivateEmail", { lst = lst, title = title, content = content }, 100 )
end

function ClientLogic:sendguildemail( mode, token, rid, subTitle, emailContent )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:SendGuildEmail( ClientCommon._C2S_Request, subTitle, emailContent ) ) )
end

function ClientLogic:SendGuildEmail( _C2S_Request, subTitle, emailContent )
    return _C2S_Request( "Email_SendGuildEmail", { subTitle = subTitle, emailContent = emailContent }, 100 )
end

-- lua Main.lua email_DeleteEmail w1 60000001 5
function ClientLogic:email_DeleteEmail ( mode, token, rid, nMailType )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Email_DeleteEmail( ClientCommon._C2S_Request, nMailType) ) )
end

function ClientLogic:Email_DeleteEmail( _C2S_Request, nMailType )
    return _C2S_Request( "Email_DeleteEmail", { type = 2, data = nMailType }, 100 )
end