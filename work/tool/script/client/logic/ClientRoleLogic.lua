--[[
* @file : ClientLogin.lua
* @type : lua lib
* @author : linfeng
* @created : Thu Jan 04 2018 14:13:15 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 客户端登陆相关
* Copyright(C) 2017 IGG, All rights reserved
]]

local ClientLogic = require "logic.ClientLogic"
local ClientCommon = require "logic.ClientCommon"
local socket = require "clientcore"
local CHECK = ClientCommon.CHECK

function ClientLogic:rolecreate( mode, token, name, country, ext )
    CHECK(name and token and country, self.help)
    if ext then
        token = ext .. token
    end
    local fd, ret = self:auth( mode, token, true )
    if ret then
        ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RoleCreateRequest( ClientCommon._C2S_Request, name, country ) ) )
    end
    local data = socket.recv(fd)
    ClientCommon:unpack(data)
    socket.close(fd)
end

function ClientLogic:rolelogin( mode, token, rid )
    CHECK(token and rid, self.help)
    local fd, ret = self:auth( mode, token, true )
    if ret then
        ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RoleLoginRequest( ClientCommon._C2S_Request, rid ) ) )
    end
    return fd
    --[[
    while true do
        local data = socket.recv(fd, 10)
        if data then
            ClientCommon:unpack(data)
        end
    end
    ]]
end

function ClientLogic:rolelogintest( mode, token, rid )
    CHECK(token and rid, self.help)
    local fd, ret = self:auth( mode, token, true )
    if ret then
        ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RoleLoginRequest( ClientCommon._C2S_Request, rid ) ) )
    end

    local nowTime
    local heartTime = 0
    while true do
        nowTime = os.time()
        if nowTime - heartTime >= 10 then
            self:heart( mode, token, rid, 1, 1, fd )
            heartTime = nowTime
        end

        socket.usleep(1000000)
    end
end

function ClientLogic:rolelist( mode, token )
    CHECK(token, self.help)
    local fd, ret = self:auth( mode, token, true )
    if ret then
        ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RoleGetRoleList( ClientCommon._C2S_Request ) ) )
    end

    local data = socket.recv(fd)
    ClientCommon:unpack(data)
end

function ClientLogic:mapmarch( mode, token, x, y )
    CHECK(token, self.help)
    local fd, ret = self:auth( mode, token, true )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:RoleLoginRequest( ClientCommon._C2S_Request, 10000205 ) ) )
    if ret then
        ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:MapMarchRequest( ClientCommon._C2S_Request, x, y ) ) )
    end
end

function ClientLogic:mapmove( mode, token, x, y )
    CHECK(token, self.help)
    local fd, ret = self:auth( mode, token, true )
    if ret then
        ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:MapMoveRequest( ClientCommon._C2S_Request, x, y ) ) )
    end
end

function ClientLogic:trainArmy( mode, token, rid, buildingIndex, type, level, isUpdate, trainNum, immediately, armyQueueIndex )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:TrainArmy( ClientCommon._C2S_Request,
                                        buildingIndex, type, level, isUpdate, trainNum, immediately, armyQueueIndex) ) )
end

function ClientLogic:awardArmy( mode, token, rid, type )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:AwardArmy( ClientCommon._C2S_Request, type ) ) )
end

function ClientLogic:trainEnd( mode, token, rid, type )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:TrainEnd( ClientCommon._C2S_Request, type ) ) )
end

function ClientLogic:disbandArmy( mode, token, rid, type, level, num )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:DisbandArmy( ClientCommon._C2S_Request, type, level, num ) ) )
end

function ClientLogic:RoleCreateRequest( _C2S_Request, _name, _country )
    return _C2S_Request( "Role_CreateRole", { name = _name, country = _country }, 100 )
end

function ClientLogic:RoleLoginRequest( _C2S_Request, _rid )
    return _C2S_Request( "Role_RoleLogin", { rid = _rid }, 100 )
end

function ClientLogic:RoleGetRoleList( _C2S_Request )
    return _C2S_Request( "Role_GetRoleList", {}, 100 )
end

function ClientLogic:MapMarchRequest( _C2S_Request, x, y )
    return _C2S_Request( "Map_March", { armyIndex = 0, targetType = 0, targetArg = { pos = { x = x, y = y } } }, 100 )
