local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"
local socket = require "clientcore"
local Random = require "Random"

-- lua Main.lua chat_SendPrivateMsg w1 60000001 60000011 616-1 game6
function ClientLogic:chat_SendPrivateMsg ( mode, token, rid, toRid, msgContent, gameNode )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Chat_SendPrivateMsg( ClientCommon._C2S_Request, toRid, msgContent, gameNode ) ) )
end

function ClientLogic:Chat_SendPrivateMsg( _C2S_Request, toRid, msgContent, gameNode )
    return _C2S_Request( "Chat_SendPrivateMsg", { toRid = toRid, msgContent = msgContent, gameNode = gameNode }, 100 )
end

-- lua Main.lua chat_Msg2GSQueryPrivateChatLst w1 60000001
function ClientLogic:chat_Msg2GSQueryPrivateChatLst ( mode, token, rid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Chat_Msg2GSQueryPrivateChatLst( ClientCommon._C2S_Request) ) )
end

function ClientLogic:Chat_Msg2GSQueryPrivateChatLst( _C2S_Request )
    return _C2S_Request( "Chat_Msg2GSQueryPrivateChatLst", { }, 100 )
end

-- lua Main.lua chat_Msg2GSQueryPrivateChatByRid x0 60000000 60000001
function ClientLogic:chat_Msg2GSQueryPrivateChatByRid ( mode, token, rid, toRid )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Chat_Msg2GSQueryPrivateChatByRid( ClientCommon._C2S_Request, toRid) ) )
end

function ClientLogic:Chat_Msg2GSQueryPrivateChatByRid( _C2S_Request, toRid )
    return _C2S_Request( "Chat_Msg2GSQueryPrivateChatByRid", { toRid = toRid }, 100 )
end

-- lua Main.lua chat_Msg2GSReadPrivateChat w1 60000001 60000011 1592373603
function ClientLogic:chat_Msg2GSReadPrivateChat ( mode, token, rid, toRid, tsLastRead )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Chat_Msg2GSReadPrivateChat( ClientCommon._C2S_Request, toRid, tsLastRead) ) )
end

function ClientLogic:Chat_Msg2GSReadPrivateChat( _C2S_Request, toRid, tsLastRead )
    return _C2S_Request( "Chat_Msg2GSReadPrivateChat", { toRid = toRid, tsLastRead = tsLastRead }, 100 )
end

function ClientLogic:sendmsg( mode, token, rid, channelType )
    local fd = self:rolelogin( mode, token, rid )
    local chatFd = self:authChat( fd, rid )

    local nowTime
    local heartTime = 0
    local sendTime = 0
    local chars = {}
    for i = 48, 57 do
        table.insert( chars, i )
    end
    for i = 65, 90 do
        table.insert( chars, i )
    end
    for i = 97, 122 do
        table.insert( chars, i )
    end
    local charNum = #chars
    while true do
        nowTime = os.time()
        if nowTime - heartTime > 10 then
            self:heart( mode, token, rid, 1, 1, fd )
            heartTime = nowTime
        end

        if nowTime - sendTime >= 2 then
            local num
            local content = ""
            for _ = 1, 300 do
                num = math.random( 1, charNum )
                content = content .. string.char( chars[num] )
            end
            ClientCommon:sendpack( chatFd, ClientCommon:MakeSprotoPack( self:SendMsg( ClientCommon._C2S_Request, channelType, content ) ) )
            sendTime = nowTime
        end

        socket.usleep(1000)
    end
end

function ClientLogic:SendMsg( _C2S_Request, channelType, msgContent )
    return _C2S_Request( "Chat_SendMsg", { channelType = channelType, msgContent = msgContent } )
end