end

function ClientLogic:MapMoveRequest( _C2S_Request, x, y )
    return _C2S_Request( "Map_Move", { x = x, y = y }, 100 )
end

function ClientLogic:TrainArmy( _C2S_Request, buildingIndex, type, level, isUpdate, trainNum, immediately, armyQueueIndex )
    return _C2S_Request( "Role_TrainArmy", { buildingIndex = buildingIndex, type = type, level = level, isUpdate = isUpdate, trainNum = trainNum,
    immediately = immediately, armyQueueIndex = armyQueueIndex }, 100 )
end

function ClientLogic:AwardArmy( _C2S_Request, type )
    return _C2S_Request( "Role_AwardArmy", { type = type }, 100 )
end

function ClientLogic:TrainEnd( _C2S_Request, type )
    return _C2S_Request( "Role_TrainEnd", { type = type }, 100 )
end

function ClientLogic:DisbandArmy( _C2S_Request, type, level, num )
    return _C2S_Request( "Role_DisbandArmy", { type = type, level = level, num = num }, 100 )
end

function ClientLogic:buyresource( mode, token, rid, itemId, itemNum )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:BuyResource( ClientCommon._C2S_Request, itemId, itemNum ) ) )
end

function ClientLogic:BuyResource( _C2S_Request, itemId, itemNum )
    return _C2S_Request( "Role_BuyResource", { itemId = itemId, itemNum = itemNum }, 100 )
end

function ClientLogic:speedUp( mode, token, rid, queueIndex, type, itemId, itemNum, costDenar )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:SpeedUp( ClientCommon._C2S_Request, queueIndex, type, itemId, itemNum, costDenar ) ) )
end

function ClientLogic:SpeedUp( _C2S_Request, queueIndex, type, itemId, itemNum, costDenar )
    return _C2S_Request( "Role_SpeedUp", { queueIndex = queueIndex, type = type, itemId = itemId, itemNum = itemNum, costDenar = costDenar }, 100 )
end

function ClientLogic:queryrolebyparam( mode, token, rid, param )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:QueryRoleByParam( ClientCommon._C2S_Request, param ) ) )
end

function ClientLogic:QueryRoleByParam( _C2S_Request, param )
    return _C2S_Request( "Role_QueryRoleByParam", { param = param }, 100 )
end

function ClientLogic:getVipPoint( mode, token, rid )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetVipPoint( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetVipPoint( _C2S_Request )
    return _C2S_Request( "Role_GetVipPoint", {}, 100 )
end

function ClientLogic:getVipFreeBox( mode, token, rid )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:GetVipFreeBox( ClientCommon._C2S_Request ) ) )
end

function ClientLogic:GetVipFreeBox( _C2S_Request )
    return _C2S_Request( "Role_GetVipFreeBox", {}, 100 )
end

function ClientLogic:changeCivilization( mode, token, rid, civilizationId, useItem )
    CHECK(token, self.help)
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:ChangeCivilization( ClientCommon._C2S_Request, civilizationId, useItem ) ) )
end

function ClientLogic:ChangeCivilization( _C2S_Request, civilizationId, useItem )
    return _C2S_Request( "Role_ChangeCivilization", { civilizationId = civilizationId, useItem = useItem }, 100 )
end

-- lua Main.lua role_QueryRoleName w0 60000000 ID.118942635
function ClientLogic:role_QueryRoleName ( mode, token, rid, name )
    local fd = self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Role_QueryRoleName( ClientCommon._C2S_Request, name) ) )
end

function ClientLogic:Role_QueryRoleName( _C2S_Request, name )
    return _C2S_Request( "Role_QueryRoleName", { name = name }, 100 )
end

function ClientLogic:heart( mode, token, rid, serverTime, clientTime, fd )
    local fd = fd or self:rolelogin( mode, token, rid )
    ClientCommon:sendpack( fd, ClientCommon:MakeSprotoPack( self:Heart( ClientCommon._C2S_Request, serverTime, clientTime) ) )
end

function ClientLogic:Heart( _C2S_Request, serverTime, clientTime )
    return _C2S_Request( "Role_Heart", { serverTime = serverTime, clientTime = clientTime }, 100 )
end
